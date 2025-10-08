require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new
local scott_knott_esd = require('measure.compare.skesd')

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

function testcase.basic_two_samples()
    local sample1 = create_samples('fast', generate_times(10, 50, 500000))
    local sample2 = create_samples('slow', generate_times(20, 50, 500000))

    local result = scott_knott_esd({
        sample1,
        sample2,
    })

    assert.is_table(result)
    assert.is_string(result.name)
    assert.is_string(result.algorithm)
    assert.is_string(result.description)
    assert.is_string(result.clustering)
    assert.is_table(result.pairs)
    assert.is_table(result.groups)
    assert.equal(result.name,
                 "Scott-Knott ESD (Effect Size Difference) clustering")
    assert.equal(result.algorithm, 'scott-knott-esd')
    assert.match(result.description, 'multiple comparison problem')
    assert.match(result.clustering, 'hierarchical clustering')

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
    assert.equal(pair.p_value, pair.p_adjusted)
    assert.equal(pair.significant, true)
    assert.is_string(pair.significance_level)
    assert(pair.p_value <= 0.1)
    assert(pair.p_value >= 0)
end

function testcase.three_samples_multiple_comparisons()
    local samples = {
        create_samples('fast', generate_times(10, 30, 500000)),
        create_samples('medium', generate_times(15, 30, 500000)),
        create_samples('slow', generate_times(20, 30, 500000)),
    }

    local result = scott_knott_esd(samples)

    assert.is_table(result.pairs)
    assert.is_table(result.groups)
    for _, pair in ipairs(result.pairs) do
        assert.is_string(pair.name1)
        assert.is_string(pair.name2)
        assert.is_number(pair.p_value)
        assert.is_boolean(pair.significant)
        assert.equal(pair.significant, true)
        assert(pair.p_value <= 0.1)
        assert(pair.p_value >= 0)
        assert.is_string(pair.significance_level)
    end
end

