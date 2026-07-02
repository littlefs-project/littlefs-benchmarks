ifndef LFS3F_MK
LFS3F_MK := 1

# include common makefile
include Makefiles/common.mk
# derive from littlefs3 makefile
include Makefiles/lfs3.mk


# littlefs3 bench-runner and sources
LFS3F_BENCH_RUNNER ?= $(LFS3_BENCH_RUNNER)
LFS3F_BENCHFLAGS += -DFRUNCATE=1

# add to list of filesystems
FILESYSTEMS += lfs3f
U_lfs3f = LFS3F
N_lfs3f = 33
I_lfs3f = 0
C_lfs3f = $(C_BLUE)
F_lfs3f = $$$$f$$$$ # f
DEFAULT_BENCH_FILESYSTEMS += lfs3f


endif
