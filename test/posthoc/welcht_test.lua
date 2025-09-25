require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new

-- Test configuration constants
local STATISTICAL_PRECISION = 1e-4 -- 0.01% relative error tolerance
local UNDERFLOW_LIMIT = 1e-50 -- Threshold for numerical underflow
local TINY_P_VALUE = 1e-10 -- Consider p-values below this as "tiny"
local SIGNIFICANCE_LEVEL = 0.001 -- Alpha level for significance testing

-- Helper: Create samples from timing data arrays
local function create_samples(timing_arrays)
    local samples = {}
    for i, timings in ipairs(timing_arrays) do
        local sample_config = {
            name = "group_" .. i,
            time_ns = {},
            before_kb = {},
            after_kb = {},
            allocated_kb = {},
            capacity = #timings,
            count = #timings,
            gc_step = 0,
            base_kb = 1,
            cl = 95.0,
            rciw = 5.0,
        }

        for j, timing in ipairs(timings) do
            sample_config.time_ns[j] = math.floor(timing)
            sample_config.before_kb[j] = 0
            sample_config.after_kb[j] = 0
            sample_config.allocated_kb[j] = 0
        end

        samples[i] = new_samples(sample_config)
    end
    return samples
end

-- Helper: Create minimal sample for error testing
local function create_test_sample(name, timing_values)
    local config = {
        name = name,
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = #timing_values,
        count = #timing_values,
        gc_step = 0,
        base_kb = 1,
        cl = 95.0,
        rciw = 5.0,
    }

    for i, value in ipairs(timing_values) do
        config.time_ns[i] = value
        config.before_kb[i] = 0
        config.after_kb[i] = 0
        config.allocated_kb[i] = 0
    end

    return new_samples(config)
end

-- Helper: Validate p-value with appropriate precision handling
local function assert_p_value_matches(actual, expected, comparison_name)
    if expected < UNDERFLOW_LIMIT then
        assert(actual < TINY_P_VALUE, string.format(
                   "%s: p-value should be tiny, got %.15e", comparison_name,
                   actual))
    else
        local relative_error = math.abs(actual - expected) / expected
        assert(relative_error < STATISTICAL_PRECISION, string.format(
                   "%s: p-value mismatch (rel_error: %.2e)\n  got: %.15e\n  expected: %.15e",
                   comparison_name, relative_error, actual, expected))
    end
end

