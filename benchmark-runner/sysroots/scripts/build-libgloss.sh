#! /bin/bash
set -e
set -x

SOURCE_DIR=${SOURCE_DIR}
SDK_BIN=$(realpath ${SDK_BIN})
OUTPUT_DIR=$(realpath ${OUTPUT_DIR})
COMPILE_DIR=$(realpath -m ${COMPILE_DIR:-$(basename "$0" .sh)})
TARGET_SYSROOT="${OUTPUT_DIR}/riscv64-unknown-elf"
REVOC=${REVOC:-"none"}
REDUCECSR=${REDUCECSR:-"false"}
COMMON_FLAGS="-target riscv64-unknown-elf -B${SDK_BIN} -march=rv64imaxcheri -mabi=l64pc128 -mrelax -mcmodel=medany -g"

CCVARIANT_FLAGS="-mllvm -cheri-stack-revocation=${REVOC} -mllvm -cheri-uninit-reduce-callee-saved-regs=${REDUCECSR}"

[ "$REVOC" != "none" ] && UNINIT_DEFINE="-DCHERI_UNINIT"

ARGS=()
[ "$REVOC" = "uninitreserve" ] && ARGS+=("--enable-reserve-stack")
ARGS+=(
    "--disable-multilib"
    "--disable-newlib-supplied-syscalls"
    "--host=riscv64-unknown-elf"
    "--target=riscv64-unknown-elf"
    "--prefix=${OUTPUT_DIR}"
    "MAKE=gmake"
    "CC=${SDK_BIN}/clang -target riscv64-unknown-elf"
    "CXX=${SDK_BIN}/clang++ -target riscv64-unknown-elf"
    "CPP=${SDK_BIN}/clang-cpp"
    "LD=${SDK_BIN}/ld.lld"
    "AS=${SDK_BIN}/clang -target riscv64-unknown-elf"
    "AR=${SDK_BIN}/llvm-ar"
    "STRIP=${SDK_BIN}/llvm-strip"
    "OBJCOPY=${SDK_BIN}/objcopy"
    "RANLIB=${SDK_BIN}/llvm-ranlib"
    "OBJDUMP=${SDK_BIN}/llvm-objdump"
    "READELF=${SDK_BIN}/readelf"
    "NM=${SDK_BIN}/llvm-nm"
    "SIZE=${SDK_BIN}/llvm-size"
    "CFLAGS=${COMMON_FLAGS} -Wno-error=unused-command-line-argument --sysroot ${TARGET_SYSROOT} -I${TARGET_SYSROOT}/include ${UNINIT_DEFINE} ${CCVARIANT_FLAGS}"
    "CCASFLAGS=${COMMON_FLAGS} -Wno-error=unused-command-line-argument --sysroot ${TARGET_SYSROOT} -I${TARGET_SYSROOT}/include ${UNINIT_DEFINE}"
    "LDFLAGS=-static ${COMMON_FLAGS} -fuse-ld=lld --ld-path=${SDK_BIN}/ld.lld"
    "FLAGS=${COMMON_FLAGS} -Wno-error=unused-command-line-argument --sysroot ${TARGET_SYSROOT} -I${TARGET_SYSROOT}/include ${CCVARIANT_FLAGS}"
)

# [ -d "$COMPILE_DIR" ] && rm -rf "$COMPILE_DIR"
mkdir -p "$COMPILE_DIR"
cd "$COMPILE_DIR"
${SOURCE_DIR}/configure "${ARGS[@]}"
nice gmake -j16
gmake install
