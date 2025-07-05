--
-- This file is describe the how to use the measure.
--
-- * Benchmark file should be named with the pattern `*_bench.lua`.
-- * You should describe the benchmark using the `measure` module. It will be
--   loaded by the measure command and executed to run the benchmarks.
--
--
--  the followings are declared in the `measure.describe` module.
--
--- @class _measure.describe.spec
--- @field name string The name of the benchmark
--- @field namefn function|nil The function to describe the benchmark name
--- @field options table The options for the benchmark
--- @field setup function|nil The setup function for the benchmark
--- @field setup_once function|nil The setup_once function for the benchmark
--- @field run function|nil The run function for the benchmark
--- @field measure function|nil The measure function for the benchmark
--- @field teardown function|nil The teardown function for the benchmark
-- This is the describer for the benchmark, it is used to describe the benchmark
--- @class _measure.describe
--- @field spec _measure.describe.spec
local BenchmarkDescribe = {}
BenchmarkDescribe.__index = BenchmarkDescribe
BenchmarkDescribe.__tostring = function(self)
    return ('Benchmark %q'):format(self.spec.name)
end

function BenchmarkDescribe:options(opts)
    local spec = self.spec
    if type(opts) ~= 'table' then
        return false, 'argument must be a table'
    elseif spec.options then
        return false, 'options cannot be defined twice'
    elseif spec.setup or spec.setup_once or spec.run or spec.run_with_timer then

        return false,
               'options must be defined before setup(), setup_once(), run() or run_with_timer()'
    end

    -- Validate options
    if opts.context and type(opts.context) ~= 'table' and type(opts.context) ~=
        'function' then
        return false, 'options.context must be a table or a function'
    end

    if opts.confidence_level and (type(opts.confidence_level) ~= 'number' or
        opts.confidence_level <= 0 or opts.confidence_level > 100) then
        return false, 'options.confidence_level must be a number between 0 and 100'
    end

    if opts.warmup and (type(opts.warmup) ~= 'number' or opts.warmup < 0 or
        opts.warmup > 5) then
        return false, 'options.warmup must be a number between 0 and 5'
    end

    if opts.rciw and (type(opts.rciw) ~= 'number' or opts.rciw <= 0 or
        opts.rciw > 100) then
        return false, 'options.rciw must be a number between 0 and 100'
    end

    spec.options = opts
    return true
end

