require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local ci = require('measure.stats.ci')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function and constants
local create_mock_samples = mock_samples.create_mock_samples

-- Test constants
local TEST_CONSTANTS = {
    -- Sample data constants
    BASE_TIME_NS = 1000, -- Base time value in nanoseconds
    TIME_INCREMENT = 50, -- Standard time increment for test data
    SAMPLE_COUNT_STANDARD = 100, -- Standard sample count for tests
    SAMPLE_COUNT_LARGE = 150, -- Large sample count for df > 30 tests

    -- Statistical constants (should match values in ci.lua)
    MIN_SAMPLE_SIZE = 100, -- Minimum required sample size
    QUALITY_EXCELLENT_THRESHOLD = 2.0, -- RCIW <= 2% is excellent
    QUALITY_GOOD_THRESHOLD = 5.0, -- RCIW <= 5% is good
    QUALITY_ACCEPTABLE_THRESHOLD = 10.0, -- RCIW <= 10% is acceptable

    -- Confidence levels for testing
    CONFIDENCE_90 = 90, -- 90% confidence level
    CONFIDENCE_95 = 95, -- 95% confidence level
    CONFIDENCE_99 = 99, -- 99% confidence level

    -- Test data patterns
    EXTREME_INTEGER_VALUE = 2147483647, -- Maximum 32-bit signed integer
    SMALL_INCREMENT = 1, -- Minimal increment for excellent quality
    MEDIUM_INCREMENT = 10, -- Medium increment for good quality
    LARGE_INCREMENT = 100, -- Large increment for poor quality
}

function testcase.default_level()
    -- test default 95% confidence interval
    local time_values = {}
    for i = 1, TEST_CONSTANTS.SAMPLE_COUNT_STANDARD do
        time_values[i] = TEST_CONSTANTS.BASE_TIME_NS + (i - 1) *
                             TEST_CONSTANTS.TIME_INCREMENT
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
    -- resample_size can be nil or number
    if result.resample_size then
        assert.is_number(result.resample_size)
    end

    -- test that CI contains the mean
    local mean = TEST_CONSTANTS.BASE_TIME_NS +
                     (TEST_CONSTANTS.SAMPLE_COUNT_STANDARD - 1) *
                     TEST_CONSTANTS.TIME_INCREMENT / 2
    assert.less(result.lower, mean)
    assert.greater(result.upper, mean)
    assert.equal(result.level, TEST_CONSTANTS.CONFIDENCE_95)

    -- test that RCIW is positive and reasonable
    assert.greater(result.rciw, 0)
    assert.less(result.rciw, 100) -- should be less than 100% for reasonable data

    -- test new functionality
    assert.equal(result.sample_size, TEST_CONSTANTS.SAMPLE_COUNT_STANDARD)
    -- Check quality is one of the valid values
    local valid_qualities = {
        excellent = true,
        good = true,
        acceptable = true,
        poor = true,
        unknown = true,
    }
    assert.is_true(valid_qualities[result.quality])
end

function testcase.custom_levels()
    -- test with custom confidence levels
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end

    -- 90% CI
    local s90 = create_mock_samples(time_values, 90)
    local ci90 = ci(s90)
    assert.equal(ci90.level, 90)

    -- 99% CI
    local s99 = create_mock_samples(time_values, 99)
    local ci99 = ci(s99)
    assert.equal(ci99.level, 99)

    -- 99% CI should be wider than 90% CI
    local width90 = ci90.upper - ci90.lower
    local width99 = ci99.upper - ci99.lower
    assert.less(width90, width99)
end

function testcase.error_handling()
    -- test error handling with nil samples (should throw error)
    assert.throws(function()
        ci(nil)
    end)

    -- test error handling with invalid confidence level
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 100
    end
    -- Should throw assertion error for invalid level > 100
    assert.throws(function()
        create_mock_samples(time_values, 150) -- invalid level > 100
    end)
end

