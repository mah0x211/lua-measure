/**
 *  Copyright (C) 2025 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

#ifndef measure_samples_h
#define measure_samples_h

#include <errno.h>
#include <stdint.h>
#include <string.h>
// measure headers
#include "measure.h"
// lua
#include <lauxlib.h>
#include <lua.h>

#define MEASURE_SAMPLES_MT "measure.samples"

typedef struct {
    uint64_t time_ns;    // sample in nanoseconds
    size_t before_kb;    // Memory usage before operation (after GC if mode=0)
    size_t after_kb;     // Memory usage after operation
    size_t allocated_kb; // Memory allocated during operation
} measure_samples_data_t;

typedef struct {
    size_t capacity;      // capacity of the samples array
    size_t count;         // number of samples collected
    size_t base_kb;       // Memory usage at start (after initial GC)
    int saved_gc_pause;   // Saved GC pause value
    int saved_gc_stepmul; // Saved GC step multiplier value
    double cl;            // confidence  level (e.g., 95.0%)
    double rciw;          // relative confidence interval width (e.g., 5.0%)
    int gc_step;          // GC step size in KB (0 for full GC)
    int ref_data;         // reference to Lua data array
    measure_samples_data_t *data; // array of samples in nanoseconds
} measure_samples_t;

/**
 * @brief Reset the measure_samples_t object.
 * This function resets the count of samples to 0 and clears the data array
 * by setting all elements to 0.
 *
 * @param s Pointer to the measure_samples_t object
 */
static inline void measure_samples_reset(measure_samples_t *s)
{
    s->count = 0;
    memset(s->data, 0, sizeof(measure_samples_data_t) * s->capacity);
}

/**
 * @brief Initialize the measure_samples_t object.
 *
 * @param s Pointer to the measure_samples_t object
 * @param L Lua state
 */
static inline void measure_samples_preprocess(measure_samples_t *s,
                                              lua_State *L)
{
    // Always reset count and clear data
    measure_samples_reset(s);

    // Save GC state
    s->saved_gc_pause = lua_gc(L, LUA_GCSETPAUSE, 0);
    lua_gc(L, LUA_GCSETPAUSE, s->saved_gc_pause); // Restore immediately
#if LUA_VERSION_NUM >= 502
    s->saved_gc_stepmul = lua_gc(L, LUA_GCSETSTEPMUL, 0);
    lua_gc(L, LUA_GCSETSTEPMUL, s->saved_gc_stepmul); // Restore immediately
#else
    s->saved_gc_stepmul = 200; // Default value for Lua 5.1
#endif

    // Perform full GC to get clean baseline
    lua_gc(L, LUA_GCCOLLECT, 0);
    // Record baseline memory usage after GC
    s->base_kb = (size_t)(lua_gc(L, LUA_GCCOUNT, 0));
    // Disable GC if step is negative
    if (s->gc_step < 0) {
        lua_gc(L, LUA_GCSTOP, 0);
    }
}

/**
 * @brief Post-process the measure_samples_t object.
 * This function re-enables the garbage collector and restores its state.
 *
 * @param s Pointer to the measure_samples_t object
 * @param L Lua state
 */
static inline void measure_samples_postprocess(measure_samples_t *s,
                                               lua_State *L)
{
    // Re-enable and restore GC state
    lua_gc(L, LUA_GCRESTART, 0);
    lua_gc(L, LUA_GCSETPAUSE, s->saved_gc_pause);
#if LUA_VERSION_NUM >= 502
    lua_gc(L, LUA_GCSETSTEPMUL, s->saved_gc_stepmul);
#endif
}

/**
 * @brief Initialize a new sample in the measure_samples_t object.
 * This function initializes a new sample by setting the current time in
 * nanoseconds and recording the memory usage before the operation. It checks if
 * there is space left in the samples array and returns -1 if not. If the
 * gc_step is 0, it performs a full garbage collection to ensure a clean state.
 *
 * @param s Pointer to the measure_samples_t object
 * @param L Lua state
 * @return 0 on success, -1 on error (if no space left)
 */
static inline int measure_samples_init_sample(measure_samples_t *s,
                                              lua_State *L)
{
    if (s->count >= s->capacity) {
        // no space left to add a new sample
        errno = ENOSPC;
        return -1;
    }

    // if gc_step is 0, full GC to ensure clean state
    if (s->gc_step == 0) {
        lua_gc(L, LUA_GCCOLLECT, 0);
    }

    measure_samples_data_t *data = &s->data[s->count];
    // get the current time in nanoseconds
    data->time_ns                = measure_getnsec();
    // record memory before operation
    data->before_kb              = (size_t)(lua_gc(L, LUA_GCCOUNT, 0));
    data->after_kb               = 0;
    data->allocated_kb           = 0;
    return 0;
}

/**
 * @brief Update the current sample in the measure_samples_t object.
 * This function calculates the elapsed time since the sample was initialized,
 * updates the memory usage after the operation, and applies step GC if needed.
 * It increments the sample count and returns 0 on success.
 *
 * @param s Pointer to the measure_samples_t object
 * @param L Lua state
 * @return int 0 on success, -1 on error (if no space left)
 */
static inline int measure_samples_update_sample(measure_samples_t *s,
                                                lua_State *L)
{
    if (s->count >= s->capacity) {
        // no space left to add a new sample
        errno = ENOSPC;
        return -1;
    }

    measure_samples_data_t *data = &s->data[s->count];
    // calculate the elapsed time
    data->time_ns                = measure_getnsec() - data->time_ns;
    data->after_kb               = (size_t)lua_gc(L, LUA_GCCOUNT, 0);
    // Calculate allocated KB
    if (data->after_kb > data->before_kb) {
        data->allocated_kb = data->after_kb - data->before_kb;
    }

    // Apply step GC if needed
    if (s->gc_step > 0 && data->allocated_kb >= (size_t)s->gc_step) {
        lua_gc(L, LUA_GCSTEP, s->gc_step);
    }

    // Increment sample count
    s->count++;

    return 0;
}

#endif /* measure_samples_h */
