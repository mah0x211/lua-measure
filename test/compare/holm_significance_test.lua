local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new
local welcht = require('measure.compare.welcht')
local skesd = require('measure.compare.skesd')

-- Equal within-group variances make the three pairwise tests reproducible.
local function new_group(name, offset)
    return assert(new_samples({
        name = name,
        capacity = 5,
        count = 5,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5,
        time_ns = { 100 + offset, 110 + offset, 120 + offset,
                    130 + offset, 140 + offset },
        before_kb = { 0, 0, 0, 0, 0 },
        after_kb = { 0, 0, 0, 0, 0 },
    }))
end

function testcase.welcht_uses_adjusted_p_for_significance()
    local result = welcht({
        new_group('A', 0),
        new_group('B', 25),
        new_group('C', 50),
    })
    local pair = result.pairs.A.B

    assert.greater(pair.p_value, 0.03)
    assert.less(pair.p_value, 0.05)
    assert.greater(pair.p_adjusted, 0.05)
    assert.is_false(pair.significant)
    assert.is_nil(pair.significance_level)
end

function testcase.welcht_uses_adjusted_p_for_significance_level()
    local result = welcht({
        new_group('A', 0),
        new_group('B', 20),
        new_group('C', 40),
    })
    local pair = result.pairs.A.C

    assert.less(pair.p_value, 0.01)
    assert.greater(pair.p_adjusted, 0.01)
    assert.less(pair.p_adjusted, 0.05)
    assert.is_true(pair.significant)
    assert.equal(pair.significance_level, 'p<0.05')
end

function testcase.skesd_uses_adjusted_p_for_significance()
    local result = skesd({
        new_group('A', 0),
        new_group('B', 25),
        new_group('C', 50),
    })
    assert.equal(#result.groups, 3)
    local pair = result.pairs['Cluster 1']['Cluster 2']

    assert.greater(pair.p_value, 0.03)
    assert.less(pair.p_value, 0.05)
    assert.greater(pair.p_adjusted, 0.05)
    assert.is_false(pair.significant)
    assert.is_nil(pair.significance_level)
end

function testcase.skesd_uses_adjusted_p_for_significance_level()
    local result = skesd({
        new_group('A', 0),
        new_group('B', 20),
        new_group('C', 40),
    })
    assert.equal(#result.groups, 3)
    local pair = result.pairs['Cluster 1']['Cluster 3']

    assert.less(pair.p_value, 0.01)
    assert.greater(pair.p_adjusted, 0.01)
    assert.less(pair.p_adjusted, 0.05)
    assert.is_true(pair.significant)
    assert.equal(pair.significance_level, 'p<0.05')
end
