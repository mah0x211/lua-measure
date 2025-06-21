# Measure Loadfiles Module Design Document

Version: 0.1.0  
Date: 2025-06-21

## Overview

The Measure Loadfiles module provides dynamic loading and execution of benchmark files. It scans directories or processes individual files, safely executes them, and collects registered benchmark specifications for the measurement system.

## Purpose

This module serves as the entry point for benchmark discovery and loading:
- Discovers benchmark files using pattern matching (`*_bench.lua`)
- Safely loads and executes Lua benchmark files
- Handles various error conditions gracefully
- Integrates with the registry system to collect benchmark specifications
- Provides a unified interface for both single file and directory-based loading

## Module Structure

```lua
-- Module: measure.loadfiles
local type = type
local find = string.find
local sub = string.sub
local format = string.format
local pcall = pcall
local popen = io.popen
local loadfile = loadfile
local pairs = pairs
local realpath = require('measure.realpath')
local getfiletype = require('measure.getfiletype')
local registry = require('measure.registry')

-- Internal function for safe file evaluation
local function evalfile(pathname)
-- Main public function
local function loadfiles(pathname)
-- Returns loadfiles function
return loadfiles
```

## Core Components

### 1. File Pattern Matching

Benchmark files must follow the `*_bench.lua` naming convention:

```lua
if find(entry, '_bench.lua$') then
    pathnames[#pathnames + 1] = pathname .. '/' .. entry
end
```

### 2. Path Type Detection

Supports both single files and directories:

```lua
local t = getfiletype(pathname)
if t == 'file' then
    pathnames[1] = pathname
elseif t == 'directory' then
    -- Directory processing
else
    error(format('pathname %s must point to a file or directory', pathname), 2)
end
```

### 3. Safe File Execution

Uses protected evaluation to handle errors gracefully:

```lua
local function evalfile(pathname)
    local f, err = loadfile(pathname)
    if not f then
        return false, err
    end
    
    local ok
    ok, err = pcall(f)
    if not ok then
        return false, err
    end
    return true
end
```

## Key Functions

### evalfile(pathname)

Safely evaluates a Lua file with comprehensive error handling:

```lua
--- Evaluate a Lua file and catch any errors.
--- @param pathname string The pathname of the Lua file to evaluate.
--- @return boolean ok true if the file was evaluated successfully, false otherwise.
--- @return string|nil err An error message if the evaluation failed, nil otherwise.
local function evalfile(pathname)
    -- Step 1: Load file (syntax validation)
    local f, err = loadfile(pathname)
    if not f then
        return false, err  -- Syntax error or file not found
    end

    -- Step 2: Execute file (runtime validation)  
    local ok
    ok, err = pcall(f)
    if not ok then
        return false, err  -- Runtime error
    end
    return true
end
```

**Error Handling:**
- **Syntax Errors**: Caught by `loadfile()` (missing parentheses, invalid syntax)
- **Runtime Errors**: Caught by `pcall()` (type errors, nil access, call errors)

### loadfiles(pathname)

Main function that discovers, loads, and processes benchmark files:

```lua
--- Load benchmark files from the specified pathname.
--- @param pathname string The pathname to load the benchmark files from.
--- @return measure.spec[] specs A table containing the loaded benchmark specs.
--- @throws error if the pathname is not a string.
--- @throws error if the pathname is neither a file nor a directory.
local function loadfiles(pathname)
    -- 1. Validate input
    if type(pathname) ~= 'string' then
        error('pathname must be a string', 2)
    end

    -- 2. Determine path type and collect files
    local pathnames = {}
    local t = getfiletype(pathname)
    
    -- 3. Process each discovered file
    local files = {}
    for _, filename in ipairs(pathnames) do
        filename = realpath(filename)
        
        -- 4. Safe execution with error logging
        print('loading ' .. filename)
        local ok, err = evalfile(filename)
        if not ok then
            print(format('failed to load %q: %s', filename, err), 2)
        end
        
        -- 5. Collect registered specifications
        local specs = registry.get()
        registry.clear()
        -- Process specs...
    end
    
    return files
end
```

## Registry Integration

### Specification Collection Process

1. **Execute File**: Benchmark file runs and registers specifications
2. **Collect Specs**: Get all registered specs from registry
3. **Clear Registry**: Clean registry for next file
4. **Filter Results**: Match specs to current file by key suffix

```lua
local specs = registry.get()
registry.clear()
for k, spec in pairs(specs) do
    -- Verify spec belongs to current file
    if sub(k, -#filename) == filename then
        files[#files + 1] = {
            filename = filename,
            spec = spec,
        }
    else
        print(format('ignore an invalid entry %s for %s', k, filename))
    end
end
```

