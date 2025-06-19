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
-- Module: measure.metatable
-- This module provides a function to create a base metatable
--
local type = type
local error = error
local tostring = tostring
local format = string.format
local match = string.match

--- Create a base metatable with a custom __tostring metamethod.
--- The name can be a string or a function that returns a string representation
--- of the metatable.
--- @param name string|function
--- @return table The new metatable object
local function new_metatable(name)
    local mt = {}

    local tostringfn = name
    if type(name) == 'string' then
        if name == '' then
            error('name cannot be an empty string', 2)
        end
        name = format('%s: %s', name, match(tostring(mt), '(0x.+)'))
        tostringfn = function()
            return name
        end
    elseif type(name) ~= 'function' then
        error(format('name must be a string or function, got %s', type(name)), 2)
    end

    mt.__index = mt
    mt.__tostring = tostringfn
    return mt
end

return new_metatable
