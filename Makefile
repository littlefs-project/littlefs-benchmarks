# overrideable build dir, default to ./build
BUILDDIR ?= build
# overrideable results dir, default to ./results
RESULTSDIR ?= results
# overrideable plots dir, defaults ./plots
PLOTSDIR ?= plots

# how many samples to measure?
SAMPLES ?= 16

# tuneable configs
BENCH_TUNE_BS ?= 512,1024,2048,4096,8192,16384
BENCH_TUNE_IS ?= 0,256,512,1024
BENCH_TUNE_FS ?= 16,32,64,128,256,512,1024
BENCH_TUNE_CT ?= 0,256,512,1024,2048,4096

# configurations that simulate real-world storage
#
# with *_TIME indicating a per-byte estimate in nanoseconds
#
# Using a per-byte estimate isn't _super_ accurate, it ignores
# important nuances such as instruction overhead and on-disk buffers/
# caches that make batched reads/progs more efficient. But it's simple,
# and provides a decent rough estimate.
#

# sd/emmc - estimated based on w25n01gv, assumes a _perfect_ FTL
#
EMMC_READ_SIZE  ?= 512  # these estimates are at the byte-level, so the
EMMC_PROG_SIZE  ?= 512  # block size doesn't actual change anything
EMMC_ERASE_SIZE ?= 512  #
EMMC_READ_TIME  ?= 31   # taken from w25n01gv, read time
EMMC_PROG_TIME  ?= 156  # taken from w25n01gv, prog time + erase time
EMMC_ERASE_TIME ?= 0    # noop

# nor flash - based on w25q64jv
#
# https://www.winbond.com/resource-files/W25Q256JV%20SPI%20RevQ%2002072025%20Plus.pdf
#
NOR_READ_SIZE  ?= 1     # FR=104 MHz, quad prog (9.6 ns * 8/4)
NOR_PROG_SIZE  ?= 1     # => +~19 ns for bus (not read!)
NOR_ERASE_SIZE ?= 4096  #
NOR_READ_TIME  ?= 40    # fR=50 MHz, quad read (20 ns * 8/4)
NOR_PROG_TIME  ?= 1582  # tPP=0.4 ms, page=256 (0.4 ms / 256 + bus)
NOR_ERASE_TIME ?= 10986 # tSE=45 ms, sector=4096 (45 ms / 4096)

# nand flash - based on w25n01gv
#
# https://www.winbond.com/resource-files/W25N01GV%20Rev%20R%20070323.pdf
#
NAND_READ_SIZE  ?= 512    # FR=104 MHz, quad read/prog (9.6 ns * 8/4)
NAND_PROG_SIZE  ?= 512    # => +~19 ns for bus
NAND_ERASE_SIZE ?= 131072 # 
NAND_READ_TIME  ?= 31     # tRD1=25 us, p=2048, s=512 (25 us / 2048 + bus)
NAND_PROG_TIME  ?= 141    # tPP=250 us, p=2048, s=512 (250 us / 2048 + bus)
NAND_ERASE_TIME ?= 15     # tBE=2 ms, block=131072 (2 ms / 131072)



# find source files

# littlefs v3 sources
CODEMAP_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
CODEMAP_OBJ := $(CODEMAP_SRC:%.c=$(BUILDDIR)/thumb/%.o)
CODEMAP_DEP := $(CODEMAP_SRC:%.c=$(BUILDDIR)/thumb/%.d)
CODEMAP_ASM := $(CODEMAP_SRC:%.c=$(BUILDDIR)/thumb/%.s)
CODEMAP_CI  := $(CODEMAP_SRC:%.c=$(BUILDDIR)/thumb/%.ci)

# littlefs v2 sources
CODEMAP_LFS2_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs2/*.c))
CODEMAP_LFS2_OBJ := $(CODEMAP_LFS2_SRC:%.c=$(BUILDDIR)/thumb/%.o)
CODEMAP_LFS2_DEP := $(CODEMAP_LFS2_SRC:%.c=$(BUILDDIR)/thumb/%.d)
CODEMAP_LFS2_ASM := $(CODEMAP_LFS2_SRC:%.c=$(BUILDDIR)/thumb/%.s)
CODEMAP_LFS2_CI  := $(CODEMAP_LFS2_SRC:%.c=$(BUILDDIR)/thumb/%.ci)

# littlefs v1 sources
CODEMAP_LFS1_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs1/*.c))
CODEMAP_LFS1_OBJ := $(CODEMAP_LFS1_SRC:%.c=$(BUILDDIR)/thumb/%.o)
CODEMAP_LFS1_DEP := $(CODEMAP_LFS1_SRC:%.c=$(BUILDDIR)/thumb/%.d)
CODEMAP_LFS1_ASM := $(CODEMAP_LFS1_SRC:%.c=$(BUILDDIR)/thumb/%.s)
CODEMAP_LFS1_CI  := $(CODEMAP_LFS1_SRC:%.c=$(BUILDDIR)/thumb/%.ci)

# littlefs v3 bench-runner (the default)
BENCHES ?= $(wildcard benches/*.toml)
BENCH_RUNNER ?= $(BUILDDIR)/bench_runner
BENCH_SRC ?= \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		runners/bench_runner.c
BENCH_C     := \
		$(BENCHES:%.toml=$(BUILDDIR)/%.lfs3.b.c) \
		$(BENCH_SRC:%.c=$(BUILDDIR)/%.lfs3.b.c)
BENCH_A     := $(BENCH_C:%.lfs3.b.c=%.lfs3.b.a.c)
BENCH_OBJ   := $(BENCH_A:%.lfs3.b.a.c=%.lfs3.b.a.o)
BENCH_DEP   := $(BENCH_A:%.lfs3.b.a.c=%.lfs3.b.a.d)
BENCH_CI    := $(BENCH_A:%.lfs3.b.a.c=%.lfs3.b.a.ci)
BENCH_GCNO  := $(BENCH_A:%.lfs3.b.a.c=%.lfs3.b.a.gcno) \
BENCH_GCDA  := $(BENCH_A:%.lfs3.b.a.c=%.lfs3.b.a.gcda) \
BENCH_PERF  := $(BENCH_RUNNER:%=%.perf)
BENCH_TRACE := $(BENCH_RUNNER:%=%.trace)
BENCH_CSV   := $(BENCH_RUNNER:%=%.csv)

# littlefs v2 bench-runner
BENCHES_LFS2 ?= benches/bench_vs_lfs2.toml
BENCH_LFS2_RUNNER ?= $(BUILDDIR)/bench_lfs2_runner
BENCH_LFS2_SRC ?= \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs2/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		runners/bench_runner.c
BENCH_LFS2_C     := \
		$(BENCHES_LFS2:%.toml=$(BUILDDIR)/%.lfs2.b.c) \
		$(BENCH_LFS2_SRC:%.c=$(BUILDDIR)/%.lfs2.b.c)
BENCH_LFS2_A     := $(BENCH_LFS2_C:%.lfs2.b.c=%.lfs2.b.a.c)
BENCH_LFS2_OBJ   := $(BENCH_LFS2_A:%.lfs2.b.a.c=%.lfs2.b.a.o)
BENCH_LFS2_DEP   := $(BENCH_LFS2_A:%.lfs2.b.a.c=%.lfs2.b.a.d)
BENCH_LFS2_CI    := $(BENCH_LFS2_A:%.lfs2.b.a.c=%.lfs2.b.a.ci)
BENCH_LFS2_GCNO  := $(BENCH_LFS2_A:%.lfs2.b.a.c=%.lfs2.b.a.gcno) \
BENCH_LFS2_GCDA  := $(BENCH_LFS2_A:%.lfs2.b.a.c=%.lfs2.b.a.gcda) \
BENCH_LFS2_PERF  := $(BENCH_LFS2_RUNNER:%=%.perf)
BENCH_LFS2_TRACE := $(BENCH_LFS2_RUNNER:%=%.trace)
BENCH_LFS2_CSV   := $(BENCH_LFS2_RUNNER:%=%.csv)

# overridable tools/flags
CC            ?= gcc
AR            ?= ar
SIZE          ?= size
CTAGS         ?= ctags
OBJDUMP       ?= objdump
VALGRIND      ?= valgrind
GDB           ?= gdb
PERF          ?= perf
PRETTYASSERTS ?= ./scripts/prettyasserts.py

# c flags
CFLAGS += -fcallgraph-info=su
CFLAGS += -g3
CFLAGS += -I. -Ilittlefs3 -Ilittlefs2
CFLAGS += -std=c99 -Wall -Wextra -pedantic
# labels are useful for debugging, in-function organization, etc
CFLAGS += -Wno-unused-label
CFLAGS += -Wno-unused-function
CFLAGS += -Wno-format-overflow
# compiler bug: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=101854
CFLAGS += -Wno-stringop-overflow
CFLAGS += -ftrack-macro-expansion=0
ifdef DEBUG
CFLAGS += -O0
else
CFLAGS += -Os
endif
ifdef TRACE
CFLAGS += -DLFS_YES_TRACE
endif
ifdef COVGEN
CFLAGS += --coverage
endif
ifdef PERFGEN
CFLAGS += -fno-omit-frame-pointer
endif
ifdef PERFBDGEN
CFLAGS += -fno-omit-frame-pointer
endif

# also forward all LFS_*, LFS2_*, and LFS3*_ environment variables
CFLAGS += $(foreach D,$(filter LFS_%,$(.VARIABLES)),-D$D=$($D))
CFLAGS += $(foreach D,$(filter LFS1_%,$(.VARIABLES)),-D$D=$($D))
CFLAGS += $(foreach D,$(filter LFS2_%,$(.VARIABLES)),-D$D=$($D))
CFLAGS += $(foreach D,$(filter LFS3_%,$(.VARIABLES)),-D$D=$($D))

# cross-compile codemap, we don't really care about x86 code size
CODEMAP_CC ?= arm-linux-gnueabi-gcc -mthumb --static -Wno-stringop-overflow
CODEMAP_CFLAGS += $(foreach P,LFS LFS1 LFS2 LFS3,-D$P_NO_LOG)
CODEMAP_CFLAGS += $(foreach P,LFS LFS1 LFS2 LFS3,-D$P_NO_DEBUG)
CODEMAP_CFLAGS += $(foreach P,LFS LFS1 LFS2 LFS3,-D$P_NO_INFO)
CODEMAP_CFLAGS += $(foreach P,LFS LFS1 LFS2 LFS3,-D$P_NO_WARN)
CODEMAP_CFLAGS += $(foreach P,LFS LFS1 LFS2 LFS3,-D$P_NO_ERROR)
CODEMAP_CFLAGS += $(foreach P,LFS LFS1 LFS2 LFS3,-D$P_NO_ASSERT)

# bench.py -c flags
ifdef VERBOSE
BENCHCFLAGS += -v
endif

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
	$(BUILDDIR) \
	$(BUILDDIR)/thumb \
	$(RESULTSDIR) \
	$(PLOTSDIR) \
    $(addprefix $(BUILDDIR)/,$(dir \
		$(CODEMAP_SRC) \
		$(CODEMAP_LFS2_SRC) \
		$(CODEMAP_LFS1_SRC) \
        $(BENCHES) \
        $(BENCH_SRC) \
        $(BENCH_LFS2_SRC))) \
    $(addprefix $(BUILDDIR)/thumb/,$(dir \
		$(CODEMAP_SRC) \
		$(CODEMAP_LFS2_SRC) \
		$(CODEMAP_LFS1_SRC) \
        $(BENCHES) \
        $(BENCH_SRC) \
        $(BENCH_LFS2_SRC)))))
endif

# just use bash for everything, process substitution my beloved!
SHELL = /bin/bash


# top-level commands

## Build the bench-runners
.PHONY: build bench-runner build-benches
build bench-runner build-benches: CFLAGS+=$(BENCH_CFLAGS)
# note we remove some binary dependent files during compilation,
# otherwise it's way to easy to end up with outdated results
build bench-runner build-benches: \
		$(BENCH_RUNNER) \
		$(BENCH_LFS2_RUNNER)
ifdef COVGEN
	rm -f $(BENCH_GCDA)
	rm -f $(BENCH_LFS2_GCDA)
endif
ifdef PERFGEN
	rm -f $(BENCH_PERF)
	rm -f $(BENCH_LFS2_PERF)
endif
ifdef PERFBDGEN
	rm -f $(BENCH_TRACE)
	rm -f $(BENCH_LFS2_TRACE)
endif

## Find total section sizes
.PHONY: size
size: $(BENCH_OBJ)
	$(SIZE) -t $^

## Generate a ctags file
.PHONY: tags ctags
tags ctags:
	$(strip $(CTAGS) \
		--totals --fields=+n --c-types=+p \
		$(shell find -H -name '*.h') \
		$(BENCH_SRC) \
		$(BENCH_LFS2_SRC))

## Show this help text
.PHONY: help
help:
	@$(strip awk '/^## / { \
			sub(/^## /,""); \
			getline rule; \
			while (rule ~ /^(#|\.PHONY|ifdef|ifndef)/) getline rule; \
			gsub(/:.*/, "", rule); \
			if (length(rule) <= 21) { \
				printf "%2s%-21s %s\n", "", rule, $$0; \
			} else { \
				printf "%2s%s\n", "", rule; \
				printf "%24s%s\n", "", $$0; \
			} \
		}' $(MAKEFILE_LIST))


