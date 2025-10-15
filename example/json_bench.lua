-- Simple benchmark file for testing
local measure = require('measure')
local yyjson = require('yyjson').decode
local cjson = require('cjson').decode
local simdjson = require('simdjson').parse
local dkjson = require('dkjson').decode
local lunajson = require('lunajson').decode

local DATA

function measure.before_all()
    DATA = assert(io.open('twitter-like.json', 'r'):read('*a'))
    print(('Loaded data size: %f MB'):format(#DATA / 1024 / 1024))
    print('')
end

measure.describe('cjson').run(function()
    cjson(DATA)
end).describe('simdjson').run(function()
    simdjson(DATA)
end).describe('dkjson').run(function()
    dkjson(DATA)
end).describe('lunajson').run(function()
    lunajson(DATA)
end).describe('yyjson').run(function()
    yyjson(DATA)
end)
