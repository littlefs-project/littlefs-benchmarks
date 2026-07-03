ifndef BENCH_WT_MK
BENCH_WT_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WT_RESULTSDIR ?= $(RESULTSDIR)/wt
# overrideable plots dir
WT_PLOTSDIR ?= $(PLOTSDIR)/wt
# overrideable tikz dir
WT_TIKZDIR ?= $(TIKZDIR)/wt


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# list of disk geometries to bench on
BENCH_GEOMETRIES ?= nor nand
U_nor  = NOR
U_nand = NAND
U_emmc = EMMC
U_fram = FRAM
N_nor  = 0
N_nand = 1
N_emmc = 2
N_fram = 3

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, $(shell mkdir -p \
		$(WT_RESULTSDIR) \
		$(WT_PLOTSDIR) \
		$(WT_TIKZDIR)))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wt
all bench bench-wt: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
#
define BENCH_WT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wt_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WT_RULE,$\
				$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# marks rules                                                          #
#======================================================================#

### Render results nicely
.PHONY: all marks marks-wt
all marks marks-wt: $(foreach g, $(BENCH_GEOMETRIES), marks-wt-$(g))

# marks rule
marks-wt-%: \
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).%.csv))
	@$(strip ./scripts/csv.py \
		$(foreach c, $(BENCH_CASES),$\
			<(./scripts/csv.py \
				$(foreach fs, $(BENCH_FILESYSTEMS),$\
					<(./scripts/csv.py \
						$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$*.csv \
						-bj=$(I_$(fs)) -bk=$(N_$(fs)) -bfs=$(fs) \
						-Dprobe=write \
						-fn \
						-ft='float(bench_simtime)/1.0e9' \
						-o-) \
					<(./scripts/csv.py \
						$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$*.csv \
						-bj=$(I_$(fs)) -bk=$(N_$(fs)) -bfs=$(fs) \
						-Dprobe=stack \
						-fstack=bench_simtime \
						-o-) \
					<(./scripts/csv.py \
						$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$*.csv \
						-bj=$(I_$(fs)) -bk=$(N_$(fs)) -bfs=$(fs) \
						-Dprobe=heap \
						-fheap=bench_simtime \
						-o-) \
					<(./scripts/csv.py \
						$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$*.csv \
						-bj=$(I_$(fs)) -bk=$(N_$(fs)) -bfs=$(fs) \
						-Dprobe=usage \
						-fusage=bench_simtime \
						-o-)) \
				-bcase=$(c) -Bj -Bk -bfs \
				-o-)) \
		-Hrun='$(U_$*) throughput' \
		-I -brun='%(case)s,%(fs)s' \
		-fn -ft -fthroughput='float(n) / max(t, 1.0e-9)' \
		-fstack -fheap -fram='stack+heap' \
		-fusage \
		--no-total)
	@echo


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wt
all plot plot-wt: \
		$(WT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WT_PLOTSDIR)/plot_wt.$(g).svg)

## Create a quick html page for easy viewing
$(WT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wt.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WT_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py \
			<(./scripts/csv.py $$^ \
				-Si='enumerate()' -bcase -b$4 -Dprobe=write \
				-fthroughput='float(n)/max(float(bench_simtime)/1.0e9,1.0e-9)' \
				-o-) \
			<(./scripts/csv.py $$^ \
				-Si='enumerate()' -bcase -b$4 -Dprobe=heap,stack \
				-fram=bench_simtime \
				-o-) \
			-Si='enumerate()' -bcase -b$4 \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
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
		-Fo: \
		-X"-0.25,$\
			$$(shell python -c 'b=len("$5".split())-1; print(b+1/4)')" \
		$$(shell python -c '$\
			for i, fs in enumerate("$5".split()[::$6]): $\
				print("--add-xticklabel=%d=\"%s\"" % (i, fs))') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WT_RULE,$\
		$(WT_PLOTSDIR)/plot_wt.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WT_RESULTSDIR)/bench_wt.$(c).$(fs).$(g).csv)),$\
		"$(g) - simulated latency",$\
		FS,$\
		$(BENCH_FILESYSTEMS),$\
		1,$\
		--xlabel="filesystem")))


endif
