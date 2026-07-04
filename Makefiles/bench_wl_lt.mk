ifndef BENCH_WL_LT_MK
BENCH_WL_LT_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_LT_RESULTSDIR ?= $(RESULTSDIR)/wl_lt
# overrideable plots dir
WL_LT_PLOTSDIR ?= $(PLOTSDIR)/wl_lt
# overrideable tikz dir
WL_LT_TIKZDIR ?= $(TIKZDIR)/wl_lt


# range of percentiles to measure
WL_LT_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# default lookahead size, note this ends up *8
WL_LT_LOOKAHEAD_SIZE ?= 16

# range of gc_lookahead_thresh to test
WL_LT_LOOKAHEAD_THRESHES ?= 128,127,126,124,120,112,96,64,0

# run with gc
BENCHFLAGS += -DGC=1 -DGC_FLAGS=0x00020000


# default bench filesystems to default littlefs3 filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_LFS3_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WL_LT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WL_LT_RESULTSDIR) \
		$(WL_LT_PLOTSDIR) \
		$(WL_LT_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-lt
all bench bench-wl-lt: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_LT_RESULTSDIR)/bench_wl_lt.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - lookahead size
# $7 - lookahead threshes
#
define BENCH_WL_LT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_LT_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_LT_P))),$\
			-Sgc=$(p)) \
		-DLOOKAHEAD_SIZE=$(or $6,$(WL_LT_LOOKAHEAD_SIZE)) \
		-DGC_LOOKAHEAD_THRESH=$(or $7,$(WL_LT_LOOKAHEAD_THRESHES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_LT_RULE,$\
				$(WL_LT_RESULTSDIR)/bench_wl_lt.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-lt
all plot plot-wl-lt: \
		$(WL_LT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_LT_P)), \
				$(WL_LT_PLOTSDIR)/plot_wl_lt.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_LT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_LT_P)), \
			echo -e "<p><img src="plot_wl_lt.$(p).$(g).svg"></p>" >> $@ $(nl)))
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
define PLOT_WL_LT_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-s$4=$4 -bcase -bFS -b$4 -bprobe -Dprobe='*+$$*' \
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
	$(eval $(call PLOT_WL_LT_RULE,$\
		$(WL_LT_PLOTSDIR)/plot_wl_lt.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_LT_RESULTSDIR)/bench_wl_lt.$(c).$(fs).$(g).csv)),$\
		"lookahead threshes - $$* - $(g) - simulated latency",$\
		GC_LOOKAHEAD_THRESH,$\
		$(WL_LT_LOOKAHEAD_THRESHES),$\
		1,$\
		--xlabel="lookahead thresh")))


endif
