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
local select = select
local tostring = tostring
local type = type
local print = print
local find = string.find
local format = string.format
local concat = table.concat
local sort = table.sort
local stats_summary = require('measure.stats.summary')
local compare_samples = require('measure.compare')
local new_table = require('measure.report.table')
local fmt = require('measure.report.format')
local report_sysinfo = require('measure.report.sysinfo')

--- Format a string or arguments for printing
--- @param v any First argument - if string with format specifiers, used as format string
--- @param ... any Additional arguments for formatting or direct printing
--- @return string Formatted string if format specifiers used, else nil
local function vformat(v, ...)
    if type(v) == 'string' and select('#', ...) > 0 and find(v, '%%') then
        -- Format string with arguments (only if format specifiers found)
        return format(v, ...)
    end

    -- No formatting, convert all args to strings and concatenate with spaces
    local args = {
        v,
        ...,
    }
    for i = 1, select('#', v, ...) do
        args[i] = tostring(args[i])
    end
    return concat(args, ' ')
end

--- @class measure.report
--- @field protected sysinfo table System information key-value pairs
--- @field protected samples_list measure.samples[] List of samples to report on
--- @field protected baseline_summary measure.stat.summary Optional baseline summary
--- @field protected summaries measure.stat.summary[] List of statistical summaries
--- @field protected comparisons measure.compare.result Result of sample comparisons
--- @field protected file? file* Optional file handle for output (defaults to stdout)
--- @field protected tee boolean If true, also print to stdout when file is given
local Report = {}
Report.__index = Report

--- Print to file and/or stdout based on configuration
--- @param ... any Arguments to print
function Report:print(...)
    local s = vformat(...)
    print(s)
end

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
        -- First summary is the baseline for relative values
        self.baseline_summary = summaries[1]
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
    local tbl = new_table()
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
            format("%d (%.1f%%)", summary.outliers.count,
                   summary.outliers.percentage),
            format("%.1f%%", summary.cl),
            format("%.1f%%", summary.target_rciw),
            fmt.gc_step(summary.gc_step),
        })
    end

    -- Render and print table
    self:print([[
### Sampling Details
]])
    self:print(concat(tbl:render(), '\n'))
end

--- Calculate relative value vs baseline
--- @param baseline number Baseline value
--- @param target? number Target values (optional)
--- @param modifier? table Optional modifier for relative value (e.g. "faster", "slower")
--- @return string relative string (e.g. "1.23x faster" or "baseline")
local function calc_relative_value(baseline, target, modifier)
    assert(type(baseline) == "number", "Error: baseline must be a number")
    assert(type(target) == "number", "Error: target must be a number")
    assert(type(modifier) == "table", "Error: modifier must be a table")

    -- Validate modifier keys and ensure they are strings
    assert(type(modifier.greater) == "string",
           "Error: modifier.greater must be a string")
    assert(type(modifier.less) == "string",
           "Error: modifier.less must be a string")
    assert(type(modifier.equal) == "string",
           "Error: modifier.equal must be a string")

    if target == baseline then
        return modifier.equal
    elseif target > baseline then
        return format("%.3fx %s", target / baseline, modifier.greater)
    end
    return format("%.3fx %s", 1 / (target / baseline), modifier.less)
end

-- Print detailed memory analysis table
function Report:memory_analysis()
    local tbl = new_table()
    tbl:add_column("Name")
    tbl:add_column("Samples", true)
    tbl:add_column("Max Alloc/Op", true)
    tbl:add_column("Alloc/Op", true)
    tbl:add_column("Relative")
    tbl:add_column("Peak Memory", true)
    tbl:add_column("Uncollected", true)
    tbl:add_column("Avg Incr.", true)

    -- Sort samples by allocation rate (descending)
    local summaries = self:get_summaries()
    sort(summaries, function(a, b)
        return a.memstat.alloc_op < b.memstat.alloc_op
    end)

    -- Add data rows directly using sorted samples
    local baseline = self.baseline_summary
    local baseline_alloc_op = baseline.memstat.alloc_op
    for _, summary in ipairs(summaries) do
        local memstat = summary.memstat

        -- Calculate relative memory usage
        local relative = summary == baseline and 'baseline' or
                             calc_relative_value(baseline_alloc_op,
                                                 memstat.alloc_op, {
                greater = "more",
                less = "less",
                equal = "-",
            })
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

    self:print([[
### Memory Analysis

*Sorted by Alloc/Op (lower is better).*
]])
    self:print(concat(tbl:render(), '\n'))
