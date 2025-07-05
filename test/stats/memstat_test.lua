local testcase = require('testcase')
local assert = require('assert')
local memstat = require('measure.stats.memstat')
local samples = require('measure.samples')

-- Helper function to create mock samples with memory allocation data
local function create_mock_samples_with_memory(time_values, memory_data)
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
        cl = 95,
        rciw = 5.0,
    }

    for i, time_ns in ipairs(time_values) do
        data.time_ns[i] = time_ns
        data.before_kb[i] = memory_data.before_kb[i] or 100
        data.after_kb[i] = memory_data.after_kb[i] or 150
        data.allocated_kb[i] = memory_data.allocated_kb[i] or 50
    end

    local s, err = samples(data)
    if not s then
        error("Failed to create mock samples: " .. (err or "unknown error"))
    end
    return s
end

-- Test memory allocation pattern analysis
function testcase.basic()
    local s = create_mock_samples_with_memory({
        1000,
        2000,
        3000,
        4000,
        5000,
    }, {
        before_kb = {
            100,
            150,
            200,
            250,
            300,
        },
        after_kb = {
            120,
            180,
            240,
            300,
            360,
        },
        allocated_kb = {
            20,
            30,
            40,
            50,
            60,
        },
    })

    local result = memstat(s)

    -- Verify result structure
    assert.is_table(result)
    assert.is_number(result.allocation_rate)
    assert.is_number(result.gc_impact)
    assert.is_number(result.memory_efficiency)
    assert.is_number(result.peak_memory)

    -- Allocation rate should be average of allocated_kb
    assert.equal(result.allocation_rate, 40.0) -- (20+30+40+50+60)/5 = 40

    -- Peak memory should be maximum after_kb
    assert.equal(result.peak_memory, 360)

    -- Memory efficiency should be inverse of allocation rate
    assert.less(math.abs(result.memory_efficiency - 1.0 / 40.0), 0.001)
end

-- Test allocation rate calculation
function testcase.allocation_rate()
    local s = create_mock_samples_with_memory({
        1000,
        2000,
        3000,
    }, {
        before_kb = {
            100,
            100,
            100,
        },
        after_kb = {
            150,
            150,
            150,
        },
        allocated_kb = {
            10,
            20,
            30,
        },
    })

    local result = memstat(s)

    -- Average allocation should be (10+20+30)/3 = 20
    assert.equal(result.allocation_rate, 20.0)

    -- Memory efficiency should be 1/20 = 0.05
    assert.less(math.abs(result.memory_efficiency - 0.05), 0.001)
end

-- Test peak memory detection
function testcase.peak_detection()
    local s = create_mock_samples_with_memory({
        1000,
        2000,
        3000,
        4000,
    }, {
        before_kb = {
            100,
            200,
            150,
            120,
        },
        after_kb = {
            120,
            250,
            180,
            140,
        }, -- peak = 250
        allocated_kb = {
            20,
            50,
            30,
            20,
        },
    })

    local result = memstat(s)

    -- Peak memory should be 250
    assert.equal(result.peak_memory, 250)
end

-- Test GC impact correlation
function testcase.gc_impact()
    -- Create scenario where high allocation correlates with high execution time
    local s = create_mock_samples_with_memory({
        1000,
        2000,
        3000,
        4000,
    }, -- increasing time
    {
        before_kb = {
            100,
            100,
            100,
            100,
        },
        after_kb = {
            110,
            120,
            130,
            140,
        },
        allocated_kb = {
            10,
            20,
            30,
            40,
        }, -- increasing allocation
    })

    local result = memstat(s)

    -- GC impact should show positive correlation (allocation increases with time)
    assert.greater(result.gc_impact, 0)
end

-- Test with zero allocation
function testcase.zero_allocation()
    local s = create_mock_samples_with_memory({
        1000,
        2000,
        3000,
    }, {
        before_kb = {
            100,
            100,
            100,
        },
        after_kb = {
            100,
            100,
            100,
        },
        allocated_kb = {
            0,
            0,
            0,
        },
    })

    local result = memstat(s)

    -- Allocation rate should be 0
    assert.equal(result.allocation_rate, 0.0)

    -- Memory efficiency should be 0 (since allocation_rate is 0)
    assert.equal(result.memory_efficiency, 0.0)

    -- Peak memory should be 100
    assert.equal(result.peak_memory, 100)
end

-- Test with identical memory patterns
function testcase.identical_patterns()
    local s = create_mock_samples_with_memory({
        2000,
        2000,
        2000,
    }, -- identical times
    {
        before_kb = {
            100,
            100,
            100,
        },
        after_kb = {
            150,
            150,
            150,
        },
        allocated_kb = {
            50,
            50,
            50,
        }, -- identical allocations
    })

    local result = memstat(s)

    -- GC impact should be 0 (no correlation)
    assert.equal(result.gc_impact, 0.0)

    -- Allocation rate should be 50
    assert.equal(result.allocation_rate, 50.0)
end

-- Test error handling
function testcase.error_handling()
    -- Test with nil samples should throw error
    assert.throws(function()
        memstat(nil)
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
        cl = 95,
        rciw = 5.0,
    }
    local empty_samples = samples(empty_data)
    assert.throws(function()
        memstat(empty_samples)
    end)
end
