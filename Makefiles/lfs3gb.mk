ifndef LFS3GB_MK
LFS3GB_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs3 bench-runner and sources
LFS3GB_BUILDDIR     ?= $(BUILDDIR)/littlefs3gb
LFS3GB_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs3gb
LFS3GB_CFLAGS += -Ilittlefs3 -DLFS3=1 -DLFS3_YES_GBMAP=1
LFS3GB_FILTER ?= sed -n -e'1p' -e'/\<lfs3_.\+bd/d' -e'/\<lfs3/p'
LFS3GB_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
LFS3GB_OBJ := $(LFS3GB_SRC:%.c=$(LFS3GB_BUILDDIR)/%.o)
LFS3GB_DEP := $(LFS3GB_OBJ:.o=.d)
LFS3GB_CI  := $(LFS3GB_OBJ:.o=.ci)
LFS3GB_BENCH_SRC ?= \
		$(LFS3GB_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS3GB_BENCH_B   := \
		$(LFS3GB_BENCH_SRC:%.c=$(LFS3GB_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS3GB_BUILDDIR)/%.b.c)
LFS3GB_BENCH_A   := $(LFS3GB_BENCH_B:.b.c=.b.a.c)
LFS3GB_BENCH_OBJ := $(LFS3GB_BENCH_A:.b.a.c=.b.a.o)
LFS3GB_BENCH_DEP := $(LFS3GB_BENCH_OBJ:.o=.d)
LFS3GB_BENCH_CI  := $(LFS3GB_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs3gb
U_lfs3gb = LFS3GB
N_lfs3gb = 31
I_lfs3gb = 0
C_lfs3gb = $(C_BLUE)
F_lfs3gb = $$$$gb$$$$ # gb
DEFAULT_SIZE_FILESYSTEMS  += lfs3gb
DEFAULT_BUILD_FILESYSTEMS += lfs3gb
DEFAULT_BENCH_FILESYSTEMS += lfs3gb

# include compile-time deps
-include $(LFS3GB_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS3GB_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS3GB_BUILDDIR) \
		$(dir $(LFS3GB_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs3 related ctags
.PHONY: tags-lfs3gb ctags-lfs3gb
tags-lfs3gb ctags-lfs3gb: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS3GB_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs3gb
build-lfs3gb: $(LFS3GB_BENCH_RUNNER)

# bench-runner rules
$(LFS3GB_BENCH_RUNNER): $(LFS3GB_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS3GB_CFLAGS) $^ $(LFLAGS) -o$@

$(LFS3GB_BUILDDIR)/%.o $(LFS3GB_BUILDDIR)/%.ci: %.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3GB_CFLAGS) $< -o$(firstword $@)

$(LFS3GB_BUILDDIR)/%.o $(LFS3GB_BUILDDIR)/%.ci: $(LFS3GB_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3GB_CFLAGS) $< -o$(firstword $@)

$(LFS3GB_BUILDDIR)/%.s: %.c
	$(CC) -S $(CFLAGS) $(LFS3GB_CFLAGS) $< -o$@

$(LFS3GB_BUILDDIR)/%.s: $(LFS3GB_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS3GB_CFLAGS) $< -o$@

$(LFS3GB_BUILDDIR)/%.a.c: $(LFS3GB_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs3_ $< -o$@

$(LFS3GB_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS3GB_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS3GB_BUILDDIR)/%.b.c: $(LFS3GB_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
