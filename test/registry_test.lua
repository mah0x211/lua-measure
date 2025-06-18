require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local registry = require('measure.registry')

function testcase.new_creates_spec()
    -- Test that new() creates a spec for the current file
    local spec = registry.new()
    assert.is_table(spec)
    assert.is_string(spec.filename)
    assert(spec.filename:match("registry_test%.lua$"))
    assert.is_table(spec.hooks)
    assert.is_table(spec.describes)

    -- Clear describes for clean state
    spec.describes = {}
    assert.equal(#spec.describes, 0)
end

function testcase.new_returns_same_spec()
    -- Test that new() returns the same spec for the same file
    local spec1 = registry.new()
    local spec2 = registry.new()
    assert.equal(spec1, spec2)
end

function testcase.get_returns_registry()
    -- Get current registry state
    local reg = registry.get()
    assert.is_table(reg)

    -- Test that our file is in the registry (from previous tests)
    local found = false
    for filename, spec in pairs(reg) do
        assert.is_string(filename)
        assert.is_table(spec)
        if filename:match("registry_test%.lua$") then
            found = true
        end
    end
    assert.is_true(found)
end

function testcase.set_hook_valid()
    local spec = registry.new()

    -- Test setting valid hooks
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
end

function testcase.set_hook_unknown()
    local spec = registry.new()

    -- Test setting unknown hook
    local ok, err = spec:set_hook('invalid_hook', function()
    end)
    assert.is_false(ok)
    assert.re_match(err, 'Invalid hook name "invalid_hook"')
end

function testcase.set_hook_not_function()
    local spec = registry.new()

    -- Test setting hook with non-function value
    local ok, err = spec:set_hook('before_all', "not a function")
    assert.is_false(ok)
    assert.equal(err, 'fn must be a function, got string')

    ok, err = spec:set_hook('before_all', 123)
    assert.is_false(ok)
    assert.equal(err, 'fn must be a function, got number')

    ok, err = spec:set_hook('before_all', {})
    assert.is_false(ok)
    assert.equal(err, 'fn must be a function, got table')
end

function testcase.set_hook_duplicate()
    -- Create a fresh spec by clearing hooks
    local spec = registry.new()

    -- Clear any existing hooks from previous tests
    spec.hooks = {}

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
    local spec = registry.new()

    -- Test creating a describe
    local desc, err = spec:new_describe('Test 1')
    assert.is_table(desc)
    assert.is_nil(err)
    assert.equal(tostring(desc), 'measure.describe "Test 1"')

    -- Check it was added to describes
    assert.equal(spec.describes[1], desc)
    assert.equal(spec.describes['Test 1'], desc)
    assert.equal(#spec.describes, 1)
end

function testcase.new_describe_with_namefn()
    local spec = registry.new()

    -- Test creating a describe with name function
    local namefn = function(i)
        return "Test " .. i
    end
    local desc, err = spec:new_describe('Base', namefn)
    assert.is_table(desc)
    assert.is_nil(err)
end

function testcase.new_describe_duplicate_name()
    local spec = registry.new()

    -- Create first describe
    local desc1, err = spec:new_describe('Test')
    assert.is_table(desc1)
    assert.is_nil(err)

    -- Try to create another with same name
    local desc2, err2 = spec:new_describe('Test')
    assert.is_nil(desc2)
    assert.equal(err2, 'name "Test" already exists, it must be unique')
end

function testcase.new_describe_invalid_name()
    local spec = registry.new()

    -- Test with invalid name type
    local desc, err = spec:new_describe(123)
    assert.is_nil(desc)
    assert.re_match(err, 'name must be a string')
end

function testcase.new_describe_invalid_namefn()
    local spec = registry.new()

    -- Test with invalid namefn type
    local desc, err = spec:new_describe('Test', "not a function")
    assert.is_nil(desc)
    assert.re_match(err, 'namefn must be a function or nil')
end

function testcase.multiple_files()
    -- This test simulates multiple files using the registry
    -- Since we can't actually change the caller filename,
    -- we'll test the concept by verifying that each call
    -- from this file gets the same spec

    local spec1 = registry.new()

    -- Clear describes from previous tests to get accurate count
    spec1.describes = {}

    local desc1 = spec1:new_describe('File1 Test')

    -- In a real scenario, this would be from a different file
    -- and would create a different spec
    local spec2 = registry.new()

    -- Since we're in the same file, they should be the same
    assert.equal(spec1, spec2)

    -- But we can still add different describes
    local desc2 = spec2:new_describe('File1 Test 2')
    assert.not_equal(desc1, desc2)
    assert.equal(#spec2.describes, 2)
end

function testcase.set_hook_invalid_name_type()
    local spec = registry.new()

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

function testcase.clear_registry()
    -- Test the clear function
    registry.clear()
    local reg = registry.get()
    assert.is_table(reg)

    -- Check that registry is empty
    local count = 0
    for _ in pairs(reg) do
        count = count + 1
    end
    assert.equal(count, 0)

    -- Create a new spec and verify it's added
    local spec = registry.new()
    assert.is_table(spec)

    -- Verify it's in the registry
    reg = registry.get()
    count = 0
    for _ in pairs(reg) do
        count = count + 1
    end
    assert.equal(count, 1)
end
