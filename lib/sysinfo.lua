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
-- sysinfo.lua: System information gathering module
-- Collects information about the host environment, including CPU, memory, OS, and Lua runtime
local open = io.open
local popen = io.popen
local format = require('string.format')

--- Execute shell command and capture output
--- @param cmd string shell command to execute
--- @return string|nil command output with trailing whitespace removed, or nil on failure
local function exec_command(cmd)
    local handle = popen(cmd, 'r')
    if not handle then
        return nil
    end
    local result = handle:read('*a')
    handle:close()
    if result then
        -- Remove trailing newline
        result = result:gsub('%s+$', '')
    end
    return result
end

--- Detect the operating system type
--- @return string|nil OS type ('Linux', 'OSX', 'BSD', etc.) or nil if detection fails
local function detect_os_type()
    local os_type = nil
    if rawget(_G, 'jit') then
        os_type = jit.os
    end
    if not os_type then
        local handle = popen('uname 2>/dev/null')
        if handle then
            local uname = handle:read('*l')
            handle:close()
            if uname == 'Darwin' then
                os_type = 'OSX'
            else
                os_type = uname
            end
        end
    end
    return os_type
end

--- Get OS information for Linux systems
--- @return table OS information with name, version, kernel, and arch fields
local function get_os_info_linux()
    local info = {
        name = exec_command('uname -s') or 'Unknown',
        version = exec_command('uname -r') or 'Unknown',
        kernel = exec_command('uname -v') or 'Unknown',
        arch = exec_command('uname -m') or 'Unknown',
    }

    -- Get detailed OS version
    local lsb_release = exec_command('lsb_release -d 2>/dev/null')
    if lsb_release then
        info.version = lsb_release:match('Description:%s*(.+)') or info.version
    else
        -- Try /etc/os-release
        local os_release = open('/etc/os-release', 'r')
        if os_release then
            local content = os_release:read('*a')
            os_release:close()
            local pretty_name = content:match('PRETTY_NAME="([^"]+)"')
            if pretty_name then
                info.version = pretty_name
            end
        end
    end

    return info
end

--- Get OS information for macOS systems
--- @return table OS information with name, version, kernel, and arch fields
local function get_os_info_macos()
    local info = {
        name = exec_command('uname -s') or 'Unknown',
        version = exec_command('uname -r') or 'Unknown',
        kernel = exec_command('uname -v') or 'Unknown',
        arch = exec_command('uname -m') or 'Unknown',
    }

    -- Get macOS version
    local sw_vers = exec_command('sw_vers -productVersion')
    if sw_vers then
        info.version = 'macOS ' .. sw_vers
    end

    return info
end

--- Get OS information for BSD systems
--- @return table OS information with name, version, kernel, and arch fields
local function get_os_info_bsd()
    return {
        name = exec_command('uname -s') or 'Unknown',
        version = exec_command('uname -r') or 'Unknown',
        kernel = exec_command('uname -v') or 'Unknown',
        arch = exec_command('uname -m') or 'Unknown',
    }
end

--- Get OS information based on detected platform
--- @return table OS information with name, version, kernel, and arch fields
local function get_os_info()
    local os_type = detect_os_type()

    if os_type == 'Linux' then
        return get_os_info_linux()
    elseif os_type == 'OSX' then
        return get_os_info_macos()
    elseif os_type == 'BSD' then
        return get_os_info_bsd()
    else
        return {
            name = os_type or 'Unknown',
            version = 'Unknown',
            kernel = 'Unknown',
            arch = 'Unknown',
        }
    end
end

--- Get CPU information for Linux systems
--- @return table CPU information with model, cores, threads, and frequency fields
local function get_cpu_info_linux()
    local info = {
        model = 'Unknown',
        cores = 'Unknown',
        threads = 'Unknown',
        frequency = 'Unknown',
    }

    local cpuinfo = open('/proc/cpuinfo', 'r')
    if cpuinfo then
        local content = cpuinfo:read('*a')
        cpuinfo:close()

        -- Get CPU model
        info.model = content:match('model name%s*:%s*([^\n]+)') or 'Unknown'

        -- Count physical cores and threads
        local physical_ids = {}
        local processor_count = 0
        for line in content:gmatch('[^\n]+') do
            if line:match('^processor%s*:') then
                processor_count = processor_count + 1
            end
            local physical_id = line:match('physical id%s*:%s*(%d+)')
            if physical_id then
                physical_ids[physical_id] = true
            end
        end

        info.threads = tostring(processor_count)
        local core_count = 0
        for _ in pairs(physical_ids) do
            core_count = core_count + 1
        end
        if core_count == 0 then
            core_count = processor_count
        end
        info.cores = tostring(core_count)

        -- Get CPU frequency
        local freq = content:match('cpu MHz%s*:%s*([%d%.]+)')
        if freq then
            info.frequency = format('%.2f GHz', tonumber(freq) / 1000)
        end
    end

    return info
end

