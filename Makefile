
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
list: | build
	@echo "# available bench makefiles:"
	@echo "# make sizes"
	@echo "# make bench-sizes"
	@echo "# make -f Makefiles/codemaps.mk"
	@for f in Makefiles/bench*.mk ; do \
		echo "# make -f $$f" ; \
	done

