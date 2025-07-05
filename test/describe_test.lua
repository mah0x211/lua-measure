require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_describe = require('measure.describe')

function testcase.new_describe()
    -- test create valid describe instance
    local desc = assert(new_describe('test benchmark'))
    assert.equal(tostring(desc), 'measure.describe "test benchmark"')
    assert.equal(desc.spec.name, 'test benchmark')
    assert.is_nil(desc.spec.namefn)

    -- test create with namefn
    local namefn = function(i)
        return 'test ' .. i
    end
    desc = assert(new_describe('test benchmark', namefn))
    assert.equal(desc.spec.name, 'test benchmark')
    assert.equal(desc.spec.namefn, namefn)

    -- test tostring
    assert.equal(tostring(desc), 'measure.describe "test benchmark"')

    -- test invalid name type
    local d, err = new_describe(123)
    assert.is_nil(d)
    assert.equal(err, 'name must be a string, got "number"')

    -- test invalid namefn type
    d, err = new_describe('test', 'not a function')
    assert.is_nil(d)
    assert.equal(err, 'namefn must be a function or nil, got "string"')
end

function testcase.options()
    local desc = assert(new_describe('test'))

    -- test valid options
    local ok, err = desc:options({
        context = {
            foo = 'bar',
        },
        warmup = 5,
        confidence_level = 95,
        rciw = 5,
    })
    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_table(desc.spec.options)

    -- test options with function values
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        context = function()
            return {}
        end,
        warmup = 3, -- warmup no longer supports function type
        confidence_level = 95,
        rciw = 5,
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test invalid argument type
    desc = assert(new_describe('test'))
    ok, err = desc:options('not a table')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a table')

    -- test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:options({}))
    ok, err = desc:options({})
    assert.is_false(ok)
    assert.equal(err, 'options cannot be defined twice')

    -- test must be defined before setup
    desc = assert(new_describe('test'))
    assert(desc:setup(function()
    end))
    ok, err = desc:options({})
    assert.is_false(ok)
    assert.equal(err,
                 'options must be defined before setup(), setup_once(), run() or run_with_timer()')

    -- test must be defined before setup_once
    desc = assert(new_describe('test'))
    assert(desc:setup_once(function()
    end))
    ok, err = desc:options({})
    assert.is_false(ok)
    assert.equal(err,
                 'options must be defined before setup(), setup_once(), run() or run_with_timer()')

    -- test must be defined before run
    desc = assert(new_describe('test'))
    assert(desc:run(function()
    end))
    ok, err = desc:options({})
    assert.is_false(ok)
    assert.equal(err,
                 'options must be defined before setup(), setup_once(), run() or run_with_timer()')

    -- test must be defined before run_with_timer
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(function()
    end))
    ok, err = desc:options({})
    assert.is_false(ok)
    assert.equal(err,
                 'options must be defined before setup(), setup_once(), run() or run_with_timer()')

    -- test invalid context type
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        context = 123,
    })
    assert.is_false(ok)
    assert.equal(err, 'options.context must be a table or a function')

    -- test invalid confidence_level type
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        confidence_level = 'not a number',
    })
    assert.is_false(ok)
    assert.equal(err,
                 'options.confidence_level must be a number between 0 and 100')

    -- test invalid confidence_level value (negative)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        confidence_level = -1,
    })
    assert.is_false(ok)
    assert.equal(err,
                 'options.confidence_level must be a number between 0 and 100')

    -- test invalid confidence_level value (too high)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        confidence_level = 150,
    })
    assert.is_false(ok)
    assert.equal(err,
                 'options.confidence_level must be a number between 0 and 100')

    -- test invalid warmup type
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        warmup = 'not a number',
    })
    assert.is_false(ok)
    assert.equal(err, 'options.warmup must be a number between 0 and 5')

    -- test invalid warmup value (negative)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        warmup = -1,
    })
    assert.is_false(ok)
    assert.equal(err, 'options.warmup must be a number between 0 and 5')

    -- test valid warmup value (zero)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        warmup = 0,
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test valid warmup value (maximum)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        warmup = 5,
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test valid warmup value (decimal)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        warmup = 2.5,
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test invalid warmup value (too high)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        warmup = 6,
    })
    assert.is_false(ok)
    assert.equal(err, 'options.warmup must be a number between 0 and 5')

    -- test invalid rciw type
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        rciw = 'not a number',
    })
    assert.is_false(ok)
    assert.equal(err, 'options.rciw must be a number between 0 and 100')

    -- test invalid rciw value (zero)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        rciw = 0,
    })
    assert.is_false(ok)
    assert.equal(err, 'options.rciw must be a number between 0 and 100')

    -- test invalid rciw value (too high)
    desc = assert(new_describe('test'))
    ok, err = desc:options({
        rciw = 150,
    })
    assert.is_false(ok)
    assert.equal(err, 'options.rciw must be a number between 0 and 100')
end

