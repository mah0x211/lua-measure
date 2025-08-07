require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local fmt = require('measure.report.format')

-- Test format_time function
function testcase.format_time()
    -- Test nil and NaN
    assert.equal(fmt.time(nil), "N/A")
    assert.equal(fmt.time(0 / 0), "N/A") -- NaN

    -- Test nanoseconds
    assert.equal(fmt.time(0), "0 ns")
    assert.equal(fmt.time(500), "500 ns")
    assert.equal(fmt.time(999), "999 ns")

    -- Test microseconds (1000 ns = 1 us)
    assert.equal(fmt.time(1000), "1.000 us")
    assert.equal(fmt.time(1500), "1.500 us")
    assert.equal(fmt.time(999999), "999.999 us")

    -- Test milliseconds (1000000 ns = 1 ms)
    assert.equal(fmt.time(1000000), "1.000 ms")
    assert.equal(fmt.time(1500000), "1.500 ms")
    assert.equal(fmt.time(999999999), "1000.000 ms") -- Actually 1000 ms (= 1 s)

    -- Test seconds (1000000000 ns = 1 s)
    assert.equal(fmt.time(1000000000), "1.000 s")
    assert.equal(fmt.time(1500000000), "1.500 s")
    assert.equal(fmt.time(59999999999), "60.000 s") -- Rounded to 60.000
end

-- Test format_confidence_interval function
function testcase.format_confidence_interval()
    -- Test nil and NaN inputs
    assert.equal(fmt.confidence_interval(nil, 100), "N/A")
    assert.equal(fmt.confidence_interval(100, nil), "N/A")
    assert.equal(fmt.confidence_interval(nil, nil), "N/A")
    assert.equal(fmt.confidence_interval(0 / 0, 100), "N/A") -- NaN mean
    assert.equal(fmt.confidence_interval(100, 0 / 0), "N/A") -- NaN ci_width

    -- Test valid confidence intervals
    assert.equal(fmt.confidence_interval(1000000, 200000),
                 "[900.000 us, 1.100 ms]")
    assert.equal(fmt.confidence_interval(5000000, 1000000),
                 "[4.500 ms, 5.500 ms]")
    assert.equal(fmt.confidence_interval(1000000000, 200000000),
                 "[900.000 ms, 1.100 s]")

    -- Test edge case with zero width
    assert.equal(fmt.confidence_interval(1000000, 0), "[1.000 ms, 1.000 ms]")
end

-- Test format_throughput function
function testcase.format_throughput()
    -- Test nil and NaN
    assert.equal(fmt.throughput(nil), "N/A")
    assert.equal(fmt.throughput(0 / 0), "N/A") -- NaN

    -- Test operations per second
    assert.equal(fmt.throughput(0), "0.00 op/s")
    assert.equal(fmt.throughput(500), "500.00 op/s")
    assert.equal(fmt.throughput(999), "999.00 op/s")

    -- Test K op/s (1000 op/s = 1 K op/s)
    assert.equal(fmt.throughput(1000), "1.00 K op/s")
    assert.equal(fmt.throughput(1500), "1.50 K op/s")
    assert.equal(fmt.throughput(999999), "1000.00 K op/s") -- Actually 1000 K op/s (= 1 M op/s)

    -- Test M op/s (1000000 op/s = 1 M op/s)
    assert.equal(fmt.throughput(1000000), "1.00 M op/s")
    assert.equal(fmt.throughput(1500000), "1.50 M op/s")
    assert.equal(fmt.throughput(999999999), "1000.00 M op/s") -- Actually 1000 M op/s (= 1 G op/s)

    -- Test G op/s (1000000000 op/s = 1 G op/s)
    assert.equal(fmt.throughput(1000000000), "1.00 G op/s")
    assert.equal(fmt.throughput(1500000000), "1.50 G op/s")
    assert.equal(fmt.throughput(5000000000), "5.00 G op/s")
end

-- Test format_memory function
function testcase.format_memory()
    -- Test nil and NaN
    assert.equal(fmt.memory(nil), "N/A")
    assert.equal(fmt.memory(0 / 0), "N/A") -- NaN

    -- Test kilobytes
    assert.equal(fmt.memory(0), "0.00 KB")
    assert.equal(fmt.memory(500), "500.00 KB")
    assert.equal(fmt.memory(1023), "1023.00 KB")

    -- Test megabytes (1024 KB = 1 MB)
    assert.equal(fmt.memory(1024), "1.00 MB")
    assert.equal(fmt.memory(1536), "1.50 MB")
    assert.equal(fmt.memory(1048575), "1024.00 MB") -- Actually 1024 MB (= 1 GB)

    -- Test gigabytes (1048576 KB = 1 GB)
    assert.equal(fmt.memory(1048576), "1.00 GB")
    assert.equal(fmt.memory(1572864), "1.50 GB")
    assert.equal(fmt.memory(5242880), "5.00 GB")
end

-- Test format_gc_step function
function testcase.format_gc_step()
    -- Test disabled GC (-1)
    assert.equal(fmt.gc_step(-1), "disabled")

    -- Test full GC (0)
    assert.equal(fmt.gc_step(0), "full GC")

    -- Test incremental GC (positive values)
    assert.equal(fmt.gc_step(1), "1 KB")
    assert.equal(fmt.gc_step(256), "256 KB")
    assert.equal(fmt.gc_step(1024), "1024 KB")

    -- Test negative values other than -1
    assert.equal(fmt.gc_step(-2), "-2 KB")
    assert.equal(fmt.gc_step(-100), "-100 KB")
