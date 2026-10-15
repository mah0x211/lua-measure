local testcase = require('testcase')
local assert = require('assert')
local samples = require('measure.samples')
local sampler = require('measure.sampler')

-- On 64-bit targets, 2^59 samples overflow the 32-byte data array size.
-- These inputs also leave the old implementation with an empty or small
-- allocation, so rejection tests do not request enormous physical memory.
local overflowing_capacity = math.floor(2 ^ 59)

function testcase.new_rejects_overflowing_array_size()
    local s, err = samples.new('overflow', overflowing_capacity)
    assert.is_nil(s)
    assert.equal(err, 'capacity is too large')
end

function testcase.new_rejects_multiple_array_size_wraps()
    local s, err = samples.new('overflow', overflowing_capacity * 2)
    assert.is_nil(s)
    assert.equal(err, 'capacity is too large')
end

function testcase.new_restore_rejects_overflowing_array_size()
    local s, err = samples.new({
        name = 'restored',
        capacity = overflowing_capacity,
        count = 0,
        gc_step = 0,
        cl = 95,
        rciw = 5,
        base_kb = 1,
        time_ns = {},
        before_kb = {},
        after_kb = {},
    })
    assert.is_nil(s)
    assert.equal(err, "invalid field 'capacity': is too large")
end

function testcase.capacity_rejects_overflow_without_changing_samples()
    local s = assert(samples.new('growth', 2))
    assert.is_true(sampler(function()
    end, s))
    local original = s:dump()

    local err = assert.throws(function()
        s:capacity(overflowing_capacity)
    end)
    assert.match(err, 'capacity is too large')
    assert.equal(s:capacity(), 2)
    assert.equal(s:dump(), original)

    assert.equal(s:capacity(2), 4)
    assert.is_true(sampler(function()
    end, s))
    assert.equal(#s, 4)
    local data = s:dump()
    assert.equal(data.time_ns[1], original.time_ns[1])
    assert.equal(data.time_ns[2], original.time_ns[2])
end

function testcase.merge_preserves_data_and_combines_capacities()
    local s = assert(samples.new({
        name = 'source',
        capacity = 4,
        count = 2,
        gc_step = 0,
        cl = 95,
        rciw = 5,
        base_kb = 1,
        time_ns = { 100, 200 },
        before_kb = { 1, 2 },
        after_kb = { 2, 4 },
    }))
    local original = s:dump()

    local merged = samples.merge('merged', { s, s })
    assert.equal(merged:capacity(), 8)
    assert.equal(#merged, 4)
    assert.equal(merged:dump().time_ns, { 100, 200, 100, 200 })
    assert.equal(merged:mean(), 150)
    assert.equal(s:dump(), original)
end