# low-level rules
-include $(BENCH_DEP)
-include $(BENCH_LFS2_DEP)
.SUFFIXES:
.SECONDARY:
, := ,

$(BENCH_RUNNER): $(BENCH_OBJ)
	$(CC) $(CFLAGS) $^ $(LFLAGS) -o$@

$(BENCH_LFS2_RUNNER): $(BENCH_LFS2_OBJ)
	$(CC) $(CFLAGS) $^ $(LFLAGS) -o$@

# our main build rule generates .o, .d, and .ci files, the latter
# used for stack analysis

# cross-compile for codemap
$(BUILDDIR)/thumb/%.o $(BUILDDIR)/thumb/%.ci: %.c
	$(strip $(CODEMAP_CC) -c -MMD $(CFLAGS) $(CODEMAP_CFLAGS) $< \
		-o $(BUILDDIR)/thumb/$*.o)

$(BUILDDIR)/thumb/%.o $(BUILDDIR)/thumb/%.ci: $(BUILDDIR)/thumb/%.c
	$(strip $(CODEMAP_CC) -c -MMD $(CFLAGS) $(CODEMAP_CFLAGS) $< \
		-o $(BUILDDIR)/thumb/$*.o)

# .lfs3 files need -DLFS3=1
$(BUILDDIR)/%.lfs3.b.a.o $(BUILDDIR)/%.lfs3.b.a.ci: %.lfs3.b.a.c
	$(CC) -c -MMD -DLFS3=1 $(CFLAGS) $< -o $(BUILDDIR)/$*.lfs3.b.a.o

$(BUILDDIR)/%.lfs3.b.a.o $(BUILDDIR)/%.lfs3.b.a.ci: $(BUILDDIR)/%.lfs3.b.a.c
	$(CC) -c -MMD -DLFS3=1 $(CFLAGS) $< -o $(BUILDDIR)/$*.lfs3.b.a.o

# .lfs2 files need -DLFS2=1
$(BUILDDIR)/%.lfs2.b.a.o $(BUILDDIR)/%.lfs2.b.a.ci: %.lfs2.b.a.c
	$(CC) -c -MMD -DLFS2=1 $(CFLAGS) $< -o $(BUILDDIR)/$*.lfs2.b.a.o

$(BUILDDIR)/%.lfs2.b.a.o $(BUILDDIR)/%.lfs2.b.a.ci: $(BUILDDIR)/%.lfs2.b.a.c
	$(CC) -c -MMD -DLFS2=1 $(CFLAGS) $< -o $(BUILDDIR)/$*.lfs2.b.a.o

$(BUILDDIR)/%.s: %.c
	$(CC) -S $(CFLAGS) $< -o$@

$(BUILDDIR)/%.s: $(BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $< -o$@

$(BUILDDIR)/%.a.c: %.c
	$(PRETTYASSERTS) -Plfs_ $< -o$@

$(BUILDDIR)/%.a.c: $(BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ $< -o$@

# limit .lfs3 files to lfs3 benches
$(BUILDDIR)/%.lfs3.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(BUILDDIR)/%.lfs3.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

# limit .lfs2 files to lfs2 benches
$(BUILDDIR)/%.lfs2.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(BUILDDIR)/%.lfs2.b.c: %.c $(BENCHES_LFS2)
	./scripts/bench.py -c $(BENCHES_LFS2) -s $< $(BENCHCFLAGS) -o$@



#======================================================================#
# ok! with that out of the way, here's our actual benchmark rules      #
#======================================================================#

# bench.py flags
BENCHFLAGS += -b
# forward -j flag
BENCHFLAGS += $(filter -j%,$(MAKEFLAGS))
ifdef PERFGEN
BENCHFLAGS += -p$(BENCH_PERF)
endif
ifdef PERFBDGEN
BENCHFLAGS += -t$(BENCH_TRACE) --trace-backtrace --trace-freq=100
endif
ifdef VERBOSE
BENCHFLAGS  += -v
endif
ifdef EXEC
BENCHFLAGS += --exec="$(EXEC)"
endif
ifneq ($(GDB),gdb)
BENCHFLAGS += --gdb-path="$(GDB)"
endif
ifneq ($(VALGRIND),valgrind)
BENCHFLAGS += --valgrind-path="$(VALGRIND)"
endif
ifneq ($(PERF),perf)
BENCHFLAGS += --perf-path="$(PERF)"
endif


## Run all benchmarks!
.PHONY: bench bench-all
bench bench-all: \
		bench-internal \
		bench-many \
		bench-fwrite \
		bench-fwrite-tune \
		bench-vs-lfs2

## Run benchmarks over internal data structures
.PHONY: bench-internal
bench-internal: \
		bench-rbyd \
		bench-btree \
		bench-mtree

## Run benchmarks over rbyd operations
.PHONY: bench-rbyd
bench-rbyd: $(RESULTSDIR)/bench_rbyd.csv

## Run benchmarks over btree operations
.PHONY: bench-btree
bench-btree: $(RESULTSDIR)/bench_btree.csv

## Run benchmarks over mtree operations
.PHONY: bench-mtree
bench-mtree: $(RESULTSDIR)/bench_mtree.csv

## Plot benchmarks over file/dir creation
.PHONY: bench-many
bench-many: $(RESULTSDIR)/bench_many.csv

## Run benchmarks over file writes
.PHONY: bench-fwrite
bench-fwrite: $(RESULTSDIR)/bench_fwrite.csv

## Run file write benchmarks with tuneable configs
.PHONY: bench-fwrite-tune
bench-fwrite-tune: \
		bench-fwrite-tune-bs \
		bench-fwrite-tune-is \
		bench-fwrite-tune-fs \
		bench-fwrite-tune-ct

## Run file write benchmarks comparing block_sizes
.PHONY: bench-fwrite-tune-bs
bench-fwrite-tune-bs: $(RESULTSDIR)/bench_fwrite_tune_bs.csv

## Run file write benchmarks comparing inline_sizes
.PHONY: bench-fwrite-tune-is
bench-fwrite-tune-is: $(RESULTSDIR)/bench_fwrite_tune_is.csv

## Run file write benchmarks comparing fragment_sizes
.PHONY: bench-fwrite-tune-fs
bench-fwrite-tune-fs: $(RESULTSDIR)/bench_fwrite_tune_fs.csv

## Run file write benchmarks comparing crystal_threshs
.PHONY: bench-fwrite-tune-ct
bench-fwrite-tune-ct: $(RESULTSDIR)/bench_fwrite_tune_ct.csv

## Run benchmarks over littlefs v3 vs v2
.PHONY: bench-vs-lfs2
bench-vs-lfs2: \
		bench-vs-lfs2-counter \
		bench-vs-lfs2-many \
		bench-vs-lfs2-fwrite \
		bench-vs-lfs2-logging

## Run benchmarks v3 vs v2 comparing a simple counter
.PHONY: bench-vs-lfs2-counter
bench-vs-lfs2-counter: \
		$(foreach SIM, emmc nor nand, \
			$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.$(SIM).csv \
			$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.$(SIM).csv)

## Run benchmarks v3 vs v2 comparing many files
.PHONY: bench-vs-lfs2-many
bench-vs-lfs2-many: \
		$(foreach SIM, emmc nor nand, \
			$(RESULTSDIR)/bench_vs_lfs2_many.lfs3.$(SIM).csv \
			$(RESULTSDIR)/bench_vs_lfs2_many.lfs2.$(SIM).csv)

## Run benchmarks v3 vs v2 comparing file read/writes
.PHONY: bench-vs-lfs2-fwrite
bench-vs-lfs2-fwrite: \
		$(foreach SIM, emmc nor nand, \
			$(RESULTSDIR)/bench_vs_lfs2_fwrite.lfs3.$(SIM).csv \
			$(RESULTSDIR)/bench_vs_lfs2_fwrite.lfs2.$(SIM).csv)

## Run benchmarks v3 vs v2 comparing logging
.PHONY: bench-vs-lfs2-logging
bench-vs-lfs2-logging: \
		$(foreach SIM, emmc nor nand, \
			$(RESULTSDIR)/bench_vs_lfs2_logging.lfs3.$(SIM).csv \
			$(RESULTSDIR)/bench_vs_lfs2_logging.lfs2.$(SIM).csv)


# run the benches!
$(RESULTSDIR)/bench_rbyd.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_rbyd \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# per-attr results
#
# this breaks if the pattern is empty for some reason?
$(RESULTSDIR)/bench_rby%.per.csv: $(RESULTSDIR)/bench_rby%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Bm='%(m)s+per' \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed='float(bench_readed) / float(n)' \
		-fbench_proged='float(bench_proged) / float(n)' \
		-fbench_erased='float(bench_erased) / float(n)' \
		-o$@)

# run the benches!
$(RESULTSDIR)/bench_btree.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_btree \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# amortized results
$(RESULTSDIR)/bench_btre%.amor.csv: $(RESULTSDIR)/bench_btre%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=commit -Bm=commit+amor \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
		-o$@)

