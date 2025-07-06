local testcase = require('testcase')
local assert = require('assert')
local mad = require('measure.stats.mad')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

function testcase.known_data()
    -- test with known data
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    local result = mad(s)

    -- Median is 3000, absolute deviations are [2000, 1000, 0, 1000, 2000]
    -- MAD = median of [0, 1000, 1000, 2000, 2000] = 1000
    assert.is_number(result)
    assert.equal(result, 1000.0)
end

function testcase.edge_cases()
    -- test with single value
    local s_single = create_mock_samples({
        42,
    })
    assert.equal(mad(s_single), 0.0)

    -- test with identical values
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(mad(s_identical), 0.0)

    -- test with two values
    local s_two = create_mock_samples({
        1000,
        3000,
    })
    assert.equal(mad(s_two), 1000.0)
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        mad(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end
