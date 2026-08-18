/*
 * Some extra bench helpers
 *
 */

#include "benches/bench_helpers.h"


// warm up the filesystem
//
// this writes a 1 block file 2*block_count times to get things into a
// good state for benchmarking
//
// most importantly this uses up any pre-erased blocks created during
// format, which is inconsistent across filesystems and messes with
// benchmarks
int bench_helpers_warmup(const struct lfs3_cfg *cfg, void *fs) {
    uint8_t *wbuf = malloc(BLOCK_SIZE);
    memset(wbuf, '1', BLOCK_SIZE);

    #if defined(LFS3)
    (void)cfg;
    lfs3_t *lfs3 = fs;

    lfs3_file_t file;
    lfs3_file_open(lfs3, &file, "warmup",
            LFS3_O_WRONLY | LFS3_O_CREAT | LFS3_O_EXCL) => 0;
    for (lfs3_block_t i = 0; i < 2*BLOCK_COUNT; i++) {
        lfs3_file_rewind(lfs3, &file) => 0;
        lfs3_file_write(lfs3, &file, wbuf, BLOCK_SIZE) => BLOCK_SIZE;
        lfs3_file_sync(lfs3, &file) => 0;
    }
    lfs3_file_close(lfs3, &file) => 0;

    lfs3_remove(lfs3, "warmup") => 0;

    #elif defined(LFS2)
    (void)cfg;
    lfs2_t *lfs2 = fs;

    lfs2_file_t file;
    lfs2_file_open(lfs2, &file, "warmup",
            LFS2_O_WRONLY | LFS2_O_CREAT | LFS2_O_EXCL) => 0;
    for (lfs2_block_t i = 0; i < 2*BLOCK_COUNT; i++) {
        lfs2_file_rewind(lfs2, &file) => 0;
        lfs2_file_write(lfs2, &file, wbuf, BLOCK_SIZE) => BLOCK_SIZE;
        lfs2_file_sync(lfs2, &file) => 0;
    }
    lfs2_file_close(lfs2, &file) => 0;

    lfs2_remove(lfs2, "warmup") => 0;

    #elif defined(SPIFFS)
    spiffs *spiffs = fs;

    // this unfortunately takes way too long with spiffs, so instead
    // let's just zero disk and run the write loop only a couple times
    //
    // zeroing clears spiffs's lookup tables and makes it think all pages
    // have been deleted, which is mostly the same effect
    memset(wbuf, 0, BLOCK_SIZE);
    for (lfs3_block_t i = 0; i < BLOCK_COUNT; i++) {
        cfg->erase(cfg, i) => 0;
        cfg->prog(cfg, i, 0, wbuf, BLOCK_SIZE) => 0;
    }

    // update spiffs internal state
    spiffs_obj_lu_scan(spiffs) => 0;

    memset(wbuf, '1', BLOCK_SIZE);
    spiffs_file fd = SPIFFS_open(spiffs, "warmup",
            SPIFFS_WRONLY | SPIFFS_CREAT | SPIFFS_EXCL, 0777);
    assert(fd >= 0);
    // only a write a couple times
    for (lfs3_block_t i = 0; i < 4; i++) {
        SPIFFS_lseek(spiffs, fd, 0, SPIFFS_SEEK_SET) => 0;
        SPIFFS_write(spiffs, fd, wbuf, BLOCK_SIZE) => BLOCK_SIZE;
        s32_t d = SPIFFS_fflush(spiffs, fd);
        assert(d >= 0);
    }
    SPIFFS_close(spiffs, fd) => 0;

    SPIFFS_remove(spiffs, "warmup") => 0;

    #elif defined(YAFFS2)
    (void)cfg;
    (void)fs;

    int fd = yaffs_open("warmup", O_WRONLY | O_CREAT | O_EXCL, 0777);
    assert(fd >= 0);

    for (lfs3_block_t i = 0; i < 2*BLOCK_COUNT; i++) {
        yaffs_lseek(fd, 0, SEEK_SET) => 0;
        lfs3_soff_t d = yaffs_write(fd, wbuf, BLOCK_SIZE);
        if (d != BLOCK_SIZE) {
            // shortened writes are technically allowed by POSIX, but
            // this is usually a symptom of an error, allow another
            // write to make sure
            if (d < 0) {
                LFS3_ERROR("yaffs2 warmup failed? %d", yaffs_errno);
                return d;
            }
        }
        yaffs_fsync(fd) => 0;
    }
    yaffs_close(fd) => 0;

    yaffs_unlink("warmup") => 0;
    #endif

    free(wbuf);
    return 0;
}



