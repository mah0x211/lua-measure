local testcase = require('testcase')
local assert = require('assert')
local sampler = require('measure.sampler')
local new_samples = require('measure.samples').new

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
        cl = 95, -- Default confidence level
        rciw = 5.0, -- Default target relative confidence interval width
    }

    for i, time_ns in ipairs(time_values) do
        data.time_ns[i] = math.floor(time_ns)
        data.before_kb[i] = 0
        data.after_kb[i] = 0
        data.allocated_kb[i] = 0
    end

    -- Override with extra fields if provided
    if extra_fields then
        for k, v in pairs(extra_fields) do
            data[k] = v
        end
    end

    return new_samples(data)
end

-- Constructor tests

function testcase.constructor()
    -- Test default capacity without name
    local s = new_samples()
    assert.match(tostring(s), '^measure.samples: ', false)
    assert.match(s:name(), '^0x', false)
    assert.equal(s:capacity(), 1000)
    assert.equal(#s, 0)

    -- Test custom capacity without name
    s = new_samples(nil, 100)
    assert.equal(s:capacity(), 100)
    assert.equal(#s, 0)

    -- Test large capacity without name
    s = new_samples(nil, 10000)
    assert.equal(s:capacity(), 10000)
    assert.equal(#s, 0)

    -- Test with minimum capacity (1)
    s = new_samples(nil, 1)
    assert.equal(s:capacity(), 1)
    assert.equal(#s, 0)

    -- Test with very large capacity
    s = new_samples(nil, 1000000)
    assert.equal(s:capacity(), 1000000)
    assert.equal(#s, 0)

    -- Test gc_step normalization (negative values become -1)
    s = new_samples(nil, 10, -100)
    assert.equal(s:capacity(), 10)
    assert.equal(s:gc_step(), -1) -- Verify gc_step was normalized

    -- Test very large gc_step
    s = new_samples(nil, 10, 999999)
    assert.equal(s:capacity(), 10)
    assert.equal(s:gc_step(), 999999) -- Verify gc_step is preserved

    -- Test with all valid parameters
    s = new_samples(nil, 100, 1024, 99, 1)
    assert.match(tostring(s), '^measure.samples: ', false)
    assert.equal(s:capacity(), 100)
    assert.equal(s:gc_step(), 1024)
    assert.equal(s:cl(), 99)
    assert.equal(s:rciw(), 1)
end

function testcase.constructor_with_name()
    -- Test with name
    local s = new_samples("test_benchmark")
    assert.equal(tostring(s), "measure.samples: test_benchmark")
    assert.equal(s:name(), "test_benchmark")
    assert.equal(s:capacity(), 1000) -- Default capacity
    assert.equal(#s, 0)

    -- Test with name and capacity
    s = new_samples("my_test", 500)
    assert.equal(tostring(s), "measure.samples: my_test")
    assert.equal(s:name(), "my_test")
    assert.equal(s:capacity(), 500)
    assert.equal(#s, 0)

    -- Test with empty name
    s = new_samples("")
    assert.match(tostring(s), "^measure%.samples: ", false)
    assert.match(s:name(), "^0x", false)
    assert.equal(s:capacity(), 1000)
    assert.equal(#s, 0)

    -- Test with exactly 255 characters (should work)
    local max_name = string.rep("b", 255)
    s = new_samples(max_name)
    assert.equal(tostring(s), "measure.samples: " .. max_name)
    assert.equal(s:name(), max_name)
    assert.equal(s:capacity(), 1000)

    -- Test with name and all valid parameters
    s = new_samples("test", 100, 1024, 99, 1)
    assert.equal(tostring(s), "measure.samples: test")
    assert.equal(s:capacity(), 100)
    assert.equal(s:gc_step(), 1024)
    assert.equal(s:cl(), 99)
    assert.equal(s:rciw(), 1)
end

function testcase.constructor_invalid_name()
    -- Test with name that is too long (>255 characters)
    local long_name = string.rep("a", 256)
    local s, err = new_samples(long_name)
    assert.is_nil(s)
    assert.match(err, "name must be <= 255 characters", false)
end

function testcase.constructor_invalid_capacity()
    -- Test invalid capacity (returns nil + error message)
    local s, err = new_samples(nil, 0)
    assert.is_nil(s)
    assert.match(err, "capacity must be > 0", false)

    s, err = new_samples(nil, -1)
    assert.is_nil(s)
    assert.match(err, "capacity must be > 0", false)

    -- Test with name and invalid capacity
    s, err = new_samples("test", 0)
    assert.is_nil(s)
    assert.match(err, "capacity must be > 0", false)
end

function testcase.constructor_invalid_types()
    -- Test empty table (restoration mode but missing fields - type check will fail)
    assert.throws(function()
        new_samples({})
    end)

    -- Test with boolean
    assert.throws(function()
        new_samples(true)
    end)
end

-- Restore functionality tests

function testcase.restore()
    -- Test restoration with valid data using helper function
    local s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    }, {
        name = "restored_samples",
        capacity = 10,
        gc_step = 2048,
        base_kb = 512,
        cl = 90,
        rciw = 2.5,
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
    assert.equal(tostring(s), "measure.samples: restored_samples")
    assert.equal(s:name(), "restored_samples")
    assert.equal(s:capacity(), 10)
    assert.equal(#s, 5)

    -- Verify data was restored correctly
    local dump = s:dump()
    assert.equal(dump.name, "restored_samples")
    assert.equal(dump.capacity, 10)
    assert.equal(dump.count, 5)
    assert.equal(dump.gc_step, 2048)
    assert.equal(dump.base_kb, 512)
    assert.equal(dump.cl, 90)
    assert.equal(dump.rciw, 2.5)
    assert.equal(#dump.time_ns, 5)
    assert.equal(dump.time_ns[1], 1000)
    assert.equal(dump.time_ns[2], 2000)
    assert.equal(dump.time_ns[3], 3000)

    -- Test restoration where capacity > count
    s = create_samples_data({
        1000,
        2000,
    }, {
        capacity = 5, -- Capacity larger than count
        cl = 88,
        rciw = 6.0,
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

    assert.equal(s:capacity(), 5)
    assert.equal(#s, 2)

    dump = s:dump()
    assert.equal(dump.capacity, 5)
    assert.equal(dump.count, 2)
    assert.equal(#dump.time_ns, 2)
    assert.equal(#dump.before_kb, 2)

    -- Test metadata preservation through dump/restore cycle
    local s1 = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    }, {
        name = "meta_preserve",
        capacity = 10, -- Different from count to test this scenario
        gc_step = 2048,
        base_kb = 512,
        cl = 99,
        rciw = 1.5,
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
    assert.equal(tostring(s1), "measure.samples: meta_preserve")
    assert.equal(s1:capacity(), 10)
    assert.equal(#s1, 5)

    -- Dump the samples
    dump = s1:dump()

    -- Verify all metadata fields are present
    assert.equal(dump.name, "meta_preserve")
    assert.equal(dump.capacity, 10)
    assert.equal(dump.count, 5)
    assert.equal(dump.gc_step, 2048)
    assert.equal(dump.base_kb, 512)
    assert.equal(dump.cl, 99)
    assert.equal(dump.rciw, 1.5)
    assert.equal(#dump.time_ns, 5)
    assert.equal(#dump.before_kb, 5)
    assert.equal(#dump.after_kb, 5)
    assert.equal(#dump.allocated_kb, 5)

    -- Restore from dump
    local s2 = new_samples(dump)
    assert.equal(tostring(s2), "measure.samples: meta_preserve")
    assert.equal(s2:capacity(), 10)
    assert.equal(#s2, 5)

    -- Test another dump to ensure multiple round-trips work
    local dump2 = s2:dump()
    assert.equal(dump2.name, "meta_preserve")
    assert.equal(dump2.capacity, 10)
    assert.equal(dump2.count, 5)
    assert.equal(dump2.gc_step, 2048)
    assert.equal(dump2.base_kb, 512)
    assert.equal(dump2.cl, 99)
    assert.equal(dump2.rciw, 1.5)
end

function testcase.restore_missing_fields()
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
            cl = 95,
            rciw = 5.0,
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
            cl = 95,
            rciw = 5.0,
            -- Missing count
        })
    end)

    -- Test missing required array fields (throws due to type check)
    local base_data = {
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
    }

    local required_fields = {
        'time_ns',
        'before_kb',
        'after_kb',
    }
    local field_values = {
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
    }

    -- Test each required field is missing
    for _, missing_field in ipairs(required_fields) do
        local data = {}
        -- Copy base data
        for k, v in pairs(base_data) do
            data[k] = v
        end
        -- Add all fields except the missing one
        for field, values in pairs(field_values) do
            if field ~= missing_field then
                data[field] = values
            end
        end

        assert.throws(function()
            new_samples(data)
        end)
    end
end

function testcase.restore_invalid_values()
    -- Test with zero capacity
    local bad_data, err = new_samples({
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
    })
    assert.is_nil(bad_data)
    assert.match(err, "invalid field 'capacity': must be > 0", false)

    -- Test count > capacity
    bad_data, err = new_samples({
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
        cl = 95,
        rciw = 5.0,
    })
    assert.is_nil(bad_data)
    assert.match(err, "invalid field 'count': must be >= 0 and <= capacity",
                 false)

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

    -- Test non-numeric values in array fields (returns nil + error)
    -- Test time_ns field with non-numeric value
    bad_data, err = new_samples({
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
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
    })
    assert.is_nil(bad_data)
    assert.match(err, "must be a integer >= 0")
end

function testcase.restore_array_size_mismatch()
    -- Test array size mismatch for all required fields
    local base_data = {
        capacity = 2,
        count = 2,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
        sum = 3000,
        min = 1000,
        max = 2000,
        M2 = 500000,
        mean = 1500,
    }

    local array_fields = {
        'time_ns',
        'before_kb',
        'after_kb',
    }
    local correct_values = {
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
    }

    -- Test each array field with wrong size
    for _, field in ipairs(array_fields) do
        local data = {}
        -- Copy base data
        for k, v in pairs(base_data) do
            data[k] = v
        end
        -- Add all fields with correct size
        for f, values in pairs(correct_values) do
            if f == field then
                data[f] = {
                    values[1],
                } -- Wrong size (1 instead of 2)
            else
                data[f] = values -- Correct size
            end
        end

        local result, err = new_samples(data)
        assert.is_nil(result)
        assert.match(err, "array size does not match", false)
    end
end

-- Dump functionality tests

function testcase.dump()
    local s = new_samples(nil, 10)

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
    assert.is_number(data.cl)
    assert.equal(data.cl, 95)
    assert.is_number(data.rciw)
    assert.equal(data.rciw, 5.0)
    assert.is_number(data.sum)
    assert.equal(data.sum, 0)
    assert.is_number(data.min)
    assert.equal(data.min, 0) -- Should be 0 for empty samples
    assert.is_number(data.max)
    assert.equal(data.max, 0)
    assert.is_number(data.M2)
    assert.equal(data.M2, 0)
    assert.is_number(data.mean)
    assert.equal(data.mean, 0)
    -- name field should not exist for samples without name
    assert.is_nil(data.name)

    -- Test dump with name
    s = new_samples("test_dump", 10)
    data = s:dump()
    assert.is_table(data)
    assert.equal(data.name, "test_dump")
    assert.equal(data.capacity, 10)
    assert.equal(data.count, 0)

    -- Test that dump() includes all statistical fields with correct values
    s = create_samples_data({
        100,
        200,
        300,
        400,
        500,
    }, {
        capacity = 10,
    })

    data = s:dump()

    -- Verify all statistical fields are present in dump
    assert.is_number(data.sum)
    assert.is_number(data.min)
    assert.is_number(data.max)
    assert.is_number(data.mean)
    assert.is_number(data.M2)

    -- Verify other fields are still present
    assert.equal(data.capacity, 10)
    assert.equal(data.count, 5)
    assert.equal(#data.time_ns, 5)

    -- Test that statistical fields are preserved through dump/restore cycle
    local s1 = create_samples_data({
        1000,
        2000,
        3000,
    }, {
        capacity = 5,
    })

    -- Create samples and dump
    local dump1 = s1:dump()

    -- Restore from dump
    local s2 = new_samples(dump1)
    local dump2 = s2:dump()

    -- Verify statistical fields are preserved
    assert.equal(dump2.sum, dump1.sum)
    assert.equal(dump2.min, dump1.min)
    assert.equal(dump2.max, dump1.max)
    assert.equal(dump2.mean, dump1.mean)
    assert.equal(dump2.M2, dump1.M2)

    -- Verify through accessor methods
    assert.is_number(s2:min())
    assert.is_number(s2:max())
    assert.is_number(s2:mean())
end

-- Statistical method tests

function testcase.min()
    -- Test min should return NaN for empty samples
    local s = new_samples()
    assert.is_nan(s:min())

    -- Test with simple integer values
    s = create_samples_data({
        5000,
        1000,
        3000,
        2000,
        4000,
    })
    assert.equal(s:min(), 1000.0) -- minimum value

    -- Test with single value
    local s_single = create_samples_data({
        42000,
    })
    assert.equal(s_single:min(), 42000.0)

    -- Test with unsorted values
    local s_unsorted = create_samples_data({
        3000,
        1000,
        2000,
    })
    assert.equal(s_unsorted:min(), 1000.0)

    -- Test with duplicate values
    local s_duplicates = create_samples_data({
        1000,
        500,
        2000,
        500,
    })
    assert.equal(s_duplicates:min(), 500.0)

    -- Test min calculation edge cases
    -- Test with identical values
    local s_identical = create_samples_data({
        5000,
        5000,
        5000,
    })
    assert.equal(s_identical:min(), 5000.0)

    -- Test with large numbers
    local s_large = create_samples_data({
        1000000000,
        2000000000,
        500000000,
    })
    assert.equal(s_large:min(), 500000000.0)
end

function testcase.max()
    -- Test max should return NaN for empty samples
    local s = new_samples()
    assert.is_nan(s:max())

    -- Test with simple integer values
    s = create_samples_data({
        1000,
        5000,
        3000,
        2000,
        4000,
    })
    assert.equal(s:max(), 5000) -- maximum value

    -- Test with single value
    local s_single = create_samples_data({
        42000,
    })
    assert.equal(s_single:max(), 42000)

    -- Test with unsorted values
    local s_unsorted = create_samples_data({
        3000,
        1000,
        2000,
    })
    assert.equal(s_unsorted:max(), 3000)

    -- Test with duplicate values
    local s_duplicates = create_samples_data({
        2000,
        1000,
        2000,
        500,
    })
    assert.equal(s_duplicates:max(), 2000)

    -- Test with identical values
    local s_identical = create_samples_data({
        5000,
        5000,
        5000,
    })
    assert.equal(s_identical:max(), 5000)

    -- Test with large numbers
    local s_large = create_samples_data({
        500000000,
        1000000000,
        2000000000,
    })
    assert.equal(s_large:max(), 2000000000)
end

function testcase.mean()
    -- Test mean should return NaN for empty samples
    local s = new_samples()
    assert.is_nan(s:mean())

    -- Test with simple integer values
    s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    assert.equal(s:mean(), 3000.0) -- (1000+2000+3000+4000+5000)/5 = 3000

    -- Test with single value
    local s_single = create_samples_data({
        42000,
    })
    assert.equal(s_single:mean(), 42000.0)

    -- Test with two values
    local s_two = create_samples_data({
        1000,
        3000,
    })
    assert.equal(s_two:mean(), 2000.0) -- (1000+3000)/2 = 2000

    -- Test with decimal precision
    local s_decimal = create_samples_data({
        1500,
        2500,
        3500,
    })
    assert.equal(s_decimal:mean(), 2500.0) -- (1500+2500+3500)/3 = 2500

    -- Test with large numbers
    local s_large = create_samples_data({
        1000000000,
        2000000000,
        3000000000,
    })
    assert.equal(s_large:mean(), 2000000000.0)

    -- Test with very small numbers
    local s_small = create_samples_data({
        1,
        2,
        3,
    })
    assert.equal(s_small:mean(), 2.0)

    -- Test that statistical values are correctly calculated after restoration
    -- This tests the core functionality of automatic statistical computation

    -- Test with known values for precise validation
    local test_values = {
        100,
        200,
        300,
        400,
        500,
    }

    s = create_samples_data(test_values, {
        capacity = 10,
    })

    -- Verify basic count
    assert.equal(#s, 5)

    -- Verify min and max are correctly calculated
    assert.equal(s:min(), 100)
    assert.equal(s:max(), 500)

    -- Verify mean is correctly calculated: (100+200+300+400+500)/5 = 300
    assert.equal(s:mean(), 300)

    -- Verify sum is correctly calculated: 100+200+300+400+500 = 1500
    local dump = s:dump()
    assert.equal(dump.sum, 1500)
end

function testcase.variance()
    -- Test variance should return NaN if number of samples is less than 2
    local s = create_samples_data({
        1000,
    })
    assert.is_nan(s:variance())

    -- Test with known variance case
    s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    -- For this dataset: mean = 3000
    -- Variance = ((1000-3000)^2 + (2000-3000)^2 + (3000-3000)^2 + (4000-3000)^2 + (5000-3000)^2) / 4
    -- = (4000000 + 1000000 + 0 + 1000000 + 4000000) / 4 = 10000000 / 4 = 2500000
    assert.equal(s:variance(), 2500000)

    -- Test with identical values (should be 0)
    local s_identical = create_samples_data({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(s_identical:variance(), 0.0)

    -- Test with simple two-value case
    local s_two = create_samples_data({
        1000,
        3000,
    })
    -- mean = 2000, variance = ((1000-2000)^2 + (3000-2000)^2) / 1 = 2000000
    assert.equal(s_two:variance(), 2000000)

    -- Test with three values
    local s_three = create_samples_data({
        2000,
        4000,
        6000,
    })
    -- mean = 4000, variance = ((2000-4000)^2 + (4000-4000)^2 + (6000-4000)^2) / 2
    -- = (4000000 + 0 + 4000000) / 2 = 4000000
    assert.equal(s_three:variance(), 4000000)

    -- Test with four values
    local s_four = create_samples_data({
        1000,
        3000,
        5000,
        7000,
    })
    -- mean = 4000
    -- variance = ((1000-4000)^2 + (3000-4000)^2 + (5000-4000)^2 + (7000-4000)^2) / 3
    -- = (9000000 + 1000000 + 1000000 + 9000000) / 3 = 20000000 / 3 ≈ 6666666.67
    assert.less(math.abs(s_four:variance() - 6666666.67), 0.1)

    -- Test with decimal values
    local s_decimal = create_samples_data({
        100,
        150,
        200,
        250,
        300,
    })
    -- mean = 200, variance = ((100-200)^2 + (150-200)^2 + (200-200)^2 + (250-200)^2 + (300-200)^2) / 4
    -- = (10000 + 2500 + 0 + 2500 + 10000) / 4 = 25000 / 4 = 6250
    assert.equal(s_decimal:variance(), 6250)

    -- Test with large numbers
    local s_large = create_samples_data({
        1000000000,
        2000000000,
        3000000000,
    })
    -- mean = 2000000000
    -- variance = ((1000000000-2000000000)^2 + (2000000000-2000000000)^2 + (3000000000-2000000000)^2) / 2
    -- = (1e18 + 0 + 1e18) / 2 = 1e18
    assert.equal(s_large:variance(), 1e18)

    -- Test with small numbers
    local s_small = create_samples_data({
        1,
        2,
        3,
    })
    -- mean = 2, variance = ((1-2)^2 + (2-2)^2 + (3-2)^2) / 2 = (1 + 0 + 1) / 2 = 1
    assert.equal(s_small:variance(), 1.0)

    -- Test with alternating values
    local s_alternating = create_samples_data({
        1000,
        9000,
        1000,
        9000,
    })
    -- mean = 5000, variance = 2*((1000-5000)^2) + 2*((9000-5000)^2) / 3
    -- = 2*(16000000) + 2*(16000000) / 3 = 64000000 / 3 ≈ 21333333.33
    assert.less(math.abs(s_alternating:variance() - 21333333.33), 0.1)

    -- Test variance is correctly calculated
    -- For values [100,200,300,400,500], mean=300
    -- Variance = ((100-300)^2 + (200-300)^2 + (300-300)^2 + (400-300)^2 + (500-300)^2) / (5-1)
    --         = (40000 + 10000 + 0 + 10000 + 40000) / 4
    --         = 100000 / 4 = 25000
    s = create_samples_data({
        100,
        200,
        300,
        400,
        500,
    })
    assert.equal(s:variance(), 25000)

    -- Test with identical values (variance should be 0)
    local s2 = create_samples_data({
        250,
        250,
        250,
    }, {
        capacity = 5,
    })
    assert.equal(s2:min(), 250)
    assert.equal(s2:max(), 250)
    assert.equal(s2:mean(), 250)
    assert.equal(s2:variance(), 0)

    local dump2 = s2:dump()
    assert.equal(dump2.sum, 750) -- 250 * 3
    assert.equal(dump2.M2, 0) -- No variance for identical values

    -- Test edge cases for statistical calculation after restoration

    -- Test with single value
    local s1 = create_samples_data({
        1234,
    }, {
        capacity = 2,
    })
    assert.equal(s1:min(), 1234)
    assert.equal(s1:max(), 1234)
    assert.equal(s1:mean(), 1234)
    assert.is_nan(s1:variance())

    local dump1 = s1:dump()
    assert.equal(dump1.sum, 1234)
    assert.equal(dump1.M2, 0)

    -- Test with two values
    s2 = create_samples_data({
        1000,
        2000,
    }, {
        capacity = 5,
    })
    assert.equal(s2:min(), 1000)
    assert.equal(s2:max(), 2000)
    assert.equal(s2:mean(), 1500) -- (1000+2000)/2

    dump2 = s2:dump()
    assert.equal(dump2.sum, 3000)

    -- For two values [1000, 2000], mean=1500
    -- Variance = ((1000-1500)^2 + (2000-1500)^2) / (2-1) = (250000 + 250000) / 1 = 500000
    assert.equal(s2:variance(), 500000)

    -- Test with zero values
    local s3 = create_samples_data({
        0,
        0,
        0,
    }, {
        capacity = 5,
    })
    assert.equal(s3:min(), 0)
    assert.equal(s3:max(), 0)
    assert.equal(s3:mean(), 0)
    assert.equal(s3:variance(), 0)

    local dump3 = s3:dump()
    assert.equal(dump3.sum, 0)
    assert.equal(dump3.M2, 0)

    -- Test Welford's method implementation for numerical stability

    -- Test with values that could cause numerical issues with naive method
    -- Use smaller base to avoid integer overflow
    local base = 1e12 -- Large but safe base value
    s = create_samples_data({
        base + 1,
        base + 2,
        base + 3,
        base + 4,
        base + 5,
    }, {
        capacity = 5,
    })
    assert.is_number(s:mean())
    assert.is_number(s:variance())
    assert.is_number(s:min())
    assert.is_number(s:max())

    -- Verify statistical consistency
    assert(s:variance() >= 0)

    -- Test with extremely large values near safe integer limit
    local huge_val = 2 ^ 52 -- Large but safer value
    s = create_samples_data({
        huge_val - 2000,
        huge_val - 1000,
        huge_val,
    }, {
        capacity = 3,
    })
    assert.is_number(s:min())
    assert.is_number(s:max())
    assert.is_number(s:mean())
    assert.is_number(s:variance())

    -- Test with all zero values
    s = create_samples_data({
        0,
        0,
        0,
        0,
        0,
    }, {
        capacity = 5,
    })
    assert.equal(s:min(), 0)
    assert.equal(s:max(), 0)
    assert.equal(s:mean(), 0)
    assert.equal(s:variance(), 0)

    -- Test that statistical values are internally consistent
    local values = {
        100,
        200,
        300,
        400,
        500,
    }

    s = create_samples_data(values, {
        capacity = 5,
    })

    -- Verify consistency: min <= mean <= max
    assert(s:min() <= s:mean(), "min should be <= mean")
    assert(s:mean() <= s:max(), "mean should be <= max")

    -- Verify sum consistency: sum / count = mean
    local dump = s:dump()
    assert.less_or_equal(math.abs(dump.sum / dump.count - dump.mean), 50.1)
end

function testcase.stddev()
    -- Test stddev should return NaN if number of samples is less than 2
    local s = create_samples_data({
        1000,
    })
    assert.is_nan(s:stddev())

    -- Test with known variance case
    s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    -- For this dataset: mean = 3000, variance = 2500000, stddev = sqrt(2500000) ≈ 1581.14
    assert.less(math.abs(s:stddev() - 1581.14), 0.1)

    -- Test with identical values (should be 0)
    local s_identical = create_samples_data({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(s_identical:stddev(), 0.0)

    -- Test with single value (should be NaN)
    local s_single = create_samples_data({
        42000,
    })
    assert.is_nan(s_single:stddev())

    -- Test with simple two-value case
    local s_two = create_samples_data({
        1000,
        3000,
    })
    -- variance = ((1000-2000)^2 + (3000-2000)^2) / 1 = 2000000, stddev = sqrt(2000000) ≈ 1414.21
    assert.less(math.abs(s_two:stddev() - 1414.21), 0.1)

    -- Test with three values
    local s_three = create_samples_data({
        2000,
        4000,
        6000,
    })
    -- mean = 4000, variance = ((2000-4000)^2 + (4000-4000)^2 + (6000-4000)^2) / 2 = 4000000, stddev = 2000
    assert.less(math.abs(s_three:stddev() - 2000.0), 0.1)

    -- Test with large numbers
    local s_large = create_samples_data({
        1000000000,
        2000000000,
        3000000000,
    })
    assert.greater(s_large:stddev(), 0)
    assert.is_number(s_large:stddev())

    -- Test with small numbers
    local s_small = create_samples_data({
        1,
        2,
        3,
    })
    assert.equal(s_small:stddev(), 1.0)

    -- Test with very large variation
    local large_var_samples = create_samples_data({
        1,
        1000000000,
        1,
        1000000000,
        1,
    })
    assert.is_number(large_var_samples:stddev())
    assert.greater(large_var_samples:stddev(), 0)

    -- Test with patterns that might stress the variance calculation
    local pattern_samples = create_samples_data({
        100,
        200,
        300,
        400,
        500,
        600,
        700,
        800,
        900,
        1000,
    })
    assert.is_number(pattern_samples:stddev())
    assert.greater(pattern_samples:stddev(), 0)

    -- Verify stddev is correctly calculated: sqrt(25000) = 158.11...
    s = create_samples_data({
        100,
        200,
        300,
        400,
        500,
    })
    local expected_stddev = math.sqrt(25000)
    assert.less_or_equal(math.abs(s:stddev() - expected_stddev), 0.001)
end

function testcase.percentile()
    -- Test p50 (median) with odd number of values
    local s_odd = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    local p50 = s_odd:percentile(50)
    assert.equal(p50, 3000) -- Middle value

    -- Test with even number of values
    local s_even = create_samples_data({
        1000,
        2000,
        3000,
        4000,
    })
    local p50_even = s_even:percentile(50)
    assert.equal(p50_even, 2500) -- (2000+3000)/2 = 2500

    -- Test with single value
    local s_single = create_samples_data({
        12345,
    })
    assert.equal(s_single:percentile(50), 12345.0)

    -- Test with unsorted data (should still work correctly)
    local s_unsorted = create_samples_data({
        5000,
        1000,
        3000,
        2000,
        4000,
    })
    assert.equal(s_unsorted:percentile(50), 3000)

    -- Test various percentiles
    local s = create_samples_data({
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
    -- Test 0th percentile (minimum)
    assert.equal(s:percentile(0), 1000.0)

    -- Test 25th percentile
    local p25 = s:percentile(25)
    assert.greater_or_equal(p25, 2000)
    assert.less_or_equal(p25, 4000)

    -- Test 75th percentile
    local p75 = s:percentile(75)
    assert.greater_or_equal(p75, 7000)
    assert.less_or_equal(p75, 9000)

    -- Test 100th percentile (maximum)
    assert.equal(s:percentile(100), 10000)

    -- Test edge cases
    -- Test with identical values
    local s_identical = create_samples_data({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(s_identical:percentile(25), 5000)
    assert.equal(s_identical:percentile(50), 5000)
    assert.equal(s_identical:percentile(75), 5000)

    -- Test with two values
    local s_two = create_samples_data({
        1000,
        3000,
    })
    assert.equal(s_two:percentile(0), 1000)
    assert.equal(s_two:percentile(50), 2000)
    assert.equal(s_two:percentile(100), 3000)

    -- Test with empty samples should return NaN
    local empty_samples = create_samples_data({}, {
        capacity = 10,
    })
    local not_a_number = empty_samples:percentile(50)
    assert.is_nan(not_a_number)
end

function testcase.percentile_invalid()
    -- Test error handling
    local s = create_samples_data({
        1000,
        2000,
        3000,
    })

    -- Test with nil samples should throw error
    local err = assert.throws(function()
        s:percentile(nil)
    end)
    assert.re_match(err, 'percentile.+number expected, got nil')

    -- Test with invalid percentile values
    err = assert.throws(function()
        s:percentile(-1) -- Negative percentile
    end)
    assert.re_match(err, 'percentile.+must be between 0 and 100')

    err = assert.throws(function()
        s:percentile(101) -- > 100
    end)
    assert.re_match(err, 'percentile.+must be between 0 and 100')
end

function testcase.stderr()
    -- Test stderr should return NaN if number of samples is less than 2
    local s = create_samples_data({
        1000,
    })
    assert.is_nan(s:stderr())

    -- test standard error calculation
    s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    assert.is_number(s:stderr())
    assert.greater(s:stderr(), 0) -- stderr should be positive

    -- test with single sample (stderr should be NaN)
    s = create_samples_data({
        1000,
    })
    assert.is_number(s:stderr())
    assert.is_nan(s:stderr()) -- no error with single sample

    -- test with identical values (stderr should be 0)
    s = create_samples_data({
        1000,
        1000,
        1000,
        1000,
    })
    assert.is_number(s:stderr())
    assert.equal(s:stderr(), 0.0) -- no variation
end

function testcase.cv()
    -- Test coefficient of variation should return NaN if number of samples is less than 2
    local s = create_samples_data({
        1000,
    })
    assert.is_nan(s:cv())

    -- test coefficient of variation calculation
    s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    assert.is_number(s:cv())
    assert.greater(s:cv(), 0) -- CV should be positive

    -- test with identical values (CV should be 0)
    s = create_samples_data({
        1000,
        1000,
        1000,
        1000,
    })
    assert.is_number(s:cv())
    assert.equal(s:cv(), 0.0) -- no variation

    -- test with zero mean (should return NaN)
    s = create_samples_data({
        0,
        0,
        0,
    })
    -- check for NaN
    assert.is_nan(s:cv())
end

function testcase.throughput()
    -- Test throughput returns NaN for empty samples
    local s = new_samples()
    assert.is_nan(s:throughput())

    -- test throughput calculation with 1 second mean time
    s = create_samples_data({
        1000000000,
        1000000000,
        1000000000,
    }) -- 1 second each
    assert.is_number(s:throughput())
    assert.equal(s:throughput(), 1.0) -- 1 operation per second

    -- test throughput with 0.5 second mean time
    s = create_samples_data({
        500000000,
        500000000,
        500000000,
    }) -- 0.5 second each
    assert.is_number(s:throughput())
    assert.equal(s:throughput(), 2.0) -- 2 operations per second

    -- test with zero time values (should return NaN)
    s = create_samples_data({
        0,
        0,
        0,
    })
    -- check for NaN
    assert.is_nan(s:throughput())

    -- test throughput calculation (ops/sec) with varying times
    s = create_samples_data({
        1000000,
        2000000,
        3000000,
    }) -- 1ms, 2ms, 3ms average
    -- mean = 2ms = 2e6 ns = 0.002s, throughput = 1/0.002 = 500 ops/sec
    assert.is_number(s:throughput())
    assert.greater(s:throughput(), 450)
    assert.less(s:throughput(), 550)
end

function testcase.mad()
    -- test MAD should return NaN if number of samples is less than 3
    local s = create_samples_data({
        1000,
        2000,
    })
    assert.is_nan(s:mad())

    -- test MAD calculation with 5 values
    s = create_samples_data({
        1000,
        2000,
        3000,
        4000,
        5000,
    })
    -- Median is 3000, absolute deviations are [2000, 1000, 0, 1000, 2000]
    -- MAD = median of [0, 1000, 1000, 2000, 2000] = 1000
    assert.is_number(s:mad())
    assert.equal(s:mad(), 1000.0)

    -- test with identical values
    local s_identical = create_samples_data({
        5000,
        5000,
        5000,
        5000,
    })
    assert.equal(s_identical:mad(), 0.0)
end

function testcase.memstat()
    local s = create_samples_data({
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
    })
    -- Verify result structure
    local stat = s:memstat()
    assert.is_table(stat)
    assert.is_number(stat.allocation_rate)
    assert.is_number(stat.gc_impact)
    assert.is_number(stat.memory_efficiency)
    assert.is_number(stat.peak_memory)

    -- Allocation rate should be average of allocated_kb
    assert.equal(stat.allocation_rate, 40.0) -- (20+30+40+50+60)/5 = 40

    -- Peak memory should be maximum after_kb
    assert.equal(stat.peak_memory, 360)

    -- Memory efficiency should be inverse of allocation rate
    assert.less(math.abs(stat.memory_efficiency - 1.0 / 40.0), 0.001)

    -- Test allocation rate calculation
    s = create_samples_data({
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
    })
    stat = s:memstat()
    -- Average allocation should be (50+50+50)/3 = 50
    assert.equal(stat.allocation_rate, 50.0)

    -- Memory efficiency should be 1 / allocation_rate
    assert.equal(stat.memory_efficiency, 0.02)

    -- Test peak memory detection
    s = create_samples_data({
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
    })
    stat = s:memstat()
    -- Peak memory should be 250
    assert.equal(stat.peak_memory, 250)

    -- Test GC impact correlation
    -- Create scenario where high allocation correlates with high execution time
    s = create_samples_data({
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
    })
    stat = s:memstat()
    -- GC impact should show positive correlation (allocation increases with time)
    assert.greater(stat.gc_impact, 0)

    -- Test with zero allocation
    s = create_samples_data({
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
    })
    stat = s:memstat()
    -- Allocation rate should be 0
    assert.equal(stat.allocation_rate, 0.0)

    -- Memory efficiency should be 0 (since allocation_rate is 0)
    assert.equal(stat.memory_efficiency, 0.0)

    -- Peak memory should be 100
    assert.equal(stat.peak_memory, 100)

    -- Test with identical memory patterns
    s = create_samples_data({
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
    })
    stat = s:memstat()
    -- GC impact should be 0 (no correlation)
    assert.equal(stat.gc_impact, 0.0)

    -- Allocation rate should be 50
    assert.equal(stat.allocation_rate, 50.0)
end

function testcase.capacity_increase()
    -- Test capacity increase functionality
    local s = new_samples("test", 10)
    assert.equal(s:capacity(), 10)

    -- Test that add samples works within initial capacity
    local ok, err = sampler(function()
    end, s)
    assert.is_nil(err)
    assert.is_true(ok)
    assert.equal(#s, 10)

    -- Test increasing capacity
    local new_cap = s:capacity(5) -- Increase by 5
    assert.equal(new_cap, 15)
    assert.equal(s:capacity(), 15)

    -- Test that existing functionality still works
    assert.equal(s:name(), "test")
    assert.equal(#s, 10)

    -- Test with larger increase
    new_cap = s:capacity(100) -- Increase by 100
    assert.equal(new_cap, 115)
    assert.equal(s:capacity(), 115)

    -- Test invalid increase values
    ok, err = pcall(function()
        s:capacity(0)
    end)
    assert.is_false(ok)
    assert.match(err, "positive integer expected")

    ok, err = pcall(function()
        s:capacity(-5)
    end)
    assert.is_false(ok)
    assert.match(err, "positive integer expected")

    -- Test with samples already added
    s = create_samples_data({
        1000,
        2000,
        3000,
    }, {
        capacity = 5,
        count = 3,
    })
    assert.equal(s:capacity(), 5)
    assert.equal(#s, 3)

    -- Increase capacity and verify existing data is preserved
    new_cap = s:capacity(10)
    assert.equal(new_cap, 15)
    assert.equal(s:capacity(), 15)
    assert.equal(#s, 3) -- Count should remain the same

    -- Verify statistics are preserved
    assert.equal(s:min(), 1000)
    assert.equal(s:max(), 3000)
    assert.equal(s:mean(), 2000)

    -- Test that we can add more samples after increasing capacity
    ok = sampler(function()
    end, s)
    assert.is_true(ok)
    assert.equal(#s, 15) -- Should be at new capacity
end
