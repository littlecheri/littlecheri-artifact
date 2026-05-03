configfile: "config/sysroots_config.yaml"
configfile: "config/local_config.yaml"

wildcard_constraints:
    sysrootname="|".join(config["sysrootnames"])

def sysrootname_to_revoc(sysrootname):
    match sysrootname:
        case "none": 
            return "none"
        case "uninit":
            return "uninit"
        case "uninitreserve" | "uninitreservereduce":
            return "uninitreserve"

def sysrootname_to_reducecsr(sysrootname):
    match sysrootname:
        case "none" | "uninit" | "uninitreserve":
            return "false"
        case "uninitreservereduce":
            return "true"

rule build_llvm:
    output: expand("{build_dir}/llvm/bin/{executable}", build_dir=config["build_dir"], executable=config["llvm_executables"])
    params:
        build_dir=f"{config["build_dir"]}/llvm",
        cmake_config_opts= [
            "-GNinja",
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
            "-DCMAKE_C_COMPILER=/usr/bin/clang",
            "-DCMAKE_CXX_COMPILER=/usr/bin/clang++",
            "-DCMAKE_ASM_COMPILER=/usr/bin/clang",
            "-DLLVM_TARGETS_TO_BUILD=RISCV",
            "-DLLVM_ENABLE_PROJECTS='llvm;clang;lld'",
            "-DLLVM_ENABLE_LLD=True",
            "-DLLVM_OPTIMIZED_TABLEGEN=FALSE",
            "-DLLVM_USE_SPLIT_DWARF=True",
            "-DLLVM_PARALLEL_LINK_JOBS=4",
            "-DLLVM_INSTALL_UTILS=TRUE",
            "-DLLVM_INSTALL_BINUTILS_SYMLINKS=TRUE",
            "-DLLVM_ENABLE_ASSERTIONS=TRUE",
            "-DLLVM_ENABLE_LIBXML2=FALSE",
            "-DLLVM_ENABLE_ZLIB=FORCE_ON",
            "-DLLVM_ENABLE_OCAMLDOC=False",
            "-DLLVM_ENABLE_BINDINGS=False",
            "-DLLVM_ENABLE_Z3_SOLVER=FALSE",
            "-DLLVM_INCLUDE_EXAMPLES=False",
            "-DLLVM_INCLUDE_DOCS=False",
            "-DLLVM_INCLUDE_BENCHMARKS=False",
            "-DLLVM_TOOL_LLVM_MCA_BUILD=FALSE",
            "-DLLVM_TOOL_LLVM_EXEGESIS_BUILD=FALSE",
            "-DLLVM_TOOL_LLVM_RC_BUILD=FALSE",
            "-DCLANG_ENABLE_STATIC_ANALYZER=FALSE",
            "-DCLANG_ENABLE_ARCMT=FALSE",
        ]
    log: "logs/llvm_tools.log"
    run: 
        if config["clean"]: shell("rm -rf {params.build_dir}")
        shell(f"""
        nice cmake -S {config["sources"]["llvm-project"]["base"]}/{config["sources"]["llvm-project"]["llvm"]} -B {params.build_dir} {{params.cmake_config_opts}}
        nice cmake --build {params.build_dir} --target all -j16
        """)

rule install_llvm:
    input:
        expand("{build_dir}/llvm/bin/{executable}", build_dir=config["build_dir"], executable=config["llvm_executables"])
    output:
        expand("sysroots/{sysrootname}/bin/{executable}", sysrootname="{sysrootname}", executable=config["llvm_executables"]),
        prefix_dir=directory("sysroots/{sysrootname}"),
    params:
        build_dir=f"{config["build_dir"]}/llvm",
    shell:
        "cmake --install {params.build_dir} --prefix {output.prefix_dir}"

rule build_newlib:
    input:
        rules.install_llvm.output,
        "sysroots/scripts/build-newlib.sh",
    output:
        expand("sysroots/{sysrootname}/riscv64-unknown-elf/lib/{library}.a", sysrootname="{sysrootname}", library=["libc", "libm"]),
    params:
        args=lambda w: [
            f"SDK_BIN=sysroots/{w.sysrootname}/bin",
            f"OUTPUT_DIR=sysroots/{w.sysrootname}",
            f"COMPILE_DIR={config['build_dir']}/newlib/{w.sysrootname}",
            "SOURCE_DIR={}".format(config["sources"]["newlib"]),
            "REVOC={}".format(sysrootname_to_revoc(w.sysrootname)),
            "REDUCECSR={}".format(sysrootname_to_reducecsr(w.sysrootname)),
        ]
    run:
        if config["clean"]: shell("rm -rf {params.build_dir}")
        shell("{params.args} {config[sysroots_scripts]}/build-newlib.sh")