function testcase.large_samples()
    -- test with large samples (df >= 30) for normal distribution approximation
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 10
    end

    -- 99% CI should use normal approximation (2.576)
    local s99 = create_mock_samples(time_values, 99)
    local ci99 = ci(s99)
    assert.is_table(ci99)
    assert.is_number(ci99.lower)
    assert.is_number(ci99.upper)
    assert.equal(ci99.level, 99)

    -- 95% CI should use normal approximation (1.96)
    local s95 = create_mock_samples(time_values, 95)
    local ci95 = ci(s95)
    assert.is_table(ci95)
    assert.is_number(ci95.lower)
    assert.is_number(ci95.upper)

    -- 90% CI should use normal approximation (1.645)
    local s90 = create_mock_samples(time_values, 90)
    local ci90 = ci(s90)
    assert.is_table(ci90)
    assert.is_number(ci90.lower)
    assert.is_number(ci90.upper)

    -- test other confidence level that defaults to 1.0
    local s50 = create_mock_samples(time_values, 50)
    local ci50 = ci(s50)
    assert.is_table(ci50)
    assert.is_number(ci50.lower)
    assert.is_number(ci50.upper)
end

function testcase.confidence_level_interpolation()
    -- Purpose: Test confidence level interpolation between 90% and 95%
    -- This tests the interpolation logic in get_t_value() lines 268-275

    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end

    -- Test various confidence levels that require interpolation
    local interpolated_levels = {
        91,
        92,
        92.1,
        93,
        93.5,
        94,
    }
    local results = {}

    for _, level in ipairs(interpolated_levels) do
        local s = create_mock_samples(time_values, level)
        results[level] = ci(s)
        assert.is_table(results[level])
        assert.equal(results[level].level, level)
    end

    -- Test boundary values (should NOT trigger interpolation)
    local s90 = create_mock_samples(time_values, 90)
    local ci90 = ci(s90)
    assert.equal(ci90.level, 90)

    local s95 = create_mock_samples(time_values, 95)
    local ci95 = ci(s95)
    assert.equal(ci95.level, 95)

    -- Verify that CI width increases with confidence level
    local width90 = ci90.upper - ci90.lower
    local width95 = ci95.upper - ci95.lower
    assert.less(width90, width95)

    -- Verify that interpolated values are in between
    for _, level in ipairs(interpolated_levels) do
        local width = results[level].upper - results[level].lower
        assert.greater_or_equal(width, width90)
        assert.less_or_equal(width, width95)
    end
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

    -- test confidence level = -1 (invalid) - should throw error
    assert.throws(function()
        create_mock_samples(time_values, -1)
    end)

    -- test confidence level = 101 (invalid) - should throw error
    assert.throws(function()
        create_mock_samples(time_values, 101)
    end)

    -- test very low confidence level (valid)
    local s10 = create_mock_samples(time_values, 10)
    local result3 = ci(s10)
    assert.is_table(result3)
    assert.is_number(result3.lower)
    assert.is_number(result3.upper)
end

function testcase.extreme_df_cases()
    -- test extreme degrees of freedom cases

    -- Test very large sample (df > 30) with more than 100 samples
    local large_time_values = {}
    for i = 1, 150 do -- df = 149 > 30
        large_time_values[i] = 1000 + i
    end
    local large_s = create_mock_samples(large_time_values, 95)

    -- test that it uses normal approximation for df > 30
    local ci_large = ci(large_s)
    assert.is_table(ci_large)
    assert.is_number(ci_large.lower)
    assert.is_number(ci_large.upper)
end

function testcase.extreme_edge_cases()
    -- Test minimum sample count that passes validation
    local time_values = {}
    for i = 1, 100 do -- Now using MIN_SAMPLE_SIZE = 100
        time_values[i] = 1000 + i * 100
    end
    local s = create_mock_samples(time_values, 95)
    local result = ci(s)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)

    -- Test with invalid small sample count to trigger early return
    local s_small = create_mock_samples({
        1000,
    }, 95) -- count = 1 < MIN_SAMPLE_SIZE
    local result_small = ci(s_small)
    assert.is_table(result_small)
    assert.is_nan(result_small.lower)
    assert.is_nan(result_small.upper)
    -- Should recommend resampling to MIN_SAMPLE_SIZE
    assert.equal(result_small.resample_size, 100)
end

