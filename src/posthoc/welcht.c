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

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
// lua
#include "../measure_samples.h"
#include "../stats/common.h"
#include <lauxlib.h>
#include <lua.h>

// Structure to hold sample pair comparison result
typedef struct {
    int idx1;
    int idx2;
    double t_statistic;
    double df;
    double p_value;
    double p_adjusted;
} pairwise_result_t;

// Mathematical constants for high-precision calculations
static const double FPMIN_THRESHOLD      = 1.0e-300;
static const double BETA_CONVERGENCE_EPS = 1.0e-16;
static const int BETA_MAX_ITERATIONS     = 500;

// Error message prefix for consistent error reporting
#define WELCHT_ERROR_PREFIX "welcht: "

// Compare function for sorting p-values (for Holm correction)
static int compare_pairwise_by_pvalue(const void *a, const void *b)
{
    const pairwise_result_t *res_a = (const pairwise_result_t *)a;
    const pairwise_result_t *res_b = (const pairwise_result_t *)b;

    if (res_a->p_value < res_b->p_value) {
        return -1;
    }
    if (res_a->p_value > res_b->p_value) {
        return 1;
    }
    return 0;
}

// Bernoulli coefficients for Stirling's approximation: B_n / (n * n!)
typedef struct {
    double coeff;
} bernoulli_term_t;

static const bernoulli_term_t BERNOULLI_COEFFS[] = {
    {1.0 / 12.0},          // B2/(2*2!)
    {-1.0 / 360.0},        // B4/(4*4!)
    {1.0 / 1260.0},        // B6/(6*6!)
    {-1.0 / 1680.0},       // B8/(8*8!)
    {1.0 / 1188.0},        // B10/(10*10!)
    {-691.0 / 360360.0},   // B12/(12*12!)
    {1.0 / 156.0},         // B14/(14*14!)
    {-3617.0 / 122400.0},  // B16/(16*16!)
    {43867.0 / 244188.0},  // B18/(18*18!)
    {-174611.0 / 125400.0} // B20/(20*20!)
};
static const size_t NUM_BERNOULLI_TERMS =
    sizeof(BERNOULLI_COEFFS) / sizeof(BERNOULLI_COEFFS[0]);

// High-precision log gamma using Stirling's approximation
static double log_gamma_stirling(double x)
{
    // Apply gamma recurrence relation for values < 15 (helper function inlined)
    double correction = 0.0;
    while (x < 15.0) {
        correction -= log(x);
        x += 1.0;
    }

    // Base Stirling formula: log(Γ(x)) ≈ (x-0.5)log(x) - x + 0.5*log(2π)
    double result = (x - 0.5) * log(x) - x + 0.91893853320467274178032973640562;

    // Add Bernoulli correction terms
    double x_inv       = 1.0 / x;
    double x_inv_power = x_inv;
    double x_inv2      = x_inv * x_inv;

    for (size_t i = 0; i < NUM_BERNOULLI_TERMS; i++) {
        result += BERNOULLI_COEFFS[i].coeff * x_inv_power;
        x_inv_power *= x_inv2;
    }

    return result + correction;
}

// Lentz's continued fraction algorithm for incomplete beta function
static double betacf(double a, double b, double x)
{
// Prevent underflow in continued fraction calculations (helper macro)
#define ensure_minimum_value(value)                                            \
    do {                                                                       \
        if (fabs(*(value)) < FPMIN_THRESHOLD) {                                \
            *(value) = (*(value) < 0) ? -FPMIN_THRESHOLD : FPMIN_THRESHOLD;    \
        }                                                                      \
    } while (0)

    double qab = a + b;
    double qap = a + 1.0;
    double qam = a - 1.0;

    // Initialize Lentz's algorithm
    double c = 1.0;
    double d = 1.0 - qab * x / qap;
    ensure_minimum_value(&d);
    d        = 1.0 / d;
    double h = d;

    for (int m = 1; m <= BETA_MAX_ITERATIONS; m++) {
        int m2 = 2 * m;

        // Even coefficient
        double aa = m * (b - m) * x / ((qam + m2) * (a + m2));
        d         = 1.0 + aa * d;
        ensure_minimum_value(&d);
        c = 1.0 + aa / c;
        ensure_minimum_value(&c);
        d = 1.0 / d;
        h *= d * c;

        // Odd coefficient
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
        d  = 1.0 + aa * d;
        ensure_minimum_value(&d);
        c = 1.0 + aa / c;
        ensure_minimum_value(&c);
        d          = 1.0 / d;
        double del = d * c;
        h *= del;

        // Check convergence
        if (fabs(del - 1.0) <= BETA_CONVERGENCE_EPS) {
            break;
        }
    }

#undef ensure_minimum_value
    return h;
}

