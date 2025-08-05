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
-- Module: measure
-- This is the main entry point for the measure benchmarking library
--
local type = type
local tostring = tostring
local format = string.format
local error = error
local getinfo = require('measure.getinfo')
local new_spec = require('measure.spec')
local registry_get = require('measure.registry').get
local registry_add = require('measure.registry').add
local new_options = require('measure.options')

--- @type fun(name: string, namefn: function|nil, opts: measure.options?): measure.describe
local new_describe

--- Create a new describe proxy object
--- @param desc measure.describe The benchmark description object
--- @param opts measure.options? Optional options for the describe
local function new_describe_proxy(desc, opts)
    return setmetatable({}, {
        __tostring = function()
            return tostring(desc)
        end,
        __index = function(self, method)
            if type(method) ~= 'string' then
                error(format(
                          'Attempt to access measure.describe as a table: %q',
                          tostring(method)), 2)
            end

            if method == 'describe' then
                -- creates a new describe object with the same options
                if desc.spec.run or desc.spec.run_with_timer then
                    return function(name, namefn)
                        return new_describe(name, namefn, opts)
                    end
                end
                -- If the run or run_with_timer is not defined, it is not allowed to create a new describe
                error(format(
                          'Cannot append new describe to %q, run or run_with_timer is not defined',
                          desc.spec.name), 2)
            end

            return function(...)
                -- get the method of the description
                local fn = desc[method]
                if type(fn) ~= 'function' then
                    error(format('%s has no method %q', tostring(self), method),
                          2)
                end

                -- Call the method with the provided arguments
                local ok, err = fn(desc, ...)
                if not ok then
                    error(format('%s(): %s', method, err), 2)
                end

                return self
            end
        end,
    })
end

--- Get the measure.spec for the current file
--- @return measure.spec
local function get_spec()
    local info = getinfo(2, 'file')
    local spec = registry_get(info.file.source)
    if spec then
        -- Spec already exists, return it
        return spec
    end

    -- Create a new spec for this file
    spec = new_spec()
    local ok, err = registry_add(info.file.source, spec)
    if not ok then
        error(
            format('Failed to register spec for %q: %s', info.file.source, err),
            2)
    end
    return spec
end

-- Hook setter (__newindex)
-- Handles assignment of lifecycle hooks
local function hook_setter(_, key, fn)
    local spec = get_spec()
    local ok, err = spec:set_hook(key, fn)
    if not ok then
        error(err, 2)
    end
end

--- Create a new describer object
--- This is called when measure.describe() is invoked
--- @param name string Name of the measure.describe
--- @param namefn function Optional function to generate the name
--- @param opts measure.options? Optional options for the describe
--- @return measure.describe
function new_describe(name, namefn, opts)
    -- Create new benchmark description
    local spec = get_spec()
    local desc, err = spec:new_describe(name, namefn, opts)
    if not desc then
        error(err, 2)
    end

    return new_describe_proxy(desc, opts)
end

--- Prevent non-describe access to the measure object
--- This is used to ensure that only describe methods can be called
local function prevent_non_describe_access(_, key)
    error(format('Attempt to access %q field', tostring(key)), 2)
end

--- Set options for the measure object
--- This allows setting global options for all benchmarks.
--- @param opts measure.options Options to set
--- @return table proxy object that allows chaining describe calls
--- @throws error if options are invalid
local function set_options(opts)
    local options, err = new_options(opts)
    if not options then
        error(err, 2)
    end

    return setmetatable({
        describe = function(name, namefn)
            return new_describe(name, namefn, options)
        end,
    }, {
        __index = prevent_non_describe_access,
        __newindex = prevent_non_describe_access,
    })
end

local function allow_new_describe(_, key)
    if type(key) == 'string' then
        if key == 'describe' then
            return new_describe
        elseif key == 'options' then
            return set_options
        end
    end
    error(format('Attempt to access measure as a table: %q', tostring(key)), 2)
end

-- Create the measure object
local Measure = require('measure.metatable')('measure')
Measure.__index = allow_new_describe
Measure.__newindex = hook_setter

return setmetatable({}, Measure)
