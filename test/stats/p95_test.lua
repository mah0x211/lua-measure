require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local p95 = require('measure.stats.p95')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.test_p95_basic()
    -- test 95th percentile calculation
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = p95(s)

    assert.is_number(result)
    assert.equal(result, 4800) -- 95th percentile
end

function testcase.test_p95_single_sample()
    -- test with single sample
    local s = create_mock_samples({
        1000,
    })

    local result = p95(s)

    assert.is_number(result)
    assert.equal(result, 1000)
end

function testcase.test_p95_error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        p95(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end
