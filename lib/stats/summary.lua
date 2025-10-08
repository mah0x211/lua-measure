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
local stats_outliers = require('measure.stats.outliers')
local stats_ci = require('measure.stats.ci')

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

--- Helper function to calculate outlier result
--- @param samples measure.samples An instance of measure.samples
--- @return table Outlier result containing count, percentage, and indices
local function calculate_outlier_result(samples)
    local outliers, err = stats_outliers(samples)
    if err then
        -- Handle error case (e.g., insufficient samples)
        return {
            count = 0,
            percentage = 0,
            indices = {},
        }
    end

    -- Process outlier indices (guaranteed to exist when no error)
    local outlier_count = #outliers
    return {
        count = outlier_count,
        percentage = outlier_count > 0 and (outlier_count / #samples * 100) or 0,
        indices = outliers,
    }
end

--- @class measure.stat.summary
--- @field name string Name of the benchmark
--- @field mean number Mean execution time
--- @field median number Median execution time
--- @field stddev number Standard deviation of execution times
--- @field variance number Variance of execution times
--- @field min number Minimum execution time
--- @field max number Maximum execution time
--- @field p25 number 25th percentile execution time
--- @field p75 number 75th percentile execution time
--- @field p95 number 95th percentile execution time
--- @field p99 number 99th percentile execution time
--- @field iqr number Interquartile range (p75 - p25)
--- @field cv number Coefficient of variation (stddev / mean)
--- @field throughput number Throughput (operations per second)
--- @field memstat table Memory statistics (allocated, peak, etc.)
--- @field ci_lower number Lower bound of the confidence interval
--- @field ci_upper number Upper bound of the confidence interval
--- @field ci_width number Width of the confidence interval (ci_upper - ci_lower)
--- @field ci_level number Confidence level (e.g., 95 for 95%)
--- @field rciw number Relative confidence interval width (ci_width / mean * 100)
--- @field ci_quality string Quality of the confidence interval (excellent, good, acceptable, poor)
--- @field outliers table Outlier statistics (count, percentage, indices)
--- @field sample_count number Number of samples collected
--- @field gc_step number Garbage collection step used during sampling
--- @field cl number Confidence level used during sampling
--- @field target_rciw number Target relative confidence interval width used during sampling
--- @field quality string Overall quality assessment (excellent, good, acceptable, poor)
--- @field quality_score number Overall quality score (0.0 to 1.0)

--- Calculates comprehensive summary statistics from samples
--- @param samples measure.samples An instance of measure.samples
--- @return measure.stat.summary summary statistics containing all key metrics
local function summary(samples)
    local sample_count = #samples

    -- Calculate confidence interval
    local ci = stats_ci(samples)

    -- Calculate outliers
    local outliers = calculate_outlier_result(samples)

    -- Cache percentile calculations to avoid expensive recalculations
    local p25 = samples:percentile(25)
    local p75 = samples:percentile(75)
    -- Add quality assessment
    local quality, score = assess_quality(ci.quality, outliers.percentage or 0,
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
        memstat = samples:memstat(),
        ci_lower = ci.lower,
        ci_upper = ci.upper,
        ci_width = ci.upper - ci.lower,
        ci_level = ci.level,
        rciw = ci.rciw,
        ci_quality = ci.quality,
        outliers = outliers,
        sample_count = sample_count,
        gc_step = samples:gc_step(),
        cl = samples:cl(),
        target_rciw = samples:rciw(),
        quality = quality,
        quality_score = score,
    }
end

return summary