-- Helper: Validate result has correct structure and ranges
local function assert_valid_result_structure(result)
    assert.is_table(result, "Result should be a table")
    assert.is_table(result.pair, "Result.pair should be a table")
    assert.equal(#result.pair, 2, "Result.pair should contain exactly 2 samples")
    assert.is_userdata(result.pair[1], "First sample should be userdata")
    assert.is_userdata(result.pair[2], "Second sample should be userdata")
    assert.is_number(result.p_value, "p_value should be a number")
    assert.is_number(result.p_adjusted, "p_adjusted should be a number")

    assert(result.p_value >= 0 and result.p_value <= 1,
           "p_value must be in [0,1]")
    assert(result.p_adjusted >= 0 and result.p_adjusted <= 1,
           "p_adjusted must be in [0,1]")
    assert(result.p_adjusted >= result.p_value, "p_adjusted must be >= p_value")
end

-- Helper: Generate synthetic timing data with controlled variance
local function generate_synthetic_timings(base_nanoseconds, variance_range,
                                          sample_size)
    local timings = {}
    local half_size = sample_size / 2
    for i = 1, sample_size do
        timings[i] = base_nanoseconds + (i - half_size) * variance_range
    end
    return timings
end

-- Test: Three-group comparison with R statistical software reference values
function testcase.r_reference_three_groups()
    -- These values were calculated using R's t.test() function with Holm correction
    local reference_data = {
        -- Group 1: ~10ms timings
        {
            10047621,
            10491343,
            9808641,
            10180902,
            10059669,
            10451847,
            10294296,
            9530767,
            9728044,
            9755471,
            10115021,
            10024849,
            9884274,
            9974321,
            10010456,
            10305429,
            10187653,
            9901235,
            9842157,
            10123489,
            10089765,
            9956234,
            10234567,
            10012345,
            9987654,
            10145678,
            9876543,
            10098765,
            10054321,
            10001234,
        },
        -- Group 2: ~25ms timings
        {
            24891234,
            25123456,
            24567890,
            24789012,
            25012345,
            24678901,
            24890123,
            25234567,
            24456789,
            24987654,
            24765432,
            25098765,
            24543210,
            24876543,
            25123450,
            24654321,
            24987650,
            24321098,
            24789123,
            25012340,
            24567891,
            24890124,
            25234568,
            24456780,
            24987655,
            24765433,
            25098766,
            24543211,
            24876544,
            25123451,
        },
        -- Group 3: ~50ms timings
        {
            50123456,
            51234567,
            49876543,
            50987654,
            51098765,
            50234567,
            50876543,
            51234560,
            49765432,
            50456789,
            50789012,
            51012345,
            50345678,
            50678901,
            51123456,
            50456780,
            50789013,
            51012346,
            50345679,
            50678902,
            51123457,
            50234568,
            50876544,
            51234561,
            49765433,
            50456790,
            50789014,
            51012347,
            50345670,
            50678903,
        },
    }

    local expected_raw_p = {
        2.300745325833069e-87,
        2.199067084798957e-78,
        4.495178516935868e-76,
    }
    local expected_holm_p = {
        6.902235977499208e-87,
        4.398134169597914e-78,
        4.495178516935868e-76,
    }

    local samples = create_samples(reference_data)
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    assert.equal(#results, 3, "Should have 3 pairwise comparisons for 3 groups")

    local comparison_names = {
        "Group1_vs_Group2",
        "Group1_vs_Group3",
        "Group2_vs_Group3",
    }
    for i, result in ipairs(results) do
        assert_valid_result_structure(result)
        assert_p_value_matches(result.p_value, expected_raw_p[i],
                               comparison_names[i] .. "_raw")
        assert_p_value_matches(result.p_adjusted, expected_holm_p[i],
                               comparison_names[i] .. "_holm")
    end
end

-- Test: Two-group exact precision validation
function testcase.two_groups_precision_check()
    local group_a_timings = {
        15000000,
        15001000,
        15002000,
        14999000,
        15000500,
        15001500,
        14998500,
        15002500,
        14999500,
        15000250,
    }
    local group_b_timings = {
        15010000,
        15011000,
        15012000,
        15009000,
        15010500,
        15011500,
        15008500,
        15012500,
        15009500,
        15010250,
    }

    local r_calculated_p_value = 1.172421738534126e-12

    local samples = create_samples({
        group_a_timings,
        group_b_timings,
    })
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    assert.equal(#results, 1, "Should have exactly 1 comparison for 2 groups")
    local result = results[1]

    assert_valid_result_structure(result)
    assert_p_value_matches(result.p_value, r_calculated_p_value,
                           "TwoGroups_precision")
    assert.equal(result.p_adjusted, result.p_value,
                 "Single comparison needs no Holm adjustment")
end

-- Test: Basic result structure for multiple groups
function testcase.result_structure_validation()
    local test_groups = {
        generate_synthetic_timings(5000000, 10000, 25), -- 5ms ± variance
        generate_synthetic_timings(5100000, 10000, 25), -- 5.1ms ± variance
        generate_synthetic_timings(20000000, 20000, 25), -- 20ms ± variance
        generate_synthetic_timings(20200000, 20000, 25), -- 20.2ms ± variance
    }

    local samples = create_samples(test_groups)
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    assert.equal(#results, 6, "Should have C(4,2) = 6 pairwise comparisons")

    for _, result in ipairs(results) do
        assert_valid_result_structure(result)
    end
end

-- Test: Holm correction monotonicity property
function testcase.holm_monotonicity_check()
    local test_groups = {
        generate_synthetic_timings(5000000, 10000, 25),
        generate_synthetic_timings(5100000, 10000, 25),
        generate_synthetic_timings(20000000, 20000, 25),
        generate_synthetic_timings(20200000, 20000, 25),
    }

    local samples = create_samples(test_groups)
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    -- Sort results by raw p-value for monotonicity check
    local sorted_by_p = {}
    for i, result in ipairs(results) do
        sorted_by_p[i] = {
            p_value = result.p_value,
            p_adjusted = result.p_adjusted,
        }
    end
    table.sort(sorted_by_p, function(a, b)
        return a.p_value < b.p_value
    end)

    -- Verify Holm correction maintains monotonicity
    for i = 2, #sorted_by_p do
        assert(sorted_by_p[i].p_adjusted >= sorted_by_p[i - 1].p_adjusted,
               string.format("Holm monotonicity violated at position %d", i))
    end
end

-- Test: Significant differences detection
function testcase.significance_detection()
    local fast_group = generate_synthetic_timings(5000000, 5000, 20) -- 5ms, low variance
    local slow_group = generate_synthetic_timings(25000000, 10000, 20) -- 25ms, higher variance

    local samples = create_samples({
        fast_group,
        slow_group,
    })
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    assert.equal(#results, 1, "Should have 1 comparison")
    assert(results[1].p_value < SIGNIFICANCE_LEVEL,
           "Large difference should be statistically significant")
end

-- Test: Minimum viable sample sizes
function testcase.minimum_sample_sizes()
    local tiny_group1 = {
        10000000,
        10100000,
    } -- Just 2 samples
    local tiny_group2 = {
        20000000,
        20100000,
    } -- Just 2 samples

    local samples = create_samples({
        tiny_group1,
        tiny_group2,
    })
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    assert.equal(#results, 1, "Should handle minimum sample size")
    assert_valid_result_structure(results[1])
end

-- Test: Invalid input rejection
function testcase.invalid_input_handling()
    local welcht = require('measure.posthoc.welcht')

    assert.throws(function()
        welcht("invalid_string")
    end, "Should reject string input")
    assert.throws(function()
        welcht({})
    end, "Should reject empty table")
end

-- Test: Insufficient sample count rejection
function testcase.insufficient_samples_handling()
    local welcht = require('measure.posthoc.welcht')
    local single_sample = create_test_sample("lonely", {
        1000,
        2000,
    })

    assert.throws(function()
        welcht({
            single_sample,
        })
    end, "Should reject single sample")
end

-- Test: Insufficient data points rejection
function testcase.insufficient_data_points_handling()
    local welcht = require('measure.posthoc.welcht')
    local undersized_sample = create_test_sample("tiny", {
        1000,
    }) -- Only 1 data point
    local normal_sample = create_test_sample("normal", {
        2000,
        3000,
    })

    assert.throws(function()
        welcht({
            undersized_sample,
            normal_sample,
        })
    end, "Should reject samples with insufficient data points")
end

-- Test: Holm correction formula accuracy
function testcase.holm_formula_accuracy()
    local test_groups = {
        generate_synthetic_timings(10000000, 1000, 30), -- Similar base times
        generate_synthetic_timings(10050000, 1000, 30), -- Small difference
        generate_synthetic_timings(20000000, 1000, 30), -- Large difference
    }

    local samples = create_samples(test_groups)
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    -- Verify Holm formula: p_adj[i] = min(1, p[i] * (m - i + 1)) with monotonicity
    local sorted_results = {}
    for i, result in ipairs(results) do
        sorted_results[i] = {
            p_value = result.p_value,
            p_adjusted = result.p_adjusted,
        }
    end
    table.sort(sorted_results, function(a, b)
        return a.p_value < b.p_value
    end)

    local num_comparisons = #sorted_results
    for i = 1, num_comparisons do
        local raw_holm = sorted_results[i].p_value * (num_comparisons - i + 1)
        local expected_adjusted = math.min(1.0, raw_holm)

        -- Account for monotonicity constraint
        if i > 1 then
            expected_adjusted = math.max(expected_adjusted,
                                         sorted_results[i - 1].p_adjusted)
        end

        local formula_error = math.abs(sorted_results[i].p_adjusted -
                                           expected_adjusted)
        assert(formula_error < 1e-12, string.format(
                   "Holm formula error at rank %d: error = %.2e", i,
                   formula_error))
    end
end

-- Test: Extreme variance differences
function testcase.extreme_variance_handling()
    local low_variance_group = {}
    local high_variance_group = {}

    -- Create groups with very different variances
    for i = 1, 20 do
        low_variance_group[i] = 10000000 + (i % 2) * 100 -- Tiny variance
        high_variance_group[i] = 10000000 + (i - 10) * 100000 -- Large variance
    end

    local samples = create_samples({
        low_variance_group,
        high_variance_group,
    })
    local welcht = require('measure.posthoc.welcht')
    local results = welcht(samples)

    assert.equal(#results, 1, "Should handle extreme variance differences")
    assert_valid_result_structure(results[1])
end
