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

#include <alloca.h>
#include <stdint.h>
#include <string.h>
// lua
#include "../measure_samples.h"
#include "../stats/common.h"
#include <lauxlib.h>
#include <lua.h>

// Effect size thresholds for Cohen's d interpretation
#define COHEN_D_SMALL  0.2
#define COHEN_D_MEDIUM 0.5
#define COHEN_D_LARGE  0.8

// Structure to hold cluster information for Scott-Knott ESD
typedef struct {
    int id;          // Cluster identifier (0-based)
    size_t count;    // Number of samples in this cluster
    double mean;     // Mean of this cluster
    double variance; // Variance of this cluster
} skesd_cluster_t;

// Structure to store original sample reference (internal use)
typedef struct {
    measure_samples_t *sample;
    int idx;
} sample_ref_t;

// Structure to hold statistical calculation results
typedef struct {
    double mean;
    double variance;
    size_t count;
} statistics_result_t;

// Calculate Cohen's d effect size between two groups
static inline double calc_cohen_d(double mean1, double var1, size_t n1,
                                  double mean2, double var2, size_t n2)
{
    double combined_variance =
        ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2);
    double combined_std = sqrt(combined_variance);

    // Avoid division by zero
    if (combined_std == 0.0) {
        return 0.0;
    }

    // Cohen's d = (mean1 - mean2) / combined_std
    return fabs(mean1 - mean2) / combined_std;
}

// Compare function for sorting clusters by mean
static int compare_clusters_by_mean(const void *a, const void *b)
{
    const skesd_cluster_t *cluster_a = (const skesd_cluster_t *)a;
    const skesd_cluster_t *cluster_b = (const skesd_cluster_t *)b;

    if (cluster_a->mean < cluster_b->mean) {
        return -1;
    }
    if (cluster_a->mean > cluster_b->mean) {
        return 1;
    }
    return 0;
}

// Calculate sum of squares between clusters for partitioning
static double calc_between_clusters_ss(const skesd_cluster_t *clusters,
                                       size_t start, size_t end,
                                       size_t split_point)
{
    if (start >= end || split_point <= start || split_point >= end) {
        return 0.0;
    }

    // Calculate means for left and right partitions
    double left_sum = 0.0, right_sum = 0.0;
    size_t left_count = 0, right_count = 0;

    for (size_t i = start; i < split_point; i++) {
        left_sum += clusters[i].mean * clusters[i].count;
        left_count += clusters[i].count;
    }

    for (size_t i = split_point; i < end; i++) {
        right_sum += clusters[i].mean * clusters[i].count;
        right_count += clusters[i].count;
    }

    if (left_count == 0 || right_count == 0) {
        return 0.0;
    }

    double left_mean    = left_sum / left_count;
    double right_mean   = right_sum / right_count;
    double overall_mean = (left_sum + right_sum) / (left_count + right_count);

    // Calculate between-groups sum of squares
    double ss_between =
        left_count * (left_mean - overall_mean) * (left_mean - overall_mean) +
        right_count * (right_mean - overall_mean) * (right_mean - overall_mean);

    return ss_between;
}

// Find optimal partition point using Scott-Knott approach
static size_t find_optimal_partition(const skesd_cluster_t *clusters,
                                     size_t start, size_t end)
{
    if (end - start <= 1) {
        return start;
    }

    double max_ss     = 0.0;
    size_t best_split = start + 1;

    // Try all possible split points
    for (size_t split = start + 1; split < end; split++) {
        double ss = calc_between_clusters_ss(clusters, start, end, split);
        if (ss > max_ss) {
            max_ss     = ss;
            best_split = split;
        }
    }

    return best_split;
}

// Calculate combined statistics with flexible cluster selection
// For range: pass assignments=NULL, start/end for range
// For cluster: pass assignments with cluster_id, start=0,
// end=num_clusters
static statistics_result_t
calc_cluster_stats_flexible(const skesd_cluster_t *clusters, size_t start,
                            size_t end, const int *assignments,
                            int target_cluster_id)
{
    double sum = 0.0, sum_sq = 0.0;
    size_t count = 0;

    for (size_t i = start; i < end; i++) {
        // Include cluster if: no cluster filter OR cluster belongs to target
        // cluster
        if (assignments == NULL || assignments[i] == target_cluster_id) {
            sum += clusters[i].mean * clusters[i].count;
            sum_sq += clusters[i].variance * (clusters[i].count - 1) +
                      clusters[i].mean * clusters[i].mean * clusters[i].count;
            count += clusters[i].count;
        }
    }

    statistics_result_t result = {0.0, 0.0, 0};

    if (count == 0) {
        return result;
    }

    result.mean  = sum / count;
    result.count = count;

    // Calculate variance
    double variance = (sum_sq - sum * sum / count) / (count - 1);
    result.variance = (variance < 0) ? 0.0 : variance;

    return result;
}

// Convenience wrapper for range-based statistics
static statistics_result_t calc_combined_stats(const skesd_cluster_t *clusters,
                                               size_t start, size_t end)
{
    return calc_cluster_stats_flexible(clusters, start, end, NULL, 0);
}

