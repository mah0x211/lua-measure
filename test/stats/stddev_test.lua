local testcase = require('testcase')
local assert = require('assert')
local stddev = require('measure.stats.stddev')
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
        allocated_kb = {},
        capacity = 10,  -- capacity must be > 0
        count = 0,      -- but count can be 0
        gc_step = 0,
        base_kb = 1,
    }
    local empty_samples = samples(empty_data)
    local result = stddev(empty_samples)
    -- Check for NaN (NaN is not equal to itself)
    assert.is_true(result ~= result)
end
