local testcase = require('testcase')
local assert = require('assert')
local max = require('measure.stats.max')
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

-- Test max calculation with known data
function testcase.known_data()
    -- Test with simple integer values
    local s = create_mock_samples({
        1000,
        5000,
        3000,
        2000,
        4000,
    })
    local result = max(s)
    assert.equal(result, 5000.0) -- maximum value

    -- Test with single value
    local s_single = create_mock_samples({
        42000,
    })
    assert.equal(max(s_single), 42000.0)

    -- Test with unsorted values
    local s_unsorted = create_mock_samples({
        3000,
        1000,
        2000,
    })
    assert.equal(max(s_unsorted), 3000.0)

    -- Test with duplicate values
    local s_duplicates = create_mock_samples({
        2000,
        1000,
        2000,
        500,
    })
    assert.equal(max(s_duplicates), 2000.0)
end

-- Test max calculation edge cases
function testcase.edge_cases()
    -- Test with identical values
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
    })
    assert.equal(max(s_identical), 5000.0)

    -- Test with large numbers
    local s_large = create_mock_samples({
        500000000,
        1000000000,
        2000000000,
    })
    assert.equal(max(s_large), 2000000000.0)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error
    assert.throws(function()
        max(nil)
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
    }
    local empty_samples = samples(empty_data)
    assert.throws(function()
        max(empty_samples)
    end)
end
