ifndef BENCH_WL_GCTC_MK
BENCH_WL_GCTC_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_GCTC_RESULTSDIR ?= $(RESULTSDIR)/wl_gctc
# overrideable plots dir
WL_GCTC_PLOTSDIR ?= $(PLOTSDIR)/wl_gctc
# overrideable tikz dir
WL_GCTC_TIKZDIR ?= $(TIKZDIR)/wl_gctc


# range of percentiles to measure
WL_GCTC_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# range of gc times to measure
WL_GCTC_GC_TIMES ?= $\
		1,10,100,$\
		1000,10000,100000,$\
		1000000,10000000,100000000,$\
		1000000000,10000000000,100000000000,$\
		1000000000000,10000000000000

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
ifneq ($(WL_GCTC_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WL_GCTC_RESULTSDIR) \
				$(WL_GCTC_PLOTSDIR) \
				$(WL_GCTC_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-gctc
all bench: bench-wl-gctc
bench-wl-gctc: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_GCTC_RESULTSDIR)/bench_wl_gctc.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - gc times
#
define BENCH_WL_GCTC_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_GCTC_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_GCTC_P))),$\
			-Sgc=$(p)) \
		-DGC_TIME=$(or $6,$(WL_GCTC_GC_TIMES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_GCTC_RULE,$\
				$(WL_GCTC_RESULTSDIR)/bench_wl_gctc.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-gctc
all plot: plot-wl-gctc
plot-wl-gctc: \
		$(WL_GCTC_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_GCTC_P)), \
				$(WL_GCTC_PLOTSDIR)/plot_wl_gctc.$(p).$(g).svg)) \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_GCTC_P)), \
				$(WL_GCTC_PLOTSDIR)/plot_wl_gctc_freq.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_GCTC_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_GCTC_P)), \
			echo -e "<p><img src="plot_wl_gctc.$(p).$(g).svg"></p>" \
				>> $@ $(nl)))
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_GCTC_P)), \
			echo -e "<p><img src="plot_wl_gctc_freq.$(p).$(g).svg"></p>" \
				>> $@ $(nl)))
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
define PLOT_WL_GCTC_RULE
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
	$(eval $(call PLOT_WL_GCTC_RULE,$\
		$(WL_GCTC_PLOTSDIR)/plot_wl_gctc.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_GCTC_RESULTSDIR)/bench_wl_gctc.$(c).$(fs).$(g).csv)),$\
		"gc times - $$* - $(g) - simulated latency",$\
		GC_TIME,$\
		$(WL_GCTC_GC_TIMES),$\
		1,$\
		--xlabel="gc time")))

# per-percentile freq plot rule
#
# $1 - target
# $2 - sources
# $3 - title
# $4 - orig x-axis
# $5 - extra plotmpl.py flags
#
define PLOT_WL_GCTC_FREQ_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py \
			<(./scripts/csv.py \
				<(./scripts/csv.py $$^ \
					-bcase -bFS -b$4 -Dprobe='write+avg' \
					-fwrite_avg=bench_simtime \
					-o-) \
				<(./scripts/csv.py $$^ \
					-bcase -bFS -b$4 -Dprobe='gc+avg' \
					-fgc_avg=bench_simtime \
					-o-) \
				<(./scripts/csv.py $$^ \
					-bcase -bFS -b$4 -Dprobe='write+$$*' \
					-fwrite_p=bench_simtime \
					-o-) \
				-bcase -bFS -b$4 \
				-o-) \
			-bcase -bFS -b$4 \
			-ffreq='1.0e9/max(gc_avg+write_avg, 1.0)' \
			-flatency='write_p/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-xfreq --xunits=Hz --xzoom \
		-ylatency --yunits=s \
		--subplot=" \
				--title='seq' \
				--ylabel='latency' \
				-Dcase=bench_wl_seq" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wl_random" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wl_logging" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wl_many" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		$5 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# per-percentile freq plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WL_GCTC_FREQ_RULE,$\
		$(WL_GCTC_PLOTSDIR)/plot_wl_gctc_freq.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_GCTC_RESULTSDIR)/bench_wl_gctc.$(c).$(fs).$(g).csv)),$\
		"gc freqs - $$* - $(g) - simulated latency",$\
		GC_TIME,$\
		--xlabel="gc time")))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wl-gctc
save save-results: save-results-wl-gctc
save-results-wl-gctc:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WL_GCTC_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wl-gctc
save save-plots: save-plots-wl-gctc
save-plots-wl-gctc:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WL_GCTC_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wl-gctc
save save-tikz: save-tikz-wl-gctc
save-tikz-wl-gctc:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WL_GCTC_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wl-gctc touch-results-wl-gctc
reuse-results touch-results: reuse-results-wl-gctc touch-results-wl-gctc
reuse-results-wl-gctc touch-results-wl-gctc:
	find $(WL_GCTC_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wl-gctc
clean clean-results: clean-results-wl-gctc
clean-results-wl-gctc:
	rm -rf $(WL_GCTC_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wl-gctc
clean clean-plots: clean-plots-wl-gctc
clean-plots-wl-gctc:
	rm -rf $(WL_GCTC_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wl-gctc
clean clean-tikz: clean-tikz-wl-gctc
clean-tikz-wl-gctc:
	rm -rf $(WL_GCTC_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
