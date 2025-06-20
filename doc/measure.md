# Measure Module Design Document

Version: 0.2.0  
Date: 2025-06-20

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
local measure = setmetatable({}, {
    __newindex = hook_setter,      -- Handles hook assignments
    __index = allow_new_describe   -- Handles property access for 'describe'
})
```

### 2. State Management

The module maintains minimal internal state for security and simplicity. File-specific registry specifications are obtained dynamically through the `get_spec()` function, eliminating the need for persistent state variables.

### 3. Hook Management

The module supports four lifecycle hooks that are set via direct assignment:

- `before_all`: Called once before all benchmarks
- `before_each`: Called before each benchmark
- `after_each`: Called after each benchmark  
- `after_all`: Called once after all benchmarks

## Metatable Implementation

### Hook Setter (__newindex)

```lua
local function hook_setter(_, key, fn)
    local spec = get_spec()
    local ok, err = spec:set_hook(key, fn)
    if not ok then
        error(err, 2)
    end
end
```

Validates and registers lifecycle hooks through the dynamically obtained registry spec.

### Method Caller (__call)

The measure object does not have a `__call` metamethod. Attempting to call `measure()` directly will result in an error. The `describe` function is accessed through the `__index` metamethod.

### Method Resolver (__index)

```lua
local function allow_new_describe(self, key)
    if type(key) ~= 'string' or key ~= 'describe' then
        error(format('Attempt to access measure as a table: %q', tostring(key)), 2)
    end
    return new_describe
end
```

This function enforces strict access control:
- Only allows access to the `describe` key
- Returns the `new_describe` function directly
- Prevents any other table-like access to the measure object

### Describe Proxy Implementation

The `new_describe` function returns a proxy object that implements method chaining:

```lua
local function new_describe_proxy(name, desc)
    return setmetatable({}, {
        __tostring = function()
            return format('measure.describe %q', name)
        end,
        __index = function(self, method)
            if type(method) ~= 'string' then
                error(format('Attempt to access measure.describe as a table: %q',
                          tostring(method)), 2)
            end
            
            return function(...)
                local fn = desc[method]
                if type(fn) ~= 'function' then
                    error(format('%s has no method %q', tostring(self), method), 2)
                end
                
                local ok, err = fn(desc, ...)
                if not ok then
                    error(format('%s(): %s', method, err), 2)
                end
                
                return self
            end
        end,
    })
end
```

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

### 3. API Usage Flow

1. Access `measure.describe` returns the `new_describe` function
2. Call `new_describe(name)` creates a describe object and returns a proxy
3. Access proxy methods returns functions that can be called immediately
4. Method calls return the proxy for chaining

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
2. **Reference Storage Prevention**: The design prevents storing references to bypass security checks
3. **Type Validation**: All inputs validated before processing
4. **Error Isolation**: Errors thrown at appropriate stack levels
5. **Describe Chain Prevention**: The proxy pattern prevents `measure.describe(...).describe(...)` calls:
   - `measure.describe` proxy instances have no `describe` method
   - Attempting to chain `describe` calls results in "has no method" errors

## Usage Example

```lua
local measure = require('measure')

-- Define hooks
measure.before_all = function()
    return { start_time = os.time() }
end

-- Define benchmark (correct usage)
measure.describe('Example Benchmark')
    .options({ warmup = 10 })
    .run(function()
        -- benchmark code
    end)

-- Invalid usage (will throw error)
-- measure.describe('Test').describe('Another')  -- Error: has no method "describe"
-- measure()  -- Error: Attempt to call measure
```

## File Scope

Each benchmark file gets its own `RegistrySpec` instance, ensuring complete isolation between files while maintaining consistent API behavior.
