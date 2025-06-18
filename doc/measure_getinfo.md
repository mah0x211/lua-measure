# Measure Getinfo Module Design Document

Version: 0.1.0  
Date: 2025-06-18

## Overview

The Measure Getinfo module provides structured access to Lua's source and debug information. It offers a simplified and focused API compared to the native `debug.getinfo` function, allowing users to retrieve specific information fields with automatic source code extraction.

## Purpose

This module serves as a debugging utility that:
- Provides structured access to source and debug information
- Extracts and formats file information with pathname parsing
- Reads source code directly from files when available (Lua functions only)
- Focuses on the most commonly used debug information fields

## Module Structure

```lua
-- Module: measure.getinfo
local getinfo = require('measure.getinfo')

-- The module exports a single function
return getinfo
```

## API Function

### getinfo(...)

Retrieves structured source and debug information based on the specified fields.

```lua
--- Get source information with flexible API
--- @param ... any (level, field1, field2, ...) or (field1, field2, ...)
--- @return table result The structured source information
function getinfo(...)
```

#### Parameters

The function accepts arguments in two formats:

1. **With explicit level**: `getinfo(level, field1, field2, ...)`
   - `level` (number): Stack level where 0 refers to the function calling getinfo
   - `field1, field2, ...` (string): Field names to retrieve

2. **Without level**: `getinfo(field1, field2, ...)`
   - `field1, field2, ...` (string): Field names to retrieve
   - Stack level defaults to the caller of getinfo

#### Return Value

Returns a table containing the requested fields.

#### Errors

The function throws errors for:
- No arguments provided
- Invalid first argument type (not number or string)
- Negative level value
- Non-string field arguments
- Unknown field names
- Stack level beyond the call stack

## Available Fields

The module supports exactly three fields:

### source

Source information including file details and source code.

```lua
{
    source = {
        name = "example.lua",           -- Filename only (or full source for non-file sources)
        pathname = "/path/to/example.lua", -- Full pathname (or source string)
        line_head = 10,                 -- First line of function definition
        line_tail = 20,                 -- Last line of function definition
        line_current = 15,              -- Currently executing line
        code = "function foo()\n...",   -- Actual source code (Lua functions only)
    }
}
```

For Lua functions loaded from files, the `code` field contains the actual source code. For C functions or code loaded from strings, `code` may be nil.

### name

Function name information.

```lua
{
    name = {
        name = "foo",                   -- Function name (may be nil)
        what = "global",                -- How it was called (global, local, method, field, etc.)
    }
}
```

### function

Function object and metadata.

```lua
{
    ["function"] = {
        type = "Lua",                   -- "Lua", "C", or "main"
        nups = 2,                       -- Number of upvalues
    }
}
```

## Usage Examples

### Get Source Information

```lua
local getinfo = require('measure.getinfo')

-- Get current source info
local info = getinfo(0, 'source')
print(info.source.name)        -- "example.lua"
print(info.source.pathname)    -- "/path/to/example.lua"
print(info.source.line_current) -- Current line number
if info.source.code then
    print(info.source.code)    -- Function source code
end
```

### Get Multiple Fields

```lua
-- Get source, name, and function info
local info = getinfo(0, 'source', 'name', 'function')

print(info.source.name)
print(info.name.what)
print(info['function'].type)  -- "Lua" or "C"
```

### Get Function Information

```lua
local function vararg_func(a, b, ...)
    local info = getinfo(0, 'function')
    print("Upvalues:", info['function'].nups)
end

vararg_func(1, 2, 3, 4)
```

### Default Level Usage

```lua
local function get_my_info()
    -- Without level, defaults to the caller
    return getinfo('source')
end

local info = get_my_info()
print(info.source.name)  -- Will show the file where get_my_info was called
```

## Integration with measure.registry

The measure.registry module uses getinfo to identify which file is creating benchmark specifications:

```lua
local getinfo = require('measure.getinfo')

function registry.new()
    -- Get the file path from the caller
    local info = getinfo(1, 'source')
    if not info or not info.source then
        error("Failed to identify caller")
    end
    
    local filename = info.source.pathname
    -- Use filename as registry key...
end
```

## Implementation Notes

1. **Stack Level Adjustment**: 
   - With explicit level: Adds 2 to account for getinfo and debug.getinfo
   - Without level: Uses level 2 as default (getinfo -> caller)

2. **Source Reading**: Source code is only available for Lua functions loaded from files. C functions and string-loaded code won't have the `code` field populated.

3. **Field Validation**: Only `source`, `name`, and `function` are valid fields. Any other field name causes an error.

4. **Performance**: The function calls `debug.getinfo` once with all necessary options, then extracts only the requested fields.

## Error Handling

The module provides clear error messages for common mistakes:

```lua
-- No arguments
getinfo()
-- Error: at least one argument is required

-- Invalid first argument type
getinfo(true, 'source')
-- Error: first argument must be number or string, got boolean

-- Negative level
getinfo(-1, 'source')
-- Error: level must be a non-negative integer, got -1

-- Invalid field type
getinfo(0, 123)
-- Error: field #2 must be a string, got number

-- Unknown field
getinfo(0, 'unknown')
-- Error: field #2 must be one of "function", "name", "source", got "unknown"

-- Stack level too high
getinfo(100, 'source')
-- Error: failed to get debug info for level 102
```

## Version History

- **0.1.0** (2025-06-18): Initial version with full field support
