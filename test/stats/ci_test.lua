require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local ci = require('measure.stats.ci')
local samples = require('measure.samples')

-- Helper function to create mock samples with known time values
local function create_mock_samples(time_values)
    local count = #time_values
    local data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = count,
        count = count,
        gc_step = 0,
        base_kb = 1,
    }

    for i, time_ns in ipairs(time_values) do
        data.time_ns[i] = time_ns
        data.before_kb[i] = 0
        data.after_kb[i] = 0
        data.allocated_kb[i] = 0
    end

    local s, err = samples(data)
    if not s then
        error("Failed to create mock samples: " .. (err or "unknown error"))
    end
    return s
end

function testcase.default_level()
    -- test default 95% confidence interval
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    local result = ci(s)

    -- test basic structure
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)
    assert.is_number(result.level)
    assert.is_number(result.rciw)

    -- test new fields
    assert.is_number(result.sample_size)
    assert.is_string(result.quality)
    assert.is_number(result.confidence_score)
    -- resample_size can be nil or number
    if result.resample_size then
        assert.is_number(result.resample_size)
    end

    -- test that CI contains the mean
    local mean = 1000 + (100 - 1) * 50 / 2 -- average of 1000 to 5950
    assert.less(result.lower, mean)
    assert.greater(result.upper, mean)
    assert.equal(result.level, 0.95)

    -- test that RCIW is positive and reasonable
    assert.greater(result.rciw, 0)
    assert.less(result.rciw, 100) -- should be less than 100% for reasonable data

    -- test new functionality
    assert.equal(result.sample_size, 100)
    -- Check quality is one of the valid values
    local valid_qualities = {
        excellent = true,
        good = true,
        acceptable = true,
        poor = true,
        unknown = true,
    }
    assert.is_true(valid_qualities[result.quality])
    assert.greater_or_equal(result.confidence_score, 0.0)
    assert.less_or_equal(result.confidence_score, 1.0)
end

function testcase.custom_levels()
    -- test with custom confidence levels
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    -- 90% CI
    local ci90 = ci(s, 0.90)
    assert.equal(ci90.level, 0.90)

    -- 99% CI
    local ci99 = ci(s, 0.99)
    assert.equal(ci99.level, 0.99)

    -- 99% CI should be wider than 90% CI
    local width90 = ci90.upper - ci90.lower
    local width99 = ci99.upper - ci99.lower
    assert.less(width90, width99)
end

function testcase.error_handling()
    -- test error handling with nil samples (Lua implementation returns NaN)
    local result = ci(nil)

    assert.is_table(result)
    -- check for NaN in lower and upper bounds
    assert.is_nan(result.lower)
    assert.is_nan(result.upper)

    -- test error handling with invalid confidence level
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 100
    end
    local s = create_mock_samples(time_values)
    -- Should throw assertion error for invalid level > 1
    assert.throws(function()
        ci(s, 1.5) -- invalid level > 1
    end)
end

function testcase.large_samples()
    -- test with large samples (df >= 30) for normal distribution approximation
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 10
    end
    local s = create_mock_samples(time_values)

    -- 99% CI should use normal approximation (2.576)
    local ci99 = ci(s, 0.99)
    assert.is_table(ci99)
    assert.is_number(ci99.lower)
    assert.is_number(ci99.upper)
    assert.equal(ci99.level, 0.99)

    -- 95% CI should use normal approximation (1.96)
    local ci95 = ci(s, 0.95)
    assert.is_table(ci95)
    assert.is_number(ci95.lower)
    assert.is_number(ci95.upper)

    -- 90% CI should use normal approximation (1.645)
    local ci90 = ci(s, 0.90)
    assert.is_table(ci90)
    assert.is_number(ci90.lower)
    assert.is_number(ci90.upper)

    -- test other confidence level that defaults to 1.0
    local ci50 = ci(s, 0.50)
    assert.is_table(ci50)
    assert.is_number(ci50.lower)
    assert.is_number(ci50.upper)
end

function testcase.interpolation()
    -- test confidence level interpolation between 90% and 95%
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    local ci92 = ci(s, 0.92) -- between 90% and 95%
    assert.is_table(ci92)
    assert.is_number(ci92.lower)
    assert.is_number(ci92.upper)
    assert.equal(ci92.level, 0.92)
end

