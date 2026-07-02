ifndef LFS3S_MK
LFS3S_MK := 1

# include common makefile
include Makefiles/common.mk
# derive from littlefs3 makefile
include Makefiles/lfs3.mk


# littlefs3 bench-runner and sources
LFS3S_BENCH_RUNNER ?= $(LFS3_BENCH_RUNNER)
LFS3S_BENCHFLAGS += -DSET=1

# add to list of filesystems
FILESYSTEMS += lfs3s
U_lfs3s = LFS3S
N_lfs3s = 35
I_lfs3s = 0
C_lfs3s = $(C_BLUE)
F_lfs3s = $$$$s$$$$ # s
DEFAULT_BENCH_FILESYSTEMS += lfs3s


endif
