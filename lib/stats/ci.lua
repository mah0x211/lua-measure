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
local abs = math.abs
local exp = math.exp
local sqrt = math.sqrt
local min = math.min
local max = math.max
local ceil = math.ceil
local mean = require('measure.stats.mean')
local stddev = require('measure.stats.stddev')
local cv = require('measure.stats.cv')

-- Constants for statistical calculations
local STATS_EPSILON = 1e-15
local MIN_SAMPLE_SIZE = 100 -- Minimum sample size

-- Confidence levels
local CONFIDENCE_LEVEL_90 = 0.90
local CONFIDENCE_LEVEL_95 = 0.95
local CONFIDENCE_LEVEL_99 = 0.99

-- Quality assessment thresholds based on RCIW (%)
local QUALITY_EXCELLENT = 2.0 -- Bootstrap-equivalent precision
local QUALITY_GOOD = 5.0 -- Practical precision (recommended default)
local QUALITY_ACCEPTABLE = 10.0 -- Minimum acceptable level

-- T-distribution critical values for common confidence levels
-- Indexed by degrees of freedom (df = n - 1)
-- For df >= 30, use normal distribution approximation
local t_table = {
    {
        df = 1,
        t_90 = 6.314,
        t_95 = 12.706,
        t_99 = 63.657,
    },
    {
        df = 2,
        t_90 = 2.920,
        t_95 = 4.303,
        t_99 = 9.925,
    },
    {
        df = 3,
        t_90 = 2.353,
        t_95 = 3.182,
        t_99 = 5.841,
    },
    {
        df = 4,
        t_90 = 2.132,
        t_95 = 2.776,
        t_99 = 4.604,
    },
    {
        df = 5,
        t_90 = 2.015,
        t_95 = 2.571,
        t_99 = 4.032,
    },
    {
        df = 6,
        t_90 = 1.943,
        t_95 = 2.447,
        t_99 = 3.707,
    },
    {
        df = 7,
        t_90 = 1.895,
        t_95 = 2.365,
        t_99 = 3.499,
    },
    {
        df = 8,
        t_90 = 1.860,
        t_95 = 2.306,
        t_99 = 3.355,
    },
    {
        df = 9,
        t_90 = 1.833,
        t_95 = 2.262,
        t_99 = 3.250,
    },
    {
        df = 10,
        t_90 = 1.812,
        t_95 = 2.228,
        t_99 = 3.169,
    },
    {
        df = 11,
        t_90 = 1.796,
        t_95 = 2.201,
        t_99 = 3.106,
    },
    {
        df = 12,
        t_90 = 1.782,
        t_95 = 2.179,
        t_99 = 3.055,
    },
    {
        df = 13,
        t_90 = 1.771,
        t_95 = 2.160,
        t_99 = 3.012,
    },
    {
        df = 14,
        t_90 = 1.761,
        t_95 = 2.145,
        t_99 = 2.977,
    },
    {
        df = 15,
        t_90 = 1.753,
        t_95 = 2.131,
        t_99 = 2.947,
    },
    {
        df = 16,
        t_90 = 1.746,
        t_95 = 2.120,
        t_99 = 2.921,
    },
    {
        df = 17,
        t_90 = 1.740,
        t_95 = 2.110,
        t_99 = 2.898,
    },
    {
        df = 18,
        t_90 = 1.734,
        t_95 = 2.101,
        t_99 = 2.878,
    },
    {
        df = 19,
        t_90 = 1.729,
        t_95 = 2.093,
        t_99 = 2.861,
    },
    {
        df = 20,
        t_90 = 1.725,
        t_95 = 2.086,
        t_99 = 2.845,
    },
    {
        df = 21,
        t_90 = 1.721,
        t_95 = 2.080,
        t_99 = 2.831,
    },
    {
        df = 22,
        t_90 = 1.717,
        t_95 = 2.074,
        t_99 = 2.819,
    },
    {
        df = 23,
        t_90 = 1.714,
        t_95 = 2.069,
        t_99 = 2.807,
    },
    {
        df = 24,
        t_90 = 1.711,
        t_95 = 2.064,
        t_99 = 2.797,
    },
    {
        df = 25,
        t_90 = 1.708,
        t_95 = 2.060,
        t_99 = 2.787,
    },
    {
        df = 26,
        t_90 = 1.706,
        t_95 = 2.056,
        t_99 = 2.779,
    },
    {
        df = 27,
        t_90 = 1.703,
        t_95 = 2.052,
        t_99 = 2.771,
    },
    {
        df = 28,
        t_90 = 1.701,
        t_95 = 2.048,
        t_99 = 2.763,
    },
    {
        df = 29,
        t_90 = 1.699,
        t_95 = 2.045,
        t_99 = 2.756,
    },
    {
        df = 30,
        t_90 = 1.697,
        t_95 = 2.042,
        t_99 = 2.750,
    },
}

