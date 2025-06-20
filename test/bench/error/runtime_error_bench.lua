-- Benchmark file with runtime error
-- This file will load successfully with loadfile() but fail during pcall(f)
local measure = require('measure')

local bench = measure.describe("runtime_error")
bench.run(function()
    return "test"
end)

-- File-level runtime error that occurs during pcall(f)
error("Intentional runtime error for testing pcall failure")
