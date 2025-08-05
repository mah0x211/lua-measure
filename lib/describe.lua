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
-- Module: measure.describe
-- This module defines the benchmark description objects that encapsulate
-- individual benchmark specifications.
--
local type = type
local find = string.find
local sub = string.sub
local format = string.format
local getinfo = require('measure.getinfo')

--- @class measure.describe.spec
--- @field name string The name of the benchmark
--- @field namefn function|nil Optional function to generate dynamic names
--- @field options measure.options|nil Options for the benchmark
--- @field setup function|nil Setup function for each iteration
--- @field setup_once function|nil Setup function that runs once before all iterations
--- @field run function|nil The function to benchmark
--- @field run_with_timer function|nil function to benchmark with timer
--- @field teardown function|nil Teardown function for cleanup after each iteration

--- @class measure.describe.fileinfo
--- @field source string The source of the benchmark (e.g., file path)
--- @field pathname string The pathname of the benchmark file
--- @field lineno number The line number where the benchmark is defined

--- @class measure.describe
--- @field spec measure.describe.spec The benchmark specification
--- @field fileinfo measure.describe.fileinfo? Information about the file where the benchmark is defined
local Describe = require('measure.metatable')(function(self)
    return format('measure.describe %q', self.spec.name)
end)

--- Define setup function for each benchmark iteration
--- @param fn function The setup function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:setup(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup then
        return false, 'cannot be defined twice'
    elseif spec.setup_once then
        return false, 'cannot be defined if setup_once() is defined'
    elseif spec.run or spec.run_with_timer then
        return false, 'must be defined before run() or run_with_timer()'
    end

    spec.setup = fn
    return true
end

--- Define setup function that runs once before all iterations
--- @param fn function The setup_once function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:setup_once(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup_once then
        return false, 'cannot be defined twice'
    elseif spec.setup then
        return false, 'cannot be defined if setup() is defined'
    elseif spec.run or spec.run_with_timer then
        return false, 'must be defined before run() or run_with_timer()'
    end

    spec.setup_once = fn
    return true
end

--- Define the function to benchmark
--- @param fn function The run function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:run(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.run then
        return false, 'cannot be defined twice'
    elseif spec.run_with_timer then
        return false, 'cannot be defined if run_with_timer() is defined'
    end

    spec.run = fn
    return true
end

--- Define the function to benchmark with timer
--- @param fn function The run_with_timer function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:run_with_timer(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.run_with_timer then
        return false, 'cannot be defined twice'
    elseif spec.run then
        return false, 'cannot be defined if run() is defined'
    end

    spec.run_with_timer = fn
    return true
end

--- Define teardown function for cleanup
--- @param fn function The teardown function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:teardown(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.teardown then
        return false, 'cannot be defined twice'
    elseif not spec.run and not spec.run_with_timer then
        return false, 'must be defined after run() or run_with_timer()'
    end

    spec.teardown = fn
    return true
end

--- Create a new benchmark describe instance
--- @param name string The name of the benchmark
--- @param namefn function? Optional function to generate dynamic names
--- @param opts measure.options? Optional options for the describe
--- @return measure.describe? desc The new describe instance
--- @return string? err Error message if failed
local function new_describe(name, namefn, opts)
    if type(name) ~= 'string' then
        return nil, format('name must be a string, got %q', type(name))
    elseif namefn ~= nil and type(namefn) ~= 'function' then
        return nil,
               format('namefn must be a function or nil, got %q', type(namefn))
    end

    --- Get the current working directory
    local PWD = assert(io.popen('pwd'):read('*l'))
    --- Get the file information for the current benchmark
    --- This will search the call stack for the first Lua file that matches the
    --- current working directory and has a `.lua` extension.
    local fileinfo
    for i = 1, 100 do
        local info = getinfo(i, 'file', 'source')
        if not info then
            break
        elseif sub(info.file.pathname, 1, #PWD) == PWD and
            find(info.file.source, '%.lua$') then
            fileinfo = {
                source = info.file.source,
                pathname = info.file.pathname,
                lineno = info.source.line_current,
            }
            break
        end
    end

    local desc = setmetatable({
        spec = {
            name = name,
            namefn = namefn,
            options = opts,
        },
        fileinfo = fileinfo,
    }, Describe)
    return desc
end

return new_describe
