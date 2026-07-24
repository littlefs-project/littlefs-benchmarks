ifndef YAFFS2NCKP_MK
YAFFS2NCKP_MK := 1

# include common makefile
include Makefiles/common.mk
# derive from yaffs2 makefile
include Makefiles/yaffs2.mk


# yaffs2 bench-runner and sources
YAFFS2NCKP_BENCH_RUNNER ?= $(YAFFS2_BENCH_RUNNER)
YAFFS2NCKP_BENCHFLAGS ?= -DSKIP_CKPOINT=1

# add to list of filesystems
FILESYSTEMS += yaffs2nckp
ALIAS_FILESYSTEMS += yaffs2nckp
U_yaffs2nckp = YAFFS2NCKP
N_yaffs2nckp = 51
I_yaffs2nckp = 5
C_yaffs2nckp = $(C_PURPLE)
F_yaffs2nckp = $$$$nckp$$$$ # nckp
DEFAULT_BENCH_FILESYSTEMS  += yaffs2nckp
DEFAULT_YAFFS2_FILESYSTEMS += yaffs2nckp


endif
