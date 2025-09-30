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
local stats = require('measure.stats')
local sysinfo = require('measure.sysinfo')
local table_utils = require('measure.report.table')
local fmt = require('measure.report.format')
local print = require('measure.print')

local DIV = string.rep('=', 80)

-- Format system information for display (compact format)
local function format_sysinfo(info)
    local lines = {}

    -- Header
    lines[#lines + 1] = 'Environment Information'
    lines[#lines + 1] = DIV

    -- Hardware line: CPU, cores, total memory (exclude available memory)
    local hw_parts = {}
    if info.cpu.model then
        hw_parts[#hw_parts + 1] = info.cpu.model
    end
    if info.cpu.cores and info.cpu.threads then
        hw_parts[#hw_parts + 1] = format('%d cores (%d threads)',
                                         info.cpu.cores, info.cpu.threads)
    end
    if info.memory.total then
        hw_parts[#hw_parts + 1] = info.memory.total
    end
    if #hw_parts > 0 then
        lines[#lines + 1] = 'Hardware: ' .. concat(hw_parts, ', ')
    end

    -- Host line: OS, version, arch, kernel version
    local host_parts = {}
    if info.os.name then
        host_parts[#host_parts + 1] = info.os.name
    end
    if info.os.version then
        host_parts[#host_parts + 1] = info.os.version
    end
    if info.os.arch then
        host_parts[#host_parts + 1] = info.os.arch
    end
    -- Add kernel version, but extract just the version number for brevity
    if info.os.kernel then
        local kernel_version = info.os.kernel:match('Version ([^:]+)')
        if kernel_version then
            host_parts[#host_parts + 1] = format('kernel=%s', kernel_version)
        end
    end
    if #host_parts > 0 then
        lines[#lines + 1] = '    Host: ' .. concat(host_parts, ', ')
    end

    -- Runtime line: Lua version, JIT status (exclude GC info)
    local runtime_parts = {}
    if info.lua.version then
        runtime_parts[#runtime_parts + 1] = info.lua.version
    end
    if info.lua.jit then
        runtime_parts[#runtime_parts + 1] = format('JIT=%s',
                                                   info.lua.jit_status or
                                                       'unknown')
    else
        runtime_parts[#runtime_parts + 1] = 'no-JIT'
    end
    if #runtime_parts > 0 then
        lines[#lines + 1] = ' Runtime: ' .. concat(runtime_parts, ', ')
    end

    -- Date line
    if info.timestamp then
        lines[#lines + 1] = '    Date: ' .. info.timestamp
    end

    lines[#lines + 1] = DIV
    return concat(lines, '\n')
end

-- Helper function to find sample by name
local function find_sample(samples, name)
    for _, sample in ipairs(samples) do
        if sample.name == name then
            return sample
        end
    end
    return nil
end

-- Helper function to get comparison result between two samples
local function get_comparison(comparisons, name1, name2)
    for _, comp in ipairs(comparisons) do
        if (comp.name1 == name1 and comp.name2 == name2) or
            (comp.name1 == name2 and comp.name2 == name1) then
            return comp
        end
    end
    return nil
end

-- Helper function to get group info for a sample (SK-ESD clustering)
local function get_group_info(groups, name)
    if not groups then
        return nil, false, {}, nil
    end

    for _, group in ipairs(groups) do
        for _, group_name in ipairs(group.names or {}) do
            if group_name == name then
                return group.rank, #group.names > 1, group.names, group.id
            end
        end
    end
    return nil, false, {}, nil
end

-- Helper function to format group display for SK-ESD clustering
local function format_group_display(cluster_id, has_peers, group_members)
    if not cluster_id then
        return "N/A"
    end

    if has_peers then
        return format("C%d (%d)", cluster_id, #group_members)
    else
        return format("C%d", cluster_id)
    end
end

-- Calculate relative performance vs baseline
local function calculate_relative_performance(sample_mean, baseline_mean)
    local ratio = sample_mean / baseline_mean
    if ratio > 1 then
        return format("%.1f%% slower", (ratio - 1) * 100)
    else
        return format("%.1f%% faster", (1 - ratio) * 100)
    end
end

local function create_rankings(samples, groups)
    local rankings = {
        by_time_simple = {},
        by_time = {},
        by_time_with_ranks = {},
        by_memory = {},
        by_reliability = {},
    }

    if not samples or #samples == 0 then
        return rankings
    end

    local ordered = {}
    for _, info in ipairs(samples) do
        ordered[#ordered + 1] = {
            name = info.name,
            mean = info.mean,
        }
    end
    sort(ordered, function(a, b)
        if a.mean == b.mean then
            return a.name < b.name
        end
        return a.mean < b.mean
    end)

    for _, item in ipairs(ordered) do
        rankings.by_time_simple[#rankings.by_time_simple + 1] = item.name
    end

    local cluster_lookup = {}
    if groups then
        for _, group in ipairs(groups) do
            for _, name in ipairs(group.names or {}) do
                cluster_lookup[name] = group.id or group.rank
            end
        end
    end

    if groups and #groups > 0 then
        local samples_with_clusters = {}
        for _, item in ipairs(ordered) do
            samples_with_clusters[#samples_with_clusters + 1] = {
                name = item.name,
                mean = item.mean,
                cluster_id = cluster_lookup[item.name],
            }
        end

        local cluster_sizes = {}
        for _, sample in ipairs(samples_with_clusters) do
            local cid = sample.cluster_id or sample.name
            cluster_sizes[cid] = (cluster_sizes[cid] or 0) + 1
        end

        local cluster_ranks = {}
        local current_rank = 1
        for _, sample in ipairs(samples_with_clusters) do
            local cid = sample.cluster_id or sample.name
            if not cluster_ranks[cid] then
                cluster_ranks[cid] = current_rank
                current_rank = current_rank + (cluster_sizes[cid] or 1)
            end
        end

        for _, sample in ipairs(samples_with_clusters) do
            rankings.by_time[#rankings.by_time + 1] = sample.name
            rankings.by_time_with_ranks[#rankings.by_time_with_ranks + 1] = {
                name = sample.name,
                rank = cluster_ranks[sample.cluster_id or sample.name],
            }
        end
    else
        for idx, item in ipairs(ordered) do
            rankings.by_time[#rankings.by_time + 1] = item.name
            rankings.by_time_with_ranks[#rankings.by_time_with_ranks + 1] = {
                name = item.name,
                rank = idx,
            }
        end
    end

    local by_memory = {}
    for _, info in ipairs(samples) do
        if info.memory_per_op then
            by_memory[#by_memory + 1] = {
                name = info.name,
                value = info.memory_per_op,
            }
        end
    end
    sort(by_memory, function(a, b)
        if a.value == b.value then
            return a.name < b.name
        end
        return a.value < b.value
    end)
    for _, item in ipairs(by_memory) do
        rankings.by_memory[#rankings.by_memory + 1] = item.name
    end

    local by_reliability = {}
    for _, info in ipairs(samples) do
        by_reliability[#by_reliability + 1] = {
            name = info.name,
            value = info.ci_width or math.huge,
        }
    end
    sort(by_reliability, function(a, b)
        if a.value == b.value then
            return a.name < b.name
        end
        return a.value < b.value
    end)
    for _, item in ipairs(by_reliability) do
        rankings.by_reliability[#rankings.by_reliability + 1] = item.name
    end

    return rankings
end

-- Get significance indicator for comparison
local function get_significance_indicator(comparisons, baseline_name,
                                          sample_name)
    local comp = get_comparison(comparisons, baseline_name, sample_name)
    if comp and comp.significant then
        return "[x] (" .. comp.significance_level .. ")"
    else
        return "[ ]"
    end
end

local function get_cluster_significance_indicator(comparisons, baseline_id,
                                                  sample_id)
    if not baseline_id or not sample_id or baseline_id == sample_id then
        return "[ ]"
    end

    local name_base = 'Cluster ' .. baseline_id
    local name_sample = 'Cluster ' .. sample_id
    local comp = get_comparison(comparisons, name_base, name_sample)
    if comp and comp.significant then
        if comp.significance_level then
            return "[x] (" .. comp.significance_level .. ")"
        else
            return "[x]"
        end
    end
    return "[ ]"
end

-- Print performance ranking legend
local function print_performance_legend(algorithm)
    print.line()

    if algorithm == "scott-knott-esd" then
        print("Cluster Legend:")
        print(
            "  C1, C2, ... = Statistical cluster ID (preserves original clustering result)")
        print(
            "  (n) = Number of statistically equivalent sample groups in cluster")
        print("  unique = Significantly different from all other sample groups")
        print("  name +n = Statistically equivalent to 'name' and n others")
    elseif algorithm == "single-sample" then
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
local function print_performance_ranking_scott_knott_esd(results)
    local tbl = table_utils.new_table(
                    "Performance Ranking with Statistical Clustering (Primary=Mean)",
                    "Note: Ranking shows individual performance; same cluster ID = statistically equivalent")

    -- Add columns
    tbl:add_column("Rank", true)
    tbl:add_column("Cluster")
    tbl:add_column("Name")
    tbl:add_column("Primary", true)
    tbl:add_column("Relative")
    tbl:add_column("Stat.Equiv")
    tbl:add_column("vs Baseline")

    local baseline_name = results.rankings.by_time[1]
    local baseline = find_sample(results.samples, baseline_name)

    local _, _, _, baseline_group_id = get_group_info(results.groups,
                                                      baseline_name)

    -- Add data rows using cluster-based ranking
    for _, rank_info in ipairs(results.rankings.by_time_with_ranks) do
        local name = rank_info.name
        local rank = rank_info.rank
        local sample = find_sample(results.samples, name)
        local relative = rank == 1 and "baseline" or
                             calculate_relative_performance(sample.mean,
                                                            baseline.mean)
        local group_rank, has_peers, group_members, group_id = get_group_info(
                                                                   results.groups,
                                                                   name)
        local cluster_id = format_group_display(group_rank, has_peers,
                                                group_members)
        local significant
        if rank == 1 then
            significant = "-"
        else
            if baseline_group_id and group_id then
                significant = get_cluster_significance_indicator(
                                  results.comparisons, baseline_group_id,
                                  group_id)
            else
                significant = get_significance_indicator(results.comparisons,
                                                         baseline_name, name)
            end
        end

        local stat_equiv = "-"
        if has_peers then
            local peers = {}
            for _, member in ipairs(group_members) do
                if member ~= name then
                    peers[#peers + 1] = member
                end
            end
            if #peers > 0 then
                if #peers == 1 then
                    stat_equiv = peers[1]
                else
                    stat_equiv = format("%s +%d", peers[1], #peers - 1)
                end
            end
        else
            stat_equiv = "unique"
        end

        tbl:add_rows({
            tostring(rank),
            cluster_id,
            name,
            fmt.time(sample.mean),
            relative,
            stat_equiv,
            significant,
        })
    end

    print(concat(tbl:render(), '\n'))
    print_performance_legend(results.method and results.method.algorithm or
                                 "scott-knott-esd")
    print.line()
end

-- Print performance ranking table with Welch's t-test comparisons
local function print_performance_ranking_welchs_test(results)
    local has_clusters = results.groups and #results.groups > 0
    local title =
        "Performance Ranking with Statistical Comparisons (Primary=Mean)"
    local note =
        "Note: Statistical significance shows pairwise comparisons with multiple testing correction"

    local tbl = table_utils.new_table(title, note)

    -- Add columns
    tbl:add_column("Rank", true)
    if has_clusters then
        tbl:add_column("Cluster")
    end
    tbl:add_column("Name")
    tbl:add_column("Primary", true)
    tbl:add_column("Relative")
    tbl:add_column("vs Baseline")
    tbl:add_column("vs Others")
    tbl:add_column("Effect")

    local baseline_name = results.rankings.by_time[1]
    local baseline = find_sample(results.samples, baseline_name)

    -- Add data rows using cluster-based ranking
    for _, rank_info in ipairs(results.rankings.by_time_with_ranks) do
        local name = rank_info.name
        local rank = rank_info.rank
        local sample = find_sample(results.samples, name)
        local relative = rank == 1 and "baseline" or
                             calculate_relative_performance(sample.mean,
                                                            baseline.mean)
        local significant
        if rank == 1 then
            significant = "-"
        else
            significant = get_significance_indicator(results.comparisons,
                                                     baseline_name, name)
        end

        local vs_others = "-"
        local effect_size = "-"

        if rank > 1 then
            local sig_count = 0
            local total_comparisons = 0

            for _, other_name in ipairs(results.rankings.by_time) do
                if other_name ~= name then
                    total_comparisons = total_comparisons + 1
                    local comp = get_comparison(results.comparisons, name,
                                                other_name)
                    if comp and comp.significant then
                        sig_count = sig_count + 1
                    end
                end
            end

            if total_comparisons > 0 then
                vs_others = format("%d/%d sig", sig_count, total_comparisons)
            end

            local ratio = sample.mean / baseline.mean
            if ratio >= 2.0 then
                effect_size = "large"
            elseif ratio >= 1.5 then
                effect_size = "medium"
            else
                effect_size = "small"
            end
        end

        -- Build row data based on whether clustering info is available
        local row_data = {
            tostring(rank),
        }

        if has_clusters then
            local group_rank, has_peers, group_members = get_group_info(
                                                             results.groups,
                                                             name)
            local cluster_id = format_group_display(group_rank, has_peers,
                                                    group_members)
            row_data[#row_data + 1] = cluster_id or "-"
        end

        row_data[#row_data + 1] = name
        row_data[#row_data + 1] = fmt.time(sample.mean)
        row_data[#row_data + 1] = relative
        row_data[#row_data + 1] = significant
        row_data[#row_data + 1] = vs_others
        row_data[#row_data + 1] = effect_size

        tbl:add_rows(row_data)
    end

    print(concat(tbl:render(), '\n'))
    print_performance_legend(results.method and results.method.algorithm or
                                 "welch-t-test-holm-correction")
    print.line()
end

-- Print performance ranking table with statistical clustering (SK-ESD) or comparisons (Welch)
local function print_performance_ranking(results)
    if results.method and results.method.algorithm == "scott-knott-esd" then
        print_performance_ranking_scott_knott_esd(results)
    else
        print_performance_ranking_welchs_test(results)
    end
end

-- Print detailed memory analysis table
local function print_memory_analysis(samples_list)
    -- Create table directly with new interface
    local tbl = table_utils.new_table("Memory Analysis",
                                      "Note: Sorted by allocation rate (lower is better).")

    -- Add columns
    tbl:add_column("Name")
    tbl:add_column("Samples", true)
    tbl:add_column("Max Alloc", true)
    tbl:add_column("Alloc Rate", true)
    tbl:add_column("Rel.")
    tbl:add_column("Peak Memory", true)
    tbl:add_column("Uncollected", true)
    tbl:add_column("Avg Incr.", true)

    -- Sort samples by allocation rate (descending)
    local sorted_samples = {}
    for _, sample in ipairs(samples_list) do
        local memstat = sample:memstat()
        local alloc_rate = memstat and memstat.alloc_op or 0
        sorted_samples[#sorted_samples + 1] = {
            sample = sample,
            alloc_rate = alloc_rate,
        }
    end

    sort(sorted_samples, function(a, b)
        return a.alloc_rate < b.alloc_rate
    end)

    -- Get baseline (first/best sample) for relative calculation
    local baseline_alloc_rate = sorted_samples[1] and
                                    sorted_samples[1].alloc_rate or 1

    -- Add data rows directly using sorted samples
    for rank, entry in ipairs(sorted_samples) do
        local sample = entry.sample
        local name = sample:name()
        local memstat = sample:memstat()

        if memstat then
            local sample_count = tostring(#sample)
            local max_alloc_op =
                (memstat.max_alloc_op and memstat.max_alloc_op ==
                    memstat.max_alloc_op) and fmt.memory(memstat.max_alloc_op) ..
                    '/op' or "N/A"
            local alloc_rate =
                memstat.alloc_op and fmt.memory(memstat.alloc_op) .. "/op" or
                    "N/A"

            -- Calculate relative memory usage
            local relative = "1.0x"
            if rank > 1 and baseline_alloc_rate > 0 then
                local ratio = entry.alloc_rate / baseline_alloc_rate
                relative = format("%.1fx", ratio)
            end
            local peak_memory = memstat.peak_memory and
                                    fmt.memory(memstat.peak_memory) or "N/A"
            local uncollected = (memstat.uncollected and memstat.uncollected ==
                                    memstat.uncollected) and
                                    fmt.memory(memstat.uncollected) or "N/A"
            local avg_incr = (memstat.avg_incr and memstat.avg_incr ==
                                 memstat.avg_incr) and
                                 fmt.memory(memstat.avg_incr) .. "/op" or "N/A"

            tbl:add_rows({
                name,
                sample_count,
                max_alloc_op,
                alloc_rate,
                relative,
                peak_memory,
                uncollected,
                avg_incr,
            })
        else
            tbl:add_rows({
                name,
                "N/A",
                "N/A",
                "N/A",
                "N/A",
                "N/A",
                "N/A",
                "N/A",
            })
        end
    end

    print(concat(tbl:render(), '\n'))
end

-- Print comprehensive sample summary with statistics (merged from detailed stats)
local function print_summary_statistics(results)
    -- Create table directly with new interface
    local tbl = table_utils.new_table(
                    "Benchmark Summary & Statistics (Sorted by Mean)", nil)

    -- Add columns
    tbl:add_column("Rank", true)
    tbl:add_column("Name")
    tbl:add_column("Ops/sec", true)
    tbl:add_column("Mean", true)
    tbl:add_column("p50", true)
    tbl:add_column("p95", true)
    tbl:add_column("p99", true)
    tbl:add_column("StdDev", true)
    tbl:add_column("Relative")

    local baseline_name = results.rankings.by_time_simple[1]
    local baseline = find_sample(results.samples, baseline_name)

    -- Add data rows using simple time-based ranking
    for rank, name in ipairs(results.rankings.by_time_simple) do
        local sample = find_sample(results.samples, name)
        local relative = "baseline"
        if rank > 1 then
            local ratio = sample.mean / baseline.mean
            relative = format("%.1fx slower", ratio)
        end

        tbl:add_rows({
            tostring(rank),
            name,
            fmt.throughput(sample.throughput),
            fmt.time(sample.mean),
            fmt.time(sample.median),
            fmt.time(sample.p95),
            fmt.time(sample.p99),
            fmt.time(sample.stddev),
            relative,
        })
    end

    print(concat(tbl:render(), '\n'))
end

-- Print measurement reliability analysis (sorted by reliability/precision)
local function print_measurement_reliability_analysis(results)
    -- Create table directly with new interface
    local tbl = table_utils.new_table("Measurement Reliability Analysis",
                                      "Note: Ranked by measurement precision (lower RCIW = more reliable)")

    -- Add columns
    tbl:add_column("Rank", true) -- Numeric column
    tbl:add_column("Name") -- Text column
    tbl:add_column("95% CI") -- Text column (contains formatting)
    tbl:add_column("CI Width", true) -- Numeric column (time values)
    tbl:add_column("RCIW", true) -- Numeric column (percentage)
    tbl:add_column("Quality") -- Text column

    -- Create a list of samples with their RCIW for sorting
    local reliability_samples = {}
    for _, name in ipairs(results.rankings.by_time) do
        local sample = find_sample(results.samples, name)
        reliability_samples[#reliability_samples + 1] = {
            name = name,
            sample = sample,
            rciw = sample.rciw or 999.0, -- Use high value for missing RCIW
        }
    end

    -- Sort by RCIW (lower is better = more reliable)
    sort(reliability_samples, function(a, b)
        return a.rciw < b.rciw
    end)

    -- Add data rows directly
    for rank, entry in ipairs(reliability_samples) do
        local sample = entry.sample
        local ci_display = fmt.confidence_interval(sample.mean, sample.ci_width)
        local rciw_display = format("%.1f%%", sample.rciw or 0)
        local quality_display = sample.quality or "unknown"

        tbl:add_rows({
            tostring(rank),
            entry.name,
            ci_display,
            fmt.time(sample.ci_width or 0),
            rciw_display,
            quality_display,
        })
    end

    print(concat(tbl:render(), '\n'))
end

-- Print sampling details (without ranking, focused on technical details)
local function print_sampling_details(samples_list)
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
    for _, sample in ipairs(samples_list) do
        local name = sample:name()
        local conf_level = format("%.1f%%", (type(sample.cl) == "function" and
                                      sample:cl() or sample.cl) or 95)
        local outliers = format("%d (%.1f%%)",
                                sample.outliers and sample.outliers.total or 0,
                                sample.outliers and sample.outliers.percentage or
                                    0)
        local target_rciw = format("%.1f%%",
                                   (type(sample.rciw) == "function" and
                                       sample:rciw() or sample.target_rciw) or
                                       2.0)
        local gc_step = fmt.gc_step((type(sample.gc_step) == "number" and
                                        sample.gc_step) or 0)

        tbl:add_rows({
            name,
            tostring(sample.sample_count or #sample),
            outliers,
            conf_level,
            target_rciw,
            gc_step,
        })
    end

    print(concat(tbl:render(), '\n'))
end

-- Print statistical method information and clustering details
local function print_method_information(results, samples_list)
    print("Statistical Analysis Method:")
    print.divider("=", 80)

    if results.method then
        print("Method: %s", results.method.name)
        print("Groups: %d sample groups clustered into %d statistical groups",
              #samples_list, results.groups and #results.groups or 0)
        print("Interpretation: %s", results.method.description)
        if results.method.clustering then
            print("                Clustering: %s", results.method.clustering)
        end
    end

    -- Clustering details are already shown in the Performance Ranking table
    print.line()
end

-- Main function to print comprehensive sample comparison results
local function build_comparison_results(samples_list)
    local stats_result = stats(samples_list)
    local comparison = stats_result.comparison

    local method = comparison and comparison.method or {
        name = "Single sample summary",
        algorithm = 'single-sample',
        description = "Only one sample provided; pairwise comparisons are unavailable",
        clustering = "single group (no statistical comparison)",
    }

    local groups = comparison and comparison.groups or {}
    local comparisons = comparison and comparison.pairs or {}
    local summaries = stats_result.summaries or {}
    local rankings = create_rankings(summaries, groups)

    return {
        samples = summaries,
        summaries = summaries,
        comparisons = comparisons,
        groups = groups,
        method = method,
        rankings = rankings,
        comparison = comparison,
    }
end

local function print_comparison(samples_list)
    -- Validate input
    if not samples_list or type(samples_list) ~= "table" or #samples_list < 1 then
        print("Error: At least one sample required for comparison")
        return
    end

    -- Always print system information
    local info = sysinfo()
    print(format_sysinfo(info))
    print.line()

    -- Print sampling details before any analysis
    print_sampling_details(samples_list)

    -- Print memory analysis
    print_memory_analysis(samples_list)

    -- Build comparison and ranking results
    local results = build_comparison_results(samples_list)

    -- Print summary statistics first (comprehensive summary with stats)
    print_summary_statistics(results)

    if #results.summaries > 1 then
        -- Print measurement reliability analysis (statistical quality assessment)
        print_measurement_reliability_analysis(results)

        -- Print detailed statistical analysis results (only if clustering occurred)
        local num_clusters = results.groups and #results.groups or #results.summaries
        local num_samples = #results.summaries
        if num_clusters < num_samples then
            -- Print method information (explains statistical analysis approach)
            print_method_information(results, samples_list)
            print_performance_ranking(results)
        end
    end
end

-- Export the module
return {
    print_comparison = print_comparison,
    _build_results = build_comparison_results,
}
