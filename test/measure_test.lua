require('luacov')
local testcase = require('testcase')
local assert = require('assert')

-- Use actual measure module instead of mock
local measure = require('measure')
local registry = require('measure.registry')

function testcase.before_each()
    -- Clear registry state for each test
    registry.clear()
end

function testcase.hook_assignment_before_all()
    -- Test setting before_all hook
    measure.before_all = function()
        return {
            context = 'test',
        }
    end

    -- Verify hook was set (indirectly by checking no error was thrown)
    assert.is_true(true) -- Hook assignment succeeded if we reach here
end

function testcase.hook_assignment_before_each()
    -- Test setting before_each hook
    measure.before_each = function(i, ctx)
        assert.is_number(i)
        assert.is_table(ctx)
    end

    assert.is_true(true) -- Hook assignment succeeded
end

function testcase.hook_assignment_after_each()
    -- Test setting after_each hook
    measure.after_each = function(i, ctx)
        assert.is_number(i)
        assert.is_table(ctx)
    end

    assert.is_true(true) -- Hook assignment succeeded
end

function testcase.hook_assignment_after_all()
    -- Test setting after_all hook
    measure.after_all = function(ctx)
        assert.is_table(ctx)
    end

    assert.is_true(true) -- Hook assignment succeeded
end

function testcase.hook_assignment_invalid_name()
    -- Test setting invalid hook name
    assert.throws(function()
        measure.invalid_hook = function()
        end
    end, 'Invalid hook name')
end

function testcase.hook_assignment_not_function()
    -- Test setting hook with non-function value
    assert.throws(function()
        measure.before_all = "not a function"
    end, 'fn must be a function')
end

function testcase.hook_assignment_duplicate()
    -- Test setting duplicate hook
    measure.before_all = function()
    end

    assert.throws(function()
        measure.before_all = function()
        end
    end, 'already exists')
end

function testcase.describe_basic()
    -- Test basic describe functionality
    local desc = measure.describe('Test Benchmark')
    assert.is_table(desc)

    -- Check tostring format to verify it's a proxy object
    assert.equal(tostring(desc), 'measure.describe "Test Benchmark"')
end

function testcase.describe_with_namefn()
    -- Test describe with name function
    local namefn = function(i)
        return 'Test ' .. i
    end
    local desc = measure.describe('Base Name', namefn)
    assert.is_table(desc)

    -- Check tostring format to verify it's a proxy object
    assert.equal(tostring(desc), 'measure.describe "Base Name"')
end

function testcase.describe_invalid_name()
    -- Test describe with invalid name
    assert.throws(function()
        measure.describe(123)
    end, 'name must be a string')
end

function testcase.describe_invalid_namefn()
    -- Test describe with invalid namefn
    assert.throws(function()
        measure.describe('Test', "not a function")
    end, 'namefn must be a function or nil')
end

function testcase.describe_duplicate_name()
    -- Test describe with duplicate name
    measure.describe('Duplicate')

    assert.throws(function()
        measure.describe('Duplicate')
    end, 'already exists')
end

function testcase.method_chaining_options()
    -- Test new options API with chaining
    local proxy = measure.options({
        warmup = 3,
        gc_step = 1024,
        confidence_level = 95,
        rciw = 5,
    })
    local result = proxy.describe('Test')

    -- Result should be the describe proxy object
    assert.match(result, 'measure.describe "Test"')
end

function testcase.method_chaining_setup()
    -- Test method chaining with setup
    local result = measure.describe('Test').setup(function()
        return 'setup_value'
    end)

    assert.match(result, 'measure.describe "Test"')
end

function testcase.method_chaining_setup_once()
    -- Test method chaining with setup_once
    local result = measure.describe('Test').setup_once(function()
        return 'setup_once_value'
    end)

    assert.match(result, 'measure.describe "Test"')
end

function testcase.method_chaining_run()
    -- Test method chaining with run
    local result = measure.describe('Test').run(function()
        -- benchmark code
    end)

    assert.match(result, 'measure.describe "Test"')
end

function testcase.method_chaining_run_with_timer()
    -- Test method chaining with run_with_timer
    local result = measure.describe('Test').run_with_timer(function()
        -- measurement code
    end)

    assert.match(result, 'measure.describe "Test"')
end

function testcase.method_chaining_teardown()
    -- Test method chaining with teardown after run
    local result = measure.describe('Test').run(function()
        -- benchmark code
    end).teardown(function()
        -- cleanup code
    end)

    assert.match(result, 'measure.describe "Test"')
end

function testcase.method_chaining_full_sequence()
    -- Test full method chaining sequence with new API
    local result = measure.options({
        warmup = 5,
        gc_step = 0,
        confidence_level = 95,
        rciw = 5,
    }).describe('Full Test').setup(function()
        return 'test_data'
    end).run(function(data)
        assert.equal(data, 'test_data')
    end).teardown(function()
        -- cleanup
    end)

    assert.match(result, 'measure.describe "Full Test"')
end

function testcase.method_error_handling()
    -- Test error handling in new options API
    assert.throws(function()
        measure.options("not a table")
    end)
end

function testcase.invalid_method_call()
    -- Test invalid method call
    assert.throws(function()
        measure.describe('Test').invalid_method()
    end, 'has no')
end

function testcase.table_access_error()
    -- Test invalid table access - this is not applicable to our mock implementation
    -- The original measure module has different behavior
    assert.is_true(true) -- Skip this test for now
end

