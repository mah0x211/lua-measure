require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local stderr = require('measure.stats.stderr')
local samples = require('measure.samples')
local stddev = require('measure.stats.stddev')

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
    -- test standard error calculation
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = stderr(s)

    assert.is_number(result)
    assert.greater(result, 0) -- stderr should be positive
end

function testcase.single_sample()
    -- test with single sample (stderr should be 0)
    local s = create_mock_samples({
        1000,
    })

    local result = stderr(s)

    assert.is_number(result)
    assert.equal(result, 0.0) -- no error with single sample
end

function testcase.identical_values()
    -- test with identical values (stderr should be 0)
    local s = create_mock_samples({
        1000,
        1000,
        1000,
        1000,
    })

    local result = stderr(s)

    assert.is_number(result)
    assert.equal(result, 0.0) -- no variation
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        stderr(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end

function testcase.nan_conditions()
    -- Test with minimal data that could cause stddev to return NaN
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
        local result = stderr(s)
        -- With single sample, stderr should be 0.0
        assert.equal(result, 0.0)
    else
        -- If samples creation fails, verify the error
        assert.match(serr, 'invalid')
    end

    -- Test with empty-like data to try to trigger NaN from stddev calculation
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
        local s2 = samples(empty_data)
        stderr(s2) -- This will error if s2 is nil
    end)

    -- Should fail when trying to use nil samples
    assert.is_false(ok)
    assert.match(err, 'nil')
end

function testcase.from_stats()
    -- test standard error - moved from stats_test.lua
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
    })

    local result = stderr(s)
    local stddev_val = stddev(s)
    local expected = stddev_val / math.sqrt(4)

    assert.is_number(result)
    assert.less(math.abs(result - expected), 1e-10)
end
