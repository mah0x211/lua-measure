local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples')
local sampler = require('measure.sampler')

-- Test measure.sampler module (function-based API)
function testcase.sampler_basic_call()
    local samples = new_samples(10)

    -- Test basic function call
    local count = 0
    local ok = sampler(function()
        count = count + 1
    end, samples)
    assert.is_true(ok)
    assert.equal(count, 10) -- Should use full capacity
end

function testcase.sampler_invalid_args()
    local samples = new_samples(10)

    -- Test non-function first argument
    assert.throws(function()
        sampler('not a function', samples)
    end)

    assert.throws(function()
        sampler(123, samples)
    end)

    assert.throws(function()
        sampler({}, samples)
    end)

    -- Test invalid samples argument
    assert.throws(function()
        sampler(function()
        end, 'invalid')
    end)

    assert.throws(function()
        sampler(function()
        end, {})
    end)

    assert.throws(function()
        sampler(function()
        end, 123)
    end)
end

function testcase.sampler_run_basic()
    local samples = new_samples(10)

    -- Test basic run (uses full capacity by default)
    local count = 0
    local ok = sampler(function()
        count = count + 1
        -- Add small loop to ensure measurable time
        local sum = 0
        for i = 1, 100 do
            sum = sum + i
        end
    end, samples)
    assert.is_true(ok)

    -- Check that function was called (default: capacity times)
    assert.equal(count, 10)

    -- Check samples were collected
    assert.equal(#samples, 10)

    -- Check dump returns data with new column-oriented format
    local data = samples:dump()
    assert.is_table(data)
    assert.equal(#data.time_ns, 10)
    assert.equal(#data.before_kb, 10)
    assert.equal(#data.after_kb, 10)
    assert.equal(#data.allocated_kb, 10)
    for i = 1, 10 do
        assert.is_uint(data.time_ns[i])
        assert.greater(data.time_ns[i], 0) -- Should have some elapsed time
        assert.is_uint(data.before_kb[i])
        assert.is_uint(data.after_kb[i])
        assert.is_uint(data.allocated_kb[i])
    end
end

function testcase.sampler_run_with_warmup()
    local samples = new_samples(100)

    -- Test with warmup (using new API: function, samples, warmup)
    local warmup_count = 0
    local sample_count = 0
    local ok = sampler(function(is_warmup)
        if is_warmup then
            warmup_count = warmup_count + 1
        else
            sample_count = sample_count + 1
        end
        -- Add small loop to ensure measurable time
        local sum = 0
        for i = 1, 100 do
            sum = sum + i
        end
    end, samples, 1) -- 1 second warmup
    assert.is_true(ok)

    -- Should have some warmup calls
    assert.greater(warmup_count, 0)
    -- Should have exactly samples.capacity sample calls
    assert.equal(sample_count, 100)
    -- Samples should be collected
    assert.equal(#samples, 100)

    -- Test with 0 warmup (no warmup)
    local samples2 = new_samples(10)
    warmup_count = 0
    sample_count = 0
    ok = sampler(function(is_warmup)
        if is_warmup then
            warmup_count = warmup_count + 1
        else
            sample_count = sample_count + 1
        end
    end, samples2) -- no warmup (default 0)
    assert.is_true(ok)

    -- Should have no warmup calls
    assert.equal(warmup_count, 0)
    -- Should have exactly 10 sample calls
    assert.equal(sample_count, 10)
    assert.equal(#samples2, 10)
end

function testcase.sampler_warmup_error_handling()
    local samples = new_samples(10)

    -- Test warmup error handling
    local ok, err_msg = sampler(function(is_warmup)
        if is_warmup then
            error('warmup error')
        end
    end, samples, 1) -- 1 second warmup
    assert.is_false(ok)
    assert.match(err_msg, 'runtime error:.*warmup error', false)
end

function testcase.sampler_invalid_warmup_args()
    local samples = new_samples(10)

    -- Test invalid warmup values
    -- Note: Based on sampler.c, negative warmup is normalized to 0, so it doesn't throw
    local ok = sampler(function()
    end, samples, -1) -- negative warmup (normalized to 0)
    assert.is_true(ok)

    assert.throws(function()
        sampler(function()
        end, samples, 'invalid') -- non-number warmup
    end)
end

function testcase.sampler_function_errors()
    local samples = new_samples(10)

    -- Test runtime error handling
    local ok, err = sampler(function()
        error('test error')
    end, samples)

    assert.is_false(ok)
    assert.match(err, 'runtime error:.*test error', false)

    -- Test nil access error
    ok, err = sampler(function()
        local x = nil
        return x.unknown_field -- Try to access field on nil  -- luacheck: ignore x.unknown_field
    end, samples)

    assert.is_false(ok)
    assert.match(err, 'runtime error:', false)

    -- Test type error
    ok, err = sampler(function()
        return 1 + {}
    end, samples)

    assert.is_false(ok)
    assert.match(err, 'runtime error:', false)
end

function testcase.sampler_edge_cases()
    -- Test with capacity 1
    local samples = new_samples(1)

    local count = 0
    local ok = sampler(function()
        count = count + 1
        -- Add small loop to ensure measurable time
        local sum = 0
        for i = 1, 100 do
            sum = sum + i
        end
    end, samples)
    assert.is_true(ok)

    assert.equal(count, 1)
    assert.equal(#samples, 1)
end

function testcase.sampler_performance_characteristics()
    local samples = new_samples(100)

    -- Test with very fast function
    local ok = sampler(function()
        -- Small loop to ensure measurable time
        local sum = 0
        for i = 1, 10 do
            sum = sum + i
        end
    end, samples)
    assert.is_true(ok)

    assert.equal(#samples, 100)
    local data = samples:dump()

    -- All samples should have measurable time
    assert.equal(#data.time_ns, 100)
    for i = 1, 100 do
        assert.greater(data.time_ns[i], 0) -- Should be measurable
    end

    -- Test with slower function
    local samples2 = new_samples(10)

    ok = sampler(function()
        -- Do some work
        local sum = 0
        for i = 1, 1000 do
            sum = sum + i
        end
        return sum
    end, samples2)
    assert.is_true(ok)

    assert.equal(#samples2, 10)
    local data2 = samples2:dump()

    -- These samples should generally be larger
    assert.equal(#data2.time_ns, 10)
    for i = 1, 10 do
        assert.greater(data2.time_ns[i], 0) -- Should be measurable
    end
end

function testcase.sampler_memory_management()
    -- Test multiple samples objects
    local samples_list = {}

    for i = 1, 10 do
        samples_list[i] = new_samples(5)
    end

    -- Use them
    for i = 1, 10 do
        local ok = sampler(function()
            -- Add small loop to ensure measurable time
            local sum = 0
            for j = 1, 100 do
                sum = sum + j
            end
            return i * 2 + sum
        end, samples_list[i])
        assert.is_true(ok)
        assert.equal(#samples_list[i], 5)
    end

    -- Clear references and force GC
    samples_list = nil -- luacheck: ignore 311
    collectgarbage('collect')
    collectgarbage('collect')

    -- Test large data
    local big_samples = new_samples(1000)

    local ok = sampler(function()
        -- Small loop to ensure measurable time
        local sum = 0
        for i = 1, 10 do
            sum = sum + i
        end
    end, big_samples)
    assert.is_true(ok)

    assert.equal(#big_samples, 1000)

    -- Clear and GC
    big_samples = nil -- luacheck: ignore 311
    collectgarbage('collect')
    collectgarbage('collect')
end

function testcase.sampler_gc_behavior()
    -- Test with function-based API - no persistent sampler object
    local samples = new_samples(10)

    local ok = sampler(function()
        -- Add small loop to ensure measurable time
        local sum = 0
        for i = 1, 100 do
            sum = sum + i
        end
        return true
    end, samples)
    assert.is_true(ok)

    assert.equal(#samples, 10)
end

function testcase.sampler_function_protection()
    local samples = new_samples(10)

    -- Test argument validation (already covered in sampler_invalid_args)
    -- Function-based API doesn't have method protection issues
    local ok = sampler(function()
    end, samples)
    assert.is_true(ok)
end

function testcase.sampler_samples_reset()
    -- Test that samples are reset on each run
    local samples = new_samples(5)

    -- First run
    local ok = sampler(function()
        -- Add small loop to ensure measurable time
        local sum = 0
        for i = 1, 100 do
            sum = sum + i
        end
    end, samples)
    assert.is_true(ok)
    assert.equal(#samples, 5)

    -- Second run - samples should be reset automatically
    ok = sampler(function()
        -- Add small loop to ensure measurable time
        local sum = 0
        for i = 1, 100 do
            sum = sum + i
        end
    end, samples)
    assert.is_true(ok)
    assert.equal(#samples, 5) -- Should have 5 new samples, not 10
end

function testcase.sampler_memory_error_simulation()
    -- Test memory allocation error handling
    -- This is difficult to simulate in normal conditions
    local samples = new_samples(1)

    -- Test with a function that allocates a lot of memory
    -- This won't trigger LUA_ERRMEM but tests the path exists
    local ok, err = sampler(function()
        local huge = {}
        for i = 1, 100000 do
            huge[i] = string.rep("x", 1000)
        end
        return huge -- Use the variable to avoid unused warning
    end, samples)

    -- Either succeeds or fails with runtime error (not memory error in practice)
    if not ok then
        assert.match(err, "error:", false)
    end
end

function testcase.sampler_with_gc_data()
    local samples = new_samples(10, 0) -- Full GC mode

    -- Test with function that allocates memory
    local count = 0
    local ok = sampler(function(is_warmup)
        if not is_warmup then
            count = count + 1
            -- Allocate some memory
            local t = {}
            for i = 1, 100 do
                t[i] = string.rep('x', 100)
            end
            return t
        end
    end, samples)

    assert.is_true(ok)
    assert.equal(count, 10)
    assert.equal(#samples, 10)

    -- Check both time and GC data was collected
    local data = samples:dump()
    assert.is_table(data)
    assert.equal(#data.time_ns, 10)
    assert.equal(#data.before_kb, 10)
    assert.equal(#data.after_kb, 10)
    assert.equal(#data.allocated_kb, 10)

    -- Verify GC samples have valid data
    for i = 1, 10 do
        assert.is_uint(data.time_ns[i])
        assert.greater(data.time_ns[i], 0)
        assert.is_uint(data.before_kb[i])
        assert.is_uint(data.after_kb[i])
        assert.is_uint(data.allocated_kb[i])
        -- Memory should typically increase after allocation
        assert(data.after_kb[i] >= data.before_kb[i])
        assert(data.allocated_kb[i] >= 0)
    end
end

function testcase.sampler_gc_with_warmup()
    local samples = new_samples(5, -1) -- Disabled GC mode

    -- Test with GC data collection and warmup
    local warmup_count = 0
    local sample_count = 0
    local ok = sampler(function(is_warmup)
        if is_warmup then
            warmup_count = warmup_count + 1
        else
            sample_count = sample_count + 1
            -- Allocate memory during sampling
            local _ = {}
            for i = 1, 50 do
                _[i] = string.rep('y', 50)
            end
        end
    end, samples, 1) -- 1 second warmup

    assert.is_true(ok)
    assert.greater(warmup_count, 0)
    assert.equal(sample_count, 5)
    assert.equal(#samples, 5)

    -- Check GC data is collected for non-warmup calls only
    local data = samples:dump()
    assert.equal(#data.time_ns, 5)
    assert.equal(#data.before_kb, 5)
    assert.equal(#data.after_kb, 5)
    assert.equal(#data.allocated_kb, 5)
end

function testcase.sampler_different_gc_modes()
    local samples1 = new_samples(3, -1) -- Disabled GC
    local samples2 = new_samples(3, 0) -- Full GC
    local samples3 = new_samples(3, 1024) -- Step GC

    local test_func = function(is_warmup)
        if not is_warmup then
            local _ = {}
            for i = 1, 200 do
                _[i] = string.rep('z', 200)
            end
        end
    end

    -- Test disabled GC
    local ok = sampler(test_func, samples1)
    assert.is_true(ok)
    assert.equal(#samples1, 3)

    -- Test full GC
    ok = sampler(test_func, samples2)
    assert.is_true(ok)
    assert.equal(#samples2, 3)

    -- Test step GC
    ok = sampler(test_func, samples3)
    assert.is_true(ok)
    assert.equal(#samples3, 3)

    -- All should have collected both time and GC data
    local data1 = samples1:dump()
    local data2 = samples2:dump()
    local data3 = samples3:dump()

    assert.equal(#data1.time_ns, 3)
    assert.equal(#data1.before_kb, 3)
    assert.equal(#data2.time_ns, 3)
    assert.equal(#data2.before_kb, 3)
    assert.equal(#data3.time_ns, 3)
    assert.equal(#data3.before_kb, 3)
end

function testcase.sampler_gc_data_without_allocation()
    local samples = new_samples(5, 0) -- Full GC mode

    -- Test function that doesn't allocate memory
    local count = 0
    local ok = sampler(function(is_warmup)
        if not is_warmup then
            count = count + 1
            -- Simple arithmetic, no allocation
            local sum = 0
            for i = 1, 100 do
                sum = sum + i
            end
        end
    end, samples)

    assert.is_true(ok)
    assert.equal(count, 5)
    assert.equal(#samples, 5)

    -- Check GC data shows minimal/no allocation
    local data = samples:dump()
    for i = 1, 5 do
        -- Should have minimal or no allocation
        assert(data.allocated_kb[i] >= 0)
        -- Most iterations should have 0 allocation
    end
end

function testcase.sampler_gc_error_handling()
    local samples = new_samples(3, 0) -- Full GC mode

    -- Test function error with GC data collection
    local ok, err = sampler(function(is_warmup)
        if not is_warmup then
            error('test error with GC')
        end
    end, samples)

    assert.is_false(ok)
    assert.match(err, 'runtime error:.*test error with GC', false)

    -- First sample initialization happens before error
    assert.equal(#samples, 1) -- One sample initialized but failed during execution
end

