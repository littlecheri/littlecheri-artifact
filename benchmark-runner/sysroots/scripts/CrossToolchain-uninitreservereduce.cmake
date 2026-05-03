#
# Copyright (c) 2016-2020 Alex Richardson
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory (Department of Computer Science and
# Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
# DARPA SSITH research programme.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
set(CMAKE_SYSTEM_NAME Generic)

set(CMAKE_SYSTEM_VERSION "")
set(CMAKE_SYSTEM_PROCESSOR "riscv64")

if(CMAKE_VERSION VERSION_LESS "3.9")
    message(FATAL_ERROR "This toolchain file requires CMake >= 3.9")
endif()

if(NOT DEFINED CHERI_SDK_BINDIR)
    message(FATAL_ERROR "Define bin dir which at least contains clang and lld")
endif(NOT DEFINED CHERI_SDK_BINDIR)
# Allow compiler dir to be different from toolchain directory (e.g. LLVM build dir)
if(NOT DEFINED CHERI_COMPILER_BINDIR)
    set(CHERI_COMPILER_BINDIR "${CHERI_SDK_BINDIR}")
endif(NOT DEFINED CHERI_COMPILER_BINDIR)
set(CHERIBSD_SYSROOT "")
# add the correct --sysroot:
# https://cmake.org/cmake/help/git-master/variable/CMAKE_SYSROOT.html
set(CMAKE_SYSROOT ${CHERIBSD_SYSROOT})

set(CMAKE_MAKE_PROGRAM "/usr/bin/ninja" CACHE FILEPATH "ninja")

set(CMAKE_AR "${CHERI_SDK_BINDIR}/llvm-ar" CACHE FILEPATH "ar")
set(CMAKE_RANLIB "${CHERI_SDK_BINDIR}/llvm-ranlib" CACHE FILEPATH "ranlib")
set(CMAKE_NM "${CHERI_SDK_BINDIR}/llvm-nm" CACHE FILEPATH "nm")
set(CMAKE_STRIP "${CHERI_SDK_BINDIR}/llvm-strip" CACHE FILEPATH "strip")

# specify the cross compiler
set(CMAKE_C_COMPILER "${CHERI_COMPILER_BINDIR}/clang")
set(CMAKE_C_COMPILER_TARGET "riscv64-unknown-elf")

set(CMAKE_CXX_COMPILER "${CHERI_COMPILER_BINDIR}/clang++")
set(CMAKE_CXX_COMPILER_TARGET "riscv64-unknown-elf")

set(CMAKE_ASM_COMPILER "${CHERI_COMPILER_BINDIR}/clang")
set(CMAKE_ASM_COMPILER_TARGET "riscv64-unknown-elf")
# https://gitlab.kitware.com/cmake/cmake/issues/18575
if (CMAKE_VERSION VERSION_LESS "3.13")
    set(CMAKE_ASM_COMPILER_ID "Clang")  # for some reason CMake doesn't detect this automatically
endif()

set(CHERI_UNINIT_CC_VARIANT_FLAGS "-mllvm -cheri-stack-revocation=uninitreserve -mllvm -cheri-uninit-reduce-callee-saved-regs=true")

set(CHERIBSD_COMMON_FLAGS "-target riscv64-unknown-elf -B${CHERI_SDK_BINDIR} -march=rv64imaxcheri -mabi=l64pc128 -mrelax -mcmodel=medany -ggdb -gz -Wno-error=unused-command-line-argument -ffreestanding -Werror=implicit-function-declaration -Werror=format -Werror=incompatible-pointer-types -Werror=cheri-capability-misuse -Werror=cheri-bitwise-operations -Werror=cheri-prototypes -Werror=pass-failed -Werror=undefined-internal ${CHERI_UNINIT_CC_VARIANT_FLAGS}")
# https://cmake.org/cmake/help/git-master/variable/CMAKE_TRY_COMPILE_PLATFORM_VARIABLES.html
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES CHERI_SDK_BINDIR CHERIBSD_SYSROOT CHERIBSD_COMMON_FLAGS LIB_SUFFIX PKG_CONFIG_USE_CMAKE_PREFIX_PATH)

# CMake 3.7 has new variables that we can use to correctly initialize these flags
# https://cmake.org/cmake/help/git-master/release/3.7.html#variables
set(CMAKE_EXE_LINKER_FLAGS_INIT    "-target riscv64-unknown-elf -B${CHERI_SDK_BINDIR} -march=rv64imaxcheri -mabi=l64pc128 -mrelax -mcmodel=medany -fuse-ld=lld --ld-path=${CHERI_SDK_BINDIR}/ld.lld -Wl,--gdb-index -Wl,--compress-debug-sections=zlib")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-target riscv64-unknown-elf -B${CHERI_SDK_BINDIR} -march=rv64imaxcheri -mabi=l64pc128 -mrelax -mcmodel=medany -fuse-ld=lld --ld-path=${CHERI_SDK_BINDIR}/ld.lld -Wl,--gdb-index -Wl,--compress-debug-sections=zlib")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-target riscv64-unknown-elf -B${CHERI_SDK_BINDIR} -march=rv64imaxcheri -mabi=l64pc128 -mrelax -mcmodel=medany -fuse-ld=lld --ld-path=${CHERI_SDK_BINDIR}/ld.lld -Wl,--gdb-index -Wl,--compress-debug-sections=zlib")
set(CMAKE_C_FLAGS_INIT   "${CHERIBSD_COMMON_FLAGS} ")
set(CMAKE_ASM_FLAGS_INIT "${CHERIBSD_COMMON_FLAGS} ")
set(CMAKE_CXX_FLAGS_INIT "${CHERIBSD_COMMON_FLAGS} ")

# where is the target environment
set(CMAKE_FIND_ROOT_PATH ${CHERIBSD_SYSROOT})
# search for programs in the build host directories
set(PKG_CONFIG_USE_CMAKE_PREFIX_PATH FALSE)
# PKG_CONFIG_LIBDIR overrides PKG_CONFIG_PATH
set(PKG_CONFIG_LIBDIR "")
set(ENV{PKG_CONFIG_LIBDIR} "")
set(PKG_CONFIG_SYSROOT_DIR ${CHERIBSD_SYSROOT})
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CHERIBSD_SYSROOT})
set(PKG_CONFIG_PATH "")
set(ENV{PKG_CONFIG_PATH} "")

# Use -pthread flag https://gitlab.kitware.com/cmake/cmake/issues/16920
set(THREADS_HAVE_PTHREAD_ARG TRUE)


# Ensure we search in the custom install prefix that we install everything to:
set(CMAKE_PREFIX_PATH ";${CMAKE_PREFIX_PATH}")
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

