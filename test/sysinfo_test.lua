require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local get_sysinfo = require('measure.sysinfo')

function testcase.sysinfo_returns_table()
    -- Test that sysinfo function returns a table
    local info = get_sysinfo()
    assert.is_table(info)
end

function testcase.sysinfo_structure()
    -- Test sysinfo returns proper structure with string fields
    local info = get_sysinfo()
    assert.is_table(info.os)
    assert.is_table(info.cpu)
    assert.is_table(info.memory)
    assert.is_table(info.lua)
    assert.is_string(info.timestamp)
    assert.re_match(info.timestamp, '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}')

    -- Test OS fields are strings
    assert.is_string(info.os.name)
    assert.is_string(info.os.version)
    assert.is_string(info.os.kernel)
    assert.is_string(info.os.arch)

    -- Test CPU fields are strings
    assert.is_string(info.cpu.model)
    assert.is_string(info.cpu.cores)
    assert.is_string(info.cpu.threads)
    assert.is_string(info.cpu.frequency)

    -- Test memory fields are strings
    assert.is_string(info.memory.total)
    assert.is_string(info.memory.available)
end

function testcase.lua_info_required_fields()
    -- Test required fields in Lua runtime information are proper types
    local info = get_sysinfo()
    assert.is_string(info.lua.version)
    assert.is_boolean(info.lua.jit)
    assert.is_string(info.lua.jit_version)
    assert.is_string(info.lua.jit_status)
end

function testcase.sysinfo_is_function()
    -- Test that sysinfo module exports a function
    assert.is_function(get_sysinfo)
end

function testcase.consistency_across_calls()
    -- Test that stable fields return consistent values
    local info1 = get_sysinfo()
    local info2 = get_sysinfo()

    assert.equal(info1.lua.version, info2.lua.version)
    assert.equal(info1.lua.jit, info2.lua.jit)
end
