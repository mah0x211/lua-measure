# Measure Sampler Module Design Document

Version: 0.1.0  
Date: 2025-06-29

## Overview

The Measure Sampler module provides a function-based benchmark execution engine that simplifies performance measurement. It implements a clean, three-argument API that focuses on execution with integrated time and garbage collection data collection, removing the complexity of object management and providing streamlined error handling.

## Purpose

This module serves as the benchmark execution engine for the measure system:
- Executes benchmark functions with precise timing and GC measurement
- Provides a simple function-based API (no object instantiation required)
- Handles warmup execution separate from measurement collection
- Integrates seamlessly with measure.samples for unified data collection
- Manages GC state automatically through the samples object
- Offers robust error handling with clear failure reporting

## Module Structure

```lua
-- Module: measure.sampler
local sampler = require('measure.sampler')

-- Function-based API with three arguments
local success, error_message = sampler(
    benchmark_function,  -- Function to benchmark
    samples_object,      -- measure.samples object (contains GC config)
    warmup_seconds       -- Optional warmup duration (default: 0)
)
```

## Core Components

### 1. Function-Based Architecture

The sampler is implemented as a direct function call rather than an object:

```c
static int run_lua(lua_State *L)
{
    sampler_t s = {.L = L};
    
    // Validate arguments
    luaL_checktype(L, 1, LUA_TFUNCTION);           // benchmark function
    s.samples = luaL_checkudata(L, 2, MEASURE_SAMPLES_MT); // samples object
    lua_Integer iv = luaL_optinteger(L, 3, 0);     // optional warmup
    s.warmup = (iv < 0) ? 0 : (int)iv;
    
    // Execute warmup and sampling
    if (s.warmup > 0) warmup_lua(&s);
    return sampling_lua(&s);
}
```

### 2. Integrated Sampling Process

The sampling process is tightly integrated with the samples object:

```c
static int sampling_lua(sampler_t *s)
{
    lua_State *L = s->L;
    size_t sample_size = s->samples->capacity;
    
    // Preprocess samples object (sets up GC state)
    measure_samples_preprocess(s->samples, L);
    
    for (size_t i = 0; i < sample_size; i++) {
        // Initialize sample (records start time and memory)
        measure_samples_init_sample(s->samples, L);
        
        // Execute benchmark function
        lua_pushvalue(L, 1);
        lua_pushboolean(L, 0);  // is_warmup = false
        int rc = lua_pcall(L, 1, 0, 0);
        
        // Update sample (records end time and memory)
        measure_samples_update_sample(s->samples, L);
        
        // Handle errors
        if (is_lua_error(L, rc)) return -1;
    }
    
    // Postprocess samples object (restores GC state)
    measure_samples_postprocess(s->samples, L);
    return 0;
}
```

### 3. Warmup Execution

Warmup execution is separate from measurement collection:

```c
static int warmup_lua(sampler_t *s)
{
    if (s->warmup > 0) {
        const uint64_t warmup_ns = MEASURE_SEC2NSEC(s->warmup);
        uint64_t start_time = measure_getnsec();
        
        while ((measure_getnsec() - start_time) < warmup_ns) {
            lua_pushvalue(L, 1);
            lua_pushboolean(L, 1);  // is_warmup = true
            lua_pcall(L, 1, 0, 0);
        }
    }
    return 0;
}
```

## API Reference

### Main Function

#### `sampler(benchmark_function, samples_object, warmup_seconds)`

Executes a benchmark function and collects performance data.

**Parameters:**
- `benchmark_function` (function): Function to benchmark
  - Receives `is_warmup` boolean parameter
  - Should perform the operation to be measured
- `samples_object` (measure.samples): Object that stores results and GC configuration
- `warmup_seconds` (integer, optional): Warmup duration in seconds (default: 0)

**Returns:**
- `true` on successful execution
- `false, error_message` on failure

**Example:**
```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')(1000, 0) -- 1000 capacity, full GC

local ok, err = sampler(function(is_warmup)
    if not is_warmup then
        -- Only perform expensive operations during measurement
        return expensive_calculation()
    else
        -- Lighter operations during warmup
        simple_calculation()
    end
end, samples, 2) -- 2 seconds warmup

if not ok then
    print("Benchmark failed:", err)
else
    print("Benchmark completed successfully")
    local data = samples:dump()
    print("Average time (μs):", calculate_mean(data.time_ns) / 1000)
end
```

## Usage Examples

### Basic Benchmarking

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

-- Create samples object with full GC
local s = samples(1000, 0)

-- Simple benchmark without warmup
local ok = sampler(function(is_warmup)
    -- Function always executes the same operation
    local sum = 0
    for i = 1, 10000 do
        sum = sum + i
    end
    return sum
end, s)

