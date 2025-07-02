local testcase = require('testcase')
local assert = require('assert')
local outliers = require('measure.stats.outliers')
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

function testcase.tukey_method()
    -- test with data containing outliers
    local s = create_mock_samples({
        100,
        110,
        120,
        130,
        140,
        150,
        160,
        170,
        180,
        1000,
    })

    local result = outliers(s)

    -- test that outliers returns an array
    assert.is_table(result)
    -- test that 1000 is detected as outlier (index 10)
    assert.greater(#result, 0)
end

function testcase.mad_method()
    -- test MAD method
    local s = create_mock_samples({
        100,
        110,
        120,
        130,
        140,
        150,
        160,
        170,
        180,
        1000,
    })

    local result = outliers(s, "mad")

    assert.is_table(result)
    assert.greater(#result, 0)
end

function testcase.no_outliers()
    -- test with no outliers
    local s = create_mock_samples({
        100,
        110,
        120,
        130,
        140,
    })

    local result = outliers(s)

    assert.is_table(result)
    assert.equal(#result, 0)
end

function testcase.error_handling()
    -- test error handling with nil samples
    local ok, err = pcall(function()
        outliers(nil)
    end)

    assert.is_false(ok)
    assert.match(err, 'samples')
end
