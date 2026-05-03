OPATH ?= .

REVOC?=uninitreserve
CHERI_ENCAP?=trampoline
CLEAR?=clear
STACK_SIZE?=8M
LINKER_SCRIPT?=sail.ld

SYSROOT?=/home/eliass/Documents/Res/Uninit/benchmarks/setup/sysroots/uninitreserve
SDK_BIN?=$(SYSROOT)/bin
SYSROOT_DIR?=$(SYSROOT)/riscv64-unknown-elf

ARCHFLAGS=--target=riscv64-unknown-elf -march=rv64imaxcheri -mabi=l64pc128 --sysroot=$(SYSROOT_DIR) -B$(SDK_BIN)
ARCHFLAGS+=-mllvm -cheri-uninit-return-encapsulation=$(CHERI_ENCAP)
ARCHFLAGS+=-mllvm -cheri-stack-revocation=$(REVOC)

CFLAGS=-mcmodel=medany -mrelax -O0 -g -std=gnu99 -fno-common -DPARSE_ARGS $(XCFLAGS)
LDFLAGS=-Wl,--defsym=STACK_SIZE_MIN=$(STACK_SIZE) -T$(LINKER_SCRIPT) -fuse-ld=lld -static -nostartfiles
CC=$(SDK_BIN)/clang $(ARCHFLAGS)

ifneq ($(CHERI_ENCAP), none)
CFLAGS+=-DWRAP_UNINIT
endif

ifeq ($(CLEAR), clear)
CFLAGS+=-mllvm -cheri-uninit-clear-regs=true
else
CFLAGS+=-mllvm -cheri-uninit-clear-regs=false
endif

REDUCECSR ?= noreduce

ifeq ($(REDUCECSR), reduce)
CFLAGS+=-mllvm -cheri-uninit-reduce-callee-saved-regs=true
else
CFLAGS+=-mllvm -cheri-uninit-reduce-callee-saved-regs=false
endif

$(OPATH)random-callstack-ubench.elf: random-callstack-ubench.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(OPATH)random-callstack-ubench-instrumented.elf: CFLAGS += -DINSTRUMENT_UNINIT
$(OPATH)random-callstack-ubench-instrumented.elf: random-callstack-ubench.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(OPATH)random-callstack-ubench+large-alloc.elf: random-callstack-ubench.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ -DUBENCH_LARGE_ALLOC

$(OPATH)random-callstack-ubench+small-alloc.elf: random-callstack-ubench.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ -DUBENCH_SMALL_ALLOC


random-callstack-ubench.dump: random-callstack-ubench.elf
	$(SDK_BIN)/llvm-objdump -dSr $^ > $@

random_secure_plain_depth.csv: random-callstack-ubench-instrumented.elf
	cheri_riscv_sim_RV64 -p -z 1024 -S $< -V -t $@ --cmdline-args '-o instrumentation.txt'

random_secure_plain_depth.png: random_secure_plain_depth.csv FORCE
	rm -f $@
	gnuplot -c depth.gp $< $@ "$$(grep -i -e "Seed" $< | sed s/\#//g)"

clean:
	rm -f $(OPATH)random-callstack-ubench.elf $(OPATH)random-callstack-ubench.dump

FORCE: ;