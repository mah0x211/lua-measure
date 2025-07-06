require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local p75 = require('measure.stats.p75')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.test_p75_basic()
    -- test 75th percentile calculation
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = p75(s)

    assert.is_number(result)
    assert.equal(result, 4000) -- 75th percentile
end

function testcase.test_p75_single_sample()
    -- test with single sample
    local s = create_mock_samples({
        1000,
    })

    local result = p75(s)

    assert.is_number(result)
    assert.equal(result, 1000)
end

function testcase.test_p75_error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        p75(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end