function testcase.setup()
    local desc = assert(new_describe('test'))
    local setup_fn = function()
    end

    -- test valid setup
    local ok, err = desc:setup(setup_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.setup, setup_fn)

    -- test invalid argument type
    desc = assert(new_describe('test'))
    ok, err = desc:setup('not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:setup(setup_fn))
    ok, err = desc:setup(setup_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- test cannot define if setup_once is defined
    desc = assert(new_describe('test'))
    assert(desc:setup_once(function()
    end))
    ok, err = desc:setup(setup_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined if setup_once() is defined')

    -- test must be defined before run
    desc = assert(new_describe('test'))
    assert(desc:run(function()
    end))
    ok, err = desc:setup(setup_fn)
    assert.is_false(ok)
    assert.equal(err, 'must be defined before run() or run_with_timer()')

    -- test must be defined before run_with_timer
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(function()
    end))
    ok, err = desc:setup(setup_fn)
    assert.is_false(ok)
    assert.equal(err, 'must be defined before run() or run_with_timer()')
end

function testcase.setup_once()
    local desc = assert(new_describe('test'))
    local setup_once_fn = function()
    end

    -- test valid setup_once
    local ok, err = desc:setup_once(setup_once_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.setup_once, setup_once_fn)

    -- test invalid argument type
    desc = assert(new_describe('test'))
    ok, err = desc:setup_once('not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:setup_once(setup_once_fn))
    ok, err = desc:setup_once(setup_once_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- test cannot define if setup is defined
    desc = assert(new_describe('test'))
    assert(desc:setup(function()
    end))
    ok, err = desc:setup_once(setup_once_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined if setup() is defined')

    -- test must be defined before run
    desc = assert(new_describe('test'))
    assert(desc:run(function()
    end))
    ok, err = desc:setup_once(setup_once_fn)
    assert.is_false(ok)
    assert.equal(err, 'must be defined before run() or run_with_timer()')

    -- test must be defined before run_with_timer
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(function()
    end))
    ok, err = desc:setup_once(setup_once_fn)
    assert.is_false(ok)
    assert.equal(err, 'must be defined before run() or run_with_timer()')
end

function testcase.run()
    local desc = assert(new_describe('test'))
    local run_fn = function()
    end

    -- test valid run
    local ok, err = desc:run(run_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.run, run_fn)

    -- test invalid argument type
    desc = assert(new_describe('test'))
    ok, err = desc:run('not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:run(run_fn))
    ok, err = desc:run(run_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- test cannot define if run_with_timer is defined
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(function()
    end))
    ok, err = desc:run(run_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined if run_with_timer() is defined')
end

function testcase.run_with_timer()
    local desc = assert(new_describe('test'))
    local run_with_timer_fn = function()
    end

    -- test valid run_with_timer
    local ok, err = desc:run_with_timer(run_with_timer_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.run_with_timer, run_with_timer_fn)

    -- test invalid argument type
    desc = assert(new_describe('test'))
    ok, err = desc:run_with_timer('not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(run_with_timer_fn))
    ok, err = desc:run_with_timer(run_with_timer_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- test cannot define if run is defined
    desc = assert(new_describe('test'))
    assert(desc:run(function()
    end))
    ok, err = desc:run_with_timer(run_with_timer_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined if run() is defined')
end

function testcase.teardown()
    local desc = assert(new_describe('test'))
    local teardown_fn = function()
    end

    -- test valid teardown after run
    assert(desc:run(function()
    end))
    local ok, err = desc:teardown(teardown_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.teardown, teardown_fn)

    -- test valid teardown after run_with_timer
    desc = assert(new_describe('test'))
    assert(desc:run_with_timer(function()
    end))
    ok, err = desc:teardown(teardown_fn)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(desc.spec.teardown, teardown_fn)

    -- test invalid argument type
    desc = assert(new_describe('test'))
    assert(desc:run(function()
    end))
    ok, err = desc:teardown('not a function')
    assert.is_false(ok)
    assert.equal(err, 'argument must be a function')

    -- test cannot define twice
    desc = assert(new_describe('test'))
    assert(desc:run(function()
    end))
    assert(desc:teardown(teardown_fn))
    ok, err = desc:teardown(teardown_fn)
    assert.is_false(ok)
    assert.equal(err, 'cannot be defined twice')

    -- test must be defined after run or run_with_timer
    desc = assert(new_describe('test'))
    ok, err = desc:teardown(teardown_fn)
    assert.is_false(ok)
    assert.equal(err, 'must be defined after run() or run_with_timer()')
end

function testcase.complete_workflow()
    -- test typical workflow with options, setup, run, teardown
    local desc = assert(new_describe('complete test'))
    assert(desc:options({
        warmup = 3,
        confidence_level = 95,
        rciw = 5,
    }))
    assert(desc:setup(function(i, _)
        return 'test' .. i
    end))
    assert(desc:run(function(data)
        return data .. data
    end))
    assert(desc:teardown(function(_)
    end))

    -- verify all spec fields are set
    assert.is_table(desc.spec.options)
    assert.is_function(desc.spec.setup)
    assert.is_function(desc.spec.run)
    assert.is_function(desc.spec.teardown)
    assert.is_nil(desc.spec.setup_once)
    assert.is_nil(desc.spec.run_with_timer)

    -- test workflow with setup_once and run_with_timer
    desc = assert(new_describe('test with setup_once', function(i)
        return 'iteration ' .. i
    end))
    assert(desc:options({
        context = {
            multiplier = 2,
        },
    }))
    assert(desc:setup_once(function()
        return {
            data = 'shared',
        }
    end))
    assert(desc:run_with_timer(function(_, _, _)
        local start = os.clock()
        -- do work
        local stop = os.clock()
        return stop - start
    end))

    -- verify spec fields
    assert.is_table(desc.spec.options)
    assert.is_function(desc.spec.setup_once)
    assert.is_function(desc.spec.run_with_timer)
    assert.is_function(desc.spec.namefn)
    assert.is_nil(desc.spec.setup)
    assert.is_nil(desc.spec.run)
    assert.is_nil(desc.spec.teardown)
end
