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



# some scripts to organize by module
#
# passes unknown functions as their own module as we want to explicitly
# sort everything
#
LFS3_MOD_FILTER_RULES += 'lfs3_rbyd_.*=rbyd'
LFS3_MOD_FILTER_RULES += 'lfs3_rattr_.*=rbyd'
LFS3_MOD_FILTER_RULES += 'lfs3_tag_.*=rbyd'
LFS3_MOD_FILTER_RULES += 'lfs3_btree_.*=btree'
LFS3_MOD_FILTER_RULES += 'lfs3_bshrub_.*=btree'
LFS3_MOD_FILTER_RULES += 'lfs3_shrub_.*=btree'
LFS3_MOD_FILTER_RULES += 'lfs3_file_.*=file'
LFS3_MOD_FILTER_RULES += 'lfs3_bptr_.*=file'
LFS3_MOD_FILTER_RULES += 'lfs3_dir_.*=dir'
LFS3_MOD_FILTER_RULES += 'lfs3_mkdir=dir'
LFS3_MOD_FILTER_RULES += 'lfs3_rmbookmark=dir'
LFS3_MOD_FILTER_RULES += 'lfs3_mdir_.*=mdir'
LFS3_MOD_FILTER_RULES += 'lfs3_mptr_.*=mdir'
LFS3_MOD_FILTER_RULES += 'lfs3_mid_.*=mdir'
LFS3_MOD_FILTER_RULES += 'lfs3_m[rb]?id=mdir'
LFS3_MOD_FILTER_RULES += 'lfs3_mtree_lookup=mdir'
LFS3_MOD_FILTER_RULES += 'lfs3_fs_consumegdelta=mdir'
LFS3_MOD_FILTER_RULES += 'lfs3_path_.*=path'
LFS3_MOD_FILTER_RULES += 'lfs3_mtree_namelookup=path'
LFS3_MOD_FILTER_RULES += 'lfs3_mtree_pathlookup=path'
LFS3_MOD_FILTER_RULES += 'lfs3_mtree_traverse=trv'
LFS3_MOD_FILTER_RULES += 'lfs3_m?trv_.*=trv'
LFS3_MOD_FILTER_RULES += 'lfs3_m?gc_.*=gc'
LFS3_MOD_FILTER_RULES += 'lfs3_mtree_mknogrm=gc'
LFS3_MOD_FILTER_RULES += 'lfs3_fs_(?:mkconsistent|requestck|clearck|ck)=gc'
LFS3_MOD_FILTER_RULES += 'lfs3_fs_gc_=gc'
LFS3_MOD_FILTER_RULES += 'lfs3_alloc_.*=alloc'
LFS3_MOD_FILTER_RULES += 'lfs3_gbmap_.*=gbmap'
LFS3_MOD_FILTER_RULES += 'lfs3_format=format'
LFS3_MOD_FILTER_RULES += 'lfs3_fs_grow=grow'
LFS3_MOD_FILTER_RULES += 'lfs3_(?:mount|mountinited|unmount)=mount'
LFS3_MOD_FILTER_RULES += 'lfs3_(?:init|deinit)=mount'
LFS3_MOD_FILTER_RULES += 'lfs3_fs_(?:cksum|stat|size|statblock)=fs'
LFS3_MOD_FILTER_RULES += 'lfs3_handle_.*=fs'
LFS3_MOD_FILTER_RULES += 'lfs3_(?:get|set|remove|stat|stat_|size|rename)=fs'
LFS3_MOD_FILTER_RULES += 'lfs3_attr_.*=attr'
LFS3_MOD_FILTER_RULES += 'lfs3_(?:lookup|size|get|set|remove)attr=attr'
LFS3_MOD_FILTER_RULES += 'lfs3_bd_.*=data'
LFS3_MOD_FILTER_RULES += 'lfs3_data_.*=data'
LFS3_MOD_FILTER_RULES += 'lfs3_(?:from|to)leb128=data'
LFS3_MOD_FILTER_RULES += 'lfs3_(?:from|to)le32=data'
LFS3_MOD_FILTER_RULES += 'lfs3_mem(?:xor|len)=data'
LFS3_MOD_FILTER_RULES += 'lfs3_crc32c(?:|_.*)=crc32c'

define LFS3_MOD_FILTER_SCRIPT
import csv, re, sys
rules = [(lambda p,m: (re.compile(p), m))(*rule.rsplit("=",1))
		for rule in sys.argv[1:]]
