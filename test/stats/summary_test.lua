require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local summary = require('measure.stats.summary')
local outliers = require('measure.stats.outliers')
local ci = require('measure.stats.ci')

local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.basic()
    -- test comprehensive summary statistics
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = summary(s)

    -- test structure
    assert.is_table(result)

    -- test that all expected fields are present and are numbers
    assert.is_string(result.name)
    assert.is_number(result.mean)
    assert.is_number(result.median)
    assert.is_number(result.stddev)
    assert.is_number(result.variance)
    assert.is_number(result.cv)
    assert.is_number(result.iqr)
    assert.is_number(result.min)
    assert.is_number(result.max)
    assert.is_number(result.p25)
    assert.is_number(result.p75)
    assert.is_number(result.p95)
    assert.is_number(result.p99)
    assert.is_number(result.throughput)
    assert.is_number(result.memory_per_op)

    -- test CI fields
    assert.is_number(result.ci_lower)
    assert.is_number(result.ci_upper)
    assert.is_number(result.ci_width)
    assert.is_number(result.ci_level)
    assert.is_number(result.rciw)
    assert.is_string(result.ci_quality)

    -- test outlier fields
    assert.is_table(result.outliers)
    assert.is_number(result.outliers.count)
    assert.is_number(result.outliers.percentage)
    assert.is_table(result.outliers.indices)

    -- test additional fields
    assert.is_number(result.sample_count)
    assert.is_number(result.gc_step)
    assert.is_number(result.cl)
    assert.is_number(result.target_rciw)
    assert.is_string(result.quality)
    assert.is_number(result.quality_score)

    -- test some basic values
    assert.equal(result.mean, 3000)
    assert.equal(result.min, 1000)
    assert.equal(result.max, 5000)
    assert.equal(result.median, 3000)
    assert.equal(result.iqr, 2000) -- p75 - p25 = 4000 - 2000
    assert.equal(result.sample_count, 5)
end

function testcase.single_sample()
    -- test with single sample
    local s = create_mock_samples({
        1000,
    })

    local result = summary(s)

    assert.is_table(result)
    assert.equal(result.mean, 1000)
    assert.equal(result.min, 1000)
    assert.equal(result.max, 1000)
    assert.equal(result.median, 1000)
    assert.equal(result.iqr, 0.0)
    assert.equal(result.sample_count, 1)

    -- test quality assessment with single sample
    assert.is_string(result.quality)
    assert.is_number(result.quality_score)
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        summary(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end

function testcase.from_stats()
    -- test comprehensive summary - moved from stats_test.lua
    local s = create_mock_samples({
        1000,
        1500,
        2000,
        2500,
        3000,
    })

    local result = summary(s)

    -- test structure
    assert.is_table(result)
    assert.is_string(result.name)
    assert.is_number(result.mean)
    assert.is_number(result.median)
    assert.is_number(result.stddev)
    assert.is_number(result.variance)
    assert.is_number(result.cv)
    assert.is_number(result.iqr)
    assert.is_number(result.min)
    assert.is_number(result.max)
    assert.is_number(result.p25)
    assert.is_number(result.p75)
    assert.is_number(result.p95)
    assert.is_number(result.p99)
    assert.is_number(result.throughput)

    -- test consistency with samples methods
    assert.equal(result.mean, s:mean())
    assert.equal(result.median, s:percentile(50))
    assert.equal(result.stddev, s:stddev())
    assert.equal(result.cv, s:cv())
    assert.equal(result.p25, s:percentile(25))
    assert.equal(result.p75, s:percentile(75))
    assert.equal(result.iqr, result.p75 - result.p25)
    assert.equal(result.min, 1000) -- minimum value
    assert.equal(result.max, 3000) -- maximum value
    assert.equal(result.throughput, s:throughput())

    -- test consistency with CI and outlier modules
    local ci_result = ci(s)
    assert.equal(result.ci_lower, ci_result.lower)
    assert.equal(result.ci_upper, ci_result.upper)
    assert.equal(result.ci_level, ci_result.level)
    assert.equal(result.rciw, ci_result.rciw)
    assert.equal(result.ci_quality, ci_result.quality)

    local outlier_indices, outlier_err = outliers(s)
    if not outlier_err and outlier_indices then
        assert.equal(result.outliers.count, #outlier_indices)
        assert.equal(result.outliers.percentage, (#outlier_indices / 5 * 100))
        assert.equal(#result.outliers.indices, #outlier_indices)
        -- Check that indices match
        for i, idx in ipairs(outlier_indices) do
            assert.equal(result.outliers.indices[i], idx)
        end
    else
        assert.equal(result.outliers.count, 0)
        assert.equal(result.outliers.percentage, 0)
        assert.equal(#result.outliers.indices, 0)
    end
end

function testcase.nan_handling()
    -- test NaN handling in edge cases - moved from stats_test.lua
    local s_single = create_mock_samples({
        1000,
    })

    -- cv should be NaN for single sample (stddev=0)
    assert.is_nan(s_single:cv())

    -- Check summary handles NaN values correctly
    local result = summary(s_single)
    assert.is_nan(result.cv)
end

function testcase.quality_assessment()
    -- test quality assessment logic
    local s_small = create_mock_samples({
        1000,
        2000,
        3000,
    })

    local result_small = summary(s_small)
    assert.is_string(result_small.quality)
    assert.is_number(result_small.quality_score)
    assert(
        result_small.quality == 'excellent' or result_small.quality == 'good' or
            result_small.quality == 'acceptable' or result_small.quality ==
            'poor')

    -- Create larger sample set for better quality score
    local large_samples = {}
    for i = 1, 200 do
        large_samples[i] = 1000 + i * 10
    end
    local s_large = create_mock_samples(large_samples)

    local result_large = summary(s_large)
    assert.is_string(result_large.quality)
    assert.is_number(result_large.quality_score)

    -- Larger sample set should have better or equal quality score
    assert(result_large.quality_score >= result_small.quality_score)
end

function testcase.memory_per_op()
    -- test memory per operation calculation
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = summary(s)
    assert.is_number(result.memory_per_op)
    assert(result.memory_per_op >= 0)
end
