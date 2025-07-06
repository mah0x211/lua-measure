require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local iqr = require('measure.stats.iqr')
local samples = require('measure.samples')
local p25 = require('measure.stats.p25')
local p75 = require('measure.stats.p75')

local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.basic()
    -- test IQR calculation (75th - 25th percentile)
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = iqr(s)

    assert.is_number(result)
    assert.equal(result, 2000) -- 4000 - 2000 = 2000
end

function testcase.single_sample()
    -- test with single sample (IQR should be 0)
    local s = create_mock_samples({
        1000,
    })

    local result = iqr(s)

    assert.is_number(result)
    assert.equal(result, 0.0) -- Q3 - Q1 = 1000 - 1000 = 0
end

function testcase.identical_values()
    -- test with identical values (IQR should be 0)
    local s = create_mock_samples({
        1000,
        1000,
        1000,
        1000,
    })

    local result = iqr(s)

    assert.is_number(result)
    assert.equal(result, 0.0) -- no variation
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        iqr(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end

function testcase.nan_conditions()
    -- Test with minimal data that could cause p25 or p75 to return NaN
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
        cl = 95,
        rciw = 5.0,
    }

    local s, serr = samples(minimal_data)
    if s then
        local result = iqr(s)
        -- With single sample, p25 and p75 should be the same, IQR = 0
        assert.equal(result, 0.0)
    else
        -- If samples creation fails, verify the error
        assert.match(serr, 'invalid')
    end

    -- Test with empty-like data to try to trigger NaN from percentile calculations
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

    local ok, err = pcall(function()
        local s2 = samples(empty_data)
        iqr(s2) -- This will error if s2 is nil
    end)

    -- Should fail when trying to use nil samples
    assert.is_false(ok)
    assert.match(err, 'nil')
end

function testcase.from_stats()
    -- test interquartile range - moved from stats_test.lua
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = iqr(s)
    local q1 = p25(s)
    local q3 = p75(s)
    local expected = q3 - q1

    assert.is_number(result)
    assert.equal(result, expected)
end
