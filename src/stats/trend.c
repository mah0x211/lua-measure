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

// Threshold for trend stability
#define CORRELATION_STABILITY_THRESHOLD 0.1

// Structure for trend analysis
typedef struct {
    double slope;       // Trend slope
    double correlation; // Correlation coefficient
    int stable;         // 1 if performance is stable, 0 otherwise
} trend_t;

/**
 * Analyze performance trend using linear regression
 * Calculates slope, correlation coefficient, and stability assessment
 * @param samples Pointer to samples data structure
 * @return trend_t structure with trend analysis results
 */
// NOTE: Assumes input has already been validated
static trend_t stats_trend(const measure_samples_t *samples)
{
    trend_t trend = {0.0, 0.0, 1};

    if (samples->count < MIN_SAMPLES_TREND_ANALYSIS) {
        return trend;
    }

    // Calculate linear regression for trend analysis
    double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_x2 = 0.0;
    size_t n = samples->count;

    for (size_t i = 0; i < n; i++) {
        double x = (double)i;
        double y = (double)samples->data[i].time_ns;
        sum_x += x;
        sum_y += y;
        sum_xy += x * y;
        sum_x2 += x * x;
    }

    double denom = n * sum_x2 - sum_x * sum_x;
    if (denom != 0.0) {
        trend.slope = (n * sum_xy - sum_x * sum_y) / denom;

        // Calculate correlation coefficient
        double mean_x = sum_x / n;
        double mean_y = sum_y / n;
        double num = 0.0, den_x = 0.0, den_y = 0.0;

        for (size_t i = 0; i < n; i++) {
            double dx = (double)i - mean_x;
            double dy = (double)samples->data[i].time_ns - mean_y;
            num += dx * dy;
            den_x += dx * dx;
            den_y += dy * dy;
        }

        if (den_x > 0.0 && den_y > 0.0) {
            trend.correlation = num / sqrt(den_x * den_y);
        }

        // Consider stable if correlation is weak (|r| < 0.1)
        trend.stable =
            (fabs(trend.correlation) < CORRELATION_STABILITY_THRESHOLD) ? 1 : 0;
    }

    return trend;
}

// Lua binding for trend analysis
static int trend_lua(lua_State *L)
{
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);

    trend_t trend = stats_trend(samples);
    lua_createtable(L, 0, 3);
    lua_pushnumber(L, trend.slope);
    lua_setfield(L, -2, "slope");
    lua_pushnumber(L, trend.correlation);
    lua_setfield(L, -2, "correlation");
    lua_pushboolean(L, trend.stable);
    lua_setfield(L, -2, "stable");

    return 1;
}

LUALIB_API int luaopen_measure_stats_trend(lua_State *L)
{
    lua_pushcfunction(L, trend_lua);
    return 1;
}
