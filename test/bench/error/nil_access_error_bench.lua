-- Benchmark file with nil access error (pcall failure)
-- This file will load successfully with loadfile() but fail during pcall(f)
local measure = require('measure')

local function throw_error()
    local x = nil
    print(x.field) -- Nil access error: attempt to index nil value
end

-- This will cause pcall(f) to fail in evalfile()
throw_error()
