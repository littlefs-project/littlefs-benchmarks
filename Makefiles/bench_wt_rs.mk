ifndef BENCH_WT_RS_MK
BENCH_WT_RS_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WT_RS_RESULTSDIR ?= $(RESULTSDIR)/wt_rs
# overrideable plots dir
WT_RS_PLOTSDIR ?= $(PLOTSDIR)/wt_rs
# overrideable tikz dir
WT_RS_TIKZDIR ?= $(TIKZDIR)/wt_rs


# range of read sizes to test
WT_RS_READ_SIZES ?= 1,4,8,16,32,64,128,256,512,1024,2048,4096,8192


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WT_RS_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WT_RS_RESULTSDIR) \
				$(WT_RS_PLOTSDIR) \
				$(WT_RS_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wt-rs
all bench: bench-wt-rs
bench-wt-rs: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WT_RS_RESULTSDIR)/bench_wt_rs.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - read sizes
#
define BENCH_WT_RS_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wt_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-DREAD_SIZE=$$(shell python -c '$\
			print(",".join(str(x) $\
				for x in [$(or $5,$(WT_RS_READ_SIZES))] $\
				if x < $$(shell ./scripts/bench.py -R$$< $\
					-DDISK_GEOMETRY=$(N_$4) $\
					-QERASE_SIZE)))') \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WT_RS_RULE,$\
				$(WT_RS_RESULTSDIR)/bench_wt_rs.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wt-rs
all plot: plot-wt-rs
plot-wt-rs: \
		$(WT_RS_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WT_RS_PLOTSDIR)/plot_wt_rs.$(g).svg)

## Create a quick html page for easy viewing
$(WT_RS_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wt_rs.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WT_RS_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 -Dprobe=write \
			-fthroughput='float(n)/max(float(bench_simtime)/1.0e9,1.0e-9)' \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 -Dprobe=heap,stack \
			-fram=bench_simtime \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-x$4 \
		--subplot=" \
				--title='seq' \
				--ylabel='throughput' \
				-Dcase=bench_wt_seq \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				--ylabel='ram' \
				-Dcase=bench_wt_seq \
				-yram --y2 --yunits=B\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wt_random \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				-Dcase=bench_wt_random \
				-yram --y2 --yunits=B\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wt_logging \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				-Dcase=bench_wt_logging \
				-yram --y2 --yunits=B\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wt_many \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				-Dcase=bench_wt_many \
				-yram --y2 --yunits=B\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		--xlog \
		-X"$$(shell python -c 'a=min([$5]); print(a-a/4)'),$\
			$$(shell python -c 'b=max([$5]); print(b+b/4)')" \
		--x2 --xunits=B \
		$$(shell python -c '$\
			for n in [$5][::$6]: $\
				print("--add-xticklabel=%d=\"%%(x)IB\"" % n)') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WT_RS_RULE,$\
		$(WT_RS_PLOTSDIR)/plot_wt_rs.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WT_RS_RESULTSDIR)/bench_wt_rs.$(c).$(fs).$(g).csv)),$\
		"read sizes - $(g) - simulated throughput",$\
		READ_SIZE,$\
		$(WT_RS_READ_SIZES),$\
		2,$\
		--xlabel="read size")))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wt-rs
save save-results: save-results-wt-rs
save-results-wt-rs:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WT_RS_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wt-rs
save save-plots: save-plots-wt-rs
save-plots-wt-rs:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WT_RS_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wt-rs
save save-tikz: save-tikz-wt-rs
save-tikz-wt-rs:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WT_RS_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wt-rs touch-results-wt-rs
reuse-results touch-results: reuse-results-wt-rs touch-results-wt-rs
reuse-results-wt-rs touch-results-wt-rs:
	find $(WT_RS_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wt-rs
clean clean-results: clean-results-wt-rs
clean-results-wt-rs:
	rm -rf $(WT_RS_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wt-rs
clean clean-plots: clean-plots-wt-rs
clean-plots-wt-rs:
	rm -rf $(WT_RS_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wt-rs
clean clean-tikz: clean-tikz-wt-rs
clean-tikz-wt-rs:
	rm -rf $(WT_RS_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
