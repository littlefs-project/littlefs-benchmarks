ifndef BENCH_WEAR_MK
BENCH_WEAR_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WEAR_RESULTSDIR ?= $(RESULTSDIR)/wear
# overrideable plots dir
WEAR_PLOTSDIR ?= $(PLOTSDIR)/wear
# overrideable tikz dir
WEAR_TIKZDIR ?= $(TIKZDIR)/wear


# block recycles to bench? these only make sense for littlefs
WEAR_BLOCK_RECYCLES ?= 0,1,10,100,1000


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WEAR_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WEAR_RESULTSDIR) \
				$(WEAR_PLOTSDIR) \
				$(WEAR_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wear
all bench: bench-wear
bench-wear: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - block recycles
#
define BENCH_WEAR_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wear_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-Swear=1 \
		-Swear=max -Swear=stddev -Swaf \
		$(if $(filter $3,$\
				$(DEFAULT_LFS3_FILESYSTEMS) $\
				$(DEFAULT_LFS2_FILESYSTEMS)),$\
			-DBLOCK_RECYCLES=$(or $5,$(WEAR_BLOCK_RECYCLES))) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WEAR_RULE,$\
				$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wear
all plot: plot-wear
plot-wear: \
		$(WEAR_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WEAR_PLOTSDIR)/plot_wear.$(g).svg) \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WEAR_PLOTSDIR)/plot_wear_wa.$(g).svg)

## Create a quick html page for easy viewing
$(WEAR_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wear.$(g).svg"></p>" >> $@ $(nl))
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wear_wa.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WEAR_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py \
			<(./scripts/csv.py $$^ \
				-bcase -bFS -bBLOCK_RECYCLES -Dprobe=wear \
				-bblock -fblock=n \
				-fwear=bench_simtime \
				-Swear \
				-o-) \
			-fi='enumerate(case,FS,BLOCK_RECYCLES;)' -Si \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-bBLOCK_RECYCLES \
		--subplot=" \
				--title='seq' \
				--ylabel='disk wear' \
				-Dcase=bench_wear_seq \
				-xblock \
				-ywear \
			--subplot-below=\" \
				--ylabel='distribution' \
				-Dcase=bench_wear_seq \
				-xi \
				-ywear\"" \
		--subplot-right=" \
				--title='random' \
				--ylabel='disk wear' \
				-Dcase=bench_wear_random \
				-xblock \
				-ywear \
			--subplot-below=\" \
				--ylabel='distribution' \
				-Dcase=bench_wear_random \
				-xi \
				-ywear\"" \
		--subplot-right=" \
				--title='logging' \
				--ylabel='disk wear' \
				-Dcase=bench_wear_logging \
				-xblock \
				-ywear \
			--subplot-below=\" \
				--ylabel='distribution' \
				-Dcase=bench_wear_logging \
				-xi \
				-ywear\"" \
		--subplot-right=" \
				--title='many' \
				--ylabel='disk wear' \
				-Dcase=bench_wear_many \
				-xblock \
				-ywear \
			--subplot-below=\" \
				--ylabel='distribution' \
				-Dcase=bench_wear_many \
				-xi \
				-ywear\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs),%(BLOCK_RECYCLES)s') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WEAR_RULE,$\
		$(WEAR_PLOTSDIR)/plot_wear.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv)),$\
		"$(g) - simulated wear",$\
		,$\
		,$\
		1,$\
		--xlabel="percentile")))

