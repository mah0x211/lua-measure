# Measure Spec Module Design Document

Version: 0.1.0  
Date: 2025-06-19

## Overview

The Measure Spec module provides a factory function for creating benchmark specification objects that manage lifecycle hooks and benchmark describe objects. Each spec acts as a container for a file's benchmark configuration.

## Purpose

This module serves as the foundation for benchmark specification that:
- Creates independent spec objects for benchmark files
- Manages lifecycle hooks (`before_all`, `before_each`, `after_each`, `after_all`)
- Creates and manages benchmark describe objects
- Provides validation for hook names and describe uniqueness

## Module Structure

```lua
-- Module: measure.spec
local new_describe = require('measure.describe')
local type = type
local format = string.format
local setmetatable = setmetatable
local concat = table.concat

-- Valid hook names
local HOOK_NAMES = {
    before_all = true,
    before_each = true,
    after_each = true,
    after_all = true,
}

-- Spec metatable
local Spec = require('measure.metatable')('measure.spec')

-- Public API
return new_spec
```

## Core Components

### 1. Spec Class

Each spec is a metatable-based object:

```lua
--- @class measure.spec
--- @field hooks table<measure.spec.hookname, function> The hooks for the benchmark
--- @field describes table The describes for the benchmark
local Spec = require('measure.metatable')('measure.spec')
```

### 2. Hook Management

```lua
function Spec:set_hook(name, fn)
    if type(name) ~= 'string' then
        return false, format('name must be a string, got %s', type(name))
    elseif type(fn) ~= 'function' then
        return false, format('fn must be a function, got %s', type(fn))
    elseif not HOOK_NAMES[name] then
        return false,
               format('Invalid hook name %q, must be one of: %s', name,
                      concat(HOOK_NAMES), ', ')
    end

    local v = self.hooks[name]
    if type(v) == 'function' then
        return false, format('Hook %q already exists, it must be unique', name)
    end

    self.hooks[name] = fn
    return true
end
```

### 3. Describe Creation

```lua
function Spec:new_describe(name, namefn)
    -- Create new describe object
    local desc, err = new_describe(name, namefn)
    if not desc then
        return nil, err
    end

    -- Check for duplicate names
    if self.describes[name] then
        return nil, format('name %q already exists, it must be unique', name)
    end

    -- Add to describes list and map
    local idx = #self.describes + 1
    self.describes[idx] = desc
    self.describes[name] = desc
    return desc
end
```

## Key Functions

### new_spec()

Creates a new spec object:

```lua
local function new_spec()
    -- Create new spec
    return setmetatable({
        hooks = {},
        describes = {},
    }, Spec)
end
```

## Hook Types

The module supports four lifecycle hooks:

1. **before_all**: Runs once before all benchmarks in the spec
2. **before_each**: Runs before each individual benchmark iteration
3. **after_each**: Runs after each individual benchmark iteration  
4. **after_all**: Runs once after all benchmarks in the spec

## Spec Structure

Each spec object contains:

```
spec = {
    hooks = {
        before_all = function() ... end,    -- Optional
        before_each = function() ... end,   -- Optional
        after_each = function() ... end,    -- Optional
        after_all = function() ... end,     -- Optional
    },
    describes = {
        [1] = describe1,                    -- Indexed access
        [2] = describe2,
        ["Benchmark Name 1"] = describe1,   -- Name-based access
        ["Benchmark Name 2"] = describe2,
    }
}
```

## Integration Points

### Registry Module
- Registry validates spec objects using `tostring(spec)` pattern matching
- Registry stores spec references for file-based organization

### Describe Module
- Spec imports describe factory function
- Spec creates describe objects and manages their lifecycle
- Describe objects are stored both by index and name

### Metatable Module
- Spec uses metatable for consistent `__tostring` behavior
- Provides object identity and type checking

## Error Messages

The module provides descriptive error messages:
- `name must be a string, got number`
- `fn must be a function, got string`
- `Invalid hook name "invalid_hook", must be one of: "before_all", "before_each", "after_each", "after_all"`
- `Hook "before_all" already exists, it must be unique`
- `name "Test" already exists, it must be unique`

## Validation Rules

### Hook Validation
1. Hook name must be a string
2. Hook function must be a function
3. Hook name must be one of the four valid types
4. Each hook type can only be set once per spec

### Describe Validation
1. Describe name must be a string
2. Name function (if provided) must be a function
3. Describe names must be unique within a spec
4. Describes are accessible by both index and name

## Example Usage

```lua
local new_spec = require('measure.spec')

-- Create a new spec
local spec = new_spec()

-- Set lifecycle hooks
spec:set_hook('before_all', function()
    print('Setting up test environment')
end)

spec:set_hook('after_all', function()
    print('Cleaning up test environment')
end)

-- Create benchmark describes
local desc1 = spec:new_describe('String Concatenation')
desc1:run(function()
    local result = 'hello' .. 'world'
end)

local desc2 = spec:new_describe('Table Insert')
desc2:run(function()
    local t = {}
    table.insert(t, 'value')
end)

-- Access describes
print(#spec.describes)              -- 2
print(spec.describes[1])            -- desc1
print(spec.describes['Table Insert']) -- desc2
```

## Independence

Each spec object is completely independent:
- Separate hooks tables
- Separate describes tables  
- No shared state between specs
- Multiple specs can exist simultaneously

## Security Considerations

1. **Type Safety**: All inputs validated before storage
2. **Uniqueness**: Hook and describe names must be unique
3. **Isolation**: Each spec maintains independent state
4. **Validation**: Comprehensive input validation prevents invalid states

## Design Patterns

### Factory Pattern
- `new_spec()` acts as a factory function
- Returns fully initialized spec objects
- Consistent initialization across all specs

### Builder Pattern
- Specs are configured incrementally
- `set_hook()` and `new_describe()` build up the spec
- Each method provides validation and error handling

### Registry Pattern
- Describes are stored in both indexed and named access patterns
- Supports both iteration and direct lookup
- Maintains referential integrity