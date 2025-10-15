require('luacov')
local testcase = require('testcase')
local assert = require('assert')

local new_options = require('measure.options')

-- Helper function to assert valid options creation
local function assert_valid_options(opts_table, expected_values)
    local opts, err = new_options(opts_table)
    assert.is_nil(err)
    assert.not_nil(opts)

    -- Check expected values if provided
    if expected_values then
        for key, value in pairs(expected_values) do
            assert.equal(opts[key], value)
        end
    end

    return opts
end

-- Helper function to assert invalid options creation
local function assert_invalid_options(opts_table, expected_error)
    local opts, err = new_options(opts_table)
    assert.is_nil(opts)
    assert.equal(err, expected_error)
end

function testcase.valid_options_with_all_fields()
    -- Test with all valid options
    local context = {
        foo = 'bar',
    }
    assert_valid_options({
        context = context,
        warmup = 3,
        gc_step = 0,
        confidence_level = 95,
        rciw = 5,
    }, {
        context = context,
        warmup = 3,
        gc_step = 0,
        confidence_level = 95,
        rciw = 5,
    })
end

function testcase.valid_options_with_function_context()
    -- Test with function context
    local context_fn = function()
        return {
            test = true,
        }
    end
    local opts = assert_valid_options({
        context = context_fn,
    })
    assert.equal(opts.context, context_fn)
    assert.equal(opts.confidence_level, 95) -- Default
    assert.equal(opts.rciw, 5) -- Default
end

function testcase.valid_options_empty_table()
    -- Test with empty options table (defaults applied)
    local opts = assert_valid_options({})
    -- Check default values
    assert.is_nil(opts.context)
    assert.equal(opts.warmup, 1) -- Default value
    assert.equal(opts.gc_step, 0) -- Default value
    assert.equal(opts.confidence_level, 95) -- Default value
    assert.equal(opts.rciw, 5) -- Default value
end

function testcase.valid_options_with_partial_values()
    -- Test with some values provided, others get defaults
    local opts = assert_valid_options({
        warmup = 2,
        confidence_level = 99,
    })
    assert.equal(opts.warmup, 2)
    assert.equal(opts.confidence_level, 99)
    assert.is_nil(opts.context)
    assert.equal(opts.gc_step, 0) -- Default value
    assert.equal(opts.rciw, 5) -- Default value
end

function testcase.valid_options_boundary_values()
    -- Test boundary values that should be accepted
    assert_valid_options({
        warmup = 0,
    })
    assert_valid_options({
        warmup = 5,
    })
    assert_valid_options({
        warmup = 2.5,
    }) -- Decimal values should be valid

    assert_valid_options({
        confidence_level = 0.1,
    }) -- Just above 0
    assert_valid_options({
        confidence_level = 100,
    })

    assert_valid_options({
        rciw = 0.1,
    }) -- Just above 0
    assert_valid_options({
        rciw = 100,
    })

    assert_valid_options({
        gc_step = -1,
    }) -- Disabled GC
    assert_valid_options({
        gc_step = 0,
    }) -- Full GC
    assert_valid_options({
        gc_step = 1024,
    }) -- Step GC
end

function testcase.invalid_argument_not_table()
    -- Test with non-table arguments
    local invalid_args = {
        "invalid",
        123,
        true,
        false,
        function()
        end,
    }

    for _, arg in ipairs(invalid_args) do
        assert_invalid_options(arg, 'argument must be a table')
    end

    -- nil is special case
    local opts, err = new_options(nil)
    assert.is_nil(opts)
    assert.equal(err, 'argument must be a table')
end

function testcase.invalid_context_types()
    -- Test with invalid context types
    local invalid_contexts = {
        "string",
        123,
        true,
        false,
    }

    for _, ctx in ipairs(invalid_contexts) do
        assert_invalid_options({
            context = ctx,
        }, 'options.context must be a table or a function')
    end
end

function testcase.invalid_warmup_values()
    -- Test warmup validation
    assert_invalid_options({
        warmup = -0.1,
    }, 'options.warmup must be a number between 0 and 5')
    assert_invalid_options({
        warmup = 5.1,
    }, 'options.warmup must be a number between 0 and 5')
    assert_invalid_options({
        warmup = "invalid",
    }, 'options.warmup must be a number between 0 and 5')
    assert_invalid_options({
        warmup = {},
    }, 'options.warmup must be a number between 0 and 5')