// Log gamma function using direct Stirling implementation for better precision
static double log_gamma(double x)
{
    return log_gamma_stirling(x);
}

// Regularized incomplete beta function I_x(a,b)
static double betai(double a, double b, double x)
{
    if (x < 0.0 || x > 1.0) {
        return -1.0; // Invalid input
    }

    if (x == 0.0) {
        return 0.0;
    }
    if (x == 1.0) {
        return 1.0;
    }

    // Compute beta prefactor in log space for numerical stability
    double log_bt = log_gamma(a + b) - log_gamma(a) - log_gamma(b) +
                    a * log(x) + b * log(1.0 - x);

    // Choose the most numerically stable form
    if (x < (a + 1.0) / (a + b + 2.0)) {
        // Use direct form
        double bt = exp(log_bt);
        return bt * betacf(a, b, x) / a;
    } else {
        // Use complementary form for better stability
        double bt = exp(log_bt);
        return 1.0 - bt * betacf(b, a, 1.0 - x) / b;
    }
}

// Student's t-distribution cumulative distribution function
static double student_t_cdf(double t, double df)
{
    if (!isfinite(t) || !isfinite(df) || df <= 0) {
        return (t < 0) ? 0.0 : 1.0;
    }

    // For very large |t|, use asymptotic behavior
    if (fabs(t) > 100.0) {
        return (t < 0) ? 0.0 : 1.0;
    }

    // Special case for df = 1 (Cauchy distribution)
    if (fabs(df - 1.0) < 1e-15) {
        return 0.5 + atan(t) / M_PI;
    }

    // For large df, use normal approximation
    if (df > 1000.0) {
        // Standard normal CDF approximation
        double z = t;
        return 0.5 * (1.0 + erf(z / sqrt(2.0)));
    }

    // Use the relationship: T ~ t_df ⟺ T² / (df + T²) ~ Beta(1/2, df/2)
    // But implement with better numerical stability

    double t_squared = t * t;

    // For better numerical stability, use different forms based on magnitude
    double x;
    if (t_squared < df) {
        // x = t²/(df + t²)
        x = t_squared / (df + t_squared);
    } else {
        // x = 1 - df/(df + t²) for better precision when t is large
        x = 1.0 - df / (df + t_squared);
    }

    // Compute the incomplete beta function
    double p_beta = betai(0.5, df / 2.0, x);

    // Return the CDF value
    if (t >= 0.0) {
        return 0.5 + 0.5 * p_beta;
    } else {
        return 0.5 - 0.5 * p_beta;
    }
}

// Calculate two-tailed p-value from t-statistic
static double calc_two_tailed_p_value(double t, double df)
{
    if (!isfinite(t) || !isfinite(df) || df <= 0) {
        return 1.0;
    }

    double p = 2.0 * (1.0 - student_t_cdf(fabs(t), df));

    // Clamp p-value to valid [0,1] range (inlined)
    if (p < 0.0)
        p = 0.0;
    else if (p > 1.0)
        p = 1.0;

    return p;
}

// Calculate Welch's t-statistic and degrees of freedom
static void calc_welch_t_test(double mean1, double var1, size_t n1,
                              double mean2, double var2, size_t n2,
                              double *t_stat, double *df)
{
    // Calculate standard error
    double se1     = var1 / n1;
    double se2     = var2 / n2;
    double se_diff = sqrt(se1 + se2);

    // Calculate t-statistic
    if (se_diff > 0) {
        *t_stat = (mean1 - mean2) / se_diff;
    } else {
        *t_stat = 0.0;
    }

    // Calculate degrees of freedom using Welch-Satterthwaite equation
    double df_num   = (se1 + se2) * (se1 + se2);
    double df_denom = (se1 * se1) / (n1 - 1) + (se2 * se2) / (n2 - 1);

    if (df_denom > 0) {
        *df = df_num / df_denom;
    } else {
        *df = n1 + n2 - 2; // Fall back to pooled df
    }
}

// Apply Holm correction to p-values
static void apply_holm_correction(pairwise_result_t *results, int n_comparisons)
{
    // Sort by p-value
    qsort(results, n_comparisons, sizeof(pairwise_result_t),
          compare_pairwise_by_pvalue);

    // Apply Holm correction
    for (int i = 0; i < n_comparisons; i++) {
        double adjusted = results[i].p_value * (n_comparisons - i);

        // Ensure monotonicity
        if (i > 0 && adjusted < results[i - 1].p_adjusted) {
            adjusted = results[i - 1].p_adjusted;
        }

        // Cap at 1.0
        if (adjusted > 1.0) {
            adjusted = 1.0;
        }

        results[i].p_adjusted = adjusted;
    }
}

