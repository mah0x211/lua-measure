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
local mean = require('measure.stats.mean')

-- NaN value for error handling
local NaN = 0 / 0

--- Checks if a value is NaN (Not a Number)
--- @param v any The value to check
--- @return boolean ok true if the value is NaN, false otherwise
local function is_nan(v)
    return not v or v ~= v
end

--- Calculates the throughput (operations per second) from samples
--- @param samples measure.samples An instance of measure.samples
--- @return number Throughput in operations per second, or NaN on error
local function throughput(samples)
    local mean_time_ns = mean(samples)
    if is_nan(mean_time_ns) or mean_time_ns <= 0 then
        return NaN
    end

    -- Convert nanoseconds to seconds and calculate operations per second
    local mean_time_s = mean_time_ns / 1e9
    if mean_time_s <= 1e-15 then -- STATS_EPSILON equivalent
        return NaN
    end

    return 1.0 / mean_time_s
end

return throughput
