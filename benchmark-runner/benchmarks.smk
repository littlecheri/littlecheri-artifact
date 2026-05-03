wildcard_constraints:
    instrumentation=r"(-instrumented)?",
    stack_size="[0-9]+[KM]",
    run_id=r"[0-9_\-]+|manual"

# Utility

def translate_sysroot(wildcards):
    match wildcards.revoc:
        case "none":
            return "none"
        case "uninit":
            if wildcards.reserve == "reserve":
                if wildcards.reducecsr == "reduce":
                    return "uninitreservereduce"
                else:
                    return "uninitreserve"
            else:
                return "uninit" 

def translate_revoc(wildcards):
    assert(not (wildcards.revoc == "none" and wildcards.reserve == "reserve"))
    if (wildcards.revoc == "uninit"):
        if (wildcards.reserve == "reserve"): return "uninitreserve"
        else: return "uninit"
    else: return "none"

def benchmark_common_args(w, output):
    return [
        f"OPATH=$(realpath {subpath(output.binary, parent=True)})" + "/",
        "SYSROOT_DIR=$(realpath sysroots/{}/riscv64-unknown-elf)".format(translate_sysroot(w)),
        "SDK_BIN=$(realpath sysroots/{}/bin)/".format(translate_sysroot(w)),
        "REVOC={}".format(translate_revoc(w)),
        "CLEAR={}".format(w.clearregs),
        "LINKER_SCRIPT=sail_{}.ld".format(w.stack_size),
        "CHERI_ENCAP={}".format(w.encap),
        "REDUCECSR={}".format(w.reducecsr),
        "INSTRUMENT={}".format(1 if "-instrumented" in w else 0)
    ]

# Building

rule build_coremark:
    input:
        lambda w: "sysroots/{}/complete".format(translate_sysroot(w)),
    output:
        binary="<binary_dir>/coremark{instrumentation}.elf",
    log:
        "<binary_dir>/build-coremark{instrumentation}.log"
    params:
        make_args=lambda w, output: (benchmark_common_args(w,output) + [
            "PORT_DIR=riscv-semihost",
            "TOOLCHAIN=LLVM",
            "CHERI=1",
            "ITERATIONS=100",
        ] + (['XCFLAGS="-DWRAP_UNINIT -mllvm -cheri-uninit-stack-split=false"'] if False and w.encap != "none" else []))
    shell: "echo {params.make_args} && " + f"make -C {config['sources']['coremark']} " + "{params.make_args} &> {log}"

rule build_libc_bench:
    input:
        lambda w: "sysroots/{}/complete".format(translate_sysroot(w)),
        sources=config['sources']['libc-bench']['dir'],
        source_files=expand("{dir}/{file}", dir=config['sources']['libc-bench']['dir'], file=config['sources']['libc-bench']['files']),
        makefile=f"{config['sources']['libc-bench']['dir']}/Makefile"
    output:
        binary="<binary_dir>/libc-bench{instrumentation}.elf"
    log:
        "<binary_dir>/build-libc-bench{instrumentation}.log"
    params:
        make_args=lambda w, output: benchmark_common_args(w,output) + (["INSTRUMENT=1"] if w.instrumentation != "" else [])
    shell: "make -C {input.sources} {params.make_args} clean $(realpath {output.binary}) &> {log}"

rule build_random_callstack_ubench:
    input:
        lambda w: "sysroots/{}/complete".format(translate_sysroot(w)),
        sources=config['sources']['random-callstack-ubench'],
        makefile=f"{config['sources']['random-callstack-ubench']}/Makefile",
        source=config['sources']['random-callstack-ubench']+"/random-callstack-ubench.c"
    output:
        binary="<binary_dir>/random-callstack-ubench{instrumentation}.elf"
    log:
        "<binary_dir>/random-callstack-ubench{instrumentation}.log"
    params:
        make_args=lambda w, output: 
            benchmark_common_args(w,output) 
            + (["INSTRUMENT=1"] if "instrumentation" in w and w.instrumentation != "" else [])
    shell:
        "make -C {input.sources} {params.make_args} $(realpath {output}) &> {log}"

use rule build_random_callstack_ubench as build_random_callstack_bench_custom_alloc with:
    output:
        binary="<binary_dir>/random-callstack-ubench{alloc}.elf"
    log:
        "<binary_dir>/random-callstack-ubench{alloc}.log"
    wildcard_constraints: 
        alloc=r"\+large-alloc|\+small-alloc",

# Custom regular runners

use rule run_sail_output_gem5 as run_libc_bench_output_gem5 with:
    wildcard_constraints:
        benchmark="libc-bench",
        libcbench_part="|".join(config["libc-bench_parts"])
    pathvars:
        trace_file_prefix="<parent_dir>/traces/{benchmark}_{libcbench_part}_{stack_size}",
        sail_dir="<parent_dir>/sail/{benchmark}_{libcbench_part}_{stack_size}",
    params:
        sail_options="-S -p -Vall -vmem -vinstr -vreg",
        cmdline_args=lambda w: f"{w.libcbench_part}"