// Perform all pairwise t-tests and store results
static int perform_pairwise_tests(lua_State *L, measure_samples_t **samples,
                                  size_t n_samples, pairwise_result_t *results)
{
    int comparison_idx = 0;

    for (size_t i = 0; i < n_samples; i++) {
        for (size_t j = i + 1; j < n_samples; j++) {
            measure_samples_t *s1 = samples[i];
            measure_samples_t *s2 = samples[j];

            // Calculate sample variances
            double var1 = s1->M2 / (s1->count - 1);
            double var2 = s2->M2 / (s2->count - 1);

            // Validate variances
            if (!isfinite(var1) || var1 < 0 || !isfinite(var2) || var2 < 0) {
                return luaL_error(L,
                                  WELCHT_ERROR_PREFIX
                                  "invalid variance detected in samples %zu "
                                  "and %zu (var1=%.2e, var2=%.2e)",
                                  i + 1, j + 1, var1, var2);
            }

            // Perform Welch t-test
            double t_stat, df;
            calc_welch_t_test(s1->mean, var1, s1->count, s2->mean, var2,
                              s2->count, &t_stat, &df);

            double p_value = calc_two_tailed_p_value(t_stat, df);

            // Store result (1-based indexing for Lua)
            results[comparison_idx] = (pairwise_result_t){
                .idx1        = (int)i + 1,
                .idx2        = (int)j + 1,
                .t_statistic = t_stat,
                .df          = df,
                .p_value     = p_value,
                .p_adjusted  = p_value // Will be adjusted by Holm correction
            };
            comparison_idx++;
        }
    }
    return 0; // Success
}

// Build Lua result table from computed results
static void build_result_table(lua_State *L, pairwise_result_t *results,
                               int n_comparisons)
{
    lua_createtable(L, n_comparisons, 0);

    for (int i = 0; i < n_comparisons; i++) {
        lua_createtable(L, 0, 3);

        // Create pair field [sample1, sample2]
        lua_createtable(L, 2, 0);
        lua_rawgeti(L, 1, results[i].idx1);
        lua_rawseti(L, -2, 1);
        lua_rawgeti(L, 1, results[i].idx2);
        lua_rawseti(L, -2, 2);
        lua_setfield(L, -2, "pair");

        // Add p_value and p_adjusted fields
        lua_pushnumber(L, results[i].p_value);
        lua_setfield(L, -2, "p_value");
        lua_pushnumber(L, results[i].p_adjusted);
        lua_setfield(L, -2, "p_adjusted");

        // Add result to array
        lua_rawseti(L, -2, i + 1);
    }
}

// Validate input table and return sample count
static size_t validate_input_samples(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    size_t n_samples = lua_rawlen(L, 1);

    if (n_samples < 2) {
        luaL_error(L, WELCHT_ERROR_PREFIX "minimum 2 samples required, got %d",
                   (int)n_samples);
    }

    return n_samples;
}

// Extract and validate all samples from Lua table into provided array
static void extract_samples(lua_State *L, size_t n_samples,
                            measure_samples_t **samples)
{
    for (size_t i = 1; i <= n_samples; i++) {
        lua_rawgeti(L, 1, (lua_Integer)i); // Get sample from input table
        if (lua_isnil(L, -1)) {
            luaL_error(L, WELCHT_ERROR_PREFIX "nil value at sample index %d",
                       (int)i);
        }

        measure_samples_t *sample = luaL_checkudata(L, -1, MEASURE_SAMPLES_MT);
        if (sample->count < 2) {
            luaL_error(L,
                       WELCHT_ERROR_PREFIX
                       "sample %d contains %d values, minimum 2 required",
                       (int)i, (int)sample->count);
        }

        samples[i - 1] = sample;
        lua_pop(L, 1); // Remove sample from stack
    }
}

// Main Welch t-test function with improved structure
static int welch_t_test_lua(lua_State *L)
{
    // Step 1: Validate input
    size_t n_samples = validate_input_samples(L);

    // Step 2: Allocate samples array on stack (lightweight: 8 bytes ×
    // n_samples)
    measure_samples_t **samples =
        alloca(sizeof(measure_samples_t *) * n_samples);
    extract_samples(L, n_samples, samples);

    // Step 3: Allocate result storage
    int n_comparisons = (n_samples * (n_samples - 1)) / 2;
    pairwise_result_t *results =
        lua_newuserdata(L, sizeof(pairwise_result_t) * n_comparisons);

    // Step 4: Perform statistical calculations
    int result_code = perform_pairwise_tests(L, samples, n_samples, results);
    if (result_code != 0) {
        return result_code; // Error already reported by perform_pairwise_tests
    }
    apply_holm_correction(results, n_comparisons);

    // Step 5: Build and return Lua result table
    build_result_table(L, results, n_comparisons);
    return 1;
}

LUALIB_API int luaopen_measure_posthoc_welcht(lua_State *L)
{
    lua_pushcfunction(L, welch_t_test_lua);
    return 1;
}
