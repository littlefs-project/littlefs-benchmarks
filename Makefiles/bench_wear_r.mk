ifndef BENCH_WEAR_R_MK
BENCH_WEAR_R_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WEAR_R_RESULTSDIR ?= $(RESULTSDIR)/wear_r
# overrideable plots dir
WEAR_R_PLOTSDIR ?= $(PLOTSDIR)/wear_r
# overrideable tikz dir
WEAR_R_TIKZDIR ?= $(TIKZDIR)/wear_r


# range of block recycles to bench
# avoid power-of-two? aliasing issues?
#WEAR_R_BLOCK_RECYCLES ?= 0,1,2,4,8,16,32,64,128,256,512,1024
WEAR_R_BLOCK_RECYCLES ?= 0,1,2,5,7,10,25,50,75,100,250,500,750,1000


# we don't need to bench all the filesystems
BENCH_FILESYSTEMS ?= lfs3 # $(DEFAULT_LFS3_FILESYSTEMS)

# and we're interested in some of the more atypical disk geometries
BENCH_GEOMETRIES ?= nor nand emmc # $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WEAR_R_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WEAR_R_RESULTSDIR) \
				$(WEAR_R_PLOTSDIR) \
				$(WEAR_R_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wear-r
all bench: bench-wear-r
bench-wear-r: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WEAR_R_RESULTSDIR)/bench_wear_r.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - block recycles
#
# note emmc + r=0 simply does not work (it _technically_ does! but every
# write results in an mroot extension, which is very bad, very slow, and
# will eventually consume all blocks)
#
define BENCH_WEAR_R_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wear_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-Swear=max -Swear=stddev -Swaf \
		-DBLOCK_RECYCLES=$(if $(filter $4,emmc),$\
			$(subst $(space),$(comma),$\
				$(filter-out 0,$\
					$(subst $(comma),$(space),$\
						$(or $5,$(WEAR_R_BLOCK_RECYCLES))))),$\
			$(or $5,$(WEAR_R_BLOCK_RECYCLES))) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WEAR_R_RULE,$\
				$(WEAR_R_RESULTSDIR)/bench_wear_r.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wear-r
all plot: plot-wear-r
plot-wear-r: \
		$(WEAR_R_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WEAR_R_PLOTSDIR)/plot_wear_r.$(g).svg)

## Create a quick html page for easy viewing
$(WEAR_R_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wear_r.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WEAR_R_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 \
			-Dprobe=wear+max -fwmax=bench_t \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 \
			-Dprobe=wear+stddev -fwstddev=bench_t \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 \
			-Dprobe=waf -fwaf=bench_t \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-x$4 \
		--subplot=" \
				--title='seq' \
				--ylabel='max' \
				-Dcase=bench_wear_seq \
				-ywmax \
			--subplot-below=\" \
				--ylabel='stddev' \
				-Dcase=bench_wear_seq \
				-ywstddev\" \
			--subplot-below=\" \
				--ylabel='waf' \
				-Dcase=bench_wear_seq \
				-ywaf\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wear_random \
				-ywmax \
			--subplot-below=\" \
				-Dcase=bench_wear_random \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_random \
				-ywaf\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wear_logging \
				-ywmax \
			--subplot-below=\" \
				-Dcase=bench_wear_logging \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_logging \
				-ywaf\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wear_many \
				-ywmax \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywaf\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs),%(BLOCK_RECYCLES)s') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		--xlog --x2 --xunits=B \
		-X"$$(shell python -c 'a=min([$5]); print(a-a/4)'),$\
			$$(shell python -c 'b=max([$5]); print(b+b/4)')" \
		$$(shell python -c '$\
			for n in [$5][::$6]: $\
				print("--add-xticklabel=%d=\"%%(x)IB\"" % n)') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WEAR_R_RULE,$\
		$(WEAR_R_PLOTSDIR)/plot_wear_r.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WEAR_R_RESULTSDIR)/bench_wear_r.$(c).$(fs).$(g).csv)),$\
		"chunk sizes - $(g) - simulated wear",$\
		BLOCK_RECYCLES,$\
		$(WEAR_R_BLOCK_RECYCLES),$\
		2,$\
		--xlabel="block recycles")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wear-r
all tikz tikz-wear-r: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WEAR_R_TIKZDIR)/tikz_wear_r.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - x-axis
#
define TIKZ_WEAR_R_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py $$^ \
			-b$3 \
			-Dprobe=wear+max -fwmax=bench_t \
			-o-) \
		<(./scripts/csv.py $$^ \
			-b$3 \
			-Dprobe=wear+stddev -fwstddev=bench_t \
			-o-) \
		<(./scripts/csv.py $$^ \
			-b$3 \
			-Dprobe=waf -fwaf=bench_t \
			-o-) \
		-b$3 -F$3 \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WEAR_R_RULE,$\
				$(WEAR_R_TIKZDIR)/tikz_wear_r.$(c).$(fs).$(g).csv,$\
				$(WEAR_R_RESULTSDIR)/bench_wear_r.$(c).$(fs).$(g).csv,$\
				BLOCK_RECYCLES)))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wear-r
save save-results: save-results-wear-r
save-results-wear-r:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WEAR_R_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wear-r
save save-plots: save-plots-wear-r
save-plots-wear-r:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WEAR_R_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wear-r
save save-tikz: save-tikz-wear-r
save-tikz-wear-r:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WEAR_R_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wear-r touch-results-wear-r
reuse-results touch-results: reuse-results-wear-r touch-results-wear-r
reuse-results-wear-r touch-results-wear-r:
	find $(WEAR_R_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wear-r
clean clean-results: clean-results-wear-r
clean-results-wear-r:
	rm -rf $(WEAR_R_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wear-r
clean clean-plots: clean-plots-wear-r
clean-plots-wear-r:
	rm -rf $(WEAR_R_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wear-r
clean clean-tikz: clean-tikz-wear-r
clean-tikz-wear-r:
	rm -rf $(WEAR_R_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
