ifndef LFS3G_MK
LFS3G_MK := 1

# include common makefile
include Makefiles/common.mk
# derive from littlefs3 makefile
include Makefiles/lfs3.mk


# littlefs3 bench-runner and sources
LFS3G_BENCH_RUNNER ?= $(LFS3_BENCH_RUNNER)
LFS3G_BENCHFLAGS += -DGRANULAR=1

# add to list of filesystems
FILESYSTEMS += lfs3g
ALIAS_FILESYSTEMS += lfs3g
U_lfs3g = LFS3G
N_lfs3g = 33
I_lfs3g = 0
C_lfs3g = $(C_BLUE)
F_lfs3g = $$$$g$$$$ # g
DEFAULT_BENCH_FILESYSTEMS += lfs3g
DEFAULT_LFS3_FILESYSTEMS  += lfs3g


endif
