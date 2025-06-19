# Measure Registry Module Design Document

Version: 0.2.0  
Date: 2025-06-19

## Overview

The Measure Registry module manages explicit registration of benchmark specifications and maintains a registry of all benchmarks organized by their source files. It provides a simple, explicit registration model where specs must be explicitly registered with filenames.

## Purpose

This module serves as the central registry that:
- Maintains a registry mapping filenames to their benchmark specifications
- Validates file existence for registered specs
- Provides explicit registration and retrieval API
- Supports testing with registry clearing functionality

## Module Structure

```lua
-- Module: measure.registry
local type = type
local format = string.format
local find = string.find
local tostring = tostring
local open = io.open

-- Registry of all file specifications
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

The global registry that maps benchmark filenames to their specifications:

```lua
--- @type table<string, measure.spec>
local Registry = {}
```

### 2. File Validation

All registered specs must be associated with existing files:

```lua
-- Ensure filename can open as a file
local file = io.open(filename, 'r')
if not file then
    -- filename is not a valid file
    return false, format('filename %q must point to an existing file', filename)
end
file:close()
```

### 3. Spec Type Validation

Only measure.spec objects can be registered:

```lua
elseif not find(tostring(spec), '^measure%.spec') then
    return false, format('spec must be a measure.spec, got %q', tostring(spec))
end
```

## Key Functions

### add_spec()

Registers a new benchmark specification associated with a filename:

```lua
local function add_spec(filename, spec)
    if type(filename) ~= 'string' then
        return false, format('filename must be a string, got %s', type(filename))
    elseif not find(tostring(spec), '^measure%.spec') then
        return false, format('spec must be a measure.spec, got %q', tostring(spec))
    end

    -- Ensure filename can open as a file
    local file = open(filename, 'r')
    if not file then
        return false, format('filename %q must point to an existing file', filename)
    end
    file:close()

    Registry[filename] = spec
    return true
end
```

### get()

Returns the entire registry:

```lua
local function get()
    return Registry
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
    "/path/to/benchmark/example_bench.lua" = spec1,
    "/path/to/benchmark/another_bench.lua" = spec2,
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

Unlike automatic file-based registration, this module requires explicit registration:
1. Create a `measure.spec` object
2. Call `registry.add(filename, spec)` to register it
3. Registry validates file existence and spec type
4. Registry stores the association for later retrieval

## Error Messages

The module provides descriptive error messages:
- `filename must be a string, got number`
- `spec must be a measure.spec, got "string"`
- `filename "nonexistent.lua" must point to an existing file`

## Usage Flow

1. Create a `measure.spec` object
2. Set hooks and describes on the spec
3. Call `registry.add(filename, spec)` to register the spec
4. Registry validates filename and spec type
5. Registry stores the association for runner access
6. Use `registry.get()` to retrieve all registered specs

## Security Considerations

1. **File Existence Validation**: All filenames must point to existing files
2. **Type Safety**: Only `measure.spec` objects can be registered
3. **Input Validation**: All parameters validated before registration
4. **Explicit Control**: No automatic behavior, all registration is explicit

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
local ok, err = registry.add('example_bench.lua', spec)
if not ok then
    error('Failed to register spec: ' .. err)
end
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
