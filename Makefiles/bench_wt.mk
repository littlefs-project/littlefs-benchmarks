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


endif
