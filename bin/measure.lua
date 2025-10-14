#!/usr/bin/env lua

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
-- measure: A benchmarking tool for Lua
--
local print = print
local find = string.find
local format = string.format
local match = string.match
local unpack = table.unpack or unpack
local chdir = require('chdir')
local report = require('measure.report')
local report_sysinfo = require('measure.report.sysinfo')
local listfiles = require('measure.listfiles')
local loadfile = require('measure.loadfile')
local new_samples = require('measure.samples').new
local sampler = require('measure.sampler')
local stats_ci = require('measure.stats.ci')
-- constants
-- current working directory
local PWD = assert(io.popen('pwd'):read('*l'))

--- Change directory, execute function, and return to original directory
--- @param dir string Working directory to change
--- @param fn function Function to execute
--- @param ... any Arguments to pass to the function
--- @return ... Results of the function execution
local function pcall_in_dir(dir, fn, ...)
    assert(chdir(dir))
    local res = {
        pcall(fn, ...),
    }
    assert(chdir(PWD))
    if not res[1] then
        error(res[2])
    end
    return unpack(res, 2, 10)
end

--- Print usage information
local function print_usage()
    print([[
measure is a benchmarking command for Lua scripts.

Usage:
  measure [options] <pathname>

Options:
  --help                Show this help message.
  --version             Show version information.

Arguments:
    <pathname>  The path to a Lua script or directory containing Lua scripts
                to benchmark. The benchmark script should be named `*_bench.lua`.
]])
    os.exit(0)
end

--- Print formatted output
--- @param ... any Arguments to format
--- @usage printf("Hello, %s!", "world")
local function printf(...)
    print(format(...))
end

local VERSION = '0.1.0'
--- Print version information
local function print_version()
    printf('measure %s', VERSION)
    print("A benchmarking tool for Lua")
    os.exit(0)
end

--- Parse command line arguments
local function parse_argv()
    local argv = _G.arg or {}
    local args = {
        record_dir = './measure_records',
    }
    for i = 1, #argv do
        local arg = argv[i]
        if arg == '--help' then
            print_usage()
        elseif arg == '--version' then
            print_version()
        elseif find(arg, '^%-') then
            printf('Unknown option: %q', arg)
            os.exit(1)
        elseif args.pathname then
            print('Error: Only one pathname is allowed.')
            print_usage()
        else
            args.pathname = arg
        end
    end

    if not args.pathname then
        print('Error: No pathname specified')
        print_usage()
    end

    return args
end

-- Execute benchmarks

--- Safely call a function with error handling
--- @param msg string Error message prefix
--- @param fn function Function to call
--- @param ... any Arguments to pass to the function
--- @return boolean ok True if the function executed successfully
--- @return any ... results of the function or an error message if failed
local function safecall(msg, fn, ...)
    local res = {
        pcall(fn, ...),
    }
    if not res[1] then
        return false, format('ERROR: %s: %s', msg, res[2])
    end
    return true, unpack(res, 2, 10)
end

--- Run the sampling function with warmup
--- @param name string The name of the benchmark
--- @param fn function The function to sample
--- @param ctx table The context object for the sampling function
--- @return measure.samples? samples The samples object with collected data
--- @return any err Error message if failed
local function do_sampling(name, fn, ctx)
    local iteration = 0
    local sample_size = 30
    local samples = new_samples(name, sample_size, ctx.gc_step,
                                ctx.confidence_level, ctx.rciw)
    while sample_size do
        iteration = iteration + 1
        printf('    - Sampling %d samples (iteration %d)', sample_size,
               iteration)
        local ok, err = sampler(fn, samples, ctx.warmup)
        if not ok then
            error(err, 2)
        end

        local ci = stats_ci(samples)
        sample_size = ci.resample_size
        if sample_size then
            samples:capacity(sample_size - #samples)
        end
    end

    return samples
end

local function NOOP()
end

local function run_describes(spec)
    local results = {}
    for _, desc in ipairs(spec.describes) do
        printf('- %s', desc.spec.name)

        -- execute setup() function if defined
        local opts = desc.spec.options or {}
        local ok, res = safecall('setup()', desc.spec.setup or NOOP,
                                 opts.context)
        if not ok then
            return nil, res
        end

        -- execute run() or run_with_timer() function
        local sampling_ctx = {
            warmup = opts.warmup,
            gc_step = opts.gc_step,
            confidence_level = opts.confidence_level,
            rciw = opts.rciw,
        }
        local bench_ok, bench_res
        if desc.spec.run then
            bench_ok, bench_res = safecall('run()', function()
                return do_sampling(desc.spec.name, desc.spec.run, sampling_ctx)
            end)
        else
            bench_ok, bench_res = safecall('run_with_timer()',
                                           desc.spec.run_with_timer,
                                           function(fn)
                return do_sampling(desc.spec.name, fn, sampling_ctx)
            end)
        end

        -- execute teardown() function if defined
        ok, res = safecall('teardown()', desc.spec.teardown or NOOP,
                           opts.context)
        if not ok then
            return nil, res
        end

        if not bench_ok then
            -- benchmarking failed
            return nil, bench_res
        end
        results[#results + 1] = bench_res
    end
    return results
end

--- Execute the benchmark specification
--- @param spec table The benchmark specification
--- @return table? results The benchmark results
--- @return any err Error message if failed
local function do_benchmark(spec)
    -- execute before_all()
    local ok, res = safecall('before_all()', spec.hooks.before_all or NOOP)
    if not ok then
        return nil, res
    end
    -- create the hook context
    local hook_ctx = res or {}

    -- run describes
    local results, err = run_describes(spec)

    -- execute: after_all hook if defined
    ok, res = safecall('after_all()', spec.hooks.after_all or NOOP, hook_ctx)
    if not ok then
        return nil, res
    end

    return results, err
end

--- Get the directory name from a given pathname
--- @param pathname string The full pathname
--- @return string dirname The directory part of the pathname
--- @return string filename The filename part of the pathname
local function dirname(pathname)
    local dir, file = match(pathname, '^(.-)([^/]+)$')
    return dir ~= '' and dir or '.', file
end

do
    local ARGS = parse_argv()
    local pathnames, err = listfiles(ARGS.pathname)
    if not pathnames then
        print(err)
        os.exit(1)
    end

    local target_files = {}
    for _, pathname in ipairs(pathnames) do
        local dir, filename = dirname(pathname)
        local file
        file, err = pcall_in_dir(dir, loadfile, filename)
        if not file then
            print(err)
            os.exit(1)
        end
        file.pathname = pathname
        file.dirname = dir
        target_files[#target_files + 1] = file
    end
    if #target_files == 0 then
        print()
        print('No benchmark files found')
        os.exit(1)
    end

    print()
    print('# Benchmark Reports')
    print()

    -- Environment information
    print('```')
    for k, v in pairs(report_sysinfo()) do
        printf('%-8s: %s', k, v)
    end
    print('```')
    print()

    for _, file in ipairs(target_files) do
        printf('## Exec: %s', file.pathname)
        print()

        -- run the benchmark in the directory of the file
        local results
        results, err = pcall_in_dir(file.dirname, do_benchmark, file.spec)

        -- print the results or error message
        print()
        if results then
            report(results):render()
        else
            print(err)
        end
    end
    return
end

