-- Benchmark file that defines multiple specs
local measure = require('measure')

-- First spec
local bench1 = measure.describe("first_spec")
bench1.run(function()
    return "first spec"
end)

-- Second spec
local bench2 = measure.describe("second_spec")
bench2.run(function()
    return "second spec"
end)
