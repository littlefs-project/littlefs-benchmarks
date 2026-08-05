/*
 * Some extra bench helpers
 *
 */
#ifndef BENCH_HELPERS_H
#define BENCH_HELPERS_H

#include "runners/bench_runner.h"


// warm up the filesystem
//
// this writes a 1 block file 2*block_count times to get things into a
// good state for benchmarking
//
// most importantly this uses up any pre-erased blocks created during
// format, which is inconsistent across filesystems and messes with
// benchmarks
int bench_helpers_warmup(const struct lfs3_cfg *cfg, void *fs);


// populate the filesystem with static files
//
// useful for static vs dynamic wear-leveling, metadata pressure, etc
int bench_helpers_populate(const struct lfs3_cfg *cfg, void *fs,
        lfs3_off_t static_count, lfs3_off_t static_size,
        bool static_compact);


// interesting usage info, though not all filesystems provide these
struct bench_helpers_usage {
    uintmax_t usage;
    uintmax_t mdir;
    uintmax_t btree;
    uintmax_t data;
};

// find tight disk usage
//
// this is going to be a bit different for each filesystem
//
int bench_helpers_usage(const struct lfs3_cfg *cfg, void *fs,
        struct bench_helpers_usage *usage);


#endif
