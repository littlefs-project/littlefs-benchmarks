ifndef LFS3F_MK
LFS3F_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs3 bench-runner and sources
LFS3F_BUILDDIR     ?= $(BUILDDIR)/littlefs3f
LFS3F_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs3f
LFS3F_CFLAGS += -Ilittlefs3 -DLFS3=1
LFS3F_BENCHFLAGS += -DFRUNCATE=1
LFS3F_FILTER ?= sed -n -e'1p' -e'/\<lfs3_.\+bd/d' -e'/\<lfs3/p'
LFS3F_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
LFS3F_OBJ := $(LFS3F_SRC:%.c=$(LFS3F_BUILDDIR)/%.o)
LFS3F_DEP := $(LFS3F_OBJ:.o=.d)
LFS3F_CI  := $(LFS3F_OBJ:.o=.ci)
LFS3F_BENCH_SRC ?= \
		$(LFS3F_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS3F_BENCH_B   := \
		$(LFS3F_BENCH_SRC:%.c=$(LFS3F_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS3F_BUILDDIR)/%.b.c)
LFS3F_BENCH_A   := $(LFS3F_BENCH_B:.b.c=.b.a.c)
LFS3F_BENCH_OBJ := $(LFS3F_BENCH_A:.b.a.c=.b.a.o)
LFS3F_BENCH_DEP := $(LFS3F_BENCH_OBJ:.o=.d)
LFS3F_BENCH_CI  := $(LFS3F_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs3f
U_lfs3f = LFS3F
N_lfs3f = 33
I_lfs3f = 0
C_lfs3f = $(C_BLUE)
F_lfs3f = $$$$f$$$$ # f
DEFAULT_BUILD_FILESYSTEMS += lfs3f
DEFAULT_BENCH_FILESYSTEMS += lfs3f

# include compile-time deps
-include $(LFS3F_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS3F_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS3F_BUILDDIR) \
		$(dir $(LFS3F_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs3 related ctags
.PHONY: tags-lfs3f ctags-lfs3f
tags-lfs3f ctags-lfs3f: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS3F_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs3f
build-lfs3f: $(LFS3F_BENCH_RUNNER)

# bench-runner rules
$(LFS3F_BENCH_RUNNER): $(LFS3F_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS3F_CFLAGS) $^ $(LFLAGS) -o$@

$(LFS3F_BUILDDIR)/%.o $(LFS3F_BUILDDIR)/%.ci: %.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3F_CFLAGS) $< -o$(firstword $@)

$(LFS3F_BUILDDIR)/%.o $(LFS3F_BUILDDIR)/%.ci: $(LFS3F_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3F_CFLAGS) $< -o$(firstword $@)

$(LFS3F_BUILDDIR)/%.s: %.c
	$(CC) -S $(CFLAGS) $(LFS3F_CFLAGS) $< -o$@

$(LFS3F_BUILDDIR)/%.s: $(LFS3F_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS3F_CFLAGS) $< -o$@

$(LFS3F_BUILDDIR)/%.a.c: $(LFS3F_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs3_ $< -o$@

$(LFS3F_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS3F_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS3F_BUILDDIR)/%.b.c: $(LFS3F_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
