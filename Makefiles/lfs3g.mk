ifndef LFS3G_MK
LFS3G_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs3 bench-runner and sources
LFS3G_BUILDDIR     ?= $(BUILDDIR)/littlefs3g
LFS3G_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs3g
LFS3G_CFLAGS += -Ilittlefs3 -DLFS3=1
LFS3G_BENCHFLAGS += -DGRANULAR=1
LFS3G_FILTER ?= sed -n -e'1p' -e'/\<lfs3_.\+bd/d' -e'/\<lfs3/p'
LFS3G_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
LFS3G_OBJ := $(LFS3G_SRC:%.c=$(LFS3G_BUILDDIR)/%.o)
LFS3G_DEP := $(LFS3G_OBJ:.o=.d)
LFS3G_CI  := $(LFS3G_OBJ:.o=.ci)
LFS3G_BENCH_SRC ?= \
		$(LFS3G_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS3G_BENCH_B   := \
		$(LFS3G_BENCH_SRC:%.c=$(LFS3G_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS3G_BUILDDIR)/%.b.c)
LFS3G_BENCH_A   := $(LFS3G_BENCH_B:.b.c=.b.a.c)
LFS3G_BENCH_OBJ := $(LFS3G_BENCH_A:.b.a.c=.b.a.o)
LFS3G_BENCH_DEP := $(LFS3G_BENCH_OBJ:.o=.d)
LFS3G_BENCH_CI  := $(LFS3G_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs3g
U_lfs3g = LFS3G
N_lfs3g = 32
I_lfs3g = 0
C_lfs3g = $(C_BLUE)
F_lfs3g = $$$$g$$$$ # g
DEFAULT_BUILD_FILESYSTEMS += lfs3g
DEFAULT_BENCH_FILESYSTEMS += lfs3g

# include compile-time deps
-include $(LFS3G_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS3G_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS3G_BUILDDIR) \
		$(dir $(LFS3G_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs3 related ctags
.PHONY: tags-lfs3g ctags-lfs3g
tags-lfs3g ctags-lfs3g: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS3G_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs3g
build-lfs3g: $(LFS3G_BENCH_RUNNER)

# bench-runner rules
$(LFS3G_BENCH_RUNNER): $(LFS3G_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS3G_CFLAGS) $^ $(LFLAGS) -o$@

$(LFS3G_BUILDDIR)/%.o $(LFS3G_BUILDDIR)/%.ci: %.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3G_CFLAGS) $< -o$(firstword $@)

$(LFS3G_BUILDDIR)/%.o $(LFS3G_BUILDDIR)/%.ci: $(LFS3G_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3G_CFLAGS) $< -o$(firstword $@)

$(LFS3G_BUILDDIR)/%.s: %.c
	$(CC) -S $(CFLAGS) $(LFS3G_CFLAGS) $< -o$@

$(LFS3G_BUILDDIR)/%.s: $(LFS3G_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS3G_CFLAGS) $< -o$@

$(LFS3G_BUILDDIR)/%.a.c: $(LFS3G_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs3_ $< -o$@

$(LFS3G_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS3G_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS3G_BUILDDIR)/%.b.c: $(LFS3G_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