function testcase.group_structure_and_ranking()
    local samples = {
        create_samples('sample1', generate_times(10, 50, 500000)),
        create_samples('sample2', generate_times(15, 50, 500000)),
        create_samples('sample3', generate_times(20, 50, 500000)),
    }

    local result = scott_knott_esd(samples)

    -- Verify group structure
    assert.is_table(result.groups)
    assert(#result.groups >= 1)

    for _, group in ipairs(result.groups) do
        assert.is_number(group.rank)
        assert.is_table(group.names)
        assert.is_number(group.mean)
        assert.is_number(group.cohen_d)
        assert(#group.names >= 1)

        -- Verify rank is positive
        assert(group.rank >= 1)
    end
end

function testcase.low_mean_edge_case()
    local low_sample = create_samples('low', generate_times(1, 20, 100000))
    local normal_sample = create_samples('normal',
                                         generate_times(10, 20, 500000))

    local result = scott_knott_esd({
        low_sample,
        normal_sample,
    })

    assert.is_table(result.pairs)
    assert(#result.pairs >= 1)

    local pair = result.pairs[1]

    -- Verify calculations are correct even with low values
    assert.is_number(pair.speedup)
    assert.is_number(pair.difference)
    assert.is_number(pair.relative_difference)
    assert.is_boolean(pair.significant)
end

function testcase.distinct_performance_groups()
    local samples = {
        create_samples('very_fast', generate_times(5, 50, 500000)),
        create_samples('fast', generate_times(10, 50, 500000)),
        create_samples('medium', generate_times(20, 50, 500000)),
        create_samples('slow', generate_times(40, 50, 500000)),
    }

    local result = scott_knott_esd(samples)

    -- Verify group structure
    assert.is_table(result.groups)
    assert(#result.groups >= 1)

    -- Collect all sample names from groups
    local found_names = {}
    for _, group in ipairs(result.groups) do
        for _, name in ipairs(group.names) do
            found_names[name] = true
        end
    end

    -- Verify all samples are present in groups
    local expected_names = {
        'very_fast',
        'fast',
        'medium',
        'slow',
    }
    for _, name in ipairs(expected_names) do
        assert(found_names[name], 'Sample ' .. name .. ' should be in groups')
    end
end

function testcase.single_sample_error()
    local sample = create_samples('only_one', generate_times(10, 20, 500000))

    local ok, err = pcall(scott_knott_esd, {
        sample,
    })

    -- Scott-Knott ESD should handle single sample gracefully
    -- or produce meaningful error
    if not ok then
        assert.is_string(err)
    else
        -- If it succeeds, verify structure
        assert.is_table(err)
        assert.is_string(err.name)
        assert.is_string(err.algorithm)
        assert.is_string(err.description)
        assert.is_table(err.pairs)
        assert.is_table(err.groups)
    end
end

function testcase.single_cluster_no_comparisons()
    -- Create very similar samples that should cluster into one group
    local samples = {
        create_samples('similar1', generate_times(10, 30, 10000)),
        create_samples('similar2', generate_times(10.01, 30, 10000)),
        create_samples('similar3', generate_times(10.02, 30, 10000)),
    }

    local result = scott_knott_esd(samples)

    assert.is_table(result)
    assert.is_string(result.name)
    assert.is_string(result.algorithm)
    assert.is_string(result.description)
    assert.is_string(result.clustering)
    assert.is_table(result.pairs)
    assert.is_table(result.groups)

    -- If all samples are clustered into one group, no comparisons should exist
    if #result.groups == 1 then
        assert.equal(#result.pairs, 0)
    end
end

function testcase.performance_metrics_calculations()
    local fast_sample = create_samples('fast', generate_times(10, 30, 500000))
    local slow_sample = create_samples('slow', generate_times(20, 30, 500000)) -- 2x slower

    local result = scott_knott_esd({
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

function testcase.all_samples_in_groups()
    local samples = {}
    local sample_names = {
        'test1',
        'test2',
        'test3',
        'test4',
    }

    for i, name in ipairs(sample_names) do
        samples[i] =
            create_samples(name, generate_times(10 + i * 5, 20, 500000))
    end

    local result = scott_knott_esd(samples)

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

function testcase.empty_samples_error()
    local ok, err = pcall(scott_knott_esd, {})

    -- Should handle empty list gracefully or provide meaningful error
    if not ok then
        assert.is_string(err)
    else
        -- If it succeeds, should have valid structure
        assert.is_table(err)
    end
end

function testcase.scott_knott_esd_clustering()
    local samples = {
        create_samples('cluster1_a', generate_times(10, 30, 500000)),
        create_samples('cluster1_b', generate_times(10.2, 30, 500000)),
        create_samples('cluster2_a', generate_times(20, 30, 500000)),
        create_samples('cluster2_b', generate_times(20.2, 30, 500000)),
    }

    local result = scott_knott_esd(samples)

    assert.is_table(result.groups)
    assert.is_table(result.pairs)

    -- Verify method is Scott-Knott ESD
    assert.equal(result.algorithm, 'scott-knott-esd')
    assert.equal(result.name,
                 "Scott-Knott ESD (Effect Size Difference) clustering")

    -- All pairs should be significant in Scott-Knott ESD
    for _, pair in ipairs(result.pairs) do
        assert.equal(pair.significant, true)
        assert.is_number(pair.p_value)
        assert(pair.p_value <= 0.1)
        assert(pair.p_value >= 0)
        assert.is_string(pair.significance_level)
    end
end

function testcase.hierarchical_clustering_effect_size()
    local samples = {}

    -- Create samples with progressively different effect sizes
    for i = 1, 6 do
        local base_time = 5 + i * 3 -- 5ms, 8ms, 11ms, 14ms, 17ms, 20ms
        samples[i] = create_samples('sample' .. i,
                                    generate_times(base_time, 40, 500000))
    end

    local result = scott_knott_esd(samples)

    assert.is_table(result.groups)

    -- Verify groups have Cohen's d values
    for _, group in ipairs(result.groups) do
        assert.is_number(group.cohen_d)
        assert.is_number(group.mean)
        assert.is_number(group.rank)
        assert.is_table(group.names)
    end

    -- Verify all samples are clustered
    local total_samples_in_groups = 0
    for _, group in ipairs(result.groups) do
        total_samples_in_groups = total_samples_in_groups + #group.names
    end
    assert.equal(total_samples_in_groups, 6)
end

function testcase.ranking_order_consistency()
    local samples = {
        create_samples('slow_algo', generate_times(30, 30, 500000)),
        create_samples('fast_algo', generate_times(5, 30, 500000)),
        create_samples('medium_algo', generate_times(15, 30, 500000)),
        create_samples('slower_algo', generate_times(25, 30, 500000)),
    }

    local result = scott_knott_esd(samples)

    assert.is_table(result.groups)
    assert(#result.groups >= 1)
    local ranks = {}
    for _, group in ipairs(result.groups) do
        ranks[#ranks + 1] = group.rank
    end
    table.sort(ranks)

    for i, rank in ipairs(ranks) do
        assert.equal(rank, i, 'Ranks should be consecutive starting from 1')
    end

    for i = 1, #result.groups - 1 do
        local current_group = result.groups[i]
        local next_group = result.groups[i + 1]
        if current_group.rank < next_group.rank then
            assert(current_group.mean <= next_group.mean, string.format(
                       'Group with rank %d (mean=%.2f) should have lower mean than rank %d (mean=%.2f)',
                       current_group.rank, current_group.mean, next_group.rank,
                       next_group.mean))
        end
    end

    local rank1_group = nil
    local min_mean = math.huge
    for _, group in ipairs(result.groups) do
        if group.rank == 1 then
            rank1_group = group
        end
        min_mean = math.min(min_mean, group.mean)
    end

    assert(rank1_group, 'Should have a rank 1 group')
    assert.equal(rank1_group.mean, min_mean,
                 'Rank 1 group should have the lowest mean time')
end

function testcase.output_format_verification()
    local samples = {
        create_samples('baseline', generate_times(15, 25, 500000)),
        create_samples('optimized', generate_times(10, 25, 500000)),
    }

    local result = scott_knott_esd(samples)

    -- Verify top-level structure
    assert.is_table(result)
    assert.is_string(result.name)
    assert.is_string(result.algorithm)
    assert.is_string(result.description)
    assert.is_string(result.clustering)
    assert.is_table(result.pairs)
    assert.is_table(result.groups)

    -- Verify method details
    assert.equal(result.name,
                 "Scott-Knott ESD (Effect Size Difference) clustering")
    assert.equal(result.algorithm, 'scott-knott-esd')
    assert.match(result.description, 'multiple comparison problem')
    assert.match(result.clustering, 'hierarchical clustering')

    -- Verify pairs structure
    for _, pair in ipairs(result.pairs) do
        assert.is_string(pair.name1)
        assert.is_string(pair.name2)
        assert.is_number(pair.speedup)
        assert.is_number(pair.difference)
        assert.is_number(pair.relative_difference)
        assert.is_number(pair.p_value)
        assert.is_number(pair.p_adjusted)
        assert.is_boolean(pair.significant)
        assert.is_string(pair.significance_level)
    end

    -- Verify groups structure
    for _, group in ipairs(result.groups) do
        assert.is_table(group.names)
        assert.is_number(group.rank)
        assert.is_number(group.mean)
        assert.is_number(group.cohen_d)
    end
end
