-- Benchmark file with type error (pcall failure)
-- This file will load successfully with loadfile() but fail during pcall(f)
local measure = require('measure')

local function throw_error()
    local a = 1 + {} -- Type error: attempt to add number and table
end

-- This will cause pcall(f) to fail in evalfile()
throw_error()
