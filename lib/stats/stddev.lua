--
--  Copyright (C) 2025 Masatoshi Fukunaga
--
--  Permission is hereby granted, free of charge, to any person obtaining a
--  copy of this software and associated documentation files (the "Software"),
--  to deal in the Software without restriction, including without limitation
--  the rights to use, copy, modify, merge, publish, distribute, sublicense,
--  and/or sell copies of the Software, and to permit persons to whom the
--  Software is furnished to do so, subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included in
--  all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
--  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
--  DEALINGS IN THE SOFTWARE.
--
local sqrt = math.sqrt
local variance = require('measure.stats.variance')
-- NaN value for error handling
local NaN = 0 / 0

--- Calculate standard deviation of samples
--- @param samples measure.samples object
--- @return number standard deviation value or NaN on error
local function stddev(samples)
    -- Protect against nil input and other errors from variance module
    local ok, var = pcall(variance, samples)
    if not ok then
        -- Re-throw the error to maintain compatibility with C implementation
        error(var, 2)
    end

    -- Check for NaN (NaN is not equal to itself in Lua)
    if var ~= var then
        return NaN
    end

    return sqrt(var)
end

return stddev
