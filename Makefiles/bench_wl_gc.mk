ifndef BENCH_WL_GC_MK
BENCH_WL_GC_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_GC_RESULTSDIR ?= $(RESULTSDIR)/wl_gc
# overrideable plots dir
WL_GC_PLOTSDIR ?= $(PLOTSDIR)/wl_gc
# overrideable tikz dir
WL_GC_TIKZDIR ?= $(TIKZDIR)/wl_gc


# range of percentiles to measure
WL_GC_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# run with gc
BENCHFLAGS += -DGC=1


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WL_GC_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WL_GC_RESULTSDIR) \
		$(WL_GC_PLOTSDIR) \
		$(WL_GC_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-gc
all bench: bench-wl-gc
bench-wl-gc: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_GC_RESULTSDIR)/bench_wl_gc.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
#
define BENCH_WL_GC_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_GC_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_GC_P))),$\
			-Sgc=$(p)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_GC_RULE,$\
				$(WL_GC_RESULTSDIR)/bench_wl_gc.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-gc
all plot: plot-wl-gc
plot-wl-gc: \
		$(WL_GC_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WL_GC_PLOTSDIR)/plot_wl_gc.$(g).svg) \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_GC_P)), \
				$(WL_GC_PLOTSDIR)/plot_wl_gc.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_GC_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wl_gc.$(g).svg"></p>" >> $@ $(nl))
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_GC_P)), \
			echo -e "<p><img src="plot_wl_gc.$(p).$(g).svg"></p>" >> $@ $(nl)))
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
define PLOT_WL_GC_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-Si='enumerate()' -bcase -bFS -b$4 \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		--subplot=" \
				--title='seq' \
				--ylabel='write latency' \
				-Dcase=bench_wl_seq \
				-D$4='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				--ylabel='gc latency' \
				-Dcase=bench_wl_seq \
				-D$4='gc+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wl_random \
				-D$4='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				--ylabel='gc latency' \
				-Dcase=bench_wl_random \
				-D$4='gc+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wl_logging \
				-D$4='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				--ylabel='gc latency' \
				-Dcase=bench_wl_logging \
				-D$4='gc+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wl_many \
				-D$4='write+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				--ylabel='gc latency' \
				-Dcase=bench_wl_many \
				-D$4='gc+*' \
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
			for i, p in list(enumerate("$5".split(",")))[::$6]: $\
				print("--add-xticklabel=%d=\"%s\"" % (i, p))') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WL_GC_RULE,$\
		$(WL_GC_PLOTSDIR)/plot_wl_gc.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_GC_RESULTSDIR)/bench_wl_gc.$(c).$(fs).$(g).csv)),$\
		"$(g) - simulated latency - with gc",$\
		probe,$\
		$(WL_GC_P),$\
		1,$\
		--xlabel="percentile")))

# per-percentile plot rule
#
# $1 - target
# $2 - sources
# $3 - title
# $4 - x-axis
# $5 - x-ticks
# $6 - x-skip
# $7 - extra plotmpl.py flags
#
define PLOT_WL_GC_P_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-Si='enumerate()' -bcase -b$4 -bprobe -Dprobe='*+$$*' \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 -H175 \
		--title=$3 \
		-bprobe \
		--subplot=" \
				--title='seq (write)' \
				--ylabel='latency' \
				-Dcase=bench_wl_seq \
				-Dprobe='write+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='seq (gc)' \
				-Dcase=bench_wl_seq \
				-Dprobe='gc+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='random (write)' \
				-Dcase=bench_wl_random \
				-Dprobe='write+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='random (gc)' \
				-Dcase=bench_wl_random \
				-Dprobe='gc+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='logging (write)' \
				-Dcase=bench_wl_logging \
				-Dprobe='write+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='logging (gc)' \
				-Dcase=bench_wl_logging \
				-Dprobe='gc+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='many (write)' \
				-Dcase=bench_wl_many \
				-Dprobe='write+*' \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='many (gc)' \
				-Dcase=bench_wl_many \
				-Dprobe='gc+*' \
				-ylatency --yunits=s" \
		-Fo: -C'write+*=$(C_BLUE)' -C'gc+*=$(C_ORANGE)' \
		-X"-0.25,$\
			$$(shell python -c 'b=len("$5".split())-1; print(b+1/4)')" \
		$$(shell python -c '$\
			for i, fs in list(enumerate("$5".split()))[::$6]: $\
				print("--add-xticklabel=%d=\"%s\"" % (i, fs))') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# per-percentile plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WL_GC_P_RULE,$\
		$(WL_GC_PLOTSDIR)/plot_wl_gc.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_GC_RESULTSDIR)/bench_wl_gc.$(c).$(fs).$(g).csv)),$\
		"$$* - $(g) - simulated latency",$\
		FS,$\
		$(BENCH_FILESYSTEMS),$\
		1,$\
		--xlabel="filesystem")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wl-gc
all tikz tikz-wl-gc: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WL_GC_TIKZDIR)/tikz_wl_gc.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - percentiles
#
define TIKZ_WL_GC_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach p, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-bi=0 -Dprobe='write+$(p)' \
				-flatency_$(subst .,$(nil),$(p))='bench_simtime/1.0e9' \
				-o-)) \
		$(foreach p, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-bi=0 -Dprobe='gc+$(p)' \
				-fgc_$(subst .,$(nil),$(p))='bench_simtime/1.0e9' \
				-o-)) \
		-bi \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WL_GC_RULE,$\
				$(WL_GC_TIKZDIR)/tikz_wl_gc.$(c).$(fs).$(g).csv,$\
				$(WL_GC_RESULTSDIR)/bench_wl_gc.$(c).$(fs).$(g).csv,$\
				$(WL_GC_P))))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wl-gc
save save-results: save-results-wl-gc
save-results-wl-gc:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WL_GC_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wl-gc
save save-plots: save-plots-wl-gc
save-plots-wl-gc:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WL_GC_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wl-gc
save save-tikz: save-tikz-wl-gc
save-tikz-wl-gc:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WL_GC_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wl-gc touch-results-wl-gc
reuse-results touch-results: reuse-results-wl-gc touch-results-wl-gc
reuse-results-wl-gc touch-results-wl-gc:
	find $(WL_GC_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wl-gc
clean clean-results: clean-results-wl-gc
clean-results-wl-gc:
	rm -rf $(WL_GC_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wl-gc
clean clean-plots: clean-plots-wl-gc
clean-plots-wl-gc:
	rm -rf $(WL_GC_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wl-gc
clean clean-tikz: clean-tikz-wl-gc
clean-tikz-wl-gc:
	rm -rf $(WL_GC_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
