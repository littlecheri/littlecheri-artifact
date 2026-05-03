# Sail Parser

[![PyPI](https://img.shields.io/pypi/v/sail-parser.svg)][pypi_]
[![Status](https://img.shields.io/pypi/status/sail-parser.svg)][status]
[![Python Version](https://img.shields.io/pypi/pyversions/sail-parser)][python version]
[![License](https://img.shields.io/pypi/l/sail-parser)][license]

[![Read the documentation at https://sail-parser.readthedocs.io/](https://img.shields.io/readthedocs/sail-parser/latest.svg?label=Read%20the%20Docs)][read the docs]
[![Tests](https://github.com/stormeuh/sail-parser/workflows/Tests/badge.svg)][tests]
[![Codecov](https://codecov.io/gh/stormeuh/sail-parser/branch/main/graph/badge.svg)][codecov]

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)][pre-commit]
[![Black](https://img.shields.io/badge/code%20style-black-000000.svg)][black]

[pypi_]: https://pypi.org/project/sail-parser/
[status]: https://pypi.org/project/sail-parser/
[python version]: https://pypi.org/project/sail-parser
[read the docs]: https://sail-parser.readthedocs.io/
[tests]: https://github.com/stormeuh/sail-parser/actions?workflow=Tests
[codecov]: https://app.codecov.io/gh/stormeuh/sail-parser
[pre-commit]: https://github.com/pre-commit/pre-commit
[black]: https://github.com/psf/black

## Regex scratchbook

```
(?'instmem'(?>mem\[[RWX],0x[0-9A-F]{16}\] -> 0x[0-9A-F]{4}\n){2})(?'inst'\[[0-9]\] \[[MSU]\]: 0x[0-9A-F]{16} \(0x[0-9A-F]{8}\) )
(?'instmem'(?>.*\n){2})(?'inst'\[[0-9]*\] \[[MSU]\]: 0x[0-9A-F]{16} \(0x[0-9A-F]{8}\) (?'asm'.*)\n(?'datamem'(?>(?>tag|mem)\[[RWX],0x[0-9A-F]{16}\].*\n)*)(?'reg'(?>.\d{1,2} <- .*)*))\n\n
(?P<instmem>(?:.*\n){2})(?P<inst>\[[0-9]*\] \[[MSU]\]: 0x[0-9A-F]{16} \(0x[0-9A-F]{8}\) (?P<asm>.*)\n(?P<datamem>(?:(?:tag|mem)\[[RWX],0x[0-9A-F]{16}\].*\n)*))(?P<reg>(?:.\d{1,2} <- .*\n)*)(?P<htif>(?:htif.*\n.*\n)?)\n
```

## Quirks related to Sail-Gem5 interaction

Instruction sequence number is encoded in the `id` field of instruction packets.

Producing the trace of instruction fetches is a bit weird because sail is not emulating interactions with caches but gem5 assumes the trace does.
So far two fixes have been implemented for this:
- Sail splits instruction fetches into 2 byte chunks (to do with something PMP related). 
This is terrible for performance on gem5, so by default these fetches are fused back together so there is one fetch per instruction.
- For some reason sometimes instruction fetches straddle a 64-byte alignment barrier.
Gem5 disallows this because it expects cache requests to happen within the same cache line.
In this case the fetches are not fused.

## Installation

You can install _Sail Parser_ via [pip] from [PyPI]:

```console
$ pip install sail-parser
```

## Usage

Please see the [Command-line Reference] for details.

## Contributing

Contributions are very welcome.
To learn more, see the [Contributor Guide].

## License

Distributed under the terms of the [MIT license][license],
_Sail Parser_ is free and open source software.

## Issues

If you encounter any problems,
please [file an issue] along with a detailed description.

## Credits

This project was generated from [@cjolowicz]'s [Hypermodern Python Cookiecutter] template.

[@cjolowicz]: https://github.com/cjolowicz
[pypi]: https://pypi.org/
[hypermodern python cookiecutter]: https://github.com/cjolowicz/cookiecutter-hypermodern-python
[file an issue]: https://github.com/stormeuh/sail-parser/issues
[pip]: https://pip.pypa.io/

<!-- github-only -->

[license]: https://github.com/stormeuh/sail-parser/blob/main/LICENSE
[contributor guide]: https://github.com/stormeuh/sail-parser/blob/main/CONTRIBUTING.md
[command-line reference]: https://sail-parser.readthedocs.io/en/latest/usage.html
