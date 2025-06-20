-- Simple benchmark file for testing
local measure = require('measure')

local bench = measure.describe("simple_test")
bench.run(function()
    return "single file test"
end)
