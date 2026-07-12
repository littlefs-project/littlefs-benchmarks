ifndef BENCH_WL_PC_MK
BENCH_WL_PC_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WL_PC_RESULTSDIR ?= $(RESULTSDIR)/wl_pc
# overrideable plots dir
WL_PC_PLOTSDIR ?= $(PLOTSDIR)/wl_pc
# overrideable tikz dir
WL_PC_TIKZDIR ?= $(TIKZDIR)/wl_pc


# range of percentiles to measure
WL_PC_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# range of gc_preerase_count to test
WL_PC_PREERASE_COUNTS ?= $\
	0,1,2,4,8,16,32,64,128,$\
	256,512,1024,2048,4096,8192,16384,32768

# run with gc
BENCHFLAGS += -DGC=1 -DGC_FLAGS=0x00040000


# default bench filesystems to default littlefs3 filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_LFS3_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WL_PC_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WL_PC_RESULTSDIR) \
		$(WL_PC_PLOTSDIR) \
		$(WL_PC_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wl-pc
all bench: bench-wl-pc
bench-wl-pc: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WL_PC_RESULTSDIR)/bench_wl_pc.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - preerase count
#
define BENCH_WL_PC_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wl_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_PC_P))),$\
			-Swrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(WL_PC_P))),$\
			-Sgc=$(p)) \
		-DGC_PREERASE_COUNT=$(or $6,$(WL_PC_PREERASE_COUNTS)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WL_PC_RULE,$\
				$(WL_PC_RESULTSDIR)/bench_wl_pc.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wl-pc
all plot: plot-wl-pc
plot-wl-pc: \
		$(WL_PC_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(WL_PC_P)), \
				$(WL_PC_PLOTSDIR)/plot_wl_pc.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(WL_PC_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(WL_PC_P)), \
			echo -e "<p><img src="plot_wl_pc.$(p).$(g).svg"></p>" >> $@ $(nl)))
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
define PLOT_WL_PC_RULE
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
	$(eval $(call PLOT_WL_PC_RULE,$\
		$(WL_PC_PLOTSDIR)/plot_wl_pc.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WL_PC_RESULTSDIR)/bench_wl_pc.$(c).$(fs).$(g).csv)),$\
		"preerase counts - $$* - $(g) - simulated latency",$\
		GC_PREERASE_COUNT,$\
		$(WL_PC_PREERASE_COUNTS),$\
		2,$\
		--xlabel="preerase count")))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wl-pc
save save-results: save-results-wl-pc
save-results-wl-pc:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WL_PC_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wl-pc
save save-plots: save-plots-wl-pc
save-plots-wl-pc:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WL_PC_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wl-pc
save save-tikz: save-tikz-wl-pc
save-tikz-wl-pc:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WL_PC_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wl-pc touch-results-wl-pc
reuse-results touch-results: reuse-results-wl-pc touch-results-wl-pc
reuse-results-wl-pc touch-results-wl-pc:
	find $(WL_PC_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wl-pc
clean clean-results: clean-results-wl-pc
clean-results-wl-pc:
	rm -rf $(WL_PC_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wl-pc
clean clean-plots: clean-plots-wl-pc
clean-plots-wl-pc:
	rm -rf $(WL_PC_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wl-pc
clean clean-tikz: clean-tikz-wl-pc
clean-tikz-wl-pc:
	rm -rf $(WL_PC_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
