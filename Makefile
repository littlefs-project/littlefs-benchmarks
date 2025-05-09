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


# find source files

# littlefs v3 bench-runner (the default)
BENCHES ?= $(wildcard benches/*.toml)
BENCH_RUNNER ?= $(BUILDDIR)/bench_runner
BENCH_SRC ?= \
		$(wildcard littlefs3/*.c) \
		$(wildcard bd/*.c) \
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
		$(wildcard littlefs2/*.c) \
		$(wildcard bd/*.c) \
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
CFLAGS += $(foreach D,$(filter LFS2_%,$(.VARIABLES)),-D$D=$($D))
CFLAGS += $(foreach D,$(filter LFS3_%,$(.VARIABLES)),-D$D=$($D))

# bench.py -c flags
ifdef VERBOSE
BENCHCFLAGS += -v
endif

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
	$(BUILDDIR) \
	$(RESULTSDIR) \
	$(PLOTSDIR) \
    $(addprefix $(BUILDDIR)/,$(dir \
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

## Run file write benchmarks with different block_sizes
.PHONY: bench-fwrite-tune-bs
bench-fwrite-tune-bs: $(RESULTSDIR)/bench_fwrite_tune_bs.csv

## Run file write benchmarks with different inline_sizes
.PHONY: bench-fwrite-tune-is
bench-fwrite-tune-is: $(RESULTSDIR)/bench_fwrite_tune_is.csv

## Run file write benchmarks with different fragment_sizes
.PHONY: bench-fwrite-tune-fs
bench-fwrite-tune-fs: $(RESULTSDIR)/bench_fwrite_tune_fs.csv

## Run file write benchmarks with different crystal_threshs
.PHONY: bench-fwrite-tune-ct
bench-fwrite-tune-ct: $(RESULTSDIR)/bench_fwrite_tune_ct.csv

## Run benchmarks over littlefs v3 vs v2
.PHONY: bench-vs-lfs2
bench-vs-lfs2: \
		bench-vs-lfs2-counter

## Run benchmarks v3 vs v2 comparing a simple counter
.PHONY: bench-vs-lfs2-counter
bench-vs-lfs2-counter: \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.csv


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
		-fbench_readed='float(bench_readed) / float(REWRITE ? SIZE : n)' \
		-fbench_proged='float(bench_proged) / float(REWRITE ? SIZE : n)' \
		-fbench_erased='float(bench_erased) / float(REWRITE ? SIZE : n)' \
		-o$@)


# v3 vs v2 bench rules!

# run the benches against v3
$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.csv: $(BENCH_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_vs_lfs2_counter \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# run the benches against v2
$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.csv: $(BENCH_LFS2_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_vs_lfs2_counter \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# amortized results
$(RESULTSDIR)/bench_vs_lfs%.amor.csv: $(RESULTSDIR)/bench_vs_lfs%.csv
	$(strip ./scripts/csv.py $^ \
		-Bn -Bm='%(m)s+amor' \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
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


## Plot all benchmarks!
.PHONY: all plot plot-all
all plot plot-all: \
		plot-internal \
		plot-many \
		plot-fwrite \
		plot-fwrite-tune \
		plot-vs-lfs2

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
		$(PLOTSDIR)/bench_fwrite_rewriting.svg \
		$(PLOTSDIR)/bench_fwrite_linear.svg \
		$(PLOTSDIR)/bench_fwrite_random.svg

## Plot file write benchmarks with tuneable configs
.PHONY: plot-fwrite-tune
plot-fwrite-tune: \
		plot-fwrite-tune-bs \
		plot-fwrite-tune-is \
		plot-fwrite-tune-fs \
		plot-fwrite-tune-ct

## Plot file write benchmarks with different block_sizes
.PHONY: plot-fwrite-tune-bs
plot-fwrite-tune-bs: \
		$(PLOTSDIR)/bench_fwrite_tune_bs_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_bs_random.svg

## Plot file write benchmarks with different inline_sizes
.PHONY: plot-fwrite-tune-is
plot-fwrite-tune-is: \
		$(PLOTSDIR)/bench_fwrite_tune_is_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_is_random.svg

## Plot file write benchmarks with different fragment_sizes
.PHONY: plot-fwrite-tune-fs
plot-fwrite-tune-fs: \
		$(PLOTSDIR)/bench_fwrite_tune_fs_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_fs_random.svg

## Plot file write benchmarks with different crystal_threshs
.PHONY: plot-fwrite-tune-ct
plot-fwrite-tune-ct: \
		$(PLOTSDIR)/bench_fwrite_tune_ct_linear.svg \
		$(PLOTSDIR)/bench_fwrite_tune_ct_random.svg

## Plot benchmarks over littlefs v3 vs v2
.PHONY: plot-vs-lfs2
plot-vs-lfs2: \
		plot-vs-lfs2-counter

## Plot benchmarks v3 vs v2 comparing a simple counter
.PHONY: plot-vs-lfs2-counter
plot-vs-lfs2-counter: \
		$(PLOTSDIR)/bench_vs_lfs2_counter_r.svg \
		$(PLOTSDIR)/bench_vs_lfs2_counter_p.svg \
		$(PLOTSDIR)/bench_vs_lfs2_counter_e.svg
#		$(PLOTSDIR)/bench_vs_lfs2_counter_u.svg \
#		$(PLOTSDIR)/bench_vs_lfs2_counter.svg


# plot rules

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
				-ybench_proged_bnd\"" \
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
				-Y0,512 \
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
				-Y0,1024\
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
				-Y0,16 \
				-W0.25 \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				$(if $1,-ybench_readed_bnd) \
				--ylabel=usage \
				--title='usage (total)' \
				-H0.665\""
PLOT_FWRITE_FLAGS += $(if $1,$(PLOT_COLORS_3BND),$(PLOT_COLORS_3))

# file writes - sparseish
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
		--title="file writes - sparseish" \
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
$(PLOTSDIR)/bench_fwrite_rewriting.svg: \
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
		-DREWRITE=1 \
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
		-DREWRITE=1 \
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
		-DREWRITE=1 \
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
		-DREWRITE=1 \
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
		-DREWRITE=1 \
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
PLOT_VS_LFS2_FLAGS += --y2 --yunits=B
PLOT_VS_LFS2_FLAGS += \
		--subplot=" \
				-Dm=write \
				--ylabel=$1 \
				--title=nor \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=write+amor \
				--ylabel='$1 (amortized)' \
				-H0.5"
PLOT_VS_LFS2_FLAGS += $(PLOT_COLORS_1BND)

# lfs3 vs lfs2 - simple counter - reads
$(PLOTSDIR)/bench_vs_lfs2_counter_r.svg: \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.amor.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.amor.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_readed_avg \
			-fbench_readed_bnd=bench_readed_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_readed_avg='*' \
			-fbench_readed_bnd=bench_readed_max \
			-o-) \
		--title="lfs3 vs lfs2 - simple counter - reads" \
		-bV -SV \
		-xn \
		-ybench_readed_avg -ybench_readed_bnd \
		--legend \
		-L'*,bench_readed_avg=littlefs v%(V)s' \
		-L'*,bench_readed_bnd=' \
		$(call PLOT_VS_LFS2_FLAGS,readed) \
		$(PLOTFLAGS) \
		-o$@)

# lfs3 vs lfs2 - simple counter - progs
$(PLOTSDIR)/bench_vs_lfs2_counter_p.svg: \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.amor.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.amor.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_proged_avg \
			-fbench_proged_bnd=bench_proged_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_proged_avg='*' \
			-fbench_proged_bnd=bench_proged_max \
			-o-) \
		--title="lfs3 vs lfs2 - simple counter - progs" \
		-bV -SV \
		-xn \
		-ybench_proged_avg -ybench_proged_bnd \
		--legend \
		-L'*,bench_proged_avg=littlefs v%(V)s' \
		-L'*,bench_proged_bnd=' \
		$(call PLOT_VS_LFS2_FLAGS,proged) \
		$(PLOTFLAGS) \
		-o$@)

# lfs3 vs lfs2 - simple counter - erases
$(PLOTSDIR)/bench_vs_lfs2_counter_e.svg: \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs3.amor.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.avg.csv \
		$(RESULTSDIR)/bench_vs_lfs2_counter.lfs2.amor.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-fbench_erased_avg \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-Dbench_erased_avg='*' \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="lfs3 vs lfs2 - simple counter - erases" \
		-bV -SV \
		-xn \
		-ybench_erased_avg -ybench_erased_bnd \
		--legend \
		-L'*,bench_erased_avg=littlefs v%(V)s' \
		-L'*,bench_erased_bnd=' \
		$(call PLOT_VS_LFS2_FLAGS,erased) \
		$(PLOTFLAGS) \
		-o$@)





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

