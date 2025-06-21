-- Benchmark file with function call error (pcall failure)
-- This file will load successfully with loadfile() but fail during pcall(f)
local measure = require('measure')

local function throw_error()
    local f = 123
    f() -- Call error: attempt to call a number value
end

-- This will cause pcall(f) to fail in evalfile()
throw_error()
