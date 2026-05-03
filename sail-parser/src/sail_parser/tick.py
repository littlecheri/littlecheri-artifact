from dataclasses import dataclass
from .parsing import TickText, parse_file_to_text
from enum import StrEnum, auto
from typing import List, Tuple, Optional, Iterator, Generator
import re
from itertools import chain
from multiprocessing.queues import Queue
from io import BytesIO, StringIO

class Instruction:
    opcode: int
    mnemonic: str
    operands: List[str]

    def __init__(self, inst_text: str) -> 'Instruction':
        return None

class ExecutionMode(StrEnum):
    M = auto()
    S = auto()
    U = auto()

# note: having all side effects subclass this same superclass turned out to be
# kind of stupid, since they share almost nothing.
# This should have been refactored out
class SideEffect:
    placeholder: str

class MemoryOperation(StrEnum):
    R = auto()
    W = auto()
    X = auto()

#this is kind of hacky and manual, but it does ensure we get an error when a size appears which
# isn't what we expected...
MEM_VAL_LEN_TO_SIZE = {
    1:1,   #tag
    4:1,   #byte
    6:2,   #half-word
    10:4,  #word
    18:8, #double-word
    34:16  #capability
}

class RegisterSideEffect():
    reg: int
    tag: bool
    seal: bool
    uninit: bool
    perms: int
    otype: int
    address: int
    base: int
    length: int
    
    def __init__(self, reg: int, body: str) -> None:
        self.reg = reg
        body_match = REG_BODY_REGEX.match(body)
        if body_match is None:
            return
        for key,val in body_match.groupdict().items():
            if key in ['tag', 'seal', 'uninit']:
                setattr(self, key, bool(val))
            else:
                setattr(self, key, int(val, base=16))
                
    @property
    def top(self) -> int:
        return self.base + self.length

REG_FMT_REGEX = re.compile(r"(?:.(?P<reg>\d{1,2})) <-  (?P<body>[\w\d :]*)")
REG_BODY_REGEX = re.compile(r"(?:t:(?P<tag>\d)) (?:s:(?P<seal>\d)) (?:uninit:(?P<uninit>\d)) (?:perms:(?P<perms>0x[A-F\d]+)) (?:type:(?P<otype>0x[A-F\d]+)) (?:address:(?P<address>0x[A-F\d]+)) (?:base:(?P<base>0x[A-F\d]+)) (?:length:(?P<length>0x[A-F\d]+))")
def parse_all_register(text_tick: TickText) -> Iterator[RegisterSideEffect]:
    for match in REG_FMT_REGEX.finditer(text_tick.reg):
        # for now only match stack
        reg = int(match.group('reg'))
        if reg != 2: 
            continue
        yield RegisterSideEffect(reg, match.group('body'))        

@dataclass
class MemorySideEffect(SideEffect):
    op: MemoryOperation
    addr: int
    size: int
    tag: Optional[Tuple[int, bool]] = None

    def from_matches(mem_match: re.Match, tag_match: re.Match = None) -> 'MemorySideEffect':
        size = MEM_VAL_LEN_TO_SIZE[len(mem_match.group('val'))]
        if tag_match is None: tag = None
        else: tag = (int(tag_match.group('addr'),16), bool(int(tag_match.group('val'))))
        if mem_match.group('op') is None: op = MemoryOperation.W
        else: op = MemoryOperation[mem_match.group('op')]
        return MemorySideEffect(op, int(mem_match.group('addr'),16), size, tag)
    
    def end_addr(self: 'MemorySideEffect') -> int:
        return self.addr + self.size

def is_instruction_fetch(side_effect: SideEffect) -> bool:
    return (isinstance(side_effect, MemorySideEffect) 
            and side_effect.op is MemoryOperation.X)

def is_data_memop(side_effect: SideEffect) -> bool:
    return (isinstance(side_effect, MemorySideEffect) 
        and side_effect.op is not MemoryOperation.X)

