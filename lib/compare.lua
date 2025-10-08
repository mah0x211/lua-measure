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
-- compare.lua: Sample comparison orchestration
-- Selects and executes appropriate comparison algorithms based on sample count
-- Load comparison algorithms
local welcht_compare = require('measure.compare.welcht')
local skesd_compare = require('measure.compare.skesd')

--- @class measure.compare.result
--- @field name string Name of the comparison method
--- @field algorithm string Algorithm used
--- @field description string Description of the method
--- @field clustering string Clustering information
--- @field groups table
--- @field pairs table

--- Create result for single-sample input
--- @param sample measure.samples
--- @return measure.compare.result
local function create_single_sample_result(sample)
    local name = sample:name()
    local groups = {
        {
            rank = 1,
            names = {
                name,
            },
            members = {
                1,
            },
            mean = sample:mean(),
        },
    }
    groups[name] = groups[1] -- name to group mapping

    return {
        name = "Single sample summary",
        algorithm = 'single-sample',
        description = "Only one sample provided; pairwise comparisons are unavailable",
        clustering = "single group (no statistical comparison)",
        pairs = {},
        groups = groups,
    }
end

--- Compare multiple samples using appropriate statistical method
--- @param samples_list table Array of measure.samples objects to compare
--- @return measure.compare.result
local function compare(samples_list)
    assert(type(samples_list) == 'table' and #samples_list > 0,
           'samples_list must be a table with at least one element')

    local count = #samples_list
    if count > 5 then
        -- Use Scott-Knott ESD for 6+ groups (better handling of multiple comparisons)
        return skesd_compare(samples_list)
    elseif count > 1 then
        -- Use Welch t-test with Holm correction for ≤5 groups (higher statistical power)
        return welcht_compare(samples_list)
    end
    return create_single_sample_result(samples_list[1])
end

return compare
