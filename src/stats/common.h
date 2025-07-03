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

#ifndef measure_stats_common_h
#define measure_stats_common_h

#include "../measure_samples.h"
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Constants for statistical calculations
#define STATS_EPSILON 1e-15

// Confidence levels
#define CONFIDENCE_LEVEL_90 0.90 // 90% confidence
#define CONFIDENCE_LEVEL_95 0.95 // 95% confidence
#define CONFIDENCE_LEVEL_99 0.99 // 99% confidence

// Standard percentiles
#define PERCENTILE_25 25.0 // First quartile
#define PERCENTILE_50 50.0 // Median
#define PERCENTILE_75 75.0 // Third quartile

// Minimum sample requirements
// Minimum for trend analysis
#define MIN_SAMPLES_TREND_ANALYSIS    3
// Minimum for outlier detection (Tukey)
#define MIN_SAMPLES_OUTLIER_DETECTION 4
// Minimum for MAD outlier detection
#define MIN_SAMPLES_MAD_OUTLIER       3

// T-distribution critical values for common confidence levels
// Indexed by degrees of freedom (df = n - 1)
// For df >= 30, use normal distribution approximation
static const struct {
    double df;
    double t_90; // 90% confidence
    double t_95; // 95% confidence
    double t_99; // 99% confidence
} t_table[] = {
    {1,  6.314, 12.706, 63.657},
    {2,  2.920, 4.303,  9.925 },
    {3,  2.353, 3.182,  5.841 },
    {4,  2.132, 2.776,  4.604 },
    {5,  2.015, 2.571,  4.032 },
    {6,  1.943, 2.447,  3.707 },
    {7,  1.895, 2.365,  3.499 },
    {8,  1.860, 2.306,  3.355 },
    {9,  1.833, 2.262,  3.250 },
    {10, 1.812, 2.228,  3.169 },
    {11, 1.796, 2.201,  3.106 },
    {12, 1.782, 2.179,  3.055 },
    {13, 1.771, 2.160,  3.012 },
    {14, 1.761, 2.145,  2.977 },
    {15, 1.753, 2.131,  2.947 },
    {16, 1.746, 2.120,  2.921 },
    {17, 1.740, 2.110,  2.898 },
    {18, 1.734, 2.101,  2.878 },
    {19, 1.729, 2.093,  2.861 },
    {20, 1.725, 2.086,  2.845 },
    {21, 1.721, 2.080,  2.831 },
    {22, 1.717, 2.074,  2.819 },
    {23, 1.714, 2.069,  2.807 },
    {24, 1.711, 2.064,  2.797 },
    {25, 1.708, 2.060,  2.787 },
    {26, 1.706, 2.056,  2.779 },
    {27, 1.703, 2.052,  2.771 },
    {28, 1.701, 2.048,  2.763 },
    {29, 1.699, 2.045,  2.756 },
    {30, 1.697, 2.042,  2.750 }
};

// Helper function to get t-value for given confidence level and degrees of
// freedom
static inline double get_t_value(size_t df, double confidence_level)
{
    // For large samples (df >= 30), use normal distribution approximation
    if (df >= 30) {
        if (confidence_level >= CONFIDENCE_LEVEL_99) {
            return 2.576;
        }
        if (confidence_level >= CONFIDENCE_LEVEL_95) {
            return 1.96;
        }
        if (confidence_level >= CONFIDENCE_LEVEL_90) {
            return 1.645;
        }
        return 1.0;
    }

    // Use t-table for small samples
    if (df == 0) {
        df = 1; // Minimum df = 1
    }
    if (df > 30) {
        df = 30; // Cap at 30
    }

    size_t idx = df - 1;
    if (confidence_level >= CONFIDENCE_LEVEL_99) {
        return t_table[idx].t_99;
    }
    if (confidence_level >= CONFIDENCE_LEVEL_95) {
        return t_table[idx].t_95;
    }
    if (confidence_level >= CONFIDENCE_LEVEL_90) {
        return t_table[idx].t_90;
    }

    // For other confidence levels, interpolate between 90% and 95%
    if (confidence_level > CONFIDENCE_LEVEL_90 &&
        confidence_level < CONFIDENCE_LEVEL_95) {
        double t90   = t_table[idx].t_90;
        double t95   = t_table[idx].t_95;
        double ratio = (confidence_level - CONFIDENCE_LEVEL_90) /
                       (CONFIDENCE_LEVEL_95 - CONFIDENCE_LEVEL_90);
        return t90 + ratio * (t95 - t90);
    }

    return t_table[idx].t_90; // Default to 90%
}

// Helper function to validate samples data
static inline int validate_samples(const measure_samples_t *samples)
{
    if (!samples || !samples->data) {
        return 0;
    }

    // Check for negative time values
    for (size_t i = 0; i < samples->count; i++) {
        if (samples->data[i].time_ns < 0) {
            return 0;
        }
    }

    return 1;
}

// Helper function to check if a double value is valid (not NaN or Inf)
static inline int is_valid_number(double value)
{
    return isfinite(value);
}

// Helper function to validate percentile (0 <= p <= 100)
static inline int validate_percentile(double p)
{
    return p >= 0.0 && p <= 100.0;
}

// Helper function to validate positive number
static inline int validate_positive_number(double value)
{
    return value > 0.0 && is_valid_number(value);
}

// Safe mean calculation with overflow protection
// NOTE: Assumes input has already been validated
static inline double stats_mean(const measure_samples_t *samples)
{
    if (samples->count == 0) {
        return NAN;
    }

    uint64_t sum = 0;

    for (size_t i = 0; i < samples->count; i++) {
        uint64_t value = samples->data[i].time_ns;

        // Check for overflow: sum + value > UINT64_MAX
        if (sum > UINT64_MAX - value) {
            return NAN; // Return NaN on overflow
        }

        sum += value;
    }

    return (double)sum / (double)samples->count;
}

