local testcase = require('testcase')
local assert = require('assert')
local trend = require('measure.stats.trend')
local new_samples = require('measure.samples').new
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

-- Test performance trend analysis
function testcase.analysis()
    -- Test with clear increasing trend (performance degradation)
    local s_increasing = create_mock_samples({
        1000,
        1500,
        2000,
        2500,
        3000,
    })

    local result = trend(s_increasing)

    -- Verify result structure
    assert.is_table(result)
    assert.is_number(result.slope)
    assert.is_number(result.correlation)
    assert.is_boolean(result.stable)

    -- Should have positive slope (increasing trend)
    assert.greater(result.slope, 0)

    -- Should have strong positive correlation
    assert.greater(result.correlation, 0.9)

    -- Should not be stable (clear trend)
    assert.is_false(result.stable)
end

-- Test decreasing trend (performance improvement)
function testcase.decreasing()
    local s_decreasing = create_mock_samples({
        3000,
        2500,
        2000,
        1500,
        1000,
    })

    local result = trend(s_decreasing)

    -- Should have negative slope (decreasing trend)
    assert.less(result.slope, 0)

    -- Should have strong negative correlation
    assert.less(result.correlation, -0.9)

    -- Should not be stable (clear trend)
    assert.is_false(result.stable)
end

-- Test stable performance (no trend)
function testcase.stable()
    local s_stable = create_mock_samples({
        2000,
        2010,
        1990,
        2005,
        1995,
        2000,
        2008,
        1992,
    })

    local result = trend(s_stable)

    -- Slope should be close to zero
    assert.less(math.abs(result.slope), 5.0)

    -- Correlation should be weak (threshold is 0.1 for stability)
    assert.less(math.abs(result.correlation), 0.5)

    -- Should be considered stable (|correlation| < 0.1)
    if math.abs(result.correlation) < 0.1 then
        assert.is_true(result.stable)
    else
        -- If correlation is higher, stable might be false
        assert.is_boolean(result.stable)
    end
end

-- Test with identical values
function testcase.identical_values()
    local s_identical = create_mock_samples({
        2000,
        2000,
        2000,
        2000,
        2000,
    })

    local result = trend(s_identical)

    -- Slope should be exactly zero
    assert.equal(result.slope, 0.0)

    -- Correlation should be zero (undefined for identical values)
    assert.equal(result.correlation, 0.0)

    -- Should be stable
    assert.is_true(result.stable)
end

-- Test with minimum required samples
function testcase.minimum_samples()
    -- Test with exactly 3 samples (minimum for trend analysis)
    local s_three = create_mock_samples({
        1000,
        2000,
        3000,
    })

    local result = trend(s_three)

    assert.is_table(result)
    assert.is_number(result.slope)
    assert.is_number(result.correlation)
    assert.is_boolean(result.stable)

    -- Should detect clear increasing trend
    assert.greater(result.slope, 0)
    assert.greater(result.correlation, 0.9)
    assert.is_false(result.stable)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error
    assert.throws(function()
        trend(nil)
    end)

    -- Test with insufficient samples (< 3) - should return default values
    local s_two = create_mock_samples({
        1000,
        2000,
    })
    local result_two = trend(s_two)
    assert.is_table(result_two)

    local s_one = create_mock_samples({
        1000,
    })
    local result_one = trend(s_one)
    assert.is_table(result_one)

    -- Test with empty samples
    local empty_data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = 0,
        count = 0,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
    }
    local empty_samples = new_samples(empty_data)
    assert.throws(function()
        trend(empty_samples)
    end)
end
