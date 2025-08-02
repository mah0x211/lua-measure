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
local quantile = require('measure.quantile')

-- Constants for statistical calculations
local STATS_EPSILON = 1e-15
local MIN_SAMPLE_SIZE = 100 -- Minimum sample size

-- Quality assessment thresholds based on RCIW (%)
local QUALITY_EXCELLENT = 2.0 -- Bootstrap-equivalent precision
local QUALITY_GOOD = 5.0 -- Practical precision (recommended default)
local QUALITY_ACCEPTABLE = 10.0 -- Minimum acceptable level

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
--- Uses real-time half-width comparison for adaptive sampling (ChatGPT o3 approach)
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

    -- Convert target RCIW to target half-width (δ)
    -- RCIW = 2 * half-width / mean * 100%
    -- Therefore: half-width = RCIW * mean / 200
    local target_half_width = target_rciw * abs(current_mean) / 200.0

    -- Get appropriate critical value (t or z)
    local critical_value = quantile(confidence_level)

    -- Calculate current half-width from actual measurements
    local current_half_width = critical_value * current_stderr

    -- ChatGPT o3 stopping condition: half <= delta
    if current_half_width <= target_half_width then
        return nil -- Target achieved, no resampling needed
    end

    -- If target not achieved, estimate required sample size
    -- Formula: n_req = (critical_value * stddev / target_half_width)^2
    local current_stddev = current_stderr * sqrt(current_n)
    local estimated_n = (critical_value * current_stddev / target_half_width) ^
                            2

    -- Apply minimum and reasonable upper bound
    estimated_n = max(ceil(estimated_n), current_n + 30) -- At least 30 more samples
    estimated_n = min(estimated_n, 10000) -- Cap at 10000 samples

    return estimated_n
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

    local mean_val = samples:mean()
    local stderr_val = calculate_stderr(samples)
    local cv_val = samples:cv()
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
    result.confidence_score = calculate_confidence_score(result.sample_size,
                                                         result.rciw, cv_val)

    return result
end

return confidence_interval