rule build_libgloss:
    input:
        rules.install_llvm.output,
        rules.build_newlib.output,
        "sysroots/scripts/build-libgloss.sh",
    output:
        "sysroots/{sysrootname}/riscv64-unknown-elf/lib/libgloss.a",
    params:
        args=lambda w: [
            f"SDK_BIN=sysroots/{w.sysrootname}/bin",
            f"OUTPUT_DIR=sysroots/{w.sysrootname}",
            "COMPILE_DIR={}/libgloss/{}".format(config["build_dir"], w.sysrootname),
            "SOURCE_DIR={}".format(config["sources"]["libgloss"]),
            "REVOC={}".format(sysrootname_to_revoc(w.sysrootname)),
            "REDUCECSR={}".format(sysrootname_to_reducecsr(w.sysrootname)),
        ]
    run:
        if config["clean"]: shell("rm -rf {params.build_dir}")
        shell("{params.args} {config[sysroots_scripts]}/build-libgloss.sh")

rule build_compiler_rt:
    input:
        rules.install_llvm.output,
    output:
        "sysroots/{sysrootname}/lib/clang/15.0.0/lib/libclang_rt.builtins-riscv64.a",
        "sysroots/{sysrootname}/lib/clang/15.0.0/lib/baremetal/libclang_rt.builtins-riscv64.a",
    params:
        output_dir="sysroots/{sysrootname}/lib/clang/15.0.0",
        build_dir=lambda w: f"{config["build_dir"]}/compiler_rt/{w.sysrootname}",
        cmake_config_opts=lambda w: [
            "-GNinja",
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
            "--toolchain=$(realpath {}/CrossToolchain-{}.cmake)".format(config["sysroots_scripts"], w.sysrootname),
            f"-DCMAKE_INSTALL_INCLUDEDIR=sysroots/{w.sysrootname}/riscv64-unknown-elf/includes",
            "-DCMAKE_BUILD_RPATH_USE_ORIGIN=TRUE",
            "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE",
            '-DCMAKE_INSTALL_RPATH=$$ORIGIN/../lib',
            "-DCMAKE_BUILD_WITH_INSTALL_RPATH=FALSE",
            "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
            "-DLLVM_CONFIG_PATH=NOTFOUND",
            "-DCMAKE_DISABLE_FIND_PACKAGE_LLVM=TRUE",
            "-DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE",
            "-DCOMPILER_RT_BAREMETAL_BUILD=TRUE",
            "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE",
            "-DCOMPILER_RT_OS_DIR=.",
            "-DCOMPILER_RT_DEBUG=TRUE",
            f"-DCHERI_SDK_BINDIR=$(realpath sysroots/{w.sysrootname}/bin)",
            f"-DCHERI_COMPILER_BINDIR=$(realpath sysroots/{w.sysrootname}/bin)",
        ],
    run: 
        if config["clean"]: shell("rm -rf {params.build_dir}")
        shell(f"""
        nice cmake -S {config["sources"]["llvm-project"]["base"]}/{config["sources"]["llvm-project"]["compiler_rt"]}\\
            -B {params.build_dir} {{params.cmake_config_opts}}
        nice cmake --build {params.build_dir} --target all -j16
        mkdir -p {params.output_dir}/lib/baremetal
        cmake --install {params.build_dir} --prefix {params.output_dir}
        ln -s $(realpath {params.output_dir}/lib/libclang_rt.builtins-riscv64.a) {params.output_dir}/lib/baremetal/libclang_rt.builtins-riscv64.a
        """)

rule install_extra_headers:
    input:
        rules.build_newlib.output,
        header="scripts/wrap_uninit.h"
    output:
        "sysroots/{sysrootname}/riscv64-unknown-elf/include/wrap_uninit.h"
    shell: "install {input.header} {output}"

rule build_sysroot:
    input:
        rules.install_llvm.output,
        rules.build_newlib.output,
        rules.build_compiler_rt.output,
        rules.build_libgloss.output,
        rules.install_extra_headers.output,
    output: "sysroots/{sysrootname}/complete"
    shell: "touch {output}"