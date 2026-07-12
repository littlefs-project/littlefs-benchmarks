ifndef CODEMAPS_MK
CODEMAPS_MK := 1

# this extends the build makefile
include Makefiles/build.mk


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


#======================================================================#
# codemap rules                                                        #
#======================================================================#

## Generate codemaps
.PHONY: all codemap codemaps
all: codemap codemaps
codemap codemaps: \
		$(CODEMAPSDIR)/codemaps.html \
		$(CODEMAPSDIR)/codemaps_tiny.html \
		$(foreach fs, $(SIZE_FILESYSTEMS), \
			$(CODEMAPSDIR)/codemap_$(fs).svg \
			$(CODEMAPSDIR)/codemap_$(fs)_tiny.svg)

## Create a quick html page for easy viewing
$(CODEMAPSDIR)/codemaps.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach fs, $(SIZE_FILESYSTEMS), \
		echo -e "<p><img src="codemap_$(fs).svg"></p>" >> $@ $(nl))
	echo -e "$(subst $(nl),\n,$(HTML_FOOTER))" >> $@

$(CODEMAPSDIR)/codemaps_tiny.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach fs, $(SIZE_FILESYSTEMS), \
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
$(foreach fs, $(SIZE_FILESYSTEMS),$\
	$(eval $(call CODEMAP_RULE,$\
			$(CODEMAPSDIR)/codemap_$(fs).svg,$\
			$($(U_$(fs))_OBJ) $($(U_$(fs))_CI),$\
			$(fs))))

# tiny codemap rules
$(foreach fs, $(SIZE_FILESYSTEMS),$\
	$(eval $(call CODEMAP_TINY_RULE,$\
			$(CODEMAPSDIR)/codemap_$(fs)_tiny.svg,$\
			$($(U_$(fs))_OBJ) $($(U_$(fs))_CI),$\
			$(fs))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save codemaps
.PHONY: save save-codemaps
save: save-codemaps
save-codemaps:
	mkdir -p $(SAVEDIR)/
	cp -ru $(CODEMAPSDIR) $(SAVEDIR)/


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean codemaps
.PHONY: clean clean-codemaps
clean: clean-codemaps
clean-codemaps:
	rm -rf $(CODEMAPSDIR)
	@echo "# note: Not cleaning saved output"


endif
