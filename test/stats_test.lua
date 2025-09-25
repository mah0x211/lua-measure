local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new
local stats = require('measure.stats')

local function create_named_samples(name, time_values)
    local data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = #time_values,
        count = #time_values,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
        name = name,
    }

    for i, time_ns in ipairs(time_values) do
        data.time_ns[i] = math.floor(time_ns)
        data.before_kb[i] = 100
        data.after_kb[i] = 100
        data.allocated_kb[i] = 0
    end

    return new_samples(data)
end

function testcase.basic()
    local time_values1 = {}
    local time_values2 = {}

    for i = 1, 100 do
        time_values1[#time_values1 + 1] = (10 + i * 0.1) * 1000000
        time_values2[#time_values2 + 1] = (20 + i * 0.1) * 1000000
    end

    local sample1 = create_named_samples('fast', time_values1)
    local sample2 = create_named_samples('slow', time_values2)

    local result = stats({
        sample1,
        sample2,
    })

    assert.is_table(result)
    assert.is_table(result.summaries)
    assert.is_table(result.comparison)
    assert.is_table(result.comparison.pairs)
    assert.is_table(result.comparison.method)
    assert.is_string(result.comparison.method.name)
    assert.equal(#result.summaries, 2)
    assert(result.comparison.method.name ==
               "Welch's t-test with Holm correction" or
               result.comparison.method.name ==
               "Scott-Knott ESD (Effect Size Difference) clustering",
           'method name should be proper method name')

    local fast_sample, slow_sample
    for _, sample in ipairs(result.summaries) do
        if sample.name == 'fast' then
            fast_sample = sample
        elseif sample.name == 'slow' then
            slow_sample = sample
        end
    end

    assert.is_table(fast_sample)
    assert.is_table(slow_sample)
    assert.is_number(fast_sample.mean)
    assert.is_number(slow_sample.mean)
    assert(fast_sample.mean < slow_sample.mean,
           'fast should be faster than slow')

    assert.is_table(result.comparison.pairs)
    assert(#result.comparison.pairs >= 1)

    local comparison = result.comparison.pairs[1]
    assert.is_string(comparison.name1)
    assert.is_string(comparison.name2)
    assert.is_number(comparison.speedup)
    assert.is_number(comparison.p_value)
    assert.is_boolean(comparison.significant)
end

function testcase.single_sample()
    local time_values = {}
    for _ = 1, 10 do
        time_values[#time_values + 1] = 10 * 1000000
    end

    local sample1 = create_named_samples('only_one', time_values)
    local result = stats({sample1})

    assert.is_table(result.summaries)
    assert.equal(#result.summaries, 1)
    assert.is_table(result.comparison)
    assert.equal(result.comparison.method.algorithm, 'single-sample')
    assert.equal(#result.comparison.pairs, 0)
    assert.equal(result.summaries[1].name, 'only_one')
end

function testcase.quality_assessment()
    local stable_times = {}
    for _ = 1, 1000 do
        stable_times[#stable_times + 1] = 10 * 1000000
    end

    local variable_times = {}
    for i = 1, 100 do
        variable_times[#variable_times + 1] = (10 + (i % 10)) * 1000000
    end

    local sample1 = create_named_samples('stable', stable_times)
    local sample2 = create_named_samples('variable', variable_times)
    local result = stats({sample1, sample2})

    for _, sample in ipairs(result.summaries) do
        assert.is_string(sample.quality)
        assert.is_number(sample.quality_score)
        assert(sample.quality == 'excellent' or sample.quality == 'good' or
                   sample.quality == 'acceptable' or sample.quality == 'poor',
               'quality should be one of the expected values')
        assert(sample.quality_score >= 0 and sample.quality_score <= 1)
    end
end

function testcase.multiple_samples()
    local samples_list = {}

    for i = 1, 6 do
        local time_values = {}
        for j = 1, 50 do
            time_values[#time_values + 1] = (10 * i + j * 0.1) * 1000000
        end

        local sample = create_named_samples('sample' .. i, time_values)
        samples_list[#samples_list + 1] = sample
    end

    local result = stats(samples_list)

    assert.equal(#result.summaries, 6)
    assert.equal(result.comparison.method.name,
                 "Scott-Knott ESD (Effect Size Difference) clustering")
    assert.is_table(result.comparison.groups)
end

function testcase.groups_structure()
    local time_values1 = {}
    local time_values2 = {}

    for _ = 1, 100 do
        time_values1[#time_values1 + 1] = 10 * 1000000
        time_values2[#time_values2 + 1] = 20 * 1000000
    end

    local sample1 = create_named_samples('group1', time_values1)
    local sample2 = create_named_samples('group2', time_values2)
    local result = stats({sample1, sample2})

    if result.comparison and result.comparison.groups then
        for _, group in ipairs(result.comparison.groups) do
            assert.is_table(group.names)
            assert.is_number(group.rank)
            assert(#group.names >= 1)
        end
    end
end
