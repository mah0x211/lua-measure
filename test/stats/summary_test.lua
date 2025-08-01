require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local summary = require('measure.stats.summary')

-- Individual stats modules for consistency testing
local stderr = require('measure.stats.stderr')
local cv = require('measure.stats.cv')
local iqr = require('measure.stats.iqr')
local throughput = require('measure.stats.throughput')

local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.basic()
    -- test comprehensive summary statistics
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = summary(s)

    -- test structure
    assert.is_table(result)

    -- test that all expected fields are present and are numbers
    assert.is_number(result.mean)
    assert.is_number(result.stddev)
    assert.is_number(result.stderr)
    assert.is_number(result.variance)
    assert.is_number(result.cv)
    assert.is_number(result.iqr)
    assert.is_number(result.min)
    assert.is_number(result.max)
    assert.is_number(result.p25)
    assert.is_number(result.p50)
    assert.is_number(result.p75)
    assert.is_number(result.p95)
    assert.is_number(result.p99)
    assert.is_number(result.throughput)

    -- test some basic values
    assert.equal(result.mean, 3000)
    assert.equal(result.min, 1000)
    assert.equal(result.max, 5000)
    assert.equal(result.p50, 3000) -- median
end

function testcase.single_sample()
    -- test with single sample
    local s = create_mock_samples({
        1000,
    })

    local result = summary(s)

    assert.is_table(result)
    assert.equal(result.mean, 1000)
    assert.equal(result.min, 1000)
    assert.equal(result.max, 1000)
    assert.equal(result.p50, 1000)
    assert.is_nan(result.stderr)
    assert.equal(result.iqr, 0.0)
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        summary(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end

function testcase.from_stats()
    -- test comprehensive summary - moved from stats_test.lua
    local s = create_mock_samples({
        1000,
        1500,
        2000,
        2500,
        3000,
    })

    local result = summary(s)

    -- test structure
    assert.is_table(result)
    assert.is_number(result.mean)
    assert.is_number(result.stddev)
    assert.is_number(result.stderr)
    assert.is_number(result.variance)
    assert.is_number(result.cv)
    assert.is_number(result.iqr)
    assert.is_number(result.min)
    assert.is_number(result.max)
    assert.is_number(result.p25)
    assert.is_number(result.p50)
    assert.is_number(result.p75)
    assert.is_number(result.p95)
    assert.is_number(result.p99)
    assert.is_number(result.throughput)

    -- test consistency with individual modules
    assert.equal(result.mean, s:mean())
    assert.equal(result.stddev, s:stddev())
    assert.equal(result.stderr, stderr(s))
    assert.equal(result.cv, cv(s))
    assert.equal(result.iqr, iqr(s))
    assert.equal(result.min, 1000) -- minimum value
    assert.equal(result.max, 3000) -- maximum value
    assert.equal(result.throughput, throughput(s))
end

function testcase.nan_handling()
    -- test NaN handling in edge cases - moved from stats_test.lua
    local s_single = create_mock_samples({
        1000,
    })

    -- stderr should be NaN for single sample
    assert.is_nan(stderr(s_single))

    -- cv should be NaN for single sample (stddev=0)
    assert.is_nan(cv(s_single))
end
