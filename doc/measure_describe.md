# Measure Describe Module Design Document

Version: 0.1.0  
Date: 2025-06-17

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
local BenchmarkDescribe = {}
BenchmarkDescribe.__index = BenchmarkDescribe

-- Factory function
local function new_describe(name, namefn)
    -- Create and return describe instance
end

return new_describe
```

## Core Components

### 1. BenchmarkDescribe Class

The main class for benchmark descriptions:

```lua
--- @class measure.describe
--- @field spec measure.describe.spec
local BenchmarkDescribe = {}
BenchmarkDescribe.__index = BenchmarkDescribe
BenchmarkDescribe.__tostring = function(self)
    return ('Benchmark %q'):format(self.spec.name)
end
```

### 2. Benchmark Specification

```lua
--- @class measure.describe.spec
--- @field name string The name of the benchmark
--- @field namefn function|nil The function to describe the benchmark name
--- @field options table The options for the benchmark
--- @field setup function|nil The setup function for the benchmark
--- @field setup_once function|nil The setup_once function for the benchmark
--- @field run function|nil The run function for the benchmark
--- @field measure function|nil The measure function for the benchmark
--- @field teardown function|nil The teardown function for the benchmark
```

## Method Implementations

### options()

Configures benchmark execution parameters:

```lua
function BenchmarkDescribe:options(opts)
    local spec = self.spec
    if type(opts) ~= 'table' then
        return false, 'argument must be a table'
    elseif spec.options then
        return false, 'options cannot be defined twice'
    elseif spec.setup or spec.setup_once or spec.run or spec.measure then
        return false, 
               'options must be defined before setup(), setup_once(), run() or measure()'
    end
    
    -- Validate options
    if opts.context and type(opts.context) ~= 'table' and 
       type(opts.context) ~= 'function' then
        return false, 'options.context must be a table or a function'
    end
    
    if opts.repeats and type(opts.repeats) ~= 'number' and 
       type(opts.repeats) ~= 'function' then
        return false, 'options.repeats must be a number or a function'
    end
    
    -- Additional validation for warmup, sample_size...
    
    spec.options = opts
    return true
end
```

### setup() / setup_once()

Defines initialization logic with mutual exclusivity:

```lua
function BenchmarkDescribe:setup(fn)
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

function BenchmarkDescribe:setup_once(fn)
    -- Similar validation with setup/setup_once mutual exclusivity
end
```

### run() / measure()

Defines benchmark execution with mutual exclusivity:

```lua
function BenchmarkDescribe:run(fn)
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
```

### teardown()

Defines cleanup logic:

```lua
function BenchmarkDescribe:teardown(fn)
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
        return nil, ('name must be a string, got %q'):format(type(name))
    elseif namefn ~= nil and type(namefn) ~= 'function' then
        return nil, ('namefn must be a function or nil, got %q'):format(
                   type(namefn))
    end
    
    return setmetatable({
        spec = {
            name = name,
            namefn = namefn,
        },
    }, BenchmarkDescribe)
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

## Type Safety

All inputs are validated for type correctness:
- Names must be strings
- Functions must be functions
- Options must be tables
- Option values must match expected types
