ifndef BENCH_MOUNT_MM_MK
BENCH_MOUNT_MM_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
MOUNT_MM_RESULTSDIR ?= $(RESULTSDIR)/mount_mm
# overrideable plots dir
MOUNT_MM_PLOTSDIR ?= $(PLOTSDIR)/mount_mm
# overrideable tikz dir
MOUNT_MM_TIKZDIR ?= $(TIKZDIR)/mount_mm


# what percentile are we interested in?
MOUNT_MM_P ?= max

# run with powerloss
MOUNT_MM_POWERLOSS ?= 0,1

# number of static files to create
MOUNT_MM_STATIC_COUNTS ?= 0,1,2,4,8,16,32,64,128,256,512,1024,2048,4096

# size of static files
#
# very small, note this does hurt fs that align to pages
MOUNT_MM_STATIC_SIZE ?= 64


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(MOUNT_MM_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(MOUNT_MM_RESULTSDIR) \
				$(MOUNT_MM_PLOTSDIR) \
				$(MOUNT_MM_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-mount-mm
all bench: bench-mount-mm
bench-mount-mm: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(MOUNT_MM_RESULTSDIR)/bench_mount_mm.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - powerloss
# $7 - static counts
# $8 - static size
#
define BENCH_MOUNT_MM_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_mount_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_MOUNTS),-DSIM_MOUNTS=$(SIM_MOUNTS)) \
		$(if $(SIM_ROTATES),-DSIM_ROTATES=$(SIM_ROTATES)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-Srotates \
		-Sgrms \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_MM_P))),$\
			-Smountwrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_MM_P))),$\
			-Scloseunmount=$(p)) \
		-Susage -Smdir -Sbtree -Sdata \
		-DPOWERLOSS=$(or $6,$(MOUNT_MM_POWERLOSS)) \
		-DSTATIC_COUNT=$(or $7,$(MOUNT_MM_STATIC_COUNTS)) \
		-DSTATIC_SIZE=$(or $8,$(MOUNT_MM_STATIC_SIZE)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_MOUNT_MM_RULE,$\
				$(MOUNT_MM_RESULTSDIR)/bench_mount_mm.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-mount-mm
all plot: plot-mount-mm
plot-mount-mm: \
		$(MOUNT_MM_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(MOUNT_MM_PLOTSDIR)/plot_mount_mm.$(g).svg)

## Create a quick html page for easy viewing
$(MOUNT_MM_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_mount_mm.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_MOUNT_MM_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bPOWERLOSS -b$4 -Dprobe=mountwrite+$(MOUNT_MM_P) \
			-flatency='float(bench_simtime)/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-x$4 \
		-ylatency \
		--subplot=" \
				--title='seq' \
				--ylabel='mount latency (no pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				--ylabel='mount latency (yes pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=1\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=1\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=1\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_mount_mmany \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				-Dcase=bench_mount_mmany \
				-DPOWERLOSS=1\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		--xlog --x2 --xunits=B \
		--yunits=s \
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
	$(eval $(call PLOT_MOUNT_MM_RULE,$\
		$(MOUNT_MM_PLOTSDIR)/plot_mount_mm.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(MOUNT_MM_RESULTSDIR)/bench_mount_mm.$(c).$(fs).$(g).csv)),$\
		"metadata - $(g) - simulated mount time",$\
		STATIC_COUNT,$\
		$(MOUNT_MM_STATIC_COUNTS),$\
		2,$\
		--xlabel="static counts")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-mount-mm
all tikz tikz-mount-mm: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(MOUNT_MM_TIKZDIR)/tikz_mount_mm.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - x-axis
#
define TIKZ_MOUNT_MM_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py $$^ \
			-b$3 -DPOWERLOSS=0 -Dprobe=mountwrite+$(MOUNT_MM_P) \
			-fmountwrite_npl_$(subst .,$(nil),$(MOUNT_MM_P))=$\
				'float(bench_simtime)/1.0e9' \
			-o-) \
		<(./scripts/csv.py $$^ \
			-b$3 -DPOWERLOSS=1 -Dprobe=mountwrite+$(MOUNT_MM_P) \
			-fmountwrite_ypl_$(subst .,$(nil),$(MOUNT_MM_P))=$\
				'float(bench_simtime)/1.0e9' \
			-o-) \
		-b$3 -F$3 \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_MOUNT_MM_RULE,$\
				$(MOUNT_MM_TIKZDIR)/tikz_mount_mm.$(c).$(fs).$(g).csv,$\
				$(MOUNT_MM_RESULTSDIR)/bench_mount_mm.$(c).$(fs).$(g).csv,$\
				STATIC_COUNT)))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-mount-mm
save save-results: save-results-mount-mm
save-results-mount-mm:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(MOUNT_MM_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-mount-mm
save save-plots: save-plots-mount-mm
save-plots-mount-mm:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(MOUNT_MM_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-mount-mm
save save-tikz: save-tikz-mount-mm
save-tikz-mount-mm:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(MOUNT_MM_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-mount-mm touch-results-mount-mm
reuse-results touch-results: reuse-results-mount-mm touch-results-mount-mm
reuse-results-mount-mm touch-results-mount-mm:
	find $(MOUNT_MM_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-mount-mm
clean clean-results: clean-results-mount-mm
clean-results-mount-mm:
	rm -rf $(MOUNT_MM_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-mount-mm
clean clean-plots: clean-plots-mount-mm
clean-plots-mount-mm:
	rm -rf $(MOUNT_MM_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-mount-mm
clean clean-tikz: clean-tikz-mount-mm
clean-tikz-mount-mm:
	rm -rf $(MOUNT_MM_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
