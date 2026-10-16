local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new
local sampler = require('measure.sampler')

local original_pause

function testcase.before_each()
    collectgarbage('restart')
    original_pause = collectgarbage('setpause', 120)
end

function testcase.after_each()
    collectgarbage('setpause', original_pause)
    collectgarbage('restart')
end

function testcase.sampler_error_restores_pause_with_disabled_gc()
    local s = assert(new_samples('failure', 3, -1))
    local ok, err = sampler(function()
        collectgarbage('setpause', 40)
        error('sampling failure')
    end, s)

    assert.is_false(ok)
    assert.match(err, 'runtime error:.*sampling failure', false)
    assert.equal(collectgarbage('setpause', 120), 120)
    assert.equal(#s, 1)
end

function testcase.sampler_error_restores_pause_with_full_gc()
    local s = assert(new_samples('failure', 3, 0))
    local ok, err = sampler(function()
        collectgarbage('setpause', 40)
        error('sampling failure')
    end, s)

    assert.is_false(ok)
    assert.match(err, 'runtime error:.*sampling failure', false)
    assert.equal(collectgarbage('setpause', 120), 120)
end

function testcase.sampler_success_restores_pause_with_disabled_gc()
    local s = assert(new_samples('success', 3, -1))
    local ok, err = sampler(function()
        collectgarbage('setpause', 40)
    end, s)

    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(collectgarbage('setpause', 120), 120)
    assert.equal(#s, 3)
end

function testcase.sampler_warmup_error_does_not_restore_uninitialized_state()
    local s = assert(new_samples('warmup', 3, -1))
    local ok, err = sampler(function()
        collectgarbage('setpause', 40)
        error('warmup failure')
    end, s, 1)

    assert.is_false(ok)
    assert.match(err, 'runtime error:.*warmup failure', false)
    assert.equal(collectgarbage('setpause', 120), 40)
    assert.equal(#s, 0)
end

function testcase.sampler_can_continue_after_callback_error()
    local s = assert(new_samples('retry', 3, -1))
    local ok, err = sampler(function()
        collectgarbage('setpause', 40)
        error('first call failed')
    end, s)

    assert.is_false(ok)
    assert.match(err, 'runtime error:.*first call failed', false)
    assert.equal(collectgarbage('setpause', 120), 120)

    local calls = 0
    ok, err = sampler(function()
        calls = calls + 1
    end, s)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(calls, 2)
    assert.equal(#s, 3)
    assert.equal(collectgarbage('setpause', 120), 120)
end
