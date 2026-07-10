/*
 * YAFFS2 config, for littlefs benchmarking
 *
 */

#ifndef __YAFFSCFG_H__
#define __YAFFSCFG_H__


// yaffs2 includes
//
// note yaffs2 uses a lot of non-prefixed OS-level names
//
// we're using our current system's stdlib for these, but yaffs2 can be
// told to define its own if desired:
// - #define CONFIG_YAFFS_PROVIDE_DEFS 1
// - #define CONFIG_YAFFSFS_PROVIDE_VALUES 1
// - #define CONFIG_YAFFS_DEFINES_TYPES 1
//
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>

// needed only for constants?
#undef _FEATURES_H
#define _DEFAULT_SOURCE
#include <dirent.h>


// yaffs2 compile-time config

#define CONFIG_YAFFS_DIRECT 1
#define CONFIG_YAFFS_YAFFS2 1
// TODO docs say not supported? TODO test this?
#define CONFIG_YAFFS_NO_YAFFS1 1
// well yes use less RAM
#define CONFIG_YAFFS_SMALL_RAM 1
// 32-bit time
#define CONFIG_YAFFS_USE_32_BIT_TIME_T 1
// disable trace for code size
#ifdef LFS3_NO_LOG
#define CONFIG_YAFFS_NO_TRACE
#endif

// // 32-bit Y_LOFF_T
// #define Y_LOFF_T int32_t

// map Y_LOFF_T to ssize_t
//
// this should end up 32-bits on thumb and 64-bits locally
#define Y_LOFF_T ssize_t

// number of statically allocated file handles
// we only need one file for benchmarking
#define YAFFSFS_N_HANDLES 1
// number of statically allocated dirents for readdir
#define YAFFSFS_N_DSC 1


// various types
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t  u8;

typedef int64_t  s64;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int8_t   s8;


// take over os glue (yaffs_osglue.h)
//
// (sorry, I know this is cursed)
#define __YAFFS_OSGLUE_H__

// override various os glue

static void yaffsfs_OSInitialisation(void) {}
static inline u32 yaffsfs_CurrentTime(void) { return 0; }
static inline void yaffsfs_Lock(void) {}
static inline void yaffsfs_Unlock(void) {}

__attribute__((weak))
int yaffs_errno = 0;

static inline void yaffsfs_SetError(int err) {
    yaffs_errno = err;
}

static inline int yaffsfs_GetLastError(void) {
    return yaffs_errno;
}

static inline void *yaffsfs_malloc(size_t size) {
    return malloc(size);
}

static inline void yaffsfs_free(void *ptr) {
    free(ptr);
}

static inline int yaffsfs_CheckMemRegion(const void *addr, size_t size,
        int write_request) {
    (void)addr;
    (void)size;
    (void)write_request;
    return 0;
}

// YAFFS_TRACE_ALWAYS + YAFFS_TRACE_CHECKPT
__attribute__((weak))
unsigned int yaffs_trace_mask = 0xf0008000;
//unsigned int yaffs_trace_mask = -1; // all trace flags
//unsigned int yaffs_trace_mask = 0;  // no trace flags

static inline void yaffs_bug_fn(const char *file_name, int line_no) {
    (void)file_name;
    (void)line_no;
    __builtin_trap();
}


// why was this never declared?
struct yaffs_dev;
void yaffs_remove_device(struct yaffs_dev *dev);


#endif