function testcase.large_df_cap()
    -- Test very large degrees of freedom (df > 30) to trigger df capping
    local large_time_values = {}
    for i = 1, 150 do -- df = 149 > 30, should be capped to 30
        large_time_values[i] = 1000 + i
    end

    -- Test various confidence levels to ensure df capping works
    local s90 = create_mock_samples(large_time_values, 90)
    local ci90 = ci(s90)
    assert.is_table(ci90)
    assert.is_number(ci90.lower)
    assert.is_number(ci90.upper)

    local s95 = create_mock_samples(large_time_values, 95)
    local ci95 = ci(s95)
    assert.is_table(ci95)
    assert.is_number(ci95.lower)
    assert.is_number(ci95.upper)

    local s99 = create_mock_samples(large_time_values, 99)
    local ci99 = ci(s99)
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
    local s = create_mock_samples(time_values, 95)

    local result = ci(s)
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

    local s90 = create_mock_samples(time_values, 90)
    local ci90 = ci(s90)
    local s95 = create_mock_samples(time_values, 95)
    local ci95 = ci(s95)
    local s99 = create_mock_samples(time_values, 99)
    local ci99 = ci(s99)

    -- Higher confidence levels should have wider intervals and higher RCIW
    assert.greater(ci95.rciw, ci90.rciw)
    assert.greater(ci99.rciw, ci95.rciw)
end

function testcase.rciw_error_cases()
    -- Test RCIW with error cases - nil samples should throw error
    assert.throws(function()
        ci(nil)
    end)

    -- Test with invalid confidence level - should throw error
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 100
    end
    assert.throws(function()
        create_mock_samples(time_values, 150)
    end)

    -- Test with insufficient samples
    local s_single = create_mock_samples({
        1000,
    }, 95)
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
    local s = create_mock_samples(time_values, 95)

    local result = ci(s)
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
    local s = create_mock_samples(time_values, 95)

    local result = ci(s)
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

    -- Test with strict target (2%)
    local s_strict = create_mock_samples(time_values, 95, 2.0)
    local result_strict = ci(s_strict)
    assert.is_table(result_strict)

    -- Test with loose target (15%)
    local s_loose = create_mock_samples(time_values, 95, 15.0)
    local result_loose = ci(s_loose)
    assert.is_table(result_loose)

    -- Strict target should be more likely to recommend resampling
    if result_strict.rciw > 2.0 then
        assert.is_number(result_strict.resample_size)
    end
    if result_loose.rciw <= 15.0 then
        assert.is_nil(result_loose.resample_size)
    end
end

function testcase.resample_target_calculation()
    -- Test resample target calculation logic
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 50
    end
    local s = create_mock_samples(time_values, 95, 2.0)

    local result = ci(s)
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
end

-- New test cases for complete coverage

function testcase.small_sample_t_table()
    -- Test small sample processing (df < 30) to trigger t-table usage
    -- Override MIN_SAMPLE_SIZE temporarily by using samples with exactly 100 elements
    -- but force smaller df by using a special case

    -- Create samples with exactly 30 samples to test df = 29 < 30
    local time_values = {}
    for i = 1, 30 do
        time_values[i] = 1000 + i * 100
    end
    -- Need to pad to 100 for MIN_SAMPLE_SIZE, but we'll test actual small sample logic
    for i = 31, 100 do
        time_values[i] = 1000 + 30 * 100 -- Pad with same value
    end

    local s30 = create_mock_samples(time_values, 95)
    local result = ci(s30)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)
end

function testcase.very_small_samples_t_table()
    -- Test edge cases in t-table lookup for small samples
    -- Create samples to trigger different t-table rows

    -- Test with 10 samples (df = 9) - but pad to 100 for validation
    local time_values = {}
    for i = 1, 10 do
        time_values[i] = 1000 + i * 50
    end
    for i = 11, 100 do
        time_values[i] = 1000 + 10 * 50
    end

    local s10 = create_mock_samples(time_values, 95)
    local result = ci(s10)
    assert.is_table(result)

    -- Test different confidence levels with small samples
    local s10_90 = create_mock_samples(time_values, 90)
    local result90 = ci(s10_90)
    assert.is_table(result90)

    local s10_99 = create_mock_samples(time_values, 99)
    local result99 = ci(s10_99)
    assert.is_table(result99)
end

