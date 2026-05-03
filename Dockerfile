FROM fedora:43
RUN dnf install -y clang conda git

ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd -g $USER_GID -o $USERNAME && useradd -m -u $USER_UID -g $USER_GID -o -s /bin/bash $USERNAME && usermod -aG wheel $USERNAME
USER $USERNAME
CMD /bin/bash

WORKDIR /littlecheri
ADD --chown=$USER_UID:$USER_GID patches /littlecheri/patches
ADD --keep-git-dir --chown=$USER_UID:$USER_GID https://github.com/CTSRD-CHERI/llvm-project.git llvm-project
RUN git -C llvm-project fetch --depth 1 origin 578ea4f7ef67d589f0ca7d10ec9e383333567421 && \
    git -C llvm-project -c advice.detachedHead=false checkout FETCH_HEAD && \
    git -C llvm-project apply /littlecheri/patches/llvm.patch

ADD --chown=$USER_UID:$USER_GID sail-parser /littlecheri/sail-parser
USER root
RUN dnf install -y pipx
USER $USERNAME
RUN pipx install ./sail-parser

RUN git clone --depth 1 --branch v24.1.0.1 https://github.com/gem5/gem5 gem5 && \
    git -C gem5 apply /littlecheri/patches/gem5.patch
USER root
RUN dnf install -y m4 pkg-config wget cmake python3 python3-devel \
    protobuf-compiler protobuf-devel \
    zlib-ng zlib-ng-compat zlib-ng-devel zlib-ng-compat-devel \
    gperftools-devel gperftools-libs \
    boost \
    hdf5 hdf5-devel \
    capstone capstone-devel \
    libpng libpng-devel \
    elfutils-libelf elfutils-libelf-devel
USER $USERNAME
RUN pipx install scons==4.5.2
ENV PATH="$PATH:/home/user/.local/bin"
WORKDIR gem5
RUN scons build/RISCV/gem5.opt -j $(nproc)
WORKDIR /littlecheri

RUN git clone https://github.com/CTSRD-CHERI/sail-cheri-riscv.git
WORKDIR sail-cheri-riscv
RUN git checkout c93d5ef && \
    git apply /littlecheri/patches/sail-cheri-riscv.patch
RUN git clone https://github.com/rems-project/sail-riscv.git && \
    git -C sail-riscv checkout 9602e3a && \
    git -C sail-riscv apply /littlecheri/patches/sail-riscv.patch
USER root
RUN dnf install -y z3 opam gmp gmp-devel
USER $USERNAME
RUN opam init --disable-sandboxing && opam install --yes sail && make csim

RUN git clone https://github.com/CTSRD-CHERI/newlib && \
    git -C newlib checkout e9065ae && \
    git -C newlib apply /littlecheri/patches/newlib.patch

RUN git clone --depth 1 https://sourceware.org/git/newlib-cygwin.git newlib-cygwin && \
    git -C newlib-cygwin fetch --depth 1 origin c5fe019a9a3c6e6cfff4a42d63ce5d0975556b63 && \
    git -C newlib-cygwin -c advice.detachedHead=false checkout FETCH_HEAD && \
    git -C newlib-cygwin apply /littlecheri/patches/libgloss.patch

RUN git clone https://github.com/GaloisInc/BESSPIN-coremark coremark && \
    git -C coremark checkout 6864c50 && \
    git -C coremark apply /littlecheri/patches/coremark.patch

RUN git clone https://git.musl-libc.org/git/libc-bench && \
    git -C libc-bench checkout b6b2ce5 && \
    git -C libc-bench apply /littlecheri/patches/libc-bench.patch

ADD --chown=$USER_UID:$USER_GID benchmark-runner /littlecheri/benchmark-runner
WORKDIR /littlecheri/benchmark-runner
RUN conda env create -f ./environment.yaml