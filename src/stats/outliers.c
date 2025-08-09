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

// Error codes for outlier detection
typedef enum {
    OUTLIER_SUCCESS                  = 0,
    OUTLIER_ERR_INSUFFICIENT_SAMPLES = 1,
    OUTLIER_ERR_INVALID_STATISTICS   = 2,
    OUTLIER_ERR_INVALID_METHOD       = 3
} outlier_error_t;

// Helper function for MAD-based outlier detection with custom threshold
// NOTE: Assumes input has already been validated and outliers structure is
// initialized
static outlier_error_t stats_outliers_mad_impl(const measure_samples_t *samples,
                                               double threshold,
                                               outliers_t *outliers)
{
    if (samples->count < MIN_SAMPLES_MAD_OUTLIER) {
        return OUTLIER_ERR_INSUFFICIENT_SAMPLES;
    }

    double median = stats_percentile(samples, PERCENTILE_50);
    double mad    = stats_mad(samples);

    if (!is_valid_number(median) || !is_valid_number(mad) ||
        mad <= STATS_EPSILON) {
        return OUTLIER_ERR_INVALID_STATISTICS;
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

    return OUTLIER_SUCCESS;
}

/**
 * Detect outliers using specified method
 * @param samples Pointer to samples data structure
 * @param method Outlier detection method (MEASURE_OUTLIER_TUKEY or
 * MEASURE_OUTLIER_MAD)
 * @param outliers Pointer to outliers structure to fill
 * @return Error code (OUTLIER_SUCCESS on success)
 */
// NOTE: Assumes input has already been validated and outliers structure is
// initialized
static outlier_error_t stats_outliers(const measure_samples_t *samples,
                                      outlier_method_t method,
                                      outliers_t *outliers)
{
    if (samples->count < MIN_SAMPLES_OUTLIER_DETECTION) {
        return OUTLIER_ERR_INSUFFICIENT_SAMPLES;
    }

    outliers->count = 0; // Reset count

    if (method == MEASURE_OUTLIER_TUKEY) {
        // Tukey's method using IQR
        double q1 = stats_percentile(samples, PERCENTILE_25);
        double q3 = stats_percentile(samples, PERCENTILE_75);

        if (!is_valid_number(q1) || !is_valid_number(q3)) {
            return OUTLIER_ERR_INVALID_STATISTICS;
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
        return OUTLIER_SUCCESS;
    } else if (method == MEASURE_OUTLIER_MAD) {
        // Use the unified MAD implementation with default threshold
        return stats_outliers_mad_impl(samples, OUTLIER_MAD_DEFAULT, outliers);
    } else {
        // Invalid method
        return OUTLIER_ERR_INVALID_METHOD;
    }
}

// Helper function to get error message
static const char *get_outlier_error_message(outlier_error_t err)
{
    switch (err) {
    case OUTLIER_SUCCESS:
        return NULL;
    case OUTLIER_ERR_INSUFFICIENT_SAMPLES:
        return "insufficient samples for outlier detection (need at least 4 "
               "samples)";
    case OUTLIER_ERR_INVALID_STATISTICS:
        return "invalid statistics (unable to compute percentiles or MAD)";
    case OUTLIER_ERR_INVALID_METHOD:
        return "invalid outlier detection method";
    default:
        return "unknown error";
    }
}

// Lua binding for outliers detection
static int outliers_lua(lua_State *L)
{
    static const char *const methods[] = {"tukey", "mad", NULL};
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    int method_idx             = luaL_checkoption(L, 2, "tukey", methods);
    outlier_method_t method =
        (method_idx == 0) ? MEASURE_OUTLIER_TUKEY : MEASURE_OUTLIER_MAD;

    // Allocate indices array using lua_newuserdata
    // This ensures proper memory management by Lua's GC
    size_t *indices =
        (size_t *)lua_newuserdata(L, samples->count * sizeof(size_t));

    // Create outliers structure on stack
    outliers_t outliers = {
        .indices  = indices,
        .capacity = samples->count,
        .count    = 0,
    };

    // Detect outliers
    outlier_error_t err = stats_outliers(samples, method, &outliers);
    if (err != OUTLIER_SUCCESS) {
        // Return nil and error message
        lua_pushnil(L);
        lua_pushstring(L, get_outlier_error_message(err));
        return 2;
    }

    // Return array of outlier indices (1-based for Lua)
    lua_createtable(L, outliers.count, 0);
    for (size_t i = 0; i < outliers.count; i++) {
        lua_pushinteger(L,
                        outliers.indices[i] + 1); // Convert to 1-based indexing
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

LUALIB_API int luaopen_measure_stats_outliers(lua_State *L)
{
    lua_pushcfunction(L, outliers_lua);
    return 1;
}
