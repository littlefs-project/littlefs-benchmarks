ifndef SIZES_MK
SIZES_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable tikz dir
SIZES_TIKZDIR ?= $(TIKZDIR)/sizes

# note SIZE_FILESYSTEMS is already defined in build.mk


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(SIZES_TIKZDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(SIZES_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# size rules                                                           #
#======================================================================#

# these are already defined in build.mk, since they're generally useful,
# just forward to all here

## Find compile-time sizes _before_ link-time gc
# .PHONY: sizes sizes-prelink
all: sizes

## Find compile-time sizes _after_ link-time gc
# .PHONY: sizes-postlink bench-sizes
# all: sizes-postlink


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-sizes
all tikz tikz-sizes: \
		$(SIZES_TIKZDIR)/tikz_sizes.csv \
		$(foreach fs, $(SIZE_FILESYSTEMS), \
			$(SIZES_TIKZDIR)/tikz_sizes.$(fs).csv)

# combined sizes rule
$(SIZES_TIKZDIR)/tikz_sizes.csv: \
		$(foreach fs, $(SIZE_FILESYSTEMS), \
			$($(U_$(fs))_OBJ) \
			$($(U_$(fs))_CI))
	$(strip ./scripts/csv.py \
		$(foreach fs, $(SIZE_FILESYSTEMS), \
			<(./scripts/csv.py \
				<(./scripts/code.py $($(U_$(fs))_OBJ) \
					-bfunction -o-) \
				-bi=$(I_$(fs)) -bfs=$(fs) -bfunction -o-) \
			<(./scripts/csv.py \
				<(./scripts/data.py $($(U_$(fs))_OBJ) \
					-bfunction -o-) \
				-bi=$(I_$(fs)) -bfs=$(fs) -bfunction -o-) \
			<(./scripts/csv.py \
				<(./scripts/stack.py $($(U_$(fs))_CI) \
					-bfunction -o-) \
				-bi=$(I_$(fs)) -bfs=$(fs) -bfunction -o-) \
			<(./scripts/csv.py \
				<(./scripts/ctx.py $($(U_$(fs))_OBJ) \
					-bfunction -o-) \
				-bi=$(I_$(fs)) -bfs=$(fs) -bfunction -o-)) \
		-Si=i -bfs \
		-fcode=code_size \
		-fdata=data_size \
		-fstack='max(stack_limit)' \
		-fctx='max(ctx_size)' \
		-o$@)

# per-fs tikz rule
#
# $1 - target
# $2 - fs type/version
#
define TIKZ_SIZES_RULE
$(info $1 $2)
$1: $($(U_$2)_OBJ) $($(U_$2)_CI)
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py \
			<(./scripts/code.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			-bi=$(I_$2) -bfs=$2 -bfunction -o-) \
		<(./scripts/csv.py \
			<(./scripts/data.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			-bi=$(I_$2) -bfs=$2 -bfunction -o-) \
		<(./scripts/csv.py \
			<(./scripts/stack.py $($(U_$2)_CI) \
				-bfunction -o-) \
			-bi=$(I_$2) -bfs=$2 -bfunction -o-) \
		<(./scripts/csv.py \
			<(./scripts/ctx.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			-bi=$(I_$2) -bfs=$2 -bfunction -o-) \
		-bi=0 \
		-fcode=code_size \
		-fdata=data_size \
		-fstack='max(stack_limit)' \
		-fctx='max(ctx_size)' \
		-o$$@)
endef

# tikz rules
$(foreach fs, $(SIZE_FILESYSTEMS), \
	$(eval $(call TIKZ_SIZES_RULE,$\
		$(SIZES_TIKZDIR)/tikz_sizes.$(fs).csv,$\
		$(fs))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save tikz
.PHONY: save save-tikz save-tikz-wt
save save-tikz: save-tikz-wt
save-tikz-wt:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(SIZES_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wt
clean clean-tikz: clean-tikz-wt
clean-tikz-wt:
	rm -rf $(SIZES_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
