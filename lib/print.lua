--
-- Copyright (C) 2025 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--- Generic print utilities for output formatting
--- Provides enhanced print functionality with formatting support and visual dividers
---
--- Example usage:
---   local print = require('measure.print')
---   print("Hello %s!", "world")        -- Formats and prints "Hello world!"
---   print(42)                          -- Prints 42 without formatting
---   print.divider("-", 80)             -- Prints 80 dashes
---   print.header("Title", 40)          -- Prints centered title with equals
---
local format = string.format
local rep = string.rep
local find = string.find
local floor = math.floor
local concat = table.concat
local tostring = tostring
local select = select

-- Constants
local DEFAULT_DIVIDER_CHAR = "-"
local DEFAULT_HEADER_CHAR = "="
local DEFAULT_WIDTH = 80

--- Enhanced print function with conditional formatting
--- @param v any First argument - if string with format specifiers, used as format string
--- @param ... any Additional arguments for formatting or direct printing
local function printf(v, ...)
    if type(v) == 'string' and select('#', ...) > 0 and find(v, '%%') then
        -- Format string with arguments (only if format specifiers found)
        print(format(v, ...))
        return
    end

    -- Print all arguments without formatting, separated by spaces
    local args = {
        v,
        ...,
    }
    for i = 1, select('#', v, ...) do
        args[i] = tostring(args[i])
    end
    print(concat(args, ' '))
end

--- Print a divider line
--- @param char string? Character to repeat (default: "-")
--- @param width number? Width of divider (default: 80)
local function print_divider(char, width)
    assert(char == nil or type(char) == 'string', 'char must be a string')
    assert(width == nil or type(width) == 'number', 'width must be a number')

    local divider_char = char or DEFAULT_DIVIDER_CHAR
    local divider_width = width or DEFAULT_WIDTH
    print(rep(divider_char, divider_width))
end

--- Print a centered header with dividers
--- @param title string Title text to display
--- @param width number? Width of header (default: 80)
--- @param char string? Character for divider (default: "=")
local function print_header(title, width, char)
    assert(type(title) == 'string', 'title must be a string')
    assert(width == nil or type(width) == 'number', 'width must be a number')
    assert(char == nil or type(char) == 'string', 'char must be a string')

    local header_width = width or DEFAULT_WIDTH
    local header_char = char or DEFAULT_HEADER_CHAR
    local title_len = #title

    if title_len >= header_width then
        -- Title is too long, just print with minimal padding
        print(format("%s %s %s", header_char, title, header_char))
        return
    end

    -- Calculate padding for centered title
    local padding = (header_width - title_len - 2) / 2 -- -2 for spaces around title
    local left_padding = floor(padding)
    local right_padding = header_width - title_len - 2 - left_padding

    print(format("%s %s %s", rep(header_char, left_padding), title,
                 rep(header_char, right_padding)))
end

--- Print an empty line
local function print_line()
    print("")
end

-- Export the module with enhanced print as callable
return setmetatable({
    divider = print_divider,
    header = print_header,
    line = print_line,
}, {
    __call = function(_, ...)
        return printf(...)
    end,
})