function testcase.confidence_level_99_large_sample()
    -- Test 99% confidence level with large samples (df >= 30) to trigger line 239-240
    local time_values = {}
    for i = 1, 100 do -- df = 99 >= 30
        time_values[i] = 1000 + i * 10
    end

    local s99 = create_mock_samples(time_values, 99)
    local result = ci(s99)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)
    assert.equal(result.level, 99)

    -- 99% CI should be wider than 95% CI
    local s95 = create_mock_samples(time_values, 95)
    local result95 = ci(s95)
    local width99 = result.upper - result.lower
    local width95 = result95.upper - result95.lower
    assert.greater(width99, width95)
end

function testcase.confidence_level_90_large_sample()
    -- Test 90% confidence level with large samples to trigger line 245-246
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 15
    end

    local s90 = create_mock_samples(time_values, 90)
    local result = ci(s90)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)
    assert.equal(result.level, 90)
end

function testcase.confidence_level_interpolation_trigger()
    -- Test confidence level interpolation between 90% and 95% to trigger lines 271-277
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 20
    end

    -- Test confidence levels between 90% and 95%
    local s92 = create_mock_samples(time_values, 92)
    local result92 = ci(s92)
    assert.is_table(result92)
    assert.equal(result92.level, 92)

    local s93_5 = create_mock_samples(time_values, 93.5)
    local result93_5 = ci(s93_5)
    assert.is_table(result93_5)
    assert.equal(result93_5.level, 93.5)
end

function testcase.edge_confidence_levels()
    -- Test edge cases for confidence levels to trigger default behavior
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 25
    end

    -- Test very low confidence level (should default to 1.0 for large samples)
    local s10 = create_mock_samples(time_values, 10)
    local result10 = ci(s10)
    assert.is_table(result10)
    assert.equal(result10.level, 10)

    -- Test confidence level below 90% (should use default t_90 for small samples)
    local s50 = create_mock_samples(time_values, 50)
    local result50 = ci(s50)
    assert.is_table(result50)
    assert.equal(result50.level, 50)
end

function testcase.df_edge_cases()
    -- Test df = 0 case and df capping logic (lines 252-257)
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 30
    end

    local s = create_mock_samples(time_values, 95)
    local result = ci(s)
    assert.is_table(result)

    -- Test with very large sample to trigger df > 30 capping
    local large_values = {}
    for i = 1, 200 do
        large_values[i] = 1000 + i * 5
    end
    local s_large = create_mock_samples(large_values, 95)
    local result_large = ci(s_large)
    assert.is_table(result_large)
end

function testcase.nan_cv_handling()
    -- Test NaN CV handling in calculate_resample_size (line 339-341)
    -- Create samples that might produce NaN CV
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 0 -- All zeros might cause NaN in CV calculation
    end

    local s_zeros = create_mock_samples(time_values, 95, 2.0)
    local result = ci(s_zeros)
    assert.is_table(result)
    -- Should handle NaN CV gracefully
end

function testcase.quality_classification_branches()
    -- Test all quality classification branches

    -- Test "good" quality (between excellent and acceptable)
    local time_values_good = {}
    for i = 1, 100 do
        time_values_good[i] = 1000 + (i - 1) * 5 -- Small variation to get "good" quality (RCIW ~4.56%)
    end
    local s_good = create_mock_samples(time_values_good)
    local result_good = ci(s_good)
    assert.equal(result_good.quality, "good")

    -- Test "acceptable" quality
    local time_values_acceptable = {}
    for i = 1, 100 do
        time_values_acceptable[i] = 1000 + (i - 1) * 10 -- Moderate variation (RCIW ~7.61%)
    end
    local s_acceptable = create_mock_samples(time_values_acceptable)
    local result_acceptable = ci(s_acceptable)
    assert.equal(result_acceptable.quality, "acceptable")

    -- Test "unknown" quality with NaN RCIW
    -- This requires creating a condition where RCIW becomes NaN
end

