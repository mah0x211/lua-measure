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
local sqrt = math.sqrt

-- NaN value for error handling
local NaN = 0 / 0

--- Checks if a value is NaN (Not a Number)
--- @param v any The value to check
--- @return boolean ok true if the value is NaN, false otherwise
local function is_nan(v)
    return not v or v ~= v
end

--- Calculates the standard error of the mean from samples
--- @param samples measure.samples An instance of measure.samples
--- @return number Standard error, or NaN on error
local function stderr(samples)
    local std = samples:stddev()
    if is_nan(std) then
        return NaN
    end

    local count = #samples
    if count <= 1 then
        return 0.0
    end

    return std / sqrt(count)
end

return stderr
