ifndef LFS1_MK
LFS1_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs1 bench-runner and sources
LFS1_BUILDDIR     ?= $(BUILDDIR)/littlefs1
LFS1_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs1
LFS1_CFLAGS += -Ilittlefs1 -Ilittlefs3 -DLFS1=1
LFS1_FILTER ?= sed -n -e'1p' -e'/\<lfs1/p'
LFS1_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs1/*.c))
LFS1_OBJ := $(LFS1_SRC:%.c=$(LFS1_BUILDDIR)/%.o)
LFS1_DEP := $(LFS1_OBJ:.o=.d)
LFS1_CI  := $(LFS1_OBJ:.o=.ci)
LFS1_BENCH_SRC ?= \
		$(LFS1_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS1_BENCH_B   := \
		$(LFS1_BENCH_SRC:%.c=$(LFS1_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS1_BUILDDIR)/%.b.c)
LFS1_BENCH_A   := $(LFS1_BENCH_B:.b.c=.b.a.c)
LFS1_BENCH_OBJ := $(LFS1_BENCH_A:.b.a.c=.b.a.o)
LFS1_BENCH_DEP := $(LFS1_BENCH_OBJ:.o=.d)
LFS1_BENCH_CI  := $(LFS1_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs1
U_lfs1 = LFS1
N_lfs1 = 1
I_lfs1 = 3
C_lfs1 = $(C_GREEN)
F_lfs1 = D # diamond
DEFAULT_SIZE_FILESYSTEMS += lfs1

# include compile-time deps
-include $(LFS1_DEP)
-include $(LFS1_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS1_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS1_BUILDDIR) \
		$(dir $(LFS1_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs1 related ctags
.PHONY: tags-lfs1 ctags-lfs1
tags-lfs1 ctags-lfs1: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS1_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs1
build-lfs1: $(LFS1_BENCH_RUNNER)

# bench-runner rules
$(LFS1_BENCH_RUNNER): $(LFS1_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS1_CFLAGS) $^ $(LFLAGS) -o$@

.SECONDEXPANSION:
$(LFS1_BUILDDIR)/%.o $(LFS1_BUILDDIR)/%.ci: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -c -MMD $(CFLAGS) $(LFS1_CFLAGS) $< -o$(firstword $@)

$(LFS1_BUILDDIR)/%.o $(LFS1_BUILDDIR)/%.ci: $(LFS1_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS1_CFLAGS) $< -o$(firstword $@)

.SECONDEXPANSION:
$(LFS1_BUILDDIR)/%.s: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -S $(CFLAGS) $(LFS1_CFLAGS) $< -o$@

$(LFS1_BUILDDIR)/%.s: $(LFS1_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS1_CFLAGS) $< -o$@

$(LFS1_BUILDDIR)/%.a.c: $(LFS1_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs1_ -Plfs1_ $< -o$@

$(LFS1_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS1_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS1_BUILDDIR)/%.b.c: $(LFS1_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