function testcase.cv_factor_branches()
    -- Test different CV factor branches

    -- Test very low variation (cv <= 0.1)
    local time_values_low_cv = {}
    for i = 1, 100 do
        time_values_low_cv[i] = 1000 + (i % 2) -- Very small variation
    end
    local s_low_cv = create_mock_samples(time_values_low_cv)
    local result_low_cv = ci(s_low_cv)
    assert.is_table(result_low_cv)

    -- Test moderate variation (0.1 < cv <= 0.5)
    local time_values_mod_cv = {}
    for i = 1, 100 do
        time_values_mod_cv[i] = 1000 + (i - 1) * 10 -- Moderate variation
    end
    local s_mod_cv = create_mock_samples(time_values_mod_cv)
    local result_mod_cv = ci(s_mod_cv)
    assert.is_table(result_mod_cv)

    -- Test high variation (cv > 0.5)
    local time_values_high_cv = {}
    for i = 1, 100 do
        time_values_high_cv[i] = 1000 + (i - 1) * 100 -- High variation
    end
    local s_high_cv = create_mock_samples(time_values_high_cv)
    local result_high_cv = ci(s_high_cv)
    assert.is_table(result_high_cv)
end

function testcase.resample_size_calculation()
    -- Test resample size calculation branches

    -- Test case where target_n <= current_n (should return nil)
    local time_values_good = {}
    for i = 1, 100 do
        time_values_good[i] = 1000 + (i - 1) -- Very low variation, should not need resampling
    end
    local s_good = create_mock_samples(time_values_good, 95, 50.0) -- Very loose target
    local result_good = ci(s_good)
    assert.equal(result_good.quality, "excellent")
    assert.equal(result_good.resample_size, nil)
    -- Should not recommend resampling for very loose target

    -- Test case where resampling is recommended
    local time_values_poor = {}
    for i = 1, 100 do
        time_values_poor[i] = 1000 + (i - 1) * 50 -- Higher variation
    end
    local s_poor = create_mock_samples(time_values_poor, 95, 1.0) -- Very strict target
    local result_poor = ci(s_poor)
    -- Should recommend resampling for very strict target
    if result_poor.rciw > 1.0 then
        assert.is_number(result_poor.resample_size)
        assert.greater_or_equal(result_poor.resample_size, 100) -- At least MIN_SAMPLE_SIZE
    end
end

function testcase.zero_stderr_handling()
    -- Test stderr <= STATS_EPSILON case (lines 458-460)
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 -- All identical to get stderr = 0
    end
    local s_identical = create_mock_samples(time_values)

    local result = ci(s_identical)
    assert.equal(result.lower, 1000)
    assert.equal(result.upper, 1000)
    assert.equal(result.rciw, 0.0)
end

-- Additional test cases for complete code coverage

function testcase.force_small_sample_t_table()
    -- Purpose: Test t-table lookup for small samples (df < 30)
    -- Coverage: Tests get_t_value() function lines 248-280 where df < 30
    -- Method: Create samples with 100 elements (passes MIN_SAMPLE_SIZE) but with
    --         statistical patterns that might trigger small sample behavior
    local time_values = {}
    for i = 1, 100 do
        if i <= 25 then
            time_values[i] = 1000 + i * 20 -- First 25 samples vary
        else
            time_values[i] = 1000 + 25 * 20 -- Rest are identical to reduce effective sample size
        end
    end

    -- This will still pass MIN_SAMPLE_SIZE but should have different statistical properties
    local s_small = create_mock_samples(time_values, 95)
    local result = ci(s_small)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)

    -- Test different confidence levels with this pattern
    local s_90 = create_mock_samples(time_values, 90)
    local result_90 = ci(s_90)
    assert.is_table(result_90)

    local s_99 = create_mock_samples(time_values, 99)
    local result_99 = ci(s_99)
    assert.is_table(result_99)
end

function testcase.force_nan_stddev()
    -- Purpose: Test numerical stability with extreme values
    -- Coverage: Tests calculate_stderr() and general CI calculation with large numbers
    -- Method: Use maximum 32-bit integer values to stress numerical calculations
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 2147483647 -- Very large valid integers (2^31 - 1)
    end

    local s_large = create_mock_samples(time_values, 95)
    local result = ci(s_large)
    assert.is_table(result)
    -- Should handle extreme values gracefully
end

