require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_describe = require('measure.describe')

-- Helper functions
local function create_dummy_fn()
    return function()
    end
end

-- Constructor tests
function testcase.constructor()
    -- Test valid describe instance
    local desc = assert(new_describe('test benchmark'))
    assert.equal(tostring(desc), 'measure.describe "test benchmark"')
    assert.equal(desc.spec.name, 'test benchmark')
end

function testcase.constructor_invalid()
    -- Test invalid arguments
    local desc, err = new_describe(123)
    assert.is_nil(desc)
    assert.equal(err, 'name must be a string, got "number"')
end

-- Helper function for method testing
local function test_method_lifecycle(method_name, expected_field,
                                     incompatible_method)
    local test_fn = create_dummy_fn()

    -- Test valid call
    local desc = assert(new_describe('test'))
    local ok, err = desc[method_name](desc, test_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec[expected_field], test_fn)

    -- Test invalid argument type
    desc = assert(new_describe('test'))
    ok, err = desc[method_name](desc, 'not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- Test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc[method_name](desc, test_fn))
    ok, err = desc[method_name](desc, test_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- Test incompatible method if specified
    if incompatible_method then
        desc = assert(new_describe('test'))
        assert(desc[incompatible_method.name](desc, create_dummy_fn()))
        ok, err = desc[method_name](desc, test_fn)
        assert.is_false(ok)
        assert.equal(err, incompatible_method.error)
    end
end

-- Method tests

function testcase.setup()
    test_method_lifecycle('setup', 'setup', {
        name = 'setup_once',
        error = 'cannot be defined if setup_once() is defined',
    })

    -- Test ordering constraints
    local desc = assert(new_describe('test'))
    assert(desc:run(create_dummy_fn()))
    local ok, err = desc:setup(create_dummy_fn())
    assert.is_false(ok)
    assert.equal(err, 'must be defined before run() or run_with_timer()')
end

function testcase.setup_once()
    test_method_lifecycle('setup_once', 'setup_once', {
        name = 'setup',
        error = 'cannot be defined if setup() is defined',
    })

    -- Test ordering constraints
    local desc = assert(new_describe('test'))
    assert(desc:run_with_timer(create_dummy_fn()))
    local ok, err = desc:setup_once(create_dummy_fn())
    assert.is_false(ok)
    assert.equal(err, 'must be defined before run() or run_with_timer()')
end

function testcase.run()
    test_method_lifecycle('run', 'run', {
        name = 'run_with_timer',
        error = 'cannot be defined if run_with_timer() is defined',
    })
end

function testcase.run_with_timer()
    test_method_lifecycle('run_with_timer', 'run_with_timer', {
        name = 'run',
        error = 'cannot be defined if run() is defined',
    })
end

function testcase.teardown()
    local teardown_fn = create_dummy_fn()

    -- Test teardown after run
    local desc = assert(new_describe('test'))
    assert(desc:run(create_dummy_fn()))
    local ok, err = desc:teardown(teardown_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.teardown, teardown_fn)

    -- Test teardown after run_with_timer
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(create_dummy_fn()))
    ok, err = desc:teardown(create_dummy_fn())
    assert.is_true(ok)
    assert.is_nil(err)

    -- Test invalid argument type
    desc = assert(new_describe('test'))
    assert(desc:run(create_dummy_fn()))
    ok, err = desc:teardown('not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- Test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:run(create_dummy_fn()))
    assert(desc:teardown(teardown_fn))
    ok, err = desc:teardown(teardown_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- Test must be defined after run
    desc = assert(new_describe('test'))
    ok, err = desc:teardown(create_dummy_fn())
    assert.is_false(ok)
    assert.equal(err, 'must be defined after run() or run_with_timer()')
end

-- Workflow tests
function testcase.workflow()
    -- Test setup → run → teardown workflow
    local desc = assert(new_describe('complete test'))
    assert(desc:setup(create_dummy_fn()))
    assert(desc:run(create_dummy_fn()))
    assert(desc:teardown(create_dummy_fn()))

    local expected_fields = {
        'setup',
        'run',
        'teardown',
    }
    local nil_fields = {
        'setup_once',
        'run_with_timer',
        'options',
    }

    for _, field in ipairs(expected_fields) do
        assert.is_function(desc.spec[field])
    end
    for _, field in ipairs(nil_fields) do
        assert.is_nil(desc.spec[field])
    end

    -- Test setup_once → run_with_timer workflow
    desc = assert(new_describe('test with setup_once'))
    assert(desc:setup_once(create_dummy_fn()))
    assert(desc:run_with_timer(create_dummy_fn()))

    expected_fields = {
        'setup_once',
        'run_with_timer',
    }
    nil_fields = {
        'setup',
        'run',
        'teardown',
        'options',
    }

    for _, field in ipairs(expected_fields) do
        assert.is_function(desc.spec[field])
    end
    for _, field in ipairs(nil_fields) do
        assert.is_nil(desc.spec[field])
    end
end
