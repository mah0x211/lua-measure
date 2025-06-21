-- Benchmark file in mixed directory
local measure = require('measure')

local bench = measure.describe("pattern_bench")
bench.run(function()
    return "mixed directory bench"
end)