MEM_REGEX = re.compile(r"(?P<type>mem|tag)\[(?:(?P<op>[RX]),){0,1}(?P<addr>0x[0-9A-F]*)\] (?:->|<-) (?P<val>0x[0-9A-F]*|[01])")
def parse_all_memory(text_tick: TickText) -> Iterator[MemorySideEffect]:
    all_memory_matches = list(chain(
        MEM_REGEX.finditer(text_tick.instmem),
        MEM_REGEX.finditer(text_tick.readmem),
        MEM_REGEX.finditer(text_tick.writemem)
    ))
    
    for (index, match) in enumerate(all_memory_matches):
        if match.group('type') == "tag": continue
        tag_match = None
        if all_memory_matches[index - 1].group('type') == "tag":
            tag_match = all_memory_matches[index - 1]
        yield MemorySideEffect.from_matches(match, tag_match)

class Tick:
    _index: int
    _mode: ExecutionMode
    _inst: Instruction
    _side_effects: List[SideEffect]
    _register_side_effects: List[RegisterSideEffect]

    def __init__(self, index: int, 
                 mode: ExecutionMode, 
                 side_effects: List[SideEffect],
                 register_side_effects: List[RegisterSideEffect]
                 ) -> None:
        self._index = index
        self._mode = mode
        self._side_effects = side_effects
        self._register_side_effects = register_side_effects
        
    @classmethod
    def from_texttick(cls, text_tick: TickText) -> "Tick":
        index = int(text_tick.index)
        mode = ExecutionMode[text_tick.mode]
        side_effects = list(parse_all_memory(text_tick))
        register_side_effects = list(parse_all_register(text_tick))
        return cls(index, mode, side_effects, register_side_effects)
    
    @classmethod
    def final_tick(cls) -> "Tick":
        return cls(-1000, None, [], [])
    
    @property
    def index(self) -> int:
        if not self.is_final:
            return self._index
        else:
            raise ValueError
    
    @property
    def mode(self) -> ExecutionMode:
        if not self.is_final:
            return self._mode
        else:
            raise ValueError
    
    @property
    def side_effects(self) -> List[SideEffect]:
        if not self.is_final:
            return self._side_effects
        else:
            raise ValueError
            
    @side_effects.setter
    def side_effects(self, side_effects: List[SideEffect]) -> None:
        if not self.is_final:
            self._side_effects = side_effects
        else:
            raise ValueError
            
    @property
    def register_side_effects(self) -> List[RegisterSideEffect]:
        if not self.is_final:
            return self._register_side_effects
        else:
            raise ValueError
        
    def get_assignment_for_reg(self, reg: int) -> Optional[RegisterSideEffect]:
        if self.is_final:
            raise ValueError
        return next((regSE for regSE in self.register_side_effects if regSE.reg == reg), None)
            
    @property
    def is_final(self) -> bool:
        return self._index == -1000
    

# expects fetches to be sorted
def fetches_are_contiguous(fetches: List[SideEffect]) -> bool:
    return all(
        fetch_a.end_addr() == fetch_b.addr for (fetch_a,fetch_b)
        in zip(fetches[:-1], fetches[1:])
    )

CACHE_LINE_SIZE=64
def fetches_straddle_cache_line(fetches: List[SideEffect]) -> bool:
    return any(
        fetch.addr % CACHE_LINE_SIZE > fetch.end_addr() % CACHE_LINE_SIZE
        for fetch in fetches
    )

def fuse_instruction_fetches(tick: Tick) -> Tick:
    instruction_fetches = [se for se in tick.side_effects 
                           if is_instruction_fetch(se)]
    instruction_fetches.sort(key=lambda fetch: fetch.addr)
    assert(fetches_are_contiguous(instruction_fetches))
    
    if fetches_straddle_cache_line(instruction_fetches): return tick
    
    tick.side_effects = list(filter(
        lambda side_effect: side_effect not in instruction_fetches, 
        tick.side_effects))
    instruction_fetches[0].size = (instruction_fetches[-1].end_addr() 
                                    - instruction_fetches[0].addr)
    tick.side_effects += [instruction_fetches[0]]
    return tick

def parse_ticks(input: BytesIO, stats_output: StringIO, count_cshrink: bool, **kwargs: int) -> Generator[Tick]:
    return (Tick.from_texttick(tt) for tt in parse_file_to_text(input, count_cshrink, stats_output))

# create a queue and spawn this function into its own thread
def parse_ticks_into_queue(input: BytesIO, queue: Queue[Tick]) -> None:
    for ticktext in parse_file_to_text(input):
        queue.put(Tick.from_texttick(ticktext))
    queue.put(Tick.final_tick())
    return