function testcase.identical_values()
    -- test with identical values (stderr = 0)
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000
    end
    local s = create_mock_samples(time_values)

    local result = ci(s)
    assert.is_table(result)
    assert.equal(result.lower, 1000) -- should equal mean
    assert.equal(result.upper, 1000) -- should equal mean
    assert.equal(result.rciw, 0.0) -- RCIW should be 0% for identical values
end

function testcase.single_sample()
    -- test with single sample (should fail due to MIN_SAMPLE_SIZE = 100)
    local s = create_mock_samples({
        1000,
    })

    local result = ci(s)
    assert.is_table(result)
    assert.is_nan(result.lower)
    assert.is_nan(result.upper)
    -- Should recommend resampling to MIN_SAMPLE_SIZE
    assert.equal(result.resample_size, 100)
end

function testcase.edge_cases()
    -- test confidence level edge cases
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 100
    end
    local s = create_mock_samples(time_values)

    -- test confidence level = 0 (invalid) - should throw error
    assert.throws(function()
        ci(s, 0.0)
    end)

    -- test confidence level = 1.0 (invalid) - should throw error
    assert.throws(function()
        ci(s, 1.0)
    end)

    -- test very low confidence level (valid)
    local result3 = ci(s, 0.1)
    assert.is_table(result3)
    assert.is_number(result3.lower)
    assert.is_number(result3.upper)
end

function testcase.interpolation_detailed()
    -- test confidence level interpolation between 90% and 95%
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    -- test that 92% CI is computed (should trigger lines 112-115 if between 90% and 95%)
    local ci92 = ci(s, 0.92)
    assert.is_table(ci92)
    assert.is_number(ci92.lower)
    assert.is_number(ci92.upper)
    assert.equal(ci92.level, 0.92)

    -- For this test, we just verify the interpolation code path exists
    -- The actual interpolation might not be triggered due to the confidence level logic
    -- Let's test a different confidence level that will trigger interpolation
    local ci91 = ci(s, 0.91) -- between 90% and 95%
    assert.is_table(ci91)
    assert.is_number(ci91.lower)
    assert.is_number(ci91.upper)
    assert.equal(ci91.level, 0.91)

    -- Verify that different confidence levels produce different results
    local ci90 = ci(s, 0.90)
    local ci95 = ci(s, 0.95)

    -- 95% CI should be wider than 90% CI
    local width90 = ci90.upper - ci90.lower
    local width95 = ci95.upper - ci95.lower
    assert.greater(width95, width90)
end

function testcase.extreme_df_cases()
    -- test extreme degrees of freedom cases

    -- Test very large sample (df > 30) with more than 100 samples
    local large_time_values = {}
    for i = 1, 150 do -- df = 149 > 30
        large_time_values[i] = 1000 + i
    end
    local large_s = create_mock_samples(large_time_values)

    -- test that it uses normal approximation for df > 30
    local ci_large = ci(large_s, 0.95)
    assert.is_table(ci_large)
    assert.is_number(ci_large.lower)
    assert.is_number(ci_large.upper)
end

function testcase.interpolation_trigger()
    -- Force interpolation code path
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    -- Test confidence level exactly between 90% and 95% to trigger interpolation
    local ci92 = ci(s, 0.92) -- should trigger interpolation
    assert.is_table(ci92)
    assert.is_number(ci92.lower)
    assert.is_number(ci92.upper)
    assert.equal(ci92.level, 0.92)
end

function testcase.extreme_edge_cases()
    -- Test minimum sample count that passes validation
    local time_values = {}
    for i = 1, 100 do -- Now using MIN_SAMPLE_SIZE = 100
        time_values[i] = 1000 + i * 100
    end
    local s = create_mock_samples(time_values)
    local result = ci(s, 0.95)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)

    -- Test with invalid small sample count to trigger early return
    local s_small = create_mock_samples({
        1000,
    }) -- count = 1 < MIN_SAMPLE_SIZE
    local result_small = ci(s_small)
    assert.is_table(result_small)
    assert.is_nan(result_small.lower)
    assert.is_nan(result_small.upper)
    -- Should recommend resampling to MIN_SAMPLE_SIZE
    assert.equal(result_small.resample_size, 100)
end

