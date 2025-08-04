local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples')
local welch_anova = require('measure.welch_anova')

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

-- Helper for basic result validation (used only for tests without precise values)
local function assert_basic_result(result, expected_df1)
    assert.match(tostring(result), '^measure.welch_anova: ', false)
    assert.is_number(result:fstat())
    assert.is_number(result:df1())
    assert.is_number(result:df2())
    assert.is_number(result:pvalue())
    assert.equal(result:df1(), expected_df1)
    assert.is_true(result:fstat() >= 0)
    assert.is_true(result:df2() > 0)
    assert.is_true(result:pvalue() >= 0.0 and result:pvalue() <= 1.0)
end

-- Helper for R precision comparison
local function assert_r_precision(result, expected_f, expected_df1,
                                  expected_df2, expected_p)
    assert.is_true(math.abs(result:fstat() - expected_f) < 1e-11,
                   string.format(
                       "F-statistic mismatch: expected %.15f, got %.15f",
                       expected_f, result:fstat()))
    assert.is_true(math.abs(result:df1() - expected_df1) < 1e-12,
                   string.format("df1 mismatch: expected %.15f, got %.15f",
                                 expected_df1, result:df1()))
    assert.is_true(math.abs(result:df2() - expected_df2) < 1e-11,
                   string.format("df2 mismatch: expected %.15f, got %.15f",
                                 expected_df2, result:df2()))

    -- Handle p-value comparison, accounting for underflow to 0
    if expected_p == 0.0 then
        assert.is_true(result:pvalue() == 0.0,
                       string.format(
                           "p-value mismatch: expected %.15e, got %.15e",
                           expected_p, result:pvalue()))
    else
        assert.is_true(math.abs(result:pvalue() - expected_p) / expected_p <
                           1e-9,
                       string.format(
                           "p-value mismatch: expected %.15e, got %.15e",
                           expected_p, result:pvalue()))
    end
end

-- =============================================================================
-- BASIC FUNCTIONALITY TESTS
-- =============================================================================

function testcase.basic_two_groups()
    local group1 = create_samples({
        100,
        105,
        98,
        102,
        99,
    }, "group1")
    local group2 = create_samples({
        110,
        115,
        108,
        112,
        109,
    }, "group2")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 32.467532467532465, 1.000000000000000,
                       8.000000000000000, 4.554140448179725e-04)
end

function testcase.basic_three_groups()
    local group1 = create_samples({
        100,
        105,
        98,
        102,
        99,
    }, "group1")
    local group2 = create_samples({
        110,
        115,
        108,
        112,
        109,
    }, "group2")
    local group3 = create_samples({
        120,
        125,
        118,
        122,
        119,
    }, "group3")

    local result = welch_anova({
        group1,
        group2,
        group3,
    })
    assert_r_precision(result, 59.940059940059939, 2.000000000000000,
                       8.000000000000000, 1.531608645193609e-05)
end

function testcase.metatable_protection()
    local group1 = create_samples({
        100,
        105,
        98,
        102,
    }, "group1")
    local group2 = create_samples({
        110,
        115,
        108,
        112,
    }, "group2")

    local result = welch_anova({
        group1,
        group2,
    })
    assert.equal(getmetatable(result), "metatable is protected")
end

-- =============================================================================
-- ERROR HANDLING TESTS
-- =============================================================================

function testcase.error_cases()
    -- Non-table input
    assert.throws(function()
        welch_anova("not a table")
    end)

    -- Empty table
    assert.throws(function()
        welch_anova({})
    end)

    -- Only one group
    local group1 = create_samples({
        100,
        105,
        98,
    }, "group1")
    assert.throws(function()
        welch_anova({
            group1,
        })
    end)

    -- Group with insufficient samples
    local small_group = create_samples({
        100,
    }, "small")
    local normal_group = create_samples({
        110,
        115,
        108,
    }, "normal")
    assert.throws(function()
        welch_anova({
            small_group,
            normal_group,
        })
    end)

    -- Zero variance group
    local zero_var_group = create_samples({
        100,
        100,
        100,
        100,
    }, "zero_var")
    assert.throws(function()
        welch_anova({
            zero_var_group,
            normal_group,
        })
    end)
end

-- =============================================================================
-- R VERIFICATION TESTS (Realistic benchmark scenarios)
-- =============================================================================

function testcase.algorithm_performance_comparison()
    local group1 = create_samples({
        1529276,
        1535473,
        1494535,
        1477325,
        1530294,
        1409102,
        1531505,
        1486191,
    }, "algorithm_a")
    local group2 = create_samples({
        2165901,
        2089681,
        2186050,
        2418077,
        2244475,
        2262426,
    }, "algorithm_b")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 229.755400027926811, 1.000000000000000,
                       6.126605301779406, 4.347039966206107e-06)
end

function testcase.memory_allocation_performance()
    local group1 = create_samples({
        845527,
        826799,
        830399,
        808735,
        839798,
    }, "consistent_allocator")
    local group2 = create_samples({
        862358,
        814621,
        1151284,
        1061628,
        964398,
        872939,
        1051131,
    }, "variable_allocator")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 8.458117071524750, 1.000000000000000,
                       6.215513340734844, 2.596919281634369e-02)
end

