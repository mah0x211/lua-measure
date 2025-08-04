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

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
// lua
#include "measure_samples.h"
#include "stats/common.h"
#include <lauxlib.h>
#include <lua.h>

#define MEASURE_WELCH_ANOVA_MT "measure.welch_anova"

typedef struct {
    double fstat;  // F-statistic
    double df1;    // Degrees of freedom (numerator)
    double df2;    // Degrees of freedom (denominator)
    double pvalue; // Approximate p-value
} measure_welch_anova_t;

static int pvalue_lua(lua_State *L)
{
    measure_welch_anova_t *s = luaL_checkudata(L, 1, MEASURE_WELCH_ANOVA_MT);
    lua_pushnumber(L, s->pvalue);
    return 1;
}

static int df2_lua(lua_State *L)
{
    measure_welch_anova_t *s = luaL_checkudata(L, 1, MEASURE_WELCH_ANOVA_MT);
    lua_pushnumber(L, s->df2);
    return 1;
}

static int df1_lua(lua_State *L)
{
    measure_welch_anova_t *s = luaL_checkudata(L, 1, MEASURE_WELCH_ANOVA_MT);
    lua_pushnumber(L, s->df1);
    return 1;
}

static int fstat_lua(lua_State *L)
{
    measure_welch_anova_t *s = luaL_checkudata(L, 1, MEASURE_WELCH_ANOVA_MT);
    lua_pushnumber(L, s->fstat);
    return 1;
}

static int tostring_lua(lua_State *L)
{
    measure_welch_anova_t *w = luaL_checkudata(L, 1, MEASURE_WELCH_ANOVA_MT);
    lua_pushfstring(L, MEASURE_WELCH_ANOVA_MT ": %p", (void *)w);
    return 1;
}

/* -------------------------------------------------------------------------
 *  Regularised incomplete beta I_x(a,b)  and F‑distribution CDF utilities
 *  (Adapted from Cephes Math Library – public domain)
 * -------------------------------------------------------------------------*/
// Compute the log of the beta function using gamma functions
// This is used as a normalization factor for the incomplete beta function
static double compute_log_beta(double a, double b)
{
    return lgamma(a) + lgamma(b) - lgamma(a + b);
}

// Compute the complete regularized incomplete beta function I_x(a,b) using
// continued fraction This function returns the actual I_x(a,b) value, not just
// the continued fraction part
static double compute_regularized_incomplete_beta(double a, double b, double x)
{
    // Handle boundary cases
    if (x <= 0.0) {
        return 0.0;
    } else if (x >= 1.0) {
        return 1.0;
    } else if (a <= 0.0 || b <= 0.0) {
        return 0.0; // Invalid parameters
    }

    // Use symmetry relation I_x(a,b) = 1 - I_{1-x}(b,a) to ensure convergence
    // The continued fraction converges better when x < (a+1)/(a+b+2)
    if (x > (a + 1.0) / (a + b + 2.0)) {
        return 1.0 - compute_regularized_incomplete_beta(b, a, 1.0 - x);
    }

    // Compute the normalization factor
    double log_beta_front = a * log(x) + b * log1p(-x) - compute_log_beta(a, b);
    double beta_front     = exp(log_beta_front);

    // Continued fraction computation using Lentz's algorithm
    const int MAX_ITERATIONS         = 200;
    const double CONVERGENCE_EPSILON = 1e-14;
    const double TINY_VALUE          = 1e-30;

    // Pre-compute commonly used values
    double a_plus_b  = a + b;
    double a_plus_1  = a + 1.0;
    double a_minus_1 = a - 1.0;

    // Initialize Lentz's algorithm
    double c_factor = 1.0;
    double d_factor = 1.0 - a_plus_b * x / a_plus_1;

    if (fabs(d_factor) < TINY_VALUE) {
        d_factor = TINY_VALUE;
    }

    d_factor          = 1.0 / d_factor;
    double convergent = d_factor;

    // Iterate the continued fraction
    for (int iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
        int twice_iteration = iteration * 2;

        // Even term: coefficient = m*(b-m)*x / [(a-1+2m)*(a+2m)]
        double even_coeff =
            iteration * (b - iteration) * x /
            ((a_minus_1 + twice_iteration) * (a + twice_iteration));

        // Update factors for even term
        d_factor = 1.0 + even_coeff * d_factor;
        if (fabs(d_factor) < TINY_VALUE) {
            d_factor = TINY_VALUE;
        }

        c_factor = 1.0 + even_coeff / c_factor;
        if (fabs(c_factor) < TINY_VALUE) {
            c_factor = TINY_VALUE;
        }

        d_factor = 1.0 / d_factor;
        convergent *= d_factor * c_factor;

        // Odd term: coefficient = -(a+m)*(a+b+m)*x / [(a+2m)*(a+1+2m)]
        double odd_coeff =
            -(a + iteration) * (a_plus_b + iteration) * x /
            ((a + twice_iteration) * (a_plus_1 + twice_iteration));

        // Update factors for odd term
        d_factor = 1.0 + odd_coeff * d_factor;
        if (fabs(d_factor) < TINY_VALUE) {
            d_factor = TINY_VALUE;
        }

        c_factor = 1.0 + odd_coeff / c_factor;
        if (fabs(c_factor) < TINY_VALUE) {
            c_factor = TINY_VALUE;
        }

        d_factor     = 1.0 / d_factor;
        double delta = d_factor * c_factor;
        convergent *= delta;

        // Check for convergence
        if (fabs(delta - 1.0) < CONVERGENCE_EPSILON) {
            break;
        }
    }

    // Return the complete regularized incomplete beta function
    // I_x(a,b) = [x^a * (1-x)^b / B(a,b)] * continued_fraction / a
    return beta_front * convergent / a;
}

