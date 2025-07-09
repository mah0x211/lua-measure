local testcase = require('testcase')
local assert = require('assert')
local stddev = require('measure.stats.stddev')
local samples = require('measure.samples')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

-- Test standard deviation calculation with known data
function testcase.known_data()
    -- Test with known variance case
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    local result = stddev(s)
    -- For this dataset: mean = 3000, variance = 2500000, stddev = sqrt(2500000) ≈ 1581.14
    assert.less(math.abs(result - 1581.14), 0.1)

    -- Test with identical values (should be 0)
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(stddev(s_identical), 0.0)

    -- Test with single value (should be 0)
    local s_single = create_mock_samples({
        42000,
    })
    assert.equal(stddev(s_single), 0.0)
end

-- Test standard deviation calculation with simple cases
function testcase.simple_cases()
    -- Test with simple two-value case
    local s_two = create_mock_samples({
        1000,
        3000,
    })
    local result_two = stddev(s_two)
    -- variance = ((1000-2000)^2 + (3000-2000)^2) / 1 = 2000000, stddev = sqrt(2000000) ≈ 1414.21
    assert.less(math.abs(result_two - 1414.21), 0.1)

    -- Test with three values
    local s_three = create_mock_samples({
        2000,
        4000,
        6000,
    })
    local result_three = stddev(s_three)
    -- mean = 4000, variance = ((2000-4000)^2 + (4000-4000)^2 + (6000-4000)^2) / 2 = 4000000, stddev = 2000
    assert.less(math.abs(result_three - 2000.0), 0.1)
end

-- Test edge cases
function testcase.edge_cases()
    -- Test with large numbers
    local s_large = create_mock_samples({
        1000000000,
        2000000000,
        3000000000,
    })
    local result_large = stddev(s_large)
    assert.greater(result_large, 0)
    assert.is_number(result_large)

    -- Test with small numbers
    local s_small = create_mock_samples({
        1,
        2,
        3,
    })
    assert.equal(stddev(s_small), 1.0)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error (from variance module)
    assert.throws(function()
        stddev(nil)
    end)

    -- Test with empty samples should return NaN (variance now returns NaN)
    local empty_data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        capacity = 10, -- capacity must be > 0
        count = 0, -- but count can be 0
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
    }
    local empty_samples = samples(empty_data)
    local result = stddev(empty_samples)
    -- Check for NaN (NaN is not equal to itself)
    assert.is_true(result ~= result)
end

-- Test additional error cases to improve coverage
function testcase.variance_error_handling()
    -- Try to trigger pcall error in variance module (line 588)
    -- Test with invalid samples object that might cause variance to fail
    assert.throws(function()
        stddev("invalid_samples") -- String instead of samples object
    end)

    assert.throws(function()
        stddev({}) -- Empty table instead of proper samples object
    end)
end

function testcase.nan_variance_handling()
    -- Try to create condition where variance returns NaN (line 593)
    -- This is tricky because variance module is implemented in C
    -- Test with edge case that might produce NaN variance

    -- Create samples with very extreme values that might cause numerical issues
    local extreme_data = {
        time_ns = {
            2147483647,
            1,
            2147483647,
            1,
        }, -- Extreme alternating values
        before_kb = {
            0,
            0,
            0,
            0,
        },
        after_kb = {
            0,
            0,
            0,
            0,
        },
        capacity = 4,
        count = 4,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
    }

    local extreme_samples = samples(extreme_data)
    local result = stddev(extreme_samples)
    -- Should handle this gracefully
    assert.is_number(result)
end

function testcase.additional_coverage_tests()
    -- Additional tests to improve coverage

    -- Test with very large variation
    local large_var_samples = create_mock_samples({
        1,
        1000000000,
        1,
        1000000000,
        1,
    })
    local result_large_var = stddev(large_var_samples)
    assert.is_number(result_large_var)
    assert.greater(result_large_var, 0)

    -- Test with patterns that might stress the variance calculation
    local pattern_samples = create_mock_samples({
        100,
        200,
        300,
        400,
        500,
        600,
        700,
        800,
        900,
        1000,
    })
    local result_pattern = stddev(pattern_samples)
    assert.is_number(result_pattern)
    assert.greater(result_pattern, 0)
end