// Convenience wrapper for cluster-based statistics
static statistics_result_t calc_cluster_stats(const skesd_cluster_t *clusters,
                                              const int *assignments,
                                              int num_clusters, int cluster_id)
{
    return calc_cluster_stats_flexible(clusters, 0, (size_t)num_clusters,
                                       assignments, cluster_id);
}

static int should_merge_partitions(const skesd_cluster_t *clusters,
                                   size_t start, size_t split, size_t end,
                                   double threshold)
{
    // Calculate combined statistics for left and right partitions
    statistics_result_t left_stats =
        calc_combined_stats(clusters, start, split);
    statistics_result_t right_stats = calc_combined_stats(clusters, split, end);

    if (left_stats.count == 0 || right_stats.count == 0) {
        return 1; // Merge if one partition is empty
    }

    // Calculate Cohen's d between partitions
    double cohen_d =
        calc_cohen_d(left_stats.mean, left_stats.variance, left_stats.count,
                     right_stats.mean, right_stats.variance, right_stats.count);

    // Merge if effect size is negligible
    return cohen_d < threshold;
}

// Recursive Scott-Knott ESD clustering
static void scott_knott_esd_recursive(skesd_cluster_t *clusters, size_t start,
                                      size_t end, int *assignments,
                                      int *current_cluster_id,
                                      double effect_threshold)
{
    if (end - start <= 1) {
        // Assign single cluster
        for (size_t i = start; i < end; i++) {
            assignments[clusters[i].id] = *current_cluster_id;
        }
        (*current_cluster_id)++;
        return;
    }

    // Find optimal partition
    size_t split = find_optimal_partition(clusters, start, end);

    // Check if partitions should be merged based on effect size
    if (should_merge_partitions(clusters, start, split, end,
                                effect_threshold)) {
        // Merge into single cluster
        for (size_t i = start; i < end; i++) {
            assignments[clusters[i].id] = *current_cluster_id;
        }
        (*current_cluster_id)++;
        return;
    }

    // Recursively process left and right partitions
    scott_knott_esd_recursive(clusters, start, split, assignments,
                              current_cluster_id, effect_threshold);
    scott_knott_esd_recursive(clusters, split, end, assignments,
                              current_cluster_id, effect_threshold);
}

// Extract sample clusters from Lua input and validate them
static int extract_and_validate_samples(lua_State *L, int table_index,
                                        skesd_cluster_t **clusters_ptr,
                                        sample_ref_t **samples_ptr)
{
    size_t table_len = lua_rawlen(L, table_index);
    if (table_len == 0) {
        return luaL_error(L, "empty table or hash-like tables not supported");
    }

    int num_clusters = 0;
    skesd_cluster_t *clusters =
        lua_newuserdata(L, sizeof(skesd_cluster_t) * table_len);
    sample_ref_t *samples =
        lua_newuserdata(L, sizeof(sample_ref_t) * table_len);

    for (size_t i = 1; i <= table_len; i++) {
        lua_rawgeti(L, table_index, (lua_Integer)i);
        if (lua_isnil(L, -1)) {
            lua_pop(L, 1);
            continue;
        }

        measure_samples_t *sample_data =
            luaL_checkudata(L, -1, MEASURE_SAMPLES_MT);

        // Validate sample
        if (sample_data->count < 2) {
            return luaL_error(L,
                              "each cluster must contain at least 2 samples");
        }

        // Extract statistics
        double mean     = sample_data->mean;
        double variance = sample_data->M2 / (sample_data->count - 1);

        if (!isfinite(mean) || !isfinite(variance) || variance <= 0.0) {
            return luaL_error(L, "invalid sample statistics or zero variance");
        }

        // Store cluster info
        clusters[num_clusters] = (skesd_cluster_t){.id    = (int)num_clusters,
                                                   .count = sample_data->count,
                                                   .mean  = mean,
                                                   .variance = variance};

        samples[num_clusters] = (sample_ref_t){
            .sample = sample_data,
            .idx    = (int)i,
        };

        num_clusters++;
        lua_pop(L, 1);
    }

    if (num_clusters < 2) {
        return luaL_error(
            L, "Scott-Knott ESD requires at least two clusters, got %zu",
            num_clusters);
    }

    *clusters_ptr = clusters;
    *samples_ptr  = samples;
    return num_clusters;
}

// Calculate Cohen's d for a specific cluster against all other clusters
static double calc_cohen_d_for_cluster(const skesd_cluster_t *clusters,
                                       const int *assignments, int num_samples,
                                       int num_clusters, int cluster_id,
                                       int *compare_cluster)
{
    double max_cohen_d = 0.0;
    *compare_cluster   = 0;

    for (int j = 0; j < num_clusters; j++) {
        if (cluster_id == j) {
            continue;
        }

        // Calculate combined statistics for both clusters
        statistics_result_t stats_i =
            calc_cluster_stats(clusters, assignments, num_samples, cluster_id);
        statistics_result_t stats_j =
            calc_cluster_stats(clusters, assignments, num_samples, j);

        if (stats_i.count > 0 && stats_j.count > 0) {
            double cohen_d =
                calc_cohen_d(stats_i.mean, stats_i.variance, stats_i.count,
                             stats_j.mean, stats_j.variance, stats_j.count);

            if (cohen_d > max_cohen_d) {
                max_cohen_d = cohen_d;
                // Store the actual cluster ID (1-based) of the comparison cluster
                *compare_cluster = (num_clusters > 1) ? (j + 1) : 0;
            }
        }
    }

    return max_cohen_d;
}