# byte-per-byte usage results
$(RESULTSDIR)/bench_btre%.per.csv: $(RESULTSDIR)/bench_btre%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=usage -Bm=usage+per \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed='float(bench_readed) / float(n)' \
		-fbench_proged='float(bench_proged) / float(n)' \
		-fbench_erased='float(bench_erased) / float(n)' \
		-o$@)

# run the benches!
$(RESULTSDIR)/bench_mtree.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_mtree \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# amortized results
$(RESULTSDIR)/bench_mtre%.amor.csv: $(RESULTSDIR)/bench_mtre%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=commit -Bm=commit+amor \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
		-o$@)

# byte-per-byte usage results
$(RESULTSDIR)/bench_mtre%.per.csv: $(RESULTSDIR)/bench_mtre%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=traversal,usage -Bm='%(m)s+per' \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed='float(bench_readed) / float(n)' \
		-fbench_proged='float(bench_proged) / float(n)' \
		-fbench_erased='float(bench_erased) / float(n)' \
		-o$@)

# run the benches!
$(RESULTSDIR)/bench_many.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_many \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# amortized results
$(RESULTSDIR)/bench_man%.amor.csv: $(RESULTSDIR)/bench_man%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=creat,mkdir -Bm='%(m)s+amor' \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
		-o$@)

# byte-per-byte usage results
$(RESULTSDIR)/bench_man%.per.csv: $(RESULTSDIR)/bench_man%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=traversal,usage -Bm='%(m)s+per' \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed='float(bench_readed) / float(n)' \
		-fbench_proged='float(bench_proged) / float(n)' \
		-fbench_erased='float(bench_erased) / float(n)' \
		-o$@)

# run the benches!
$(RESULTSDIR)/bench_fwrite.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_fwrite \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

$(RESULTSDIR)/bench_fwrite_tune_bs.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_fwrite \
		-DSEED="range($(SAMPLES))" \
		-DBLOCK_SIZE=$(BENCH_TUNE_BS) \
		$(BENCHFLAGS) \
		-o$@)

$(RESULTSDIR)/bench_fwrite_tune_is.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_fwrite \
		-DSEED="range($(SAMPLES))" \
		-DINLINE_SIZE=$(BENCH_TUNE_IS) \
		$(BENCHFLAGS) \
		-o$@)

$(RESULTSDIR)/bench_fwrite_tune_fs.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_fwrite \
		-DSEED="range($(SAMPLES))" \
		-DFRAGMENT_SIZE=$(BENCH_TUNE_FS) \
		$(BENCHFLAGS) \
		-o$@)

$(RESULTSDIR)/bench_fwrite_tune_ct.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_fwrite \
		-DSEED="range($(SAMPLES))" \
		-DCRYSTAL_THRESH=$(BENCH_TUNE_CT) \
		$(BENCHFLAGS) \
		-o$@)

# amortized results
#
# this breaks if the pattern is empty for some reason?
$(RESULTSDIR)/bench_fwrit%.amor.csv: $(RESULTSDIR)/bench_fwrit%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Dm=write -Bm=write+amor \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
		-o$@)

# byte-per-byte usage results
$(RESULTSDIR)/bench_fwrit%.per.csv: $(RESULTSDIR)/bench_fwrit%.csv
	$(strip ./scripts/csv.py $^ \
		-BREWRITE -BSIZE -Bn -Dm=usage -Bm=usage+per \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed='float(bench_readed) \
			/ float((REWRITE == 1) ? SIZE : n)' \
		-fbench_proged='float(bench_proged) \
			/ float((REWRITE == 1) ? SIZE : n)' \
		-fbench_erased='float(bench_erased) \
			/ float((REWRITE == 1) ? SIZE : n)' \
		-o$@)


# v3 vs v2 bench rules!
define BENCH_VS_LFS2_RULES

# the actual v3 vs v2 bench rules
$$(RESULTSDIR)/bench_vs_lfs2_counter.$(V).$(SIM).csv: $(V_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_vs_lfs2_counter \
		-DSEED="range($$(SAMPLES))" \
		-DREAD_SIZE=$(SIM_READ_SIZE) \
		-DPROG_SIZE=$(SIM_PROG_SIZE) \
		-DBLOCK_SIZE=$(SIM_ERASE_SIZE) \
		$$(BENCHFLAGS) \
		-o$$@)

$$(RESULTSDIR)/bench_vs_lfs2_many.$(V).$(SIM).csv: $(V_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_vs_lfs2_many \
		-DSEED="range($$(SAMPLES))" \
		-DREAD_SIZE=$(SIM_READ_SIZE) \
		-DPROG_SIZE=$(SIM_PROG_SIZE) \
		-DBLOCK_SIZE=$(SIM_ERASE_SIZE) \
		$$(BENCHFLAGS) \
		-o$$@)

$$(RESULTSDIR)/bench_vs_lfs2_fwrite.$(V).$(SIM).csv: $(V_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_vs_lfs2_fwrite \
		-DSEED="range($$(SAMPLES))" \
		-DREAD_SIZE=$(SIM_READ_SIZE) \
		-DPROG_SIZE=$(SIM_PROG_SIZE) \
		-DBLOCK_SIZE=$(SIM_ERASE_SIZE) \
		$$(BENCHFLAGS) \
		-o$$@)

$$(RESULTSDIR)/bench_vs_lfs2_logging.$(V).$(SIM).csv: $(V_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_vs_lfs2_logging \
		-DSEED="range($$(SAMPLES))" \
		-DREAD_SIZE=$(SIM_READ_SIZE) \
		-DPROG_SIZE=$(SIM_PROG_SIZE) \
		-DBLOCK_SIZE=$(SIM_ERASE_SIZE) \
		$$(BENCHFLAGS) \
		-o$$@)

# simulated/estimated results
$$(RESULTSDIR)/bench_vs_lfs%.$(SIM).sim.csv: \
		$$(RESULTSDIR)/bench_vs_lfs%.$(SIM).csv
	$$(strip ./scripts/csv.py $$^ \
		-Bm='%(m)s+sim' \
		-fbench_readed=' \
			(float(bench_readed)*float($(SIM_READ_TIME)) \
				+ float(bench_proged)*float($(SIM_PROG_TIME)) \
				+ float(bench_erased)*float($(SIM_ERASE_TIME)) \
				) / 1.0e9' \
		-fbench_proged=0 \
		-fbench_erased=0 \
		-fbench_creaded=' \
			(float(bench_creaded)*float($(SIM_READ_TIME)) \
				+ float(bench_cproged)*float($(SIM_PROG_TIME)) \
				+ float(bench_cerased)*float($(SIM_ERASE_TIME)) \
				) / 1.0e9' \
		-fbench_cproged=0 \
		-fbench_cerased=0 \
		-o$$@)

endef

# parameterize based on lfs3/lfs2 and sim type
$(foreach V_, lfs3/LFS3 lfs2/LFS2, \
	$(foreach V, $(word 1,$(subst /, ,$(V_))), \
	$(foreach V_RUNNER, $(if $(filter lfs3/%,$(V_)), \
			$$(BENCH_RUNNER), \
			$$(BENCH_LFS2_RUNNER)), \
	$(foreach SIM_, emmc/EMMC nor/NOR nand/NAND, \
		$(foreach SIM, $(word 1,$(subst /, ,$(SIM_))), \
		$(foreach SIM_READ_SIZE, \
			$$($(word 2,$(subst /, ,$(SIM_)))_READ_SIZE), \
		$(foreach SIM_PROG_SIZE, \
			$$($(word 2,$(subst /, ,$(SIM_)))_PROG_SIZE), \
		$(foreach SIM_ERASE_SIZE, \
			$$($(word 2,$(subst /, ,$(SIM_)))_ERASE_SIZE), \
		$(foreach SIM_READ_TIME, \
			$$($(word 2,$(subst /, ,$(SIM_)))_READ_TIME), \
		$(foreach SIM_PROG_TIME, \
			$$($(word 2,$(subst /, ,$(SIM_)))_PROG_TIME), \
		$(foreach SIM_ERASE_TIME, \
			$$($(word 2,$(subst /, ,$(SIM_)))_ERASE_TIME), \
		$(eval $(BENCH_VS_LFS2_RULES)))))))))))))

