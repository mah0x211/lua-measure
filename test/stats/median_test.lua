require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local median = require('measure.stats.median')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.test_median_odd_count()
    -- test with odd number of samples
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = median(s)

    assert.is_number(result)
    assert.equal(result, 3000) -- middle value
end

function testcase.test_median_even_count()
    -- test with even number of samples
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
    })

    local result = median(s)

    assert.is_number(result)
    assert.equal(result, 2500) -- average of middle two values
end

function testcase.test_median_single_sample()
    -- test with single sample
    local s = create_mock_samples({
        1000,
    })

    local result = median(s)

    assert.is_number(result)
    assert.equal(result, 1000)
end

function testcase.test_median_error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        median(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end
