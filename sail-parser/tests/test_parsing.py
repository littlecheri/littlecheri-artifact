"""Test cases for the __main__ module."""
import pytest
from click.testing import CliRunner
from importlib.resources import files, as_file
from mmap import mmap, ACCESS_READ

from sail_parser.parsing import parse_file_to_text
from sail_parser.tick import Tick
import tests.resources

def test_indices_match() -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as file:
        with open(file, mode="r", encoding="utf8") as file_handle:
            with mmap(file_handle.fileno(), length=0, access=ACCESS_READ) as mmap_handle:
                tts = [tt for tt in parse_file_to_text(mmap_handle)]
    for array_index in range(len(tts)):
        assert(array_index == int(tts[array_index].index))
    return

def test_indices_match_snakemake() -> None:
    with as_file(files(tests.resources).joinpath('testcase0_uninit_trampoline.sail.trace')) as file:
        with open(file, mode="r", encoding="utf8") as file_handle:
            with mmap(file_handle.fileno(), length=0, access=ACCESS_READ) as mmap_handle:
                tts = [tt for tt in parse_file_to_text(mmap_handle)]
    assert(len(tts) == 91595)
    for array_index in range(len(tts)):
        assert(array_index == int(tts[array_index].index))
    return

def test_construct_ticks() -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as file:
        with open(file, mode="r", encoding="utf8") as file_handle:
            with mmap(file_handle.fileno(), length=0, access=ACCESS_READ) as mmap_handle:
                ticks = [Tick(tt) for tt in parse_file_to_text(mmap_handle)]
    for t in ticks:
        assert(len(t.side_effects) > 0)
