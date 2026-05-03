#! /bin/bash -ex

SOURCE_DIR=${SOURCE_DIR}
SDK_BIN=$(realpath ${SDK_BIN})
OUTPUT_DIR=$(realpath ${OUTPUT_DIR})
COMPILE_DIR=$(realpath -m ${COMPILE_DIR:-$(basename "$0" .sh)})
ARCHFLAGS="-target riscv64-unknown-elf -B${SDK_BIN} -march=rv64imaxcheri -mabi=l64pc128 -mrelax -mcmodel=medany"
REVOC=${REVOC:-"none"}
REDUCECSR=${REDUCECSR:-"false"}

CCVARIANT_FLAGS="-mllvm -cheri-stack-revocation=${REVOC} -mllvm -cheri-uninit-reduce-callee-saved-regs=${REDUCECSR}"

ARGS=(
    "--enable-static"
    "--with-newlib"
    "--disable-shared"
    "--disable-libgloss" # for the love of <insert higher being> leave this disabled and use libgloss-htif fork
    "--disable-multilib"
    "--disable-libstdcxx"
    "--disable-newlib-multithread"
    "--disable-newlib-mb"
    "--disable-newlib-iconv"
    "--enable-malloc-debugging"
    "--enable-newlib-long-time_t"
    "--enable-newlib-io-c99-formats"
    "--enable-newlib-io-long-long"
    "--disable-newlib-io-long-double"
    "--enable-newlib-io-float"
    "--enable-newlib-global-atexit"
    "--enable-serial-build-configure"
    "--enable-serial-target-configure"
    "--enable-serial-host-configure"
    # "--enable-newlib-elix-level=2"
    "--target=riscv64-unknown-elf" 
    "--prefix=${OUTPUT_DIR}"
    "MAKE=gmake"
    "CC_FOR_TARGET=${SDK_BIN}/clang -target riscv64-unknown-elf"
    "CXX_FOR_TARGET=${SDK_BIN}/clang++ -target riscv64-unknown-elf"
    "LD_FOR_TARGET=${SDK_BIN}/ld.lld"
    "AS_FOR_TARGET=${SDK_BIN}/clang -target riscv64-unknown-elf"
    "AR_FOR_TARGET=${SDK_BIN}/llvm-ar"
    "STRIP_FOR_TARGET=${SDK_BIN}/llvm-strip"
    "OBJCOPY_FOR_TARGET=${SDK_BIN}/objcopy"
    "RANLIB_FOR_TARGET=${SDK_BIN}/llvm-ranlib"
    "OBJDUMP_FOR_TARGET=${SDK_BIN}/llvm-objdump"
    "READELF_FOR_TARGET=${SDK_BIN}/readelf"
    "NM_FOR_TARGET=${SDK_BIN}/llvm-nm"
    "CFLAGS_FOR_TARGET=${ARCHFLAGS} -g -Wno-error=unused-command-line-argument --sysroot /this/path/does/not/exist -DMALLOC_ALIGNMENT=16 ${CCVARIANT_FLAGS}"
    "CCASFLAGS_FOR_TARGET=${ARCHFLAGS} -Wno-error=unused-command-line-argument --sysroot /this/path/does/not/exist"
    "LDFLAGS_FOR_TARGET=${ARCHFLAGS} -g -static -fuse-ld=lld --ld-path=${SDK_BIN}/ld.lld"
    "FLAGS_FOR_TARGET=${ARCHFLAGS} -g -Wno-error=unused-command-line-argument --sysroot /this/path/does/not/exist ${CCVARIANT_FLAGS}"
    "CC_FOR_BUILD=/usr/bin/clang"
    "CC=/usr/bin/clang"
    "CXX_FOR_BUILD=/usr/bin/clang++"
    "CXX=/usr/bin/clang++"
    "CPP_FOR_BUILD=/usr/bin/clang-cpp"
    "CPP=/usr/bin/clang-cpp"
)

# [ -d "$COMPILE_DIR" ] && rm -rf "$COMPILE_DIR"
mkdir -p "$COMPILE_DIR"
cd "$COMPILE_DIR"
${SOURCE_DIR}/configure "${ARGS[@]}"
nice gmake -j16 all
gmake install
echo "$0\n$(pwd)" > "${OUTPUT_DIR}/newlib-build.txt"