r = csv.DictReader(sys.stdin)
w = csv.DictWriter(sys.stdout, r.fieldnames + ["module"])
w.writeheader()
for f in r:
	for p, m in rules:
		if p.fullmatch(f["function"]):
			break
	else:
		m = f["function"]
	w.writerow(f | {"module":m})
endef

LFS3_MOD_FILTER ?= $(strip python \
	-c 'exec('"'"'$\
		$(subst $(nl),\n,$\
			$(subst $(tab),\t,$\
				$(LFS3_MOD_FILTER_SCRIPT)))'"'"')' \
	$(LFS3_MOD_FILTER_RULES))
LFS3GB_MOD_FILTER ?= $(LFS3_MOD_FILTER)
LFS3GBP_MOD_FILTER ?= $(LFS3GB_MOD_FILTER)



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
			$(SIZES_TIKZDIR)/tikz_sizes.$(fs).csv) \
		$(foreach fs, $(SIZE_FILESYSTEMS), \
			$(SIZES_TIKZDIR)/tikz_sizes_fn.$(fs).csv) \
		$(foreach fs, $(SIZE_FILESYSTEMS), \
			$(SIZES_TIKZDIR)/tikz_sizes_mod.$(fs).csv)

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
				<(./scripts/data.py $($(U_$(fs))_OBJ) \
					-bfunction -o-) \
				<(./scripts/stack.py $($(U_$(fs))_CI) \
					-bfunction -o-) \
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
$1: $($(U_$2)_OBJ) $($(U_$2)_CI)
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py \
			<(./scripts/code.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			<(./scripts/data.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			<(./scripts/stack.py $($(U_$2)_CI) \
				-bfunction -o-) \
			<(./scripts/ctx.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			-bi=$(I_$2) -bfs=$2 -bfunction -o-) \
		-Si=i -bfs \
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

# per-fs per-function tikz rule
#
# $1 - target
# $2 - fs type/version
#
define TIKZ_SIZES_FN_RULE
$1: $($(U_$2)_OBJ) $($(U_$2)_CI)
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py \
			<(./scripts/code.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			<(./scripts/data.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			<(./scripts/stack.py $($(U_$2)_CI) \
				-bfunction -o-) \
			<(./scripts/ctx.py $($(U_$2)_OBJ) \
				-bfunction -o-) \
			-bi=$(I_$2) -bfs=$2 -bfunction -o-) \
		-scode -Si=i -bfs -bfunction \
		-fcode=code_size \
		-fdata=data_size \
		-fstack='max(stack_limit)' \
		-fframe='stack_frame' \
		-fctx='max(ctx_size)' \
		-o$$@)
endef

# tikz rules
$(foreach fs, $(SIZE_FILESYSTEMS), \
	$(eval $(call TIKZ_SIZES_FN_RULE,$\
		$(SIZES_TIKZDIR)/tikz_sizes_fn.$(fs).csv,$\
		$(fs))))

# per-fs per-module tikz rule
#
# $1 - target
# $2 - fs type/version
#
define TIKZ_SIZES_MOD_RULE
$1: $($(U_$2)_OBJ) $($(U_$2)_CI)
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py \
				<(./scripts/code.py $($(U_$2)_OBJ) \
					-bfunction -o-) \
				<(./scripts/data.py $($(U_$2)_OBJ) \
					-bfunction -o-) \
				<(./scripts/stack.py $($(U_$2)_CI) \
					-bfunction -o-) \
				<(./scripts/ctx.py $($(U_$2)_OBJ) \
					-bfunction -o-) \
				-bi=$(I_$2) -bfs=$2 -bfunction -o- \
			| $(if $($(U_$2)_MOD_FILTER), \
				$($(U_$2)_MOD_FILTER), \
				./scripts/csv.py - -Bmodule=misc -feh=0 -o-)) \
		-scode -Si=i -bfs -bmodule \
		-fcode=code_size \
		-fdata=data_size \
		-fstack='max(stack_limit)' \
		-fframe='stack_frame' \
		-fctx='max(ctx_size)' \
		-o$$@)
endef

# tikz rules
$(foreach fs, $(SIZE_FILESYSTEMS), \
	$(eval $(call TIKZ_SIZES_MOD_RULE,$\
		$(SIZES_TIKZDIR)/tikz_sizes_mod.$(fs).csv,$\
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
