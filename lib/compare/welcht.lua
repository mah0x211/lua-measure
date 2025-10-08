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
-- compare/welch.lua: Welch t-test with Holm correction comparison
-- Handles conversion and analysis of Welch t-test results
-- Performance optimizations: localize frequently used functions
--
local ipairs = ipairs
local abs = math.abs

-- Load required modules
local welcht = require('measure.posthoc.welcht')

--- Convert Welch t-test results to comparison format
--- @param welcht_results table Results from measure.posthoc.welcht
--- @return table Array and hash map of comparison objects with statistical results
local function convert_welcht_results(welcht_results)
    local comparisons = {}

    for _, result in ipairs(welcht_results) do
        local sample1 = result.pair[1]
        local sample2 = result.pair[2]

        -- Calculate performance metrics using samples methods
        local mean1 = sample1:mean()
        local mean2 = sample2:mean()
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

        local comp_result = {
            name1 = sample1:name(),
            name2 = sample2:name(),
            speedup = speedup,
            difference = difference,
            relative_difference = relative_difference,
            p_value = result.p_value,
            p_adjusted = result.p_adjusted,
            significant = result.p_value < 0.05,
            significance_level = significance_level,
        }

        -- Add to array
        comparisons[#comparisons + 1] = comp_result

        -- Create O(1) access indices (bidirectional)
        if not comparisons[comp_result.name1] then
            comparisons[comp_result.name1] = {}
        end
        if not comparisons[comp_result.name2] then
            comparisons[comp_result.name2] = {}
        end

        comparisons[comp_result.name1][comp_result.name2] = comp_result
        comparisons[comp_result.name2][comp_result.name1] = comp_result
    end

    return comparisons
end

--- Create compact letter display groups based on pairwise comparisons
--- Similar to TukeyHSD compact letter display based on statistical significance
--- @param comparisons table Array of pairwise comparison results
--- @param samples_list table Array of measure.samples objects
--- @return table Array of group objects with rank, names, and members
local function create_compact_letter_groups(comparisons, samples_list)
    -- Build similarity matrix: samples are similar if statistically non-significant
    local n = #samples_list
    local similar = {}
    for i = 1, n do
        similar[i] = {}
        for j = 1, n do
            similar[i][j] = (i == j) -- Diagonal: each sample is similar to itself
        end
    end

    -- Update similarity matrix based on statistical test results
    for _, comp in ipairs(comparisons) do
        local idx1, idx2 = nil, nil
        for i, sample in ipairs(samples_list) do
            if sample:name() == comp.name1 then
                idx1 = i
            end
            if sample:name() == comp.name2 then
                idx2 = i
            end
        end

        if idx1 and idx2 then
            -- Samples are considered similar if difference is not statistically significant
            local is_similar = not comp.significant
            similar[idx1][idx2] = is_similar
            similar[idx2][idx1] = is_similar
        end
    end

    -- Group statistically similar samples using graph traversal
    local visited = {}
    local groups = {}
    local group_id = 0

    for i = 1, n do
        if not visited[i] then
            local group = {}
            -- Traverse connected components using stack-based approach
            local stack = {
                i,
            }
            while #stack > 0 do
                local node = table.remove(stack)
                if not visited[node] then
                    visited[node] = true
                    group[#group + 1] = node

                    for neighbor = 1, n do
                        if similar[node][neighbor] and not visited[neighbor] then
                            stack[#stack + 1] = neighbor
                        end
                    end
                end
            end

            if #group > 0 then
                local names = {}
                group_id = group_id + 1
                groups[#groups + 1] = {
                    rank = group_id,
                    names = names,
                    members = group,
                }
                -- Map sample indices to names for output
                for _, member_idx in ipairs(group) do
                    local name = samples_list[member_idx]:name()
                    names[#names + 1] = name
                    groups[name] = groups[#groups] -- Map sample name to its group for quick lookup
                end
            end
        end
    end

    -- Preserve group ranking order for consistency with statistical tests
    return groups
end

--- Analyze samples using Welch t-test with Holm correction
--- Performs statistical comparison using Welch t-test for unequal variances
--- with Holm multiple comparison correction
--- @param samples_list table Array of measure.samples objects to compare
--- @return table result Complete comparison result with method, pairs, and groups
local function welch_t_test(samples_list)
    local welcht_results = welcht(samples_list)
    local comparisons = convert_welcht_results(welcht_results)
    local groups = create_compact_letter_groups(comparisons, samples_list)

    return {
        name = "Welch's t-test with Holm correction",
        algorithm = 'welch-t-test-holm-correction',
        description = "Each sample group is compared against every other sample group with adjusted p-values to control family-wise error rate",
        clustering = "compact letter display based on statistical significance",
        pairs = comparisons,
        groups = groups,
    }
end

return welch_t_test
