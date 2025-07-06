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

// Default number of histogram bins
#define DEFAULT_DISTRIBUTION_BINS 10

// Structure for distribution/histogram
typedef struct {
    double *bin_edges;   // Bin edges (size = bins + 1)
    size_t *frequencies; // Frequency counts (size = bins)
    size_t bins;         // Number of bins
} distribution_t;

static void distribution_free(distribution_t *dist)
{
    if (dist) {
        free(dist->bin_edges);
        free(dist->frequencies);
        free(dist);
    }
}

/**
 * Calculate histogram/distribution of sample values
 * @param samples Pointer to samples data structure
 * @param bins Number of histogram bins
 * @return distribution_t structure with bin edges and frequencies
 */
// NOTE: Assumes input has already been validated
static distribution_t *stats_distribution(const measure_samples_t *samples,
                                          size_t bins)
{
    distribution_t *dist = malloc(sizeof(distribution_t));
    if (!dist) {
        return NULL;
    }

    dist->bin_edges   = malloc((bins + 1) * sizeof(double));
    dist->frequencies = malloc(bins * sizeof(size_t));
    if (!dist->bin_edges || !dist->frequencies) {
        distribution_free(dist);
        return NULL;
    }

    dist->bins = bins;

    // Calculate bin edges
    uint64_t min_val = stats_min(samples);
    uint64_t max_val = stats_max(samples);
    double range     = (double)(max_val - min_val);

    // Handle edge case where all values are identical (range = 0)
    if (range <= STATS_EPSILON) {
        // Create a single bin containing all values
        for (size_t i = 0; i <= bins; i++) {
            dist->bin_edges[i] = (double)min_val + (double)i * STATS_EPSILON;
        }

        // Initialize frequencies
        for (size_t i = 0; i < bins; i++) {
            dist->frequencies[i] = 0;
        }

        // All values go to the first bin
        dist->frequencies[0] = samples->count;
    } else {
        // Normal case with non-zero range
        for (size_t i = 0; i <= bins; i++) {
            dist->bin_edges[i] = (double)min_val + (range * i) / bins;
        }

        // Initialize frequencies
        for (size_t i = 0; i < bins; i++) {
            dist->frequencies[i] = 0;
        }

        // Count frequencies
        for (size_t i = 0; i < samples->count; i++) {
            uint64_t val   = samples->data[i].time_ns;
            size_t bin_idx = (size_t)(((double)(val - min_val)) / range * bins);
            if (bin_idx >= bins) {
                bin_idx = bins - 1; // Handle edge case
            }
            dist->frequencies[bin_idx]++;
        }
    }

    return dist;
}

// Lua binding for distribution calculation
static int distribution_lua(lua_State *L)
{
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_Integer bins = luaL_optinteger(L, 2, DEFAULT_DISTRIBUTION_BINS);

    if (!validate_positive_number(bins)) {
        return luaL_error(L, "number of bins must be positive, got %d",
                          (int)bins);
    }

    distribution_t *dist = stats_distribution(samples, bins);
    if (!dist) {
        return luaL_error(L, "failed to calculate distribution");
    }

    // Return table with bin_edges and frequencies
    lua_createtable(L, 0, 2);

    // bin_edges array
    lua_createtable(L, dist->bins + 1, 0);
    for (size_t i = 0; i <= dist->bins; i++) {
        lua_pushnumber(L, dist->bin_edges[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "bin_edges");

    // frequencies array
    lua_createtable(L, dist->bins, 0);
    for (size_t i = 0; i < dist->bins; i++) {
        lua_pushinteger(L, dist->frequencies[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "frequencies");

    distribution_free(dist);
    return 1;
}

LUALIB_API int luaopen_measure_stats_distribution(lua_State *L)
{
    lua_pushcfunction(L, distribution_lua);
    return 1;
}