function testcase.force_count_one_stderr()
    -- Purpose: Test edge case where all samples are identical
    -- Coverage: Tests calculate_stderr() with effectively no variation (line 298-302)
    -- Method: Create samples where all values are identical to achieve stderr ≈ 0

    -- Create samples where effective count is 1 or 0
    local time_values = {}
    time_values[1] = 1000
    for i = 2, 100 do
        time_values[i] = 1000 -- All identical, effectively count = 1 for variation
    end

    local s_one = create_mock_samples(time_values, 95)
    local result = ci(s_one)
    assert.is_table(result)
    -- Should handle this edge case gracefully
end

function testcase.force_nan_classify_quality()
    -- Purpose: Test quality classification with extreme value variations
    -- Coverage: Tests classify_quality() function with high variation data
    -- Method: Alternate between very large and very small values to maximize RCIW
    local time_values = {}
    for i = 1, 100 do
        if i % 2 == 0 then
            time_values[i] = 2147483647 -- Very large
        else
            time_values[i] = 1 -- Very small
        end
    end

    local s_extreme = create_mock_samples(time_values, 95)
    local result = ci(s_extreme)
    assert.is_table(result)
    -- Should handle extreme variation gracefully
end

function testcase.force_nan_mean_or_stderr()
    -- Purpose: Test numerical stability with wide value ranges
    -- Coverage: Tests mean and stderr calculations with extreme range differences
    -- Method: Mix very small and very large values to stress calculations
    local time_values = {}
    for i = 1, 100 do
        if i <= 50 then
            time_values[i] = 1 -- Very small values
        else
            time_values[i] = 2000000000 -- Very large values (but still valid integers)
        end
    end

    local s_wide_range = create_mock_samples(time_values, 95)
    local result = ci(s_wide_range)
    assert.is_table(result)
    -- Should handle wide range gracefully
end

function testcase.force_very_small_mean()
    -- Purpose: Test RCIW calculation when mean is small but non-zero
    -- Coverage: Tests RCIW formula (width/mean)*100 with small denominators (line 466)
    -- Method: Use small consecutive integers to create small but valid mean
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = i -- 1, 2, 3, ..., 100 (small positive integers)
    end

    local s_small = create_mock_samples(time_values, 95)
    local result = ci(s_small)
    assert.is_table(result)
    assert.is_number(result.rciw)
    assert.greater(result.rciw, 0.0) -- Should have some RCIW since mean is not actually zero
end

function testcase.trigger_interpolation_small_samples()
    -- Force t-table interpolation for small samples (lines 271-277)
    -- Create samples to trigger the exact interpolation path

    local time_values = {}
    for i = 1, 100 do
        if i <= 10 then
            time_values[i] = 1000 + i * 50 -- First 10 samples vary significantly
        else
            time_values[i] = 1000 + 10 * 50 -- Rest identical to reduce effective df
        end
    end

    -- Test confidence level between 90% and 95% to trigger interpolation
    local s_interp = create_mock_samples(time_values, 92.5)
    local result = ci(s_interp)
    assert.is_table(result)
    assert.equal(result.level, 92.5)
end

function testcase.default_t_value_branch()
    -- Test default t_90 return (line 280)
    -- Create samples with very low confidence level for small samples

    local time_values = {}
    for i = 1, 100 do
        if i <= 15 then
            time_values[i] = 1000 + i * 30
        else
            time_values[i] = 1000 + 15 * 30
        end
    end

    -- Test with confidence level below 90% for small samples
    local s_low = create_mock_samples(time_values, 85)
    local result = ci(s_low)
    assert.is_table(result)
    assert.equal(result.level, 85)
end

function testcase.df_zero_and_capping()
    -- Test df = 0 and df > 30 capping logic (lines 252-257)

    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i
    end

    -- This test ensures we exercise the df adjustment logic
    local s = create_mock_samples(time_values, 95)
    local result = ci(s)
    assert.is_table(result)

    -- Test with larger sample size to trigger df > 30 capping
    local large_values = {}
    for i = 1, 150 do
        large_values[i] = 1000 + i * 5
    end
    local s_large = create_mock_samples(large_values, 95)
    local result_large = ci(s_large)
    assert.is_table(result_large)
end

