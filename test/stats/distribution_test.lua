local testcase = require('testcase')
local assert = require('assert')
local distribution = require('measure.stats.distribution')
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

-- Test histogram/distribution calculation
function testcase.basic()
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
        6000,
        7000,
        8000,
        9000,
        10000,
    })

    -- Test with default bin count
    local result = distribution(s)

    -- Verify result structure
    assert.is_table(result)
    assert.is_table(result.bin_edges)
    assert.is_table(result.frequencies)

    -- Default should have 10 bins, so 11 bin edges
    assert.equal(#result.bin_edges, 11)
    assert.equal(#result.frequencies, 10)

    -- Verify bin edges are sorted
    for i = 2, #result.bin_edges do
        assert.greater_or_equal(result.bin_edges[i], result.bin_edges[i - 1])
    end

    -- Verify frequencies sum to total sample count
    local total_freq = 0
    for i = 1, #result.frequencies do
        total_freq = total_freq + result.frequencies[i]
    end
    assert.equal(total_freq, 10)
end

-- Test with custom bin count
function testcase.custom_bins()
    local s = create_mock_samples({
        1000,
        2000,
        3000,
        4000,
        5000,
    })

    -- Test with 3 bins
    local result = distribution(s, 3)

    assert.equal(#result.bin_edges, 4) -- 3 bins = 4 edges
    assert.equal(#result.frequencies, 3)

    -- Verify frequencies sum to total sample count
    local total_freq = 0
    for i = 1, #result.frequencies do
        total_freq = total_freq + result.frequencies[i]
    end
    assert.equal(total_freq, 5)
end

-- Test with identical values (edge case)
function testcase.identical_values()
    local s_identical = create_mock_samples({
        5000,
        5000,
        5000,
        5000,
        5000,
    })

    local result = distribution(s_identical, 5)

    -- Should still create the requested number of bins
    assert.equal(#result.bin_edges, 6)
    assert.equal(#result.frequencies, 5)

    -- All values should be in the first bin (or distributed across bins with identical edges)
    local total_freq = 0
    for i = 1, #result.frequencies do
        total_freq = total_freq + result.frequencies[i]
    end
    assert.equal(total_freq, 5)
end

-- Test with wide range of values
function testcase.wide_range()
    local s = create_mock_samples({
        1000,
        5000,
        10000,
        50000,
        100000,
    })

    local result = distribution(s, 4)

    assert.equal(#result.bin_edges, 5)
    assert.equal(#result.frequencies, 4)

    -- Verify total count
    local total_freq = 0
    for i = 1, #result.frequencies do
        total_freq = total_freq + result.frequencies[i]
    end
    assert.equal(total_freq, 5)

    -- First bin edge should be minimum value
    assert.equal(result.bin_edges[1], 1000)
    -- Last bin edge should be maximum value
    assert.equal(result.bin_edges[5], 100000)
end

-- Test with single value
function testcase.single_value()
    local s_single = create_mock_samples({
        42000,
    })

    local result = distribution(s_single, 3)

    assert.equal(#result.bin_edges, 4)
    assert.equal(#result.frequencies, 3)

    -- All frequency should be in one bin, totaling 1
    local total_freq = 0
    for i = 1, #result.frequencies do
        total_freq = total_freq + result.frequencies[i]
    end
    assert.equal(total_freq, 1)
end

-- Test error handling
function testcase.error_handling()
    local s = create_mock_samples({
        1000,
        2000,
        3000,
    })

    -- Test with nil samples should throw error
    assert.throws(function()
        distribution(nil)
    end)

    -- Test with invalid bin count
    assert.throws(function()
        distribution(s, 0) -- Zero bins
    end)

    assert.throws(function()
        distribution(s, -5) -- Negative bins
    end)

    -- Test with empty samples
    local empty_data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = 0,
        count = 0,
        gc_step = 0,
        base_kb = 1,
    }
    local empty_samples = samples(empty_data)
    assert.throws(function()
        distribution(empty_samples)
    end)
end
