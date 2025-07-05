--
-- This file is describe the how to use the measure.
--
-- * Benchmark file should be named with the pattern `*_bench.lua`.
-- * You should describe the benchmark using the `measure` module. It will be
--   loaded by the measure command and executed to run the benchmarks.
--
local measure = require("measure")

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
    -- 'Example Benchmark' or 'Example Benchmark #<i>' if a repeats option is
    -- specified.
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
--       be defined before the run or run_with_timer function if you want to use it.
--
--  The returned values from these functions are passed to the run or run_with_timer
--  function.
--  If you defined setup_once, it will be executed once before the benchmark
--  run, and the returned value will be cached.
--
-- @param i number The repeat count, it indicates the current iterations.
-- @param ctx any The context object, it contains the context option.
-- @return ... any The value to be passed to the run or run_with_timer function.
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

