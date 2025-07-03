require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local p25 = require('measure.stats.p25')
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
