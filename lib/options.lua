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
local floor = math.floor
local INF_POS = math.huge
local INF_NEG = -INF_POS

--- @class measure.options
--- @field context table|function|nil Context for the benchmark
--- @field warmup number|nil Warmup iterations before measuring
--- @field gc_step number|nil Garbage collection step size for sampling
--- @field confidence_level number|nil confidence level in percentage (0-100, default: 95)
--- @field rciw number|nil relative confidence interval width in percentage (0-100, default: 5)

--- Prevent modification of measure.options
--- @param _ table The table being modified
--- @param key string The key being accessed
local function prevent_new_index(_, key)
    error(format('Attempt to modify measure.options: %q', tostring(key)), 2)
end

-- Create the measure.options object
local Options = require('measure.metatable')('measure.options')
Options.__newindex = prevent_new_index

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

    -- Validate warmup
    if opts.warmup ~= nil then
        local v = opts.warmup
        if type(v) ~= 'number' or v < 0 or v > 5 then
            return false, 'options.warmup must be a number between 0 and 5'
        end
    end

    -- Validate gc_step
    if opts.gc_step ~= nil then
        local v = opts.gc_step
        if type(v) ~= 'number' or v ~= v or v == INF_POS or v == INF_NEG or v ~=
            floor(v) then
            return false, 'options.gc_step must be an integer'
        end
    end

    -- Validate confidence level
    if opts.confidence_level ~= nil then
        local v = opts.confidence_level
        if type(v) ~= 'number' or v <= 0 or v > 100 then
            return false,
                   'options.confidence_level must be a number between 0 and 100'
        end
    end

    -- Validate relative confidence interval width (RCIW)
    if opts.rciw ~= nil then
        local v = opts.rciw
        if type(v) ~= 'number' or v <= 0 or v > 100 then
            return false, 'options.rciw must be a number between 0 and 100'
        end
    end

    return true
end

--- Configure benchmark execution parameters
--- @param opts table The options table
--- @return measure.options? options The validated options table
--- @return any err Error message if failed
local function new_options(opts)
    if type(opts) ~= 'table' then
        return nil, 'argument must be a table'
    end

    -- Validate options
    local ok, err = validate_options(opts)
    if not ok then
        return nil, err
    end

    -- Create the measure.options object
    return setmetatable({
        -- Set default values if not provided
        context = opts.context,
        warmup = opts.warmup,
        gc_step = opts.gc_step,
        confidence_level = opts.confidence_level or 95,
        rciw = opts.rciw or 5,
    }, Options)
end

return new_options