-- Helper function to get t-value for given confidence level and degrees of freedom
local function get_t_value(df, confidence_level)
    -- For large samples (df >= 30), use normal distribution approximation
    if df >= 30 then
        if confidence_level >= CONFIDENCE_LEVEL_99 then
            return 2.576
        end
        if confidence_level >= CONFIDENCE_LEVEL_95 then
            return 1.96
        end
        if confidence_level >= CONFIDENCE_LEVEL_90 then
            return 1.645
        end
        return 1.0
    end

    -- Use t-table for small samples
    if df == 0 then
        df = 1 -- Minimum df = 1
    end
    if df > 30 then
        df = 30 -- Cap at 30
    end

    local row = t_table[df]
    if confidence_level >= CONFIDENCE_LEVEL_99 then
        return row.t_99
    end
    if confidence_level >= CONFIDENCE_LEVEL_95 then
        return row.t_95
    end
    if confidence_level >= CONFIDENCE_LEVEL_90 then
        return row.t_90
    end

    -- For other confidence levels, interpolate between 90% and 95%
    if confidence_level > CONFIDENCE_LEVEL_90 and confidence_level <
        CONFIDENCE_LEVEL_95 then
        local t90 = row.t_90
        local t95 = row.t_95
        local ratio = (confidence_level - CONFIDENCE_LEVEL_90) /
                          (CONFIDENCE_LEVEL_95 - CONFIDENCE_LEVEL_90)
        return t90 + ratio * (t95 - t90)
    end

    return row.t_90 -- Default to 90%
end

-- NaN value for error handling
local NaN = 0 / 0

--- Checks if a value is NaN (Not a Number)
--- @param v any The value to check
--- @return boolean ok true if the value is NaN, false otherwise
local function is_nan(v)
    return not v or v ~= v
end

-- Helper function to calculate standard error
local function calculate_stderr(samples)
    local std = stddev(samples)
    if is_nan(std) then
        return NaN
    end

    local count = #samples
    if count <= 1 then
        return 0.0
    end

    return std / sqrt(count)
end

-- Helper functions for quality assessment and resampling

--- Classify measurement quality based on RCIW value
--- @param rciw number Relative Confidence Interval Width (%)
--- @return string quality classification
local function classify_quality(rciw)
    if is_nan(rciw) then
        return "unknown"
    end

    if rciw <= QUALITY_EXCELLENT then
        return "excellent"
    elseif rciw <= QUALITY_GOOD then
        return "good"
    elseif rciw <= QUALITY_ACCEPTABLE then
        return "acceptable"
    else
        return "poor"
    end
end

--- Calculate recommended sample size for resampling (nil if not needed)
--- Using modern coefficient of variation (CV) based calculation
--- @param current_n number Current sample size
--- @param target_rciw number Target RCIW value (%)
--- @param confidence_level number Confidence level in ratio format (e.g., 0.95)
--- @param cv_val number Coefficient of variation
--- @return number|nil recommended sample size (nil if resampling not needed)
local function calculate_resample_size(current_n, target_rciw, confidence_level,
                                       cv_val)
    -- Calculate coefficient of variation using the CV module
    if is_nan(cv_val) then
        return MIN_SAMPLE_SIZE -- Default to minimum resample size
    end

    -- Convert RCIW from percentage to ratio
    local r = target_rciw / 100.0

    -- Get z-value for confidence level
    local z_value
    if confidence_level >= CONFIDENCE_LEVEL_99 then
        z_value = 2.576
    elseif confidence_level >= CONFIDENCE_LEVEL_95 then
        z_value = 1.96
    elseif confidence_level >= CONFIDENCE_LEVEL_90 then
        z_value = 1.645
    else
        z_value = 1.96 -- Default to 95%
    end

    -- Modern formula: n = (z * CV / r)^2
    local target_n = (z_value * cv_val / r) ^ 2

    -- Apply minimum samples for statistical validity and practical use
    target_n = max(ceil(target_n), MIN_SAMPLE_SIZE)

    -- Return nil if current samples are sufficient
    if target_n <= current_n then
        return nil
    end

    return target_n
end

