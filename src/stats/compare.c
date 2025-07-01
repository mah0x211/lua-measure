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

// Statistical significance levels
#define SIGNIFICANCE_LEVEL_01 0.01 // 1% significance level
#define SIGNIFICANCE_LEVEL_05 0.05 // 5% significance level
#define SIGNIFICANCE_LEVEL_10 0.10 // 10% significance level
#define SIGNIFICANCE_LEVEL_20 0.20 // 20% significance level
#define SIGNIFICANCE_LEVEL_50 0.50 // 50% significance level

// Structure for comparison results
typedef struct {
    double speedup;    // Speedup factor (time1/time2)
    double difference; // Mean difference
    double p_value;    // Statistical significance
    int significant;   // 1 if statistically significant, 0 otherwise
} comparison_t;

// Helper function to approximate p-value from t-statistic
static double approximate_p_value(double t_stat, size_t df)
{
    // Use absolute value of t-statistic
    t_stat = fabs(t_stat);

    // Get critical values for different significance levels
    double t_01 = get_t_value(df, CONFIDENCE_LEVEL_99); // p = 0.01
    double t_05 = get_t_value(df, CONFIDENCE_LEVEL_95); // p = 0.05
    double t_10 = get_t_value(df, CONFIDENCE_LEVEL_90); // p = 0.10

    // Approximate p-value based on t-statistic
    if (t_stat >= t_01)
        return SIGNIFICANCE_LEVEL_01;
    if (t_stat >= t_05)
        return SIGNIFICANCE_LEVEL_05;
    if (t_stat >= t_10)
        return SIGNIFICANCE_LEVEL_10;

    // For smaller t-values, use rough approximation
    if (t_stat >= 1.0)
        return SIGNIFICANCE_LEVEL_20;
    return SIGNIFICANCE_LEVEL_50;
}

/**
 * Perform statistical comparison between two sample sets using Welch's t-test
 * Calculates speedup, difference, p-value, and statistical significance
 * @param samples1 First sample set
 * @param samples2 Second sample set
 * @return comparison_t structure with statistical comparison results
 */
// NOTE: Assumes input has already been validated
static comparison_t stats_compare(const measure_samples_t *samples1,
                                  const measure_samples_t *samples2)
{
    comparison_t comp = {NAN, NAN, 1.0, 0};

    double mean1 = stats_mean(samples1);
    double mean2 = stats_mean(samples2);

    if (!is_valid_number(mean1) || !is_valid_number(mean2)) {
        return comp;
    }

    comp.speedup    = (mean2 > 0.0) ? mean1 / mean2 : NAN;
    comp.difference = mean1 - mean2;

    // Welch's t-test for unequal variances
    double var1 = stats_variance(samples1);
    double var2 = stats_variance(samples2);
    double n1   = (double)samples1->count;
    double n2   = (double)samples2->count;

    if (!is_valid_number(var1) || !is_valid_number(var2)) {
        return comp;
    }

    double se = sqrt(var1 / n1 + var2 / n2);
    if (se > STATS_EPSILON) {
        double t_stat = comp.difference / se;

        // Calculate degrees of freedom using Welch-Satterthwaite equation
        double df_num = pow(var1 / n1 + var2 / n2, 2);
        double df_den =
            pow(var1 / n1, 2) / (n1 - 1) + pow(var2 / n2, 2) / (n2 - 1);
        double df = df_num / df_den;

        // Round down to nearest integer
        size_t df_int = (size_t)floor(df);
        if (df_int < 1)
            df_int = 1;

        // Approximate p-value (two-tailed test)
        comp.p_value     = approximate_p_value(t_stat, df_int);
        comp.significant = (comp.p_value <= SIGNIFICANCE_LEVEL_05) ? 1 : 0;
    } else {
        // If standard error is too small, samples are likely identical
        comp.p_value     = 1.0;
        comp.significant = 0;
    }

    return comp;
}

// Lua binding for sample comparison
static int compare_lua(lua_State *L)
{
    measure_samples_t *samples1 = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    measure_samples_t *samples2 = luaL_checkudata(L, 2, MEASURE_SAMPLES_MT);

    if (!validate_samples(samples1)) {
        return luaL_error(L, "invalid samples1: contains negative time values");
    }

    if (!validate_samples(samples2)) {
        return luaL_error(L, "invalid samples2: contains negative time values");
    }

    comparison_t comp = stats_compare(samples1, samples2);

    lua_createtable(L, 0, 4);
    lua_pushnumber(L, comp.speedup);
    lua_setfield(L, -2, "speedup");
    lua_pushnumber(L, comp.difference);
    lua_setfield(L, -2, "difference");
    lua_pushnumber(L, comp.p_value);
    lua_setfield(L, -2, "p_value");
    lua_pushboolean(L, comp.significant);
    lua_setfield(L, -2, "significant");

    return 1;
}

LUALIB_API int luaopen_measure_stats_compare(lua_State *L)
{
    lua_pushcfunction(L, compare_lua);
    return 1;
}
