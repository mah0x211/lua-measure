# Measure Registry Module Design Document

Version: 0.3.0  
Date: 2025-06-21

## Overview

The Measure Registry module manages explicit registration of benchmark specifications and maintains a registry of all benchmarks organized by their identification keys. It provides a simple, explicit registration model where specs must be explicitly registered with string keys.

## Purpose

This module serves as the central registry that:
- Maintains a registry mapping string keys to their benchmark specifications
- Provides explicit registration and retrieval API
- Supports testing with registry clearing functionality
- Uses keys as display identifiers for benchmark runners

## Module Structure

```lua
-- Module: measure.registry
local type = type
local format = string.format
local find = string.find
local tostring = tostring
-- Registry of all specifications
local Registry = {}

-- Public API
return {
    get = get,
    add = add_spec,
    clear = clear,
}
```

## Core Components

### 1. Registry Table

The global registry that maps benchmark keys to their specifications:

```lua
--- @type table<string, measure.spec>
local Registry = {}
```

### 2. Spec Type Validation

Only measure.spec objects can be registered:

```lua
elseif not find(tostring(spec), '^measure%.spec') then
    return false, format('spec must be a measure.spec, got %q', tostring(spec))
end
```

## Key Functions

### add_spec()

Registers a new benchmark specification associated with a key:

```lua
local function add_spec(key, spec)
    if type(key) ~= 'string' then
        return false, format('key must be a string, got %s', type(key))
    elseif not find(tostring(spec), '^measure%.spec') then
        return false, format('spec must be a measure.spec, got %q', tostring(spec))
    elseif Registry[key] then
        return false, format('key %q already exists in the registry', key)
    end

    Registry[key] = spec
    return true
end
```

### get()

Returns the entire registry or a specific spec by key:

```lua
local function get(key)
    if key == nil then
        return Registry
    elseif type(key) == 'string' then
        return Registry[key]
    end
    error(format('key must be a string or nil, got %s', type(key)), 2)
end
```

### clear()

Clears the registry (for testing purposes):

```lua
local function clear()
    Registry = {}
end
```

## Registry Structure

The registry maintains a simple mapping structure:

```
Registry = {
    "@/path/to/benchmark/example_bench.lua" = spec1,
    "@/path/to/benchmark/another_bench.lua" = spec2,
}
```

Where each spec is a `measure.spec` object containing:
- `hooks`: Table of lifecycle hooks (`before_all`, `before_each`, `after_each`, `after_all`)
- `describes`: Table of benchmark describe objects indexed by number and name

## Integration Points

### Measure Module
- Uses `registry.add()` to register specs explicitly
- Creates `measure.spec` objects independently
- Uses `registry.get()` to access all registered specs

### Spec Module
- Registry validates that only `measure.spec` objects are registered
- Registry stores spec references but doesn't manage spec creation

## Explicit Registration Model

This module requires explicit registration of specifications:
1. Create a `measure.spec` object
2. Call `registry.add(key, spec)` to register it
3. Registry validates key type and spec type
4. Registry stores the association for later retrieval

## Error Messages

The module provides descriptive error messages:
- `key must be a string, got number`
- `spec must be a measure.spec, got "string"`
- `key "duplicate_key" already exists in the registry`

## Usage Flow

1. Create a `measure.spec` object
2. Set hooks and describes on the spec
3. Call `registry.add(key, spec)` to register the spec
4. Registry validates key and spec type
5. Registry stores the association for runner access
6. Use `registry.get()` to retrieve all registered specs

## Security Considerations

1. **Type Safety**: Only `measure.spec` objects can be registered
2. **Input Validation**: All parameters validated before registration  
3. **Explicit Control**: No automatic behavior, all registration is explicit
4. **Duplicate Prevention**: Keys must be unique across the registry

## Example Implementation

```lua
-- In benchmark file: example_bench.lua
local registry = require('measure.registry')
local new_spec = require('measure.spec')

-- Create a new spec
local spec = new_spec()

-- Configure the spec
spec:set_hook('before_all', function() print('Starting tests') end)
local desc = spec:new_describe('Performance Test')
desc:run(function() 
    -- benchmark code here
end)

-- Register the spec
local ok, err = registry.add('@example_bench.lua', spec)
if not ok then
    error('Failed to register spec: ' .. err)
end
```

## Runner Integration

The runner can access all registered benchmarks:

```lua
local registry = require('measure.registry')
local all_specs = registry.get()

for key, spec in pairs(all_specs) do
    print("Running benchmarks from:", key)
    -- Execute hooks and benchmarks
end
```
