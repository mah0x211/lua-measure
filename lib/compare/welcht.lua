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

--- @class measure.compare.welcht.pair
--- @field name1 string Name of the first case
--- @field name2 string Name of the second case
--- @field speedup number Ratio of first-case mean to second-case mean, or zero when the second mean is nonpositive
--- @field difference number First-case mean minus second-case mean in nanoseconds
--- @field relative_difference number Absolute difference as a percentage of the second mean, or zero when it is nonpositive
--- @field p_value number Unadjusted two-sided Welch p-value
--- @field p_adjusted number Holm-adjusted p-value
--- @field significant boolean Whether the adjusted p-value is below 0.05
--- @field significance_level string|nil Adjusted-p-value threshold label when significant

--- @class measure.compare.welcht.pairs
--- @field [integer] measure.compare.welcht.pair Pair results in native comparison order
--- @field [string] table<string, measure.compare.welcht.pair> Bidirectional lookup by case names

--- @class measure.compare.welcht.group
--- @field rank integer One-based letter-column identifier, not a performance rank
--- @field letter string Lowercase CLD token, such as a, z, or aa
--- @field names string[] Case names belonging to this letter column
--- @field members integer[] Corresponding one-based indices into the original sample list

--- @class measure.compare.welcht.groups
--- @field [integer] measure.compare.welcht.group Letter columns in display order
--- @field [string] measure.compare.welcht.group[] All letter columns containing the named case

--- @class measure.compare.welcht.result
--- @field name string Statistical method name
--- @field algorithm string Comparison algorithm identifier
--- @field description string Interpretation of the pairwise testing method
--- @field clustering string Interpretation of the overlapping letter display
--- @field pairs measure.compare.welcht.pairs Pairwise results and bidirectional lookup
--- @field groups measure.compare.welcht.groups Letter columns and complete case membership lists

--- Convert native Welch results into pairwise statistics and name lookups.
--- Decisions and threshold labels use Holm-adjusted p-values; both original
--- p-value fields are retained. Each name-order lookup refers to the same pair.
--- @param welcht_results table[] Native results containing pair, p_value, and p_adjusted
--- @return measure.compare.welcht.pairs comparisons Ordered pairs with bidirectional case-name lookup
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

        -- Categorize statistical significance after Holm correction
        local significance_level = nil
        if result.p_adjusted < 0.001 then
            significance_level = 'p<0.001'
        elseif result.p_adjusted < 0.01 then
            significance_level = 'p<0.01'
        elseif result.p_adjusted < 0.05 then
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
            significant = result.p_adjusted < 0.05,
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

--- Check whether a letter column contains an original sample index.
--- The column is read without modification.
--- @param column integer[] Original sample indices assigned to one letter
--- @param member integer Original sample index to locate
--- @return boolean found Whether member occurs in column
local function contains(column, member)
    for _, value in ipairs(column) do
        if value == member then
            return true
        end
    end
    return false
end

--- Check whether every member of one letter column occurs in another.
--- Equal columns also satisfy the subset relation; neither array is modified.
--- @param column integer[] Candidate subset of original sample indices
--- @param other integer[] Candidate containing column
--- @return boolean subset Whether other contains every member of column
local function is_subset(column, other)
    for _, member in ipairs(column) do
        if not contains(other, member) then
            return false
        end
    end
    return true
end

--- Remove duplicate or contained letter columns in place.
--- A containing column retains every case and pair from a removed subset.
--- Equal columns retain their earlier representative; surviving member arrays
--- are not modified.
--- @param columns integer[][] Letter columns to compact in place
--- @return integer[][] columns The same outer array after redundant columns are removed
local function absorb(columns)
    for i = #columns, 1, -1 do
        for j = 1, #columns do
            if i ~= j and (#columns[i] < #columns[j] or i > j) and
                is_subset(columns[i], columns[j]) then
                table.remove(columns, i)
                break
            end
        end
    end
    return columns
end

--- Encode a positive one-based column identifier as a lowercase letter token.
--- Tokens extend beyond the alphabet: 1 is a, 26 is z, and 27 is aa.
--- @param index integer Positive one-based letter-column identifier
--- @return string letter CLD token identifying the column, not a performance rank
local function letter_for(index)
    local letter = ''
    while index > 0 do
        index = index - 1
        letter = string.char(97 + index % 26) .. letter
        index = math.floor(index / 26)
    end
    return letter
end

--- Build overlapping compact letter display groups by inserting and absorbing columns.
--- comparisons must cover every unordered pair in samples_list. Significant
--- pairs share no letter, and non-significant pairs share at least one letter.
--- Every case is represented, but no minimum number of letters is promised.
--- Numeric keys enumerate letter columns; groups[name] lists all column objects
--- containing that case. Input samples and comparison results are not modified.
--- @param comparisons measure.compare.welcht.pairs Complete pairwise decisions after Holm correction
--- @param samples_list measure.samples[] Named samples whose indices and names identify group members
--- @return measure.compare.welcht.groups groups Letter columns and all memberships indexed by case name
local function create_compact_letter_groups(comparisons, samples_list)
    local first = {}
    local indices = {}
    for i, sample in ipairs(samples_list) do
        first[i] = i
        indices[sample:name()] = i
    end
    local columns = {first}

    -- Insert-and-absorb: separate significant pairs without losing any
    -- non-significant pair's shared column. This is not a minimum-letter search.
    for _, comp in ipairs(comparisons) do
        if comp.significant then
            local left, right = indices[comp.name1], indices[comp.name2]
            local split = {}
            for _, column in ipairs(columns) do
                if contains(column, left) and contains(column, right) then
                    local without_left, without_right = {}, {}
                    for _, member in ipairs(column) do
                        if member ~= left then
                            without_left[#without_left + 1] = member
                        end
                        if member ~= right then
                            without_right[#without_right + 1] = member
                        end
                    end
                    split[#split + 1] = without_right
                    split[#split + 1] = without_left
                else
                    split[#split + 1] = column
                end
            end
            columns = absorb(split)
        end
    end

    local groups = {}
    for _, sample in ipairs(samples_list) do
        groups[sample:name()] = {}
    end
    for rank, members in ipairs(columns) do
        local group = {
            rank = rank,
            letter = letter_for(rank),
            names = {},
            members = members,
        }
        groups[#groups + 1] = group
        for _, member in ipairs(members) do
            local name = samples_list[member]:name()
            group.names[#group.names + 1] = name
            local memberships = groups[name]
            memberships[#memberships + 1] = group
        end
    end
    return groups
end

--- Compare samples with Welch tests, Holm correction, and an overlapping CLD.
--- Pairwise statistics remain the source of significance decisions. Sharing a
--- letter indicates non-significance, not established statistical equivalence.
--- @param samples_list measure.samples[] At least two named sample objects accepted by the native Welch test
--- @return measure.compare.welcht.result result Method metadata, pairwise statistics, and overlapping letter memberships
local function welch_t_test(samples_list)
    local welcht_results = welcht(samples_list)
    local comparisons = convert_welcht_results(welcht_results)
    local groups = create_compact_letter_groups(comparisons, samples_list)

    return {
        name = "Welch's t-test with Holm correction",
        algorithm = 'welch-t-test-holm-correction',
        description = "Each sample group is compared against every other sample group with adjusted p-values to control family-wise error rate",
        clustering = "Overlapping compact letter display: cases share a letter exactly when their Holm-adjusted comparison is non-significant at the 5% level. Sharing a letter does not establish statistical equivalence.",
        pairs = comparisons,
        groups = groups,
    }
end

return welch_t_test
