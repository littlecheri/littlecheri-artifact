# LittleCHERI artifact

## Artifact Structure

This artifact consists of patches on publicly available code repositories, and sources to custom tools.
See usage on where to start.

### Patches

Patches from the `patches` folder can be applied onto the repo at the given URL, at the given commit hash or tag.

| Program          | Patch base hash/tag                      | Repo URL                                        |
| ---------------- | ---------------------------------------- | ----------------------------------------------- |
| LLVM             | 578ea4f7ef67d589f0ca7d10ec9e383333567421 | https://github.com/CTSRD-CHERI/llvm-project     |
| Gem5             | v24.1.0.1 Hotfix Release                 | https://github.com/gem5/gem5                    |
| newlib           | e9065ae                                  | https://github.com/CTSRD-CHERI/newlib           |
| libgloss         | c5fe019a9a3c6e6cfff4a42d63ce5d0975556b63 | https://sourceware.org/git/newlib-cygwin        |
| coremark         | 6864c50                                  | https://github.com/GaloisInc/BESSPIN-coremark   |
| libc-bench       | b6b2ce5                                  | https://git.musl-libc.org/git/libc-bench        |
| sail-cheri-riscv | c93d5ef                                  | https://github.com/CTSRD-CHERI/sail-cheri-riscv |
| sail-riscv       | 9602e3a (submodule of sail-cheri-riscv)  | https://github.com/rems-project/sail-riscv      |

### Sources

| Program                   | Purpose                                                                                                                                                           |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `benchmark-runner`        | Build and run benchmarks, including compilers and libraries.                                                                                                      |
| `sail-parser`             | Using sail traces, produces gem5 traces and useful statistics.                                                                                                    |
| `random-callstack-ubench` | Microbenchmark to test fine-grained compartmentalization with deep callstacks.                                                                                    |
| `result_processing.ods`   | Spreadsheet used to process results into graphs. Created with Google Sheets, so unfortunately non-functional when exported, our apologies for this inconvenience. |

## Usage

### Using the Dockerfile

Install Docker, then build the image using `docker build -t littlecheri .`.
Finally, spin up a container with `docker run --rm -it littlecheri`, and skip to "Building and running the benchmarks".

### Configuring the environment locally

Clone the repositories listed under patches (keep in mind sail-riscv is a submodule of sail-cheri-riscv, but has its own patch).
Install `sail-parser` using `pipx` with `pipx install <path_to>/sail-parser`.
Build `gem5` using `scons build/RISCV/gem5.opt -j $(nproc)`.
Build the CHERI-RISC-V emulator using `make csim` in `sail-cheri-riscv`.

All other tools will be built by the benchmark runner itself.
Configure the paths to their sources in `benchmark-runner/config/local_config.yaml`.

### Building and running the benchmarks

We use the `snakemake` tool as a build script for building and running benchmarks.
Before using it, activate its conda environment with `conda activate snakemake`.
The folder `benchmark-runner/runs/2026-04-23_12-38-05` contains the results as published in the paper, as well as the seed used to run the `random-callstack-ubench`.
Change directory into the `benchmark-runner` folder and run `snakemake --cores $(nproc) runs/2026-04-23_12-38-05/results.csv --force` to re-run those results.

Alternatively, run `snakemake --cores $(nproc)` to start a completely new run.
Keep in mind the `random-callstack-ubench` results will vary slightly due to the different seed.

### Processing `results.csv`

The `results.csv` file contains the raw run results, where the following table shows the correspondence between columns in the CSV and quantities being measured.

| Quantity              | Column Key                         |
| --------------------- | ---------------------------------- |
| Gem5 Cycles           | `simTicks`                         |
| Instructions          | `sail.Instructions`                |
| Stack Pressure        | `guest.stack.pressure`             |
| Total Stack Allocated | `guest.stack.cumulativeAllocation` |
| Binary Size           | `binary_size`                      |
| Secure Calls          | `secureCalls`                      |

The CSV file was then imported verbatim into the "Data" tab of our Google Sheets document, which was exported as `results_processing.ods`.
Unfortunately, exporting breaks some functionality, which is important to the functioning of this specific spreadsheet.
Specifically, the Google Sheets `QUERY` function does not have a one-to-one equivalent in the ODS or XLSX formats.