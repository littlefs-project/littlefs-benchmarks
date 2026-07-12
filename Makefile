
# This is just a simple wrapper over build
#
# There's a bunch of benchmarks and some of them take forever, so
# you'll need to specify them explicitly

include Makefiles/build.mk

## Build benches by default
.PHONY: all
all: build list

## List available benches
.PHONY: list
list:
	@echo "# note: Available bench makefiles:"
	@echo "# note: make sizes"
	@echo "# note: make bench-sizes"
	@echo "# note: make -f Makefiles/codemaps.mk"
	@for f in Makefiles/bench*.mk ; do \
		echo "# note: make -f $$f" ; \
	done


## Save bench-runner things
.PHONY: save save-build
save: save-build

## Save codemaps
.PHONY: save save-codemaps
save: save-codemaps
save-codemaps:
	mkdir -p $(SAVEDIR)/
	cp -ru $(CODEMAPSDIR) $(SAVEDIR)/

## Save bench results
.PHONY: save save-results
save: save-results
save-results:
	mkdir -p $(SAVEDIR)/
	cp -ru $(RESULTSDIR) $(SAVEDIR)/

## Save bench plots
.PHONY: save save-plots
save: save-plots
save-plots:
	mkdir -p $(SAVEDIR)/
	cp -ru $(PLOTSDIR) $(SAVEDIR)/

## Save tikz
.PHONY: save save-tikz
save: save-tikz
save-tikz:
	mkdir -p $(SAVEDIR)/
	cp -ru $(TIKZDIR) $(SAVEDIR)/


## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results
reuse-results touch-results:
	find $(RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


## Clean bench-runner things
.PHONY: clean clean-build
clean: clean-build

## Clean codemaps
.PHONY: clean clean-codemaps
clean: clean-codemaps
clean-codemaps:
	rm -rf $(CODEMAPSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench results
.PHONY: clean clean-results
clean: clean-results
clean-results:
	rm -rf $(RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots
clean: clean-plots
clean-plots:
	rm -rf $(PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz
clean: clean-tikz
clean-tikz:
	rm -rf $(TIKZDIR)
	@echo "# note: Not cleaning saved output"


## Clean saved files, note this will prompt
.PHONY: clean-saved
clean-saved:
	rm -rfi $(SAVEDIR)



