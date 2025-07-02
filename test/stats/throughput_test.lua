require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local throughput = require('measure.stats.throughput')
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

function testcase.basic()
    -- test throughput calculation with 1 second mean time
    local s = create_mock_samples({
        1000000000,
        1000000000,
        1000000000,
    }) -- 1 second each

    local result = throughput(s)

    assert.is_number(result)
    assert.equal(result, 1.0) -- 1 operation per second
end

function testcase.half_second()
    -- test throughput with 0.5 second mean time
    local s = create_mock_samples({
        500000000,
        500000000,
        500000000,
    }) -- 0.5 second each

    local result = throughput(s)

    assert.is_number(result)
    assert.equal(result, 2.0) -- 2 operations per second
end

function testcase.zero_time()
    -- test with zero time values (should return NaN)
    local s = create_mock_samples({
        0,
        0,
        0,
    })

    local result = throughput(s)

    -- check for NaN
    assert.is_nan(result)
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        throughput(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end

function testcase.nan_conditions()
    -- Test with minimal data that could cause mean to return NaN
    local minimal_data = {
        time_ns = {
            0,
        },
        before_kb = {
            0,
        },
        after_kb = {
            0,
        },
        allocated_kb = {
            0,
        },
        capacity = 1,
        count = 1,
        gc_step = 0,
        base_kb = 1,
    }

    local s, serr = samples(minimal_data)
    if s then
        local result = throughput(s)
        -- With zero time, throughput should be NaN
        assert.is_nan(result)
    else
        -- If samples creation fails, verify the error
        assert.match(serr, 'invalid')
    end

    -- Test with extremely small time values to trigger epsilon condition
    local tiny_data = {
        time_ns = {
            1e-20,
            1e-20,
            1e-20,
        }, -- extremely small time values
        before_kb = {
            0,
            0,
            0,
        },
        after_kb = {
            0,
            0,
            0,
        },
        allocated_kb = {
            0,
            0,
            0,
        },
        capacity = 3,
        count = 3,
        gc_step = 0,
        base_kb = 1,
    }

    local s2, err2 = samples(tiny_data)
    if s2 then
        local result2 = throughput(s2)
        -- With extremely small time, it might trigger the epsilon check
        -- This should be a very large number or potentially NaN
        assert.is_number(result2)
    else
        -- If samples creation fails, verify the error
        assert.match(err2, 'integer')
    end

    -- Test with empty-like data to try to trigger NaN from mean calculation
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

    local ok, err = pcall(function()
        local s3 = samples(empty_data)
        throughput(s3) -- This will error if s3 is nil
    end)

    -- Should fail when trying to use nil samples
    assert.is_false(ok)
    assert.match(err, 'nil')
end

function testcase.from_stats()
    -- test throughput calculation (ops/sec) - moved from stats_test.lua
    local s = create_mock_samples({
        1000000,
        2000000,
        3000000,
    }) -- 1ms, 2ms, 3ms average

    local result = throughput(s)

    -- mean = 2ms = 2e6 ns = 0.002s, throughput = 1/0.002 = 500 ops/sec
    assert.is_number(result)
    assert.greater(result, 450)
    assert.less(result, 550)
end