// populate the filesystem with static files
//
// useful for static vs dynamic wear-leveling, metadata pressure, etc
int bench_helpers_populate(const struct lfs3_cfg *cfg, void *fs,
        lfs3_off_t static_count, lfs3_off_t static_size,
        bool static_compact) {
    (void)static_compact;
    char nbuf[256];
    uint8_t *wbuf = malloc(static_size);
    memset(wbuf, 's', static_size);

    #if defined(LFS3)
    (void)cfg;
    lfs3_t *lfs3 = fs;

    for (lfs3_off_t i = 0; i < static_count; i++) {
        lfs3_file_t file;
        sprintf(nbuf, "static_%08x", i);
        lfs3_file_open(lfs3, &file, nbuf,
                LFS3_O_WRONLY | LFS3_O_CREAT | LFS3_O_EXCL) => 0;
        lfs3_file_write(lfs3, &file, wbuf, static_size) => static_size;
        lfs3_file_close(lfs3, &file) => 0;
    }

    if (static_compact) {
        lfs3_gc_t gc;
        lfs3_gc_open(lfs3, &gc, LFS3_GC_COMPACTMETA) => 0;
        lfs3_sblock_t steps = lfs3_gc_write(lfs3, &gc, -1);
        assert(steps >= 0);
        lfs3_gc_close(lfs3, &gc) => 0;
    }
    #elif defined(LFS2)
    (void)cfg;
    lfs2_t *lfs2 = fs;

    for (lfs3_off_t i = 0; i < static_count; i++) {
        lfs2_file_t file;
        sprintf(nbuf, "static_%08x", i);
        lfs2_file_open(lfs2, &file, nbuf,
                LFS2_O_WRONLY | LFS2_O_CREAT | LFS2_O_EXCL) => 0;
        lfs2_file_write(lfs2, &file, wbuf, static_size) => static_size;
        lfs2_file_close(lfs2, &file) => 0;
    }

    #elif defined(SPIFFS)
    (void)cfg;
    spiffs *spiffs = fs;

    for (lfs3_off_t i = 0; i < static_count; i++) {
        sprintf(nbuf, "static_%08x", i);
        spiffs_file fd = SPIFFS_open(spiffs, nbuf,
                SPIFFS_WRONLY | SPIFFS_CREAT | SPIFFS_EXCL, 0777);
        assert(fd >= 0);
        SPIFFS_write(spiffs, fd, wbuf, static_size) => static_size;
        SPIFFS_close(spiffs, fd) => 0;
    }

    #elif defined(YAFFS2)
    (void)cfg;
    (void)fs;

    for (lfs3_off_t i = 0; i < static_count; i++) {
        sprintf(nbuf, "static_%08x", i);
        int fd = yaffs_open(nbuf, O_WRONLY | O_CREAT | O_EXCL, 0777);
        assert(fd >= 0);
        yaffs_write(fd, wbuf, static_size) => static_size;
        yaffs_close(fd) => 0;
    }
    #endif

    free(wbuf);
    return 0;
}



// needed to find disk usage for littlefs2
#if defined(LFS2)
static int bench_helpers_usage_cb(void *ctx, lfs3_block_t block) {
    uint8_t *usage_bmap = ctx;
    // TODO found a bug in littlefs2? lfs2_fs_traverse is returning the
    // fake cache block when it shouldn't ... and other garbage?
    if (!(block >= 0 && block < BLOCK_COUNT)) {
        LFS3_WARN("lfs2_fs_traverse: weird block? %d", block);
        return 0;
    }
    usage_bmap[block/8] |= 1 << (block % 8);
    return 0;
}
#endif

