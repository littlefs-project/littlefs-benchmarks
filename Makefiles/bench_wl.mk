ifndef BENCH_WL_MK
BENCH_WL_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_RESULTSDIR ?= $(RESULTSDIR)/wl
# overrideable plots dir
WL_PLOTSDIR ?= $(PLOTSDIR)/wl
# overrideable tikz dir
WL_TIKZDIR ?= $(TIKZDIR)/wl


# range of percentiles to measure
WL_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WL_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WL_RESULTSDIR) \
				$(WL_PLOTSDIR) \
				$(WL_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl
all bench: bench-wl
bench-wl: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_RESULTSDIR)/bench_wl.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
#
define BENCH_WL_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_P))),$\
			-Swrite=$(p)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_RULE,$\
				$(WL_RESULTSDIR)/bench_wl.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl
all plot: plot-wl
plot-wl: \
		$(WL_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WL_PLOTSDIR)/plot_wl.$(g).svg) \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_P)), \
				$(WL_PLOTSDIR)/plot_wl.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wl.$(g).svg"></p>" >> $@ $(nl))
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_P)), \
			echo -e "<p><img src="plot_wl.$(p).$(g).svg"></p>" >> $@ $(nl)))
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
define PLOT_WL_RULE
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
	$(eval $(call PLOT_WL_RULE,$\
		$(WL_PLOTSDIR)/plot_wl.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_RESULTSDIR)/bench_wl.$(c).$(fs).$(g).csv)),$\
		"$(g) - simulated latency",$\
		probe,$\
		$(WL_P),$\
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
define PLOT_WL_P_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-Si='enumerate()' -bcase -b$4 -Dprobe='write+$$*' \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 -H175 \
		--title=$3 \
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
		-Fo: \
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
	$(eval $(call PLOT_WL_P_RULE,$\
		$(WL_PLOTSDIR)/plot_wl.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_RESULTSDIR)/bench_wl.$(c).$(fs).$(g).csv)),$\
		"$$* - $(g) - simulated latency",$\
		FS,$\
		$(BENCH_FILESYSTEMS),$\
		1,$\
		--xlabel="filesystem")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wl
all tikz tikz-wl: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WL_TIKZDIR)/tikz_wl.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - percentiles
#
define TIKZ_WL_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach p, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-bi=0 -Dprobe='write+$(p)' \
				-flatency_$(subst .,$(nil),$(p))='bench_simtime/1.0e9' \
				-o-)) \
		-bi \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WL_RULE,$\
				$(WL_TIKZDIR)/tikz_wl.$(c).$(fs).$(g).csv,$\
				$(WL_RESULTSDIR)/bench_wl.$(c).$(fs).$(g).csv,$\
				$(WL_P))))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wl
save save-results: save-results-wl
save-results-wl:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WL_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wl
save save-plots: save-plots-wl
save-plots-wl:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WL_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wl
save save-tikz: save-tikz-wl
save-tikz-wl:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WL_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wl touch-results-wl
reuse-results touch-results: reuse-results-wl touch-results-wl
reuse-results-wl touch-results-wl:
	find $(WL_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wl
clean clean-results: clean-results-wl
clean-results-wl:
	rm -rf $(WL_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wl
clean clean-plots: clean-plots-wl
clean-plots-wl:
	rm -rf $(WL_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wl
clean clean-tikz: clean-tikz-wl
clean-tikz-wl:
	rm -rf $(WL_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
