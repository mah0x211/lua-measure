-- Simple benchmark file for testing
local measure = require('measure')
local base64mix = require('base64mix').encode
local base64 = require('base64').encode
local basexx = require('basexx').to_base64
local luabase64 = require('LuaBase64').encode

local DATA

function measure.before_all()
    DATA = assert(io.open('twitter-like.json', 'r'):read('*a'))
    print(('Loaded data size: %f MB'):format(#DATA / 1024 / 1024))
    print('')
end

measure.options({
    -- Warmup time in seconds (default 1)
    -- warmup = 1,
    -- Garbage collector step size in KB (default 0 = full GC)
    -- gc_step = 0,
    -- Confidence interval level % (default 95)
    -- confidence_level = 95,
    -- Target relative confidence interval width % (default 5)
    -- rciw = 5,
}).describe('base64').run(function()
    base64(DATA)
end).describe('basexx').run(function()
    basexx(DATA)
end).describe('luabase64').run(function()
    luabase64(DATA)
end).describe('base64mix').run(function()
    base64mix(DATA)
end)

