local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples')

-- Helper function to create valid samples data
local function create_samples_data(time_values, extra_fields)
    local count = #time_values
    local data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = count,
        count = count,
        gc_step = 0,
        base_kb = 1, -- Changed from 0 to 1
    }

    -- Override with extra fields if provided
    if extra_fields then
        for k, v in pairs(extra_fields) do
            data[k] = v
        end
    end

    for i, time_ns in ipairs(time_values) do
        data.time_ns[i] = time_ns
        data.before_kb[i] = 0
        data.after_kb[i] = 0
        data.allocated_kb[i] = 0
    end

    return data
end

-- Test measure.samples module basic functionality

function testcase.samples_new()
    -- Test default capacity
    local s = new_samples()
    assert.match(tostring(s), '^measure.samples: ', false)
    assert.equal(s:capacity(), 1000)
    assert.equal(#s, 0)

    -- Test custom capacity
    s = new_samples(100)
    assert.equal(s:capacity(), 100)
    assert.equal(#s, 0)

    -- Test large capacity
    s = new_samples(10000)
    assert.equal(s:capacity(), 10000)
    assert.equal(#s, 0)
end

function testcase.samples_new_invalid_args()
    -- Test invalid capacity (returns nil + error message)
    local s, err = new_samples(0)
    assert.is_nil(s)
    assert.match(err, "capacity must be > 0", false)

    s, err = new_samples(-1)
    assert.is_nil(s)
    assert.match(err, "capacity must be > 0", false)

    -- Test non-integer arguments (luaL_optinteger throws error for non-numbers)
    -- These should throw errors
    assert.throws(function()
        new_samples('invalid')
    end)

    -- Test empty table (restoration mode but missing fields - type check will fail)
    assert.throws(function()
        new_samples({})
    end)

    assert.throws(function()
        new_samples(true)
    end)

    -- Test multiple arguments (second arg should be ignored)
    s = new_samples(100, 200, 300)
    assert.equal(s:capacity(), 100)
end

function testcase.samples_dump()
    local s = new_samples(10)

    -- Test empty dump with new column-oriented format
    local data = s:dump()
    assert.is_table(data)
    assert.is_table(data.time_ns)
    assert.is_table(data.before_kb)
    assert.is_table(data.after_kb)
    assert.is_table(data.allocated_kb)
    assert.equal(#data.time_ns, 0)
    assert.equal(#data.before_kb, 0)
    assert.equal(#data.after_kb, 0)
    assert.equal(#data.allocated_kb, 0)

    -- Test metadata fields in dump
    assert.is_number(data.capacity)
    assert.equal(data.capacity, 10)
    assert.is_number(data.count)
    assert.equal(data.count, 0)
    assert.is_number(data.gc_step)
    assert.equal(data.gc_step, 0)
    assert.is_number(data.base_kb)
    assert.equal(data.base_kb, 0)
end

function testcase.samples_metamethods()
    local s = new_samples(100)

    -- Test __tostring
    assert.match(tostring(s), '^measure.samples: 0x', false)

    -- Test __len (initially 0)
    assert.equal(#s, 0)

    -- Test that metatable is protected
    assert.equal(getmetatable(s), "metatable is protected")
end

function testcase.samples_method_protection()
    local samples = new_samples(10)

    -- Test that we can't call methods on wrong type
    assert.throws(function()
        samples.capacity({})
    end)

    assert.throws(function()
        samples.dump('invalid')
    end)

    -- Test calling with colon syntax on wrong object
    assert.throws(function()
        new_samples().capacity({})
    end)
end

function testcase.samples_with_gc_step()
    -- Test samples with different GC configurations
    local s1 = new_samples(10) -- Default GC step (0 = full GC)
    assert.equal(s1:capacity(), 10)

    local s2 = new_samples(10, -1) -- Disabled GC
    assert.equal(s2:capacity(), 10)

    local s3 = new_samples(10, 0) -- Full GC
    assert.equal(s3:capacity(), 10)

    local s4 = new_samples(10, 1024) -- Step GC with 1024KB threshold
    assert.equal(s4:capacity(), 10)

    -- Test bug fix: negative gc_step values should be handled correctly
    local s5 = new_samples(10, -5) -- Negative value should be converted to -1
    assert.equal(s5:capacity(), 10)

    local s6 = new_samples(10, -100) -- Another negative value
    assert.equal(s6:capacity(), 10)
end

-- Test restoration functionality extensively

function testcase.samples_restore_valid_data()
    -- Test restoration with valid data using helper function
    local original_data = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    }, {
        capacity = 10,
        gc_step = 2048,
        base_kb = 512,
        before_kb = {
            100,
            110,
            120,
            130,
            140,
        },
        after_kb = {
            105,
            115,
            125,
            135,
            145,
        },
        allocated_kb = {
            5,
            5,
            5,
            5,
            5,
        },
    })

    local s = new_samples(original_data)
    assert.equal(s:capacity(), 10)
    assert.equal(#s, 5)

    -- Verify data was restored correctly
    local dump = s:dump()
    assert.equal(dump.capacity, 10)
    assert.equal(dump.count, 5)
    assert.equal(dump.gc_step, 2048)
    assert.equal(dump.base_kb, 512)
    assert.equal(#dump.time_ns, 5)
    assert.equal(dump.time_ns[1], 1000)
    assert.equal(dump.time_ns[2], 2000)
    assert.equal(dump.time_ns[3], 3000)
end

function testcase.samples_restore_error_missing_metadata()
    -- Test with missing capacity (type check will fail first)
    assert.throws(function()
        new_samples({
            time_ns = {
                1000,
                2000,
            },
            before_kb = {
                0,
                0,
            },
            after_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            count = 2,
            gc_step = 0,
            base_kb = 1,
            -- Missing capacity
        })
    end)

    -- Test with missing count (type check will fail first)
    assert.throws(function()
        new_samples({
            time_ns = {
                1000,
                2000,
            },
            before_kb = {
                0,
                0,
            },
            after_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            capacity = 2,
            gc_step = 0,
            base_kb = 1,
            -- Missing count
        })
    end)

    -- Test with zero capacity
    local bad_data3, err3 = new_samples({
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = 0,
        count = 0,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data3)
    assert.match(err3, "invalid field 'capacity': must be > 0", false)
end

function testcase.samples_restore_error_invalid_count()
    -- Test count > capacity
    local bad_data, err = new_samples({
        time_ns = {
            1000,
            2000,
            3000,
        },
        before_kb = {
            0,
            0,
            0,
        },
        after_kb = {
            0,
            0,
            0,
        },
        allocated_kb = {
            0,
            0,
            0,
        },
        capacity = 2, -- Less than count
        count = 3,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data)
    assert.match(err, "invalid field 'count': must be >= 0 and <= capacity",
                 false)
end

function testcase.samples_restore_error_missing_fields()
    -- Test missing time_ns field (throws due to type check)
    assert.throws(function()
        new_samples({
            before_kb = {
                0,
                0,
            },
            after_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            capacity = 2,
            count = 2,
            gc_step = 0,
            base_kb = 1,
            -- Missing time_ns
        })
    end)

    -- Test missing before_kb field (throws due to type check)
    assert.throws(function()
        new_samples({
            time_ns = {
                1000,
                2000,
            },
            after_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            capacity = 2,
            count = 2,
            gc_step = 0,
            base_kb = 1,
            -- Missing before_kb
        })
    end)

    -- Test missing after_kb field (throws due to type check)
    assert.throws(function()
        new_samples({
            time_ns = {
                1000,
                2000,
            },
            before_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            capacity = 2,
            count = 2,
            gc_step = 0,
            base_kb = 1,
            -- Missing after_kb
        })
    end)

    -- Test missing allocated_kb field (throws due to type check)
    assert.throws(function()
        new_samples({
            time_ns = {
                1000,
                2000,
            },
            before_kb = {
                0,
                0,
            },
            after_kb = {
                0,
                0,
            },
            capacity = 2,
            count = 2,
            gc_step = 0,
            base_kb = 1,
            -- Missing allocated_kb
        })
    end)
end

function testcase.samples_restore_error_invalid_field_types()
    -- Test non-table time_ns field (throws due to type check)
    assert.throws(function()
        new_samples({
            time_ns = "not a table",
            before_kb = {
                0,
                0,
            },
            after_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            capacity = 2,
            count = 2,
            gc_step = 0,
            base_kb = 1,
        })
    end)

    -- Test non-table before_kb field (throws due to type check)
    assert.throws(function()
        new_samples({
            time_ns = {
                1000,
                2000,
            },
            before_kb = "not a table",
            after_kb = {
                0,
                0,
            },
            allocated_kb = {
                0,
                0,
            },
            capacity = 2,
            count = 2,
            gc_step = 0,
            base_kb = 1,
        })
    end)
end

function testcase.samples_restore_error_array_size_mismatch()
    -- Test time_ns array size mismatch
    local bad_data1, err1 = new_samples({
        time_ns = {
            1000,
        }, -- Size 1, but count is 2
        before_kb = {
            0,
            0,
        },
        after_kb = {
            0,
            0,
        },
        allocated_kb = {
            0,
            0,
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data1)
    assert.match(err1, "array size does not match", false)

    -- Test before_kb array size mismatch
    local bad_data2, err2 = new_samples({
        time_ns = {
            1000,
            2000,
        },
        before_kb = {
            0,
        }, -- Size 1, but count is 2
        after_kb = {
            0,
            0,
        },
        allocated_kb = {
            0,
            0,
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data2)
    assert.match(err2, "array size does not match", false)

    -- Test after_kb array size mismatch
    local bad_data3, err3 = new_samples({
        time_ns = {
            1000,
            2000,
        },
        before_kb = {
            0,
            0,
        },
        after_kb = {
            0,
        }, -- Size 1, but count is 2
        allocated_kb = {
            0,
            0,
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data3)
    assert.match(err3, "array size does not match", false)

    -- Test allocated_kb array size mismatch
    local bad_data4, err4 = new_samples({
        time_ns = {
            1000,
            2000,
        },
        before_kb = {
            0,
            0,
        },
        after_kb = {
            0,
            0,
        },
        allocated_kb = {
            0,
        }, -- Size 1, but count is 2
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data4)
    assert.match(err4, "array size does not match", false)
end

function testcase.samples_restore_error_non_numeric_values()
    -- Test non-numeric values in time_ns (returns nil + error)
    local bad_data1, err1 = new_samples({
        time_ns = {
            1000,
            "not a number",
        },
        before_kb = {
            0,
            0,
        },
        after_kb = {
            0,
            0,
        },
        allocated_kb = {
            0,
            0,
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data1)
    assert.match(err1, "must be a integer >= 0")

    -- Test non-numeric values in before_kb (returns nil + error)
    local bad_data2, err2 = new_samples({
        time_ns = {
            1000,
            2000,
        },
        before_kb = {
            0,
            "not a number",
        },
        after_kb = {
            0,
            0,
        },
        allocated_kb = {
            0,
            0,
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data2)
    assert.match(err2, "must be a integer >= 0")

    -- Test non-numeric values in after_kb (returns nil + error)
    local bad_data3, err3 = new_samples({
        time_ns = {
            1000,
            2000,
        },
        before_kb = {
            0,
            0,
        },
        after_kb = {
            0,
            "not a number",
        },
        allocated_kb = {
            0,
            0,
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data3)
    assert.match(err3, "must be a integer >= 0")

    -- Test non-numeric values in allocated_kb (returns nil + error)
    local bad_data4, err4 = new_samples({
        time_ns = {
            1000,
            2000,
        },
        before_kb = {
            0,
            0,
        },
        after_kb = {
            0,
            0,
        },
        allocated_kb = {
            0,
            "not a number",
        },
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
    })
    assert.is_nil(bad_data4)
    assert.match(err4, "must be a integer >= 0")
end

function testcase.samples_gc_explicit()
    -- Test explicit garbage collection of samples object
    local s = new_samples(10)
    assert.equal(s:capacity(), 10)

    -- Force garbage collection explicitly
    collectgarbage('collect')

    -- Object should still be functional after GC
    assert.equal(s:capacity(), 10)
    assert.equal(#s, 0)

    -- Test dump still works
    local data = s:dump()
    assert.is_table(data)
    assert.equal(data.capacity, 10)
end

function testcase.samples_gc_step_method()
    -- Test gc_step() method with default value (0)
    local s1 = new_samples(10)
    assert.equal(s1:gc_step(), 0)

    -- Test gc_step() method with specified value (1024)
    local s2 = new_samples(10, 1024)
    assert.equal(s2:gc_step(), 1024)

    -- Test gc_step() method with disabled GC (-1)
    local s3 = new_samples(10, -1)
    assert.equal(s3:gc_step(), -1)

    -- Test gc_step() method with negative values (should be converted to -1)
    local s4 = new_samples(10, -5)
    assert.equal(s4:gc_step(), -1)

    local s5 = new_samples(10, -100)
    assert.equal(s5:gc_step(), -1)

    -- Test gc_step() method with zero (full GC)
    local s6 = new_samples(10, 0)
    assert.equal(s6:gc_step(), 0)

    -- Test gc_step() method with large positive value
    local s7 = new_samples(10, 999999)
    assert.equal(s7:gc_step(), 999999)
end

function testcase.samples_gc_step_dump_consistency()
    -- Test that gc_step() method returns same value as dump.gc_step
    local s1 = new_samples(10, 512)
    local dump1 = s1:dump()
    assert.equal(s1:gc_step(), dump1.gc_step)
    assert.equal(s1:gc_step(), 512)

    local s2 = new_samples(10, -1)
    local dump2 = s2:dump()
    assert.equal(s2:gc_step(), dump2.gc_step)
    assert.equal(s2:gc_step(), -1)

    local s3 = new_samples(10, 0)
    local dump3 = s3:dump()
    assert.equal(s3:gc_step(), dump3.gc_step)
    assert.equal(s3:gc_step(), 0)
end

function testcase.samples_gc_step_restore_preservation()
    -- Test that gc_step is preserved through dump/restore cycle
    local original_data = create_samples_data({
        1000,
        2000,
    }, {
        capacity = 5,
        gc_step = 2048, -- Custom gc_step value
        before_kb = {
            100,
            110,
        },
        after_kb = {
            105,
            115,
        },
        allocated_kb = {
            5,
            5,
        },
    })

    local s1 = new_samples(original_data)
    assert.equal(s1:gc_step(), 2048)

    -- Dump and restore
    local dump = s1:dump()
    local s2 = new_samples(dump)
    assert.equal(s2:gc_step(), 2048)

    -- Test with negative gc_step
    local data_negative = create_samples_data({
        1000,
    }, {
        capacity = 2,
        gc_step = -1, -- Disabled GC
    })

    local s3 = new_samples(data_negative)
    assert.equal(s3:gc_step(), -1)

    local dump3 = s3:dump()
    local s4 = new_samples(dump3)
    assert.equal(s4:gc_step(), -1)
end

function testcase.samples_edge_cases()
    -- Test with minimum capacity (1)
    local s1 = new_samples(1)
    assert.equal(s1:capacity(), 1)
    assert.equal(#s1, 0)

    -- Test with very large capacity
    local s2 = new_samples(1000000)
    assert.equal(s2:capacity(), 1000000)
    assert.equal(#s2, 0)

    -- Test gc_step normalization (negative values become -1)
    local s3 = new_samples(10, -100)
    assert.equal(s3:capacity(), 10)
    assert.equal(s3:gc_step(), -1) -- Verify gc_step was normalized

    -- Test very large gc_step
    local s4 = new_samples(10, 999999)
    assert.equal(s4:capacity(), 10)
    assert.equal(s4:gc_step(), 999999) -- Verify gc_step is preserved
end

function testcase.samples_metadata_preservation()
    -- Test metadata preservation through dump/restore cycle
    local original_data = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    }, {
        capacity = 10, -- Different from count to test this scenario
        gc_step = 2048,
        base_kb = 512,
        before_kb = {
            100,
            110,
            120,
            130,
            140,
        },
        after_kb = {
            105,
            115,
            125,
            135,
            145,
        },
        allocated_kb = {
            5,
            5,
            5,
            5,
            5,
        },
    })

    -- Create samples from original data
    local s1 = new_samples(original_data)
    assert.equal(s1:capacity(), 10)
    assert.equal(#s1, 5)

    -- Dump the samples
    local dump = s1:dump()

    -- Verify all metadata fields are present
    assert.equal(dump.capacity, 10)
    assert.equal(dump.count, 5)
    assert.equal(dump.gc_step, 2048)
    assert.equal(dump.base_kb, 512)
    assert.equal(#dump.time_ns, 5)
    assert.equal(#dump.before_kb, 5)
    assert.equal(#dump.after_kb, 5)
    assert.equal(#dump.allocated_kb, 5)

    -- Restore from dump
    local s2 = new_samples(dump)
    assert.equal(s2:capacity(), 10)
    assert.equal(#s2, 5)

    -- Test another dump to ensure multiple round-trips work
    local dump2 = s2:dump()
    assert.equal(dump2.capacity, 10)
    assert.equal(dump2.count, 5)
    assert.equal(dump2.gc_step, 2048)
    assert.equal(dump2.base_kb, 512)
end

function testcase.samples_memory_management()
    -- Test multiple samples objects creation and cleanup
    local samples_list = {}

    for i = 1, 10 do
        samples_list[i] = new_samples(5)
        assert.equal(samples_list[i]:capacity(), 5)
    end

    -- luacheck: ignore samples_list big_samples

    -- Clear references and force GC
    samples_list = nil
    collectgarbage('collect')
    collectgarbage('collect')

    -- Test large data allocation
    local big_samples = new_samples(1000)
    assert.equal(big_samples:capacity(), 1000)

    -- Clear and GC
    big_samples = nil
    collectgarbage('collect')
    collectgarbage('collect')
end

function testcase.samples_restore_capacity_vs_count()
    -- Test restoration where capacity > count
    local data_partial = create_samples_data({
        1000,
        2000,
    }, {
        capacity = 5, -- Capacity larger than count
        before_kb = {
            100,
            110,
        },
        after_kb = {
            105,
            115,
        },
        allocated_kb = {
            5,
            5,
        },
    })

    local s = new_samples(data_partial)
    assert.equal(s:capacity(), 5)
    assert.equal(#s, 2)

    local dump = s:dump()
    assert.equal(dump.capacity, 5)
    assert.equal(dump.count, 2)
    assert.equal(#dump.time_ns, 2)
    assert.equal(#dump.before_kb, 2)
end

