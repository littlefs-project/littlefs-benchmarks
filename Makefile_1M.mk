# overrideable build dir, default to ./build_1M
export BUILDDIR ?= build_1M
# overrideable results dir, default to ./results_1M
export RESULTSDIR ?= results_1M
# overrideable plots dir, defaults ./plots_1M
export PLOTSDIR ?= plots_1M


# increase bench sizes to 1 MiB
export BENCHFLAGS += -DDISK_SIZE=67108864
export BENCHFLAGS += -DSIZE=1048576
export BENCHFLAGS += -DSTEP=64


# override the default bench/plot rules

## Run all benchmarks!
.PHONY: bench bench-all
bench bench-all: \
		bench-vs-lfs2-fwrite \
		bench-vs-lfs2-logging

## Plot all benchmarks!
.PHONY: all plot plot-all
all plot plot-all: \
		plot-vs-lfs2-fwrite \
		plot-vs-lfs2-logging


# we just set the above defines, the default Makefile does all the
# real work
FORCE:;
%: FORCE
	@$(MAKE) $@

