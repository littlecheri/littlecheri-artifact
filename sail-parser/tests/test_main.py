"""Test cases for the __main__ module."""
import pytest
from click.testing import CliRunner
from importlib.resources import files, as_file
from os import system as shell

from sail_parser import __main__
import tests.resources

@pytest.fixture
def runner() -> CliRunner:
    """Fixture for invoking command-line interfaces."""
    return CliRunner()


def test_simple(runner: CliRunner) -> None:
    with as_file(files(tests.resources).joinpath('testcase0.out')) as file:
        result = runner.invoke(__main__.main, f"{file}")
    assert(result.exit_code == 0)
    
# def test_input_from_named_pipe(runner: CliRunner) -> None:
#     with as_file(files(tests.resources).joinpath('named_pipe.pipe')) as pipe:
#         # with as_file(files(tests.resources).joinpath('testcase0.out')) as file:
#         #     shell(f"cat {file} > {pipe}")
#         result = runner.invoke(__main__.main, f"output-proto -c {pipe} /dev/null /dev/null")
#     assert(result.exit_code == 0)