# amortized results
$(RESULTSDIR)/bench_vs_lfs%.amor.csv: $(RESULTSDIR)/bench_vs_lfs%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Bm='%(m)s+amor' \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
		-o$@)

# per-byte/entry usage results
$(RESULTSDIR)/bench_vs_lfs%.per.csv: $(RESULTSDIR)/bench_vs_lfs%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Bm='%(m)s+per' \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed='float(bench_readed) / float(n)' \
		-fbench_proged='float(bench_proged) / float(n)' \
		-fbench_erased='float(bench_erased) / float(n)' \
		-o$@)


# averaged results (over SAMPLES)
$(RESULTSDIR)/bench_%.avg.csv: $(RESULTSDIR)/bench_%.csv
	$(strip ./scripts/csv.py $^ \
		-DSEED='*' \
		-Dbench_creaded='*' \
		-Dbench_cproged='*' \
		-Dbench_cerased='*' \
		-fbench_readed_avg='avg(bench_readed)' \
		-fbench_proged_avg='avg(bench_proged)' \
		-fbench_erased_avg='avg(bench_erased)' \
		-fbench_readed_min='min(bench_readed)' \
		-fbench_proged_min='min(bench_proged)' \
		-fbench_erased_min='min(bench_erased)' \
		-fbench_readed_max='max(bench_readed)' \
		-fbench_proged_max='max(bench_proged)' \
		-fbench_erased_max='max(bench_erased)' \
		-o$@)



#======================================================================#
# and plotting rules, can't have benchmarks without plots!             #
#======================================================================#

# plot config
ifndef LIGHT
PLOTFLAGS += --dark
CODEMAPFLAGS += --dark
endif
ifdef GGPLOT
PLOTFLAGS += --ggplot
endif
ifdef XKCD
PLOTFLAGS += --xkcd
endif

ifdef LIGHT
PLOT_COLORS ?= \
		\#4c72b0bf $(if, blue    ) \
		\#dd8452bf $(if, orange  ) \
		\#55a868bf $(if, green   ) \
		\#c44e52bf $(if, red     ) \
		\#8172b3bf $(if, purple  ) \
		\#937860bf $(if, brown   ) \
		\#da8bc3bf $(if, pink    ) \
		\#8c8c8cbf $(if, gray    ) \
		\#ccb974bf $(if, yellow  ) \
		\#64b5cdbf $(if, cyan    )
else
PLOT_COLORS ?= \
		\#a1c9f4bf $(if, blue    ) \
		\#ffb482bf $(if, orange  ) \
		\#8de5a1bf $(if, green   ) \
		\#ff9f9bbf $(if, red     ) \
		\#d0bbffbf $(if, purple  ) \
		\#debb9bbf $(if, brown   ) \
		\#fab0e4bf $(if, pink    ) \
		\#cfcfcfbf $(if, gray    ) \
		\#fffea3bf $(if, yellow  ) \
		\#b9f2f0bf $(if, cyan    )
endif
PLOT_COLORS_1 := $(foreach C, $(PLOT_COLORS), \
		-C$C)
PLOT_COLORS_2 := $(foreach C, $(PLOT_COLORS), \
		-C$C \
		-C$C)
PLOT_COLORS_3 := $(foreach C, $(PLOT_COLORS), \
		-C$C \
		-C$C \
		-C$C)
PLOT_COLORS_1BND := $(foreach C, $(PLOT_COLORS), \
		-C$C -C$(C:bf=1f))
PLOT_COLORS_2BND := $(foreach C, $(PLOT_COLORS), \
		-C$C -C$(C:bf=1f) \
		-C$C -C$(C:bf=1f))
PLOT_COLORS_3BND := $(foreach C, $(PLOT_COLORS), \
		-C$C -C$(C:bf=1f) \
		-C$C -C$(C:bf=1f) \
		-C$C -C$(C:bf=1f))

# give some of the bigger subsystems explicit colors, to help with
# comparisons and to avoid similarly colored neighbors
ifdef LIGHT
CODEMAP_COLORS += -C'file=\#80be8e'   	   # was '#55a868bf', # green
CODEMAP_COLORS += -C'lfs*_file=\#80be8e'   # was '#55a868bf', # green
CODEMAP_COLORS += -C'lfs*_data=\#80be8e'   # was '#55a868bf', # green
CODEMAP_COLORS += -C'lfs*_mdir=\#d9cb97'   # was '#ccb974bf', # yellow
CODEMAP_COLORS += -C'lfs*_dir=\#d9cb97'    # was '#ccb974bf', # yellow
CODEMAP_COLORS += -C'lfs*_mtree=\#a195c6'  # was '#8172b3bf', # purple
CODEMAP_COLORS += -C'lfs*_btree=\#7995c4'  # was '#4c72b0bf', # blue
CODEMAP_COLORS += -C'lfs*_bshrub=\#8bc8da' # was '#64b5cdbf', # cyan
CODEMAP_COLORS += -C'lfs*_rbyd=\#d37a7d'   # was '#c44e52bf', # red
CODEMAP_COLORS += -C'lfs=\#ae9a88'         # was '#937860bf', # brown
CODEMAP_COLORS += -C'lfs1=\#ae9a88'        # was '#937860bf', # brown
CODEMAP_COLORS += -C'lfs2=\#ae9a88'        # was '#937860bf', # brown
CODEMAP_COLORS += -C'lfs3=\#ae9a88'        # was '#937860bf', # brown
CODEMAP_COLORS += -C'lfs*_fs=\#ae9a88'     # was '#937860bf', # brown
CODEMAP_COLORS += -C'lfs*_bd=\#a9a9a9'     # was '#8c8c8cbf', # gray
else
CODEMAP_COLORS += -C'file=\#6aac79'        # was '#8de5a1bf', # green
CODEMAP_COLORS += -C'lfs*_file=\#6aac79'   # was '#8de5a1bf', # green
CODEMAP_COLORS += -C'lfs*_data=\#6aac79'   # was '#8de5a1bf', # green
CODEMAP_COLORS += -C'lfs*_mdir=\#bfbe7a'   # was '#fffea3bf', # yellow
CODEMAP_COLORS += -C'lfs*_dir=\#bfbe7a'    # was '#fffea3bf', # yellow
CODEMAP_COLORS += -C'lfs*_mtree=\#9c8cbf'  # was '#d0bbffbf', # purple
CODEMAP_COLORS += -C'lfs*_btree=\#7997b7'  # was '#a1c9f4bf', # blue
CODEMAP_COLORS += -C'lfs*_bshrub=\#8bb5b4' # was '#b9f2f0bf', # cyan
CODEMAP_COLORS += -C'lfs*_rbyd=\#bf7774'   # was '#ff9f9bbf', # red
CODEMAP_COLORS += -C'lfs=\#a68c74'         # was '#debb9bbf', # brown
CODEMAP_COLORS += -C'lfs1=\#a68c74'        # was '#debb9bbf', # brown
CODEMAP_COLORS += -C'lfs2=\#a68c74'        # was '#debb9bbf', # brown
CODEMAP_COLORS += -C'lfs3=\#a68c74'        # was '#debb9bbf', # brown
CODEMAP_COLORS += -C'lfs*_fs=\#a68c74'     # was '#debb9bbf', # brown
CODEMAP_COLORS += -C'lfs*_bd=\#9b9b9b'     # was '#cfcfcfbf', # gray
endif



## Plot all benchmarks!
.PHONY: all plot plot-all
all plot plot-all: \
		plot-codemap \
		plot-internal \
		plot-many \
		plot-fwrite \
		plot-fwrite-tune \
		plot-vs-lfs2

## Generate codemaps
# ok, it's not really a plot, but gotta put this somewhere
.PHONY: codemap plot-codemap
codemap plot-codemap: \
		$(PLOTSDIR)/codemap_lfs3_tiny.svg \
		$(PLOTSDIR)/codemap_lfs2_tiny.svg \
		$(PLOTSDIR)/codemap_lfs1_tiny.svg \
		$(PLOTSDIR)/codemap_lfs3.svg \
		$(PLOTSDIR)/codemap_lfs2.svg \
		$(PLOTSDIR)/codemap_lfs1.svg

## Plot benchmarks over internal data structures
.PHONY: plot-internal
plot-internal: \
		plot-rbyd \
		plot-btree \
		plot-mtree

## Plot benchmarks over rbyd operations
.PHONY: plot-rbyd
plot-rbyd: \
		$(PLOTSDIR)/bench_rbyd_attr.svg \
		$(PLOTSDIR)/bench_rbyd_id.svg

## Plot benchmarks over btree operations
.PHONY: plot-btree
plot-btree: \
		$(PLOTSDIR)/bench_btree_btree.svg \
		$(PLOTSDIR)/bench_btree_namedbtree.svg

## Plot benchmarks over mtree operations
.PHONY: plot-mtree
plot-mtree: \
		$(PLOTSDIR)/bench_mtree.svg

## Plot benchmarks over file/dir creation
.PHONY: plot-many
plot-many: \
		$(PLOTSDIR)/bench_many_files.svg \
		$(PLOTSDIR)/bench_many_dirs.svg

## Plot benchmarks over file writes
.PHONY: plot-fwrite
plot-fwrite: \
		$(PLOTSDIR)/bench_fwrite_sparseish.svg \
		$(PLOTSDIR)/bench_fwrite_rewrite.svg \
		$(PLOTSDIR)/bench_fwrite_incrrewrite.svg \
		$(PLOTSDIR)/bench_fwrite_linear.svg \
		$(PLOTSDIR)/bench_fwrite_random.svg

