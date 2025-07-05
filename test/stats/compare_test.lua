local testcase = require('testcase')
local assert = require('assert')
local compare = require('measure.stats.compare')
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

-- Test statistical comparison between two sample sets
function testcase.known_data()
    -- Test with clearly different performance
    local s1 = create_mock_samples({
        2000,
        2100,
        1900,
        2050,
        1950,
    }) -- mean ≈ 2000

    local s2 = create_mock_samples({
        1000,
        1100,
        900,
        1050,
        950,
    }) -- mean ≈ 1000

    local result = compare(s1, s2)

    -- Verify result structure
    assert.is_table(result)
    assert.is_number(result.speedup)
    assert.is_number(result.difference)
    assert.is_number(result.p_value)
    assert.is_boolean(result.significant)

    -- s1 is slower than s2, so speedup should be > 1 (s1/s2 = 2000/1000 = 2.0)
    assert.greater(result.speedup, 1.0)

    -- Difference should be positive (s1 - s2 > 0)
    assert.greater(result.difference, 0)

    -- With clear difference, should be statistically significant
    assert.is_true(result.significant)
    assert.less(result.p_value, 0.05)
end

-- Test speedup calculation
function testcase.speedup()
    -- Test where s2 is exactly 2x faster than s1
    local s1 = create_mock_samples({
        2000,
        2000,
        2000,
    }) -- mean = 2000

    local s2 = create_mock_samples({
        1000,
        1000,
        1000,
    }) -- mean = 1000

    local result = compare(s1, s2)

    -- Speedup should be approximately 2.0 (s1/s2 = 2000/1000)
    assert.less(math.abs(result.speedup - 2.0), 0.1)

    -- Difference should be 1000 (2000 - 1000)
    assert.less(math.abs(result.difference - 1000.0), 0.1)
end

-- Test with identical samples
function testcase.identical_samples()
    local s1 = create_mock_samples({
        1500,
        1500,
        1500,
        1500,
    })

    local s2 = create_mock_samples({
        1500,
        1500,
        1500,
        1500,
    })

    local result = compare(s1, s2)

    -- Speedup should be 1.0 (identical performance)
    assert.less(math.abs(result.speedup - 1.0), 0.001)

    -- Difference should be 0
    assert.less(math.abs(result.difference - 0.0), 0.001)

    -- Should not be statistically significant
    assert.is_false(result.significant)
    assert.greater(result.p_value, 0.05)
end

-- Test with small differences (not significant)
function testcase.small_differences()
    local s1 = create_mock_samples({
        1000,
        1010,
        990,
        1005,
        995,
    })

    local s2 = create_mock_samples({
        1000,
        1020,
        980,
        1015,
        985,
    })

    local result = compare(s1, s2)

    -- Small difference should not be statistically significant
    assert.is_false(result.significant)
    assert.greater(result.p_value, 0.05)
end

-- Test error handling
function testcase.error_handling()
    local s1 = create_mock_samples({
        1000,
        2000,
        3000,
    })

    -- Test with nil samples should throw error
    assert.throws(function()
        compare(nil, s1)
    end)

    assert.throws(function()
        compare(s1, nil)
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
        compare(s1, empty_samples)
    end)
end
