ifndef BENCH_WEAR_S_MK
BENCH_WEAR_S_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WEAR_S_RESULTSDIR ?= $(RESULTSDIR)/wear_s
# overrideable plots dir
WEAR_S_PLOTSDIR ?= $(PLOTSDIR)/wear_s
# overrideable tikz dir
WEAR_S_TIKZDIR ?= $(TIKZDIR)/wear_s


# block recycles to bench? these only make sense for littlefs
WEAR_S_BLOCK_RECYCLES ?= 0,1,10,100,1000

# number of static files to create
WEAR_S_STATIC_COUNTS ?= 0,1,2,4,8,16 #,32 #,64,128


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WEAR_S_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WEAR_S_RESULTSDIR) \
		$(WEAR_S_PLOTSDIR) \
		$(WEAR_S_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wear-s
all bench: bench-wear-s
bench-wear-s: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WEAR_S_RESULTSDIR)/bench_wear_s.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - block recycles
# $6 - static counts
#
define BENCH_WEAR_S_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wear_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-Swaf -Scwaf -Swcv \
		-Susage -Smdir -Sbtree -Sdata \
		$(if $(filter $3,$\
				$(DEFAULT_LFS3_FILESYSTEMS) $\
				$(DEFAULT_LFS2_FILESYSTEMS)),$\
			-DBLOCK_RECYCLES=$(or $5,$(WEAR_S_BLOCK_RECYCLES))) \
		-DSTATIC_COUNT=$(or $6,$(WEAR_S_STATIC_COUNTS)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WEAR_S_RULE,$\
				$(WEAR_S_RESULTSDIR)/bench_wear_s.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wear-s
all plot: plot-wear-s
plot-wear-s: \
		$(WEAR_S_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WEAR_S_PLOTSDIR)/plot_wear_s.$(g).svg)

## Create a quick html page for easy viewing
$(WEAR_S_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wear_s.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WEAR_S_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bBLOCK_RECYCLES -b$4 \
			-Dprobe=waf -fwaf=bench_simtime \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bBLOCK_RECYCLES -b$4 \
			-Dprobe=cwaf -fcwaf=bench_simtime \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bBLOCK_RECYCLES -b$4 \
			-Dprobe=wcv -fwcv=bench_simtime \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-bBLOCK_RECYCLES \
		-x$4 \
		--subplot=" \
				--title='seq' \
				--ylabel='waf' \
				-Dcase=bench_wear_seq \
				-ywaf \
			--subplot-below=\" \
				--ylabel='cwaf' \
				-Dcase=bench_wear_seq \
				-ycwaf\" \
			--subplot-below=\" \
				--ylabel='wcv' \
				-Dcase=bench_wear_seq \
				-ywcv\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wear_random \
				-ywaf \
			--subplot-below=\" \
				-Dcase=bench_wear_random \
				-ycwaf\" \
			--subplot-below=\" \
				-Dcase=bench_wear_random \
				-ywcv\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wear_logging \
				-ywaf \
			--subplot-below=\" \
				-Dcase=bench_wear_logging \
				-ycwaf\" \
			--subplot-below=\" \
				-Dcase=bench_wear_logging \
				-ywcv\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wear_many \
				-ywaf \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ycwaf\" \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywcv\"" \
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
	$(eval $(call PLOT_WEAR_S_RULE,$\
		$(WEAR_S_PLOTSDIR)/plot_wear_s.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WEAR_S_RESULTSDIR)/bench_wear_s.$(c).$(fs).$(g).csv)),$\
		"static counts - $(g) - simulated wear",$\
		STATIC_COUNT,$\
		$(WEAR_S_STATIC_COUNTS),$\
		2,$\
		--xlabel="static count")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wear-s
all tikz tikz-wear-s: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WEAR_S_TIKZDIR)/tikz_wear_s.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - block recycles
# $4 - x-axis
#
define TIKZ_WEAR_S_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach r, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-b$4 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=waf -fwaf_r$(r)=bench_simtime \
				-o-) \
			<(./scripts/csv.py $$^ \
				-b$4 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=cwaf -fcwaf_r$(r)=bench_simtime \
				-o-) \
			<(./scripts/csv.py $$^ \
				-b$4 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=wcv -fwcv_r$(r)=bench_simtime \
				-o-)) \
		-b$4 -F$4 \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WEAR_S_RULE,$\
				$(WEAR_S_TIKZDIR)/tikz_wear_s.$(c).$(fs).$(g).csv,$\
				$(WEAR_S_RESULTSDIR)/bench_wear_s.$(c).$(fs).$(g).csv,$\
				$(WEAR_S_BLOCK_RECYCLES),$\
				STATIC_COUNT)))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wear-s
save save-results: save-results-wear-s
save-results-wear-s:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WEAR_S_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wear-s
save save-plots: save-plots-wear-s
save-plots-wear-s:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WEAR_S_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wear-s
save save-tikz: save-tikz-wear-s
save-tikz-wear-s:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WEAR_S_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wear-s touch-results-wear-s
reuse-results touch-results: reuse-results-wear-s touch-results-wear-s
reuse-results-wear-s touch-results-wear-s:
	find $(WEAR_S_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wear-s
clean clean-results: clean-results-wear-s
clean-results-wear-s:
	rm -rf $(WEAR_S_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wear-s
clean clean-plots: clean-plots-wear-s
clean-plots-wear-s:
	rm -rf $(WEAR_S_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wear-s
clean clean-tikz: clean-tikz-wear-s
clean-tikz-wear-s:
	rm -rf $(WEAR_S_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
