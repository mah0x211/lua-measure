--
-- Copyright (C) 2025 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- Module: measure.registry
-- This module manages file-scoped benchmark specifications
--
local describe = require('measure.describe')
local getinfo = require('measure.getinfo')
local type = type
local format = string.format
local setmetatable = setmetatable
local concat = table.concat

--- Registry of all file specifications
--- @type table<string, measure.registry.spec>
local Registry = {}

--- @alias measure.registry.hookname "before_all"|"before_each"|"after_each"|"after_all"

--- @class measure.registry.spec
--- @field filename string The filename of the benchmark file
--- @field hooks table<measure.registry.hookname, function> The hooks for the benchmark
--- @field describes table The describes for the benchmark
local Spec = {}
Spec.__index = Spec

--- Valid hook names
--- @type table<measure.registry.hookname, boolean>
local HOOK_NAMES = {}
for _, name in ipairs({
    'before_all',
    'before_each',
    'after_each',
    'after_all',
}) do
    HOOK_NAMES[name] = true
    HOOK_NAMES[#HOOK_NAMES + 1] = format('%q', name)
end

--- Set a lifecycle hook
--- @param name measure.registry.hookname The hook name
--- @param fn function The hook function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
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

--- Create a new describe object
--- @param name string The benchmark name
--- @param namefn function|nil Optional name generator function
--- @return measure.describe|nil desc The new describe object
--- @return string|nil err Error message if failed
function Spec:new_describe(name, namefn)
    -- Create new describe object
    local desc, err = describe(name, namefn)
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

--- Create or retrieve a spec for the current benchmark file
--- @return measure.registry.spec spec The spec for the current file
local function new_spec()
    -- Get the file path from the caller
    local info = getinfo(1, 'source')
    if not info or not info.source then
        error("Failed to identify caller")
    end

    local filename = info.source.pathname
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

--- Get the entire registry
--- @return table<string, measure.registry.spec> registry All registered specs
local function get()
    return Registry
end

--- Clear the registry.
--- This function used for testing purposes only.
local function clear()
    Registry = {}
end

-- Public API
return {
    get = get,
    new = new_spec,
    clear = clear,
}
