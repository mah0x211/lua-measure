local testcase = require('testcase')
local assert = require('assert')
local min = require('measure.stats.min')
local samples = require('measure.samples')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

-- Test min calculation with known data
function testcase.known_data()
    -- Test with simple integer values
    local s = create_mock_samples({
        5000,
        1000,
        3000,
        2000,
        4000,
    })
    local result = min(s)
    assert.equal(result, 1000.0) -- minimum value

    -- Test with single value
    local s_single = create_mock_samples({
        42000,
    })
    assert.equal(min(s_single), 42000.0)

    -- Test with unsorted values
    local s_unsorted = create_mock_samples({
        3000,
        1000,
        2000,
    })
    assert.equal(min(s_unsorted), 1000.0)

    -- Test with duplicate values
    local s_duplicates = create_mock_samples({
        1000,
        500,
        2000,
        500,
    })
    assert.equal(min(s_duplicates), 500.0)
end

-- Test min calculation edge cases
function testcase.edge_cases()
    -- Test with identical values
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
    })
    assert.equal(min(s_identical), 5000.0)

    -- Test with large numbers
    local s_large = create_mock_samples({
        1000000000,
        2000000000,
        500000000,
    })
    assert.equal(min(s_large), 500000000.0)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error
    assert.throws(function()
        min(nil)
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
        min(empty_samples)
    end)
end