# max wear and wear-amplification plot rule
#
# $1 - target
# $2 - sources
# $3 - title
# $4 - x-axis
# $5 - x-ticks
# $6 - x-skip
# $7 - extra plotmpl.py flags
# $8 - disk geometry
#
define PLOT_WEAR_WA_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py \
			<(./scripts/csv.py $$^ \
				-bcase -bFS -bBLOCK_RECYCLES -FBLOCK_RECYCLES \
				-Dprobe=wear+max -fwmax=bench_simtime \
				-o-) \
			<(./scripts/csv.py $$^ \
				-bcase -bFS -bBLOCK_RECYCLES -FBLOCK_RECYCLES \
				-Dprobe=wear+stddev -fwstddev=bench_simtime \
				-o-) \
			<(./scripts/csv.py $$^ \
				-bcase -bFS -bBLOCK_RECYCLES -FBLOCK_RECYCLES \
				-Dprobe=waf -fwaf=bench_simtime \
				-o-) \
			-bcase -bFS -bBLOCK_RECYCLES -FBLOCK_RECYCLES \
			-o-) \
		-W1500 $(if,-H350) -H525 \
		--title=$3 \
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
				-ywmax\
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywaf\"" \
		-Fo: \
		$(if, -X"-0.25,$\
			$$(shell python -c 'b=len("$5".split())-1; print(b+1/4)')") \
		$(if, $$(shell python -c '$\
			for i, fs in list(enumerate("$5".split()))[::$6]: $\
				print("--add-xticklabel=%d=\"%s\"" % (i, fs))')) \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WEAR_WA_RULE,$\
		$(WEAR_PLOTSDIR)/plot_wear_wa.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv)),$\
		"$(g) - simulated wear",$\
		FS,$\
		$(BENCH_FILESYSTEMS),$\
		1,$\
		--xlabel="filesystem",$\
		$(g))))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wear
all tikz tikz-wear: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WEAR_TIKZDIR)/tikz_wear.$(c).$(fs).$(g).csv))) \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WEAR_TIKZDIR)/tikz_wear_sorted.$(c).$(fs).$(g).csv))) \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WEAR_TIKZDIR)/tikz_wear_wa.$(c).$(fs).$(g).csv)))

# wear tikz rule
#
# $1 - target
# $2 - source
# $3 - block recycles
# $4 - sort by wear
#
define TIKZ_WEAR_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach r, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py \
				<(./scripts/csv.py $$^ \
					-bblock -Fblock=n -DBLOCK_RECYCLES='$(r),' \
					-Dprobe=wear -fwear_r$(r)=bench_simtime \
					$(if $4,-Swear_r$(r)) \
					-o-) \
				-i -Dblock='*' \
				-o-)) \
		-bi -Fi \
		-o$$@)
endef

# wear tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WEAR_RULE,$\
				$(WEAR_TIKZDIR)/tikz_wear.$(c).$(fs).$(g).csv,$\
				$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv,$\
				$(WEAR_BLOCK_RECYCLES))))))

# sorted wear tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WEAR_RULE,$\
				$(WEAR_TIKZDIR)/tikz_wear_sorted.$(c).$(fs).$(g).csv,$\
				$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv,$\
				$(WEAR_BLOCK_RECYCLES),$\
				1)))))

# extra wear stats tikz rule
#
# $1 - target
# $2 - source
# $3 - block recycles
#
define TIKZ_WEAR_WA_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach r, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-bi=0 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=wear+max -fwmax_r$(r)='max(bench_simtime)' \
				-o-)) \
		$(foreach r, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-bi=0 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=wear+stddev -fwstddev_r$(r)='max(bench_simtime)' \
				-o-)) \
		$(foreach r, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-bi=0 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=waf -fwaf_r$(r)='max(bench_simtime)' \
				-o-)) \
		-bi -Fi \
		-o$$@)
endef

# extra wear stats tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WEAR_WA_RULE,$\
				$(WEAR_TIKZDIR)/tikz_wear_wa.$(c).$(fs).$(g).csv,$\
				$(WEAR_RESULTSDIR)/bench_wear.$(c).$(fs).$(g).csv,$\
				$(WEAR_BLOCK_RECYCLES))))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wear
save save-results: save-results-wear
save-results-wear:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WEAR_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wear
save save-plots: save-plots-wear
save-plots-wear:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WEAR_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wear
save save-tikz: save-tikz-wear
save-tikz-wear:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WEAR_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wear touch-results-wear
reuse-results touch-results: reuse-results-wear touch-results-wear
reuse-results-wear touch-results-wear:
	find $(WEAR_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wear
clean clean-results: clean-results-wear
clean-results-wear:
	rm -rf $(WEAR_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wear
clean clean-plots: clean-plots-wear
clean-plots-wear:
	rm -rf $(WEAR_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wear
clean clean-tikz: clean-tikz-wear
clean-tikz-wear:
	rm -rf $(WEAR_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
