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
local sqrt = math.sqrt
local min = math.min
local max = math.max
local ceil = math.ceil
local log = math.log
local quantile = require('measure.quantile')

-- Constants for statistical calculations
local STATS_EPSILON = 1e-15
local MIN_SAMPLE_SIZE = 30 -- Minimum sample size (CLT threshold)

-- Quality assessment thresholds based on RCIW (%)
local QUALITY_EXCELLENT = 2.0 -- RCIW ≤ 2% indicates excellent precision
local QUALITY_GOOD = 5.0 -- RCIW ≤ 5% indicates good precision (recommended default)
local QUALITY_ACCEPTABLE = 10.0 -- RCIW ≤ 10% indicates acceptable precision

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
    local std = samples:stddev()
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

--- Calculate recommended sample size for resampling based on actual measurements
--- Uses confidence interval half-width comparison for adaptive sampling
--- @param samples measure.samples Current samples data
--- @param target_rciw number Target RCIW value (%)
--- @param confidence_level number Confidence level in ratio format (e.g., 0.97)
--- @param current_mean number Current mean of samples
--- @param current_stderr number Current standard error
--- @return number|nil recommended sample size (nil if target achieved)
local function calculate_resample_size(samples, target_rciw, confidence_level,
                                       current_mean, current_stderr)
    local current_n = #samples

    -- Basic validation
    if current_n < 2 or is_nan(current_mean) or is_nan(current_stderr) then
        return MIN_SAMPLE_SIZE
    end

    -- Convert target RCIW to target margin of error
    -- RCIW = 2 * margin_of_error / mean * 100%
    -- Therefore: margin_of_error = RCIW * mean / 200
    local target_margin = target_rciw * abs(current_mean) / 200.0

    -- Get appropriate critical value (t-distribution)
    local critical_value = quantile(confidence_level)

    -- Calculate current margin of error from actual measurements
    local current_margin = critical_value * current_stderr

    -- Check if current margin of error meets the target
    if current_margin <= target_margin then
        return nil -- Target achieved, no resampling needed
    end

    -- If target not achieved, estimate required sample size
    -- Formula: n_req = (critical_value * stddev / target_margin)^2
    local current_stddev = current_stderr * sqrt(current_n)
    local raw_estimated_n = (critical_value * current_stddev / target_margin) ^
                                2

    -- Apply progressive scaling for extreme ratios to prevent unrealistic recommendations
    local current_ratio = raw_estimated_n / current_n
    local scaled_estimated_n

    if current_ratio <= 2.0 then
        -- Small increase: use as-is
        scaled_estimated_n = raw_estimated_n
    elseif current_ratio <= 5.0 then
        -- Moderate increase: slight dampening
        scaled_estimated_n = current_n * (1 + (current_ratio - 1) * 0.8)
    elseif current_ratio <= 10.0 then
        -- Large increase: moderate dampening
        scaled_estimated_n = current_n * (1 + (current_ratio - 1) * 0.5)
    else
        -- Extreme increase: heavy dampening (logarithmic scaling)
        local log_ratio = log(current_ratio)
        scaled_estimated_n = current_n * (1 + log_ratio * 2)
    end

    -- Apply minimum and reasonable upper bound
    local estimated_n = max(ceil(scaled_estimated_n), current_n + 10) -- At least 10 more samples
    estimated_n = min(estimated_n, current_n * 20) -- Cap at 20x current size
    estimated_n = min(estimated_n, 5000) -- Absolute cap at 5000 samples

    return estimated_n
end

--- Calculate confidence interval for the mean using t-distribution
--- Uses appropriate t-values based on degrees of freedom for all sample sizes
--- @param samples measure.samples An instance of measure.samples with cl() and rciw() methods
--- @return table confidence interval result with quality metrics and resampling recommendations
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
    }
    local confidence_level = level / 100.0

    -- Basic validation
    if #samples < MIN_SAMPLE_SIZE then
        -- Not enough samples for confidence interval calculation
        result.resample_size = MIN_SAMPLE_SIZE
        return result
    end

    local mean_val = samples:mean()
    local stderr_val = calculate_stderr(samples)
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
        -- Get appropriate t-value for confidence level
        local t_value = quantile(confidence_level)

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
    result.resample_size = calculate_resample_size(samples, target_rciw,
                                                   confidence_level, mean_val,
                                                   stderr_val)

    return result
end

return confidence_interval
