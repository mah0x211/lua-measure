--
-- Copyright (C) 2025 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- report.lua: Benchmark result reporting module
-- Provides high-quality output formatting similar to Criterion.rs and BenchmarkDotNet
local format = string.format
local concat = table.concat
local sort = table.sort
local stats_summary = require('measure.stats.summary')
local compare_samples = require('measure.compare')
local table_utils = require('measure.report.table')
local fmt = require('measure.report.format')
local print = require('measure.print')
local report_sysinfo = require('measure.report.sysinfo')

--- @class measure.report
--- @field protected sysinfo table System information key-value pairs
--- @field protected samples_list measure.samples[] List of samples to report on
--- @field protected summaries measure.stat.summary[] List of statistical summaries
--- @field protected comparisons measure.compare.result Result of sample comparisons
local Report = {}
Report.__index = Report

--- Create or get existing statistical summaries
--- @return measure.stat.summary[] List of statistical summaries
function Report:get_summaries()
    local summaries = self.summaries
    if not summaries then
        summaries = {}
        for _, samples in ipairs(self.samples_list) do
            summaries[#summaries + 1] = stats_summary(samples)
        end
        self.summaries = summaries
    end
    return summaries
end

--- Create or get existing comparison results
--- @return measure.compare.result comparison
function Report:get_comparisons()
    local comparisons = self.comparisons
    if not comparisons then
        comparisons = compare_samples(self.samples_list)
        self.comparisons = comparisons
    end
    return comparisons
end

-- Print sampling details (without ranking, focused on technical details)
function Report:sampling_details()
    -- Create table directly with new interface
    local tbl = table_utils.new_table("Sampling Details", nil)

    -- Add columns
    tbl:add_column("Name") -- Text column
    tbl:add_column("Samples", true) -- Numeric column
    tbl:add_column("Outliers") -- Text column (contains parentheses)
    tbl:add_column("Conf Level", true) -- Numeric column
    tbl:add_column("Target RCIW", true) -- Numeric column
    tbl:add_column("GC Mode") -- Text column

    -- Add data rows directly
    local summaries = self:get_summaries()
    for _, summary in ipairs(summaries) do
        tbl:add_rows({
            summary.name,
            tostring(summary.sample_count),
            format("%d (%.1f%%)", summary.outliers.total,
                   summary.outliers.percentage),
            format("%.1f%%", summary.cl),
            format("%.1f%%", summary.target_rciw),
            fmt.gc_step(summary.gc_step),
        })
    end

    print(concat(tbl:render(), '\n'))
end

-- Print detailed memory analysis table
function Report:memory_analysis()
    -- Create table directly with new interface
    local tbl = table_utils.new_table("Memory Analysis",
                                      "Note: Sorted by Alloc/Op (lower is better).")

    -- Add columns
    tbl:add_column("Name")
    tbl:add_column("Samples", true)
    tbl:add_column("Max Alloc/Op", true)
    tbl:add_column("Alloc/Op", true)
    tbl:add_column("Rel.")
    tbl:add_column("Peak Memory", true)
    tbl:add_column("Uncollected", true)
    tbl:add_column("Avg Incr.", true)

    -- Sort samples by allocation rate (descending)
    local summaries = self:get_summaries()
    sort(summaries, function(a, b)
        return a.memstat.alloc_op < b.memstat.alloc_op
    end)

    -- Add data rows directly using sorted samples
    local baseline_alloc_op = summaries[1].memstat.alloc_op
    for rank, summary in ipairs(summaries) do
        local memstat = summary.memstat

        -- Calculate relative memory usage
        local relative = "1.0x"
        if rank > 1 and baseline_alloc_op > 0 then
            local ratio = memstat.alloc_op / baseline_alloc_op
            relative = format("%.1fx", ratio)
        end

        tbl:add_rows({
            summary.name,
            tostring(summary.sample_count),
            fmt.memory(memstat.max_alloc_op) .. '/op',
            fmt.memory(memstat.alloc_op) .. "/op",
            relative,
            fmt.memory(memstat.peak_memory),
            fmt.memory(memstat.uncollected),
            fmt.memory(memstat.avg_incr),
        })
    end

    print(concat(tbl:render(), '\n'))
end

-- Print measurement reliability analysis (sorted by reliability/precision)
function Report:reliability_analysis()
    -- Create table directly with new interface
    local tbl = table_utils.new_table("Measurement Reliability Analysis",
                                      "Note: Sorted by measurement precision (lower RCIW = more reliable)")

    -- Add columns
    tbl:add_column("Name") -- Text column
    tbl:add_column("CI Level") -- Text column (contains formatting)
    tbl:add_column("CI Width", true) -- Numeric column (time values)
    tbl:add_column("RCIW", true) -- Numeric column (percentage)
    tbl:add_column("Quality") -- Text column

    -- Create a list of samples with their RCIW for sorting
    local summaries = self:get_summaries()
    -- Sort by RCIW (lower is better = more reliable)
    sort(summaries, function(a, b)
        return a.rciw < b.rciw
    end)

    -- Add data rows directly
    for _, summary in ipairs(summaries) do
        tbl:add_rows({
            summary.name,
            format("%d%% [%s - %s]", summary.ci_level,
                   fmt.time(summary.ci_lower), fmt.time(summary.ci_upper)),
            fmt.time(summary.ci_width),
            format("%.1f%%", summary.rciw),
            summary.quality,
        })
    end

    print(concat(tbl:render(), '\n'))
end

--- Calculate relative performance vs baseline
--- @param baseline number Baseline value
--- @param target? number Target values (optional)
local function calc_relative_performance(baseline, target)
    assert(type(baseline) == "number", "Error: baseline must be a number")
    assert(type(target) == "number" or target == nil,
           "Error: target must be a number or nil")

    if not target then
        return "baseline"
    end

    local ratio = target / baseline
    if ratio > 1 then
        return format("%.1fx slower (%.1f%%)", ratio, (ratio - 1) * 100)
    end
    return format("%.1fx faster (%.1f%%)", 1 / ratio, (1 - ratio) * 100)
end

-- Print performance ranking table (sorted by mean execution time)
function Report:performance_analysis()
    -- Create table directly with new interface
    local tbl = table_utils.new_table("Performance Analysis",
                                      "Note: Sorted by mean execution time (lower is better).")

    -- Add columns
    tbl:add_column("Name")
    tbl:add_column("Ops/sec", true)
    tbl:add_column("Mean", true)
    tbl:add_column("p50", true)
    tbl:add_column("p95", true)
    tbl:add_column("p99", true)
    tbl:add_column("StdDev", true)
    tbl:add_column("Relative")

    local summaries = self:get_summaries()
    -- Sort by mean time (lower is better)
    sort(summaries, function(a, b)
        return a.mean < b.mean
    end)

    -- Add data rows using simple time-based ranking
    local baseline = summaries[1]
    for _, summary in ipairs(summaries) do
        tbl:add_rows({
            summary.name,
            fmt.throughput(summary.throughput),
            fmt.time(summary.mean),
            fmt.time(summary.median),
            fmt.time(summary.p95),
            fmt.time(summary.p99),
            fmt.time(summary.stddev),
            calc_relative_performance(baseline.mean, summary.mean),
        })
    end

    print(concat(tbl:render(), '\n'))
end

local PRINTABLE_CLUSTER = {
    ['welch-t-test-holm-correction'] = true,
    ['scott-knott-esd'] = true,
}

-- Print clustering analysis and performance ranking
function Report:cluster_analysis()
    local comparison = self:get_comparisons()
    if #comparison.groups < 2 then
        return
    end

    local alg = comparison.algorithm
    if PRINTABLE_CLUSTER[alg] then
        if alg == "scott-knott-esd" then
            self:cluster_analysis_skesd()
        else
            self:cluster_analysis_welcht()
        end
    end
end

-- Print statistical method information and clustering details
local function print_clustering_details(report)
    local samples_list = report.samples_list
    local comparison = report:get_comparisons()

    print("## Clustering Analysis Details")
    print.line()
    print("- Method: %s", comparison.name)
    print("- Groups: %d sample groups clustered into %d statistical groups",
          #samples_list, comparison.groups and #comparison.groups or 0)
    print("- Interpretation: %s", comparison.description)
    if comparison.clustering then
        print("- Clustering: %s", comparison.clustering)
    end

    print.line()
    local alg = comparison.algorithm
    if alg == "scott-knott-esd" then
        print("Cluster Legend:")
        print(
            "  C1, C2, ... = Statistical cluster ID (preserves original clustering result)")
        print(
            "  (n) = Number of statistically equivalent sample groups in cluster")
        print("  unique = Significantly different from all other sample groups")
        print("  name +n = Statistically equivalent to 'name' and n others")
    elseif alg == "single-sample" then
        print("Statistical Comparison Legend:")
        print("  Only one sample provided; no pairwise comparisons available.")
        print("  Rankings are based solely on measured mean execution time.")
    else
        print("Statistical Comparison Legend:")
        print(
            "  vs Baseline = Statistical significance compared to fastest sample group")
        print(
            "  vs Others = Number of significant pairwise comparisons (x/y sig)")
        print(
            "  Effect = Practical significance (small/medium/large difference)")
        print(
            "  [x] (p<0.xxx) = Statistically significant with Holm-corrected p-value")
    end
end

-- Print performance ranking table with Scott-Knott ESD clustering
function Report:cluster_analysis_skesd()
    local comparison = self:get_comparisons()
    if #comparison.groups < 2 then
        -- No clustering occurred; fallback to Welch's t-test report
        return
    end

    print_clustering_details(self)

    local summaries = self:get_summaries()
    -- Sort by mean time (lower is better)
    sort(summaries, function(a, b)
        return a.mean < b.mean
    end)

    local baseline = summaries[1]
    local baseline_group = comparison.groups[baseline.name]
    local tbl = table_utils.new_table("Statistical Clustering Analysis",
                                      "Note: Samples in same cluster are statistically equivalent")
    -- Add columns
    tbl:add_column("Cluster")
    tbl:add_column("Name")
    tbl:add_column("Mean", true)
    tbl:add_column("#Merged Samples", true) -- Merged sample size for cluster comparison
    tbl:add_column("Significance")
    tbl:add_column("Cohen's d") -- Scott-Knott ESD specific: effect size

    -- Add data rows
    for rank, summary in ipairs(summaries) do
        local name = summary.name
        local sample_group = comparison.groups[name]

        -- Format cluster display
        local cluster_display = format("C%d",
                                       sample_group.rank or sample_group.id)
        if #sample_group.names > 1 then
            cluster_display = format("C%d (%d)",
                                     sample_group.rank or sample_group.id,
                                     #sample_group.names)
        end

        -- Calculate statistics vs baseline
        local significant = "-"

        if rank > 1 and baseline_group and sample_group then
            if baseline_group.id == sample_group.id then
                -- Same cluster, statistically equivalent
                significant = "[ ]"
            else
                -- Different clusters, check for significance
                local cluster_name1 = "Cluster " .. baseline_group.id
                local cluster_name2 = "Cluster " .. sample_group.id
                local comp = comparison.pairs[cluster_name1][cluster_name2]

                if comp.significant then
                    significant = "[x] (" ..
                                      (comp.significance_level or "p<0.05") ..
                                      ")"
                else
                    significant = "[ ]"
                end
            end
        end

        tbl:add_rows({
            cluster_display,
            name,
            fmt.time(summary.mean),
            format("%d", sample_group.count or 0),
            significant,
            format("%.2f", sample_group.cohen_d or 0),
        })
    end

    print(concat(tbl:render(), '\n'))
    print.line()
end

-- Print pairwise statistical comparison table with Welch's t-test
function Report:cluster_analysis_welcht()
    local comparison = self:get_comparisons()
    if #comparison.groups < 2 then
        -- No clustering occurred; fallback to Welch's t-test report
        return
    end
    local summaries = self:get_summaries()
    -- Sort by mean time (lower is better)
    sort(summaries, function(a, b)
        return a.mean < b.mean
    end)
    local baseline = summaries[1]

    local tbl = table_utils.new_table(
                    "Pairwise Statistical Comparisons (Welch's t-test)",
                    "Note: Each sample compared against every other sample with Holm multiple testing correction")
    -- Add columns (matching skesd structure, with welcht-specific column)
    tbl:add_column("Cluster")
    tbl:add_column("Name")
    tbl:add_column("Mean", true)
    tbl:add_column("#Samples", true) -- Individual sample size
    tbl:add_column("Significance")
    tbl:add_column("p-adj (Holm)") -- Welch's t-test specific: Holm-corrected p-value

    -- Add data rows
    for rank, summary in ipairs(summaries) do
        local name = summary.name
        local sample_group = comparison.groups[name]

        -- Format cluster display (for Welch's t-test, this shows statistical equivalence groups)
        local cluster_display = format("G%d", sample_group.rank)
        if #sample_group.names > 1 then
            cluster_display = format("G%d (%d)", sample_group.rank,
                                     #sample_group.names)
        end

        local p_adjusted_display = "-"
        local significant = "-"
        if rank > 1 then
            -- Get pairwise comparison using O(1) access
            local comp = comparison.pairs[baseline.name][name]

            p_adjusted_display = format("%.3f", comp.p_adjusted)
            if comp.significant then
                significant =
                    "[x] (" .. (comp.significance_level or "p<0.05") .. ")"
            else
                significant = "[ ]"
            end
        end

        -- Get sample size
        local sample_size = format("%d", summary.sample_count or 0)
        tbl:add_rows({
            cluster_display,
            name,
            fmt.time(summary.mean),
            sample_size,
            significant,
            p_adjusted_display,
        })
    end

    print(concat(tbl:render(), '\n'))
    print.line()
end

--- Create a new Report instance
--- @param samples_list measure.samples[] List of samples to include in the report
local function new(samples_list)
    -- Validate input
    if not samples_list or type(samples_list) ~= "table" or #samples_list < 1 then
        error("Error: At least one sample required for comparison", 2)
    end

    local self = setmetatable({
        samples_list = samples_list,
        sysinfo = report_sysinfo(),
    }, Report)
    return self
end

return new
