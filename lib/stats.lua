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
-- stats.lua: Statistical analysis module for multiple sample groups
-- Provides statistical summaries and optional pairwise comparison
local type = type
local summary = require('measure.stats.summary')
local compare = require('measure.compare')

--- @class measure.stats
--- @field summaries measure.stat.summary[] A list of statistical summaries for each sample
--- @field comparison measure.compare.result The result of pairwise comparisons between samples

--- Calculate comprehensive statistics for one or more sample groups
--- @param samples_list measure.samples[] A list of samples
--- @return measure.stats A table containing statistical summaries and pairwise comparison results
local function stats(samples_list)
    if type(samples_list) ~= 'table' or #samples_list < 1 then
        error('stats requires at least 1 sample group')
    end

    local summaries = {}
    for _, samples in ipairs(samples_list) do
        summaries[#summaries + 1] = summary(samples)
    end

    return {
        summaries = summaries,
        comparison = compare(samples_list),
    }
end

return stats