function BenchmarkDescribe:setup(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup then
        return false, 'cannot be defined twice'
    elseif spec.setup_once then
        return false, 'cannot be defined if setup_once() is defined'
    elseif spec.run or spec.run_with_timer then
        return false, 'must be defined before run() or run_with_timer()'
    end

    spec.setup = fn
    return true
end

function BenchmarkDescribe:setup_once(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup_once then
        return false, 'cannot be defined twice'
    elseif spec.setup then
        return false, 'cannot be defined if setup() is defined'
    elseif spec.run or spec.run_with_timer then
        return false, 'must be defined before run() or run_with_timer()'
    end

    spec.setup_once = fn
    return true
end

function BenchmarkDescribe:run(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.run then
        return false, 'cannot be defined twice'
    elseif spec.run_with_timer then
        return false, 'cannot be defined if run_with_timer() is defined'
    end

    spec.run = fn
    return true
end

function BenchmarkDescribe:run_with_timer(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.run_with_timer then
        return false, 'cannot be defined twice'
    elseif spec.run then
        return false, 'cannot be defined if run() is defined'
    end

    spec.run_with_timer = fn
    return true
end

function BenchmarkDescribe:teardown(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.teardown then
        return false, 'cannot be defined twice'
    elseif not spec.run and not spec.run_with_timer then
        return false, 'must be defined after run() or run_with_timer()'
    end

    spec.teardown = fn
    return true
end

-- Create a new describe object
--- @param name string The name of the benchmark
--- @param namefn function|nil The function to describe the benchmark name
--- @return _measure.describe? The new describe object, or nil and an error message
--- @return any The error message if the describe object could not be created
local function new_describe(name, namefn)
    if type(name) ~= 'string' then
        return nil, ('name must be a string, got %q'):format(type(name))
    elseif namefn ~= nil and type(namefn) ~= 'function' then
        return nil, ('namefn must be a function or nil, got %q'):format(
                   type(namefn))
    end

    return setmetatable({
        spec = {
            name = name,
            namefn = namefn,
        },
    }, BenchmarkDescribe)
end

--
-- return a function that creates a new describe object.
-- this function is used to create a new describe object as the following code
--
--  local new_describe = require('measure.describe')
--  local desc = new_describe('Example Benchmark')
--
-- return new_describe
--

--
--  the followings are declared in the `measure.registry` module.
--

--- the measure.registry.spec used to the file-scoped benchmark registry.
--- @class _measure.regstry.spec
--- @field filename string The filename of the benchmark file.
--- @field hooks table<string, function> The hooks for the benchmark
--- @field describes table<string, _measure.describe> The describes for the benchmark
local Spec = {}
Spec.__index = Spec

-- Set a hook function for the benchmark registry.
function Spec:set_hook(name, fn)
    local HookNames = {
        before_all = true,
        before_each = true,
        after_each = true,
        after_all = true,
    }

    if not HookNames[name] then
        return false, ('Error: unknown hook %q'):format(tostring(name))
    elseif type(fn) ~= 'function' then
        return false, ('Error: %q must be a function'):format(name)
    end

    local v = self.hooks[name]
    if type(v) == 'function' then
        return false, ('Error: %q cannot be defined twice'):format(name)
    end
    -- Set the hook function
    self.hooks[name] = fn
    return true
end

-- get the new_describe() from the `measure.describe` module
-- local new_describe = require('measure.describe')

-- create a new describe object and add it to the registry
--- @param name string The name of the describe
--- @param namefn function|nil The function to describe the benchmark name
--- @return _measure.describe|nil The new describe object, or nil and an error message
--- @return string|nil The error message if the describe object could not be created
function Spec:new_describe(name, namefn)
    -- Create a new describe object
    local desc, err = new_describe(name, namefn)
    if not desc then
        return nil, err
    end

    -- Check if the describe name already exists
    if self.describes[name] then
        return nil, ('name %q already exists, it must be unique'):format(name)
    end

    -- Add the describe to the list of describes
    self.describes[#self.describes + 1] = desc
    -- Map the describe name to the spec for preving duplicates
    self.describes[name] = desc
    return desc
end

--- @type table<string, _measure.regstry.spec>
local Registry = {}

--- Get or create a new spec for the benchmark file.
--- This function is used to create a new spec for the benchmark file if it does
--- not exist, or return the existing spec if it does.
--- @return _measure.regstry.spec
local function new()
    -- get the file path from the caller
    local filename = '/path/to/benchmark/example_bench.lua'

    local spec = Registry[filename]
    if spec then
        -- If the spec already exists, return it
        return spec
    end

    -- Create a new spec for the benchmark file
    spec = setmetatable({
        filename = filename,
        hooks = {},
        describes = {},
    }, Spec)
    -- Add the spec to the registry
    Registry[filename] = spec

    -- Return the new spec
    return spec
end

-- Return the registry of specs
local function get()
    return Registry
end

--
-- return a function that creates a new describe object.
-- this function is used to create a new describe object as the following code
--
--  local registry = require('measure.registry')
--  -- this spec object holds the benchmark file information
--  local registry_spec = regisry.new_spec()
--
-- return {
--     get = get,
--     new = new,
-- }
--

--
--  the followings are declared in the `measure` module.
--

-- get the new() function from the `measure.registry` module
-- local new = require('measure.registry').new

-- This data structure defined by each benchmark file.
local RegistrySpec = new()
local desc = nil
local descfn = nil
local registrar = setmetatable({}, {
    __newindex = function(_, key, fn)
        local ok, err = RegistrySpec:set_hook(key, fn)
        if not ok then
            error(err, 2)
        end
    end,
    __call = function(self, ...)
        print('Measure call:', desc, descfn)
        if desc == 'describe' then
            local err
            desc, err = RegistrySpec:new_describe(...)
            if not desc then
                error(err, 2)
            end
            return self
        end

        if desc == nil or descfn == nil then
            error('Attempt to call measure as a function', 2)
        end

        local fn = desc[descfn]
        if type(fn) ~= 'function' then
            error(('%s has no %q'):format(desc, descfn), 2)
        end
        local ok, err = fn(desc, ...)
        if not ok then
            error(('%s %s(): %s'):format(desc, descfn, err), 2)
        end
        descfn = nil
        return self
    end,
    __index = function(self, key)
        print('Measure index:', key)
        if type(key) ~= 'string' or type(desc) == 'string' or descfn then
            error(('Attempt to access measure as a table: %q'):format(tostring(
                                                                          key)),
                  2)
        end

        if desc == nil then
            desc = key
            return self
        end
        descfn = key
        return self
    end,
})

--
-- return the registrar object, it is used to register the benchmark hooks and
-- describe the benchmarks.
--
-- return registrar

--
--  the followings are declared in the `*_bench.lua` file.
--

-- get the registrar object from the `measure` module
-- local measure = require('measure')
local measure = registrar

-- before_all is run by the measure command before any benchmarks are run.
-- It is used to set up the environment for the benchmarks.
--
-- @return any The context object, it is passed to before_each, after_each, and
-- after_all functions.
function measure.before_all()
    -- The returned values are passed to before_each, after_each, and after_all
    -- functions.
    return {}
end

--- before_each is run before each benchmarks.
--- @param i integer The number of the calls to this function, starting from 1.
--- @param ctx any The context object, it from before_all.
function measure.before_each(i, ctx)
    -- here you can set up the environment for each benchmark
end

-- after_each is run after each benchmarks.
-- It is used to clean up the resources used by the benchmark.
--
-- @param i integer The number of the calls to this function, starting from 1.
function measure.after_each(i, ctx)
    -- here you can clean up the environment for each benchmark
end

-- after_all is run after all benchmarks are run.
-- It is used to clean up the resources used by the benchmarks.
-- @param ctx any The context object, it is from before_all.
function measure.after_all(ctx)
    -- here you can clean up the environment after all benchmarks
end

-- Describe a benchmark with options and setup/teardown functions.
-- If it has no run/measure function, measure will throw an error when you
-- run the benchmark.
measure.describe('Example Benchmark', function(i, ctx)
    -- Optionally, you can pass a function to describe the benchmark name.
    -- i is the current repeat count, and ctx is the context object.
    --
    -- This function will be called with the current repeat count and context
    -- and should return a string to be append to the benchmark name.
    -- If you don't pass a function, it will use the default name
    -- 'Example Benchmark'.
    return 'hello'
end).options({
    -- context can be used to pass data to other options functions
    -- and to the setupvalue and teardown functions.
    -- Note that the context is evaluated once before the benchmark run.
    context = {
        'foo',
        'bar',
        'baz',
    },
    -- You can also define a function to create the context object.
    -- This function will be called with the current repeat count and should
    -- return a table to be used as the context object.
    -- context = function()
    --     return {
    --         'foo',
    --         'bar',
    --         'baz',
    --     }
    -- end,

    -- confidence_level is the statistical confidence level for adaptive sampling
    -- It is used to determine the precision of confidence intervals (0-100)
    -- If not specified, it defaults to 95 (95%)
    confidence_level = 95,
    
    -- rciw is the target relative confidence interval width for adaptive sampling
    -- It is used to determine when sufficient samples have been collected (0-100)
    -- If not specified, it defaults to 5 (5%)
    rciw = 5,

    -- gc_step is the garbage collection step size for sampling
    -- 0 = full GC, -1 = disabled GC, positive value = step GC in KB
    -- If not specified, it defaults to 0 (full GC)
    gc_step = 0,

    -- warmup is the number of warmup iterations before the benchmark run.
    -- It is used to warm up the system before the benchmark run
    warmup = 5,
    -- You can also define a function to calculate the warmup value.
    -- This function will be called with the current repeat count and context
    -- and should return a number to be used as the warmup value.
    -- warmup = function(i, ctx)
    --     return 5
    -- end,

}) --
--
-- NOTE:
--  You can define either setup or setup_once, but not both. And, it must
--       be defined before the run or measure function if you want to use it.
--
--  The returned values from these functions are passed to the run or measure
--  function.
--  If you defined setup_once, it will be executed once before the benchmark
--  run, and the returned value will be cached.
--
-- @param i number The repeat count, it indicates the current iterations.
-- @param ctx any The context object, it contains the context option.
-- @return ... any The value to be passed to the run or measure function.
.setup(function(i, ctx)
    return 'value'
end).setup_once(function(ctx)
    return 'value'
end) --
--
-- NOTE:
--  You must be defined either run or run_with_timer function, but not both.
--
.run(function(...)
    -- This code is executed for the benchmark run
end).run_with_timer(function(m, ...)
    -- This code is executed for measuring the benchmark
    -- `m` is the measurement object
    -- You can use `m:start()` to start measuring time
    -- and `m:stop()` to stop measuring time to push the measurement result
end) --
--
-- NOTE:
--  You can define teardown at the end of the benchmark definition if you want
--  to use it.
--
-- @param i integer The repeat count, it incremented until it reaches the repeats option.
-- @param ctx any The context object, it contains the context option.
.teardown(function(i, ctx)
    -- This code is executed after each benchmark run
end)

