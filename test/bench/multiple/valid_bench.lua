-- Valid benchmark file with setup functions
local measure = require('measure')

local bench = measure.describe("valid_bench")

bench.setup_once(function()
    -- Setup once
end)

bench.run(function()
    -- Benchmark function
    local sum = 0
    for i = 1, 1000 do
        sum = sum + i
    end
    return sum
end)