## Plot file write benchmarks with tuneable configs
.PHONY: plot-fwrite-tune
plot-fwrite-tune: \
		plot-fwrite-tune-bs \
		plot-fwrite-tune-is \
		plot-fwrite-tune-fs \
		plot-fwrite-tune-ct

## Plot file write benchmarks comparing block_sizes
.PHONY: plot-fwrite-tune-bs
plot-fwrite-tune-bs: \
		$(PLOTSDIR)/bench_fwrite_tune_bs_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_bs_random.svg

## Plot file write benchmarks comparing inline_sizes
.PHONY: plot-fwrite-tune-is
plot-fwrite-tune-is: \
		$(PLOTSDIR)/bench_fwrite_tune_is_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_is_random.svg

## Plot file write benchmarks comparing fragment_sizes
.PHONY: plot-fwrite-tune-fs
plot-fwrite-tune-fs: \
		$(PLOTSDIR)/bench_fwrite_tune_fs_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_fs_random.svg

## Plot file write benchmarks comparing crystal_threshs
.PHONY: plot-fwrite-tune-ct
plot-fwrite-tune-ct: \
		$(PLOTSDIR)/bench_fwrite_tune_ct_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_ct_random.svg

## Plot benchmarks over littlefs v3 vs v2
.PHONY: plot-vs-lfs2
plot-vs-lfs2: \
		plot-vs-lfs2-counter \
		plot-vs-lfs2-many \
		plot-vs-lfs2-fwrite \
		plot-vs-lfs2-logging

## Plot benchmarks v3 vs v2 comparing a simple counter
.PHONY: plot-vs-lfs2-counter
plot-vs-lfs2-counter: \
		$(PLOTSDIR)/bench_vs_lfs2_counter_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_counter_p.svg \
		$(PLOTSDIR)/bench_vs_lfs2_counter_e.svg \
		$(PLOTSDIR)/bench_vs_lfs2_counter_u.svg \
		$(PLOTSDIR)/bench_vs_lfs2_counter.svg

## Plot benchmarks v3 vs v2 comparing many files
.PHONY: plot-vs-lfs2-many
plot-vs-lfs2-many: \
		plot-vs-lfs2-many-creat \
		plot-vs-lfs2-many-open \
		plot-vs-lfs2-many-usage

## Plot benchmarks v3 vs v2 comparing many file creation
.PHONY: plot-vs-lfs2-many-creat
plot-vs-lfs2-many-creat: \
		$(PLOTSDIR)/bench_vs_lfs2_many_creat_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_many_creat_p.svg \
		$(PLOTSDIR)/bench_vs_lfs2_many_creat_e.svg \
		$(PLOTSDIR)/bench_vs_lfs2_many_creat.svg

## Plot benchmarks v3 vs v2 comparing many file open+read
.PHONY: plot-vs-lfs2-many-open
plot-vs-lfs2-many-open: \
		$(PLOTSDIR)/bench_vs_lfs2_many_open_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_many_open.svg

## Plot benchmarks v3 vs v2 comparing many file usage
.PHONY: plot-vs-lfs2-many-usage
plot-vs-lfs2-many-usage: \
		$(PLOTSDIR)/bench_vs_lfs2_many_usage.svg

## Plot benchmarks v3 vs v2 comparing file reads/writes
.PHONY: plot-vs-lfs2-fwrite
plot-vs-lfs2-fwrite: \
		plot-vs-lfs2-fwrite-linear-write \
		plot-vs-lfs2-fwrite-linear-read \
		plot-vs-lfs2-fwrite-linear-usage \
		plot-vs-lfs2-fwrite-random-write \
		plot-vs-lfs2-fwrite-random-read \
		plot-vs-lfs2-fwrite-random-usage

## Plot benchmarks v3 vs v2 comparing linear file writes
.PHONY: plot-vs-lfs2-fwrite-linear-write
plot-vs-lfs2-fwrite-linear-write: \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_write_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_write_p.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_write_e.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_write.svg

## Plot benchmarks v3 vs v2 comparing linear file reads
.PHONY: plot-vs-lfs2-fwrite-linear-read
plot-vs-lfs2-fwrite-linear-read: \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_read_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_read.svg

## Plot benchmarks v3 vs v2 comparing linear file usage
.PHONY: plot-vs-lfs2-fwrite-linear-usage
plot-vs-lfs2-fwrite-linear-usage: \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_linear_usage.svg

## Plot benchmarks v3 vs v2 comparing random file writes
.PHONY: plot-vs-lfs2-fwrite-random-write
plot-vs-lfs2-fwrite-random-write: \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_write_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_write_p.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_write_e.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_write.svg

## Plot benchmarks v3 vs v2 comparing random file reads
.PHONY: plot-vs-lfs2-fwrite-random-read
plot-vs-lfs2-fwrite-random-read: \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_read_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_read.svg

## Plot benchmarks v3 vs v2 comparing random file usage
.PHONY: plot-vs-lfs2-fwrite-random-usage
plot-vs-lfs2-fwrite-random-usage: \
		$(PLOTSDIR)/bench_vs_lfs2_fwrite_random_usage.svg

## Plot benchmarks v3 vs v2 comparing logging
.PHONY: plot-vs-lfs2-logging
plot-vs-lfs2-logging: \
		plot-vs-lfs2-logging-write \
		plot-vs-lfs2-logging-usage

## Plot benchmarks v3 vs v2 comparing logging writes
.PHONY: plot-vs-lfs2-logging-write
plot-vs-lfs2-logging-write: \
		$(PLOTSDIR)/bench_vs_lfs2_logging_write_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_logging_write_p.svg \
		$(PLOTSDIR)/bench_vs_lfs2_logging_write_e.svg \
		$(PLOTSDIR)/bench_vs_lfs2_logging_write.svg

## Plot benchmarks v3 vs v2 comparing logging usage
.PHONY: plot-vs-lfs2-logging-usage
plot-vs-lfs2-logging-usage: \
		$(PLOTSDIR)/bench_vs_lfs2_logging_usage.svg



# plot rules

# codemap rules!
define CODEMAP_RULES

$$(PLOTSDIR)/codemap_$(V).svg: $(V_OBJ) $(V_CI)
	$$(strip ./scripts/codemapsvg.py $$^ \
		--title="$(V) code %(code)s stack %(stack)s ctx %(ctx)s" \
		-W1750 -H750 \
		$$(CODEMAP_COLORS) \
		$$(CODEMAPFLAGS) \
		-o$$@ \
		&& ./scripts/codemap.py $$^ --no-header)

$$(PLOTSDIR)/codemap_$(V)_tiny.svg: $(V_OBJ) $(V_CI)
	$$(strip ./scripts/codemapsvg.py $$^ \
		--tiny --background=\#00000000 \
		$$(CODEMAP_COLORS) \
		$$(CODEMAPFLAGS) \
		-o$$@ \
		&& ./scripts/codemap.py $$^ --no-header)

endef

# parameterize based on lfs3/lfs2/lfs1
$(foreach V_, lfs3/LFS3 lfs2/LFS2 lfs1/LFS1, \
	$(foreach V, $(word 1,$(subst /, ,$(V_))), \
	$(foreach V_OBJ, $(if $(filter lfs3/%,$(V_)), \
			$$(CODEMAP_OBJ), \
			$(if $(filter lfs2/%,$(V_)), \
				$$(CODEMAP_LFS2_OBJ), \
				$$(CODEMAP_LFS1_OBJ))), \
	$(foreach V_CI, $(if $(filter lfs3/%,$(V_)), \
			$$(CODEMAP_CI), \
			$(if $(filter lfs2/%,$(V_)), \
				$$(CODEMAP_LFS2_CI), \
				$$(CODEMAP_LFS1_CI))), \
	$(eval $(CODEMAP_RULES))))))



# plot bench_rbyd config
PLOT_RBYD_FLAGS += -W1750 -H750
PLOT_RBYD_FLAGS += --y2 --yunits=B
PLOT_RBYD_FLAGS += \
		--subplot=" \
				-Dm=$1 \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_readed \
				--title=$1 \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=$1 \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--ylabel=bench_proged" \
		--subplot-right=" \
				-Dm=$2 \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=$2 \
				--add-xticklabel= \
				-W0.5 \
			--subplot-below=\" \
				-Dm=$2 \
				-ybench_proged_avg \
				-ybench_proged_bnd\""if
		--subplot-right=" \
				-Dm=fetch+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='fetch (per-attr)' \
				--add-xticklabel= \
				-W0.33 \
			--subplot-below=\" \
				-Dm=fetch+per \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1\"" \
		--subplot-right=" \
				-Dm=lookup \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=lookup \
				--add-xticklabel= \
				-W0.25 \
			--subplot-below=\" \
				-Dm=lookup \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1\"" \
		--subplot-right=" \
				-Dm=usage+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (per-attr)' \
				--add-xticklabel= \
				-W0.20 \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (total)'\""
PLOT_RBYD_FLAGS += $(PLOT_COLORS_2BND)

# rbyd attr operations
$(PLOTSDIR)/bench_rbyd_attr.svg: \
		$(RESULTSDIR)/bench_rbyd.avg.csv \
		$(RESULTSDIR)/bench_rbyd.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="rbyd attr operations" \
		-Dcase='bench_rbyd_attr_*' \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		$(call PLOT_RBYD_FLAGS,append,remove) \
		$(PLOTFLAGS) \
		-o$@)

# rbyd id operations
$(PLOTSDIR)/bench_rbyd_id.svg: \
		$(RESULTSDIR)/bench_rbyd.avg.csv \
		$(RESULTSDIR)/bench_rbyd.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="rbyd id operations" \
		-Dcase='bench_rbyd_id_*' \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		$(call PLOT_RBYD_FLAGS,create,delete) \
		$(PLOTFLAGS) \
		-o$@)


