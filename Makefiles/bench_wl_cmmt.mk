ifndef BENCH_WL_CMMT_MK
BENCH_WL_CMMT_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_CMMT_RESULTSDIR ?= $(RESULTSDIR)/wl_cmmt
# overrideable plots dir
WL_CMMT_PLOTSDIR ?= $(PLOTSDIR)/wl_cmmt
# overrideable tikz dir
WL_CMMT_TIKZDIR ?= $(TIKZDIR)/wl_cmmt


# range of percentiles to measure
WL_CMMT_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# range of gc_compactmeta_thresh to test
#
# this depends on disk geometry
WL_CMMT_nor_COMPACTMETA_THRESHES ?= $\
	2048,2176,2304,2432,2560,2688,2816,2944,$\
	3072,3200,3328,3456,3584,3712,3840,3968,$\
	4096
WL_CMMT_nand_COMPACTMETA_THRESHES ?= $\
	65536,69632,73728,77824,81920,86016,90112,94208,$\
	98304,102400,106496,110592,114688,118784,122880,126976,$\
	131072

# set gc_compactbtree_thresh to zero for this one
WL_CMMT_COMPACTBTREE_THRESH ?= 0

# run with gc
BENCHFLAGS += -DGC=1 -DGC_FLAGS=0x00080000


# default bench filesystems to default littlefs3 filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_LFS3_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WL_CMMT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WL_CMMT_RESULTSDIR) \
		$(WL_CMMT_PLOTSDIR) \
		$(WL_CMMT_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-cmmt
all bench bench-wl-cmmt: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_CMMT_RESULTSDIR)/bench_wl_cmmt.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - compactmeta threshes
# $7 - compactbtree thresh
#
define BENCH_WL_CMMT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_CMMT_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_CMMT_P))),$\
			-Sgc=$(p)) \
		-DGC_COMPACTMETA_THRESH=$(or $6,$(WL_CMMT_$(4)_COMPACTMETA_THRESHES)) \
		-DGC_COMPACTBTREE_THRESH=$(or $7,$(WL_CMMT_COMPACTBTREE_THRESH)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_CMMT_RULE,$\
				$(WL_CMMT_RESULTSDIR)/bench_wl_cmmt.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-cmmt
all plot plot-wl-cmmt: \
		$(WL_CMMT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_CMMT_P)), \
				$(WL_CMMT_PLOTSDIR)/plot_wl_cmmt.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_CMMT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_CMMT_P)), \
			echo -e "<p><img src="plot_wl_cmmt.$(p).$(g).svg"></p>" >> $@ $(nl)))
	echo -e "$(subst $(nl),\n,$(HTML_FOOTER))" >> $@

# core plot rule
#
# $1 - target
# $2 - sources
# $3 - title
# $4 - x-axis
# $5 - x-ticks
# $6 - x-skip
# $7 - extra plotmpl.py flags
#
define PLOT_WL_CMMT_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-S$4=$4 -bcase -bFS -b$4 -bprobe -Dprobe='*+$$*' \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-bprobe \
		--subplot=" \
				--title='seq' \
				--ylabel='latency (write)' \
				-Dcase=bench_wl_seq \
				-Dprobe='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				--ylabel='latency (gc)' \
				-Dcase=bench_wl_seq \
				-Dprobe='gc+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wl_random \
				-Dprobe='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				-Dcase=bench_wl_random \
				-Dprobe='gc+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wl_logging \
				-Dprobe='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				-Dcase=bench_wl_logging \
				-Dprobe='gc+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wl_many \
				-Dprobe='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				-Dcase=bench_wl_many \
				-Dprobe='gc+*' \
				-ylatency --yunits=s\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		-X"-0.25,$\
			$$(shell python -c 'b=len("$5".split(","))-1; print(b+1/4)')" \
		$$(shell python -c '$\
			for i, fs in list(enumerate("$5".split(",")))[::$6]: $\
				print("--add-xticklabel=%d=\"%s\"" % (i, fs))') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WL_CMMT_RULE,$\
		$(WL_CMMT_PLOTSDIR)/plot_wl_cmmt.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_CMMT_RESULTSDIR)/bench_wl_cmmt.$(c).$(fs).$(g).csv)),$\
		"compactmeta threshes - $$* - $(g) - simulated latency",$\
		GC_COMPACTMETA_THRESH,$\
		$(WL_CMMT_$(g)_COMPACTMETA_THRESHES),$\
		2,$\
		--xlabel="compactmeta thresh")))


endif
