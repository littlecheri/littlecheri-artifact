from dataclasses import dataclass
import re
from typing import Generator
import click
from io import BytesIO, StringIO
from sail_parser.lib.ringbuffer import RingBuffer

# still missing: exceptions, see inst 95984
TICK_REGEX = re.compile(rb"(?P<instmem>(?:mem\[(?:[X],)?0x[\dA-F]{16}\] -> 0x[\dA-F]{4}\n){1,2})"
                        rb"\[(?P<index>[0-9]+)\] \[(?P<mode>[MSU])\]: (?P<inst>0x[0-9A-F]{16} \(0x[0-9A-F]{4,8}\) (?:.*))\n"
                        rb"(?P<readmem>(?:(?:tag|mem)\[(?:[R],)?0x[\dA-F]{16}\] -> .+?\n)*)"
                        rb"(?P<trap>(?:.+?\n(?:trapping from [MSU] to [MSU] to handle .*?\n)(?:handling.+?\n))??)"
                        rb"(?P<csr>(?:CSR.*?\n)*)"
                        rb"(?P<scr>(?:.*c (?:<-|->) .*?\n)*)"
                        rb"(?P<writemem>(?:tag\[0x[0-9A-F]{16}\] <- \d\nmem\[0x[0-9A-F]{16}\] <- 0x[0-9A-F]{1,32}\n)?)"
                        rb"(?P<reg>(?:.\d{1,2} <- .*\n)*)"
                        rb"(?P<htif>(?:htif.*\n)*)")

@dataclass
class TickText:
    index: str
    mode: str
    instmem: str
    inst: str
    readmem: str
    writemem: str
    reg: str
    htif: str
    csr: str
    scr: str
    trap: str

def summarize(output: StringIO, cshrink_count: int, tick_count: int) -> None:
    output.write(f"secureCalls    {cshrink_count}    # Amount of secure calls made during the benchmark\n")
    output.write(f"sail.ticks         {tick_count}    # Number of ticks parsed from sail trace\n")

MAX_BUFFER_SIZE = 1024*32 # 32 KiB buffer
def parse_file_to_text(input: BytesIO, count_cshrink: bool, stats_output: StringIO) -> Generator[TickText, None, None]:
    tick_counter = 0
    cshrink_count = 0
    buffer : RingBuffer = RingBuffer(input.read(MAX_BUFFER_SIZE))
    while True:
        tick_match = TICK_REGEX.search(buffer.get())
        if tick_match is None:
            break
        # remove match from buffer
        if not buffer.extend(input.read(tick_match.end())):
            # if at end of file, advance ringbuffer instead of writing
            buffer.advance(tick_match.end())
        match_groups_string_dict = {gid: val.decode('utf8') for gid, val in tick_match.groupdict().items()}
        tick_counter += 1
        if count_cshrink:
            ret_tick = TickText(**match_groups_string_dict)
            if ret_tick.inst.find("0x0001315B") > -1: 
                cshrink_count += 1
            yield ret_tick
        else:
            yield TickText(**match_groups_string_dict)
    summarize(stats_output, cshrink_count, tick_counter)