# plot bench_btree config
PLOT_BTREE_FLAGS += -W1750 -H750
PLOT_BTREE_FLAGS += --y2 --yunits=B
PLOT_BTREE_FLAGS += \
		--subplot=" \
				-Dm=commit \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_readed \
				--title=commit \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=commit \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--ylabel=bench_proged \
				-H0.5" \
			--subplot-below=" \
				-Dm=commit \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				--ylabel=bench_erased \
				-H0.33" \
		--subplot-right=" \
				-Dm=commit+amor \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='commit (amortized)' \
				--add-xticklabel= \
				-W0.5 \
			--subplot-below=\" \
				-Dm=commit+amor \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=commit+amor \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-H0.33\"" \
		$(if $1, \
		--subplot-right=" \
				-Dm=namelookup \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=namelookup \
				--add-xticklabel= \
				-W0.33 \
			--subplot-below=\" \
				-Dm=namelookup \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0$(,)1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=namelookup \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0$(,)1 \
				-H0.33\"",) \
		--subplot-right=" \
				-Dm=lookup \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=lookup \
				--add-xticklabel= \
				-W$(if $1,0.25,0.33) \
			--subplot-below=\" \
				-Dm=lookup \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=lookup \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=usage+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (per-entry)' \
				--add-xticklabel= \
				--ylim-stddev=3 \
				-W$(if $1,0.20,0.25) \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (total)' \
				-H0.665\""
PLOT_BTREE_FLAGS += $(PLOT_COLORS_3BND)

# btree operations
$(PLOTSDIR)/bench_btree_btree.svg: \
		$(RESULTSDIR)/bench_btree.avg.csv \
		$(RESULTSDIR)/bench_btree.amor.avg.csv \
		$(RESULTSDIR)/bench_btree.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="btree operations" \
		-Dcase=bench_btree_btree \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L0,bench_erased_avg= \
		-L0,bench_erased_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L1,bench_erased_avg= \
		-L1,bench_erased_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		-L2,bench_erased_avg= \
		-L2,bench_erased_bnd= \
		$(call PLOT_BTREE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# named btree operations
$(PLOTSDIR)/bench_btree_namedbtree.svg: \
		$(RESULTSDIR)/bench_btree.avg.csv \
		$(RESULTSDIR)/bench_btree.amor.avg.csv \
		$(RESULTSDIR)/bench_btree.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="named btree operations" \
		-Dcase=bench_btree_namedbtree \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L0,bench_erased_avg= \
		-L0,bench_erased_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L1,bench_erased_avg= \
		-L1,bench_erased_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		-L2,bench_erased_avg= \
		-L2,bench_erased_bnd= \
		$(call PLOT_BTREE_FLAGS,named) \
		$(PLOTFLAGS) \
		-o$@)


# plot bench_mtree config
PLOT_MTREE_FLAGS += -W1750 -H750
PLOT_MTREE_FLAGS += --y2 --yunits=B
PLOT_MTREE_FLAGS += \
		--subplot=" \
				-Dm=commit \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_readed \
				--title=commit \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=commit \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--ylabel=bench_proged \
				-H0.5" \
			--subplot-below=" \
				-Dm=commit \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				--ylabel=bench_erased \
				-H0.33" \
		--subplot-right=" \
				-Dm=commit+amor \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='commit (amortized)' \
				--add-xticklabel= \
				-W0.5 \
			--subplot-below=\" \
				-Dm=commit+amor \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=commit+amor \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=namelookup \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=namelookup \
				--add-xticklabel= \
				-W0.33 \
			--subplot-below=\" \
				-Dm=namelookup \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=namelookup \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=lookup \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=lookup \
				--add-xticklabel= \
				-W0.25 \
			--subplot-below=\" \
				-Dm=lookup \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=lookup \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=traversal+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='traversal (per-entry)' \
				--add-xticklabel= \
				-W0.20 \
			--subplot-below=\" \
				-Dm=traversal+per \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=traversal+per \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=usage+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (per-entry)' \
				--add-xticklabel= \
				--ylim-stddev=3 \
				-W0.16 \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (total)' \
				-H0.665\""
PLOT_MTREE_FLAGS += $(PLOT_COLORS_3BND)

# mtree operations
$(PLOTSDIR)/bench_mtree.svg: \
		$(RESULTSDIR)/bench_mtree.avg.csv \
		$(RESULTSDIR)/bench_mtree.amor.avg.csv \
		$(RESULTSDIR)/bench_mtree.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="mtree operations" \
		-Dcase=bench_mtree \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L0,bench_erased_avg= \
		-L0,bench_erased_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L1,bench_erased_avg= \
		-L1,bench_erased_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		-L2,bench_erased_avg= \
		-L2,bench_erased_bnd= \
		$(PLOT_MTREE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)


# plot bench_many config
PLOT_MANY_FLAGS += -W1750 -H750
PLOT_MANY_FLAGS += --y2 --yunits=B
PLOT_MANY_FLAGS += \
		--subplot=" \
				-Dm=$1 \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_readed \
				--title=$1 \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=$1 \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--ylabel=bench_proged \
				-H0.5" \
			--subplot-below=" \
				-Dm=$1 \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				--ylabel=bench_erased \
				-H0.33" \
		--subplot-right=" \
				-Dm=$1+amor \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='$1 (amortized)' \
				--add-xticklabel= \
				-W0.5 \
			--subplot-below=\" \
				-Dm=$1+amor \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=$1+amor \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=read \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title=read \
				--add-xticklabel= \
				-W0.33 \
			--subplot-below=\" \
				-Dm=read \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=read \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=traversal+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='traversal (per-entry)' \
				--add-xticklabel= \
				-W0.25 \
			--subplot-below=\" \
				-Dm=traversal+per \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				-Y0,1 \
				-H0.5\" \
			--subplot-below=\" \
				-Dm=traversal+per \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=usage+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (per-entry)' \
				--add-xticklabel= \
				-Y0,2048 \
				-W0.20 \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=bench_usage \
				--title='usage (total)' \
				-H0.665\""
PLOT_MANY_FLAGS += $(PLOT_COLORS_3BND)

# many files
$(PLOTSDIR)/bench_many_files.svg: \
		$(RESULTSDIR)/bench_many.avg.csv \
		$(RESULTSDIR)/bench_many.amor.avg.csv \
		$(RESULTSDIR)/bench_many.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="many files" \
		-Dcase=bench_many_files \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L0,bench_erased_avg= \
		-L0,bench_erased_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L1,bench_erased_avg= \
		-L1,bench_erased_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		-L2,bench_erased_avg= \
		-L2,bench_erased_bnd= \
		$(call PLOT_MANY_FLAGS,creat) \
		$(PLOTFLAGS) \
		-o$@)

# many dirs
$(PLOTSDIR)/bench_many_dirs.svg: \
		$(RESULTSDIR)/bench_many.avg.csv \
		$(RESULTSDIR)/bench_many.amor.avg.csv \
		$(RESULTSDIR)/bench_many.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="many dirs" \
		-Dcase=bench_many_dirs \
		-bORDER \
		-xn \
		--legend \
		-L0,bench_readed_avg=inorder \
		-L0,bench_readed_bnd= \
		-L0,bench_proged_avg= \
		-L0,bench_proged_bnd= \
		-L0,bench_erased_avg= \
		-L0,bench_erased_bnd= \
		-L1,bench_readed_avg=reversed \
		-L1,bench_readed_bnd= \
		-L1,bench_proged_avg= \
		-L1,bench_proged_bnd= \
		-L1,bench_erased_avg= \
		-L1,bench_erased_bnd= \
		-L2,bench_readed_avg=random \
		-L2,bench_readed_bnd= \
		-L2,bench_proged_avg= \
		-L2,bench_proged_bnd= \
		-L2,bench_erased_avg= \
		-L2,bench_erased_bnd= \
		$(call PLOT_MANY_FLAGS,mkdir) \
		$(PLOTFLAGS) \
		-o$@)


# plot bench_fwrite config
PLOT_FWRITE_FLAGS += -W1750 -H750
PLOT_FWRITE_FLAGS += --x2 --xunits=B
PLOT_FWRITE_FLAGS += --y2 --yunits=B
PLOT_FWRITE_FLAGS += \
		--subplot=" \
				-Dm=write \
				-ybench_readed_avg \
				$(if $1,-ybench_readed_bnd) \
				--ylabel=readed \
				--title='write' \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=write \
				-ybench_proged_avg \
				$(if $1,-ybench_proged_bnd) \
				--ylabel=proged \
				--add-xticklabel= \
				-H0.5 " \
			--subplot-below=" \
				-Dm=write \
				-ybench_erased_avg \
				$(if $1,-ybench_erased_bnd) \
				--ylabel=erased \
				-H0.33" \
		--subplot-right=" \
				-Dm=write+amor \
				-ybench_readed_avg \
				$(if $1,-ybench_readed_bnd) \
				--title='write (amortized)' \
				--add-xticklabel= \
				-W0.5 \
			--subplot-below=\" \
				-Dm=write+amor \
				-ybench_proged_avg \
				$(if $1,-ybench_proged_bnd) \
				--add-xticklabel= \
				-H0.5 \" \
			--subplot-below=\" \
				-Dm=write+amor \
				-ybench_erased_avg \
				$(if $1,-ybench_erased_bnd) \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=read \
				-ybench_readed_avg \
				$(if $1,-ybench_readed_bnd) \
				--title='read' \
				--add-xticklabel= \
				-W0.33 \
			--subplot-below=\" \
				-Dm=read \
				-ybench_proged_avg \
				$(if $1,-ybench_proged_bnd) \
				--add-xticklabel= \
				-Y0,1 \
				-H0.5 \" \
			--subplot-below=\" \
				-Dm=read \
				-ybench_erased_avg \
				$(if $1,-ybench_erased_bnd) \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=usage+per \
				-ybench_readed_avg \
				$(if $1,-ybench_readed_bnd) \
				--ylabel=usage \
				--title='usage (per-byte)' \
				--add-xticklabel= \
				--ylim-stddev=3 \
				-W0.25 \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				$(if $1,-ybench_readed_bnd) \
				--ylabel=usage \
				--title='usage (total)' \
				-H0.665\""
PLOT_FWRITE_FLAGS += $(if $1,$(PLOT_COLORS_3BND),$(PLOT_COLORS_3))

