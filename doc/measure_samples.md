# Measure Samples Module Design Document

Version: 0.1.0  
Date: 2025-06-29

## Overview

The Measure Samples module provides integrated sample and garbage collection data management for performance benchmarking. It combines time measurement with GC metrics in a unified, column-oriented data structure, offering comprehensive insights into both execution time and memory allocation patterns during benchmark execution.

## Purpose

This module serves as the core data collection component for the measure system:
- Collects execution time samples in nanoseconds with high precision
- Tracks garbage collection metrics (memory usage before/after, allocation amounts)
- Provides column-oriented data format for efficient statistical analysis
- Manages GC state automatically during sampling
- Integrates GC configuration directly into the samples object

## Module Structure

```lua
-- Module: measure.samples
local samples = require('measure.samples')

-- Create samples object with capacity and optional GC configuration
local s = samples(capacity, gc_step)

-- Methods available:
-- s:capacity()  -- Get capacity
-- s:dump()      -- Get column-oriented data
-- #s            -- Get current count
```

## Core Components

### 1. Data Structure

The module uses a unified data structure that combines time and GC metrics:

```c
typedef struct {
    uint64_t time_ns;    // Execution time in nanoseconds
    size_t before_kb;    // Memory usage before operation (KB)
    size_t after_kb;     // Memory usage after operation (KB)
    size_t allocated_kb; // Memory allocated during operation (KB)
} measure_samples_data_t;

typedef struct {
    size_t capacity;              // Maximum number of samples
    size_t count;                 // Current number of samples
    size_t base_kb;               // Memory baseline after initial GC
    int saved_gc_pause;           // Saved GC pause value
    int saved_gc_stepmul;         // Saved GC step multiplier
    int gc_step;                  // GC configuration
    int ref_data;                 // Lua registry reference
    measure_samples_data_t *data; // Sample array
} measure_samples_t;
```

### 2. GC Configuration

The `gc_step` parameter controls garbage collection behavior:

- **-1**: GC disabled during sampling
- **0**: Full GC before each sample (default)
- **>0**: Step GC with threshold in KB

### 3. Automatic GC Management

The module automatically manages GC state during sampling:

```c
// Before sampling
measure_samples_preprocess(samples, L);
// During sampling  
measure_samples_init_sample(samples, L);
measure_samples_update_sample(samples, L);
// After sampling
measure_samples_postprocess(samples, L);
```

## API Reference

### Constructor

#### `samples(capacity, gc_step)`

Creates a new samples object.

**Parameters:**
- `capacity` (integer): Maximum number of samples (default: 1000)
- `gc_step` (integer, optional): GC configuration (default: 0)

**Returns:**
- Samples object on success
- `nil, error_message` on failure

**Example:**
```lua
local samples = require('measure.samples')
local s1 = samples(100)        -- 100 capacity, full GC
local s2 = samples(100, -1)    -- 100 capacity, GC disabled
local s3 = samples(100, 1024)  -- 100 capacity, step GC at 1024KB
```

### Methods

#### `samples:capacity()`

Returns the maximum capacity of the samples object.

**Returns:**
- `integer`: Maximum number of samples

#### `samples:dump()`

Returns collected data in column-oriented format for efficient analysis.

**Returns:**
- `table`: Column-oriented data structure with fields:
  - `time_ns`: Array of execution times in nanoseconds
  - `before_kb`: Array of memory usage before each operation (KB)
  - `after_kb`: Array of memory usage after each operation (KB)
  - `allocated_kb`: Array of memory allocated during each operation (KB)

**Example:**
```lua
local data = samples:dump()
print("Average time:", calculate_mean(data.time_ns))
print("Total allocation:", sum(data.allocated_kb))
print("Memory efficiency:", analyze_allocation_pattern(data))
```

#### `#samples`

Returns the current number of collected samples.

**Returns:**
- `integer`: Number of samples collected

## Usage Examples

### Basic Usage

```lua
local samples = require('measure.samples')
local sampler = require('measure.sampler')

-- Create samples with full GC mode
local s = samples(1000, 0)

-- Run benchmark
local ok = sampler(function()
    -- Your benchmark code here
    local result = expensive_calculation()
    return result
end, s)

-- Analyze results
if ok then
    local data = s:dump()
    print("Samples collected:", #s)
    print("Average time (μs):", calculate_mean(data.time_ns) / 1000)
    print("Total allocation (KB):", sum(data.allocated_kb))
end
```

### GC Performance Analysis

```lua
-- Compare different GC modes
local samples_disabled = samples(100, -1)  -- GC disabled
local samples_full = samples(100, 0)       -- Full GC
local samples_step = samples(100, 1024)    -- Step GC

local function benchmark_func()
    local t = {}
    for i = 1, 1000 do
        t[i] = string.rep("data", 100)
    end
    return t
end

-- Run benchmarks with different GC modes
sampler(benchmark_func, samples_disabled)
sampler(benchmark_func, samples_full) 
sampler(benchmark_func, samples_step)

-- Compare allocation patterns
local data_disabled = samples_disabled:dump()
local data_full = samples_full:dump()
local data_step = samples_step:dump()

print("Disabled GC - Avg allocation:", calculate_mean(data_disabled.allocated_kb))
print("Full GC - Avg allocation:", calculate_mean(data_full.allocated_kb))
print("Step GC - Avg allocation:", calculate_mean(data_step.allocated_kb))
```

## Integration Points

### With measure.sampler

The samples object is passed directly to the sampler function:

```lua
local ok, error_msg = sampler(benchmark_function, samples_object, warmup_time)
```

### With Statistical Analysis

The column-oriented format enables efficient statistical operations:

```lua
local data = samples:dump()

-- Time statistics
local time_stats = {
    mean = calculate_mean(data.time_ns),
    median = calculate_median(data.time_ns),
    std_dev = calculate_std_dev(data.time_ns),
    percentiles = calculate_percentiles(data.time_ns, {50, 95, 99})
}

-- Memory statistics  
local memory_stats = {
    total_allocated = sum(data.allocated_kb),
    avg_allocation = calculate_mean(data.allocated_kb),
    peak_usage = max(data.after_kb)
}
```

## Performance Considerations

### Memory Efficiency

- Data is stored in contiguous arrays for cache efficiency
- Column-oriented format minimizes memory access overhead
- Lua userdata management prevents garbage collection of sample data

### GC Impact

- **Disabled GC** (`-1`): Fastest execution, but may accumulate memory
- **Full GC** (`0`): Consistent baseline, but highest overhead
- **Step GC** (`>0`): Balanced approach, trigger GC at allocation threshold

### Statistical Analysis

- Column format enables vectorized operations
- Direct access to specific metrics without data transformation
- Efficient for large sample sets (>10,000 samples)

## Error Handling

### Constructor Errors

```lua
local s, err = samples(0)  -- Invalid capacity
if not s then
    print("Error:", err)  -- "capacity must be > 0"
end
```

### Capacity Overflow

The module handles capacity limits gracefully:
- Sampling automatically resets when starting new benchmark
- No buffer overflow - sampling stops at capacity limit
- Error reporting through sampler return values

### Memory Management

- Automatic cleanup through Lua garbage collection
- Registry references prevent premature deallocation
- Safe handling of C memory allocations

## Version History

- **0.1.0** (2025-06-29): Initial release with integrated GC functionality
  - Column-oriented data format
  - Unified time and GC measurement
  - Automatic GC state management
  - Three GC modes: disabled, full, step