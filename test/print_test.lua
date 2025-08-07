require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local print_mod = require('measure.print')

-- Compatibility for Lua 5.1
local unpack = table.unpack or unpack

-- Test output capture
local output_buffer = {}
local original_print = print

function testcase.after_each()
    -- luacheck: ignore 121
    print = original_print
end

local function get_print_output(...)
    if select('#', ...) == 0 then
        output_buffer[#output_buffer + 1] = ""
        return
    end

    local args = {
        ...,
    }
    local parts = {}
    for i = 1, select('#', ...) do
        parts[i] = tostring(args[i])
    end
    output_buffer[#output_buffer + 1] = table.concat(parts, ' ')
end

-- Base function to capture output from any function call
local function capture_output(func, ...)
    output_buffer = {}
    -- luacheck: ignore 121
    print = get_print_output
    func(...)
    print = original_print
    return output_buffer[1], output_buffer
end

-- Specialized capture functions for print_mod
local function capture_printf(...)
    return capture_output(print_mod, ...)
end

local function capture_divider(...)
    return capture_output(print_mod.divider, ...)
end

local function capture_header(...)
    return capture_output(print_mod.header, ...)
end

local function capture_line()
    return capture_output(print_mod.line)
end

-- Test enhanced print formatting
function testcase.enhanced_print_formatting()
    local output = capture_printf("Hello %s!", "world")
    assert.equal(output, "Hello world!")

    output = capture_printf("Number: %d, Float: %.2f", 42, 3.14159)
    assert.equal(output, "Number: 42, Float: 3.14")

    output = capture_printf("Test %s %d %s", "case", 123, "passed")
    assert.equal(output, "Test case 123 passed")
end

-- Test print without formatting
function testcase.enhanced_print_no_formatting()
    -- Single arguments
    local test_cases = {
        {
            args = {
                42,
            },
            expected = "42",
        },
        {
            args = {
                "simple string",
            },
            expected = "simple string",
        },
        {
            args = {
                true,
            },
            expected = "true",
        },
        {
            args = {
                nil,
            },
            expected = "nil",
        },
        {
            args = {
                "no format",
            },
            expected = "no format",
        },
    }

    for _, test in ipairs(test_cases) do
        local output = capture_printf(unpack(test.args))
        assert.equal(output, test.expected)
    end

    -- Multiple arguments without formatting
    local output = capture_printf("test", 123, true)
    assert.equal(output, "test 123 true")
end

-- Test divider function
function testcase.print_divider()
    local test_cases = {
        {
            args = {},
            expected = string.rep("-", 80),
        },
        {
            args = {
                "=",
            },
            expected = string.rep("=", 80),
        },
        {
            args = {
                "-",
                20,
            },
            expected = string.rep("-", 20),
        },
        {
            args = {
                "*",
                10,
            },
            expected = string.rep("*", 10),
        },
        {
            args = {
                "x",
                0,
            },
            expected = "",
        },
        {
            args = {
                "@",
                1,
            },
            expected = "@",
        },
    }

    for _, test in ipairs(test_cases) do
        local output = capture_divider(unpack(test.args))
        assert.equal(output, test.expected)
    end
end

-- Test header function
function testcase.print_header()
    local rep = string.rep

    local test_cases = {
        {
            args = {
                "Test",
            },
            expected = rep("=", 37) .. " Test " .. rep("=", 37),
        },
        {
            args = {
                "Hi",
                10,
            },
            expected = "=== Hi ===",
        },
        {
            args = {
                "Test",
                20,
                "*",
            },
            expected = rep("*", 7) .. " Test " .. rep("*", 7),
        },
        {
            args = {
                "OK",
                8,
                "@",
            },
            expected = "@@ OK @@",
        },
    }

    for _, test in ipairs(test_cases) do
        local output = capture_header(unpack(test.args))
        assert.equal(output, test.expected)
    end
end

-- Test header with edge cases
function testcase.print_header_edge_cases()
    local rep = string.rep

    -- Long title
    local output = capture_header("This is a very long title", 10)
    assert.equal(output, "= This is a very long title =")

    -- Title equal to width
    output = capture_header("12345", 5)
    assert.equal(output, "= 12345 =")

    -- Empty title
    output = capture_header("", 10)
    assert.equal(output, rep("=", 4) .. "  " .. rep("=", 4))

    -- Single character title
    output = capture_header("X", 10)
    assert.equal(output, rep("=", 3) .. " X " .. rep("=", 4))
end

-- Test line function
function testcase.print_line()
    local output = capture_line()
    assert.equal(output, "")

    -- Multiple lines
    local _, all_output = capture_output(function()
        print_mod.line()
        print_mod.line()
    end)
    assert.equal(all_output[1], "")
    assert.equal(all_output[2], "")
end

-- Test argument validation
function testcase.argument_validation()
    local validation_tests = {
        {
            func = print_mod.divider,
            args = {
                123,
            },
            pattern = "char must be a string",
        },
        {
            func = print_mod.divider,
            args = {
                "-",
                "invalid",
            },
            pattern = "width must be a number",
        },
        {
            func = print_mod.header,
            args = {
                123,
            },
            pattern = "title must be a string",
        },
        {
            func = print_mod.header,
            args = {
                "test",
                "invalid",
            },
            pattern = "width must be a number",
        },
        {
            func = print_mod.header,
            args = {
                "test",
                10,
                123,
            },
            pattern = "char must be a string",
        },
    }

    for _, test in ipairs(validation_tests) do
        local err = assert.throws(test.func, unpack(test.args))
        assert.match(err, test.pattern)
    end

    -- Valid calls should not throw errors
    capture_output(function()
        print_mod.divider("=", 10)
        print_mod.header("test", 20, "*")
        print_mod.line()
    end)
end

-- Test edge cases and special formatting
function testcase.edge_cases_and_special_formatting()
    -- Divider with empty string
    local output = capture_divider("", 5)
    assert.equal(output, "")

    -- Formatting edge cases
    local format_tests = {
        {
            args = {
                "",
                "ignored",
            },
            expected = " ignored",
        },
        {
            args = {
                "Hello %s",
            },
            expected = "Hello %s",
        }, -- No args, no formatting
        {
            args = {
                "Test %% complete",
            },
            expected = "Test %% complete",
        },
        {
            args = {
                "Progress: %d%% complete",
                50,
            },
            expected = "Progress: 50% complete",
        },
    }

    for _, test in ipairs(format_tests) do
        local result = capture_printf(unpack(test.args))
        assert.equal(result, test.expected)
    end
end

-- Test module callable interface
function testcase.module_callable()
    -- Test that module is callable
    assert.is_function(getmetatable(print_mod).__call)

    -- Test direct call
    local output = capture_printf("Direct call %s", "works")
    assert.equal(output, "Direct call works")

    -- Test mixed usage
    local _, all_output = capture_output(function()
        print_mod("Mixed usage:")
        print_mod.divider("-", 20)
        print_mod.header("TEST", 20)
        print_mod.line()
    end)

    assert.equal(all_output[1], "Mixed usage:")
    assert.equal(all_output[2], string.rep("-", 20))
    assert.equal(all_output[3],
                 string.rep("=", 7) .. " TEST " .. string.rep("=", 7))
    assert.equal(all_output[4], "")
end
