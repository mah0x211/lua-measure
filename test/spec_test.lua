require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_spec = require('measure.spec')

function testcase.new_spec_creates_object()
    -- Test that new_spec() creates a valid spec object
    local spec = new_spec()
    assert.is_table(spec)
    assert.is_table(spec.hooks)
    assert.is_table(spec.describes)
    assert.equal(#spec.describes, 0)

    -- Check that it has the correct metatable
    local mt = getmetatable(spec)
    assert.is_table(mt)
    assert.is_function(mt.__tostring)
    assert.match(tostring(spec), '^measure%.spec: 0x%x+$', false)
end

function testcase.set_hook_valid_hooks()
    local spec = new_spec()

    -- Test setting all valid hooks
    local ok, err = spec:set_hook('before_all', function()
    end)
    assert.is_true(ok)
    assert.is_nil(err)

    ok, err = spec:set_hook('before_each', function()
    end)
    assert.is_true(ok)
    assert.is_nil(err)

    ok, err = spec:set_hook('after_each', function()
    end)
    assert.is_true(ok)
    assert.is_nil(err)

    ok, err = spec:set_hook('after_all', function()
    end)
    assert.is_true(ok)
    assert.is_nil(err)

    -- Verify hooks were set
    assert.is_function(spec.hooks.before_all)
    assert.is_function(spec.hooks.before_each)
    assert.is_function(spec.hooks.after_each)
    assert.is_function(spec.hooks.after_all)
end

function testcase.set_hook_invalid_name_type()
    local spec = new_spec()

    -- Test with non-string hook name
    local ok, err = spec:set_hook(123, function()
    end)
    assert.is_false(ok)
    assert.equal(err, 'name must be a string, got number')

    ok, err = spec:set_hook(true, function()
    end)
    assert.is_false(ok)
    assert.equal(err, 'name must be a string, got boolean')

    ok, err = spec:set_hook({}, function()
    end)
    assert.is_false(ok)
    assert.equal(err, 'name must be a string, got table')
end

function testcase.set_hook_invalid_function_type()
    local spec = new_spec()

    -- Test with non-function value
    local ok, err = spec:set_hook('before_all', 'not a function')
    assert.is_false(ok)
    assert.equal(err, 'fn must be a function, got string')

    ok, err = spec:set_hook('before_all', 123)
    assert.is_false(ok)
    assert.equal(err, 'fn must be a function, got number')

    ok, err = spec:set_hook('before_all', {})
    assert.is_false(ok)
    assert.equal(err, 'fn must be a function, got table')
end

function testcase.set_hook_invalid_name()
    local spec = new_spec()

    -- Test with invalid hook name
    local ok, err = spec:set_hook('invalid_hook', function()
    end)
    assert.is_false(ok)
    assert.match(err, 'Invalid hook name "invalid_hook"', false)
    assert.match(err, 'must be one of:', false)
end

function testcase.set_hook_duplicate()
    local spec = new_spec()

    -- Set hook once
    local ok, err = spec:set_hook('before_all', function()
    end)
    assert.is_true(ok)
    assert.is_nil(err)

    -- Try to set the same hook again
    ok, err = spec:set_hook('before_all', function()
    end)
    assert.is_false(ok)
    assert.equal(err, 'Hook "before_all" already exists, it must be unique')
end

function testcase.new_describe_valid()
    local spec = new_spec()

    -- Test creating a describe
    local desc, err = spec:new_describe('Test Benchmark')
    assert.is_table(desc)
    assert.is_nil(err)

    -- Check tostring format
    assert.equal(tostring(desc), 'measure.describe "Test Benchmark"')

    -- Check it was added to describes
    assert.equal(spec.describes[1], desc)
    assert.equal(spec.describes['Test Benchmark'], desc)
    assert.equal(#spec.describes, 1)
end

function testcase.new_describe_with_namefn()
    local spec = new_spec()

    -- Test creating a describe with name function
    local namefn = function(i)
        return 'Dynamic Test ' .. i
    end
    local desc, err = spec:new_describe('Base Name', namefn)
    assert.is_table(desc)
    assert.is_nil(err)

    -- Check that namefn is stored
    assert.equal(desc.spec.namefn, namefn)
end

function testcase.new_describe_invalid_name()
    local spec = new_spec()

    -- Test with invalid name type
    local desc, err = spec:new_describe(123)
    assert.is_nil(desc)
    assert.match(err, 'name must be a string', false)

    desc, err = spec:new_describe(true)
    assert.is_nil(desc)
    assert.match(err, 'name must be a string', false)

    desc, err = spec:new_describe({})
    assert.is_nil(desc)
    assert.match(err, 'name must be a string', false)
end

function testcase.new_describe_invalid_namefn()
    local spec = new_spec()

    -- Test with invalid namefn type
    local desc, err = spec:new_describe('Test', 'not a function')
    assert.is_nil(desc)
    assert.match(err, 'namefn must be a function or nil', false)

    desc, err = spec:new_describe('Test', 123)
    assert.is_nil(desc)
    assert.match(err, 'namefn must be a function or nil', false)
end

function testcase.new_describe_duplicate_name()
    local spec = new_spec()

    -- Create first describe
    local desc1, err = spec:new_describe('Duplicate Test')
    assert.is_table(desc1)
    assert.is_nil(err)

    -- Try to create another with same name
    local desc2, err2 = spec:new_describe('Duplicate Test')
    assert.is_nil(desc2)
    assert.equal(err2, 'name "Duplicate Test" already exists, it must be unique')
end

function testcase.multiple_describes()
    local spec = new_spec()

    -- Create multiple describes
    local desc1 = spec:new_describe('Test 1')
    local desc2 = spec:new_describe('Test 2')
    local desc3 = spec:new_describe('Test 3')

    -- Check they are all different
    assert.not_equal(desc1, desc2)
    assert.not_equal(desc2, desc3)
    assert.not_equal(desc1, desc3)

    -- Check they are all in the describes table
    assert.equal(#spec.describes, 3)
    assert.equal(spec.describes[1], desc1)
    assert.equal(spec.describes[2], desc2)
    assert.equal(spec.describes[3], desc3)

    -- Check name mapping
    assert.equal(spec.describes['Test 1'], desc1)
    assert.equal(spec.describes['Test 2'], desc2)
    assert.equal(spec.describes['Test 3'], desc3)
end

function testcase.spec_independence()
    -- Test that multiple specs are independent
    local spec1 = new_spec()
    local spec2 = new_spec()

    -- They should be different objects (different references)
    assert.is_true(spec1 ~= spec2)

    -- Set different hooks
    spec1:set_hook('before_all', function()
        return 'spec1'
    end)
    spec2:set_hook('before_all', function()
        return 'spec2'
    end)

    -- Check they have different hooks
    assert.not_equal(spec1.hooks.before_all, spec2.hooks.before_all)
    assert.equal(spec1.hooks.before_all(), 'spec1')
    assert.equal(spec2.hooks.before_all(), 'spec2')

    -- Create describes in each
    spec1:new_describe('Test A')
    spec2:new_describe('Test B')

    -- Check they have different describes
    assert.equal(#spec1.describes, 1)
    assert.equal(#spec2.describes, 1)
    assert.equal(spec1.describes['Test A'].spec.name, 'Test A')
    assert.equal(spec2.describes['Test B'].spec.name, 'Test B')
    assert.is_nil(spec1.describes['Test B'])
    assert.is_nil(spec2.describes['Test A'])
end

function testcase.verify_describes_with_valid_run_function()
    local spec = new_spec()

    -- Create describe with run function
    local desc = spec:new_describe('Test with run')
    desc:run(function()
        -- Benchmark code
    end)

    -- Verify should succeed
    local errs = spec:verify_describes()
    assert.is_nil(errs)
end

function testcase.verify_describes_with_valid_run_with_timer_function()
    local spec = new_spec()

    -- Create describe with run_with_timer function
    local desc = spec:new_describe('Test with run_with_timer')
    desc:run_with_timer(function()
        -- Benchmark code with timer
    end)

    -- Verify should succeed
    local errs = spec:verify_describes()
    assert.is_nil(errs)
end

function testcase.verify_describes_with_both_run_functions()
    local spec = new_spec()

    -- Create describe with run function
    local desc1 = spec:new_describe('Test 1')
    desc1:run(function()
        -- Benchmark code
    end)

    -- Create describe with run_with_timer function
    local desc2 = spec:new_describe('Test 2')
    desc2:run_with_timer(function()
        -- Benchmark code with timer
    end)

    -- Verify should succeed
    local errs = spec:verify_describes()
    assert.is_nil(errs)
end

function testcase.verify_describes_without_run_functions()
    local spec = new_spec()

    -- Create describe without run function
    spec:new_describe('Test without run')

    -- Verify should fail
    local errs = spec:verify_describes()
    assert.is_table(errs)
    assert.equal(#errs, 1)
    -- Error message should contain source file and line number
    assert.match(errs[1],
                 'measure%.describe "Test without run" has not defined a run%(%) or run_with_timer%(%) function',
                 false)
end

function testcase.verify_describes_with_multiple_invalid_describes()
    local spec = new_spec()

    -- Create multiple describes without run functions
    spec:new_describe('Invalid 1')
    spec:new_describe('Invalid 2')
    spec:new_describe('Invalid 3')

    -- Verify should fail with multiple errors
    local errs = spec:verify_describes()
    assert.is_table(errs)
    assert.equal(#errs, 3)
    assert.match(errs[1],
                 'measure%.describe "Invalid 1" has not defined a run%(%) or run_with_timer%(%) function',
                 false)
    assert.match(errs[2],
                 'measure%.describe "Invalid 2" has not defined a run%(%) or run_with_timer%(%) function',
                 false)
    assert.match(errs[3],
                 'measure%.describe "Invalid 3" has not defined a run%(%) or run_with_timer%(%) function',
                 false)
end

function testcase.verify_describes_with_empty_describes()
    local spec = new_spec()

    -- Verify with no describes should succeed
    local errs = spec:verify_describes()
    assert.is_nil(errs)
end

function testcase.verify_describes_with_mixed_valid_and_invalid()
    local spec = new_spec()

    -- Create valid describe
    local desc1 = spec:new_describe('Valid')
    desc1:run(function()
        -- Benchmark code
    end)

    -- Create invalid describe
    spec:new_describe('Invalid')

    -- Create another valid describe
    local desc3 = spec:new_describe('Also Valid')
    desc3:run_with_timer(function()
        -- Benchmark code with timer
    end)

    -- Verify should fail with only invalid describe error
    local errs = spec:verify_describes()
    assert.is_table(errs)
    assert.equal(#errs, 1)
    assert.match(errs[1],
                 'measure%.describe "Invalid" has not defined a run%(%) or run_with_timer%(%) function',
                 false)
end
