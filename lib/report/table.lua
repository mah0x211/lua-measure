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
--- Generic table rendering utilities for benchmark reports
--- Provides flexible table formatting functionality with proper alignment and padding
---
--- Features:
--- - Automatic column width calculation
--- - Numeric value right-alignment within columns
--- - Clean ASCII table output with borders
--- - Title and note support
--- - Input validation for column definitions
---
--- Example usage:
---   local table_utils = require('measure.report.table')
---   local tbl = table_utils.new("Performance Results", "All times in nanoseconds")
---   tbl:render(columns)
---
-- Local references to frequently used functions
local max = math.max
local format = string.format
local rep = string.rep
local concat = table.concat
local find = string.find

-- Constants
local DIVIDER_CHAR = "-"

--- Creates a divider line using the specified character
--- @param char string? Character to use for the divider (default: "-")
--- @param width number Width of the divider line
--- @return string divider The divider line string
local function create_divider(char, width)
    return rep(char or DIVIDER_CHAR, width)
end

--- Creates padding spaces for string alignment
--- @param str string The string to calculate padding for
--- @param maxlen number The target maximum length
--- @return string padding Padding spaces to add
local function create_padding(str, maxlen)
    local len = #str
    return rep(' ', len < maxlen and maxlen - len or 0)
end

--- Appends spaces to the right of a string to reach target width
--- @param str string The string to pad
--- @param width number The target width
--- @return string padded The string with right padding
local function append_space(str, width)
    local spaces = create_padding(str, width)
    return str .. spaces
end

--- Prepends spaces to the left of a string to reach target width
--- @param str string The string to pad
--- @param width number The target width
--- @return string padded The string with left padding
local function prepend_space(str, width)
    local spaces = create_padding(str, width)
    return spaces .. str
end

--- Validates column definitions for consistency
--- Ensures rowwidth matches actual max row length and colwidth is correct
--- @param columns measure.report.table.column[] Array of column definitions
--- @throws error if validation fails
local function validate_columns(columns)
    for i, col in ipairs(columns) do
        -- First validate that rowwidth matches the actual max row length
        local actual_max_len = 0
        for _, row_value in ipairs(col.rows) do
            actual_max_len = max(actual_max_len, #row_value)
        end

        if col.rowwidth ~= actual_max_len then
            error(format("Column %d (%s): rowwidth validation failed! " ..
                             "Expected: %d (actual max row length), Got: %d", i,
                         col.name, actual_max_len, col.rowwidth))
        end

        -- Then validate colwidth using the corrected actual_max_len
        local expected_colwidth = max(#col.name, actual_max_len)
        if col.colwidth ~= expected_colwidth then
            error(format("Column %d (%s): colwidth validation failed! " ..
                             "Expected: %d (max of header_len=%d, actual_max_len=%d), Got: %d",
                         i, col.name, expected_colwidth, #col.name,
                         actual_max_len, col.colwidth))
        end
    end
end

--- @class measure.report.table.column
--- @field name string Column header name
--- @field is_numeric boolean Whether the column contains numeric string values
--- @field colwidth number Width of the column, max of header and rowwidth
--- @field rowwidth number Maximum length of row values
--- @field rows string[] Array of row values
local Column = require('measure.metatable')('measure.report.table.column')

function Column:add_row(value)
    assert(type(value) == 'string', "Row value must be a string")
    self.rows[#self.rows + 1] = value
    -- Update rowwidth if this row is longer
    self.rowwidth = max(self.rowwidth, #value)
    -- Update colwidth if this row is longer than the header
    self.colwidth = max(self.colwidth, #self.name, self.rowwidth)
end

--- @class measure.report.table
--- @field columns measure.report.table.column[] Array of column definitions
local Table = require('measure.metatable')('measure.report.table')

--- Add a new column to the table
--- @param name string Name of the column
--- @param is_numeric boolean? Whether the column contains numeric values (default: false)
function Table:add_column(name, is_numeric)
    assert(type(name) == 'string' and #name > 0,
           "Column name must be a non-empty string")
    assert(is_numeric == nil or type(is_numeric) == 'boolean',
           "is_numeric must be a boolean or nil")

    -- Create a new Column instance with the provided name
    self.columns[#self.columns + 1] = setmetatable({
        name = name,
        colwidth = #name, -- Initial colwidth is just the name length
        rowwidth = 0, -- Default rowwidth, will be calculated later
        rows = {},
        is_numeric = is_numeric == true, -- Default to false if not provided
    }, Column)
end

--- Adds multiple rows to each column in the table.
--- row[1] pushed to column[1], row[2] to column[2], etc.
--- @param rows string[] Array of row values to add
function Table:add_rows(rows)
    -- Validate input
    assert(type(rows) == 'table', "Rows must be a table of strings")

    -- Ensure the number of rows matches the number of columns
    local columns = self.columns
    assert(#rows == #columns, "Number of rows must match number of columns")
    -- Add each row to the corresponding column
    for i, row in ipairs(rows) do
        if type(row) ~= 'string' then
            error(format("Row#%d must be a string, got %s", i, type(row)))
        end
        columns[i]:add_row(row)
    end
end

--- Renders the table and returns formatted lines in Markdown format
--- Applies 2-stage padding logic: numeric values are right-aligned within rowwidth,
--- then left-aligned within colwidth. Non-numeric values are left-aligned within colwidth.
--- @return string[] lines Array of formatted table lines
function Table:render()
    local columns = self.columns
    local lines = {}

    -- Validate columns before rendering
    validate_columns(columns)

    -- Build header row
    local header_parts = {}
    for _, col in ipairs(columns) do
        local name = append_space(col.name, col.colwidth)
        header_parts[#header_parts + 1] = " " .. name .. " "
    end
    lines[#lines + 1] = "|" .. concat(header_parts, "|") .. "|"

    -- Build separator row with alignment hints
    local separator_parts = {}
    for _, col in ipairs(columns) do
        local separator
        if col.is_numeric then
            -- Right-align numeric columns
            separator = create_divider(DIVIDER_CHAR, col.colwidth + 1) .. ":"
        else
            -- Left-align text columns
            separator = ":" .. create_divider(DIVIDER_CHAR, col.colwidth + 1)
        end
        separator_parts[#separator_parts + 1] = separator
    end
    lines[#lines + 1] = "|" .. concat(separator_parts, "|") .. "|"

    -- Add data rows with same padding logic
    if #columns > 0 then
        local num_rows = #columns[1].rows
        for row_idx = 1, num_rows do
            local row_parts = {}
            for _, col in ipairs(columns) do
                local value = col.rows[row_idx] or ""

                -- Apply 2-stage padding logic for consistent alignment
                if not col.is_numeric or not find(value, '^%d') then
                    -- For non-numeric, just left-align within colwidth
                    value = append_space(value, col.colwidth)
                else
                    -- For numeric values, apply 2-stage padding
                    -- Stage 1: Right-align within rowwidth (for numeric alignment)
                    value = prepend_space(value, col.rowwidth)
                    -- Stage 2: Left-align within colwidth (for column width)
                    value = append_space(value, col.colwidth)
                end

                row_parts[#row_parts + 1] = " " .. value .. " "
            end
            lines[#lines + 1] = "|" .. concat(row_parts, "|") .. "|"
        end
    end

    lines[#lines + 1] = ""
    return lines
end

--- Creates a new Table instance
--- @return measure.report.table
local function new_table()
    -- Create a new Table instance with the provided title and note
    return setmetatable({
        columns = {}, -- Initialize empty columns array
    }, Table)
end

-- Export the module
return new_table