## Error Handling Patterns

### 1. Syntax Errors (loadfile failure)
```lua
-- Example: syntax_error_bench.lua
local measure = require('measure')
local bench = measure.describe("syntax_error"
-- Missing closing parenthesis
```
**Result**: `loadfile()` returns nil and error message

### 2. Runtime Errors (pcall failure)
```lua
-- Example: type_error_bench.lua  
local function throw_error()
    local a = 1 + {}  -- Type error
end
throw_error()
```
**Result**: `pcall(f)` returns false and error message

### 3. File System Errors
```lua
-- Non-existent path
error(format('pathname %s must point to a file or directory', pathname), 2)

-- Directory listing failure
error(format('failed to list directory %s: %s', pathname, err), 2)
```

## Output Structure

### Return Value Format

```lua
{
    {
        filename = "/absolute/path/to/benchmark_bench.lua",
        spec = measure.spec_object
    },
    {
        filename = "/absolute/path/to/another_bench.lua", 
        spec = measure.spec_object
    }
}
```

### Logging Output

During execution, the module produces informational output:

```
loading /path/to/benchmark_bench.lua
loading /path/to/another_bench.lua
failed to load "/path/to/broken_bench.lua": syntax error message
File loaded but no benchmarks defined
```

## Integration Points

### Dependencies

- **`measure.realpath`**: Normalizes file paths to absolute paths
- **`measure.getfiletype`**: Determines if path is file, directory, or invalid
- **`measure.registry`**: Collects and manages benchmark specifications

### Usage by Other Modules

```lua
local loadfiles = require('measure.loadfiles')

-- Load single file
local specs = loadfiles('path/to/benchmark_bench.lua')

-- Load directory
local specs = loadfiles('path/to/benchmarks/')

-- Process results
for _, entry in ipairs(specs) do
    print("Loaded:", entry.filename)
    -- Execute benchmarks using entry.spec
end
```

## Directory Processing

### File Discovery

```lua
-- Use system ls command for directory listing
local ls, err = popen('ls -1 ' .. pathname)
if not ls then
    error(format('failed to list directory %s: %s', pathname, err), 2)
end

-- Filter for benchmark files
for entry in ls:lines() do
    if find(entry, '_bench.lua$') then
        pathnames[#pathnames + 1] = pathname .. '/' .. entry
    end
end
```

### Pattern Matching Rules

- **Include**: Files ending with `_bench.lua`
- **Exclude**: All other files (`.txt`, `.md`, `.lua` without `_bench` suffix)

```
✓ example_bench.lua      (included)
✓ performance_bench.lua  (included)  
✗ helper.lua             (excluded)
✗ readme.md              (excluded)
✗ bench.lua              (excluded - doesn't end with _bench.lua)
```

## Security Considerations

### 1. Safe Execution
- Uses `pcall()` to prevent crashes from user code
- Isolates file execution errors from system failures
- Continues processing other files when individual files fail

### 2. Input Validation
- Validates pathname parameter type
- Verifies file/directory existence before processing
- Handles invalid file types gracefully

### 3. Error Isolation
- Individual file failures don't stop batch processing
- Clear error messages for debugging
- Registry is cleared between files to prevent contamination

## Example Implementation

### Single File Loading
```lua
local loadfiles = require('measure.loadfiles')

-- Load single benchmark file
local specs = loadfiles('benchmarks/string_bench.lua')

for _, entry in ipairs(specs) do
    print("Loaded benchmark from:", entry.filename)
    -- entry.spec contains the benchmark specification
end
```

### Directory Loading  
```lua
local loadfiles = require('measure.loadfiles')

-- Load all benchmark files from directory
local specs = loadfiles('benchmarks/')

print(string.format("Loaded %d benchmark files", #specs))

for _, entry in ipairs(specs) do
    print("Processing:", entry.filename)
    -- Run benchmarks using entry.spec
end
```

### Error Handling
```lua
local loadfiles = require('measure.loadfiles')

-- Attempt to load with error handling
local ok, result = pcall(loadfiles, 'invalid/path')
if not ok then
    print("Failed to load benchmarks:", result)
else
    print(string.format("Successfully loaded %d benchmarks", #result))
end
```

## Best Practices

### 1. File Organization
- Place benchmark files in dedicated directories
- Use descriptive names with `_bench.lua` suffix
- Group related benchmarks in subdirectories

### 2. Error Recovery
- Monitor loading output for failed files
- Fix syntax errors before running benchmarks
- Test individual files before batch processing

### 3. Performance Considerations
- Large directories may take time to process
- Consider organizing benchmarks into smaller groups
- Monitor memory usage with many large benchmark files