ruleorder: run_random_callstack_ubench_output_gem5 > run_sail_output_gem5
use rule run_sail_output_gem5 as run_random_callstack_ubench_output_gem5 with:
    input:
        binary="<binary_dir>/{benchmark}.elf",
        seed="runs/{run_id}/seed.txt",
    pathvars:
        trace_file_prefix="<parent_dir>/traces/{benchmark}-{secure_ratio}_{stack_size}",
        sail_dir="<parent_dir>/sail/{benchmark}-{secure_ratio}_{stack_size}",
    wildcard_constraints:
        benchmark=r"random-callstack-ubench(\+large-alloc|\+small-alloc)?",
        secure_ratio=r"[01]?\.[\d]+"
    params:
        cmdline_args=lambda w, input: f"-s {input.seed} -r {w.secure_ratio}"

# thanks to https://heitorpb.github.io/bla/bash-random-numbers/
rule generate_random_seed:
    output: "runs/{run_id}/seed.txt"
    shell: "od -vAn -N4 -t u4 < /dev/urandom | tr -d ' ' > {output}"

# Instrumentation runs

rule run_coremark_instrumented:
    input: binary="<run_dir>/uninit/reserve/isentry/clear/noreduce/binaries/8M/coremark-instrumented.elf"
    output: "<instrumentation_dir>/instrumentation.txt"
    pathvars:
        instrumentation_dir="<run_dir>/instrumentation/coremark"
    log: 
        stdout="<instrumentation_dir>/sail_instrumented.out",
        stderr="<instrumentation_dir>/sail_instrumented.err",
    params:
        sail_options="-S -p -Vall",
    shell: "{config[sail_sim]} -z 1024 -S -V {params.sail_options} --cmdline-args '{output}' {input} -t {log.stdout} 2> {log.stderr}"

rule run_libc_bench_instrumented:
    input: binary="<run_dir>/uninit/reserve/isentry/clear/noreduce/binaries/8M/libc-bench-instrumented.elf"
    output: "<instrumentation_dir>/instrumentation.txt"
    pathvars:
        instrumentation_dir="<run_dir>/instrumentation/libc-bench_{libcbench_part}"
    log: 
        stdout="<instrumentation_dir>/sail_instrumented.out",
        stderr="<instrumentation_dir>/sail_instrumented.err",
    params:
        sail_options="-S -p -Vall",
        cmdline_args=lambda w: f"{w.libcbench_part}"
    shell: "{config[sail_sim]} -z 1024 -S -V {params.sail_options} --cmdline-args '{params.cmdline_args} {output}' {input} -t {log.stdout} 2> {log.stderr}"

rule run_random_callstack_ubench_instrumented:
    input: 
        binary="<run_dir>/uninit/reserve/isentry/clear/noreduce/binaries/8M/random-callstack-ubench-instrumented.elf",
        seed="<run_dir>/seed.txt"
    output: "<instrumentation_dir>/instrumentation.txt"
    pathvars:
        instrumentation_dir="<run_dir>/instrumentation/random-callstack-ubench-{secure_ratio}"
    log: 
        stdout="<instrumentation_dir>/sail_instrumented.out",
        stderr="<instrumentation_dir>/sail_instrumented.err",
    wildcard_constraints:
        secure_ratio=r"[01]?\.[\d]+",
    params:
        sail_options="-S -p -Vall",
        cmdline_args=lambda w, input: f"-s {input.seed} -r {w.secure_ratio} "
    shell: "{config[sail_sim]} -z 1024 -S -V {params.sail_options} --cmdline-args '{params.cmdline_args}-o {output}' {input.binary} -t {log.stdout} 2> {log.stderr}"

# ruleorder: run_random_callstack_ubench_instrumented > propagate_instrumentation_random_callstack_ubench_custom_alloc
rule propagate_instrumentation_random_callstack_ubench_custom_alloc:
    input: "<run_dir>/instrumentation/random-callstack-ubench-{secure_ratio}/instrumentation.txt"
    output: temp("<run_dir>/instrumentation/random-callstack-ubench{alloc}-{secure_ratio}/instrumentation.txt")
    wildcard_constraints:
        alloc=r"\+large-alloc|\+small-alloc",
        secure_ratio=r"[01]?\.[\d]+"
    shell: "cp {input} {output}"

# ruleorder: run_libc_bench_instrumented > propagate_instrumentation
# ruleorder: run_random_callstack_ubench_instrumented > propagate_instrumentation
# rule propagate_instrumentation:
#     input: "runs/{run_id}/uninit/none/trampoline/clear/instrumentation/{benchmark}.txt"
#     output: temp("runs/{run_id}/{cc_variant}/instrumentation/{benchmark}.txt")
#     wildcard_constraints:
#         cc_variant=r"none.*|uninit/none/(none|isentry)/(clear|noclear)|uninit/none/trampoline/noclear|uninit\/reserve.*"
#     shell: "cp {input} {output}"

# ruleorder: propagate_insecure_clearregs_stats > combine_stats
# # register clearing has no impact when there is no encapsulation
# # copying results to save on computation
# rule propagate_insecure_clearregs_stats:
#     input: "runs/{run_id}/{revoc}/none/noclear/stats/{benchmark}.txt"
#     output: "runs/{run_id}/{revoc}/none/clear/stats/{benchmark}.txt"
#     shell: "sed 's/clearregs      noclear/clearregs      clear/' {input} > {output}"
