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
-- report.lua: Benchmark result reporting module
-- Provides high-quality output formatting similar to Criterion.rs and BenchmarkDotNet
local format = string.format
local concat = table.concat
local sysinfo = require('measure.sysinfo')

-- Format system information for display (compact format)
local function report_sysinfo()
    local info = sysinfo()
    local result = {}

    -- Hardware line: CPU, cores, total memory (exclude available memory)
    local hw_parts = {}
    if info.cpu.model then
        hw_parts[#hw_parts + 1] = info.cpu.model
    end
    if info.cpu.cores and info.cpu.threads then
        hw_parts[#hw_parts + 1] = format('%d cores (%d threads)',
                                         info.cpu.cores, info.cpu.threads)
    end
    if info.memory.total then
        hw_parts[#hw_parts + 1] = info.memory.total
    end
    if #hw_parts > 0 then
        result.Hardware = concat(hw_parts, ', ')
    end

    -- Host line: OS, version, arch, kernel version
    local host_parts = {}
    if info.os.name then
        host_parts[#host_parts + 1] = info.os.name
    end
    if info.os.version then
        host_parts[#host_parts + 1] = info.os.version
    end
    if info.os.arch then
        host_parts[#host_parts + 1] = info.os.arch
    end
    -- Add kernel version, but extract just the version number for brevity
    if info.os.kernel then
        local kernel_version = info.os.kernel:match('Version ([^:]+)')
        if kernel_version then
            host_parts[#host_parts + 1] = format('kernel=%s', kernel_version)
        end
    end
    if #host_parts > 0 then
        result.Host = concat(host_parts, ', ')
    end

    -- Runtime line: Lua version, JIT status (exclude GC info)
    local runtime_parts = {}
    if info.lua.version then
        runtime_parts[#runtime_parts + 1] = info.lua.version
    end
    if info.lua.jit then
        runtime_parts[#runtime_parts + 1] = format('JIT=%s',
                                                   info.lua.jit_status or
                                                       'unknown')
    else
        runtime_parts[#runtime_parts + 1] = 'no-JIT'
    end
    if #runtime_parts > 0 then
        result.Runtime = concat(runtime_parts, ', ')
    end

    -- Date line
    if info.timestamp then
        result.Date = info.timestamp
    end

    return result
end

-- Export the module
return report_sysinfo
