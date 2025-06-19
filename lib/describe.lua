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
local format = string.format
local floor = math.floor

--- @class measure.describe.spec.options
--- @field context table|function|nil Context for the benchmark
--- @field repeats number|function|nil Number of repeats for the benchmark
--- @field warmup number|function|nil Warmup iterations before measuring
--- @field sample_size number|function|nil Sample size for the benchmark

--- @class measure.describe.spec
--- @field name string The name of the benchmark
--- @field namefn function|nil Optional function to generate dynamic names
--- @field options measure.describe.spec.options|nil Options for the benchmark
--- @field setup function|nil Setup function for each iteration
--- @field setup_once function|nil Setup function that runs once before all iterations
--- @field run function|nil The function to benchmark
--- @field measure function|nil Custom measure function for timing
--- @field teardown function|nil Teardown function for cleanup after each iteration

--- @class measure.describe
--- @field spec measure.describe.spec The benchmark specification
local Describe = require('measure.metatable')(function(self)
    return format('measure.describe %q', self.spec.name)
end)

--- Validate options table values
--- @param opts table The options table to validate
--- @return boolean ok True if valid
--- @return string|nil err Error message if invalid
local function validate_options(opts)
    -- Validate context
    if opts.context ~= nil then
        local t = type(opts.context)
        if t ~= 'table' and t ~= 'function' then
            return false, 'options.context must be a table or a function'
        end
    end

    -- Validate repeats
    if opts.repeats ~= nil then
        local t = type(opts.repeats)
        if t ~= 'number' and t ~= 'function' then
            return false, 'options.repeats must be a number or a function'
        end
        if t == 'number' and
            (opts.repeats <= 0 or opts.repeats ~= floor(opts.repeats)) then
            return false, 'options.repeats must be a positive integer'
        end
    end

    -- Validate warmup
    if opts.warmup ~= nil then
        local t = type(opts.warmup)
        if t ~= 'number' and t ~= 'function' then
            return false, 'options.warmup must be a number or a function'
        end
        if t == 'number' and
            (opts.warmup < 0 or opts.warmup ~= floor(opts.warmup)) then
            return false, 'options.warmup must be a non-negative integer'
        end
    end

    -- Validate sample_size
    if opts.sample_size ~= nil then
        local t = type(opts.sample_size)
        if t ~= 'number' and t ~= 'function' then
            return false, 'options.sample_size must be a number or a function'
        end
        if t == 'number' and
            (opts.sample_size <= 0 or opts.sample_size ~=
                floor(opts.sample_size)) then
            return false, 'options.sample_size must be a positive integer'
        end
    end

    return true
end

--- Configure benchmark execution parameters
--- @param opts table The options table
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:options(opts)
    local spec = self.spec
    if type(opts) ~= 'table' then
        return false, 'argument must be a table'
    elseif spec.options then
        return false, 'options cannot be defined twice'
    elseif spec.setup or spec.setup_once or spec.run or spec.measure then
        return false,
               'options must be defined before setup(), setup_once(), run() or measure()'
    end

    -- Validate options
    local ok, err = validate_options(opts)
    if not ok then
        return false, err
    end

    spec.options = opts
    return true
end

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
    elseif spec.run or spec.measure then
        return false, 'must be defined before run() or measure()'
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
    elseif spec.run or spec.measure then
        return false, 'must be defined before run() or measure()'
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
    elseif spec.measure then
        return false, 'cannot be defined if measure() is defined'
    end

    spec.run = fn
    return true
end

--- Define the measure function for custom timing
--- @param fn function The measure function
--- @return boolean ok True if successful
--- @return string|nil err Error message if failed
function Describe:measure(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.measure then
        return false, 'cannot be defined twice'
    elseif spec.run then
        return false, 'cannot be defined if run() is defined'
    end

    spec.measure = fn
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
    elseif not spec.run and not spec.measure then
        return false, 'must be defined after run() or measure()'
    end

    spec.teardown = fn
    return true
end

--- Create a new benchmark describe instance
--- @param name string The name of the benchmark
--- @param namefn function|nil Optional function to generate dynamic names
--- @return measure.describe|nil desc The new describe instance
--- @return string|nil err Error message if failed
local function new_describe(name, namefn)
    if type(name) ~= 'string' then
        return nil, format('name must be a string, got %q', type(name))
    elseif namefn ~= nil and type(namefn) ~= 'function' then
        return nil,
               format('namefn must be a function or nil, got %q', type(namefn))
    end

    local desc = setmetatable({
        spec = {
            name = name,
            namefn = namefn,
        },
    }, Describe)
    return desc
end

return new_describe
