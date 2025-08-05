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
-- Module: measure.spec
-- This module manages benchmark specifications
--
local type = type
local format = string.format
local setmetatable = setmetatable
local concat = table.concat
local tostring = tostring
local new_describe = require('measure.describe')

--- @alias measure.spec.hookname "before_all"|"before_each"|"after_each"|"after_all"

--- Valid hook names
--- @type table<measure.spec.hookname, boolean>
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

--- @class measure.spec
--- @field hooks table<measure.spec.hookname, function> The hooks for the benchmark
--- @field describes table The describes for the benchmark
local Spec = require('measure.metatable')('measure.spec')

--- Set a lifecycle hook
--- @param name measure.spec.hookname The hook name
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

--- Verify the last describe object
--- @return boolean ok true if the last describe has a valid run function
--- @return string[]? err Error message if the last describe is invalid
function Spec:verify_describes()
    local errs = {}
    for _, desc in ipairs(self.describes) do
        if type(desc.spec.run) ~= 'function' and type(desc.spec.run_with_timer) ~=
            'function' then
            -- Collect error message for invalid describe
            errs[#errs + 1] = format(
                                  '%s:%d: %s has not defined a run() or run_with_timer() function',
                                  desc.fileinfo.source, desc.fileinfo.lineno,
                                  tostring(desc))
        end
    end

    if #errs > 0 then
        -- Return all collected errors as a single string
        return false, errs
    end

    return true
end

--- Create a new describe object
--- @param name string The benchmark name
--- @param namefn function|nil Optional name generator function
--- @param opts measure.options? Optional options for the describe
--- @return measure.describe|nil desc The new describe object
--- @return string|nil err Error message if failed
function Spec:new_describe(name, namefn, opts)
    -- Create new describe object
    local desc, err = new_describe(name, namefn, opts)
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

--- Create a new spec object
--- @return measure.spec spec The spec for the current file
local function new_spec()
    -- Create new spec
    return setmetatable({
        hooks = {},
        describes = {},
    }, Spec)
end

return new_spec
