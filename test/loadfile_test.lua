require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local loadfile = require('measure.loadfile')

-- File tracking for cleanup
local TEST_FILES = {}

-- Helper function to create a test file and track it
local function create_test_file(filename, content)
    local f, err = io.open(filename, 'w')
    if not f then
        error('Failed to create file "' .. filename .. '": ' ..
                  (err or 'unknown error'))
    end
    f:write(content or '')
    f:close()
    TEST_FILES[#TEST_FILES + 1] = filename
end

function testcase.before_all()
    -- Create tmp directory if not exists
    os.execute('mkdir -p tmp')

    -- Create test files once
    create_test_file('tmp/valid_bench.lua', [[
local measure = require('measure')

local bench = measure.describe("valid_test")
bench.run(function()
    return "test"
end)
]])

    create_test_file('tmp/syntax_error_bench.lua', [[
local measure = require('measure'
-- Missing closing parenthesis - syntax error
]])

    create_test_file('tmp/runtime_error_bench.lua', [[
local measure = require('measure')
error("Intentional runtime error")
]])

    create_test_file('tmp/no_benchmark_file.lua', [[
-- This file has no benchmark registration
local x = 1 + 1
]])

    create_test_file('tmp/invalid_spec_bench.lua', [[
local measure = require('measure')

-- Invalid spec - no run() or run_with_timer() function
measure.describe("invalid_test")
]])
end

function testcase.after_all()
    local dirname = TEST_FILES[1]:match('^(.-)/[^/]+$')
    -- Clean up test files
    for _, filepath in ipairs(TEST_FILES) do
        os.remove(filepath)
    end
    if dirname then
        os.remove(dirname)
    end
end

function testcase.module_loading()
    -- Test module loading
    assert.is_function(loadfile)
end

function testcase.invalid_argument_type()
    -- Test argument validation - pathname must be string
    local ok, err = pcall(loadfile, nil)
    assert.is_false(ok)
    assert.match(err, 'pathname must be a string')

    ok, err = pcall(loadfile, 123)
    assert.is_false(ok)
    assert.match(err, 'pathname must be a string')

    ok, err = pcall(loadfile, {})
    assert.is_false(ok)
    assert.match(err, 'pathname must be a string')

    ok, err = pcall(loadfile, true)
    assert.is_false(ok)
    assert.match(err, 'pathname must be a string')
end

function testcase.nonexistent_file()
    -- Test error handling for nonexistent file
    local result, err = loadfile('tmp/nonexistent_file_12345.lua')
    assert.is_nil(result)
    assert.is_string(err)
    assert.match(err, 'cannot open')
end

function testcase.directory_path()
    -- Test error when pathname is a directory (should fail in evalfile)
    local result, err = loadfile('tmp')
    assert.is_nil(result)
    assert.is_string(err)
end

function testcase.syntax_error_file()
    -- Test loading file with syntax error
    local result, err = loadfile('tmp/syntax_error_bench.lua')
    assert.is_nil(result)
    assert.is_string(err)
    -- Error should mention syntax issue
end

function testcase.runtime_error_file()
    -- Test loading file with runtime error
    local result, err = loadfile('tmp/runtime_error_bench.lua')
    assert.is_nil(result)
    assert.is_string(err)
    assert.match(err, 'Intentional runtime error')
end

function testcase.no_benchmark_registration()
    -- Test loading file that doesn't register any benchmarks
    local result, err = loadfile('tmp/no_benchmark_file.lua')
    assert.is_nil(result)
    assert.is_nil(err)
end

function testcase.invalid_spec_validation()
    -- Test loading file with invalid spec (no run function)
    local result, err = loadfile('tmp/invalid_spec_bench.lua')
    assert.is_nil(result)
    assert.is_string(err)
    assert.re_match(err,
                    'ignore an invalid spec.+has not defined a run.+ or run_with_timer.+ function')
end

function testcase.valid_file_loading()
    -- Test successful loading of valid benchmark file
    local result, err = loadfile('tmp/valid_bench.lua')
    assert.is_table(result)
    assert.is_nil(err)
    assert.is_string(result.filename)
    assert.is_table(result.spec)
    assert.match(result.filename, 'valid_bench.lua')
end
