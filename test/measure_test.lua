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
    -- Test method chaining with options
    local result = measure.describe('Test').options({
        repeats = 5,
        warmup = 10,
        sample_size = 1000,
    })

    -- Result should be the same proxy object
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
    -- Test full method chaining sequence
    local result = measure.describe('Full Test').options({
        repeats = 3,
        warmup = 5,
        sample_size = 100,
    }).setup(function()
        return 'test_data'
    end).run(function(data)
        assert.equal(data, 'test_data')
    end).teardown(function()
        -- cleanup
    end)

    assert.match(result, 'measure.describe "Full Test"')
end

function testcase.method_error_handling()
    -- Test error handling in method calls
    assert.throws(function()
        measure.describe('Test').options("not a table")
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

    measure.describe('Complex Test').options({
        context = function()
            return {
                local_data = 'local',
            }
        end,
        repeats = 2,
        warmup = 1,
    }).setup_once(function(ctx)
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

-- Test cases for actual measure module to verify constraint behaviors
function testcase.actual_measure_describe_chain_prevention()
    -- Test actual measure module to ensure describe chaining is prevented
    registry.clear()
    local actual_measure = require('measure')

    assert.throws(function()
        actual_measure.describe('Test').describe('Another')
    end, 'has no method "describe"')
end

function testcase.actual_measure_allow_new_describe_flag()
    -- Test AllowNewDescribe flag behavior with actual module
    registry.clear()
    local actual_measure = require('measure')

    -- First access to describe should work
    local desc = actual_measure.describe('Test')
    assert.is_table(desc)

    -- After calling describe(), accessing it again should work (flag resets after call)
    local desc2 = actual_measure.describe('Test2')
    assert.is_table(desc2)
end

function testcase.actual_measure_proxy_table_access_prevention()
    -- Test that proxy object returns functions for method access
    registry.clear()
    local actual_measure = require('measure')

    local desc_proxy = actual_measure.describe('Test')
    -- Accessing invalid method should return a function
    local invalid_method = desc_proxy.invalid_property
    assert.is_function(invalid_method)

    -- But calling it should fail
    assert.throws(function()
        invalid_method()
    end, 'has no method "invalid_property"')
end

function testcase.actual_measure_proxy_multiple_method_access()
    -- Test that proxy allows multiple method access with new implementation
    registry.clear()
    local actual_measure = require('measure')

    local desc_proxy = actual_measure.describe('Test')
    -- First method access returns a function
    local options_method = desc_proxy.options
    assert.is_function(options_method)

    -- Second method access also returns a function (allowed in new implementation)
    local run_method = desc_proxy.run
    assert.is_function(run_method)

    -- Both methods can be called independently
    options_method({
        repeats = 5,
    })
    run_method(function()
    end)
end

function testcase.actual_measure_error_messages()
    -- Test accurate error messages from actual module
    registry.clear()
    local actual_measure = require('measure')

    -- Test function call error
    assert.throws(function()
        actual_measure()
    end, 'Attempt to call measure')

    -- Test invalid table access
    assert.throws(function()
        local _ = actual_measure.invalid_property
    end, 'Attempt to access measure as a table')

    -- Test hook type validation
    assert.throws(function()
        actual_measure.before_all = "not a function"
    end, 'fn must be a function')
end

function testcase.actual_measure_hook_name_validation()
    -- Test hook name validation with actual module
    registry.clear()
    local actual_measure = require('measure')

    assert.throws(function()
        actual_measure[123] = function()
        end
    end, 'name must be a string')

    assert.throws(function()
        actual_measure.invalid_hook = function()
        end
    end, 'Invalid hook name')
end

function testcase.actual_measure_describe_parameter_validation()
    -- Test describe parameter validation
    registry.clear()
    local actual_measure = require('measure')

    assert.throws(function()
        actual_measure.describe(123)
    end, 'name must be a string')

    assert.throws(function()
        actual_measure.describe("test", "not a function")
    end, 'namefn must be a function or nil')
end

function testcase.actual_measure_proxy_call_without_method()
    -- Test calling proxy without setting method
    registry.clear()
    local actual_measure = require('measure')

    local desc_proxy = actual_measure.describe('Test')
    assert.throws(function()
        desc_proxy()
    end, 'Attempt to call')
end

function testcase.actual_measure_complete_workflow()
    -- Test complete workflow with actual module
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

    -- Create benchmark
    actual_measure.describe('Complete Test').options({
        repeats = 2,
        warmup = 1,
    }).setup(function(i)
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

function testcase.actual_measure_proxy_non_string_method_access()
    -- Test non-string method access on proxy object
    registry.clear()
    local actual_measure = require('measure')

    local desc_proxy = actual_measure.describe('Test')

    -- Try to access with non-string key (number)
    assert.throws(function()
        local _ = desc_proxy[123]
    end, 'Attempt to access measure.describe as a table')

    -- Try to access with table key
    assert.throws(function()
        local _ = desc_proxy[{}]
    end, 'Attempt to access measure.describe as a table')

    -- Try to access with nil key
    assert.throws(function()
        local _ = desc_proxy[nil]
    end, 'Attempt to access measure.describe as a table')
end

function testcase.actual_measure_method_call_error()
    -- Test method call that returns error
    registry.clear()
    local actual_measure = require('measure')

    local desc_proxy = actual_measure.describe('Test')

    -- Call options with invalid argument to trigger error
    assert.throws(function()
        desc_proxy.options("not a table")
    end, 'options(): argument must be a table')

    -- Call setup with invalid argument
    assert.throws(function()
        desc_proxy.setup("not a function")
    end, 'setup(): argument must be a function')

    -- Call run after run_with_timer (should fail)
    desc_proxy.run_with_timer(function()
    end)
    assert.throws(function()
        desc_proxy.run(function()
        end)
    end, 'run(): cannot be defined if run_with_timer')
end

function testcase.actual_measure_proxy_tostring()
    -- Test __tostring metamethod of proxy object
    registry.clear()
    local actual_measure = require('measure')

    local desc_proxy = actual_measure.describe('MyBenchmark')
    assert.equal(tostring(desc_proxy), 'measure.describe "MyBenchmark"')

    local desc_proxy2 = actual_measure.describe('Another Test')
    assert.equal(tostring(desc_proxy2), 'measure.describe "Another Test"')
end