# file writes - sparse/incremental
$(PLOTSDIR)/bench_fwrite_sparseish.svg: \
		$(RESULTSDIR)/bench_fwrite.avg.csv \
		$(RESULTSDIR)/bench_fwrite.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file writes - sparse/incremental" \
		-bORDER \
		-DREWRITE=0 \
		-xn \
		--legend \
		-L'0,bench_readed_avg=inorder' \
		-L'0,bench_readed_bnd=' \
		-L'0,bench_proged_avg=' \
		-L'0,bench_proged_bnd=' \
		-L'0,bench_erased_avg=' \
		-L'0,bench_erased_bnd=' \
		-L'1,bench_readed_avg=reversed' \
		-L'1,bench_readed_bnd=' \
		-L'1,bench_proged_avg=' \
		-L'1,bench_proged_bnd=' \
		-L'1,bench_erased_avg=' \
		-L'1,bench_erased_bnd=' \
		-L'2,bench_readed_avg=random aligned' \
		-L'2,bench_readed_bnd=' \
		-L'2,bench_proged_avg=' \
		-L'2,bench_proged_bnd=' \
		-L'2,bench_erased_avg=' \
		-L'2,bench_erased_bnd=' \
		-L'3,bench_readed_avg=random unaligned' \
		-L'3,bench_readed_bnd=' \
		-L'3,bench_proged_avg=' \
		-L'3,bench_proged_bnd=' \
		-L'3,bench_erased_avg=' \
		-L'3,bench_erased_bnd=' \
		$(call PLOT_FWRITE_FLAGS,bnd) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - rewriting
$(PLOTSDIR)/bench_fwrite_rewrite.svg: \
		$(RESULTSDIR)/bench_fwrite.avg.csv \
		$(RESULTSDIR)/bench_fwrite.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file writes - rewriting" \
		-bORDER \
		-DREWRITE=1 \
		-xn \
		--legend \
		-L'0,bench_readed_avg=inorder' \
		-L'0,bench_readed_bnd=' \
		-L'0,bench_proged_avg=' \
		-L'0,bench_proged_bnd=' \
		-L'0,bench_erased_avg=' \
		-L'0,bench_erased_bnd=' \
		-L'1,bench_readed_avg=reversed' \
		-L'1,bench_readed_bnd=' \
		-L'1,bench_proged_avg=' \
		-L'1,bench_proged_bnd=' \
		-L'1,bench_erased_avg=' \
		-L'1,bench_erased_bnd=' \
		-L'2,bench_readed_avg=random aligned' \
		-L'2,bench_readed_bnd=' \
		-L'2,bench_proged_avg=' \
		-L'2,bench_proged_bnd=' \
		-L'2,bench_erased_avg=' \
		-L'2,bench_erased_bnd=' \
		-L'3,bench_readed_avg=random unaligned' \
		-L'3,bench_readed_bnd=' \
		-L'3,bench_proged_avg=' \
		-L'3,bench_proged_bnd=' \
		-L'3,bench_erased_avg=' \
		-L'3,bench_erased_bnd=' \
		$(call PLOT_FWRITE_FLAGS,bnd) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - incremental rewriting
$(PLOTSDIR)/bench_fwrite_incrrewrite.svg: \
		$(RESULTSDIR)/bench_fwrite.avg.csv \
		$(RESULTSDIR)/bench_fwrite.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file writes - incremental rewriting" \
		-bORDER \
		-DREWRITE=2 \
		-xn \
		--legend \
		-L'0,bench_readed_avg=inorder' \
		-L'0,bench_readed_bnd=' \
		-L'0,bench_proged_avg=' \
		-L'0,bench_proged_bnd=' \
		-L'0,bench_erased_avg=' \
		-L'0,bench_erased_bnd=' \
		-L'1,bench_readed_avg=reversed' \
		-L'1,bench_readed_bnd=' \
		-L'1,bench_proged_avg=' \
		-L'1,bench_proged_bnd=' \
		-L'1,bench_erased_avg=' \
		-L'1,bench_erased_bnd=' \
		-L'2,bench_readed_avg=random aligned' \
		-L'2,bench_readed_bnd=' \
		-L'2,bench_proged_avg=' \
		-L'2,bench_proged_bnd=' \
		-L'2,bench_erased_avg=' \
		-L'2,bench_erased_bnd=' \
		-L'3,bench_readed_avg=random unaligned' \
		-L'3,bench_readed_bnd=' \
		-L'3,bench_proged_avg=' \
		-L'3,bench_proged_bnd=' \
		-L'3,bench_erased_avg=' \
		-L'3,bench_erased_bnd=' \
		$(call PLOT_FWRITE_FLAGS,bnd) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - linear
$(PLOTSDIR)/bench_fwrite_linear.svg: \
		$(RESULTSDIR)/bench_fwrite.avg.csv \
		$(RESULTSDIR)/bench_fwrite.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file writes - linear" \
		-DORDER=0 \
		-DREWRITE=0 \
		-xn \
		-L'bench_readed_avg=linear' \
		-L'bench_readed_bnd=' \
		-L'bench_proged_avg=' \
		-L'bench_proged_bnd=' \
		-L'bench_erased_avg=' \
		-L'bench_erased_bnd=' \
		$(call PLOT_FWRITE_FLAGS,bnd) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - random
$(PLOTSDIR)/bench_fwrite_random.svg: \
		$(RESULTSDIR)/bench_fwrite.avg.csv \
		$(RESULTSDIR)/bench_fwrite.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-Dbench_proged_avg='*' \
			-Dbench_erased_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file writes - random" \
		-DORDER=3 \
		-DREWRITE=2 \
		-xn \
		-L'bench_readed_avg=random' \
		-L'bench_readed_bnd=' \
		-L'bench_proged_avg=' \
		-L'bench_proged_bnd=' \
		-L'bench_erased_avg=' \
		-L'bench_erased_bnd=' \
		$(call PLOT_FWRITE_FLAGS,bnd) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - block_size - linear
$(PLOTSDIR)/bench_fwrite_tune_bs_linear.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_bs.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_bs.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_bs.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - block_size - linear" \
		-DORDER=0 \
		-DREWRITE=0 \
		-bBLOCK_SIZE \
		-xn \
		--legend \
		-sBLOCK_SIZE \
		-L'*,bench_readed_avg=bs=%(BLOCK_SIZE)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - block_size - random
$(PLOTSDIR)/bench_fwrite_tune_bs_random.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_bs.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_bs.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_bs.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - block_size - random" \
		-DORDER=3 \
		-DREWRITE=2 \
		-bBLOCK_SIZE \
		-xn \
		--legend \
		-sBLOCK_SIZE \
		-L'*,bench_readed_avg=bs=%(BLOCK_SIZE)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - inline_size - linear
$(PLOTSDIR)/bench_fwrite_tune_is_linear.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_is.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_is.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_is.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^  \
		--title="file writes - inline_size - linear" \
		-DORDER=0 \
		-DREWRITE=0 \
		-bINLINE_SIZE \
		-xn \
		--legend \
		-sINLINE_SIZE \
		-L'*,bench_readed_avg=is=%(INLINE_SIZE)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - inline_size - random
$(PLOTSDIR)/bench_fwrite_tune_is_random.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_is.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_is.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_is.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - inline_size - random" \
		-DORDER=3 \
		-DREWRITE=2 \
		-bINLINE_SIZE \
		-xn \
		--legend \
		-sINLINE_SIZE \
		-L'*,bench_readed_avg=is=%(INLINE_SIZE)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - fragment_size - linear
$(PLOTSDIR)/bench_fwrite_tune_fs_linear.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_fs.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_fs.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_fs.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - fragment_size - linear" \
		-DORDER=0 \
		-DREWRITE=0 \
		-bFRAGMENT_SIZE \
		-xn \
		--legend \
		-sFRAGMENT_SIZE \
		-L'*,bench_readed_avg=fs=%(FRAGMENT_SIZE)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - fragment_size - random
$(PLOTSDIR)/bench_fwrite_tune_fs_random.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_fs.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_fs.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_fs.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - fragment_size - random" \
		-DORDER=3 \
		-DREWRITE=2 \
		-bFRAGMENT_SIZE \
		-xn \
		--legend \
		-sFRAGMENT_SIZE \
		-L'*,bench_readed_avg=fs=%(FRAGMENT_SIZE)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - crystal_thresh - linear
$(PLOTSDIR)/bench_fwrite_tune_ct_linear.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_ct.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_ct.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_ct.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - crystal_thresh - linear" \
		-DORDER=0 \
		-DREWRITE=0 \
		-bCRYSTAL_THRESH \
		-xn \
		--legend \
		-sCRYSTAL_THRESH \
		-L'*,bench_readed_avg=ct=%(CRYSTAL_THRESH)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)

# file writes - crystal_thresh - random
$(PLOTSDIR)/bench_fwrite_tune_ct_random.svg: \
		$(RESULTSDIR)/bench_fwrite_tune_ct.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_ct.amor.avg.csv \
		$(RESULTSDIR)/bench_fwrite_tune_ct.per.avg.csv
	$(strip ./scripts/plotmpl.py \
		$^ \
		--title="file writes - crystal_thresh - random" \
		-DORDER=3 \
		-DREWRITE=2 \
		-bCRYSTAL_THRESH \
		-xn \
		--legend \
		-sCRYSTAL_THRESH \
		-L'*,bench_readed_avg=ct=%(CRYSTAL_THRESH)s' \
		-L'*,bench_proged_avg=' \
		-L'*,bench_erased_avg=' \
		$(call PLOT_FWRITE_FLAGS) \
		$(PLOTFLAGS) \
		-o$@)



# vs lfs plot rules!

