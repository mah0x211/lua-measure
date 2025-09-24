--
-- Copyright (C) 2025 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--
-- compare/skesd.lua: Scott-Knott ESD comparison
-- Handles conversion and analysis of Scott-Knott ESD results
-- Performance optimizations: localize frequently used functions
local ipairs = ipairs
local abs = math.abs
-- Load required modules
local skesd = require('measure.posthoc.skesd')
local welcht = require('measure.posthoc.welcht')
local merge_samples = require('measure.samples').merge

--- Convert Scott-Knott ESD cluster results into standardized group format
--- @param skesd_results table Results from measure.posthoc.skesd clustering
--- @return table groups Array of cluster groups with statistical ranks
local function create_skesd_groups(skesd_results)
    local groups = {}

    -- Transform Scott-Knott ESD cluster results into standardized group format
    for rank, cluster in ipairs(skesd_results) do
        local group_names = {}
        -- Extract sample names from each cluster
        for _, sample in ipairs(cluster.samples) do
            group_names[#group_names + 1] = sample:name()
        end
        groups[#groups + 1] = {
            names = group_names,
            rank = rank,
            mean = cluster.mean,
            cohen_d = cluster.cohen_d,
            id = cluster.id,
        }
    end

    return groups
end

--- Generate statistically rigorous pairwise comparisons between Scott-Knott ESD clusters
--- Uses Welch's t-test on cluster aggregate data for actual statistical significance testing
--- @param skesd_results table Results from measure.posthoc.skesd clustering
--- @return table comparisons Array of pairwise comparisons between clusters
local function create_skesd_comparisons(skesd_results)
    local comparisons = {}

    -- Guard against single cluster case (no comparisons needed)
    if #skesd_results <= 1 then
        return comparisons
    end

    -- Create aggregate samples representing each cluster
    local cluster_samples = {}
    for i, cluster in ipairs(skesd_results) do
        --- Create aggregate sample representing each cluster for Welch's t-test
        --- Combines all samples in a cluster into a single representative sample
        cluster_samples[i] = #cluster.samples == 1 and cluster.samples[1] or
                                 merge_samples('merged_samples', cluster.samples)
    end

    -- Perform Welch's t-test on cluster aggregates
    local welcht_results = welcht(cluster_samples)

    -- Convert Welch's t-test results to cluster comparison format
    for _, result in ipairs(welcht_results) do
        local sample1 = result.pair[1]
        local sample2 = result.pair[2]

        -- Find corresponding clusters for these samples
        local cluster1_idx, cluster2_idx = nil, nil
        for i, samples in ipairs(cluster_samples) do
            if samples == sample1 then
                cluster1_idx = i
            elseif samples == sample2 then
                cluster2_idx = i
            end
        end

        if cluster1_idx and cluster2_idx then
            local cluster1 = skesd_results[cluster1_idx]
            local cluster2 = skesd_results[cluster2_idx]

            -- Calculate performance metrics using cluster means
            local mean1 = cluster1.mean
            local mean2 = cluster2.mean
            local speedup = mean2 > 0 and (mean1 / mean2) or 0
            local difference = mean1 - mean2
            local relative_difference = mean2 > 0 and
                                            (abs(difference) / mean2 * 100) or 0

            -- Categorize statistical significance
            local significance_level = nil
            if result.p_value < 0.001 then
                significance_level = 'p<0.001'
            elseif result.p_value < 0.01 then
                significance_level = 'p<0.01'
            elseif result.p_value < 0.05 then
                significance_level = 'p<0.05'
            end

            comparisons[#comparisons + 1] = {
                name1 = 'Cluster ' .. cluster1.id,
                name2 = 'Cluster ' .. cluster2.id,
                speedup = speedup,
                difference = difference,
                relative_difference = relative_difference,
                p_value = result.p_value,
                p_adjusted = result.p_adjusted,
                significant = result.p_value < 0.05,
                significance_level = significance_level,
                sample_sizes = {
                    cluster1.count,
                    cluster2.count,
                },
            }
        end
    end

    return comparisons
end

--- Analyze samples using Scott-Knott ESD algorithm
--- Performs hierarchical clustering based on effect size differences
--- with statistical significance testing for multiple groups
--- @param samples_list table Array of measure.samples objects to cluster
--- @return table result Complete comparison result with method, pairs, and groups
local function scott_knott_esd(samples_list)
    local skesd_results = skesd(samples_list)
    local groups = create_skesd_groups(skesd_results)
    local comparisons = create_skesd_comparisons(skesd_results)

    return {
        method = {
            name = "Scott-Knott ESD (Effect Size Difference) clustering",
            algorithm = 'scott-knott-esd',
            description = "Statistically similar groups are identified to avoid the multiple comparison problem with large numbers of sample groups",
            clustering = "hierarchical clustering based on effect size differences",
        },
        pairs = comparisons,
        groups = groups,
    }
end

return scott_knott_esd
