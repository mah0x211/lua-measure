require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new
local welch_t_test = require('measure.compare.welcht')

-- Create mock samples with specified time values
local function create_samples(name, times)
    local data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = #times,
        count = #times,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5.0,
        name = name,
    }

    for i, time in ipairs(times) do
        data.time_ns[i] = math.floor(time)
        data.before_kb[i] = 100
        data.after_kb[i] = 100
        data.allocated_kb[i] = 0
    end

    return new_samples(data)
end

-- Generate time array with specified base time and count
local function generate_times(base_ms, count, variance)
    local times = {}
    for i = 1, count do
        local time = base_ms * 1000000 -- Convert to nanoseconds
        if variance then
            time = time + math.random(-variance, variance)
        end
        times[i] = time
    end
    return times
end

-- Test basic welch t-test functionality with 2 samples
function testcase.basic_two_samples()
    local sample1 = create_samples('fast', generate_times(10, 50))
    local sample2 = create_samples('slow', generate_times(20, 50))

    local result = welch_t_test({
        sample1,
        sample2,
    })

    -- Verify result structure
    assert.is_table(result)
    assert.is_table(result.method)
    assert.is_table(result.pairs)
    assert.is_table(result.groups)

    -- Verify method information
    assert.equal(result.method.name, "Welch's t-test with Holm correction")
    assert.equal(result.method.algorithm, 'welch-t-test-holm-correction')
    assert.is_string(result.method.description)
    assert.is_string(result.method.clustering)

    -- Verify single pair comparison for 2 samples
    assert.equal(#result.pairs, 1)
    local pair = result.pairs[1]
    assert.is_string(pair.name1)
    assert.is_string(pair.name2)
    assert.is_number(pair.speedup)
    assert.is_number(pair.difference)
    assert.is_number(pair.relative_difference)
    assert.is_number(pair.p_value)
    assert.is_number(pair.p_adjusted)
    assert.is_boolean(pair.significant)
end

-- Test with 3 samples to verify multiple pairwise comparisons
function testcase.three_samples_multiple_comparisons()
    local samples = {
        create_samples('fast', generate_times(10, 30)),
        create_samples('medium', generate_times(15, 30)),
        create_samples('slow', generate_times(20, 30)),
    }

    local result = welch_t_test(samples)

    -- Verify 3 pairwise comparisons (C(3,2) = 3)
    assert.equal(#result.pairs, 3)

    -- Verify all pairs have required fields
    for _, pair in ipairs(result.pairs) do
        assert.is_string(pair.name1)
        assert.is_string(pair.name2)
        assert.is_number(pair.p_value)
        assert.is_boolean(pair.significant)
    end
end

-- Test significance level categorization
function testcase.significance_level_categorization()
    local sample1 = create_samples('similar1', generate_times(10, 100, 100000))
    local sample2 =
        create_samples('similar2', generate_times(10.1, 100, 100000))

    local result = welch_t_test({
        sample1,
        sample2,
    })
    local pair = result.pairs[1]

    -- Test significance_level is properly categorized based on p_value
    if pair.p_value < 0.001 then
        assert.equal(pair.significance_level, 'p<0.001')
    elseif pair.p_value < 0.01 then
        assert.equal(pair.significance_level, 'p<0.01')
    elseif pair.p_value < 0.05 then
        assert.equal(pair.significance_level, 'p<0.05')
    else
        assert.is_nil(pair.significance_level)
    end

    assert.equal(pair.significant, pair.p_value < 0.05)
end

-- Test edge case: zero mean values for speedup calculation
function testcase.zero_mean_edge_case()
    local zero_sample = create_samples('zero', generate_times(0, 20))
    local normal_sample = create_samples('normal', generate_times(10, 20))

    local result = welch_t_test({
        zero_sample,
        normal_sample,
    })
    local pair = result.pairs[1]

    -- Verify zero mean handling in calculations
    if pair.name2 == 'zero' then
        assert.equal(pair.speedup, 0)
        assert.equal(pair.relative_difference, 0)
    end

    assert.is_number(pair.speedup)
    assert.is_number(pair.difference)
    assert.is_number(pair.relative_difference)
end

-- Test compact letter groups with similar samples
function testcase.compact_letter_groups_similar_samples()
    local samples = {
        create_samples('similar1', generate_times(10, 50, 100000)),
        create_samples('similar2', generate_times(10, 50, 100000)),
        create_samples('similar3', generate_times(10, 50, 100000)),
    }

    local result = welch_t_test(samples)

    -- Verify group structure
    assert.is_table(result.groups)
    assert(#result.groups >= 1)

    for _, group in ipairs(result.groups) do
        assert.is_number(group.rank)
        assert.is_table(group.names)
        assert.is_table(group.members)
        assert.equal(#group.names, #group.members)
        assert(#group.members >= 1)

        -- Verify member indices and names
        for _, member_idx in ipairs(group.members) do
            assert.is_number(member_idx)
            assert(member_idx >= 1 and member_idx <= 3)
        end
    end
end

-- Test compact letter groups with different samples
function testcase.compact_letter_groups_different_samples()
    local samples = {
        create_samples('fast', generate_times(5, 50)),
        create_samples('medium', generate_times(15, 50)),
        create_samples('slow', generate_times(25, 50)),
    }

    local result = welch_t_test(samples)

    -- Verify total members across groups equals sample count
    assert.is_table(result.groups)
    local total_members = 0
    for _, group in ipairs(result.groups) do
        total_members = total_members + #group.members
    end
    assert.equal(total_members, 3)
end

-- Test with small difference samples
function testcase.small_difference_samples()
    local samples = {
        create_samples('sample1', generate_times(10, 30)),
        create_samples('sample2', generate_times(12, 30)),
    }

    local result = welch_t_test(samples)

    assert.is_table(result)
    assert.is_table(result.groups)
    assert(#result.groups >= 1)
end

-- Test error handling for single sample
function testcase.single_sample_error()
    local sample = create_samples('only_one', generate_times(10, 20))

    local ok, err = pcall(welch_t_test, {
        sample,
    })

    assert(not ok, 'Should error with single sample')
    assert.is_string(err)
    assert(string.find(err, 'minimum 2 samples required'),
           'Should mention minimum requirement')
end

-- Test performance metrics calculations
function testcase.performance_metrics_calculations()
    local fast_sample = create_samples('fast', generate_times(10, 30))
    local slow_sample = create_samples('slow', generate_times(20, 30)) -- 2x slower

    local result = welch_t_test({
        fast_sample,
        slow_sample,
    })
    local pair = result.pairs[1]

    assert.is_number(pair.speedup)
    assert.is_number(pair.difference)
    assert.is_number(pair.relative_difference)

    -- Verify relative calculations are correct
    if pair.name1 == 'slow' and pair.name2 == 'fast' then
        assert(pair.difference > 0)
        assert(pair.relative_difference > 0)
        assert(pair.speedup > 1)
    elseif pair.name1 == 'fast' and pair.name2 == 'slow' then
        assert(pair.difference < 0)
        assert(pair.relative_difference > 0)
        assert(pair.speedup < 1)
    end
end

-- Test all samples are included in groups
function testcase.all_samples_in_groups()
    local samples = {}
    local sample_names = {
        'test1',
        'test2',
        'test3',
        'test4',
    }

    for i, name in ipairs(sample_names) do
        samples[i] = create_samples(name, generate_times(10 + i * 5, 20))
    end

    local result = welch_t_test(samples)

    -- Collect all sample names from groups
    local found_names = {}
    for _, group in ipairs(result.groups) do
        for _, name in ipairs(group.names) do
            found_names[name] = true
        end
    end

    -- Verify all samples are present
    for _, name in ipairs(sample_names) do
        assert(found_names[name], 'Sample ' .. name .. ' should be in groups')
    end

    -- Count should match
    local count = 0
    for _ in pairs(found_names) do
        count = count + 1
    end
    assert.equal(count, 4)
end

-- Test significance level threshold consistency
function testcase.significance_level_thresholds()
    local sample1 = create_samples('test1', generate_times(10, 30))
    local sample2 = create_samples('test2', generate_times(11, 30))

    local result = welch_t_test({
        sample1,
        sample2,
    })
    local pair = result.pairs[1]

    -- Verify significance level assignment matches p-value
    if pair.p_value < 0.001 then
        assert.equal(pair.significance_level, 'p<0.001')
    elseif pair.p_value < 0.01 then
        assert.equal(pair.significance_level, 'p<0.01')
    elseif pair.p_value < 0.05 then
        assert.equal(pair.significance_level, 'p<0.05')
    else
        assert.is_nil(pair.significance_level)
    end

    assert.equal(pair.significant, pair.p_value < 0.05)
end

-- Test error handling for empty samples list
function testcase.empty_samples_error()
    local ok, err = pcall(welch_t_test, {})

    assert(not ok, 'Should error with empty samples list')
    assert.is_string(err)
end

-- Test graph traversal with distinct clusters
function testcase.graph_traversal_completeness()
    local samples = {
        create_samples('group1a', generate_times(10, 50, 10000)),
        create_samples('group1b', generate_times(10.05, 50, 10000)),
        create_samples('group2a', generate_times(20, 50, 10000)),
        create_samples('group2b', generate_times(20.05, 50, 10000)),
    }

    local result = welch_t_test(samples)

    assert.is_table(result.groups)

    local expected_names = {
        'group1a',
        'group1b',
        'group2a',
        'group2b',
    }
    local found_names = {}

    for _, group in ipairs(result.groups) do
        for _, name in ipairs(group.names) do
            found_names[name] = true
        end
    end

    -- All samples should be found in groups
    for _, name in ipairs(expected_names) do
        assert(found_names[name], 'Sample ' .. name .. ' should be in groups')
    end
end

-- Test stack traversal with gradient samples
function testcase.stack_traversal_behavior()
    local samples = {}

    for i = 1, 5 do
        local base_time = 10 + i * 0.5
        samples[i] = create_samples('sample' .. i,
                                    generate_times(base_time, 30, 10000))
    end

    local result = welch_t_test(samples)

    assert.is_table(result.groups)

    local total_members = 0
    for _, group in ipairs(result.groups) do
        total_members = total_members + #group.members
        assert.is_number(group.rank)
        assert(group.rank >= 1)
        assert.is_table(group.members)
        assert.is_table(group.names)
        assert.equal(#group.members, #group.names)
    end

    assert.equal(total_members, 5)
end
