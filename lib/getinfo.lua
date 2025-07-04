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
-- Module: measure.getinfo
-- This module provides structured access to Lua's source and debug information
--
local debug_getinfo = debug.getinfo
local type = type
local format = string.format
local match = string.match
local gsub = string.gsub
local sub = string.sub
local lower = string.lower
local open = io.open
local error = error
local concat = table.concat
local realpath = require('measure.realpath')

-- Get current working directory
local PWD = assert(io.popen('pwd'):read('*l'))

--- Read source code from file
--- @param pathname string The file path
--- @param head number Starting line number
--- @param tail number Ending line number
--- @return string|nil code The source code or nil if failed
local function read_source(pathname, head, tail)
    assert(type(pathname) == 'string', 'pathname must be a string')
    assert(type(head) == 'number' and head >= 0,
           'head must be a non-negative integer')
    assert(type(tail) == 'number' and tail >= 0,
           'tail must be a non-negative integer')
    assert(head <= tail, 'head must be less than or equal to tail')

    local file, err = open(pathname, 'r')
    if not file then
        error(format('failed to open file %q: %s', pathname, err))
    end

    -- collect lines from the file
    local code = {}
    local lineno = 0
    for line in file:lines() do
        lineno = lineno + 1
        if lineno >= head and lineno <= tail then
            code[#code + 1] = line
        elseif lineno > tail then
            break
        end
    end
    file:close()

    -- If no code was collected, raise an error
    if #code == 0 then
        error(format('no source code found in %q from line %d to %d', pathname,
                     head, tail))
    end

    return concat(code, '\n')
end

--- Extract filename from source path
--- @param source string The source path
--- @return string name The filename
--- @return string pathname The full pathname
local function extract_filename(source)
    -- get basename from source
    local name = match(source, '([^/\\]+)$')
    local pathname = gsub(source, '^@', '')
    if sub(pathname, 1, 1) ~= '/' then
        -- if pathname is not absolute, prepend PWD
        pathname = PWD .. '/' .. pathname
    end
    pathname = realpath(pathname)
    return name, pathname
end

--- Get structured file information
--- @param info table The debug information table
--- @return table file The structured file information
local function getinfo_file(info)
    -- Extract filename and pathname from source
    local name, pathname = extract_filename(info.source)
    return {
        source = info.source,
        name = name,
        pathname = pathname,
        basedir = PWD,
    }
end

--- Get structured source information
--- @param info table The debug information table
--- @return table source The structured source information
local function getinfo_source(info)
    local src = {
        line_head = info.linedefined,
        line_tail = info.lastlinedefined,
        line_current = info.currentline,
    }
    if lower(info.what) == 'lua' then
        local file = getinfo_file(info)
        -- If the source is Lua code, read the source code from the file
        src.code = read_source(file.pathname, info.linedefined,
                               info.lastlinedefined)
    end
    return src
end

--- Get structured function information
--- @param info table The debug information table
--- @return table func The structured function information
local function getinfo_func(info)
    return {
        type = info.what,
        nups = info.nups,
    }
end

--- Get structured function name information
--- @param info table The debug information table
--- @return table name The structured function name information
local function getinfo_name(info)
    return {
        name = info.name,
        what = info.namewhat,
    }
end

local FIELD_HANDLERS = {}
for k, f in pairs({
    name = getinfo_name,
    file = getinfo_file,
    source = getinfo_source,
    ['function'] = getinfo_func,
}) do
    -- Register each field handler
    FIELD_HANDLERS[k] = f
    FIELD_HANDLERS[#FIELD_HANDLERS + 1] = format('%q', k)
end

--- Get source information with flexible API
--- @param ... any (level, field1, field2, ...) or (field1, field2, ...)
--- @return table result The structured source information
local function getinfo(...)
    local narg = select('#', ...)
    if narg == 0 then
        error('at least one argument is required', 2)
    end

    local level = ...
    local t = type(level)
    local idx = 1
    local argv = {
        ...,
    }
    if t == 'number' then
        -- validate level is a non-negative integer
        if level < 0 then
            error(format('level must be a non-negative integer, got %d', level),
                  2)
        end

        -- level+1 that means are:
        --  * if level 0, get the caller of this function
        --  * if level 1, get the caller of the caller
        level = level + 2
        -- start from second argument
        idx = 2
    elseif t == 'string' then
        -- default level is 2 to get the caller of this function
        level = 2
    else
        error(format('first argument must be number or string, got %s', t), 2)
    end

    -- Get whole debug information
    local info = debug_getinfo(level, 'nSluf')
    if not info then
        error(format('failed to get debug info for level %d', level), 2)
    end

    local res = {}
    for i = idx, narg do
        local f = argv[i]
        if type(f) ~= 'string' then
            error(format('field #%d must be a string, got %s', i, type(f)), 2)
        end

        local handler = FIELD_HANDLERS[f]
        if not handler then
            error(format('field #%d must be one of %s, got %q', i,
                         concat(FIELD_HANDLERS, ', '), f), 2)
        end

        res[f] = handler(info)
    end

    return res
end

return getinfo
