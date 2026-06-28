
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

