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
-- Load required modules
local outliers = require('measure.stats.outliers')
local ci = require('measure.stats.ci')

-- Helper function to assess overall quality
local function assess_quality(ci_quality, outlier_percentage, sample_count)
    local scores = {}

    -- CI quality score
    if ci_quality == "excellent" then
        scores.ci = 1.0
    elseif ci_quality == "good" then
        scores.ci = 0.8
    elseif ci_quality == "acceptable" then
        scores.ci = 0.6
    elseif ci_quality == "poor" then
        scores.ci = 0.3
    else
        scores.ci = 0.0
    end

    -- Outlier score
    if outlier_percentage <= 1.0 then
        scores.outliers = 1.0
    elseif outlier_percentage <= 3.0 then
        scores.outliers = 0.8
    elseif outlier_percentage <= 7.0 then
        scores.outliers = 0.6
    elseif outlier_percentage <= 15.0 then
        scores.outliers = 0.4
    else
        scores.outliers = 0.2
    end

    -- Sample size score
    if sample_count >= 1000 then
        scores.sample_size = 1.0
    elseif sample_count >= 500 then
        scores.sample_size = 0.9
    elseif sample_count >= 200 then
        scores.sample_size = 0.7
    elseif sample_count >= 100 then
        scores.sample_size = 0.5
    else
        scores.sample_size = 0.3
    end

    -- Calculate weighted average
    local overall_score = (scores.ci * 0.5 + scores.outliers * 0.3 +
                              scores.sample_size * 0.2)

    -- Determine overall quality
    local quality
    if overall_score >= 0.9 then
        quality = "excellent"
    elseif overall_score >= 0.7 then
        quality = "good"
    elseif overall_score >= 0.5 then
        quality = "acceptable"
    else
        quality = "poor"
    end

    return quality, overall_score
end

-- Helper function to calculate memory per operation
local function calculate_memory_per_op(samples)
    local sample_data = samples:dump()
    if not sample_data or sample_data.count == 0 then
        return 0
    end

    local total_allocated = 0
    for i = 1, sample_data.count do
        total_allocated = total_allocated + (sample_data.allocated_kb[i] or 0)
    end

    return total_allocated / sample_data.count
end

--- Calculates comprehensive summary statistics from samples
--- @param samples measure.samples An instance of measure.samples
--- @return table Comprehensive summary statistics containing all key metrics
local function summary(samples)
    -- Calculate confidence interval
    local ci_result = ci(samples)

    -- Calculate outliers
    -- Note: outliers detection requires at least 4 samples for Tukey method
    local outlier_result
    local sample_count = #samples
    if sample_count >= 4 then
        local ok = pcall(function()
            outlier_result = outliers(samples)
        end)
        if not ok then
            -- Fallback if outliers detection fails
            outlier_result = {
                mild = 0,
                severe = 0,
                percentage = 0,
            }
        end
    else
        -- Not enough samples for outlier detection
        outlier_result = {
            mild = 0,
            severe = 0,
            percentage = 0,
        }
    end

    -- Calculate memory usage per operation
    local memory_per_op = calculate_memory_per_op(samples)
    -- Cache percentile calculations to avoid expensive recalculations
    local p25 = samples:percentile(25)
    local p75 = samples:percentile(75)
    -- Add quality assessment
    local quality, score = assess_quality(ci_result.quality,
                                          outlier_result.percentage or 0,
                                          sample_count)

    return {
        name = samples:name(),
        mean = samples:mean(),
        median = samples:percentile(50),
        stddev = samples:stddev(),
        variance = samples:variance(),
        min = samples:min(),
        max = samples:max(),
        p25 = p25,
        p75 = p75,
        p95 = samples:percentile(95),
        p99 = samples:percentile(99),
        iqr = p75 - p25,
        cv = samples:cv(),
        throughput = samples:throughput(),
        memory_per_op = memory_per_op,
        ci_lower = ci_result.lower,
        ci_upper = ci_result.upper,
        ci_width = ci_result.upper - ci_result.lower,
        ci_level = ci_result.level,
        rciw = ci_result.rciw,
        ci_quality = ci_result.quality,
        outliers = {
            mild = outlier_result.mild or 0,
            severe = outlier_result.severe or 0,
            total = (outlier_result.mild or 0) + (outlier_result.severe or 0),
            percentage = outlier_result.percentage or 0,
        },
        sample_count = sample_count,
        gc_step = samples:gc_step(),
        cl = samples:cl(),
        target_rciw = samples:rciw(),
        quality = quality,
        quality_score = score,
    }
end

return summary
