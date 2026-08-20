ifndef CODEMAPS_MK
CODEMAPS_MK := 1

# this extends the build makefile
include Makefiles/build.mk

# overrideable codemaps dir
CODEMAPS_PLOTSDIR ?= $(PLOTSDIR)/codemaps

# default codemaps filesystems to size filesystems
CODEMAP_FILESYSTEMS ?= $(DEFAULT_SIZE_FILESYSTEMS)


# give some of the bigger subsystems explicit colors, to help with
# comparisons and to avoid similarly colored neighbors
CODEMAP_COLORS += -C'file=$(C_GREEN)'
CODEMAP_COLORS += -C'lfs*_file=$(C_GREEN)'
CODEMAP_COLORS += -C'lfs*_data=$(C_GREEN)'
CODEMAP_COLORS += -C'lfs*_mdir=$(C_YELLOW)'
CODEMAP_COLORS += -C'lfs*_dir=$(C_YELLOW)'
CODEMAP_COLORS += -C'lfs*_mtree=$(C_PURPLE)'
CODEMAP_COLORS += -C'lfs*_btree=$(C_BLUE)'
CODEMAP_COLORS += -C'lfs*_ctz=$(C_BLUE)'
CODEMAP_COLORS += -C'lfs*_bshrub=$(C_CYAN)'
CODEMAP_COLORS += -C'lfs*_rbyd=$(C_RED)'
CODEMAP_COLORS += -C'lfs=$(C_BROWN)'
CODEMAP_COLORS += -C'lfs1=$(C_BROWN)'
CODEMAP_COLORS += -C'lfs2=$(C_BROWN)'
CODEMAP_COLORS += -C'lfs3=$(C_BROWN)'
CODEMAP_COLORS += -C'lfs*_fs=$(C_BROWN)'
CODEMAP_COLORS += -C'lfs*_bd=$(C_GRAY)'


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(CODEMAPS_PLOTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(CODEMAPS_PLOTSDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# codemap rules                                                        #
#======================================================================#

## Generate codemaps
.PHONY: all codemap codemaps
all: codemap codemaps
codemap codemaps: \
		$(CODEMAPS_PLOTSDIR)/codemaps.html \
		$(CODEMAPS_PLOTSDIR)/codemaps_tiny.html \
		$(foreach fs, $(CODEMAP_FILESYSTEMS), \
			$(CODEMAPS_PLOTSDIR)/codemap_$(fs).svg \
			$(CODEMAPS_PLOTSDIR)/codemap_$(fs)_tiny.svg)

## Create a quick html page for easy viewing
$(CODEMAPS_PLOTSDIR)/codemaps.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach fs, $(CODEMAP_FILESYSTEMS), \
		echo -e "<p><img src="codemap_$(fs).svg"></p>" >> $@ $(nl))
	echo -e "$(subst $(nl),\n,$(HTML_FOOTER))" >> $@

$(CODEMAPS_PLOTSDIR)/codemaps_tiny.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach fs, $(CODEMAP_FILESYSTEMS), \
		echo -e "<p><img src="codemap_$(fs)_tiny.svg"></p>" >> $@ $(nl))
	echo -e "$(subst $(nl),\n,$(HTML_FOOTER))" >> $@


# codemap rules!

# normal codemap rule
#
# $1 - target
# $2 - obj/callgraph files
# $3 - fs type/version
#
define CODEMAP_RULE
$1: $2
	$$(strip ./scripts/codemapsvg.py $$^ \
		--title="$3 code %(code)s stack %(stack)s ctx %(ctx)s" \
		-W1125 -H525 \
		$$(CODEMAP_COLORS) \
		$$(CODEMAPFLAGS) \
		-o$$@ \
		&& ./scripts/codemap.py $$^ --no-header)
endef

# tiny codemap rule
#
# $1 - target
# $2 - obj/callgraph files
# $3 - fs type/version
#
define CODEMAP_TINY_RULE
$1: $2
	$$(strip ./scripts/codemapsvg.py $$^ \
		--tiny --background=\#00000000 \
		$$(CODEMAP_COLORS) \
		$$(CODEMAPFLAGS) \
		-o$$@ \
		&& ./scripts/codemap.py $$^ --no-header)
endef

# codemap rules
$(foreach fs, $(CODEMAP_FILESYSTEMS),$\
	$(eval $(call CODEMAP_RULE,$\
			$(CODEMAPS_PLOTSDIR)/codemap_$(fs).svg,$\
			$($(U_$(fs))_OBJ) $($(U_$(fs))_CI),$\
			$(fs))))

# tiny codemap rules
$(foreach fs, $(CODEMAP_FILESYSTEMS),$\
	$(eval $(call CODEMAP_TINY_RULE,$\
			$(CODEMAPS_PLOTSDIR)/codemap_$(fs)_tiny.svg,$\
			$($(U_$(fs))_OBJ) $($(U_$(fs))_CI),$\
			$(fs))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save codemaps
.PHONY: save save-codemaps
save: save-codemaps
save-codemaps:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(CODEMAPS_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean codemaps
.PHONY: clean clean-codemaps
clean: clean-codemaps
clean-codemaps:
	rm -rf $(CODEMAPS_PLOTSDIR)
	@echo "# note: Not cleaning saved output"


endif
