ifndef BENCH_WL_GCT_MK
BENCH_WL_GCT_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_GCT_RESULTSDIR ?= $(RESULTSDIR)/wl_gct
# overrideable plots dir
WL_GCT_PLOTSDIR ?= $(PLOTSDIR)/wl_gct
# overrideable tikz dir
WL_GCT_TIKZDIR ?= $(TIKZDIR)/wl_gct


# range of percentiles to measure
WL_GCT_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# range of gc times to measure
WL_GCT_GC_TIMES ?= $\
		1,10,100,$\
		1000,10000,100000,$\
		1000000,10000000,100000000,$\
		1000000000,10000000000,100000000000,$\
		1000000000000,10000000000000



# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WL_GCT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WL_GCT_RESULTSDIR) \
		$(WL_GCT_PLOTSDIR) \
		$(WL_GCT_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-gct
all bench: bench-wl-gct
bench-wl-gct: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_GCT_RESULTSDIR)/bench_wl_gct.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - gc times
#
define BENCH_WL_GCT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_GCT_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_GCT_P))),$\
			-Sgc=$(p)) \
		-DGC=1 \
		-DGC_TIME=$(or $6,$(WL_GCT_GC_TIMES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_GCT_RULE,$\
				$(WL_GCT_RESULTSDIR)/bench_wl_gct.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-gct
all plot: plot-wl-gct
plot-wl-gct: \
		$(WL_GCT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_GCT_P)), \
				$(WL_GCT_PLOTSDIR)/plot_wl_gct.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_GCT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_GCT_P)), \
			echo -e "<p><img src="plot_wl_gct.$(p).$(g).svg"></p>" >> $@ $(nl)))
	echo -e "$(subst $(nl),\n,$(HTML_FOOTER))" >> $@

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
define PLOT_WL_GCT_P_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 -Dprobe='write+$$*' \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-x$4 \
		--xlog \
		--subplot=" \
				--title='seq' \
				--ylabel='latency' \
				-Dcase=bench_wl_seq \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wl_random \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wl_logging \
				-ylatency --yunits=s" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wl_many \
				-ylatency --yunits=s" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		-X"$$(shell python -c 'a=min([$5]); print(a-a/4)'),$\
			$$(shell python -c 'b=max([$5]); print(b+b/4)')" \
		$$(shell python -c '$\
			for n in [$5][::$6]: $\
				print("--add-xticklabel=%d=\"%%(x)d\"" % n)') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# per-percentile plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WL_GCT_P_RULE,$\
		$(WL_GCT_PLOTSDIR)/plot_wl_gct.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_GCT_RESULTSDIR)/bench_wl_gct.$(c).$(fs).$(g).csv)),$\
		"gc times - $$* - $(g) - simulated latency",$\
		GC_TIME,$\
		$(WL_GCT_GC_TIMES),$\
		1,$\
		--xlabel="gc time")))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wl-gct
save save-results: save-results-wl-gct
save-results-wl-gct:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WL_GCT_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wl-gct
save save-plots: save-plots-wl-gct
save-plots-wl-gct:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WL_GCT_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wl-gct
save save-tikz: save-tikz-wl-gct
save-tikz-wl-gct:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WL_GCT_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wl-gct touch-results-wl-gct
reuse-results touch-results: reuse-results-wl-gct touch-results-wl-gct
reuse-results-wl-gct touch-results-wl-gct:
	find $(WL_GCT_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wl-gct
clean clean-results: clean-results-wl-gct
clean-results-wl-gct:
	rm -rf $(WL_GCT_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wl-gct
clean clean-plots: clean-plots-wl-gct
clean-plots-wl-gct:
	rm -rf $(WL_GCT_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wl-gct
clean clean-tikz: clean-tikz-wl-gct
clean-tikz-wl-gct:
	rm -rf $(WL_GCT_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