function testcase.compiler_optimization_levels()
    local group1 = create_samples({
        3270856,
        3157535,
        3194623,
        3146239,
    }, "opt_o0")
    local group2 = create_samples({
        1892841,
        1801795,
        1648216,
        1780491,
        1708773,
    }, "opt_o1")
    local group3 = create_samples({
        1167175,
        1170606,
        1194952,
    }, "opt_o2")

    local result = welch_anova({
        group1,
        group2,
        group3,
    })
    assert_r_precision(result, 2110.069117348226882, 2.000000000000000,
                       5.148248971185849, 3.151339021468997e-08)
end

-- =============================================================================
-- STATISTICAL BEHAVIOR TESTS
-- =============================================================================

function testcase.identical_groups()
    local group1 = create_samples({
        100,
        100.1,
        99.9,
        100.05,
        99.95,
    }, "group1")
    local group2 = create_samples({
        100,
        100.1,
        99.9,
        100.05,
        99.95,
    }, "group2")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 0.000000000000000, 1.000000000000000,
                       8.000000000000000, 1.000000000000000e+00)
end

function testcase.extreme_group_differences()
    local group1 = create_samples({
        10,
        12,
        9,
        11,
        10,
    }, "group1")
    local group2 = create_samples({
        1000,
        1020,
        990,
        1010,
        1000,
    }, "group2")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 37594.857578065464622, 1.000000000000000,
                       4.079992000799920, 3.038558404888647e-09)
end

function testcase.unequal_sample_sizes()
    local small_group = create_samples({
        5,
        6,
    }, "small")
    local large_values = {}
    for i = 1, 50 do
        large_values[i] = 10 + math.random() * 2
    end
    local large_group = create_samples(large_values, "large")

    local result = welch_anova({
        small_group,
        large_group,
    })
    assert_basic_result(result, 1.0)
end

function testcase.multiple_groups()
    local group1 = create_samples({
        100,
        102,
        99,
        101,
        98,
    }, "group1")
    local group2 = create_samples({
        105,
        107,
        104,
        106,
        103,
    }, "group2")
    local group3 = create_samples({
        110,
        112,
        109,
        111,
        108,
    }, "group3")
    local group4 = create_samples({
        115,
        117,
        114,
        116,
        113,
    }, "group4")
    local group5 = create_samples({
        120,
        122,
        119,
        121,
        118,
    }, "group5")

    local result = welch_anova({
        group1,
        group2,
        group3,
        group4,
        group5,
    })
    assert_r_precision(result, 104.166666666666671, 4.000000000000000,
                       9.999999999999998, 4.160460775892724e-08)
end

-- =============================================================================
-- EDGE CASE TESTS
-- =============================================================================

function testcase.small_variances()
    local group1 = create_samples({
        100,
        101,
        102,
        103,
    }, "group1")
    local group2 = create_samples({
        110,
        111,
        112,
        113,
    }, "group2")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 120.000000000000000, 1.000000000000000,
                       6.000000000000000, 3.436402807610595e-05)
end

function testcase.extreme_sample_size_difference()
    local small_group = create_samples({
        5.0,
        6.0,
    }, "n2_group")
    local large_values = {}
    for i = 1, 1000 do
        large_values[i] = 10.0 + (i % 100) * 0.1
    end
    local large_group = create_samples(large_values, "n1000_group")

    local result = welch_anova({
        small_group,
        large_group,
    })
    assert_basic_result(result, 1.0)
    assert.is_true(result:df2() > 1.0 and result:df2() < 10.0)
end

function testcase.extreme_variance_ratios()
    local group1 = create_samples({
        100,
        101,
        100,
        101,
    }, "low_var")
    local group2 = create_samples({
        50.0,
        150.0,
        75.0,
        125.0,
    }, "high_var")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 0.000479923212286, 1.000000000000000,
                       3.000959999975424, 9.838972482847075e-01)
end

function testcase.minimal_sample_size()
    local group1 = create_samples({
        1.0,
        2.0,
    }, "boundary1")
    local group2 = create_samples({
        1000.0,
        1001.0,
    }, "boundary2")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 1996002.000000000000000, 1.000000000000000,
                       2.000000000000000, 5.010011254746871e-07)
end

function testcase.p_value_underflow()
    local group1 = create_samples({
        1.0,
        1.1,
        0.9,
        1.05,
        0.95,
    }, "small_vals")
    local group2 = create_samples({
        1000.0,
        1001.0,
        999.0,
        1000.5,
        999.5,
    }, "large_vals")

    local result = welch_anova({
        group1,
        group2,
    })
    assert_r_precision(result, 4992003.200000056996942, 1.000000000000000,
                       6.896551724137963, 0.000000000000000e+00)
end

-- =============================================================================
-- STRESS TESTS
-- =============================================================================

function testcase.large_sample_sizes()
    local values1, values2 = {}, {}
    for i = 1, 1000 do
        values1[i] = 100 + math.random() * 10
        values2[i] = 110 + math.random() * 10
    end

    local group1 = create_samples(values1, "large1")
    local group2 = create_samples(values2, "large2")
    local result = welch_anova({
        group1,
        group2,
    })

    assert_basic_result(result, 1.0)
    assert.is_true(result:df2() > 100)
end

function testcase.numerical_stability()
    local group1 = create_samples({
        100.0,
        101.0,
        102.0,
        103.0,
    }, "stable1")
    local group2 = create_samples({
        105.0,
        106.0,
        107.0,
        108.0,
    }, "stable2")
    local group3 = create_samples({
        110.0,
        111.0,
        112.0,
        113.0,
    }, "stable3")

    local result = welch_anova({
        group1,
        group2,
        group3,
    })
    assert_r_precision(result, 54.000000000000000, 2.000000000000000,
                       6.000000000000000, 1.457938474996867e-04)
end
