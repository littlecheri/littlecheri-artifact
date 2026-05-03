"""Test cases for the __main__ module."""
import pytest
from click.testing import CliRunner
from importlib.resources import files, as_file
from mmap import mmap, ACCESS_READ
from io import open

from sail_parser.parsing import parse_file_to_text
from sail_parser.tick import Tick
from sail_parser.protobuf_out import packets_from_ticks, data_packets_from_tick, inst_packets_from_tick, _output_proto
from sail_parser.__main__ import main
import tests.resources
import tests.output

def test_ticks_to_packets() -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as file:
        with open(file, mode="r", encoding="utf8") as file_handle:
            with mmap(file_handle.fileno(), length=0, access=ACCESS_READ) as mmap_handle:
                ticks = [Tick(tt) for tt in parse_file_to_text(mmap_handle)]
    data_packets = list(packets_from_ticks(ticks, data_packets_from_tick))
    inst_packets = list(packets_from_ticks(ticks, inst_packets_from_tick))
    return

@pytest.fixture
def runner() -> CliRunner:
    """Fixture for invoking command-line interfaces."""
    return CliRunner()


def test_output_proto(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as input:
        with as_file(files(tests.output).joinpath('testcase0_data.proto')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_inst.proto')) as inst_output:
                result = runner.invoke(main, ["output-proto", f"{input}", f"{data_output}", f"{inst_output}"])
    assert(result.exit_code == 0)

def test_output_proto_compressed(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as input:
        with as_file(files(tests.output).joinpath('testcase0_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_inst.proto.gz')) as inst_output:
                result = runner.invoke(main, ["output-proto", f"{input}", f"{data_output}", f"{inst_output}", "-c", "--count-cshrink"])
    assert(result.exit_code == 0)

def test_output_proto_compressed_coremark_uninit_none(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('coremark_16K_uninit_none_100000.sail.trace')) as trace_input_path:
        with as_file(files(tests.output).joinpath('coremark_16K_uninit_none_100000_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('coremark_16K_uninit_none_100000_inst.proto.gz')) as inst_output:
                with as_file(files(tests.output).joinpath('coremark_16K_uninit_none_100000_stats.txt')) as stats_output:
                    result = runner.invoke(main, input=open(trace_input_path, "rb"), args=["output-proto", "-", f"{data_output}", f"{inst_output}", f"{stats_output}", "-c", "--count-cshrink"])
    assert(result.exit_code == 0)
    
def test_output_proto_compressed_libcbench(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('libc-bench_16K_trampoline_100000.sail.trace')) as trace_input_path:
        with as_file(files(tests.output).joinpath('libc-bench_16K_trampoline_100000_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('libc-bench_16K_trampoline_100000_inst.proto.gz')) as inst_output:
                with as_file(files(tests.output).joinpath('libc-bench_16K_trampoline_100000_stats.txt')) as stats_output:
                    result = runner.invoke(main, input=open(trace_input_path, "rb"), args=["output-proto", "-", f"{data_output}", f"{inst_output}", f"{stats_output}", "-c", "--count-cshrink"])
    assert(result.exit_code == 0)
    
def test_snakemake_out(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('testcase0_uninit_trampoline.sail.trace')) as trace_input_path:
        with as_file(files(tests.output).joinpath('testcase0_uninit_trampoline_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_uninit_trampoline_inst.proto.gz')) as inst_output:
                with as_file(files(tests.output).joinpath('libc-bench_16K_trampoline_100000_stats.txt')) as stats_output:
                    result = runner.invoke(main, input=open(trace_input_path, "rb"), args=["output-proto", "-", f"{data_output}", f"{inst_output}", f"{stats_output}", "-c", "--count-cshrink"])
    assert(result.exit_code == 0)
    
def test_integration_off_by_100(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('coremark_16K_uninit_none_off_by_100.sail.trace')) as trace_input_path:
        with as_file(files(tests.output).joinpath('testcase0_uninit_trampoline_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_uninit_trampoline_inst.proto.gz')) as inst_output:
                with as_file(files(tests.output).joinpath('coremark_16K_uninit_none_off_by_100_stats.txt')) as stats_output:
                    result = runner.invoke(main, input=open(trace_input_path, "rb"), args=["output-proto", "-", f"{data_output}", f"{inst_output}", f"{stats_output}", "-c", "--count-cshrink"])
    assert(result.exit_code == 0)