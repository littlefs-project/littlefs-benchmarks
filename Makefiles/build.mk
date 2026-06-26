ifndef BUILD_MK
BUILD_MK := 1

# include filesystem makefiles
include Makefiles/lfs3.mk
include Makefiles/lfs3gb.mk
include Makefiles/lfs3g.mk
include Makefiles/lfs3f.mk
include Makefiles/lfs3s.mk
include Makefiles/lfs2.mk
include Makefiles/lfs1.mk
include Makefiles/spiffs.mk
include Makefiles/yaffs2.mk

# default size/build filesystems to default size/build filesystems
SIZE_FILESYSTEMS  ?= $(DEFAULT_SIZE_FILESYSTEMS)
BUILD_FILESYSTEMS ?= $(DEFAULT_BUILD_FILESYSTEMS)


## Generate ctags for everything
.PHONY: tags ctags
tags ctags: $(foreach fs, $(BUILD_FILESYSTEMS), ctags-$(fs))

## Build everything
.PHONY: all build
all build: $(foreach fs, $(BUILD_FILESYSTEMS), build-$(fs))

## Find compile-time sizes _before_ link-time gc
.PHONY: sizes sizes-prelink
sizes sizes-prelink: \
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
		-Bi -bfs \
		-fcode=code_size \
		-fdata=data_size \
		-fstack='max(stack_limit)' \
		-fctx='max(ctx_size)' \
		--no-total)

## Find compile-time sizes _after_ link-time gc
#
# note we need to filter .ci symbols based on runner symbols picked up
# by code/data/ctx/etc
#
.PHONY: sizes-postlink bench-sizes
sizes-postlink bench-sizes: BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)
sizes-postlink bench-sizes: \
		$(foreach fs, $(BENCH_FILESYSTEMS), \
			$($(U_$(fs))_BENCH_RUNNER) \
			$($(U_$(fs))_CI))
	$(strip ./scripts/csv.py \
		$(foreach fs, $(BENCH_FILESYSTEMS), \
			<(./scripts/csv.py \
				<(./scripts/code.py $($(U_$(fs))_BENCH_RUNNER) \
					-bfunction -o- \
						| $($(U_$(fs))_FILTER)) \
				<(./scripts/data.py $($(U_$(fs))_BENCH_RUNNER) \
					-bfunction -o- \
						| $($(U_$(fs))_FILTER)) \
				<(./scripts/stack.py $($(U_$(fs))_BENCH_CI) \
					-bfunction -o- \
						| $($(U_$(fs))_FILTER)) \
				<(./scripts/ctx.py $($(U_$(fs))_BENCH_RUNNER) \
					-bfunction -o- \
						| $($(U_$(fs))_FILTER)) \
				-bi=$(I_$(fs)) -bfs=$(fs) -bfunction -o-)) \
		-Bi -bfs \
		-fcode=code_size \
		-fdata=data_size \
		-fstack='max((code_size) ? stack_limit : 0)' \
		-fctx='max(ctx_size)' \
		--no-total)


endif
