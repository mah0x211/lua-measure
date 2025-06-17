# Measure Registry Module Design Document

Version: 0.1.0  
Date: 2025-06-17

## Overview

The Measure Registry module manages file-scoped benchmark specifications and maintains a registry of all benchmarks organized by their source files. It provides isolation between benchmark files while tracking which benchmarks belong to which files.

## Purpose

This module serves as the central registry that:
- Creates and manages file-specific benchmark specifications
- Maintains a registry mapping filenames to their benchmark specifications
- Provides hook management for lifecycle functions
- Creates new benchmark describe objects

## Module Structure

```lua
-- Module: measure.registry
local describe = require('measure.describe')

-- Registry of all file specifications
local Registry = {}

-- Public API
return {
    get = get,
    new = new,
}
```

## Core Components

### 1. Registry Table

The global registry that maps benchmark filenames to their specifications:

```lua
--- @type table<string, measure.registry.spec>
local Registry = {}
```

### 2. Registry Spec Class

Each benchmark file gets its own spec instance:

```lua
--- @class measure.registry.spec
--- @field filename string The filename of the benchmark file
--- @field hooks table<string, function> The hooks for the benchmark
--- @field describes table<string, measure.describe> The describes for the benchmark
local Spec = {}
Spec.__index = Spec
```

### 3. Hook Management

```lua
function Spec:set_hook(name, fn)
    local HookNames = {
        before_all = true,
        before_each = true,
        after_each = true,
        after_all = true,
    }
    
    if not HookNames[name] then
        return false, ('Error: unknown hook %q'):format(tostring(name))
    elseif type(fn) ~= 'function' then
        return false, ('Error: %q must be a function'):format(name)
    end
    
    local v = self.hooks[name]
    if type(v) == 'function' then
        return false, ('Error: %q cannot be defined twice'):format(name)
    end
    
    self.hooks[name] = fn
    return true
end
```

### 4. Describe Creation

```lua
function Spec:new_describe(name, namefn)
    -- Create new describe object
    local desc, err = new_describe(name, namefn)
    if not desc then
        return nil, err
    end
    
    -- Check for duplicate names
    if self.describes[name] then
        return nil, ('name %q already exists, it must be unique'):format(name)
    end
    
    -- Add to describes list and map
    self.describes[#self.describes + 1] = desc
    self.describes[name] = desc
    return desc
end
```

## Key Functions

### new()

Creates or retrieves a spec for the current benchmark file:

```lua
local function new()
    -- Get the file path from the caller
    local filename = get_caller_filename()
    
    local spec = Registry[filename]
    if spec then
        return spec
    end
    
    -- Create new spec
    spec = setmetatable({
        filename = filename,
        hooks = {},
        describes = {},
    }, Spec)
    
    Registry[filename] = spec
    return spec
end
```

### get()

Returns the entire registry:

```lua
local function get()
    return Registry
end
```

## Registry Structure

The registry maintains a two-level structure:

```
Registry = {
    "/path/to/benchmark/example_bench.lua" = {
        filename = "/path/to/benchmark/example_bench.lua",
        hooks = {
            before_all = function() ... end,
            after_each = function() ... end,
        },
        describes = {
            [1] = describe1,
            [2] = describe2,
            ["Benchmark Name 1"] = describe1,
            ["Benchmark Name 2"] = describe2,
        }
    },
    "/path/to/benchmark/another_bench.lua" = { ... }
}
```

## Integration Points

### Measure Module
- Calls `new()` to get file-specific spec
- Uses spec methods for hook and describe management

### Describe Module
- Registry imports describe module to create instances
- Passes describe objects back to measure module

## File Isolation

Each benchmark file automatically gets its own spec when it requires the measure module. The filename is determined from the call stack, ensuring proper isolation without manual configuration.

## Error Messages

The module provides descriptive error messages:
- `Error: unknown hook "invalid_hook"`
- `Error: before_all must be a function`
- `Error: before_all cannot be defined twice`
- `name "Test" already exists, it must be unique`

## Usage Flow

1. Benchmark file requires measure module
2. Measure module calls `registry.new()` 
3. Registry creates/retrieves spec for that file
4. Spec manages hooks and describes for that file
5. Registry maintains mapping for runner access

## Security Considerations

1. **Filename-based Isolation**: Each file gets its own namespace
2. **Duplicate Prevention**: Names must be unique within a file
3. **Type Validation**: All inputs validated before storage
4. **No Cross-file Access**: Files cannot access other files' specs

## Example Implementation

```lua
-- In benchmark file: example_bench.lua
local measure = require('measure')

-- This creates a spec for "example_bench.lua" in the registry
measure.before_all = function() ... end

-- This adds a describe to the example_bench.lua spec
measure.describe('Test 1').run(function() ... end)
```

## Runner Integration

The runner can access all registered benchmarks:

```lua
local registry = require('measure.registry')
local all_specs = registry.get()

for filename, spec in pairs(all_specs) do
    print("Running benchmarks from:", filename)
    -- Execute hooks and benchmarks
end
```
