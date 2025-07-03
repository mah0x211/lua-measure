--
-- Copyright (C) 2025 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--
local p25 = require('measure.stats.p25')
local p75 = require('measure.stats.p75')

-- NaN value for error handling
local NaN = 0 / 0

--- Checks if a value is NaN (Not a Number)
--- @param v any The value to check
--- @return boolean ok true if the value is NaN, false otherwise
local function is_nan(v)
    return not v or v ~= v
end

--- Calculates the interquartile range (IQR) from samples
--- @param samples measure.samples An instance of measure.samples
--- @return number IQR (75th percentile - 25th percentile), or NaN on error
local function iqr(samples)
    local q1 = p25(samples)
    local q3 = p75(samples)

    if is_nan(q1) or is_nan(q3) then
        return NaN
    end

    return q3 - q1
end

return iqr