if ok then
    local data = s:dump()
    print("Samples collected:", #s)
    print("Min time (ns):", min(data.time_ns))
    print("Max time (ns):", max(data.time_ns))
    print("Memory allocated (KB):", sum(data.allocated_kb))
end
```

### Warmup and Memory Analysis

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

-- Create samples with step GC (trigger at 1MB allocations)
local s = samples(100, 1024)

local ok, err = sampler(function(is_warmup)
    if is_warmup then
        -- Light warmup - just create small objects
        local temp = {}
        for i = 1, 100 do
            temp[i] = i
        end
    else
        -- Actual benchmark - allocate significant memory
        local data = {}
        for i = 1, 1000 do
            data[i] = string.rep("benchmark", 100)
        end
        return data
    end
end, s, 3) -- 3 seconds of warmup

if ok then
    local data = s:dump()
    print("Execution analysis:")
    print("  Total samples:", #s)
    print("  Average time (μs):", calculate_mean(data.time_ns) / 1000)
    print("  Average allocation per sample (KB):", calculate_mean(data.allocated_kb))
    print("  Peak memory usage (KB):", max(data.after_kb))
else
    print("Benchmark failed:", err)
end
```

### Error Handling and Validation

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

local s = samples(50, -1) -- GC disabled for maximum speed

-- Test error handling
local ok, err = sampler(function(is_warmup)
    if not is_warmup then
        -- Simulate an error during measurement
        if math.random() < 0.1 then
            error("Random benchmark failure")
        end
        
        -- Normal operation
        return calculate_something()
    end
end, s, 1)

if not ok then
    print("Expected error occurred:", err)
    print("Partial samples collected:", #s)
else
    print("All samples collected successfully:", #s)
end
```

### Comparative Analysis

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

-- Compare two different algorithms
local function algorithm_a()
    local result = {}
    for i = 1, 1000 do
        result[i] = i * i
    end
    return result
end

local function algorithm_b()
    local result = {}
    for i = 1, 1000 do
        table.insert(result, i * i)
    end
    return result
end

-- Benchmark algorithm A
local samples_a = samples(100, 0)
local ok_a = sampler(algorithm_a, samples_a, 1)

-- Benchmark algorithm B  
local samples_b = samples(100, 0)
local ok_b = sampler(algorithm_b, samples_b, 1)

if ok_a and ok_b then
    local data_a = samples_a:dump()
    local data_b = samples_b:dump()
    
    print("Algorithm A - Average time (μs):", calculate_mean(data_a.time_ns) / 1000)
    print("Algorithm B - Average time (μs):", calculate_mean(data_b.time_ns) / 1000)
    print("Performance ratio:", calculate_mean(data_b.time_ns) / calculate_mean(data_a.time_ns))
end
```

## Integration Points

### With measure.samples

The sampler function requires a samples object that configures both data collection and GC behavior:

```lua
local samples_fast = samples(1000, -1)    -- GC disabled
local samples_stable = samples(1000, 0)   -- Full GC mode
local samples_balanced = samples(1000, 512) -- Step GC at 512KB

-- Same benchmark with different GC strategies
sampler(benchmark_func, samples_fast)     -- Fastest execution
sampler(benchmark_func, samples_stable)   -- Most consistent results
sampler(benchmark_func, samples_balanced) -- Balanced approach
```

### With Statistical Analysis Libraries

The function-based API integrates cleanly with analysis workflows:

```lua
local function run_benchmark(func, samples_config, warmup_time)
    local s = samples(samples_config.capacity, samples_config.gc_step)
    local ok, err = sampler(func, s, warmup_time)
    
    if ok then
        return s:dump()
    else
        error("Benchmark failed: " .. err)
    end
end

-- Run multiple configurations
local configs = {
    {capacity = 1000, gc_step = -1, name = "fast"},
    {capacity = 1000, gc_step = 0, name = "stable"},
    {capacity = 1000, gc_step = 1024, name = "balanced"}
}

for _, config in ipairs(configs) do
    local data = run_benchmark(test_function, config, 2)
    analyze_and_report(data, config.name)
end
```

## Performance Considerations

### Execution Overhead

- Function call overhead is minimal (single C function)
- No object allocation per benchmark run
- Direct integration with samples object reduces data copying
- Warmup and measurement phases are clearly separated

### Memory Management

- No persistent state between benchmark runs
- Automatic cleanup through Lua garbage collection
- C-level sample management prevents intermediate allocations
- GC state is managed entirely through samples object

### Error Handling Performance

- Fast error detection during benchmark execution
- Early termination on first error
- Detailed error reporting without performance impact
- Clean state restoration even after errors

## Error Handling

### Argument Validation

```lua
-- Invalid function
local ok, err = sampler("not a function", samples_obj)
-- Returns: false, "bad argument #1 to 'sampler' (function expected, got string)"

-- Invalid samples object
local ok, err = sampler(function() end, "not samples")
-- Returns: false, "bad argument #2 to 'sampler' (measure.samples expected, got string)"

-- Invalid warmup
local ok, err = sampler(function() end, samples_obj, "invalid")
-- Returns: false, "bad argument #3 to 'sampler' (number expected, got string)"
```

### Runtime Errors

```lua
local ok, err = sampler(function(is_warmup)
    if not is_warmup then
        error("Benchmark runtime error")
    end
end, samples_obj)
-- Returns: false, "runtime error: Benchmark runtime error"
```

### Memory Errors

```lua
-- Capacity exceeded (handled automatically by samples object)
local small_samples = samples(2, 0)
local ok = sampler(function() end, small_samples) -- Runs only 2 samples
-- Returns: true (automatically limited to capacity)
```

## Version History

- **0.1.0** (2025-06-29): Initial release with function-based API
  - Three-argument function interface
  - Integrated samples object processing
  - Automatic GC state management through samples
  - Separate warmup and measurement phases
  - Comprehensive error handling