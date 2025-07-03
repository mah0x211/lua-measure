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

#include "common.h"
#include <lauxlib.h>
#include <lua.h>

// Memory statistics structure
typedef struct {
    double allocation_rate;   // KB/op
    double gc_impact;         // Correlation between GC and time
    double memory_efficiency; // Useful work vs allocation ratio
    size_t peak_memory;       // Peak memory usage in KB
} memstat_t;

/**
 * Analyze memory allocation patterns and efficiency
 * @param samples Pointer to samples data structure with memory information
 * @return memstat_t structure with memory usage statistics
 */
// NOTE: Assumes input has already been validated
static memstat_t stats_analyze_memory(const measure_samples_t *samples)
{
    memstat_t stat = {0.0, 0.0, 0.0, 0};

    size_t total_allocation = 0;
    size_t peak_memory      = 0;

    for (size_t i = 0; i < samples->count; i++) {
        total_allocation += samples->data[i].allocated_kb;
        if (samples->data[i].after_kb > peak_memory) {
            peak_memory = samples->data[i].after_kb;
        }
    }

    stat.allocation_rate = (double)total_allocation / samples->count;
    stat.peak_memory     = peak_memory;

    // Calculate correlation between allocation and time
    double mean_time  = stats_mean(samples);
    double mean_alloc = stat.allocation_rate;
    double num = 0.0, den_time = 0.0, den_alloc = 0.0;

    for (size_t i = 0; i < samples->count; i++) {
        double dt = (double)samples->data[i].time_ns - mean_time;
        double da = (double)samples->data[i].allocated_kb - mean_alloc;
        num += dt * da;
        den_time += dt * dt;
        den_alloc += da * da;
    }

    if (den_time > 0.0 && den_alloc > 0.0) {
        stat.gc_impact = num / sqrt(den_time * den_alloc);
    }

    // Memory efficiency: inverse of allocation rate (higher is better)
    stat.memory_efficiency =
        (stat.allocation_rate > 0.0) ? 1.0 / stat.allocation_rate : 0.0;

    return stat;
}

// Lua binding for memory statistics analysis
static int memstat_lua(lua_State *L)
{
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);

    if (!validate_samples(samples)) {
        return luaL_error(L, "invalid samples: contains negative time values");
    }

    memstat_t stat = stats_analyze_memory(samples);
    lua_createtable(L, 0, 4);
    lua_pushnumber(L, stat.allocation_rate);
    lua_setfield(L, -2, "allocation_rate");
    lua_pushnumber(L, stat.gc_impact);
    lua_setfield(L, -2, "gc_impact");
    lua_pushnumber(L, stat.memory_efficiency);
    lua_setfield(L, -2, "memory_efficiency");
    lua_pushinteger(L, stat.peak_memory);
    lua_setfield(L, -2, "peak_memory");

    return 1;
}

LUALIB_API int luaopen_measure_stats_memstat(lua_State *L)
{
    lua_pushcfunction(L, memstat_lua);
    return 1;
}
