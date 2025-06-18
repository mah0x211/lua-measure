# Measure Describe Module Design Document

Version: 0.2.0  
Date: 2025-06-18

## Overview

The Measure Describe module defines the benchmark description objects that encapsulate individual benchmark specifications. It provides a structured way to define benchmark properties, validation logic, and method implementations for the fluent API.

## Purpose

This module creates and manages benchmark describe objects that:
- Store benchmark configuration and functions
- Validate method call order and arguments
- Enforce mutual exclusivity rules
- Provide clear error messages for invalid usage

## Module Structure

```lua
-- Module: measure.describe
local type = type
local format = string.format
local floor = math.floor

local Describe = {}
Describe.__index = Describe

-- Factory function
local function new_describe(name, namefn)
    -- Create and return describe instance
end

return new_describe
```

## Core Components

### 1. Describe Class

The main class for benchmark descriptions:

```lua
--- @class measure.describe
--- @field spec measure.describe.spec
local Describe = {}
Describe.__index = Describe
Describe.__tostring = function(self)
    return format('measure.describe %q', self.spec.name)
end
```

### 2. Benchmark Specification

```lua
--- @class measure.describe.spec.options
--- @field context table|function|nil Context for the benchmark
--- @field repeats number|function|nil Number of repeats for the benchmark
--- @field warmup number|function|nil Warmup iterations before measuring
--- @field sample_size number|function|nil Sample size for the benchmark

--- @class measure.describe.spec
--- @field name string The name of the benchmark
--- @field namefn function|nil Optional function to generate dynamic names
--- @field options measure.describe.spec.options|nil Options for the benchmark
--- @field setup function|nil Setup function for each iteration
--- @field setup_once function|nil Setup function that runs once before all iterations
--- @field run function|nil The function to benchmark
--- @field measure function|nil Custom measure function for timing
--- @field teardown function|nil Teardown function for cleanup after each iteration
```

## Method Implementations

### options()

Configures benchmark execution parameters:

```lua
function Describe:options(opts)
    local spec = self.spec
    if type(opts) ~= 'table' then
        return false, 'argument must be a table'
    elseif spec.options then
        return false, 'options cannot be defined twice'
    elseif spec.setup or spec.setup_once or spec.run or spec.measure then
        return false,
               'options must be defined before setup(), setup_once(), run() or measure()'
    end
    
    -- Validate options using validate_options function
    local ok, err = validate_options(opts)
    if not ok then
        return false, err
    end
    
    spec.options = opts
    return true
end

--- Validate options table values
--- @param opts table The options table to validate
--- @return boolean ok True if valid
--- @return string|nil err Error message if invalid
local function validate_options(opts)
    -- Validate context
    if opts.context ~= nil then
        local t = type(opts.context)
        if t ~= 'table' and t ~= 'function' then
            return false, 'options.context must be a table or a function'
        end
    end
    
    -- Validate repeats
    if opts.repeats ~= nil then
        local t = type(opts.repeats)
        if t ~= 'number' and t ~= 'function' then
            return false, 'options.repeats must be a number or a function'
        end
        if t == 'number' and (opts.repeats <= 0 or opts.repeats ~= floor(opts.repeats)) then
            return false, 'options.repeats must be a positive integer'
        end
    end
    
    -- Validate warmup
    if opts.warmup ~= nil then
        local t = type(opts.warmup)
        if t ~= 'number' and t ~= 'function' then
            return false, 'options.warmup must be a number or a function'
        end
        if t == 'number' and (opts.warmup < 0 or opts.warmup ~= floor(opts.warmup)) then
            return false, 'options.warmup must be a non-negative integer'
        end
    end
    
    -- Validate sample_size
    if opts.sample_size ~= nil then
        local t = type(opts.sample_size)
        if t ~= 'number' and t ~= 'function' then
            return false, 'options.sample_size must be a number or a function'
        end
        if t == 'number' and (opts.sample_size <= 0 or opts.sample_size ~= floor(opts.sample_size)) then
            return false, 'options.sample_size must be a positive integer'
        end
    end
    
    return true
end
```

