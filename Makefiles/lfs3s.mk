ifndef LFS3S_MK
LFS3S_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs3 bench-runner and sources
LFS3S_BUILDDIR     ?= $(BUILDDIR)/littlefs3s
LFS3S_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs3s
LFS3S_CFLAGS += -Ilittlefs3 -DLFS3=1
LFS3S_BENCHFLAGS += -DSET=1
LFS3S_FILTER ?= sed -n -e'1p' -e'/\<lfs3_.\+bd/d' -e'/\<lfs3/p'
LFS3S_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
LFS3S_OBJ := $(LFS3S_SRC:%.c=$(LFS3S_BUILDDIR)/%.o)
LFS3S_DEP := $(LFS3S_OBJ:.o=.d)
LFS3S_CI  := $(LFS3S_OBJ:.o=.ci)
LFS3S_BENCH_SRC ?= \
		$(LFS3S_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS3S_BENCH_B   := \
		$(LFS3S_BENCH_SRC:%.c=$(LFS3S_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS3S_BUILDDIR)/%.b.c)
LFS3S_BENCH_A   := $(LFS3S_BENCH_B:.b.c=.b.a.c)
LFS3S_BENCH_OBJ := $(LFS3S_BENCH_A:.b.a.c=.b.a.o)
LFS3S_BENCH_DEP := $(LFS3S_BENCH_OBJ:.o=.d)
LFS3S_BENCH_CI  := $(LFS3S_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs3s
U_lfs3s = LFS3S
N_lfs3s = 34
I_lfs3s = 0
C_lfs3s = $(C_BLUE)
F_lfs3s = $$$$s$$$$ # s
DEFAULT_BUILD_FILESYSTEMS += lfs3s
DEFAULT_BENCH_FILESYSTEMS += lfs3s

# include compile-time deps
-include $(LFS3S_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS3S_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS3S_BUILDDIR) \
		$(dir $(LFS3S_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs3 related ctags
.PHONY: tags-lfs3s ctags-lfs3s
tags-lfs3s ctags-lfs3s: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS3S_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs3s
build-lfs3s: $(LFS3S_BENCH_RUNNER)

# bench-runner rules
$(LFS3S_BENCH_RUNNER): $(LFS3S_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS3S_CFLAGS) $^ $(LFLAGS) -o$@

$(LFS3S_BUILDDIR)/%.o $(LFS3S_BUILDDIR)/%.ci: $(LFS3S_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3S_CFLAGS) $< -o$(firstword $@)

$(LFS3S_BUILDDIR)/%.s: $(LFS3S_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS3S_CFLAGS) $< -o$@

$(LFS3S_BUILDDIR)/%.a.c: $(LFS3S_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs3_ $< -o$@

$(LFS3S_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS3S_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS3S_BUILDDIR)/%.b.c: $(LFS3S_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
