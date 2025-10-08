require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local report_sysinfo = require('measure.report.sysinfo')

function testcase.module_loading()
    -- Test module loading as function
    assert.is_function(report_sysinfo)
end

function testcase.returns_formatted_table()
    -- Test that report_sysinfo returns a table with required fields
    local result = report_sysinfo()
    assert.is_table(result)

    -- Check for required fields with correct types
    assert.is_string(result.Hardware)
    assert.is_string(result.Host)
    assert.is_string(result.Runtime)
    assert.is_string(result.Date)
end

function testcase.hardware_field_format()
    -- Test Hardware field is comma-separated string
    local result = report_sysinfo()

    assert.is_string(result.Hardware)
    -- Should not be empty
    assert.is_true(#result.Hardware > 0)
    -- Should contain comma separators (at least between CPU and cores info)
    assert.is_true(result.Hardware:find(',') ~= nil)
end

function testcase.host_field_format()
    -- Test Host field is comma-separated string
    local result = report_sysinfo()

    assert.is_string(result.Host)
    -- Should not be empty
    assert.is_true(#result.Host > 0)
    -- Should contain comma separators (at least between OS and version)
    assert.is_true(result.Host:find(',') ~= nil)
end

function testcase.runtime_field_format()
    -- Test Runtime field is comma-separated string
    local result = report_sysinfo()

    assert.is_string(result.Runtime)
    -- Should not be empty
    assert.is_true(#result.Runtime > 0)
    -- Should contain comma separator between version and JIT status
    assert.is_true(result.Runtime:find(',') ~= nil)
end

function testcase.date_field_format()
    -- Test Date field follows ISO 8601 format (without timezone validation)
    local result = report_sysinfo()

    assert.is_string(result.Date)
    -- Check for ISO 8601 date format: YYYY-MM-DD
    assert.match(result.Date, '%d%d%d%d%-%d%d%-%d%d', false)
    -- Check for time format: HH:MM:SS
    assert.match(result.Date, '%d%d:%d%d:%d%d', false)
    -- Date and time should be separated by 'T' or space
    local has_separator = result.Date:match(
                              '%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d') or
                              result.Date:match(
                                  '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d')
    assert.is_true(has_separator ~= nil)
end

function testcase.no_newlines()
    -- Test that no field contains newlines
    local result = report_sysinfo()

    for _, value in pairs(result) do
        assert.is_string(value)
        assert.not_match(value, '\n')
    end
end

function testcase.consistent_structure()
    -- Test that multiple calls return consistent structure
    local result1 = report_sysinfo()
    local result2 = report_sysinfo()

    -- Both should have same keys
    for key in pairs(result1) do
        assert.not_nil(result2[key])
    end
    for key in pairs(result2) do
        assert.not_nil(result1[key])
    end

    -- System info should be identical (Hardware, Host, Runtime)
    assert.equal(result1.Hardware, result2.Hardware)
    assert.equal(result1.Host, result2.Host)
    assert.equal(result1.Runtime, result2.Runtime)
    -- Date may differ between calls
    assert.is_string(result1.Date)
    assert.is_string(result2.Date)
end
