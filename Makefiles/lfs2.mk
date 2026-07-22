ifndef LFS2_MK
LFS2_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs2 bench-runner and sources
LFS2_BUILDDIR     ?= $(BUILDDIR)/littlefs2
LFS2_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs2
LFS2_CFLAGS += -Ilittlefs2 -Ilittlefs3 -DLFS2=1
LFS2_FILTER ?= sed -n -e'1p' -e'/\<lfs2/p'
LFS2_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs2/*.c))
LFS2_OBJ := $(LFS2_SRC:%.c=$(LFS2_BUILDDIR)/%.o)
LFS2_DEP := $(LFS2_OBJ:.o=.d)
LFS2_CI  := $(LFS2_OBJ:.o=.ci)
LFS2_BENCH_SRC ?= \
		$(LFS2_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS2_BENCH_B   := \
		$(LFS2_BENCH_SRC:%.c=$(LFS2_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS2_BUILDDIR)/%.b.c)
LFS2_BENCH_A   := $(LFS2_BENCH_B:.b.c=.b.a.c)
LFS2_BENCH_OBJ := $(LFS2_BENCH_A:.b.a.c=.b.a.o)
LFS2_BENCH_DEP := $(LFS2_BENCH_OBJ:.o=.d)
LFS2_BENCH_CI  := $(LFS2_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs2
U_lfs2 = LFS2
N_lfs2 = 2
I_lfs2 = 2
C_lfs2 = $(C_GREEN)
F_lfs2 = ^ # triangle up
DEFAULT_SIZE_FILESYSTEMS  += lfs2
DEFAULT_BUILD_FILESYSTEMS += lfs2
DEFAULT_BENCH_FILESYSTEMS += lfs2
DEFAULT_LFS2_FILESYSTEMS  += lfs2

# include compile-time deps
-include $(LFS2_DEP)
-include $(LFS2_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS2_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS2_BUILDDIR) \
		$(dir $(LFS2_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs2 related ctags
.PHONY: tags-lfs2 ctags-lfs2
tags-lfs2 ctags-lfs2: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS2_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs2
build-lfs2: $(LFS2_BENCH_RUNNER)

# bench-runner rules
$(LFS2_BENCH_RUNNER): $(LFS2_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS2_CFLAGS) $^ $(LFLAGS) -o$@

.SECONDEXPANSION:
$(LFS2_BUILDDIR)/%.o $(LFS2_BUILDDIR)/%.ci: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -c -MMD $(CFLAGS) $(LFS2_CFLAGS) $< -o$(firstword $@)

$(LFS2_BUILDDIR)/%.o $(LFS2_BUILDDIR)/%.ci: $(LFS2_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS2_CFLAGS) $< -o$(firstword $@)

.SECONDEXPANSION:
$(LFS2_BUILDDIR)/%.s: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -S $(CFLAGS) $(LFS2_CFLAGS) $< -o$@

$(LFS2_BUILDDIR)/%.s: $(LFS2_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS2_CFLAGS) $< -o$@

$(LFS2_BUILDDIR)/%.a.c: $(LFS2_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs2_ $< -o$@

$(LFS2_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS2_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS2_BUILDDIR)/%.b.c: $(LFS2_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
