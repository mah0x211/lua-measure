require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local p25 = require('measure.stats.p25')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.test_p25_basic()
    -- test 25th percentile calculation
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = p25(s)

    assert.is_number(result)
    assert.equal(result, 2000) -- 25th percentile
end

function testcase.test_p25_single_sample()
    -- test with single sample
    local s = create_mock_samples({
        1000,
    })

    local result = p25(s)

    assert.is_number(result)
    assert.equal(result, 1000)
end

function testcase.test_p25_error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        p25(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end