// Compute the cumulative distribution function (CDF) of the F-distribution
// F ~ F(df1, df2) with degrees of freedom df1 and df2
// The F-CDF is related to the incomplete beta function by:
// P(F ≤ f) = I_x(df1/2, df2/2) where x = (df1*f)/(df1*f + df2)
static double compute_f_distribution_cdf(double f_statistic,
                                         double degrees_freedom_1,
                                         double degrees_freedom_2)
{
    // Handle edge cases
    if (f_statistic <= 0.0) {
        // F-statistic must be positive
        return 0.0;
    } else if (degrees_freedom_1 <= 0.0 || degrees_freedom_2 <= 0.0) {
        // Degrees of freedom must be positive
        return 0.0;
    }

    // Transform F-statistic to incomplete beta function argument
    double x_transform = (degrees_freedom_1 * f_statistic) /
                         (degrees_freedom_1 * f_statistic + degrees_freedom_2);

    // Compute CDF using the relationship to incomplete beta function
    return compute_regularized_incomplete_beta(
        degrees_freedom_1 * 0.5, degrees_freedom_2 * 0.5, x_transform);
}

static void *malloc_lua(lua_State *L, size_t size)
{
    return lua_newuserdata(L, size);
}

static void *realloc_lua(lua_State *L, void *ptr, size_t size, size_t newsize)
{
    void *tmp = malloc_lua(L, newsize);
    memcpy(tmp, ptr, size);
    return tmp;
}

// Structure to hold statistical information for each group in Welch's ANOVA
typedef struct {
    size_t sample_size;    // Number of samples in this group (n_i)
    double group_mean;     // Sample mean of this group (x̄_i)
    double group_variance; // Sample variance of this group (s²_i)
    double weight;         // Weight for this group: w_i = n_i/s²_i
} welch_group_stats_t;

// Structure to hold the results of Welch's ANOVA calculations
typedef struct {
    double f_statistic;       // Welch's F-statistic
    double degrees_freedom_1; // Numerator degrees of freedom (k-1)
    double degrees_freedom_2; // Denominator degrees of freedom
                              // (Welch-Satterthwaite)
    double p_value;           // P-value from F-distribution
} welch_anova_results_t;

