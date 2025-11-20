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
--- Formatting utilities for benchmark report values
--- Provides consistent formatting for time, memory, throughput and other metrics
---
--- Example usage:
---   local fmt = require('measure.report.format')
---   print(fmt.time(1500000))     -- "1.500 ms"
---   print(fmt.memory(2048))       -- "2.00 MB"
---   print(fmt.throughput(1500))   -- "1.50 K op/s"
---
local format = string.format

--- Format time duration in appropriate units
--- @param nanoseconds number? Time in nanoseconds
--- @return string Formatted time string or "N/A"
local function format_time(nanoseconds)
    if not nanoseconds or nanoseconds ~= nanoseconds then
        return "N/A"
    elseif nanoseconds >= 1e9 then
        return format("%0.3f s", nanoseconds / 1e9)
    elseif nanoseconds >= 1e6 then
        return format("%0.3f ms", nanoseconds / 1e6)
    elseif nanoseconds >= 1e3 then
        return format("%0.3f us", nanoseconds / 1e3)
    end
    return format("%0.0f ns", nanoseconds)
end

--- Format throughput in appropriate units
--- @param operations_per_second number? Operations per second
--- @return string Formatted throughput or "N/A"
local function format_throughput(operations_per_second)
    if not operations_per_second or operations_per_second ~=
        operations_per_second then
        return "N/A"
    elseif operations_per_second >= 1e9 then
        return format("%.2f G op/s", operations_per_second / 1e9)
    elseif operations_per_second >= 1e6 then
        return format("%.2f M op/s", operations_per_second / 1e6)
    elseif operations_per_second >= 1e3 then
        return format("%.2f K op/s", operations_per_second / 1e3)
    end
    return format("%.2f op/s", operations_per_second)
end

--- Format memory size
--- @param kilobytes number? Memory in kilobytes
--- @return string Formatted memory size or "N/A"
local function format_memory(kilobytes)
    if not kilobytes or kilobytes ~= kilobytes then
        return "N/A"
    elseif kilobytes >= 1048576 then
        return format("%.2f GB", kilobytes / 1048576)
    elseif kilobytes >= 1024 then
        return format("%.2f MB", kilobytes / 1024)
    end
    return format("%.2f KB", kilobytes)
end

--- Format GC step value
--- @param gc_step number? GC step value
--- @return string Formatted GC step description
local function format_gc_step(gc_step)
    assert(type(gc_step) == 'number', 'gc_step must be a number')

    if gc_step == -1 then
        return "disabled"
    elseif gc_step == 0 then
        return "full GC"
    end
    return format("%d KB", gc_step)
end

-- Export module
return {
    time = format_time,
    throughput = format_throughput,
    memory = format_memory,
    gc_step = format_gc_step,
}
