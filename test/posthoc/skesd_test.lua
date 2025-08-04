local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples')
local scott_knott_esd = require('measure.posthoc.skesd')

-- Helper function to create samples with specific values
local function create_samples(values, name)
    local data = {
        name = name or "default",
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = #values,
        count = #values,
        gc_step = 0,
        base_kb = 1,
        cl = 95.0,
        rciw = 5.0,
    }

    for i, value in ipairs(values) do
        data.time_ns[i] = math.floor(value)
        data.before_kb[i] = 0
        data.after_kb[i] = 0
        data.allocated_kb[i] = 0
    end

    return new_samples(data)
end

-- Helper to validate basic result structure
local function assert_basic_result_structure(result, expected_num_clusters)
    assert.is_table(result)

    if expected_num_clusters then
        assert.equal(#result, expected_num_clusters)
    end

    for _, cluster_entry in ipairs(result) do
        assert.is_table(cluster_entry)
        assert.is_number(cluster_entry.id)
        assert.is_table(cluster_entry.samples)
        assert.is_number(cluster_entry.cohen_d)
        assert.is_true(cluster_entry.cohen_d >= 0)
        assert.is_true(#cluster_entry.samples > 0)

        -- Check cluster statistics fields
        assert.is_number(cluster_entry.mean)
        assert.is_number(cluster_entry.variance)
        assert.is_number(cluster_entry.count)
        assert.is_true(cluster_entry.count > 0)

        for _, sample in ipairs(cluster_entry.samples) do
            assert.is_userdata(sample)
        end

        if #result > 1 then
            assert.is_number(cluster_entry.max_contrast_with)
        else
            assert.is_nil(cluster_entry.max_contrast_with)
        end
    end
end

-- =============================================================================
-- BASIC FUNCTIONALITY TESTS WITH SIMPLE API
-- =============================================================================

function testcase.two_algorithms_large_effect_separation()
    -- Test Case 1: Algorithm Performance Comparison (Large effect size)
    local algorithm_a = create_samples({
        1634105,
        1486097,
        1557042,
        1577667,
        1560188,
        1521161,
        1644853,
        1522038,
    }, "algorithm_a")

    local algorithm_b = create_samples({
        2515637,
        2155034,
        2391998,
        2562113,
        1925250,
        2117595,
    }, "algorithm_b")

    local result = scott_knott_esd({
        algorithm_a,
        algorithm_b,
    })

    assert_basic_result_structure(result, 2)

    -- Check that samples are correctly assigned
    assert.equal(#result[1].samples, 1) -- One sample in first cluster
    assert.equal(#result[2].samples, 1) -- One sample in second cluster

    -- Check that effect size is calculated
    assert.is_true(result[1].cohen_d > 2.0 or result[2].cohen_d > 2.0) -- Large effect
end

function testcase.similar_allocators_should_merge()
    -- Test Case: Memory Allocation Strategies (Very small effect)
    local consistent_allocator = create_samples({
        839001,
        800803,
        857198,
        829293,
        857080,
    }, "consistent")

    local variable_allocator = create_samples({
        935297,
        969474,
        799344,
        914612,
        684677,
        781180,
        774304,
    }, "variable")

    local result = scott_knott_esd({
        consistent_allocator,
        variable_allocator,
    })

    assert_basic_result_structure(result, 1)

    -- Check that both samples are in the same cluster
    assert.equal(#result[1].samples, 2) -- Both samples in one cluster
end

function testcase.compiler_optimizations_three_groups()
    -- Test Case: Compiler Optimization Levels (All large effects)
    local opt_o0 = create_samples({
        3244692,
        3395662,
        3215071,
        2749523,
    }, "opt_o0")

    local opt_o1 = create_samples({
        1569482,
        2067755,
        1852212,
        1656820,
        1870062,
    }, "opt_o1")

    local opt_o2 = create_samples({
        1223885,
        1255656,
        1147078,
    }, "opt_o2")

    local result = scott_knott_esd({
        opt_o0,
        opt_o1,
        opt_o2,
    })

    assert_basic_result_structure(result, 3)

    -- Check that each cluster has one sample
    for i = 1, 3 do
        assert.equal(#result[i].samples, 1)
        assert.is_number(result[i].max_contrast_with) -- Should have comparison clusters
    end
end

function testcase.api_usage_and_sample_access()
    -- Realistic benchmark scenario
    local algorithm_a = create_samples({
        1529276,
        1535473,
        1494535,
        1477325,
        1530294,
        1409102,
        1531505,
        1486191,
    }, "algorithm_a")

    local algorithm_b = create_samples({
        2165901,
        2089681,
        2186050,
        2418077,
        2244475,
        2262426,
    }, "algorithm_b")

    local algorithm_c = create_samples({
        845527,
        826799,
        830399,
        808735,
        839798,
    }, "algorithm_c")

    local result = scott_knott_esd({
        algorithm_a,
        algorithm_b,
        algorithm_c,
    })

    assert_basic_result_structure(result)

    -- Verify practical usage pattern
    for _, cluster_entry in ipairs(result) do
        assert.is_true(#cluster_entry.samples > 0)

        -- Can access sample properties
        for _, sample in ipairs(cluster_entry.samples) do
            assert.is_string(sample:name())
            assert.is_number(sample:mean())
        end
    end
end

function testcase.sample_identity_preservation()
    -- Test that original samples are preserved in clusters
    local sample1 = create_samples({
        100,
        105,
        98,
    }, "test1")
    local sample2 = create_samples({
        200,
        205,
        195,
    }, "test2")

    local result = scott_knott_esd({
        sample1,
        sample2,
    })

    assert_basic_result_structure(result)

    -- Find which clusters contain which samples
    local found_sample1, found_sample2 = false, false

    for _, cluster_entry in ipairs(result) do
        for _, sample in ipairs(cluster_entry.samples) do
            if sample:name() == "test1" then
                found_sample1 = true
            elseif sample:name() == "test2" then
                found_sample2 = true
            end
        end
    end

    assert.is_true(found_sample1)
    assert.is_true(found_sample2)
end

function testcase.input_validation_errors()
    -- Non-table input
    assert.throws(function()
        scott_knott_esd("not a table")
    end)

    -- Empty table
    assert.throws(function()
        scott_knott_esd({})
    end)

    -- Only one cluster
    local single_cluster = create_samples({
        100,
        105,
        98,
    }, "single")
    assert.throws(function()
        scott_knott_esd({
            single_cluster,
        })
    end)
end

-- =============================================================================
-- R REFERENCE DATA VALIDATION TESTS
-- Based on Scott-Knott results from R's ScottKnott package
-- These tests validate against precise reference values computed in R
-- =============================================================================

-- Helper for R precision comparison
local function assert_r_precision_cohens_d(actual_cohens_d, expected_cohens_d,
                                           test_name)
    local tolerance = math.max(1e-11, expected_cohens_d * 1e-12)
    local diff = math.abs(actual_cohens_d - expected_cohens_d)

    assert.is_true(diff < tolerance, string.format(
                       "%s - Cohen's d mismatch: expected %.15f, got %.15f, diff %.15e (tolerance %.15e)",
                       test_name, expected_cohens_d, actual_cohens_d, diff,
                       tolerance))
end

-- Helper to assert samples are in different clusters
local function assert_samples_in_different_clusters(result, sample_names)
    local cluster_assignments = {}
    for _, cluster in ipairs(result) do
        for _, sample in ipairs(cluster.samples) do
            cluster_assignments[sample:name()] = cluster.id
        end
    end

    for _, name in ipairs(sample_names) do
        assert.not_nil(cluster_assignments[name],
                       name .. " should be assigned to a cluster")
    end

    for i = 1, #sample_names - 1 do
        for j = i + 1, #sample_names do
            assert.not_equal(cluster_assignments[sample_names[i]],
                             cluster_assignments[sample_names[j]],
                             sample_names[i] .. " and " .. sample_names[j] ..
                                 " should be in different clusters")
        end
    end
end

-- Helper to validate against R reference results
local function assert_matches_r_reference(result, expected_clusters,
                                          expected_max_cohens_d, test_name)
    assert_basic_result_structure(result, expected_clusters)

    local max_cohens_d = 0
    for _, cluster in ipairs(result) do
        if cluster.cohen_d > max_cohens_d then
            max_cohens_d = cluster.cohen_d
        end
    end

    assert_r_precision_cohens_d(max_cohens_d, expected_max_cohens_d, test_name)
end

function testcase.r_reference_large_effect_separation()
    -- R Reference: Two Separated Clusters
    -- Expected Scott-Knott clusters: 2
    -- Expected max Cohen's d: 63.245553203367585
    local sample_a = create_samples({
        100,
        101,
        102,
        103,
        104,
    }, "A")
    local sample_b = create_samples({
        200,
        201,
        202,
        203,
        204,
    }, "B")

    local result = scott_knott_esd({
        sample_a,
        sample_b,
    })

    assert_matches_r_reference(result, 2, 63.245553203367585,
                               "Two Separated Clusters")

    assert_samples_in_different_clusters(result, {
        "A",
        "B",
    })

    -- Verify that compare fields correctly reference each other
    -- In a two-cluster result, each cluster should reference the other
    assert.equal(result[1].max_contrast_with, result[2].id,
                 "Cluster 1 should have max contrast with cluster 2")
    assert.equal(result[2].max_contrast_with, result[1].id,
                 "Cluster 2 should have max contrast with cluster 1")
end

function testcase.r_reference_three_distinct_clusters()
    -- R Reference: Three Ordered Clusters
    -- Expected Scott-Knott clusters: 3
    -- Expected max Cohen's d: 12.649110640673516
    local sample_low = create_samples({
        10,
        11,
        12,
        13,
        14,
    }, "Low")
    local sample_med = create_samples({
        20,
        21,
        22,
        23,
        24,
    }, "Med")
    local sample_high = create_samples({
        30,
        31,
        32,
        33,
        34,
    }, "High")

    local result = scott_knott_esd({
        sample_low,
        sample_med,
        sample_high,
    })

    assert_matches_r_reference(result, 3, 12.649110640673516,
                               "Three Ordered Clusters")

    assert_samples_in_different_clusters(result, {
        "Low",
        "Med",
        "High",
    })
end

function testcase.r_reference_small_effect_separation()
    -- R Reference: Similar Clusters (still separated by R's Scott-Knott)
    -- Expected Scott-Knott clusters: 2
    -- Expected max Cohen's d: 1.603567451474546
    local sample_sim1 = create_samples({
        100,
        101,
        102,
        103,
        104,
        105,
    }, "Similar1")
    local sample_sim2 = create_samples({
        103,
        104,
        105,
        106,
        107,
        108,
    }, "Similar2")

    local result = scott_knott_esd({
        sample_sim1,
        sample_sim2,
    })

    assert_matches_r_reference(result, 2, 1.603567451474546, "Similar Clusters")
end

function testcase.r_reference_benchmark_algorithms()
    -- R Reference: Realistic Benchmark
    -- Expected Scott-Knott clusters: 3
    -- Expected max Cohen's d: 17.833257955308326
    local sample_algo_a = create_samples({
        1529276,
        1535473,
        1494535,
        1477325,
        1530294,
        1409102,
    }, "AlgoA")
    local sample_algo_b = create_samples({
        2165901,
        2089681,
        2186050,
        2418077,
        2244475,
        2262426,
    }, "AlgoB")
    local sample_algo_c = create_samples({
        845527,
        826799,
        830399,
        808735,
        839798,
    }, "AlgoC")

    local result = scott_knott_esd({
        sample_algo_a,
        sample_algo_b,
        sample_algo_c,
    })

    assert_matches_r_reference(result, 3, 17.833257955308326,
                               "Realistic Benchmark")

    assert_samples_in_different_clusters(result, {
        "AlgoA",
        "AlgoB",
        "AlgoC",
    })
end