# plot vs lfs2 config
PLOT_VS_LFS2_FLAGS += -W1750 -H750
PLOT_VS_LFS2_FLAGS += \
		--subplot=" \
				-DBLOCK_SIZE=$(EMMC_ERASE_SIZE) \
				-Dm=$2 \
				$(if $(filter amor,$3),--ylabel=raw) \
				$(if $(filter per,$3),--ylabel=total) \
				--title=sd/emmc \
				$(if $3,--add-xticklabel=,)" \
			$(if $3, \
			--subplot-below=" \
				-DBLOCK_SIZE=$(EMMC_ERASE_SIZE) \
				-Dm=$2+$3 \
				$(if $(filter amor,$3),--ylabel=amortized) \
				$(if $(filter per,$3),--ylabel=per) \
				--ylim-stddev=3 \
				-H0.5",) \
		--subplot-right=" \
				-DBLOCK_SIZE=$(NOR_ERASE_SIZE) \
				-Dm=$2 \
				--title=nor \
				$(if $3,--add-xticklabel=,) \
				-W0.5 \
			$(if $3, \
			--subplot-below=\" \
				-DBLOCK_SIZE=$(NOR_ERASE_SIZE) \
				-Dm=$2+$3 \
				--ylim-stddev=3 \
				-H0.5\",)" \
		--subplot-right=" \
				-DBLOCK_SIZE=$(NAND_ERASE_SIZE) \
				-Dm=$2 \
				--title=nand \
				$(if $3,--add-xticklabel=,) \
				-W0.33 \
			$(if $3, \
			--subplot-below=\" \
				-DBLOCK_SIZE=$(NAND_ERASE_SIZE) \
				-Dm=$2+$3 \
				--ylim-stddev=3 \
				-H0.5\",)"
PLOT_VS_LFS2_FLAGS += $(PLOT_COLORS_1BND)

# lfs3 (no bmap) vs lfs2 rules
define PLOT_VS_LFS2_RULE
$$(PLOTSDIR)/bench_vs_lfs2_$1.svg: \
		$$(foreach V, lfs3 lfs2, \
			$$(foreach SIM, emmc nor nand, \
				$(foreach BENCH, $2, \
					$$(RESULTSDIR)/bench_vs_lfs2_$(BENCH).avg.csv)))
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-f$4_avg \
			-f$4_bnd=$4_min \
			-o-) \
		<(./scripts/csv.py $$^ \
			-D$4_avg='*' \
			-f$4_bnd=$4_max \
			-o-) \
		--title=$3 \
		-bV -SV \
		-xn \
		-y$4_avg -y$4_bnd \
		--legend \
		-L'3,$4_avg=lfs3 (no bmap)' \
		-L'3,$4_bnd=' \
		-L'2,$4_avg=lfs2' \
		-L'2,$4_bnd=' \
		$$(call PLOT_VS_LFS2_FLAGS,$5,$6,$7) \
		$8 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# lfs3 (no bmap) vs lfs2 - simple counter
$(eval $(call PLOT_VS_LFS2_RULE,counter_r,$\
	counter.$$(V).$$(SIM) counter.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - simple counter - reads",$\
	bench_readed,readed,creat,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,counter_p,$\
	counter.$$(V).$$(SIM) counter.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - simple counter - progs",$\
	bench_proged,proged,creat,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,counter_e,$\
	counter.$$(V).$$(SIM) counter.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - simple counter - erases",$\
	bench_erased,erased,creat,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,counter_u,$\
	counter.$$(V).$$(SIM) counter.$$(V).$$(SIM).per,$\
	"lfs3 (no bmap) vs lfs2 - simple counter - usage",$\
	bench_readed,usage,usage,per,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,counter,$\
	counter.$$(V).$$(SIM).sim counter.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - simple counter - simulated runtime",$\
	bench_readed,simulated,creat+sim,amor,$\
	--yunits=s))

# lfs3 (no bmap) vs lfs2 - many files create
$(eval $(call PLOT_VS_LFS2_RULE,many_creat_r,$\
	many.$$(V).$$(SIM) many.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - many files create - reads",$\
	bench_readed,readed,creat,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,many_creat_p,$\
	many.$$(V).$$(SIM) many.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - many files create - progs",$\
	bench_proged,proged,creat,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,many_creat_e,$\
	many.$$(V).$$(SIM) many.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - many files create - erases",$\
	bench_erased,erased,creat,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,many_creat,$\
	many.$$(V).$$(SIM).sim many.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - many files create - simulated runtime",$\
	bench_readed,simulated,creat+sim,amor,$\
	--yunits=s))

# lfs3 (no bmap) vs lfs2 - many files open+read
$(eval $(call PLOT_VS_LFS2_RULE,many_open_r,$\
	many.$$(V).$$(SIM) many.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - many files open+read - reads",$\
	bench_readed,readed,open,amor,$\
	--y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,many_open,$\
	many.$$(V).$$(SIM).sim many.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - many files open+read - simulated runtime",$\
	bench_readed,simulated,open+sim,amor,$\
	--yunits=s))

# lfs3 (no bmap) vs lfs2 - many files usage
$(eval $(call PLOT_VS_LFS2_RULE,many_usage,$\
	many.$$(V).$$(SIM) many.$$(V).$$(SIM).per,$\
	"lfs3 (no bmap) vs lfs2 - many files usage",$\
	bench_readed,usage,usage,per,$\
	--y2 --yunits=B))

# lfs3 (no bmap) vs lfs2 - linear file writes
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_write_r,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - linear file writes - reads",$\
	bench_readed,readed,write,amor,$\
	-DMODE=0 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_write_p,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - linear file writes - progs",$\
	bench_proged,proged,write,amor,$\
	-DMODE=0 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_write_e,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - linear file writes - erases",$\
	bench_erased,erased,write,amor,$\
	-DMODE=0 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_write,$\
	fwrite.$$(V).$$(SIM).sim fwrite.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - linear file writes - simulated runtime",$\
	bench_readed,simulated,write+sim,amor,$\
	-DMODE=0 --x2 --xunits=B --yunits=s))

# lfs3 (no bmap) vs lfs2 - linear file reads
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_read_r,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).per,$\
	"lfs3 (no bmap) vs lfs2 - linear file reads - reads",$\
	bench_readed,readed,read,per,$\
	-DMODE=1 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_read,$\
	fwrite.$$(V).$$(SIM).sim fwrite.$$(V).$$(SIM).sim.per,$\
	"lfs3 (no bmap) vs lfs2 - linear file reads - simulated runtime",$\
	bench_readed,simulated,read+sim,per,$\
	-DMODE=1 --x2 --xunits=B --yunits=s))

# lfs3 (no bmap) vs lfs2 - linear file usage
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_linear_usage,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).per,$\
	"lfs3 (no bmap) vs lfs2 - linear file usage",$\
	bench_readed,usage,usage,per,$\
	-DMODE=2 --x2 --xunits=B --y2 --yunits=B))

# lfs3 (no bmap) vs lfs2 - random file writes
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_write_r,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - random file writes - reads",$\
	bench_readed,readed,write,amor,$\
	-DMODE=3 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_write_p,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - random file writes - progs",$\
	bench_proged,proged,write,amor,$\
	-DMODE=3 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_write_e,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - random file writes - erases",$\
	bench_erased,erased,write,amor,$\
	-DMODE=3 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_write,$\
	fwrite.$$(V).$$(SIM).sim fwrite.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - random file writes - simulated runtime",$\
	bench_readed,simulated,write+sim,amor,$\
	-DMODE=3 --x2 --xunits=B --yunits=s))

# lfs3 (no bmap) vs lfs2 - random file reads
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_read_r,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - random file reads - reads",$\
	bench_readed,readed,read,amor,$\
	-DMODE=4 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_read,$\
	fwrite.$$(V).$$(SIM).sim fwrite.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - random file reads - simulated runtime",$\
	bench_readed,simulated,read+sim,amor,$\
	-DMODE=4 --x2 --xunits=B --yunits=s))

# lfs3 (no bmap) vs lfs2 - random file usage
$(eval $(call PLOT_VS_LFS2_RULE,fwrite_random_usage,$\
	fwrite.$$(V).$$(SIM) fwrite.$$(V).$$(SIM).per,$\
	"lfs3 (no bmap) vs lfs2 - random file usage",$\
	bench_readed,usage,usage,per,$\
	-DMODE=5 --x2 --xunits=B --y2 --yunits=B))

# lfs3 (no bmap) vs lfs2 - logging writes
$(eval $(call PLOT_VS_LFS2_RULE,logging_write_r,$\
	logging.$$(V).$$(SIM) logging.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - logging writes - reads",$\
	bench_readed,readed,write,amor,$\
	-DMODE=0 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,logging_write_p,$\
	logging.$$(V).$$(SIM) logging.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - logging writes - progs",$\
	bench_proged,proged,write,amor,$\
	-DMODE=0 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,logging_write_e,$\
	logging.$$(V).$$(SIM) logging.$$(V).$$(SIM).amor,$\
	"lfs3 (no bmap) vs lfs2 - logging writes - erases",$\
	bench_erased,erased,write,amor,$\
	-DMODE=0 --x2 --xunits=B --y2 --yunits=B))
$(eval $(call PLOT_VS_LFS2_RULE,logging_write,$\
	logging.$$(V).$$(SIM).sim logging.$$(V).$$(SIM).sim.amor,$\
	"lfs3 (no bmap) vs lfs2 - logging writes - simulated runtime",$\
	bench_readed,simulated,write+sim,amor,$\
	-DMODE=0 --x2 --xunits=B --yunits=s))

# lfs3 (no bmap) vs lfs2 - logging usage
$(eval $(call PLOT_VS_LFS2_RULE,logging_usage,$\
	logging.$$(V).$$(SIM) logging.$$(V).$$(SIM).per,$\
	"lfs3 (no bmap) vs lfs2 - logging usage",$\
	bench_readed,usage,usage,per,$\
	-DMODE=1 --x2 --xunits=B --y2 --yunits=B))




#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean everything
.PHONY: clean
clean: \
		clean-benches \
		clean-results \
		clean-plots

## Clean bench-runner things
.PHONY: clean-benches
clean-benches:
	rm -rf $(BUILDDIR)

## Clean bench results
.PHONY: clean-results
clean-results:
	rm -rf $(RESULTSDIR)

## Clean bench plots
.PHONY: clean-plots
clean-plots:
	rm -rf $(PLOTSDIR)

