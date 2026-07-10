ifndef LFS3GBP_MK
LFS3GBP_MK := 1

# include common makefile
include Makefiles/common.mk


# littlefs3 bench-runner and sources
LFS3GBP_BUILDDIR     ?= $(BUILDDIR)/littlefs3gbp
LFS3GBP_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.lfs3gbp
LFS3GBP_CFLAGS += -Ilittlefs3 -DLFS3=1 -DLFS3_YES_GBMAP=1
LFS3GBP_CFLAGS += -DLFS3_PREERASE=1 -DLFS3_YES_REVPERTURB=1
LFS3GBP_FILTER ?= sed -n -e'1p' -e'/\<lfs3_.\+bd/d' -e'/\<lfs3/p'
LFS3GBP_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard littlefs3/*.c))
LFS3GBP_OBJ := $(LFS3GBP_SRC:%.c=$(LFS3GBP_BUILDDIR)/%.o)
LFS3GBP_DEP := $(LFS3GBP_OBJ:.o=.d)
LFS3GBP_CI  := $(LFS3GBP_OBJ:.o=.ci)
LFS3GBP_BENCH_SRC ?= \
		$(LFS3GBP_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
LFS3GBP_BENCH_B   := \
		$(LFS3GBP_BENCH_SRC:%.c=$(LFS3GBP_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(LFS3GBP_BUILDDIR)/%.b.c)
LFS3GBP_BENCH_A   := $(LFS3GBP_BENCH_B:.b.c=.b.a.c)
LFS3GBP_BENCH_OBJ := $(LFS3GBP_BENCH_A:.b.a.c=.b.a.o)
LFS3GBP_BENCH_DEP := $(LFS3GBP_BENCH_OBJ:.o=.d)
LFS3GBP_BENCH_CI  := $(LFS3GBP_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += lfs3gbp
U_lfs3gbp = LFS3GBP
N_lfs3gbp = 32
I_lfs3gbp = 0
C_lfs3gbp = $(C_BLUE)
F_lfs3gbp = $$$$gbp$$$$ # gbp
DEFAULT_SIZE_FILESYSTEMS  += lfs3gbp
DEFAULT_BUILD_FILESYSTEMS += lfs3gbp
DEFAULT_BENCH_FILESYSTEMS += lfs3gbp
DEFAULT_LFS3_FILESYSTEMS  += lfs3gbp

# include compile-time deps
-include $(LFS3GBP_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(LFS3GBP_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(LFS3GBP_BUILDDIR) \
		$(dir $(LFS3GBP_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate littlefs3 related ctags
.PHONY: tags-lfs3gbp ctags-lfs3gbp
tags-lfs3gbp ctags-lfs3gbp: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(LFS3GBP_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-lfs3gbp
build-lfs3gbp: $(LFS3GBP_BENCH_RUNNER)

# bench-runner rules
$(LFS3GBP_BENCH_RUNNER): $(LFS3GBP_BENCH_OBJ)
	$(CC) $(CFLAGS) $(LFS3GBP_CFLAGS) $^ $(LFLAGS) -o$@

.SECONDEXPANSION:
$(LFS3GBP_BUILDDIR)/%.o $(LFS3GBP_BUILDDIR)/%.ci: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -c -MMD $(CFLAGS) $(LFS3GBP_CFLAGS) $< -o$(firstword $@)

$(LFS3GBP_BUILDDIR)/%.o $(LFS3GBP_BUILDDIR)/%.ci: $(LFS3GBP_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(LFS3GBP_CFLAGS) $< -o$(firstword $@)

.SECONDEXPANSION:
$(LFS3GBP_BUILDDIR)/%.s: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -S $(CFLAGS) $(LFS3GBP_CFLAGS) $< -o$@

$(LFS3GBP_BUILDDIR)/%.s: $(LFS3GBP_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(LFS3GBP_CFLAGS) $< -o$@

$(LFS3GBP_BUILDDIR)/%.a.c: $(LFS3GBP_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Plfs3_ $< -o$@

$(LFS3GBP_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(LFS3GBP_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(LFS3GBP_BUILDDIR)/%.b.c: $(LFS3GBP_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
