ifndef COMMON_MK
COMMON_MK := 1

# overrideable build dir, default to ./build
ifdef THUMB
  ifdef DEBUG
    BUILDDIR ?= build_thumb_dbg
  else
    BUILDDIR ?= build_thumb
  endif
else
  ifdef DEBUG
    BUILDDIR ?= build_dbg
  else
    BUILDDIR ?= build
  endif
endif
# overrideable codemaps dir, defaults to ./codemaps
CODEMAPSDIR ?= codemaps
# overrideable results dir, default to ./results
RESULTSDIR ?= results
# overrideable plots dir, defaults ./plots
PLOTSDIR ?= plots
# overrideable tikz dir, defaults to ./tikz
TIKZDIR ?= tikz

# optional save dir, defaults to ./saved, for quickly saving things
SAVEDIR ?= saved

# common benches
BENCHES ?= $(wildcard benches/*.toml)


# thumb mode!!? cross compile time!
ifdef THUMB
CC = arm-linux-gnueabi-gcc -mthumb -march=armv7 --static
BENCHFLAGS += --exec=qemu-arm
endif

# overridable tools/flags
CC            ?= gcc
AR            ?= ar
SIZE          ?= size
CTAGS         ?= ctags
OBJDUMP       ?= objdump
VALGRIND      ?= valgrind
GDB           ?= gdb
PERF          ?= perf
PRETTYASSERTS ?= ./scripts/prettyasserts.py

# c flags
CFLAGS += -fcallgraph-info=su
CFLAGS += -g3
CFLAGS += -I.
CFLAGS += -std=c99 -Wall -Wextra -pedantic
# labels are useful for debugging, in-function organization, etc
CFLAGS += -Wno-unused-label
CFLAGS += -Wno-unused-function
CFLAGS += -Wno-format-overflow
# compiler bug: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=101854
CFLAGS += -Wno-stringop-overflow
CFLAGS += -ftrack-macro-expansion=0
# enable stack measurements
CFLAGS += -DBENCH_STACK
CFLAGS += -Wl,--wrap=printf
CFLAGS += -Wl,--wrap=vprintf
# wrap malloc/free/realloc for heap measurements
CFLAGS += -DBENCH_HEAP
CFLAGS += -Wl,--wrap=malloc
CFLAGS += -Wl,--wrap=free
CFLAGS += -Wl,--wrap=realloc
CFLAGS += -Wl,--wrap=printf
CFLAGS += -Wl,--wrap=vprintf
# gc unused functions
CFLAGS += -ffunction-sections
CFLAGS += -fdata-sections
CFLAGS += -Wl,--gc-sections
ifdef DEBUG
CFLAGS += -O0
else
CFLAGS += -Os
CFLAGS += -DNDEBUG
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_NO_LOG)
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_NO_DEBUG)
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_NO_INFO)
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_NO_WARN)
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_NO_ERROR)
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_NO_ASSERT)
endif
ifdef TRACE
CFLAGS += $(foreach fs,LFS LFS1 LFS2 LFS3,-D$(fs)_YES_TRACE)
endif

# also forward all LFS_*, LFS2_*, and LFS3*_ environment variables
CFLAGS_FORWARD := $(foreach d,$(filter LFS_%,$(.VARIABLES)),-D$d=$($d))
CFLAGS_FORWARD += $(foreach d,$(filter LFS1_%,$(.VARIABLES)),-D$d=$($d))
CFLAGS_FORWARD += $(foreach d,$(filter LFS2_%,$(.VARIABLES)),-D$d=$($d))
CFLAGS_FORWARD += $(foreach d,$(filter LFS3_%,$(.VARIABLES)),-D$d=$($d))
CFLAGS += $(CFLAGS_FORWARD)

# bench.py -c flags
ifdef VERBOSE
BENCHCFLAGS += -v
endif
# explicit disk path?
# note the presence of a physical disk means we can't run in parallel
ifdef DISK_PATH
BENCHFLAGS += -d$(DISK_PATH)
DISK_BIG = 1
endif
# just always run benches in parallel by default, this makefile uses
# too much RAM to easily parallelize at the rule level
ifndef DISK_BIG
BENCHFLAGS += -j
# # forward -j flag
# BENCHFLAGS += $(filter -j%,$(MAKEFLAGS))
endif
ifdef PERFGEN
BENCHFLAGS += -p$(BENCH_LFS3_PERF)
endif
ifdef PERFBDGEN
BENCHFLAGS += -t$(BENCH_LFS3_TRACE) --trace-backtrace --trace-freq=100
endif
ifdef VERBOSE
BENCHFLAGS  += -v
endif
ifdef EXEC
BENCHFLAGS += --exec="$(EXEC)"
endif
ifneq ($(GDB),gdb)
BENCHFLAGS += --gdb-path="$(GDB)"
endif
ifneq ($(VALGRIND),valgrind)
BENCHFLAGS += --valgrind-path="$(VALGRIND)"
endif
ifneq ($(PERF),perf)
BENCHFLAGS += --perf-path="$(PERF)"
endif


# some colors for plots and things
ifndef LIGHT
CODEMAPFLAGS += --dark
PLOTFLAGS += --dark
endif
ifdef GGPLOT
PLOTFLAGS += --ggplot
endif
ifdef XKCD
PLOTFLAGS += --xkcd
endif

ifdef LIGHT
# colors borrowed from Seaborn
C_BLUE   = \#4c72b0bf # blue
C_ORANGE = \#dd8452bf # orange
C_GREEN  = \#55a868bf # green
C_RED    = \#c44e52bf # red
C_PURPLE = \#8172b3bf # purple
C_BROWN  = \#937860bf # brown
C_PINK   = \#da8bc3bf # pink
C_GRAY   = \#8c8c8cbf # gray
C_YELLOW = \#ccb974bf # yellow
C_CYAN   = \#64b5cdbf # cyan
else
# colors borrowed from Seaborn
C_BLUE   = \#a1c9f4bf # blue
C_ORANGE = \#ffb482bf # orange
C_GREEN  = \#8de5a1bf # green
C_RED    = \#ff9f9bbf # red
C_PURPLE = \#d0bbffbf # purple
C_BROWN  = \#debb9bbf # brown
C_PINK   = \#fab0e4bf # pink
C_GRAY   = \#cfcfcfbf # gray
C_YELLOW = \#fffea3bf # yellow
C_CYAN   = \#b9f2f0bf # cyan
endif

# some html template stuff
define HTML_HEADER
<html>
<head>
    <title>littlefs3-benchmarks</title>
    <link rel="icon" href="favicon.ico">
    <style>
    body {
        background-color: #443333;
        color: #ffffff;
    }
    </style>
</head>
<body>
endef

define HTML_FOOTER
</body>
</html>
endef


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(BUILDDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(BUILDDIR) \
		$(CODEMAPSDIR) \
		$(RESULTSDIR) \
		$(PLOTSDIR) \
		$(TIKZDIR)))
endif

# just use bash for everything, process substitution my beloved!
SHELL = /bin/bash

# default to all rule, dependents should define this
.DEFAULT_GOAL := all

# bunch of makefile quality of life thingies
.SUFFIXES:
.SECONDARY:
.DELETE_ON_ERROR:
.PHONY: PHONY
PHONY: ;
, := ,
comma := ,
nil :=
space := $(nil) $(nil)
define nl


endef


#======================================================================#
# ctags rules   													   #
#======================================================================#

## Reset ctags file and try to add everything from header files
.PHONY: tags-common ctags-common
tags-common ctags-common:
	$(strip $(CTAGS) \
			--totals --fields=+n --c-types=+p \
			$(shell find -H -name '*.h'))


#======================================================================#
# save rules, for quickly saving things								   #
#======================================================================#

## Save everything
.PHONY: save
save: \
		save-build \
		save-codemaps \
		save-results \
		save-plots \
		save-tikz

$(SAVEDIR):
	mkdir $@

## Save bench-runner things
.PHONY: save-build
save-build: $(SAVEDIR)
	cp -ru $(BUILDDIR) $(SAVEDIR)/

## Save codemaps
.PHONY: save-codemaps
save-codemaps: $(SAVEDIR)
	cp -ru $(CODEMAPSDIR) $(SAVEDIR)/

## Save bench results
.PHONY: save-results
save-results: $(SAVEDIR)
	cp -ru $(RESULTSDIR) $(SAVEDIR)/

## Save bench plots
.PHONY: save-plots
save-plots: $(SAVEDIR)
	cp -ru $(PLOTSDIR) $(SAVEDIR)/

## Save tikz
.PHONY: save-tikz
save-tikz: $(SAVEDIR)
	cp -ru $(TIKZDIR) $(SAVEDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Touch benches, triggering a rebench, but don't clean
.PHONY: touch touch-benches
touch touch-benches:
	touch $(BENCHES)

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results
reuse-results touch-results:
	find $(RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean everything
.PHONY: clean
clean: \
		clean-build \
		clean-codemaps \
		clean-results \
		clean-plots \
		clean-tikz
	@echo "# note: This does not clean saved results! To clean:"
	@echo "# note: make clean-saved"

## Clean bench-runner things
.PHONY: clean-build
clean-build:
	rm -rf $(BUILDDIR)

## Clean codemaps
.PHONY: clean-codemaps
clean-codemaps:
	rm -rf $(CODEMAPSDIR)

## Clean bench results
.PHONY: clean-results
clean-results:
	rm -rf $(RESULTSDIR)

## Clean bench plots
.PHONY: clean-plots
clean-plots:
	rm -rf $(PLOTSDIR)

## Clean tikz
.PHONY: clean-tikz
clean-tikz:
	rm -rf $(TIKZDIR)


## Clean everything saved, this is _not_ cleaned by default
.PHONY: clean-saved
clean-saved: \
		clean-saved-build \
		clean-saved-codemaps \
		clean-saved-results \
		clean-saved-plots \
		clean-saved-tikz
	rm -df $(SAVEDIR)

## Clean saved bench-runner things, this is _not_ cleaned by default
.PHONY: clean-saved-build
clean-saved-build:
	rm -rf $(SAVEDIR)/$(BUILDDIR)

## Clean saved codemaps, this is _not_ cleaned by default
.PHONY: clean-saved-codemaps
clean-saved-codemaps:
	rm -rf $(SAVEDIR)/$(CODEMAPSDIR)

## Clean saved bench results, this is _not_ cleaned by default
.PHONY: clean-saved-results
clean-saved-results:
	rm -rf $(SAVEDIR)/$(RESULTSDIR)

## Clean saved bench plots, this is _not_ cleaned by default
.PHONY: clean-saved-plots
clean-saved-plots:
	rm -rf $(SAVEDIR)/$(PLOTSDIR)

## Clean saved tikz, this is _not_ cleaned by default
.PHONY: clean-saved-tikz
clean-saved-tikz:
	rm -rf $(SAVEDIR)/$(TIKZDIR)


endif
