ifndef LFS3_MK
LFS3_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs3 bench-runner and sources
LFS3_BUILDDIR     ?= $(BUILDDIR)/littlefs3
LFS3_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs3
LFS3_CFLAGS += -Ilittlefs3 -DLFS3=1
LFS3_FILTER ?= sed -n -e'1p' -e'/\<lfs3_.\+bd/d' -e'/\<lfs3/p'
LFS3_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
LFS3_OBJ := $(LFS3_SRC:%.c=$(LFS3_BUILDDIR)/%.o)
LFS3_DEP := $(LFS3_OBJ:.o=.d)
LFS3_CI  := $(LFS3_OBJ:.o=.ci)
LFS3_BENCH_SRC ?= \
		$(LFS3_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS3_BENCH_B   := \
		$(LFS3_BENCH_SRC:%.c=$(LFS3_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS3_BUILDDIR)/%.b.c)
LFS3_BENCH_A   := $(LFS3_BENCH_B:.b.c=.b.a.c)
LFS3_BENCH_OBJ := $(LFS3_BENCH_A:.b.a.c=.b.a.o)
LFS3_BENCH_DEP := $(LFS3_BENCH_OBJ:.o=.d)
LFS3_BENCH_CI  := $(LFS3_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs3
U_lfs3 = LFS3
N_lfs3 = 3
I_lfs3 = 0
C_lfs3 = $(C_BLUE)
F_lfs3 = o # circle
DEFAULT_SIZE_FILESYSTEMS  += lfs3
DEFAULT_BUILD_FILESYSTEMS += lfs3
DEFAULT_BENCH_FILESYSTEMS += lfs3
DEFAULT_LFS3_FILESYSTEMS  += lfs3

# include compile-time deps
-include $(LFS3_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS3_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS3_BUILDDIR) \
		$(dir $(LFS3_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs3 related ctags
.PHONY: tags-lfs3 ctags-lfs3
tags-lfs3 ctags-lfs3: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS3_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs3
build-lfs3: $(LFS3_BENCH_RUNNER)

# bench-runner rules
$(LFS3_BENCH_RUNNER): $(LFS3_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS3_CFLAGS) $^ $(LFLAGS) -o$@

$(LFS3_BUILDDIR)/%.o $(LFS3_BUILDDIR)/%.ci: $(LFS3_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3_CFLAGS) $< -o$(firstword $@)

$(LFS3_BUILDDIR)/%.s: $(LFS3_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS3_CFLAGS) $< -o$@

$(LFS3_BUILDDIR)/%.a.c: $(LFS3_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs3_ $< -o$@

$(LFS3_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS3_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS3_BUILDDIR)/%.b.c: $(LFS3_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
