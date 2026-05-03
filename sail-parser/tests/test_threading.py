from importlib.resources import as_file, files

import pytest
from click.testing import CliRunner

import tests.output
import tests.resources
from sail_parser.__main__ import main
import yappi
import sys
from io import StringIO
import sail_parser.parsing

@pytest.fixture
def runner() -> CliRunner:
    """Fixture for invoking command-line interfaces."""
    return CliRunner()

def print_yappi_stats() -> None:
    # retrieve thread stats by their thread id (given by yappi)
    print("Thread stats:")
    threads = yappi.get_thread_stats()
    for thread in threads:
        print(
            "Function stats for (%s) (%d)" % (thread.name, thread.id)
        )  # it is the Thread.__class__.__name__
        yappi.get_func_stats(ctx_id=thread.id).print_all(columns={
            0: ("name", 80),
            1: ("ncall", 10),
            2: ("tsub", 8),
            3: ("ttot", 8),
            4: ("tavg", 8)
        })

def test_short(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('short_testcase.out')) as input:
        with as_file(files(tests.output).joinpath('short_testcase_data.proto')) as data_output:
            with as_file(files(tests.output).joinpath('short_testcase_inst.proto')) as inst_output:
                result = runner.invoke(main, ["output-proto-threaded", f"{input}", f"{data_output}", f"{inst_output}"])
    assert(result.exit_code == 0)

def test_output_proto(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as input:
        with as_file(files(tests.output).joinpath('testcase0_data.proto')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_inst.proto')) as inst_output:
                result = runner.invoke(main, ["output-proto-threaded", f"{input}", f"{data_output}", f"{inst_output}"])
    assert(result.exit_code == 0)

def test_output_proto_compressed(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as input:
        with as_file(files(tests.output).joinpath('testcase0_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_inst.proto.gz')) as inst_output:
                yappi.start()
                result = runner.invoke(main, ["output-proto-threaded", f"{input}", f"{data_output}", f"{inst_output}", "-c", "--queue-size", "4096"])
                yappi.stop()
                print_yappi_stats()
    assert(result.exit_code == 0)

@pytest.mark.parametrize("buffer_size_kib", [2,4,8,16,32,64])
def test_buffer_sizes(runner: CliRunner, monkeypatch, buffer_size_kib) -> None: # type: ignore
    with as_file(files(tests.resources).joinpath('testcase0.out')) as input:
        with as_file(files(tests.output).joinpath('testcase0_data.proto.gz')) as data_output:
            with as_file(files(tests.output).joinpath('testcase0_inst.proto.gz')) as inst_output:
                monkeypatch.setattr(sail_parser.parsing, "MAX_BUFFER_SIZE", 1024*buffer_size_kib)
                result = runner.invoke(main, ["output-proto-threaded", f"{input}", f"{data_output}", f"{inst_output}", "-c", "--queue-size", "4096"])
    assert(result.exit_code == 0)