// Extract and validate group statistics from a Lua table containing
// measure.samples userdata Returns the number of groups extracted, or 0 on
// error
static size_t extract_group_statistics(lua_State *L, int table_index,
                                       welch_group_stats_t **groups_ptr,
                                       size_t *capacity_ptr)
{
    size_t num_groups = 0;
    size_t capacity   = 8;
    welch_group_stats_t *groups =
        malloc_lua(L, sizeof(welch_group_stats_t) * capacity);

    // Iterate through all key-value pairs in the table
    lua_pushnil(L); // First key for lua_next
    while (lua_next(L, table_index) != 0) {
        // Stack: key at -2, value at -1
        measure_samples_t *sample_data =
            luaL_checkudata(L, -1, MEASURE_SAMPLES_MT);

        // Validate that each group has at least 2 samples (required for
        // variance calculation)
        if (sample_data->count < 2) {
            return luaL_error(
                L,
                "each group must contain at least 2 samples for Welch's ANOVA");
        }

        // Expand storage if needed
        if (num_groups == capacity) {
            size_t new_capacity = capacity * 2;
            groups =
                realloc_lua(L, groups, sizeof(welch_group_stats_t) * capacity,
                            sizeof(welch_group_stats_t) * new_capacity);
            capacity = new_capacity;
        }

        // Extract statistical measures from the samples
        double sample_mean     = sample_data->mean;
        // Calculate sample variance using Welford's method: s² = M2/(n-1)
        double sample_variance = sample_data->M2 / (sample_data->count - 1);

        // Validate statistical measures
        if (!isfinite(sample_mean) || !isfinite(sample_variance) ||
            sample_variance <= 0.0) {
            return luaL_error(L,
                              "invalid sample statistics: mean=%f, variance=%f "
                              "(variance must be > 0)",
                              sample_mean, sample_variance);
        }

        // Store group statistics
        groups[num_groups].sample_size    = sample_data->count;
        groups[num_groups].group_mean     = sample_mean;
        groups[num_groups].group_variance = sample_variance;
        groups[num_groups].weight =
            (double)sample_data->count / sample_variance; // w_i = n_i/s²_i
        num_groups++;

        lua_pop(L, 1); // Remove value, keep key for next iteration
    }

    // Welch's ANOVA requires at least two groups
    if (num_groups < 2) {
        return luaL_error(L,
                          "Welch's ANOVA requires at least two groups, got %zu",
                          num_groups);
    }

    *groups_ptr   = groups;
    *capacity_ptr = capacity;
    return num_groups;
}

// Perform Welch's ANOVA calculations on the extracted group statistics
// This implements the core mathematical formulas for Welch's one-way ANOVA
static welch_anova_results_t
compute_welch_anova_statistics(const welch_group_stats_t *groups,
                               size_t num_groups)
{
    welch_anova_results_t results = {0};

    // Step 1: Calculate the weighted grand mean
    // weighted_grand_mean = Σ(w_i * x̄_i) / Σ(w_i)
    double total_weight          = 0.0;
    double weighted_sum_of_means = 0.0;

    for (size_t i = 0; i < num_groups; i++) {
        total_weight += groups[i].weight;
        weighted_sum_of_means += groups[i].weight * groups[i].group_mean;
    }

    double weighted_grand_mean = weighted_sum_of_means / total_weight;

    // Step 2: Calculate the numerator of the F-statistic
    // numerator = Σ[w_i * (x̄_i - weighted_grand_mean)²] / (k - 1)
    double between_groups_variation = 0.0;

    for (size_t i = 0; i < num_groups; i++) {
        double deviation_from_grand_mean =
            groups[i].group_mean - weighted_grand_mean;
        between_groups_variation += groups[i].weight *
                                    deviation_from_grand_mean *
                                    deviation_from_grand_mean;
    }

    double f_numerator = between_groups_variation / (double)(num_groups - 1);

    // Step 3: Calculate the correction factor A (gamma in the original code)
    // This adjusts for unequal variances in the denominator
    // A = Σ[(1/(n_i - 1)) * (1 - w_i/W)²]
    double correction_factor_A = 0.0;

    for (size_t i = 0; i < num_groups; i++) {
        double weight_proportion = groups[i].weight / total_weight; // w_i/W
        double complement_weight = 1.0 - weight_proportion; // (1 - w_i/W)
        correction_factor_A += (complement_weight * complement_weight) /
                               (double)(groups[i].sample_size - 1);
    }

    // Step 4: Calculate the denominator of the F-statistic
    // denominator = 1 + [2(k-2)/(k²-1)] * A
    double k                      = (double)num_groups;
    double denominator_adjustment = (2.0 * (k - 2.0)) / (k * k - 1.0);
    double f_denominator = 1.0 + denominator_adjustment * correction_factor_A;

    // Step 5: Calculate the F-statistic
    results.f_statistic = f_numerator / f_denominator;

    // Step 6: Calculate degrees of freedom
    // df1 (numerator): Always k - 1 for one-way ANOVA
    results.degrees_freedom_1 = k - 1.0;

    // df2 (denominator): Welch-Satterthwaite approximation
    // df2 = (k² - 1) / (3A)
    results.degrees_freedom_2 = (k * k - 1.0) / (3.0 * correction_factor_A);

    // Guard against pathologically small df2 values
    if (results.degrees_freedom_2 < 1.0) {
        results.degrees_freedom_2 = 1.0;
    }

    // Step 7: Calculate p-value using F-distribution CDF
    // p-value = P(F ≥ observed_F) = 1 - P(F < observed_F)
    double f_cdf_value = compute_f_distribution_cdf(results.f_statistic,
                                                    results.degrees_freedom_1,
                                                    results.degrees_freedom_2);
    results.p_value    = 1.0 - f_cdf_value;

    // Ensure p-value stays within valid bounds [0, 1]
    if (results.p_value < 0.0) {
        results.p_value = 0.0;
    } else if (results.p_value > 1.0) {
        results.p_value = 1.0;
    }

    return results;
}

