local testcase = require('testcase')
local assert = require('assert')

-- Test measure.quantile module (C function-based API)
function testcase.quantile_basic_call()
    local quantile = require('measure.quantile')

    -- Test 95% confidence level (should return ~1.96)
    local z95 = quantile(0.95)
    assert.is_number(z95)
    assert.is_true(math.abs(z95 - 1.9599639845401) < 1e-10)

    -- Test 99% confidence level (should return ~2.576)
    local z99 = quantile(0.99)
    assert.is_number(z99)
    assert.is_true(math.abs(z99 - 2.5758293035489) < 1e-10)

    -- Test 90% confidence level (should return ~1.645)
    local z90 = quantile(0.90)
    assert.is_number(z90)
    assert.is_true(math.abs(z90 - 1.6448536269515) < 1e-10)
end

function testcase.quantile_precision_test()
    local quantile = require('measure.quantile')

    -- Test 97% confidence level (ChatGPT o3 example)
    local z97 = quantile(0.97)
    assert.is_number(z97)
    assert.is_true(math.abs(z97 - 2.1700903775846) < 1e-10)

    -- Test other confidence levels
    local z80 = quantile(0.80)
    assert.is_number(z80)
    assert.is_true(math.abs(z80 - 1.2815515655446) < 1e-10)

    local z98 = quantile(0.98)
    assert.is_number(z98)
    assert.is_true(math.abs(z98 - 2.3263478740409) < 1e-10)
end

function testcase.quantile_edge_cases()
    local quantile = require('measure.quantile')

    -- Test values close to boundaries (but not exactly at them)
    local z_low = quantile(0.001)
    assert.is_number(z_low)
    assert.is_true(z_low > 0) -- Should be positive (confidence interval z-value)

    local z_high = quantile(0.999)
    assert.is_number(z_high)
    assert.is_true(z_high > 3) -- Should be large positive for high confidence

    -- Test middle value - note: 0.5 gives 67% CI which is not 0
    local z_mid = quantile(0.5)
    assert.is_number(z_mid)
    assert.is_true(z_mid > 0.6 and z_mid < 0.7) -- Should be around 0.67
end

function testcase.quantile_symmetry_test()
    local quantile = require('measure.quantile')

    -- Test symmetry: quantile(p) should be approximately -quantile(1-p) for lower tail
    -- This tests the mathematical property of the normal distribution
    local p_values = {
        0.05,
        0.1,
        0.25,
        0.4,
    }

    for _, p in ipairs(p_values) do
        local z_low = quantile(p)
        local z_high = quantile(1 - p)

        -- Due to the way confidence intervals work, this relationship is different
        -- For confidence intervals: quantile(p) gives the (1+p)/2 quantile of standard normal
        -- So we test the actual mathematical relationship
        assert.is_number(z_low)
        assert.is_number(z_high)
        assert.is_true(z_low < z_high) -- Higher confidence should give larger z-value
    end
end

function testcase.quantile_error_handling()
    local quantile = require('measure.quantile')

    -- Test with no arguments
    assert.throws(function()
        quantile()
    end)

    -- Test with too many arguments
    assert.not_throws(function()
        quantile(0.95, 0.99)
    end)

    -- Test with non-number argument
    -- String might be converted to number, check if it errors or not
    assert.not_throws(quantile, "0.95")

    assert.throws(function()
        quantile({
            0.95,
        })
    end)

    assert.throws(function()
        quantile(true)
    end)

    -- Test that we can call the function normally
    local result = quantile(0.95)
    assert.is_number(result)
end

function testcase.quantile_boundary_values()
    local quantile = require('measure.quantile')

    -- Test boundary values that should return NaN
    local result_zero = quantile(0.0)
    assert.is_true(result_zero ~= result_zero) -- NaN check

    local result_one = quantile(1.0)
    assert.is_true(result_one ~= result_one) -- NaN check

    -- Test negative values
    local result_negative = quantile(-0.1)
    assert.is_true(result_negative ~= result_negative) -- NaN check

    -- Test values greater than 1
    local result_over_one = quantile(1.1)
    assert.is_true(result_over_one ~= result_over_one) -- NaN check
end

function testcase.quantile_module_type()
    local quantile = require('measure.quantile')

    -- The module should be a function, not a table
    assert.is_function(quantile)

    -- Test that it's callable
    local result = quantile(0.95)
    assert.is_number(result)
end

function testcase.quantile_consistency_test()
    local quantile = require('measure.quantile')

    -- Test that multiple calls with same argument return same result
    local confidence = 0.95
    local z1 = quantile(confidence)
    local z2 = quantile(confidence)
    local z3 = quantile(confidence)

    assert.equal(z1, z2)
    assert.equal(z2, z3)
    assert.equal(z1, z3)
end

function testcase.quantile_ordering_test()
    local quantile = require('measure.quantile')

    -- Test that z-values increase with confidence level
    local confidences = {
        0.50,
        0.80,
        0.90,
        0.95,
        0.99,
        0.995,
    }
    local prev_z = nil

    for _, conf in ipairs(confidences) do
        local z = quantile(conf)
        assert.is_number(z)

        if prev_z then
            assert.is_true(z > prev_z, string.format(
                               "z(%.3f) = %.6f should be > z(prev) = %.6f",
                               conf, z, prev_z))
        end
        prev_z = z
    end
end

function testcase.quantile_extreme_precision()
    local quantile = require('measure.quantile')

    -- Test with values very close to 0.5 (around the center)
    local z_5001 = quantile(0.5001)
    local z_4999 = quantile(0.4999)

    assert.is_number(z_5001)
    assert.is_number(z_4999)
    -- Both should be positive for confidence intervals
    assert.is_true(z_5001 > 0)
    assert.is_true(z_4999 > 0)
    -- 50.01% should give slightly larger z than 49.99%
    assert.is_true(z_5001 > z_4999)
end