function testcase.force_interpolation()
    -- Force interpolation code path by testing confidence level between 90% and 95%
    -- Still use exactly 100 samples to test t-table usage
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    -- Test confidence levels that should fall into the interpolation range
    -- The condition is: confidence_level > 0.90 AND confidence_level < 0.95
    local ci921 = ci(s, 0.921) -- between 90% and 95%
    assert.is_table(ci921)
    assert.is_number(ci921.lower)
    assert.is_number(ci921.upper)
    assert.equal(ci921.level, 0.921)

    local ci935 = ci(s, 0.935) -- another interpolation test
    assert.is_table(ci935)
    assert.is_number(ci935.lower)
    assert.is_number(ci935.upper)
    assert.equal(ci935.level, 0.935)

    -- Test edge case: exactly at boundaries (should NOT trigger interpolation)
    local ci90 = ci(s, 0.90) -- exactly 90%
    assert.is_table(ci90)
    assert.is_number(ci90.lower)
    assert.is_number(ci90.upper)

    local ci95 = ci(s, 0.95) -- exactly 95%
    assert.is_table(ci95)
    assert.is_number(ci95.lower)
    assert.is_number(ci95.upper)
end

function testcase.large_df_cap()
    -- Test very large degrees of freedom (df > 30) to trigger df capping
    local large_time_values = {}
    for i = 1, 150 do -- df = 149 > 30, should be capped to 30
        large_time_values[i] = 1000 + i
    end
    local s = create_mock_samples(large_time_values)

    -- Test various confidence levels to ensure df capping works
    local ci90 = ci(s, 0.90)
    assert.is_table(ci90)
    assert.is_number(ci90.lower)
    assert.is_number(ci90.upper)

    local ci95 = ci(s, 0.95)
    assert.is_table(ci95)
    assert.is_number(ci95.lower)
    assert.is_number(ci95.upper)

    local ci99 = ci(s, 0.99)
    assert.is_table(ci99)
    assert.is_number(ci99.lower)
    assert.is_number(ci99.upper)
end

function testcase.rciw_calculation()
    -- Test Relative Confidence Interval Width (RCIW) calculation
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 20
    end
    local s = create_mock_samples(time_values)

    local result = ci(s, 0.95)
    assert.is_table(result)
    assert.is_number(result.rciw)
    assert.greater(result.rciw, 0)

    -- RCIW should be: (upper - lower) / mean * 100
    local width = result.upper - result.lower
    -- Calculate mean for 100 samples: 1000, 1020, 1040, ..., 2980
    local sum = 0
    for i = 1, 100 do
        sum = sum + (1000 + (i - 1) * 20)
    end
    local mean = sum / 100
    local expected_rciw = (width / mean) * 100

    -- Allow for small floating point differences
    assert.less(math.abs(result.rciw - expected_rciw), 0.001)
end

function testcase.rciw_wider_intervals()
    -- Test that wider confidence intervals have higher RCIW values
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    local ci90 = ci(s, 0.90)
    local ci95 = ci(s, 0.95)
    local ci99 = ci(s, 0.99)

    -- Higher confidence levels should have wider intervals and higher RCIW
    assert.greater(ci95.rciw, ci90.rciw)
    assert.greater(ci99.rciw, ci95.rciw)
end

function testcase.rciw_error_cases()
    -- Test RCIW with error cases
    local result = ci(nil)
    assert.is_table(result)
    assert.is_nan(result.rciw)

    -- Test with invalid confidence level - should throw error
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 100
    end
    local s = create_mock_samples(time_values)
    assert.throws(function()
        ci(s, 1.5)
    end)

    -- Test with insufficient samples
    local s_single = create_mock_samples({
        1000,
    })
    local result3 = ci(s_single)
    assert.is_table(result3)
    assert.is_nan(result3.rciw)
    -- Should recommend resampling to MIN_SAMPLE_SIZE
    assert.equal(result3.resample_size, 100)
end

function testcase.rciw_zero_mean_edge_case()
    -- Test RCIW when mean is very close to zero (using very small positive values)
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = i - 1 -- 0 to 99 (integers)
    end
    local s = create_mock_samples(time_values)

    local result = ci(s, 0.95)
    assert.is_table(result)
    assert.is_number(result.rciw)
    -- When mean is very small, RCIW should still be calculated
    assert.greater(result.rciw, 0.0)
end

function testcase.rciw_very_small_mean()
    -- Test RCIW when mean is extremely small but non-zero
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = i -- 1 to 100 (small integers)
    end
    local s = create_mock_samples(time_values)

    local result = ci(s, 0.95)
    assert.is_table(result)
    assert.is_number(result.rciw)
    -- For very small means, RCIW should be properly calculated
    assert.greater(result.rciw, 0.0)
