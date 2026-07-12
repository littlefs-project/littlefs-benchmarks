ifndef BENCH_WL_LGBT_MK
BENCH_WL_LGBT_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_LGBT_RESULTSDIR ?= $(RESULTSDIR)/wl_lgbt
# overrideable plots dir
WL_LGBT_PLOTSDIR ?= $(PLOTSDIR)/wl_lgbt
# overrideable tikz dir
WL_LGBT_TIKZDIR ?= $(TIKZDIR)/wl_lgbt


# range of percentiles to measure
WL_LGBT_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# default lookahead size, note this ends up *8
WL_LGBT_LOOKAHEAD_SIZE ?= 16

# range of gc_lookgbmap_thresh to test
WL_LGBT_LOOKGBMAP_THRESHES ?= $\
	32768,16384,8192,4096,2048,1024,512,256,$\
	128,127,126,124,120,112,96,64,0

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
ifneq ($(WL_LGBT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WL_LGBT_RESULTSDIR) \
		$(WL_LGBT_PLOTSDIR) \
		$(WL_LGBT_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-lgbt
all bench: bench-wl-lgbt
bench-wl-lgbt: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_LGBT_RESULTSDIR)/bench_wl_lgbt.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - lookahead size
# $7 - lookgbmap threshes
#
define BENCH_WL_LGBT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_LGBT_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_LGBT_P))),$\
			-Sgc=$(p)) \
		-DLOOKAHEAD_SIZE=$(or $6,$(WL_LGBT_LOOKAHEAD_SIZE)) \
		-DGC_LOOKAHEAD_THRESH=$(or $7,$(WL_LGBT_LOOKGBMAP_THRESHES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_LGBT_RULE,$\
				$(WL_LGBT_RESULTSDIR)/bench_wl_lgbt.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-lgbt
all plot: plot-wl-lgbt
plot-wl-lgbt: \
		$(WL_LGBT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_LGBT_P)), \
				$(WL_LGBT_PLOTSDIR)/plot_wl_lgbt.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_LGBT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_LGBT_P)), \
			echo -e "<p><img src="plot_wl_lgbt.$(p).$(g).svg"></p>" >> $@ $(nl)))
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
define PLOT_WL_LGBT_RULE
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
	$(eval $(call PLOT_WL_LGBT_RULE,$\
		$(WL_LGBT_PLOTSDIR)/plot_wl_lgbt.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_LGBT_RESULTSDIR)/bench_wl_lgbt.$(c).$(fs).$(g).csv)),$\
		"lookgbmap threshes - $$* - $(g) - simulated latency",$\
		GC_LOOKAHEAD_THRESH,$\
		$(WL_LGBT_LOOKGBMAP_THRESHES),$\
		2,$\
		--xlabel="lookgbmap thresh")))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wl-lgbt
save save-results: save-results-wl-lgbt
save-results-wl-lgbt:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WL_LGBT_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wl-lgbt
save save-plots: save-plots-wl-lgbt
save-plots-wl-lgbt:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WL_LGBT_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wl-lgbt
save save-tikz: save-tikz-wl-lgbt
save-tikz-wl-lgbt:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WL_LGBT_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wl-lgbt touch-results-wl-lgbt
reuse-results touch-results: reuse-results-wl-lgbt touch-results-wl-lgbt
reuse-results-wl-lgbt touch-results-wl-lgbt:
	find $(WL_LGBT_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wl-lgbt
clean clean-results: clean-results-wl-lgbt
clean-results-wl-lgbt:
	rm -rf $(WL_LGBT_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wl-lgbt
clean clean-plots: clean-plots-wl-lgbt
clean-plots-wl-lgbt:
	rm -rf $(WL_LGBT_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wl-lgbt
clean clean-tikz: clean-tikz-wl-lgbt
clean-tikz-wl-lgbt:
	rm -rf $(WL_LGBT_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