// Main Lua interface function for Welch's ANOVA
// Input: Lua table containing measure.samples userdata objects
// Output: measure.welch_anova userdata object with results
static int welch_anova_lua(lua_State *L)
{
    // Validate input: expect a table whose values are measure.samples userdata
    luaL_checktype(L, 1, LUA_TTABLE);

    // Step 1: Extract and validate group statistics from the input table
    welch_group_stats_t *groups = NULL;
    size_t capacity             = 0;
    size_t num_groups = extract_group_statistics(L, 1, &groups, &capacity);

    // Step 2: Perform Welch's ANOVA calculations
    welch_anova_results_t results =
        compute_welch_anova_statistics(groups, num_groups);

    // Step 3: Create and populate the result userdata object
    lua_settop(L, 0); // Clear stack before returning userdata
    measure_welch_anova_t *result_object =
        (measure_welch_anova_t *)lua_newuserdata(L,
                                                 sizeof(measure_welch_anova_t));

    result_object->fstat  = results.f_statistic;
    result_object->df1    = results.degrees_freedom_1;
    result_object->df2    = results.degrees_freedom_2;
    result_object->pvalue = results.p_value;

    // Step 4: Set up the metatable for the result object
    luaL_getmetatable(L, MEASURE_WELCH_ANOVA_MT);
    lua_setmetatable(L, -2);

    return 1; // Return the userdata object on the stack
}

LUALIB_API int luaopen_measure_welch_anova(lua_State *L)
{
    // create metatable
    if (luaL_newmetatable(L, MEASURE_WELCH_ANOVA_MT)) {
        struct luaL_Reg mmethod[] = {
            {"__tostring", tostring_lua},
            {NULL,         NULL        }
        };
        struct luaL_Reg method[] = {
            {"fstat",  fstat_lua },
            {"df1",    df1_lua   },
            {"df2",    df2_lua   },
            {"pvalue", pvalue_lua},
            {NULL,     NULL      }
        };

        // metamethods
        for (struct luaL_Reg *ptr = mmethod; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        // methods
        lua_createtable(L, 0, 1);
        for (struct luaL_Reg *ptr = method; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        lua_setfield(L, -2, "__index");

        // Protect metatable from external access
        lua_pushliteral(L, "metatable is protected");
        lua_setfield(L, -2, "__metatable");

        lua_pop(L, 1);
    }

    lua_pushcfunction(L, welch_anova_lua);
    return 1;
}
