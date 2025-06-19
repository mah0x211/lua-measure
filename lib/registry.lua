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
local type = type
local format = string.format
local find = string.find
local tostring = tostring
local open = io.open

--- Registry of all file specifications
--- @type table<string, measure.spec>
local Registry = {}

--- Register a new benchmark specification associated with a filename
--- @param filename string The filename to associate with the spec
--- @param spec measure.spec The benchmark specification to register
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
local function add_spec(filename, spec)
    if type(filename) ~= 'string' then
        return false,
               format('filename must be a string, got %s', type(filename))
    elseif not find(tostring(spec), '^measure%.spec') then
        return false,
               format('spec must be a measure.spec, got %q', tostring(spec))
    elseif Registry[filename] then
        -- filename already exists in the registry
        return false,
               format('filename %q already exists in the registry', filename)
    end

    -- Ensure filename can open as a file
    local file = open(filename, 'r')
    if not file then
        -- filename is not a valid file
        return false,
               format('filename %q must point to an existing file', filename)
    end
    file:close()

    Registry[filename] = spec
    return true
end

--- Get the benchmark specification for a given filename or all specs if nil
--- @param filename string|nil The filename to retrieve spec for, or nil for all
--- @return measure.spec|table<string, measure.spec>
local function get(filename)
    if filename == nil then
        return Registry
    elseif type(filename) == 'string' then
        return Registry[filename]
    end
    error(format('filename must be a string or nil, got %s', type(filename)), 2)
end

--- Clear the registry.
--- This function used for testing purposes only.
local function clear()
    Registry = {}
end

-- Public API
return {
    get = get,
    add = add_spec,
    clear = clear,
}