end

-- Print measurement reliability analysis (sorted by reliability/precision)
function Report:reliability_analysis()
    local tbl = new_table()
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

    self:print([[
### Measurement Reliability Analysis

*Sorted by measurement precision (lower RCIW = more reliable)*
]])
    self:print(concat(tbl:render(), '\n'))
end

-- Print performance ranking table (sorted by mean execution time)
function Report:performance_analysis()
    local tbl = new_table()
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
    local baseline = self.baseline_summary
    for _, summary in ipairs(summaries) do
        tbl:add_rows({
            summary.name,
            fmt.throughput(summary.throughput),
            fmt.time(summary.mean),
            fmt.time(summary.median),
            fmt.time(summary.p95),
            fmt.time(summary.p99),
            fmt.time(summary.stddev),
            summary == baseline and "baseline" or
                calc_relative_value(baseline.mean, summary.mean, {
                    greater = "slower",
                    less = "faster",
                    equal = "-",
                }),
        })
    end

    self:print([[
### Performance Analysis

*Sorted by mean execution time (lower is better).*
]])
    self:print(concat(tbl:render(), '\n'))
end

local PRINTABLE_CLUSTER = {
    ['welch-t-test-holm-correction'] = true,
    ['scott-knott-esd'] = true,
}

-- Print clustering analysis and performance ranking
function Report:cluster_analysis()
    local comparison = self:get_comparisons()
    if #comparison.groups < #self.samples_list then
        -- Clustering occurred, print detailed analysis
        local alg = comparison.algorithm
        if PRINTABLE_CLUSTER[alg] then
            if alg == "scott-knott-esd" then
                self:cluster_analysis_skesd()
            else
                self:cluster_analysis_welcht()
            end
        end
    end
end

-- Print statistical method information and clustering details
function Report:clustering_details()
    local samples_list = self.samples_list
    local comparison = self:get_comparisons()

    self:print([[
- Method: %s
- Groups: %d sample groups clustered into %d statistical groups
- Interpretation: %s
- Clustering: %s]], comparison.name, #samples_list,
               comparison.groups and #comparison.groups or 0,
               comparison.description, comparison.clustering)

    self:print('')
end

-- Print performance ranking table with Scott-Knott ESD clustering
function Report:cluster_analysis_skesd()
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

    local baseline_group = comparison.groups[self.baseline_summary.name]
    local tbl = new_table()
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
        local significant = "-"

        -- Calculate statistics vs baseline
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
            format("C%d", sample_group.rank or sample_group.id),
            name,
            fmt.time(summary.mean),
            format("%d", sample_group.count or 0),
            significant,
            format("%.2f", sample_group.cohen_d or 0),
        })
    end

    self:print([[
### Statistical Clustering Analysis

**Note: Samples in same cluster are statistically equivalent.**
]])
    self:clustering_details()
    self:print(concat(tbl:render(), '\n'))
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
    local baseline = self.baseline_summary

    local tbl = new_table()
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
            format("C%d", sample_group.rank),
            name,
            fmt.time(summary.mean),
            sample_size,
            significant,
            p_adjusted_display,
        })
    end

    self:print([[
### Pairwise Statistical Comparisons (Welch's t-test)

**Note: Each sample compared against every other sample with Holm multiple testing correction**
]])
    self:clustering_details()
    self:print(concat(tbl:render(), '\n'))
end

--- Render the full report
function Report:render()
    -- Sampling details
    self:sampling_details()
    self:print('')

    -- Memory analysis
    self:memory_analysis()
    self:print('')

    -- Measurement reliability analysis
    self:reliability_analysis()
    self:print('')

    -- Performance analysis
    self:performance_analysis()
    self:print('')

    -- Clustering analysis (if applicable)
    self:cluster_analysis()
end

--- Create a new Report instance
--- @param samples_list measure.samples[] List of samples to include in the report
local function new(samples_list)
    -- Validate input
    if not samples_list or type(samples_list) ~= "table" or #samples_list < 1 then
        error("Error: At least one sample required for comparison", 2)
    end

    return setmetatable({
        samples_list = samples_list,
        sysinfo = report_sysinfo(),
    }, Report)
end

return new
