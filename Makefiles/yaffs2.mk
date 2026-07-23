ifndef YAFFS2_MK
YAFFS2_MK := 1

# include common makefile
include Makefiles/common.mk


# yaffs2 hacks
#
# note yaffs2 needs a preprocessing step with handle_common.sh
#
# we're feeling monstrous today so instead of actually running yaffs2's
# handle_common.sh script, just parse it for the info we need
#
# two hacks:
#
# - force inject yaffscfg.h into all files, sometimes redundantly
#
#   yaffs2 doesn't seem to consistently include yaffscfg.h, though this
#   may be a case where I'm misunderstanding yaffs2 configuration works,
#   that or a side-effect of yaffs2 being Linux-first
#
# - force yaffsfs_handlesInitialised to be non-static
#
#   there doesn't seem to be any other way to force reset yaffs2's
#   global state after a bench failure
#
YAFFS2_CORE_C := $(shell grep -o '[^ ]*\.c' yaffs2/direct/handle_common.sh)
YAFFS2_CORE_H := $(shell grep -o '[^ ]*\.h' yaffs2/direct/handle_common.sh)
YAFFS2_CORE_E := \
		-e '1i\#include "yaffscfg.h"' \
		$(shell grep -o '\-e "[^"]*"' yaffs2/direct/handle_common.sh)
YAFFS2_DIRECT_C := $(notdir $(wildcard yaffs2/direct/*.c))
YAFFS2_DIRECT_H := $(filter-out yaffscfg.h,\
		$(notdir $(wildcard yaffs2/direct/*.h)))
YAFFS2_DIRECT_E := \
		-e '1i\#include "yaffscfg.h"' \
		-e 's/static int yaffsfs_handlesInitialised/$\
			int yaffsfs_handlesInitialised/'

# yaffs2 bench-runner and sources
YAFFS2_BUILDDIR     ?= $(BUILDDIR)/yaffs2
YAFFS2_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.yaffs2
YAFFS2_CFLAGS += -Iyaffs2 -I$(YAFFS2_BUILDDIR)/yaffs2 -Ilittlefs3 -DYAFFS2=1
YAFFS2_FILTER ?= sed -n -e'1p' -e'/\<yaffs/p'
YAFFS2_SRC  ?= \
		$(addprefix yaffs2/core/,$(YAFFS2_CORE_C)) \
		$(addprefix yaffs2/direct/,$(YAFFS2_DIRECT_C))
YAFFS2_SRC_ := \
		$(addprefix $(YAFFS2_BUILDDIR)/yaffs2/,\
			$(YAFFS2_CORE_C) \
			$(YAFFS2_DIRECT_C))
YAFFS2_OBJ  := $(YAFFS2_SRC_:.c=.o)
YAFFS2_DEP  := $(YAFFS2_OBJ:.o=.d)
YAFFS2_CI   := $(YAFFS2_OBJ:.o=.ci)
YAFFS2_BENCH_SRC ?= \
		$(YAFFS2_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
YAFFS2_BENCH_SRC_ := \
		$(YAFFS2_SRC_) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
YAFFS2_BENCH_B   := \
		$(patsubst %.c,$(YAFFS2_BUILDDIR)/%.b.c,\
			$(filter-out $(YAFFS2_BUILDDIR)/%,$(YAFFS2_BENCH_SRC_))) \
		$(patsubst %.c,%.b.c,\
			$(filter $(YAFFS2_BUILDDIR)/%,$(YAFFS2_BENCH_SRC_))) \
		$(BENCHES:%.toml=$(YAFFS2_BUILDDIR)/%.b.c)
# let's not stress test prettyasserts right now
YAFFS2_BENCH_A   := \
        $(patsubst %.b.c,%.b.a.c,\
            $(filter-out $(YAFFS2_BUILDDIR)/yaffs2/%,$(YAFFS2_BENCH_B)))
YAFFS2_BENCH_OBJ := \
        $(patsubst %.b.a.c,%.b.a.o,$(YAFFS2_BENCH_A)) \
        $(patsubst %.b.c,%.b.o,\
			$(filter $(YAFFS2_BUILDDIR)/yaffs2/%,$(YAFFS2_BENCH_B)))
YAFFS2_BENCH_DEP := $(YAFFS2_BENCH_OBJ:.o=.d)
YAFFS2_BENCH_CI  := $(YAFFS2_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += yaffs2
U_yaffs2 = YAFFS2
N_yaffs2 = 5
I_yaffs2 = 5
C_yaffs2 = $(C_PURPLE)
F_yaffs2 = P # big plus
DEFAULT_SIZE_FILESYSTEMS   += yaffs2
DEFAULT_BUILD_FILESYSTEMS  += yaffs2
DEFAULT_BENCH_FILESYSTEMS  += yaffs2
DEFAULT_YAFFS2_FILESYSTEMS += yaffs2

# include compile-time deps
-include $(YAFFS2_DEP)
-include $(YAFFS2_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(YAFFS2_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(YAFFS2_BUILDDIR) \
				$(dir $(YAFFS2_BENCH_OBJ)), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate yaffs2 related ctags
.PHONY: tags-yaffs2 ctags-yaffs2
tags-yaffs2 ctags-yaffs2: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(YAFFS2_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-yaffs2
build-yaffs2: $(YAFFS2_BENCH_RUNNER)

# bench-runner rules
$(YAFFS2_BENCH_RUNNER): $(YAFFS2_BENCH_OBJ)
	$(CC) $(CFLAGS) $(YAFFS2_CFLAGS) $^ $(LFLAGS) -o$@

.SECONDEXPANSION:
$(YAFFS2_BUILDDIR)/%.o $(YAFFS2_BUILDDIR)/%.ci: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -c -MMD $(CFLAGS) $(YAFFS2_CFLAGS) $< -o$(firstword $@)

$(YAFFS2_BUILDDIR)/%.o $(YAFFS2_BUILDDIR)/%.ci: $(YAFFS2_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(YAFFS2_CFLAGS) $< -o$(firstword $@)

.SECONDEXPANSION:
$(YAFFS2_BUILDDIR)/%.s: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -S $(CFLAGS) $(YAFFS2_CFLAGS) $< -o$@

$(YAFFS2_BUILDDIR)/%.s: $(YAFFS2_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(YAFFS2_CFLAGS) $< -o$@

$(YAFFS2_BUILDDIR)/%.a.c: $(YAFFS2_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Pyaffs2_ $< -o$@

$(YAFFS2_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(YAFFS2_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(YAFFS2_BUILDDIR)/%.b.c: $(YAFFS2_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

# yaffs2 preprocessing rules
#
# yaffs2 expects some core names to be preprocessed in direct mode,
# which we've grepped and apply here, see above
#
$(YAFFS2_OBJ) $(YAFFS2_BENCH_OBJ): \
		$(addprefix $(YAFFS2_BUILDDIR)/yaffs2/,\
			$(YAFFS2_CORE_H) \
			$(YAFFS2_DIRECT_H))

$(YAFFS2_BUILDDIR)/yaffs2/%.h: yaffs2/direct/%.h
	sed $< $(YAFFS2_DIRECT_E) >$@

$(YAFFS2_BUILDDIR)/yaffs2/%.h: yaffs2/core/%.h
	sed $< $(YAFFS2_CORE_E) >$@

$(YAFFS2_BUILDDIR)/yaffs2/%.c: yaffs2/direct/%.c
	sed $< $(YAFFS2_DIRECT_E) >$@

$(YAFFS2_BUILDDIR)/yaffs2/%.c: yaffs2/core/%.c
	sed $< $(YAFFS2_CORE_E) >$@


endif