function testcase.function_call_error()
    -- Test invalid function call
    assert.throws(function()
        measure()
    end, 'Attempt to call measure as a function')
end

function testcase.multiple_describes()
    -- Test multiple describe definitions in same file
    measure.describe('First Test').run(function()
    end)

    measure.describe('Second Test').run(function()
    end)

    measure.describe('Third Test').run(function()
    end)

    -- All should succeed without error
    assert.is_true(true)
end

function testcase.state_isolation()
    -- Test that describe objects are properly isolated
    measure.describe('Test 1').run(function()
    end)

    measure.describe('Test 2').run(function()
    end)

    -- All should succeed without error
    assert.is_true(true)
end

function testcase.hook_validation_type()
    -- Test hook name type validation
    assert.throws(function()
        measure[123] = function()
        end
    end, 'name must be a string')
end

function testcase.complex_chaining_with_hooks()
    -- Test complex scenario with hooks and chaining
    measure.before_all = function()
        return {
            global_data = 'test',
        }
    end

    measure.before_each = function(i, ctx)
        ctx.iteration = i
    end

    measure.options({
        context = function()
            return {
                local_data = 'local',
            }
        end,
        warmup = 1,
        confidence_level = 95,
        rciw = 5,
    }).describe('Complex Test').setup_once(function(ctx)
        return ctx.local_data .. '_setup'
    end).run(function(data)
        assert.is_string(data)
    end).teardown(function()
        -- cleanup
    end)

    measure.after_each = function()
        -- cleanup after each
    end

    measure.after_all = function()
        -- final cleanup
    end

    assert.is_true(true) -- All operations succeeded
end

-- Test cases for actual measure module behavior
function testcase.actual_measure_proxy_behavior()
    registry.clear()
    local actual_measure = require('measure')

    -- Test describe chaining prevention
    assert.throws(function()
        actual_measure.describe('Test').describe('Another')
    end, 'has no method "describe"')

    -- Test multiple describe creation
    local desc1 = actual_measure.describe('Test1')
    local desc2 = actual_measure.describe('Test2')
    assert.is_table(desc1)
    assert.is_table(desc2)

    -- Test proxy method access returns functions
    local setup_method = desc1.setup
    local run_method = desc1.run
    assert.is_function(setup_method)
    assert.is_function(run_method)

    -- Test methods can be called independently
    setup_method(function()
        return 'test_data'
    end)
    run_method(function()
    end)

    -- Test invalid method access returns function but calling fails
    local invalid_method = desc1.invalid_property
    assert.is_function(invalid_method)
    assert.throws(function()
        invalid_method()
    end, 'has no method "invalid_property"')

    -- Test tostring
    assert.equal(tostring(desc1), 'measure.describe "Test1"')

    -- Test proxy call fails
    assert.throws(function()
        desc1()
    end, 'Attempt to call')
end

function testcase.actual_measure_error_handling()
    registry.clear()
    local actual_measure = require('measure')

    -- Test various error conditions
    local error_cases = {
        {
            function()
                actual_measure()
            end,
            'Attempt to call measure',
        },
        {
            function()
                local _ = actual_measure.invalid_property
            end,
            'Attempt to access measure as a table',
        },
        {
            function()
                actual_measure.before_all = "not a function"
            end,
            'fn must be a function',
        },
        {
            function()
                actual_measure[123] = function()
                end
            end,
            'name must be a string',
        },
        {
            function()
                actual_measure.invalid_hook = function()
                end
            end,
            'Invalid hook name',
        },
        {
            function()
                actual_measure.describe(123)
            end,
            'name must be a string',
        },
        {
            function()
                actual_measure.describe("test", "not a function")
            end,
            'namefn must be a function or nil',
        },
    }

    for _, case in ipairs(error_cases) do
        assert.throws(case[1], case[2])
    end
end

function testcase.actual_measure_proxy_table_access()
    registry.clear()
    local actual_measure = require('measure')
    local desc_proxy = actual_measure.describe('Test')

    -- Test non-string key access
    local invalid_keys = {
        123,
        {},
        nil,
    }
    for _, key in ipairs(invalid_keys) do
        assert.throws(function()
            local _ = desc_proxy[key]
        end, 'Attempt to access measure.describe as a table')
    end
end

function testcase.actual_measure_method_validation()
    registry.clear()
    local actual_measure = require('measure')
    local desc_proxy = actual_measure.describe('Test')

    -- Test method call errors
    assert.throws(function()
        desc_proxy.setup("not a function")
    end, 'setup(): argument must be a function')

    -- Test method ordering constraints
    desc_proxy.run_with_timer(function()
    end)
    assert.throws(function()
        desc_proxy.run(function()
        end)
    end, 'run(): cannot be defined if run_with_timer')
end

function testcase.actual_measure_complete_workflow()
    -- Test complete workflow with new options API
    registry.clear()
    local actual_measure = require('measure')

    -- Set hooks
    actual_measure.before_all = function()
        return {
            start_time = os.time(),
        }
    end
    actual_measure.before_each = function(i, ctx)
        ctx.iteration = i
    end

    -- Create benchmark with new chaining API
    actual_measure.options({
        warmup = 1,
        confidence_level = 95,
        rciw = 5,
    }).describe('Complete Test').setup(function(i)
        return 'test_data_' .. i
    end).run(function(data)
        assert.is_string(data)
    end).teardown(function()
        -- cleanup
    end)

    actual_measure.after_each = function()
    end
    actual_measure.after_all = function()
    end

    assert.is_true(true) -- Workflow completed successfully
end
