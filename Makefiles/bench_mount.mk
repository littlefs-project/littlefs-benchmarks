ifndef BENCH_MOUNT_MK
BENCH_MOUNT_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
MOUNT_RESULTSDIR ?= $(RESULTSDIR)/mount
# overrideable plots dir
MOUNT_PLOTSDIR ?= $(PLOTSDIR)/mount
# overrideable tikz dir
MOUNT_TIKZDIR ?= $(TIKZDIR)/mount


# range of percentiles to measure
MOUNT_P ?= avg,p50,p90,p99,p99.9,p99.99,p99.999,max

# run with powerloss
MOUNT_POWERLOSS ?= 0,1


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(MOUNT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(MOUNT_RESULTSDIR) \
		$(MOUNT_PLOTSDIR) \
		$(MOUNT_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-mount
all bench: bench-mount
bench-mount: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(MOUNT_RESULTSDIR)/bench_mount.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - powerloss
#
define BENCH_MOUNT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_mount_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_COUNT),-DSIM_COUNT=$(SIM_COUNT)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-Sgrms \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_P))),$\
			-Smount=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_P))),$\
			-Smkconsistent=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_P))),$\
			-Sopen=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_P))),$\
			-Sclose=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_P))),$\
			-Sunmount=$(p)) \
		-DPOWERLOSS=$(or $6,$(MOUNT_POWERLOSS)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_MOUNT_RULE,$\
				$(MOUNT_RESULTSDIR)/bench_mount.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-mount
all plot: plot-mount
plot-mount: \
		$(MOUNT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(MOUNT_PLOTSDIR)/plot_mount.$(g).svg) \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(foreach p, $(subst $(comma),$(space),$(MOUNT_P)), \
				$(MOUNT_PLOTSDIR)/plot_mount.$(p).$(g).svg))

## Create a quick html page for easy viewing
$(MOUNT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_mount.$(g).svg"></p>" >> $@ $(nl))
	$(foreach g, $(BENCH_GEOMETRIES), \
		$(foreach p, $(subst $(comma),$(space),$(MOUNT_P)), \
			echo -e "<p><img src="plot_mount.$(p).$(g).svg"></p>" >> $@ $(nl)))
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
define PLOT_MOUNT_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-Si='enumerate()' -bcase -bPOWERLOSS -bFS -b$4 \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 $(if, -H350) -H700 \
		--title=$3 \
		-bFS \
		--subplot=" \
				--title='seq' \
				--ylabel='mount latency (no pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=0 -D$4='mount+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				--ylabel='open latency (no pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=0 -D$4='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				--ylabel='mount latency (pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=1 -D$4='mount+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				--ylabel='open latency (pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=1 -D$4='open+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=0 -D$4='mount+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=0 -D$4='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=1 -D$4='mount+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=1 -D$4='open+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=0 -D$4='mount+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=0 -D$4='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=1 -D$4='mount+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=1 -D$4='open+*' \
				-ylatency --yunits=s\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=0 -D$4='mount+*' \
				-ylatency --yunits=s \
			--subplot-below=\" \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=0 -D$4='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=1 -D$4='mount+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=1 -D$4='open+*' \
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
			for i, p in list(enumerate("$5".split(",")))[::$6]: $\
				print("--add-xticklabel=%d=\"%s\"" % (i, p))') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_MOUNT_RULE,$\
		$(MOUNT_PLOTSDIR)/plot_mount.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(MOUNT_RESULTSDIR)/bench_mount.$(c).$(fs).$(g).csv)),$\
		"$(g) - simulated mount time",$\
		probe,$\
		$(MOUNT_P),$\
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
define PLOT_MOUNT_P_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-Si='enumerate()' -bcase -bPOWERLOSS -b$4 -bprobe -Dprobe='*+$$*' \
			-flatency='bench_simtime/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bprobe \
		--subplot=" \
				--title='seq (mount)' \
				--ylabel='latency (no pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=0 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\" \
				-W0.5 \
				--title='seq (open)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=0 -Dprobe='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-W0.5 \
				--ylabel='latency (pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=1 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\\\" \
				-W0.5 \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=1 -Dprobe='open+*' \
				-ylatency --yunits=s\\\"\"" \
		--subplot-right=" \
				--title='random (mount)' \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=0 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\" \
				-W0.5 \
				--title='random (open)' \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=0 -Dprobe='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-W0.5 \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=1 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\\\" \
				-W0.5 \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=1 -Dprobe='open+*' \
				-ylatency --yunits=s\\\"\"" \
		--subplot-right=" \
				--title='logging (mount)' \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=0 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\" \
				-W0.5 \
				--title='logging (open)' \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=0 -Dprobe='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-W0.5 \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=1 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\\\" \
				-W0.5 \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=1 -Dprobe='open+*' \
				-ylatency --yunits=s\\\"\"" \
		--subplot-right=" \
				--title='many (mount)' \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=0 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\" \
				-W0.5 \
				--title='many (open)' \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=0 -Dprobe='open+*' \
				-ylatency --yunits=s\" \
			--subplot-below=\" \
				-W0.5 \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=1 -Dprobe='mount+*' \
				-ylatency --yunits=s \
			--subplot-right=\\\" \
				-W0.5 \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=1 -Dprobe='open+*' \
				-ylatency --yunits=s\\\"\"" \
		-Fo: -C'mount+*=$(C_BLUE)' -C'open+*=$(C_ORANGE)' \
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
	$(eval $(call PLOT_MOUNT_P_RULE,$\
		$(MOUNT_PLOTSDIR)/plot_mount.%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(MOUNT_RESULTSDIR)/bench_mount.$(c).$(fs).$(g).csv)),$\
		"$$* - $(g) - simulated mount time",$\
		FS,$\
		$(BENCH_FILESYSTEMS),$\
		1,$\
		--xlabel="filesystem")))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-mount
save save-results: save-results-mount
save-results-mount:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(MOUNT_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-mount
save save-plots: save-plots-mount
save-plots-mount:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(MOUNT_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-mount
save save-tikz: save-tikz-mount
save-tikz-mount:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(MOUNT_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-mount touch-results-mount
reuse-results touch-results: reuse-results-mount touch-results-mount
reuse-results-mount touch-results-mount:
	find $(MOUNT_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-mount
clean clean-results: clean-results-mount
clean-results-mount:
	rm -rf $(MOUNT_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-mount
clean clean-plots: clean-plots-mount
clean-plots-mount:
	rm -rf $(MOUNT_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-mount
clean clean-tikz: clean-tikz-mount
clean-tikz-mount:
	rm -rf $(MOUNT_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