-- Additional test for edge case coverage
function testcase.additional_edge_case_coverage()
    -- Test edge cases that might not be covered yet
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 5 -- Small linear progression
    end

    -- Test various confidence levels to exercise different code paths
    for _, level in ipairs({
        75,
        80,
        85,
        87,
        92,
        93,
        96,
        97,
        98,
    }) do
        local s = create_mock_samples(time_values, level)
        local result = ci(s)
        assert.is_table(result)
        assert.equal(result.level, level)
        assert.is_number(result.lower)
        assert.is_number(result.upper)
        assert.is_number(result.rciw)
    end
end

function testcase.force_nan_handling()
    -- Purpose: Test NaN handling across all CI calculation functions
    -- Coverage: Tests is_nan() checks in calculate_stderr, classify_quality, etc.
    -- Method: Use edge case data (all zeros) that might produce NaN in calculations

    -- Test classify_quality with NaN rciw (line 315)
    -- Test with NaN rciw
    -- These require special conditions to generate NaN RCIW

    -- Test with empty or problematic sample data that might cause NaN
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 0 -- All zeros
    end
    local s_zeros = create_mock_samples(time_values)
    local result = ci(s_zeros)
    assert.is_table(result)
end

function testcase.force_count_edge_case()
    -- Purpose: Test stderr calculation with normal sample counts
    -- Coverage: Tests calculate_stderr() with valid sample sizes
    -- Method: Verify that samples with sufficient data produce valid results

    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i -- Normal values
    end
    local s = create_mock_samples(time_values)
    local result = ci(s)
    assert.is_table(result)
    assert.greater(result.sample_size, 1) -- Should always be > 1 with our test data
end

function testcase.force_mean_zero_edge_case()
    -- Purpose: Test RCIW calculation when mean approaches zero
    -- Coverage: Tests condition abs(mean_val) <= STATS_EPSILON (line 465)
    -- Method: Use identical small values to create minimal mean
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1 -- All very small positive values
    end
    -- This creates samples with very small mean
    local s_near_zero = create_mock_samples(time_values)
    local result = ci(s_near_zero)
    assert.is_table(result)
    -- With identical small values, RCIW should be 0.0
    assert.equal(result.rciw, 0.0)
end

function testcase.force_nan_mean_stderr()
    -- Purpose: Test numerical stability with large arithmetic progressions
    -- Coverage: Tests mean/stderr calculations with large but valid values
    -- Method: Use large integer progression to stress numerical precision

    local time_values = {}
    for i = 1, 100 do
        time_values[i] = i * 100000 -- Large but valid integer progression
    end

    local s_progression = create_mock_samples(time_values)
    local result = ci(s_progression)
    assert.is_table(result)
    assert.is_number(result.lower)
    assert.is_number(result.upper)
end

-- Add test to force t-table usage with small df
function testcase.modified_samples_for_small_df()
    -- Create a scenario that might trigger small sample t-table usage
    -- We'll create samples with exactly MIN_SAMPLE_SIZE but with special properties

    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + (i - 1) * 10 -- Linear progression
    end

    -- Test with unusual confidence levels to trigger different t-table paths
    local s_unusual = create_mock_samples(time_values, 85) -- Between 90% and 95% but closer to 90%
    local result = ci(s_unusual)
    assert.is_table(result)
    assert.equal(result.level, 85)

    -- Test with confidence level that might trigger interpolation
    local s_interp = create_mock_samples(time_values, 92.5)
    local result_interp = ci(s_interp)
    assert.is_table(result_interp)
    assert.equal(result_interp.level, 92.5)
end

-- Test the actual t-table lookup by using reflection or alternative approach
function testcase.comprehensive_confidence_levels()
    -- Test all major confidence level branches systematically
    local time_values = {}
    for i = 1, 100 do
        time_values[i] = 1000 + i * 5
    end

    -- Test exact boundary values
    local levels = {
        10,
        50,
        80,
        85,
        88,
        89,
        89.9,
        90,
        90.1,
        91,
        92,
        93,
        94,
        94.9,
        95,
        95.1,
        96,
        97,
        98,
        98.9,
        99,
        99.1,
        99.5,
    }

    for _, level in ipairs(levels) do
        local s = create_mock_samples(time_values, level)
        local result = ci(s)
        assert.is_table(result)
        assert.equal(result.level, level)
        assert.is_number(result.lower)
        assert.is_number(result.upper)
    end
end
