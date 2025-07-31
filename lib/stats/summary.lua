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
-- Core C modules
local mean = require('measure.stats.mean')
local stddev = require('measure.stats.stddev')
local variance = require('measure.stats.variance')

-- Lua modules
local median = require('measure.stats.median')
local p25 = require('measure.stats.p25')
local p75 = require('measure.stats.p75')
local p95 = require('measure.stats.p95')
local p99 = require('measure.stats.p99')
local stderr = require('measure.stats.stderr')
local cv = require('measure.stats.cv')
local iqr = require('measure.stats.iqr')
local throughput = require('measure.stats.throughput')

--- Calculates comprehensive summary statistics from samples
--- @param samples measure.samples An instance of measure.samples
--- @return table Summary statistics containing all key metrics
local function summary(samples)
    return {
        mean = mean(samples),
        stddev = stddev(samples),
        stderr = stderr(samples),
        variance = variance(samples),
        cv = cv(samples),
        iqr = iqr(samples),
        min = samples:min(),
        max = samples:max(),
        p25 = p25(samples),
        p50 = median(samples),
        p75 = p75(samples),
        p95 = p95(samples),
        p99 = p99(samples),
        throughput = throughput(samples),
    }
end

return summary