--- Calculate confidence score based on statistical indicators
--- Modern approach considering statistical validity requirements
--- @param sample_size number Number of samples used
--- @param rciw number RCIW value
--- @param cv_val number Coefficient of variation
--- @return number confidence score (0.0 to 1.0)
local function calculate_confidence_score(sample_size, rciw, cv_val)
    if is_nan(rciw) then
        return 0.0
    end

    -- Sample size factor (0.0 to 0.5) - based on MIN_SAMPLES
    local size_factor = min(sample_size / MIN_SAMPLE_SIZE, 1.0) * 0.5

    -- RCIW quality factor (0.0 to 0.3)
    local quality_factor
    if rciw <= QUALITY_EXCELLENT then
        quality_factor = 0.3
    elseif rciw <= QUALITY_GOOD then
        quality_factor = 0.3 * (QUALITY_GOOD - rciw) /
                             (QUALITY_GOOD - QUALITY_EXCELLENT)
    elseif rciw <= QUALITY_ACCEPTABLE then
        quality_factor = 0.2 * (QUALITY_ACCEPTABLE - rciw) /
                             (QUALITY_ACCEPTABLE - QUALITY_GOOD)
    else
        quality_factor = max(0.05,
                             0.2 * exp(-(rciw - QUALITY_ACCEPTABLE) / 10.0))
    end

    -- CV factor (0.0 to 0.2) - penalize high variation
    local cv_factor
    if cv_val <= 0.1 then -- Very low variation
        cv_factor = 0.2
    elseif cv_val <= 0.5 then -- Moderate variation
        cv_factor = 0.2 * (0.5 - cv_val) / 0.4
    else -- High variation (common in GC environments)
        cv_factor = max(0.0, 0.1 * exp(-cv_val))
    end

    return size_factor + quality_factor + cv_factor
end

--- Calculate confidence interval for the mean using t-distribution
--- Uses appropriate t-values based on degrees of freedom for small samples,
--- normal distribution approximation for large samples (n >= 30)
--- @param samples measure.samples An instance of measure.samples with cl() and rciw() methods
--- @return table confidence_interval_t structure with comprehensive quality assessment
local function confidence_interval(samples)
    -- Use confidence_level from options if provided, otherwise from samples
    local level = samples:cl()
    -- Use target_rciw from options if provided, otherwise from samples
    local target_rciw = samples:rciw()
    local result = {
        lower = NaN, -- Lower bound of confidence interval
        upper = NaN, -- Upper bound of confidence interval
        level = level, -- Confidence level (e.g., 95 for 95%)
        rciw = NaN, -- Relative Confidence Interval Width (%)
        sample_size = samples and #samples or 0, -- Number of samples used for calculation
        quality = "unknown", -- Quality classification: excellent/good/acceptable/poor/unknown
        resample_size = nil, -- Recommended sample size for resampling (nil if not needed)
        confidence_score = 0.0, -- Statistical confidence score (0.0-1.0)
    }
    local confidence_level = level / 100.0

    -- Basic validation
    if #samples < MIN_SAMPLE_SIZE then
        -- Not enough samples for confidence interval calculation
        result.resample_size = MIN_SAMPLE_SIZE
        return result
    end

    local mean_val = mean(samples)
    local stderr_val = calculate_stderr(samples)
    local cv_val = cv(samples)
    if is_nan(mean_val) or is_nan(stderr_val) then
        return result
    end

    if stderr_val <= STATS_EPSILON then
        -- Handle edge case where standard error is zero or very small
        -- This happens when all samples have the same value
        result.lower = mean_val
        result.upper = mean_val
        result.rciw = 0.0 -- RCIW is 0% when all values are identical
    else
        -- Get appropriate t-value based on degrees of freedom
        local df = result.sample_size - 1
        local t_value = get_t_value(df, confidence_level)

        local margin = t_value * stderr_val
        result.lower = mean_val - margin
        result.upper = mean_val + margin

        -- Calculate Relative Confidence Interval Width (RCIW)
        -- RCIW = (upper - lower) / mean * 100 (%)
        -- Only calculate if mean is not zero or very small
        if abs(mean_val) > STATS_EPSILON then
            local width = result.upper - result.lower
            result.rciw = (width / abs(mean_val)) * 100.0
        else
            result.rciw = 0.0
        end

    end

    -- Calculate quality assessment
    result.quality = classify_quality(result.rciw)
    result.resample_size = calculate_resample_size(result.sample_size,
                                                   target_rciw,
                                                   confidence_level, cv_val)
    result.confidence_score = calculate_confidence_score(result.sample_size,
                                                         result.rciw, cv_val)

    return result
end

return confidence_interval
