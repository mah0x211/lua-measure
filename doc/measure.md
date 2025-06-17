# Measure Module Design Document

Version: 0.1.0  
Date: 2025-06-17

## Overview

The Measure module serves as the main entry point for benchmark definition, implementing a secure metatable-based API that prevents direct access to internal state. It provides the primary interface for users to define benchmarks using fluent dot-notation syntax and manages the overall registration process.

## Purpose

This module acts as the registrar that coordinates between user code and the internal registry system. It exposes a controlled API surface through metatables while maintaining security and proper method call sequencing.

## Module Structure

```lua
-- Module: measure
local registry = require('measure.registry')
local registrar = create_registrar()
return registrar
```

## Core Components

### 1. Registrar Object

The registrar is a metatable-controlled object that serves as the main API:

```lua
local registrar = setmetatable({}, {
    __newindex = hook_setter,      -- Handles hook assignments
    __call = method_caller,        -- Handles method calls
    __index = method_resolver      -- Handles property access
})
```

### 2. State Management

```lua
-- Internal state tracking
local desc = nil          -- Current describe object or method name
local descfn = nil        -- Pending method to call
local RegistrySpec = nil  -- File-specific registry specification
```

### 3. Hook Management

The module supports four lifecycle hooks that are set via direct assignment:

- `before_all`: Called once before all benchmarks
- `before_each`: Called before each benchmark
- `after_each`: Called after each benchmark  
- `after_all`: Called once after all benchmarks

## Metatable Implementation

### Hook Setter (__newindex)

```lua
__newindex = function(_, key, fn)
    local ok, err = RegistrySpec:set_hook(key, fn)
    if not ok then
        error(err, 2)
    end
end
```

Validates and registers lifecycle hooks through the registry spec.

### Method Caller (__call)

```lua
__call = function(self, ...)
    if desc == 'describe' then
        -- Create new benchmark description
        local err
        desc, err = RegistrySpec:new_describe(...)
        if not desc then
            error(err, 2)
        end
        return self
    end
    
    if desc == nil or descfn == nil then
        error('Attempt to call measure as a function', 2)
    end
    
    -- Call method on current describe object
    local fn = desc[descfn]
    if type(fn) ~= 'function' then
        error(('%s has no %q'):format(desc, descfn), 2)
    end
    
    local ok, err = fn(desc, ...)
    if not ok then
        error(('%s %s(): %s'):format(desc, descfn, err), 2)
    end
    
    descfn = nil
    return self
end
```

Handles both `measure.describe()` calls and chained method calls.

### Method Resolver (__index)

```lua
__index = function(self, key)
    if type(key) ~= 'string' or type(desc) == 'string' or descfn then
        error(('Attempt to access measure as a table: %q'):format(
            tostring(key)), 2)
    end
    
    if desc == nil then
        desc = key
        return self
    end
    
    descfn = key
    return self
end
```

Manages the state machine for method chaining.

## API Flow

### 1. Hook Definition
```lua
measure.before_all = function() return {} end
measure.after_each = function(i, ctx) end
```

### 2. Benchmark Definition
```lua
measure.describe('Name').options({}).run(function() end)
```

### 3. State Transitions
```
Initial → describe → DescribeActive → method → MethodPending → call → DescribeActive
```

## Integration Points

### Registry Module
- Gets `RegistrySpec` through `registry.new()`
- Delegates hook storage to `RegistrySpec:set_hook()`
- Creates describes via `RegistrySpec:new_describe()`

### Describe Module
- Receives describe objects from registry
- Calls methods on describe objects with validation

## Error Handling

All errors are propagated with appropriate stack levels:
- Hook errors: level 2
- Describe creation errors: level 2
- Method call errors: level 2

## Security Considerations

1. **No Direct State Access**: All state is internal and never exposed
2. **Controlled Method Flow**: State machine prevents invalid sequences
3. **Type Validation**: All inputs validated before processing
4. **Error Isolation**: Errors thrown at appropriate stack levels

## Usage Example

```lua
local measure = require('measure')

-- Define hooks
function measure.before_all()
    return { start_time = os.time() }
end

-- Define benchmark
measure.describe('Example Benchmark')
    .options({ warmup = 10 })
    .run(function()
        -- benchmark code
    end)
```

## File Scope

Each benchmark file gets its own `RegistrySpec` instance, ensuring complete isolation between files while maintaining consistent API behavior.