end

function testcase.invalid_gc_step_values()
    -- Test gc_step validation (must be integer)
    local invalid_gc_steps = {
        1.5, -- Not an integer
        -0.5, -- Not an integer
        math.huge, -- Infinity
        -math.huge, -- Negative infinity
        0 / 0, -- NaN
        "invalid", -- Not a number
        {}, -- Not a number
    }

    for _, gc in ipairs(invalid_gc_steps) do
        assert_invalid_options({
            gc_step = gc,
        }, 'options.gc_step must be an integer')
    end
end

function testcase.invalid_confidence_level_values()
    -- Test confidence_level validation
    local invalid_levels = {
        0, -- Must be > 0
        -1, -- Negative
        101, -- Over 100
        150, -- Way over 100
        "95", -- Not a number
        {}, -- Not a number
    }

    for _, level in ipairs(invalid_levels) do
        assert_invalid_options({
            confidence_level = level,
        }, 'options.confidence_level must be a number between 0 and 100')
    end
end

function testcase.invalid_rciw_values()
    -- Test rciw validation
    local invalid_rciws = {
        0, -- Must be > 0
        -1, -- Negative
        101, -- Over 100
        150, -- Way over 100
        "5", -- Not a number
        {}, -- Not a number
    }

    for _, rciw in ipairs(invalid_rciws) do
        assert_invalid_options({
            rciw = rciw,
        }, 'options.rciw must be a number between 0 and 100')
    end
end

function testcase.options_object_prevents_new_fields()
    -- Test that options object prevents adding new fields
    local opts = assert_valid_options({
        warmup = 3,
    })

    -- Attempt to add new field
    local err = assert.throws(function()
        opts.new_field = 'value'
    end)
    assert.match(err, 'Attempt to modify measure.options: "new_field"')
end

function testcase.unknown_fields_discarded()
    -- Test that unknown fields are discarded (only defined fields preserved)
    local opts = assert_valid_options({
        warmup = 3,
        unknown_field = 'test',
        another_unknown = 123,
    })

    -- Check that only defined fields are preserved
    assert.equal(opts.warmup, 3)
    assert.is_nil(opts.unknown_field) -- Unknown fields are discarded
    assert.is_nil(opts.another_unknown) -- Unknown fields are discarded
    assert.equal(opts.confidence_level, 95) -- Default value
    assert.equal(opts.rciw, 5) -- Default value

    -- Count all non-nil fields
    local field_count = 0
    for _ in pairs(opts) do
        field_count = field_count + 1
    end
    assert.equal(field_count, 4) -- warmup + gc_step + confidence_level + rciw
end

function testcase.mixed_valid_and_invalid_options()
    -- Test that validation fails even if some options are valid
    assert_invalid_options({
        warmup = 3, -- Valid
        gc_step = 0, -- Valid
        rciw = -1, -- Invalid
    }, 'options.rciw must be a number between 0 and 100')
end

function testcase.all_defined_fields_accessible()
    -- Test that all defined fields are accessible, with defaults applied
    local opts = assert_valid_options({
        warmup = 2,
        confidence_level = 99,
    })

    -- Check all fields are accessible
    assert.equal(opts.warmup, 2)
    assert.is_nil(opts.context) -- Accessible but nil
    assert.equal(opts.gc_step, 0) -- Default value
    assert.equal(opts.confidence_level, 99) -- Provided value
    assert.equal(opts.rciw, 5) -- Default value

    -- Count non-nil fields (pairs() doesn't iterate over nil values)
    local field_count = 0
    local expected_fields = {
        context = true,
        warmup = true,
        gc_step = true,
        confidence_level = true,
        rciw = true,
    }

    for k, _ in pairs(opts) do
        field_count = field_count + 1
        assert(expected_fields[k], 'Unexpected field: ' .. k)
    end

    assert.equal(field_count, 4) -- warmup, gc_step, confidence_level, rciw are non-nil
end
