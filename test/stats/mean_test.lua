local testcase = require('testcase')
local assert = require('assert')
local mean = require('measure.stats.mean')
local samples = require('measure.samples')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

-- Test mean calculation with known data
function testcase.known_data()
    -- Test with simple integer values
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    local result = mean(s)
    assert.equal(result, 3000.0) -- (1000+2000+3000+4000+5000)/5 = 3000

    -- Test with single value
    local s_single = create_mock_samples({
        42000,
    })
    assert.equal(mean(s_single), 42000.0)

    -- Test with two values
    local s_two = create_mock_samples({
        1000,
        3000,
    })
    assert.equal(mean(s_two), 2000.0) -- (1000+3000)/2 = 2000

    -- Test with decimal precision
    local s_decimal = create_mock_samples({
        1500,
        2500,
        3500,
    })
    assert.equal(mean(s_decimal), 2500.0) -- (1500+2500+3500)/3 = 2500
end

-- Test mean calculation edge cases
function testcase.edge_cases()
    -- Test with large numbers
    local s_large = create_mock_samples({
        1000000000,
        2000000000,
        3000000000,
    })
    local result_large = mean(s_large)
    assert.equal(result_large, 2000000000.0)

    -- Test with very small numbers
    local s_small = create_mock_samples({
        1,
        2,
        3,
    })
    assert.equal(mean(s_small), 2.0)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error
    assert.throws(function()
        mean(nil)
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
        mean(empty_samples)
    end)
end
