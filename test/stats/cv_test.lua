require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local cv = require('measure.stats.cv')
local samples = require('measure.samples')
local mean = require('measure.stats.mean')
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
    -- test coefficient of variation calculation
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = cv(s)

    assert.is_number(result)
    assert.greater(result, 0) -- CV should be positive
end

function testcase.identical_values()
    -- test with identical values (CV should be 0)
    local s = create_mock_samples({
        1000,
        1000,
        1000,
        1000,
    })

    local result = cv(s)

    assert.is_number(result)
    assert.equal(result, 0.0) -- no variation
end

function testcase.zero_mean()
    -- test with zero mean (should return NaN)
    local s = create_mock_samples({
        0,
        0,
        0,
    })

    local result = cv(s)

    -- check for NaN
    assert.is_nan(result)
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        cv(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end

function testcase.nan_conditions()
    -- Create samples with invalid data to trigger NaN conditions
    -- This attempts to trigger the stddev or mean NaN checks

    -- Test with empty-like samples that might cause stddev to return NaN
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
        local s = samples(empty_data)
        cv(s) -- This will error if s is nil
    end)

    -- Should fail when trying to use nil samples
    assert.is_false(ok)
    assert.match(err, 'nil')

    -- Test with minimal data that could cause numerical issues
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
        local result = cv(s)
        -- With single sample, stddev should be 0, mean should be 0, causing NaN
        assert.is_nan(result)
    else
        -- If samples creation fails, verify the error
        assert.match(serr, 'invalid')
    end
end

function testcase.from_stats()
    -- test coefficient of variation - moved from stats_test.lua
    local s = create_mock_samples({
        1000,
        2000,
        3000,
    })

    local result = cv(s)
    local mean_val = mean(s)
    local stddev_val = stddev(s)

    assert.is_number(result)
    assert.equal(result, stddev_val / mean_val)
end