end

-- Test cases for new quality assessment features

function testcase.quality_classification()
    -- Test quality classification with different RCIW values

    -- Excellent quality (small variation)
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) -- Very small variation (1 unit)
    end
    local s_excellent = create_mock_samples(time_values)
    local result_excellent = ci(s_excellent)
    assert.less(result_excellent.rciw, 2.1) -- Should be excellent
    assert.equal(result_excellent.quality, "excellent")

    -- Good quality
    local time_values_good = {}
    for i = 1, 100 do
        time_values_good[i] = 1000 + (i - 1) * 10 -- Moderate variation
    end
    local s_good = create_mock_samples(time_values_good)
    local result_good = ci(s_good)
    local valid_qualities = {
        excellent = true,
        good = true,
        acceptable = true,
        poor = true,
        unknown = true,
    }
    assert.is_true(valid_qualities[result_good.quality])

    -- Poor quality (high variation)
    local time_values_poor = {}
    for i = 1, 100 do
        time_values_poor[i] = 1000 + (i - 1) * 100 -- High variation
    end
    local s_poor = create_mock_samples(time_values_poor)
    local result_poor = ci(s_poor)
    assert.greater(result_poor.rciw, 10.0) -- Should be poor
    assert.equal(result_poor.quality, "poor")
end

function testcase.resampling_recommendations()
    -- Test resampling recommendation logic

    -- High quality data should not recommend resampling
    local time_values_good = {}
    for i = 1, 100 do
        time_values_good[i] = 1000 + (i - 1) -- Very small variation (1 unit)
    end
    local s_good = create_mock_samples(time_values_good)
    local result_good = ci(s_good)
    -- For good quality data, resample_size should be nil (no resampling needed)
    assert.is_nil(result_good.resample_size)

    -- Poor quality data should recommend resampling
    local time_values_poor = {}
    for i = 1, 100 do
        time_values_poor[i] = 1000 + (i - 1) * 100 -- High variation
    end
    local s_poor = create_mock_samples(time_values_poor)
    local result_poor = ci(s_poor)
    assert.is_number(result_poor.resample_size)
    assert.greater(result_poor.resample_size, result_poor.sample_size)
end

function testcase.custom_target_rciw()
    -- Test custom target RCIW option
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    -- Test with strict target (2%)
    local result_strict = ci(s, 0.95, 2.0)
    assert.is_table(result_strict)

    -- Test with loose target (15%)
    local result_loose = ci(s, 0.95, 15.0)
    assert.is_table(result_loose)

    -- Strict target should be more likely to recommend resampling
    if result_strict.rciw > 2.0 then
        assert.is_number(result_strict.resample_size)
    end
    if result_loose.rciw <= 15.0 then
        assert.is_nil(result_loose.resample_size)
    end
end

function testcase.confidence_score_ranges()
    -- Test confidence score calculation

    -- Large sample with good precision should have high confidence
    local large_good = {}
    for i = 1, 200 do
        large_good[i] = 1000 + (i % 10) -- Small variation
    end
    local s_large_good = create_mock_samples(large_good)
    local result_large_good = ci(s_large_good)
    assert.greater(result_large_good.confidence_score, 0.5)

    -- Small sample with poor precision should have low confidence
    local time_values_poor = {}
    for i = 1, 100 do -- Minimum required samples
        time_values_poor[i] = 1000 + (i - 1) * 100 -- High variation
    end
    local s_small_poor = create_mock_samples(time_values_poor)
    local result_small_poor = ci(s_small_poor)
    assert.less(result_small_poor.confidence_score, 0.7)
end

function testcase.resample_target_calculation()
    -- Test resample target calculation logic
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values)

    local result = ci(s, 0.95, 2.0)
    assert.is_table(result)

    if result.resample_size then
        -- Resample size should be at least minimum sample size (100)
        assert.greater_or_equal(result.resample_size, 100)
    end
end

function testcase.identical_values_quality()
    -- Test quality assessment for identical values
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 -- All identical
    end
    local s_identical = create_mock_samples(time_values)

    local result = ci(s_identical)
    assert.equal(result.rciw, 0.0)
    assert.equal(result.quality, "excellent")
    -- For identical values with 100 samples, resample_size should be nil (no resampling needed)
    assert.is_nil(result.resample_size)
    assert.greater(result.confidence_score, 0.2) -- Moderate confidence even for consistent data
end