// Helper function to compare doubles for qsort
static inline int compare_double(const void *a, const void *b)
{
    double da = *(const double *)a;
    double db = *(const double *)b;
    if (da < db) {
        return -1;
    }
    if (da > db) {
        return 1;
    }
    return 0;
}

// Helper function to compare uint64_t for qsort
static inline int compare_uint64(const void *a, const void *b)
{
    uint64_t ua = *(const uint64_t *)a;
    uint64_t ub = *(const uint64_t *)b;
    if (ua < ub) {
        return -1;
    }
    if (ua > ub) {
        return 1;
    }
    return 0;
}

// Helper function to copy and sort time data as uint64_t (more efficient)
// NOTE: Assumes input has already been validated
static inline uint64_t *
copy_and_sort_time_data(const measure_samples_t *samples)
{
    uint64_t *sorted = malloc(samples->count * sizeof(uint64_t));
    if (!sorted) {
        return NULL;
    }

    for (size_t i = 0; i < samples->count; i++) {
        sorted[i] = samples->data[i].time_ns;
    }

    qsort(sorted, samples->count, sizeof(uint64_t), compare_uint64);
    return sorted;
}

// Helper function to calculate percentile from sorted uint64_t data
static inline double stats_percentile_from_sorted(const uint64_t *sorted,
                                                  size_t count, double p)
{
    if (!sorted || count == 0 || p < 0.0 || p > 100.0) {
        return NAN;
    }

    double index = (p / 100.0) * (count - 1);
    size_t lower = (size_t)floor(index);
    size_t upper = (size_t)ceil(index);

    if (lower == upper) {
        return (double)sorted[lower];
    } else {
        double weight = index - lower;
        return (double)sorted[lower] * (1.0 - weight) +
               (double)sorted[upper] * weight;
    }
}

// Calculate minimum value of samples
// NOTE: Assumes input has already been validated
static inline uint64_t stats_min(const measure_samples_t *samples)
{
    if (samples->count == 0) {
        return 0; // Return 0 for empty data, caller should check with is_valid_number()
    }

    uint64_t min_val = samples->data[0].time_ns;

    for (size_t i = 1; i < samples->count; i++) {
        uint64_t val = samples->data[i].time_ns;
        if (val < min_val) {
            min_val = val;
        }
    }
    return min_val;
}

// Calculate maximum value of samples
// NOTE: Assumes input has already been validated
static inline uint64_t stats_max(const measure_samples_t *samples)
{
    if (samples->count == 0) {
        return 0; // Return 0 for empty data, caller should check count and return NaN
    }

    uint64_t max_val = samples->data[0].time_ns;

    for (size_t i = 1; i < samples->count; i++) {
        uint64_t val = samples->data[i].time_ns;
        if (val > max_val) {
            max_val = val;
        }
    }
    return max_val;
}

// Calculate percentile of samples
// NOTE: Assumes input has already been validated
static inline double stats_percentile(const measure_samples_t *samples,
                                      double p)
{
    if (!validate_percentile(p)) {
        return NAN;
    }

    uint64_t *sorted = copy_and_sort_time_data(samples);
    if (!sorted) {
        return NAN;
    }

    double result = stats_percentile_from_sorted(sorted, samples->count, p);
    free(sorted);
    return is_valid_number(result) ? result : NAN;
}

// Calculate Median Absolute Deviation (MAD)
// NOTE: Assumes input has already been validated
static inline double stats_mad(const measure_samples_t *samples)
{
    double median = stats_percentile(samples, PERCENTILE_50);
    if (!is_valid_number(median)) {
        return NAN;
    }

    // Calculate absolute deviations from median
    double *deviations = malloc(samples->count * sizeof(double));
    if (!deviations) {
        return NAN;
    }

    for (size_t i = 0; i < samples->count; i++) {
        double value  = (double)samples->data[i].time_ns;
        deviations[i] = fabs(value - median);
    }

    // Sort deviations and find median
    qsort(deviations, samples->count, sizeof(double), compare_double);

    double mad;
    if (samples->count % 2 == 0) {
        // Even number of elements
        size_t mid1 = samples->count / 2 - 1;
        size_t mid2 = samples->count / 2;
        mad         = (deviations[mid1] + deviations[mid2]) / 2.0;
    } else {
        // Odd number of elements
        size_t mid = samples->count / 2;
        mad        = deviations[mid];
    }

    free(deviations);
    return is_valid_number(mad) ? mad : NAN;
}

// Calculate variance of samples with Kahan summation for numerical stability
// NOTE: Assumes input has already been validated
static inline double stats_variance(const measure_samples_t *samples)
{
    if (samples->count == 1) {
        return 0.0;
    }

    if (samples->count < 2) {
        return NAN;
    }

    double mean = stats_mean(samples);
    if (!is_valid_number(mean)) {
        return NAN;
    }

    double sum_sq_diff  = 0.0;
    double compensation = 0.0;

    for (size_t i = 0; i < samples->count; i++) {
        double value   = (double)samples->data[i].time_ns;
        double diff    = value - mean;
        double sq_diff = diff * diff;

        // Kahan summation for numerical stability
        double y     = sq_diff - compensation;
        double t     = sum_sq_diff + y;
        compensation = (t - sum_sq_diff) - y;
        sum_sq_diff  = t;
    }

    return sum_sq_diff / (samples->count - 1);
}

#endif // measure_stats_common_h