// find tight disk usage
//
// this is a bit different for each filesystem
//
int bench_helpers_usage(const struct lfs3_cfg *cfg, void *fs,
        struct bench_helpers_usage *usage) {
    #if defined(LFS3)
    (void)cfg;
    lfs3_t *lfs3 = fs;
    // measure disk usage
    //
    // littlefs can be a dag, so build a bitmap to find the exact
    // disk usage
    //
    // but also use 2 bits so we can still find mdir/btree/data specific
    // usage
    uint8_t *usage_bmap = malloc(((2*BLOCK_COUNT)+8-1)/8);
    memset(usage_bmap, 0, ((2*BLOCK_COUNT)+8-1)/8);

    lfs3_trv_t trv;
    lfs3_trv_open(lfs3, &trv, 0) => 0;
    while (true) {
        struct lfs3_binfo binfo;
        int err = lfs3_trv_read(lfs3, &trv, &binfo);
        assert(!err || err == LFS3_ERR_NOENT);
        if (err == LFS3_ERR_NOENT) {
            break;
        }

        if (binfo.btype == LFS3_BTYPE_MDIR) {
            usage_bmap[(2*binfo.block/8)] |= 1 << ((2*binfo.block) % 8);
        } else if (binfo.btype == LFS3_BTYPE_BTREE) {
            usage_bmap[(2*binfo.block/8)] |= 2 << ((2*binfo.block) % 8);
        } else {
            usage_bmap[(2*binfo.block/8)] |= 3 << ((2*binfo.block) % 8);
        }
    }
    lfs3_trv_close(lfs3, &trv) => 0;

    memset(usage, 0, sizeof(struct bench_helpers_usage));
    for (lfs3_size_t j = 0; j < BLOCK_COUNT; j++) {
        uint8_t btype = (usage_bmap[(2*j) / 8] >> ((2*j) % 8)) & 0x3;
        if (btype != 0) {
            usage->usage += 1;
            if (btype == 1) {
                usage->mdir += 1;
            } else if (btype == 2) {
                usage->btree += 1;
            } else {
                usage->data += 1;
            }
        }
    }

    free(usage_bmap);
    return 0;

    #elif defined(LFS2)
    (void)cfg;
    lfs2_t *lfs2 = fs;
    // measure disk usage
    //
    // littlefs can be a dag, so build a bitmap to find the exact
    // disk usage
    uint8_t *usage_bmap = malloc((BLOCK_COUNT+8-1)/8);
    memset(usage_bmap, 0, (BLOCK_COUNT+8-1)/8);

    int err = lfs2_fs_traverse(lfs2, bench_helpers_usage_cb, usage_bmap);
    if (err) {
        LFS3_WARN("lfs2_fs_traverse: failed %d", err);
    }

    memset(usage, 0, sizeof(struct bench_helpers_usage));
    for (lfs3_size_t j = 0; j < BLOCK_COUNT; j++) {
        if (usage_bmap[j / 8] & (1 << (j % 8))) {
            usage->usage += 1;
        }
    }

    free(usage_bmap);
    return 0;

    #elif defined(SPIFFS)
    (void)cfg;
    spiffs *spiffs = fs;
    // measure disk usage
    //
    // we rely on spiffs's internal bookkeeping here
    u32_t total;
    u32_t used;
    SPIFFS_info(spiffs, &total, &used) => 0;

    // include metadata pages in used
    used += (BLOCK_COUNT*BLOCK_SIZE) - total;

    // note used is already in bytes
    //
    // we could report (BLOCK_COUNT*BLOCK_SIZE) - total as meta here,
    // but, eh, we really only care about littlefs3, adding meta risks
    // confusion downstream
    memset(usage, 0, sizeof(struct bench_helpers_usage));
    usage->usage = used;
    return 0;

    #elif defined(YAFFS2)
    (void)cfg;
    struct yaffs_dev *yaffs2 = fs;

    // measure disk usage
    //
    // we rely on yaffs2's internal bookkeeping here
    //
    // Note we need to go behind yaffs2's back a bit here and _not_ use
    // yaffs_freespace. yaffs_freespace returns total bytes used, but
    // via a Y_LOFF_T, which is only 32-bits.
    //
    // Alternatively, we could define Y_LOFF_T to 64-bits in yaffscfg.h,
    // but this adds a surprising amount of codesize (+~664), and
    // yaffs_freespace seems to be the only function that falls over with
    // 32-bits
    Y_LOFF_T free = yaffs_get_n_free_chunks(yaffs2);
    assert(free >= 0);

    memset(usage, 0, sizeof(struct bench_helpers_usage));
    usage->usage = (BLOCK_COUNT*BLOCK_SIZE)
            - ((uintmax_t)free*(uintmax_t)yaffs2->data_bytes_per_chunk);
    return 0;
    #endif
}


