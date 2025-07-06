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

// Outlier detection thresholds
// Standard IQR multiplier for Tukey's method
#define OUTLIER_TUKEY_MULTIPLIER 1.5
// Default MAD threshold (moderate outliers)
#define OUTLIER_MAD_DEFAULT      2.5

// Outlier detection methods
typedef enum {
    MEASURE_OUTLIER_TUKEY = 0, // Tukey's method (IQR-based)
    MEASURE_OUTLIER_MAD   = 1  // Median Absolute Deviation
} outlier_method_t;

// Structure to hold outlier indices
typedef struct {
    size_t *indices; // Array of outlier indices
    size_t count;    // Number of outliers
    size_t capacity; // Capacity of indices array
} outliers_t;

static void outliers_free(outliers_t *outliers)
{
    if (outliers) {
        free(outliers->indices);
        free(outliers);
    }
}

// Helper function for MAD-based outlier detection with custom threshold
// NOTE: Assumes input has already been validated
static outliers_t *stats_outliers_mad_impl(const measure_samples_t *samples,
                                           double threshold)
{
    if (samples->count < MIN_SAMPLES_MAD_OUTLIER) {
        return NULL;
    }

    outliers_t *outliers = malloc(sizeof(outliers_t));
    if (!outliers) {
        return NULL;
    }

    outliers->indices = malloc(samples->count * sizeof(size_t));
    if (!outliers->indices) {
        free(outliers);
        return NULL;
    }

    outliers->count    = 0;
    outliers->capacity = samples->count;

    double median = stats_percentile(samples, PERCENTILE_50);
    double mad    = stats_mad(samples);

    if (!is_valid_number(median) || !is_valid_number(mad) ||
        mad <= STATS_EPSILON) {
        outliers_free(outliers);
        return NULL;
    }

    // MAD threshold (use default if not specified)
    if (!validate_positive_number(threshold)) {
        threshold = OUTLIER_MAD_DEFAULT;
    }

    for (size_t i = 0; i < samples->count; i++) {
        double val       = (double)samples->data[i].time_ns;
        double deviation = fabs(val - median) / mad;
        if (deviation > threshold) {
            outliers->indices[outliers->count++] = i;
        }
    }

    return outliers;
}

/**
 * Detect outliers using specified method
 * @param samples Pointer to samples data structure
 * @param method Outlier detection method (MEASURE_OUTLIER_TUKEY or
 * MEASURE_OUTLIER_MAD)
 * @return outliers_t structure containing indices of detected outliers
 */
// NOTE: Assumes input has already been validated
static outliers_t *stats_outliers(const measure_samples_t *samples,
                                  outlier_method_t method)
{
    if (samples->count < MIN_SAMPLES_OUTLIER_DETECTION) {
        return NULL;
    }

    outliers_t *outliers = malloc(sizeof(outliers_t));
    if (!outliers) {
        return NULL;
    }

    outliers->indices = malloc(samples->count * sizeof(size_t));
    if (!outliers->indices) {
        free(outliers);
        return NULL;
    }

    outliers->count    = 0;
    outliers->capacity = samples->count;

    if (method == MEASURE_OUTLIER_TUKEY) {
        // Tukey's method using IQR
        double q1 = stats_percentile(samples, PERCENTILE_25);
        double q3 = stats_percentile(samples, PERCENTILE_75);

        if (!is_valid_number(q1) || !is_valid_number(q3)) {
            outliers_free(outliers);
            return NULL;
        }

        double iqr         = q3 - q1;
        double lower_bound = q1 - OUTLIER_TUKEY_MULTIPLIER * iqr;
        double upper_bound = q3 + OUTLIER_TUKEY_MULTIPLIER * iqr;

        for (size_t i = 0; i < samples->count; i++) {
            double val = (double)samples->data[i].time_ns;
            if (is_valid_number(val) &&
                (val < lower_bound || val > upper_bound)) {
                outliers->indices[outliers->count++] = i;
            }
        }
    } else if (method == MEASURE_OUTLIER_MAD) {
        // Use the unified MAD implementation with default threshold
        outliers_free(outliers);
        return stats_outliers_mad_impl(samples, OUTLIER_MAD_DEFAULT);
    } else {
        // Invalid method
        outliers_free(outliers);
        return NULL;
    }

    return outliers;
}

// Lua binding for outliers detection
static int outliers_lua(lua_State *L)
{
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    const char *method_str     = luaL_optstring(L, 2, "tukey");

    outlier_method_t method;
    if (strcmp(method_str, "tukey") == 0) {
        method = MEASURE_OUTLIER_TUKEY;
    } else if (strcmp(method_str, "mad") == 0) {
        method = MEASURE_OUTLIER_MAD;
    } else {
        return luaL_error(
            L, "unknown outlier detection method: %s (use 'tukey' or 'mad')",
            method_str);
    }

    outliers_t *outliers = stats_outliers(samples, method);
    if (!outliers) {
        return luaL_error(L, "failed to detect outliers");
    }

    // Return array of outlier indices (1-based for Lua)
    lua_createtable(L, outliers->count, 0);
    for (size_t i = 0; i < outliers->count; i++) {
        lua_pushinteger(L, outliers->indices[i] +
                               1); // Convert to 1-based indexing
        lua_rawseti(L, -2, i + 1);
    }

    outliers_free(outliers);
    return 1;
}

LUALIB_API int luaopen_measure_stats_outliers(lua_State *L)
{
    lua_pushcfunction(L, outliers_lua);
    return 1;
}
