local testcase = require('testcase')
local assert = require('assert')
local percentile = require('measure.stats.percentile')
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
        cl = 95,
        rciw = 5.0,
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

-- Test percentile calculation with known data
function testcase.known_data()
    -- Test p50 (median) with odd number of values
    local s_odd = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    local p50 = percentile(s_odd, 50.0)
    assert.equal(p50, 3000.0) -- Middle value

    -- Test with even number of values
    local s_even = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
    })
    local p50_even = percentile(s_even, 50.0)
    assert.equal(p50_even, 2500.0) -- (2000+3000)/2 = 2500

    -- Test with single value
    local s_single = create_mock_samples({
        12345,
    })
    assert.equal(percentile(s_single, 50.0), 12345.0)

    -- Test with unsorted data (should still work correctly)
    local s_unsorted = create_mock_samples({
        5000,
        1000,
        3000,
        2000,
        4000,
    })
    assert.equal(percentile(s_unsorted, 50.0), 3000.0)
end

-- Test various percentiles
function testcase.various_percentiles()
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
        6000,
        7000,
        8000,
        9000,
        10000,
    })

    -- Test 0th percentile (minimum)
    assert.equal(percentile(s, 0.0), 1000.0)

    -- Test 25th percentile
    local p25 = percentile(s, 25.0)
    assert.greater_or_equal(p25, 2000.0)
    assert.less_or_equal(p25, 4000.0)

    -- Test 75th percentile
    local p75 = percentile(s, 75.0)
    assert.greater_or_equal(p75, 7000.0)
    assert.less_or_equal(p75, 9000.0)

    -- Test 100th percentile (maximum)
    assert.equal(percentile(s, 100.0), 10000.0)
end

-- Test edge cases
function testcase.edge_cases()
    -- Test with identical values
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(percentile(s_identical, 25.0), 5000.0)
    assert.equal(percentile(s_identical, 50.0), 5000.0)
    assert.equal(percentile(s_identical, 75.0), 5000.0)

    -- Test with two values
    local s_two = create_mock_samples({
        1000,
        3000,
    })
    assert.equal(percentile(s_two, 0.0), 1000.0)
    assert.equal(percentile(s_two, 50.0), 2000.0)
    assert.equal(percentile(s_two, 100.0), 3000.0)
end

-- Test error handling
function testcase.error_handling()
    local s = create_mock_samples({
        1000,
        2000,
        3000,
    })

    -- Test with nil samples should throw error
    assert.throws(function()
        percentile(nil, 50.0)
    end)

    -- Test with invalid percentile values
    assert.throws(function()
        percentile(s, -1.0) -- Negative percentile
    end)

    assert.throws(function()
        percentile(s, 101.0) -- > 100
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
        percentile(empty_samples, 50.0)
    end)
end