// Build result structure from clustering results
static int build_result_structure(lua_State *L, const skesd_cluster_t *clusters,
                                  const sample_ref_t *samples,
                                  const int *assignments, int num_samples,
                                  int num_clusters)
{
    // Track which clusters have been processed for Cohen's d calculation
    int8_t *processed = alloca(sizeof(int8_t) * num_clusters);

    memset(processed, 0, sizeof(int8_t) * num_clusters);

    // Create Lua table for result
    lua_createtable(L, num_clusters, 0);

    // Assign sample indices and calculate Cohen's d in one pass
    for (int i = 0; i < num_samples; i++) {
        int assigned_cluster = assignments[i];
        int cluster_id       = clusters[i].id;
        int cluster_number   = assigned_cluster + 1; // 1-based

        // get or create cluster in result table
        lua_rawgeti(L, -1, cluster_number);
        if (lua_isnil(L, -1)) {
            // Create new cluster entry
            lua_pop(L, 1);            // Pop nil
            lua_createtable(L, 0, 4); // Create new cluster table
            lua_pushvalue(L, -1); // Duplicate cluster table for setting fields
            lua_rawseti(L, -3,
                        cluster_number); // Set cluster table in result

            // id field
            lua_pushinteger(L, cluster_number);
            lua_setfield(L, -2, "id");

            // samples field
            lua_createtable(L, 0, 0);
            lua_setfield(L, -2, "samples");
        }

        // Calculate Cohen's d and statistics if not yet processed for this
        // cluster
        if (!processed[assigned_cluster]) {
            int compare_cluster = 0;
            double cohen_d      = calc_cohen_d_for_cluster(
                clusters, assignments, num_samples, num_clusters,
                assigned_cluster, &compare_cluster);
            processed[assigned_cluster] = 1;

            // Calculate cluster statistics
            statistics_result_t stats = calc_cluster_stats(
                clusters, assignments, num_samples, assigned_cluster);

            // mean field
            lua_pushnumber(L, stats.mean);
            lua_setfield(L, -2, "mean");

            // variance field
            lua_pushnumber(L, stats.variance);
            lua_setfield(L, -2, "variance");

            // count field (number of samples in cluster)
            lua_pushinteger(L, (lua_Integer)stats.count);
            lua_setfield(L, -2, "count");

            // max_contrast_with field
            if (compare_cluster > 0) {
                lua_pushinteger(L, compare_cluster);
            } else {
                lua_pushnil(L);
            }
            lua_setfield(L, -2, "max_contrast_with");

            // cohen_d field
            lua_pushnumber(L, cohen_d);
            lua_setfield(L, -2, "cohen_d");
        }

        // Add original sample from input table to samples table
        lua_getfield(L, -1, "samples");
        lua_rawgeti(L, 1, samples[cluster_id].idx);
        lua_rawseti(L, -2, lua_rawlen(L, -2) + 1);

        // Pop the samples table and cluster table
        lua_pop(L, 2);
    }

    return 1; // Return the result table on the stack
}

// Main Scott-Knott ESD function with simplified API
static int scott_knott_esd_lua(lua_State *L)
{
    // 1. Parse inputs
    luaL_checktype(L, 1, LUA_TTABLE);
    double effect_threshold = COHEN_D_MEDIUM;
    if (!lua_isnoneornil(L, 2)) {
        luaL_checktype(L, 2, LUA_TNUMBER);
        effect_threshold = lua_tonumber(L, 2);
        if (effect_threshold <= 0.0) {
            return luaL_error(L, "effect size threshold must be positive");
        }
    }

    // 2. Extract and validate samples
    skesd_cluster_t *clusters = NULL;
    sample_ref_t *samples     = NULL;
    int num_samples = extract_and_validate_samples(L, 1, &clusters, &samples);

    // 3. Perform Scott-Knott clustering
    qsort(clusters, (size_t)num_samples, sizeof(skesd_cluster_t),
          compare_clusters_by_mean);

    int *assignments = alloca(sizeof(int) * (size_t)num_samples);
    for (int i = 0; i < num_samples; i++) {
        assignments[i] = -1; // Use -1 as invalid marker
    }

    int num_clusters = 0;
    scott_knott_esd_recursive(clusters, 0, (size_t)num_samples, assignments,
                              &num_clusters, effect_threshold);

    // 4. Build result structure
    return build_result_structure(L, clusters, samples, assignments,
                                  num_samples, num_clusters);
}

LUALIB_API int luaopen_measure_posthoc_skesd(lua_State *L)
{
    lua_pushcfunction(L, scott_knott_esd_lua);
    return 1;
}