end

-- Test format_quality_indicator function
function testcase.format_quality_indicator()
    -- Test without confidence score
    assert.equal(fmt.quality_indicator("excellent"), "excellent")
    assert.equal(fmt.quality_indicator("good"), "good")
    assert.equal(fmt.quality_indicator("poor"), "poor")
    assert.equal(fmt.quality_indicator("unknown"), "unknown")

    -- Test with nil confidence score
    assert.equal(fmt.quality_indicator("good", nil), "good")

    -- Test with high confidence (>= 0.8)
    assert.equal(fmt.quality_indicator("excellent", 0.8), "excellent ***")
    assert.equal(fmt.quality_indicator("good", 0.9), "good ***")
    assert.equal(fmt.quality_indicator("good", 1.0), "good ***")

    -- Test with medium confidence (>= 0.6, < 0.8)
    assert.equal(fmt.quality_indicator("good", 0.6), "good **-")
    assert.equal(fmt.quality_indicator("acceptable", 0.7), "acceptable **-")
    assert.equal(fmt.quality_indicator("good", 0.79), "good **-")

    -- Test with low confidence (>= 0.4, < 0.6)
    assert.equal(fmt.quality_indicator("acceptable", 0.4), "acceptable *--")
    assert.equal(fmt.quality_indicator("poor", 0.5), "poor *--")
    assert.equal(fmt.quality_indicator("good", 0.59), "good *--")

    -- Test with very low confidence (< 0.4)
    assert.equal(fmt.quality_indicator("poor", 0.0), "poor ---")
    assert.equal(fmt.quality_indicator("poor", 0.1), "poor ---")
    assert.equal(fmt.quality_indicator("acceptable", 0.39), "acceptable ---")
end

-- Test edge cases and boundary values
function testcase.edge_cases()
    -- Test very large numbers
    assert.equal(fmt.time(1e15), "1000000.000 s")
    assert.equal(fmt.throughput(1e15), "1000000.00 G op/s")
    assert.equal(fmt.memory(1e15), "953674316.41 GB") -- 1e15 KB = 953674316.41 GB

    -- Test very small positive numbers
    assert.equal(fmt.time(0.1), "0.100 ns")
    assert.equal(fmt.time(0.5), "0.500 ns")
    assert.equal(fmt.time(0.9), "0.900 ns")

    -- Test negative numbers for time (negative values go to else branch -> ns)
    assert.equal(fmt.time(-1000), "-1000 ns") -- Negative, so not >= 1e3
    assert.equal(fmt.time(-1000000), "-1000000 ns") -- Negative, so not >= 1e6

    -- Test negative throughput (negative values still format with units since checks are >=)
    assert.equal(fmt.throughput(-1000), "-1000.00 op/s") -- Negative, so not >= 1e3

    -- Test negative memory (negative values still check with >= so fallback to KB)
    assert.equal(fmt.memory(-1024), "-1024.00 KB") -- Negative, so not >= 1024
end

-- Test argument type validation
function testcase.argument_validation()
    -- Test format_gc_step with non-number
    local err = assert.throws(fmt.gc_step, "invalid")
    assert.match(err, "gc_step must be a number")

    -- Test format_quality_indicator with invalid quality type
    local err2 = assert.throws(fmt.quality_indicator, 123, 0.5)
    assert.match(err2, "quality must be a string")

    -- Test format_quality_indicator with nil quality (should fail now)
    local err3 = assert.throws(fmt.quality_indicator, nil, 0.5)
    assert.match(err3, "quality must be a string")

    -- Test format_quality_indicator with invalid confidence_score type
    local err4 = assert.throws(fmt.quality_indicator, "good", "invalid")
    assert.match(err4, "confidence_score must be a number")

    -- Test valid calls should work
    assert.equal(fmt.gc_step(256), "256 KB")
    assert.equal(fmt.quality_indicator("good", 0.8), "good ***")
    assert.equal(fmt.quality_indicator("good"), "good") -- nil confidence_score is ok
end

-- Test format patterns and precision
function testcase.format_precision()
    -- Test time precision (3 decimal places)
    assert.equal(fmt.time(1234567), "1.235 ms") -- Rounded from 1.234567
    assert.equal(fmt.time(1234567890), "1.235 s") -- Rounded from 1.234567890

    -- Test throughput precision (2 decimal places)
    assert.equal(fmt.throughput(1234), "1.23 K op/s")
    assert.equal(fmt.throughput(1234567), "1.23 M op/s")

    -- Test memory precision (2 decimal places)
    assert.equal(fmt.memory(1234), "1.21 MB") -- 1234/1024 = 1.205078125 → 1.21
    assert.equal(fmt.memory(1234567), "1.18 GB") -- 1234567/1048576 = 1.177098274 → 1.18

    -- Test confidence interval combines time formatting
    assert.equal(fmt.confidence_interval(1234567, 123456),
                 "[1.173 ms, 1.296 ms]") -- Fixed calculation
end
