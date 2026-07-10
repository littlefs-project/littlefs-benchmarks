ifndef SPIFFS_MK
SPIFFS_MK := 1

# include common makefile
include Makefiles/common.mk


# spiffs bench-runner and sources
SPIFFS_BUILDDIR     ?= $(BUILDDIR)/spiffs
SPIFFS_BENCH_RUNNER ?= $(BUILDDIR)/bench_runner.spiffs
SPIFFS_CFLAGS += -Ispiffs/src -Ilittlefs3 -DSPIFFS=1
SPIFFS_FILTER ?= sed -n -e'1p' -e'/\<SPIFFS/p' -e'/\<spiffs/p'
SPIFFS_SRC ?= $(filter-out %.t.c %.b.c %.a.c,$(wildcard spiffs/src/*.c))
SPIFFS_OBJ := $(SPIFFS_SRC:%.c=$(SPIFFS_BUILDDIR)/%.o)
SPIFFS_DEP := $(SPIFFS_OBJ:.o=.d)
SPIFFS_CI  := $(SPIFFS_OBJ:.o=.ci)
SPIFFS_BENCH_SRC ?= \
		$(SPIFFS_SRC) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard bd/*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard runners/bench_*.c)) \
		$(filter-out %.t.c %.b.c %.a.c,$(wildcard benches/*.c))
SPIFFS_BENCH_B   := \
		$(SPIFFS_BENCH_SRC:%.c=$(SPIFFS_BUILDDIR)/%.b.c) \
		$(BENCHES:%.toml=$(SPIFFS_BUILDDIR)/%.b.c)
# let's not stress test prettyasserts right now
SPIFFS_BENCH_A   := \
        $(patsubst %.b.c,%.b.a.c,\
            $(filter-out $(SPIFFS_BUILDDIR)/spiffs/%,$(SPIFFS_BENCH_B)))
SPIFFS_BENCH_OBJ := \
        $(patsubst %.b.a.c,%.b.a.o,$(SPIFFS_BENCH_A)) \
        $(patsubst %.b.c,%.b.o,\
			$(filter $(SPIFFS_BUILDDIR)/spiffs/%,$(SPIFFS_BENCH_B)))
SPIFFS_BENCH_DEP := $(SPIFFS_BENCH_OBJ:.o=.d)
SPIFFS_BENCH_CI  := $(SPIFFS_BENCH_OBJ:.o=.ci)

# add to list of filesystems
FILESYSTEMS += spiffs
U_spiffs = SPIFFS
N_spiffs = 4
I_spiffs = 4
C_spiffs = $(C_RED)
F_spiffs = X # big x
DEFAULT_SIZE_FILESYSTEMS  += spiffs
DEFAULT_BUILD_FILESYSTEMS += spiffs
DEFAULT_BENCH_FILESYSTEMS += spiffs

# include compile-time deps
-include $(SPIFFS_BENCH_DEP)

# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(SPIFFS_BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(SPIFFS_BUILDDIR) \
		$(dir $(SPIFFS_BENCH_OBJ))))
endif


#======================================================================#
# ctags rules														   #
#======================================================================#

## Generate spiffs related ctags
.PHONY: tags-spiffs ctags-spiffs
tags-spiffs ctags-spiffs: ctags-common
	$(strip $(CTAGS) \
			--totals --append --fields=+n \
			$(SPIFFS_BENCH_SRC))


#======================================================================#
# build rules														   #
#======================================================================#

## Build the bench-runner
.PHONY: build-spiffs
build-spiffs: $(SPIFFS_BENCH_RUNNER)

# bench-runner rules
$(SPIFFS_BENCH_RUNNER): $(SPIFFS_BENCH_OBJ)
	$(CC) $(CFLAGS) $(SPIFFS_CFLAGS) $^ $(LFLAGS) -o$@

.SECONDEXPANSION:
$(SPIFFS_BUILDDIR)/%.o $(SPIFFS_BUILDDIR)/%.ci: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -c -MMD $(CFLAGS) $(SPIFFS_CFLAGS) $< -o$(firstword $@)

$(SPIFFS_BUILDDIR)/%.o $(SPIFFS_BUILDDIR)/%.ci: $(SPIFFS_BUILDDIR)/%.c
	$(CC) -c -MMD $(CFLAGS) $(SPIFFS_CFLAGS) $< -o$(firstword $@)

.SECONDEXPANSION:
$(SPIFFS_BUILDDIR)/%.s: %.c \
		$$(if $$(findstring .b,$$*),NO)
	$(CC) -S $(CFLAGS) $(SPIFFS_CFLAGS) $< -o$@

$(SPIFFS_BUILDDIR)/%.s: $(SPIFFS_BUILDDIR)/%.c
	$(CC) -S $(CFLAGS) $(SPIFFS_CFLAGS) $< -o$@

$(SPIFFS_BUILDDIR)/%.a.c: $(SPIFFS_BUILDDIR)/%.c
	$(PRETTYASSERTS) -Plfs_ -Plfs1_ -Plfs2_ -Pspiffs_ $< -o$@

$(SPIFFS_BUILDDIR)/%.b.c: %.toml
	./scripts/bench.py -c $< $(BENCHCFLAGS) -o$@

$(SPIFFS_BUILDDIR)/%.b.c: %.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@

$(SPIFFS_BUILDDIR)/%.b.c: $(SPIFFS_BUILDDIR)/%.c $(BENCHES)
	./scripts/bench.py -c $(BENCHES) -s $< $(BENCHCFLAGS) -o$@


endif
