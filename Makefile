# overrideable build dir, default to ./build
BUILDDIR ?= build
# overrideable results dir, default to ./results
RESULTSDIR ?= results
# overrideable plots dir, defaults ./plots
PLOTSDIR ?= plots

# how many samples to measure?
SAMPLES ?= 16


# find source files
BENCHES ?= $(wildcard benches/*.toml)

BENCH_SRC ?= $(wildcard bd/*.c) runners/bench_runner.c
BENCH_C := $(BENCHES:%.toml=$(BUILDDIR)/%.b.c) \
		$(BENCH_SRC:%.c=$(BUILDDIR)/%.b.c)
BENCH_A := $(BENCH_C:%.b.c=%.b.a.c)

BENCH_LFS3_RUNNER ?= $(BUILDDIR)/bench_runner_lfs3
BENCH_LFS3_SRC ?= $(wildcard littlefs3/*.c)
BENCH_LFS3_C     := $(BENCH_LFS3_SRC:%.c=$(BUILDDIR)/%.b.c)
BENCH_LFS3_A     := $(BENCH_LFS3_C:%.b.c=%.b.a.c)
BENCH_LFS3_OBJ   := $(BENCH_LFS3_A:%.b.a.c=%.b.a.o) \
		$(BENCH_A:%.b.a.c=%.b.a.lfs3.o)
BENCH_LFS3_DEP   := $(BENCH_LFS3_A:%.b.a.c=%.b.a.d) \
		$(BENCH_A:%.b.a.c=%.b.a.lfs3.d)
BENCH_LFS3_CI    := $(BENCH_LFS3_A:%.b.a.c=%.b.a.ci) \
		$(BENCH_A:%.b.a.c=%.b.a.lfs3.ci)
BENCH_LFS3_GCNO  := $(BENCH_LFS3_A:%.b.a.c=%.b.a.gcno) \
		$(BENCH_A:%.b.a.c=%.b.a.lfs3.gcno)
BENCH_LFS3_GCDA  := $(BENCH_LFS3_A:%.b.a.c=%.b.a.gcda) \
		$(BENCH_A:%.b.a.c=%.b.a.lfs3.gcda)
BENCH_LFS3_PERF  := $(BENCH_LFS3_RUNNER:%=%.perf)
BENCH_LFS3_TRACE := $(BENCH_LFS3_RUNNER:%=%.trace)
BENCH_LFS3_CSV   := $(BENCH_LFS3_RUNNER:%=%.csv)

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
CFLAGS += -I. -Ilittlefs3
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
        $(BENCH_LFS3_SRC)))))
endif

# just use bash for everything, process substitution my beloved!
SHELL = /bin/bash


# top-level commands

## Build the bench-runners
.PHONY: build bench-runner build-benches
build bench-runner build-benches: CFLAGS+=$(BENCH_CFLAGS)
# note we remove some binary dependent files during compilation,
# otherwise it's way to easy to end up with outdated results
build bench-runner build-benches: $(BENCH_LFS3_RUNNER)
ifdef COVGEN
	rm -f $(BENCH_LFS3_GCDA)
endif
ifdef PERFGEN
	rm -f $(BENCH_LFS3_PERF)
endif
ifdef PERFBDGEN
	rm -f $(BENCH_LFS3_TRACE)
endif

## Find total section sizes
.PHONY: size
size: $(BENCH_LFS3_OBJ)
	$(SIZE) -t $^

## Generate a ctags file
.PHONY: tags ctags
tags ctags:
	$(strip $(CTAGS) \
		--totals --fields=+n --c-types=+p \
		$(shell find -H -name '*.h') $(BENCH_LFS3_SRC))

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
-include $(BENCH_LFS3_DEP)
.SUFFIXES:
.SECONDARY:

$(BENCH_LFS3_RUNNER): $(BENCH_LFS3_OBJ)
	$(CC) $(CFLAGS) $^ $(LFLAGS) -o$@

# .lfs3 files need -DLFS3=1
$(BUILDDIR)/%.lfs3.o $(BUILDDIR)/%.lfs3.ci: %.c
	$(CC) -c -MMD -DLFS3=1 $(CFLAGS) $< -o $(BUILDDIR)/$*.lfs3.o

$(BUILDDIR)/%.lfs3.o $(BUILDDIR)/%.lfs3.ci: $(BUILDDIR)/%.c
	$(CC) -c -MMD -DLFS3=1 $(CFLAGS) $< -o $(BUILDDIR)/$*.lfs3.o

# our main build rule generates .o, .d, and .ci files, the latter
# used for stack analysis
$(BUILDDIR)/%.o $(BUILDDIR)/%.ci: %.c
	$(CC) -c -MMD $(CFLAGS) $< -o $(BUILDDIR)/$*.o

$(BUILDDIR)/%.o $(BUILDDIR)/%.ci: $(BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $< -o $(BUILDDIR)/$*.o

$(BUILDDIR)/%.s: %.c
	$(CC) -S $(CFLAGS) $< -o$@

$(BUILDDIR)/%.s: $(BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $< -o$@

$(BUILDDIR)/%.a.c: %.c
	$(PRETTYASSERTS) -Plfs_ $< -o$@

$(BUILDDIR)/%.a.c: $(BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ $< -o$@

$(BUILDDIR)/%.t.c: %.toml
	./scripts/test.py -c $< $(TESTCFLAGS) -o$@

$(BUILDDIR)/%.t.c: %.c $(TESTS)
	./scripts/test.py -c $(TESTS) -s $< $(TESTCFLAGS) -o$@

$(BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


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
		bench-files

### Run benchmarks over internal data structures
#.PHONY: bench-internal
#bench-internal: \
#		bench-files

## Run benchmarks over files
.PHONY: bench-files
bench-files: $(RESULTSDIR)/bench_files.avg.csv

# run the benches!
$(RESULTSDIR)/bench_files.csv: $(BENCH_LFS3_RUNNER)
	$(strip ./scripts/bench.py -R$< -B bench_files \
		-DSEED="range($(SAMPLES))" \
		$(BENCHFLAGS) \
		-o$@)

# amortized results
$(RESULTSDIR)/bench_files.amor.csv: $(RESULTSDIR)/bench_files.csv
	$(strip ./scripts/csv.py $^ \
		-bsuite -bcase -bn -bORDER -bREWRITE -bSEED \
		-Dm=write -bm='write+amor' \
		-fbench_readed='float(bench_creaded) / float(n)' \
		-fbench_proged='float(bench_cproged) / float(n)' \
		-fbench_erased='float(bench_cerased) / float(n)' \
		-o$@)

# byte-per-byte usage results
$(RESULTSDIR)/bench_files.per.csv: $(RESULTSDIR)/bench_files.csv
	$(strip ./scripts/csv.py $^ \
		-bsuite -bcase -bn -bORDER -bREWRITE -bSEED \
		-Dm=usage -bm='usage+per' \
		-fbench_readed='float(bench_readed) / float(REWRITE ? SIZE : n)' \
		-fbench_proged='float(bench_proged) / float(REWRITE ? SIZE : n)' \
		-fbench_erased='float(bench_erased) / float(REWRITE ? SIZE : n)' \
		-o$@)

# averaged results (over SAMPLES)
$(RESULTSDIR)/bench_files.avg.csv: \
		$(RESULTSDIR)/bench_files.csv \
		$(RESULTSDIR)/bench_files.amor.csv \
		$(RESULTSDIR)/bench_files.per.csv
	$(strip ./scripts/csv.py $^ \
		-bsuite -bcase -bm -bn -bORDER -bREWRITE \
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
PLOTFLAGS += -W1750 -H750
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
		\#4c72b0bf/\#4c72b01f \
		\#dd8452bf/\#dd84521f \
		\#55a868bf/\#55a8681f \
		\#c44e52bf/\#c44e521f \
		\#8172b3bf/\#8172b31f \
		\#937860bf/\#9378601f \
		\#da8bc3bf/\#da8bc31f \
		\#8c8c8cbf/\#8c8c8c1f \
		\#ccb974bf/\#ccb9741f \
		\#64b5cdbf/\#64b5cd1f
else
PLOT_COLORS ?= \
		\#a1c9f4bf/\#a1c9f41f \
		\#ffb482bf/\#ffb4821f \
		\#8de5a1bf/\#8de5a11f \
		\#ff9f9bbf/\#ff9f9b1f \
		\#d0bbffbf/\#d0bbff1f \
		\#debb9bbf/\#debb9b1f \
		\#fab0e4bf/\#fab0e41f \
		\#cfcfcfbf/\#cfcfcf1f \
		\#fffea3bf/\#fffea31f \
		\#b9f2f0bf/\#b9f2f01f
endif

PLOTFLAGS += $(foreach C, $(PLOT_COLORS), \
		-C$(word 1,$(subst /, ,$C)) -C$(word 2,$(subst /, ,$C)) \
		-C$(word 1,$(subst /, ,$C)) -C$(word 2,$(subst /, ,$C)) \
		-C$(word 1,$(subst /, ,$C)) -C$(word 2,$(subst /, ,$C)))

# plot bench_files config
PLOT_FILES_FLAGS += -L'0,bench_readed_avg=inorder'
PLOT_FILES_FLAGS += -L'0,bench_readed_bnd='
PLOT_FILES_FLAGS += -L'0,bench_proged_avg='
PLOT_FILES_FLAGS += -L'0,bench_proged_bnd='
PLOT_FILES_FLAGS += -L'0,bench_erased_avg='
PLOT_FILES_FLAGS += -L'0,bench_erased_bnd='
PLOT_FILES_FLAGS += -L'1,bench_readed_avg=reversed'
PLOT_FILES_FLAGS += -L'1,bench_readed_bnd='
PLOT_FILES_FLAGS += -L'1,bench_proged_avg='
PLOT_FILES_FLAGS += -L'1,bench_proged_bnd='
PLOT_FILES_FLAGS += -L'1,bench_erased_avg='
PLOT_FILES_FLAGS += -L'1,bench_erased_bnd='
PLOT_FILES_FLAGS += -L'2,bench_readed_avg=random aligned'
PLOT_FILES_FLAGS += -L'2,bench_readed_bnd='
PLOT_FILES_FLAGS += -L'2,bench_proged_avg='
PLOT_FILES_FLAGS += -L'2,bench_proged_bnd='
PLOT_FILES_FLAGS += -L'2,bench_erased_avg='
PLOT_FILES_FLAGS += -L'2,bench_erased_bnd='
PLOT_FILES_FLAGS += -L'3,bench_readed_avg=random unaligned'
PLOT_FILES_FLAGS += -L'3,bench_readed_bnd='
PLOT_FILES_FLAGS += -L'3,bench_proged_avg='
PLOT_FILES_FLAGS += -L'3,bench_proged_bnd='
PLOT_FILES_FLAGS += -L'3,bench_erased_avg='
PLOT_FILES_FLAGS += -L'3,bench_erased_bnd='
PLOT_FILES_FLAGS += --y2 --yunits=B
PLOT_FILES_FLAGS += --subplot=" \
				-Dm=write \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=readed \
				--title='write' \
				--add-xticklabel=" \
			--subplot-below=" \
				-Dm=write \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--ylabel=proged \
				--add-xticklabel= \
				-H0.5 " \
			--subplot-below=" \
				-Dm=write \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				--ylabel=erased \
				-H0.33" \
		--subplot-right=" \
				-Dm=write+amor \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='write (amortized)' \
				--add-xticklabel= \
				-W0.5 \
			--subplot-below=\" \
				-Dm=write+amor \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--add-xticklabel= \
				-H0.5 \" \
			--subplot-below=\" \
				-Dm=write+amor \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=read \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--title='read' \
				--add-xticklabel= \
				-W0.33 \
			--subplot-below=\" \
				-Dm=read \
				-ybench_proged_avg \
				-ybench_proged_bnd \
				--add-xticklabel= \
				-Y0,1 \
				-H0.5 \" \
			--subplot-below=\" \
				-Dm=read \
				-ybench_erased_avg \
				-ybench_erased_bnd \
				-Y0,1 \
				-H0.33\"" \
		--subplot-right=" \
				-Dm=usage+per \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=usage \
				--title='usage (per-byte)' \
				--add-xticklabel= \
				-Y0,16 \
				-W0.25 \
			--subplot-below=\" \
				-Dm=usage \
				-ybench_readed_avg \
				-ybench_readed_bnd \
				--ylabel=usage \
				--title='usage (total)' \
				-H0.665\""

## Plot all benchmarks!
.PHONY: all plot plot-all
all plot plot-all: \
		plot-files

### Plot benchmarks over internal data structures
#.PHONY: plot-internal
#plot-internal: $(PLOTSDIR)/bench_files.svg

## Plot benchmarks over files
.PHONY: plot-files
plot-files: \
		$(PLOTSDIR)/bench_files_sparseish.svg \
		$(PLOTSDIR)/bench_files_rewriting.svg \
		$(PLOTSDIR)/bench_files_linear.svg \
		$(PLOTSDIR)/bench_files_random.svg

$(PLOTSDIR)/bench_files_sparseish.svg: $(RESULTSDIR)/bench_files.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-DREWRITE=0 -bORDER -bm -bn \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=0 -bORDER -bm -bn \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=0 -bORDER -bm -bn \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file operations - sparseish" \
		-bORDER \
		-xn \
		--legend \
		$(PLOTFLAGS) \
		$(PLOT_FILES_FLAGS) \
		-o$@)

$(PLOTSDIR)/bench_files_rewriting.svg: $(RESULTSDIR)/bench_files.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-DREWRITE=1 -bORDER -bm -bn \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=1 -bORDER -bm -bn \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=1 -bORDER -bm -bn \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file operations - rewriting" \
		-bORDER \
		-xn \
		--legend \
		$(PLOTFLAGS) \
		$(PLOT_FILES_FLAGS) \
		-o$@)

$(PLOTSDIR)/bench_files_linear.svg: $(RESULTSDIR)/bench_files.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-DREWRITE=0 -DORDER=0 -bm -bn \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=0 -DORDER=0 -bm -bn \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=0 -DORDER=0 -bm -bn \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file operations - linear" \
		-xn \
		--legend \
		$(PLOTFLAGS) \
		$(PLOT_FILES_FLAGS) \
		-o$@)

$(PLOTSDIR)/bench_files_random.svg: $(RESULTSDIR)/bench_files.avg.csv
	$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $^ \
			-DREWRITE=1 -DORDER=3 -bm -bn \
			-fbench_readed_avg \
			-fbench_proged_avg \
			-fbench_erased_avg \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=1 -DORDER=3 -bm -bn \
			-fbench_readed_bnd=bench_readed_min \
			-fbench_proged_bnd=bench_proged_min \
			-fbench_erased_bnd=bench_erased_min \
			-o-) \
		<(./scripts/csv.py $^ \
			-DREWRITE=1 -DORDER=3 -bm -bn \
			-fbench_readed_bnd=bench_readed_max \
			-fbench_proged_bnd=bench_proged_max \
			-fbench_erased_bnd=bench_erased_max \
			-o-) \
		--title="file operations - random" \
		-xn \
		--legend \
		$(PLOTFLAGS) \
		$(PLOT_FILES_FLAGS) \
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

