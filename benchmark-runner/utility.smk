rule dump_binary:
    input: 
        binary="{prefix}/{benchmark}.elf",
        tool="sysroots/uninit/bin/llvm-objdump"
    output: "{prefix}/{benchmark}.dump"
    shell: "{input.tool} --syms -dSr {input.binary} > {output}"

rule trace_sail_to_gem5_with_mem_profile:
    input: "{case}/traces/{benchmark}.sail.trace"
    output:
        data="{case}/traces/{benchmark}_mem_profiled_data.proto.gz",
        inst="{case}/traces/{benchmark}_mem_profiled_inst.proto.gz",
        profile="{case}/profiles/{benchmark}.mem_prof",
    shell: "{config[sail_parser]} output-proto-traced -c {input} {output.data} {output.inst} {output.profile}"

rule clean:
    input: directory("<run_dir>")
    output: temp("<run_dir>/clean")
    shell: "rm -rf {input}/none {input}/uninit {input}/instrumentation && rm -f {input}/results.* && touch {output}"