### setup() / setup_once()

Defines initialization logic with mutual exclusivity:

```lua
function Describe:setup(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup then
        return false, 'cannot be defined twice'
    elseif spec.setup_once then
        return false, 'cannot be defined if setup_once() is defined'
    elseif spec.run or spec.measure then
        return false, 'must be defined before run() or measure()'
    end
    
    spec.setup = fn
    return true
end

function Describe:setup_once(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup_once then
        return false, 'cannot be defined twice'
    elseif spec.setup then
        return false, 'cannot be defined if setup() is defined'
    elseif spec.run or spec.measure then
        return false, 'must be defined before run() or measure()'
    end
    
    spec.setup_once = fn
    return true
end
```

### run() / measure()

Defines benchmark execution with mutual exclusivity:

```lua
function Describe:run(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.run then
        return false, 'cannot be defined twice'
    elseif spec.measure then
        return false, 'cannot be defined if measure() is defined'
    end
    
    spec.run = fn
    return true
end

function Describe:measure(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.measure then
        return false, 'cannot be defined twice'
    elseif spec.run then
        return false, 'cannot be defined if run() is defined'
    end
    
    spec.measure = fn
    return true
end
```

### teardown()

Defines cleanup logic:

```lua
function Describe:teardown(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.teardown then
        return false, 'cannot be defined twice'
    elseif not spec.run and not spec.measure then
        return false, 'must be defined after run() or measure()'
    end
    
    spec.teardown = fn
    return true
end
```

## Factory Function

```lua
local function new_describe(name, namefn)
    if type(name) ~= 'string' then
        return nil, format('name must be a string, got %q', type(name))
    elseif namefn ~= nil and type(namefn) ~= 'function' then
        return nil, format('namefn must be a function or nil, got %q', type(namefn))
    end
    
    local desc = setmetatable({
        spec = {
            name = name,
            namefn = namefn,
        },
    }, Describe)
    return desc
end
```

## Validation Rules

### Method Order Constraints

1. `options()` must be called before `setup()`, `setup_once()`, `run()`, or `measure()`
2. `setup()` or `setup_once()` must be called before `run()` or `measure()`
3. `teardown()` must be called after `run()` or `measure()`

### Mutual Exclusivity

1. Cannot define both `setup()` and `setup_once()`
2. Cannot define both `run()` and `measure()`
3. Cannot call any method twice

### Required Methods

At least one of `run()` or `measure()` must be defined for a valid benchmark.

## Error Handling

All methods return `(bool, error)` tuples:
- Success: `true, nil`
- Failure: `false, "error message"`

Error messages are descriptive and specific:
- `"argument must be a table"`
- `"options cannot be defined twice"`
- `"cannot be defined if setup_once() is defined"`

## Integration Points

### Registry Module
- Registry creates describe instances via factory
- Validates uniqueness before storing

### Measure Module
- Calls methods through metatable __call
- Handles error propagation to user

## Usage Example

```lua
-- Created by registry
local desc = new_describe('String Concat', function(i)
    return 'iteration ' .. i
end)

-- Method chaining through measure module
desc:options({ warmup = 10 })
desc:setup(function(i, ctx) return "test" end)
desc:run(function(str) return str .. str end)
```

## Implementation Details

### Local Variables

All built-in functions are cached as local variables for performance and safety:
```lua
local type = type
local format = string.format  
local floor = math.floor
```

### Option Validation

Comprehensive validation is performed for all option values:
- `context`: Must be table or function
- `repeats`: Must be positive integer or function
- `warmup`: Must be non-negative integer or function  
- `sample_size`: Must be positive integer or function

### Type Safety

All inputs are validated for type correctness:
- Names must be strings
- Functions must be functions
- Options must be tables
- Option values must match expected types and constraints
