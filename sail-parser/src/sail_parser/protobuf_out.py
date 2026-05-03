import sail_parser.packet_pb2 as packet
import sail_parser.inst_dep_record_pb2 as data_packet
import click
from .tick import (
    Tick, 
    MemoryOperation, 
    MemorySideEffect, 
    SideEffect, 
    is_instruction_fetch, 
    is_data_memop,
    fuse_instruction_fetches
)
from .parsing import parse_file_to_text
from .stack_pressure import StackPressureTracker
from typing import List, Iterable, Callable, Dict, cast, Generator
from io import BytesIO, StringIO
import sail_parser.lib.protolib as protolib
import gzip
from multiprocessing.queues import Queue


DATA_MEMOP_TO_RECORDTYPE = {
    MemoryOperation.R: data_packet.InstDepRecord.RecordType.LOAD,
    MemoryOperation.W: data_packet.InstDepRecord.RecordType.STORE
}
INST_MEMOP_TO_CMD = {
    MemoryOperation.X: 1
}

OBJ_ID = "test"
TICK_FREQ = 1000000000
TICKS_PER_INST = 2500
INST_DEP_COMP_DELAY = 0
FIRST_TICK = 5

FETCH_TRACE_FILE_HEADER = packet.PacketHeader()
FETCH_TRACE_FILE_HEADER.obj_id = OBJ_ID
FETCH_TRACE_FILE_HEADER.tick_freq=TICK_FREQ

DATA_TRACE_FILE_HEADER = data_packet.InstDepRecordHeader()
DATA_TRACE_FILE_HEADER.obj_id = OBJ_ID
DATA_TRACE_FILE_HEADER.tick_freq = TICK_FREQ
DATA_TRACE_FILE_HEADER.window_size = 1

def comp_node_from_tick(tick: Tick) -> data_packet.InstDepRecord:
    out_packet = data_packet.InstDepRecord()
    out_packet.seq_num = tick.index
    out_packet.type = data_packet.InstDepRecord.RecordType.COMP
    out_packet.comp_delay = INST_DEP_COMP_DELAY
    if not tick.index == FIRST_TICK:
        out_packet.reg_dep.append(tick.index - 1)
    return out_packet

def packets_from_tick(tick: Tick,
                      filter: Callable[[SideEffect], bool],
                      cmd_map: Dict[MemoryOperation, int]) -> List[packet.Packet]:
    output_packets = []
    memevents = (se for se in tick.side_effects if filter(se))
    for memevent in memevents:
        out_packet = packet.Packet()
        out_packet.pkt_id = tick.index
        out_packet.tick = tick.index * TICKS_PER_INST
        out_packet.cmd = cmd_map[memevent.op]
        out_packet.addr = memevent.addr
        out_packet.size = memevent.size
        out_packet.pc = memevent.addr
        output_packets.append(out_packet)
    return output_packets

def data_packets_from_tick(tick: Tick) -> List[data_packet.InstDepRecord]:
    memevents = (se for se in tick.side_effects if is_data_memop(se))
    
    output_packets = []
    for memevent in memevents:
        out_packet = data_packet.InstDepRecord()
        out_packet.seq_num = tick.index
        out_packet.type = DATA_MEMOP_TO_RECORDTYPE[memevent.op]
        out_packet.p_addr = memevent.addr
        out_packet.size = memevent.size
        out_packet.comp_delay = INST_DEP_COMP_DELAY
        if not tick.index == FIRST_TICK:
            out_packet.reg_dep.append(tick.index - 1)
        output_packets.append(out_packet)
    # if len(output_packets) == 0: return [comp_node_from_tick(tick)]
    else: return output_packets

def inst_packets_from_tick(tick: Tick) -> List[packet.Packet]:
    tick = fuse_instruction_fetches(tick)
    return packets_from_tick(tick, is_instruction_fetch, INST_MEMOP_TO_CMD)

def packets_from_ticks[P](ticks: List[Tick],
                       packets_from_tick_fn: Callable[[Tick], List[P]]) -> Iterable[P]:
    for t in ticks:
        yield from packets_from_tick_fn(t)

def write_packets_to_file[P,H](packets: Iterable[P], file: BytesIO) -> None:
    for p in packets:
        protolib.encodeMessage(file, p)

def initialize_protobuf_file[H](file: BytesIO, header: H) -> None:
    file.write(b'gem5')
    protolib.encodeMessage(file, header)

def prepare_output_files(data_output_arg: BytesIO, 
                         inst_output_arg: BytesIO, 
                         compress: bool) -> (BytesIO, BytesIO):
    data_out : BytesIO = data_output_arg
    inst_out : BytesIO = inst_output_arg
    if compress:
        data_out = gzip.GzipFile(fileobj=data_out, mode='wb')
        inst_out = gzip.GzipFile(fileobj=inst_out, mode='wb')
    
    initialize_protobuf_file(data_out, DATA_TRACE_FILE_HEADER)
    initialize_protobuf_file(inst_out, FETCH_TRACE_FILE_HEADER)
    
    return (data_out, inst_out)

def _output_proto(ticks: Generator[Tick],
                  data_output_arg: BytesIO,
                  inst_output_arg: BytesIO,
                  stats_output: StringIO,
                  compress: bool,
                  **kwargs: int) -> None:
    global TICKS_PER_INST
    TICKS_PER_INST = kwargs["ticks_per_inst"]
    for _ in zip(range(FIRST_TICK), ticks): 
        continue # skip until FIRST_TICK
    
    data_out, inst_out = prepare_output_files(data_output_arg, inst_output_arg, compress)
    
    data_packet_counter = 0
    inst_packet_counter = 0
    stack_pressure = StackPressureTracker()
    
    for tick in ticks:
        data_packets = data_packets_from_tick(tick)
        data_packet_counter += len(data_packets)
        write_packets_to_file(data_packets, data_out)
        
        inst_packets = inst_packets_from_tick(tick)
        inst_packet_counter += len(inst_packets)
        write_packets_to_file(inst_packets, inst_out)
        stack_pressure.process_tick(tick)
    
    print(f"Total data packets written: {data_packet_counter}")
    print(f"Total inst packets written: {inst_packet_counter}")
    stack_pressure.summarize(stats_output)

def tick_generator_from_queue(ticks: Queue[Tick]) -> Generator[Tick]:
    tick = ticks.get()
    while not tick.is_final:
        yield tick
        tick = ticks.get()

def _output_proto_from_queue(ticks: Queue[Tick],
                             data_output_arg: BytesIO,
                             inst_output_arg: BytesIO,
                             compress: bool,
                             **kwargs: int) -> None:
    tick_generator = tick_generator_from_queue(ticks)
    _output_proto(tick_generator, 
                  data_output_arg, inst_output_arg,
                  compress, **kwargs)