--- Get CPU information for macOS systems
--- @return table CPU information with model, cores, threads, and frequency fields
local function get_cpu_info_macos()
    local info = {
        model = 'Unknown',
        cores = 'Unknown',
        threads = 'Unknown',
        frequency = 'Unknown',
    }

    info.model = exec_command('sysctl -n machdep.cpu.brand_string') or 'Unknown'
    local core_count = exec_command('sysctl -n hw.physicalcpu')
    local thread_count = exec_command('sysctl -n hw.logicalcpu')
    info.cores = core_count or 'Unknown'
    info.threads = thread_count or 'Unknown'

    -- Get CPU frequency (if available)
    local freq = exec_command('sysctl -n hw.cpufrequency_max 2>/dev/null')
    if freq and tonumber(freq) then
        info.frequency = format('%.2f GHz', tonumber(freq) / 1e9)
    end

    return info
end

--- Get CPU information based on detected platform
--- @return table CPU information with model, cores, threads, and frequency fields
local function get_cpu_info()
    local os_type = detect_os_type()

    if os_type == 'Linux' then
        return get_cpu_info_linux()
    elseif os_type == 'OSX' then
        return get_cpu_info_macos()
    else
        return {
            model = 'Unknown',
            cores = 'Unknown',
            threads = 'Unknown',
            frequency = 'Unknown',
        }
    end
end

--- Get memory information for Linux systems
--- @return table Memory information with total and available fields
local function get_memory_info_linux()
    local info = {
        total = 'Unknown',
        available = 'Unknown',
    }

    local meminfo = open('/proc/meminfo', 'r')
    if meminfo then
        local content = meminfo:read('*a')
        meminfo:close()

        local total_kb = content:match('MemTotal:%s*(%d+)')
        local available_kb = content:match('MemAvailable:%s*(%d+)')
        if not available_kb then
            -- Fallback for older kernels
            local free_kb = content:match('MemFree:%s*(%d+)')
            local buffers_kb = content:match('Buffers:%s*(%d+)')
            local cached_kb = content:match('Cached:%s*(%d+)')
            if free_kb and buffers_kb and cached_kb then
                available_kb = tonumber(free_kb) + tonumber(buffers_kb) +
                                   tonumber(cached_kb)
            end
        end

        if total_kb then
            info.total = format('%.2f GB', tonumber(total_kb) / 1024 / 1024)
        end
        if available_kb then
            info.available = format('%.2f GB',
                                    tonumber(available_kb) / 1024 / 1024)
        end
    end

    return info
end

--- Get memory information for macOS systems
--- @return table Memory information with total and available fields
local function get_memory_info_macos()
    local info = {
        total = 'Unknown',
        available = 'Unknown',
    }

    local total_bytes = exec_command('sysctl -n hw.memsize')
    if total_bytes then
        info.total = format('%.2f GB',
                            tonumber(total_bytes) / 1024 / 1024 / 1024)
    end

    -- Get available memory using vm_stat
    local vm_stat = exec_command('vm_stat')
    if vm_stat then
        local page_size = vm_stat:match('page size of (%d+) bytes')
        local pages_free = vm_stat:match('Pages free:%s*(%d+)')
        local pages_inactive = vm_stat:match('Pages inactive:%s*(%d+)')
        if page_size and pages_free and pages_inactive then
            local available_bytes = (tonumber(pages_free) +
                                        tonumber(pages_inactive)) *
                                        tonumber(page_size)
            info.available = format('%.2f GB',
                                    available_bytes / 1024 / 1024 / 1024)
        end
    end

    return info
end

--- Get memory information based on detected platform
--- @return table Memory information with total and available fields
local function get_memory_info()
    local os_type = detect_os_type()

    if os_type == 'Linux' then
        return get_memory_info_linux()
    elseif os_type == 'OSX' then
        return get_memory_info_macos()
    else
        return {
            total = 'Unknown',
            available = 'Unknown',
        }
    end
end

--- Get Lua runtime information
--- @return table Lua runtime information with version and JIT status
local function get_lua_info()
    local info = {
        version = _VERSION or 'Unknown',
        jit = false,
        jit_version = 'N/A',
        jit_status = 'N/A',
    }

    -- Check for LuaJIT
    if rawget(_G, 'jit') then
        info.jit = true
        info.jit_version = jit.version or 'Unknown'
        info.jit_status = jit.status() and 'enabled' or 'disabled'

        -- Get JIT compilation options
        if jit.status then
            local status_info = {
                jit.status(),
            }
            if #status_info > 1 then
                local opts = {}
                for i = 2, #status_info do
                    table.insert(opts, status_info[i])
                end
                if #opts > 0 then
                    info.jit_options = table.concat(opts, ', ')
                else
                    info.jit_options = 'N/A'
                end
            end
        end
    end

    return info
end

-- Cache for system information to avoid repeated expensive operations
local CACHED_INFO = nil

--- Get all system information with caching
--- @return table Complete system information including os, cpu, memory, lua, and timestamp
local function get_all()
    -- Return cached information if already collected
    if CACHED_INFO then
        -- Only update timestamp for each call
        CACHED_INFO.timestamp = os.date('%Y-%m-%d %H:%M:%S')
        return CACHED_INFO
    end

    -- Collect system information once and cache it
    CACHED_INFO = {
        os = get_os_info(),
        cpu = get_cpu_info(),
        memory = get_memory_info(),
        lua = get_lua_info(),
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
    }

    return CACHED_INFO
end

-- Export only the get_all function
return get_all
