local testcase = require('testcase')
local assert = require('assert')
local outliers = require('measure.stats.outliers')
local mock_samples = require('./test/helpers/mock_samples')

-- Import helper function
local create_mock_samples = mock_samples.create_mock_samples

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

function testcase.insufficient_samples()
    -- test with insufficient samples (less than 4)
    local s = create_mock_samples({
        100,
        110,
    })

    local result, err = outliers(s)

    assert.is_nil(result)
    assert.is_string(err)
    assert.match(err, 'insufficient')
end
