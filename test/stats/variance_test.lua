local testcase = require('testcase')
local assert = require('assert')
local variance = require('measure.stats.variance')
local samples = require('measure.samples')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

-- Test variance calculation with known data
function testcase.known_data()
    -- Test with known variance case
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    local result = variance(s)
    -- For this dataset: mean = 3000
    -- Variance = ((1000-3000)^2 + (2000-3000)^2 + (3000-3000)^2 + (4000-3000)^2 + (5000-3000)^2) / 4
    -- = (4000000 + 1000000 + 0 + 1000000 + 4000000) / 4 = 10000000 / 4 = 2500000
    assert.equal(result, 2500000)

    -- Test with identical values (should be 0)
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(variance(s_identical), 0.0)

    -- Test with single value (should be 0)
    local s_single = create_mock_samples({
        42000,
    })
    assert.equal(variance(s_single), 0.0)
end

-- Test variance calculation with simple cases
function testcase.simple_cases()
    -- Test with simple two-value case
    local s_two = create_mock_samples({
        1000,
        3000,
    })
    local result_two = variance(s_two)
    -- mean = 2000, variance = ((1000-2000)^2 + (3000-2000)^2) / 1 = 2000000
    assert.equal(result_two, 2000000)

    -- Test with three values
    local s_three = create_mock_samples({
        2000,
        4000,
        6000,
    })
    local result_three = variance(s_three)
    -- mean = 4000, variance = ((2000-4000)^2 + (4000-4000)^2 + (6000-4000)^2) / 2
    -- = (4000000 + 0 + 4000000) / 2 = 4000000
    assert.equal(result_three, 4000000)

    -- Test with four values
    local s_four = create_mock_samples({
        1000,
        3000,
        5000,
        7000,
    })
    local result_four = variance(s_four)
    -- mean = 4000
    -- variance = ((1000-4000)^2 + (3000-4000)^2 + (5000-4000)^2 + (7000-4000)^2) / 3
    -- = (9000000 + 1000000 + 1000000 + 9000000) / 3 = 20000000 / 3 ≈ 6666666.67
    assert.less(math.abs(result_four - 6666666.67), 0.1)
end

-- Test variance with decimal values
function testcase.decimal_values()
    -- Test with decimal values
    local s_decimal = create_mock_samples({
        100,
        150,
        200,
        250,
        300,
    })
    local result = variance(s_decimal)
    -- mean = 200, variance = ((100-200)^2 + (150-200)^2 + (200-200)^2 + (250-200)^2 + (300-200)^2) / 4
    -- = (10000 + 2500 + 0 + 2500 + 10000) / 4 = 25000 / 4 = 6250
    assert.equal(result, 6250)
end

-- Test edge cases
function testcase.edge_cases()
    -- Test with large numbers
    local s_large = create_mock_samples({
        1000000000,
        2000000000,
        3000000000,
    })
    local result_large = variance(s_large)
    -- mean = 2000000000
    -- variance = ((1000000000-2000000000)^2 + (2000000000-2000000000)^2 + (3000000000-2000000000)^2) / 2
    -- = (1e18 + 0 + 1e18) / 2 = 1e18
    assert.equal(result_large, 1e18)

    -- Test with small numbers
    local s_small = create_mock_samples({
        1,
        2,
        3,
    })
    local result_small = variance(s_small)
    -- mean = 2, variance = ((1-2)^2 + (2-2)^2 + (3-2)^2) / 2 = (1 + 0 + 1) / 2 = 1
    assert.equal(result_small, 1.0)

    -- Test with alternating values
    local s_alternating = create_mock_samples({
        1000,
        9000,
        1000,
        9000,
    })
    local result_alternating = variance(s_alternating)
    -- mean = 5000, variance = 2*((1000-5000)^2) + 2*((9000-5000)^2) / 3
    -- = 2*(16000000) + 2*(16000000) / 3 = 64000000 / 3 ≈ 21333333.33
    assert.less(math.abs(result_alternating - 21333333.33), 0.1)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error
    assert.throws(function()
        variance(nil)
    end)

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
    local empty_samples = samples(empty_data)
    assert.throws(function()
        variance(empty_samples)
    end)
end
