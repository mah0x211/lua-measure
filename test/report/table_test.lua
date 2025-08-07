require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local table_utils = require('measure.report.table')

function testcase.new_table()
    -- Valid creation
    local tbl = table_utils.new_table("Test Title")
    assert.is_table(tbl)

    local tbl_with_note = table_utils.new_table("Test Title", "Test Note")
    assert.is_table(tbl_with_note)

    -- Invalid arguments
    local err = assert.throws(function()
        table_utils.new_table()
    end)
    assert.match(err, "Table title must be a non-empty string")

    err = assert.throws(function()
        table_utils.new_table("")
    end)
    assert.match(err, "Table title must be a non-empty string")

    err = assert.throws(function()
        table_utils.new_table("Title", 123)
    end)
    assert.match(err, "Table note must be a string or nil")
end

function testcase.add_column()
    local tbl = table_utils.new_table("Test")

    -- Non-numeric column
    tbl:add_column("Name")
    assert.equal(#tbl.columns, 1)
    assert.equal(tbl.columns[1].name, "Name")
    assert.is_false(tbl.columns[1].is_numeric)

    -- Numeric column
    tbl:add_column("Value", true)
    assert.equal(#tbl.columns, 2)
    assert.equal(tbl.columns[2].name, "Value")
    assert.is_true(tbl.columns[2].is_numeric)

    -- Invalid arguments
    local err = assert.throws(function()
        tbl:add_column()
    end)
    assert.match(err, "Column name must be a non-empty string")

    err = assert.throws(function()
        tbl:add_column("")
    end)
    assert.match(err, "Column name must be a non-empty string")

    err = assert.throws(function()
        tbl:add_column("Test", "not_boolean")
    end)
    assert.match(err, "is_numeric must be a boolean or nil")
end

function testcase.add_row()
    local tbl = table_utils.new_table("Test")
    tbl:add_column("Name")
    local column = tbl.columns[1]

    -- Valid row
    column:add_row("Test Value")
    assert.equal(#column.rows, 1)
    assert.equal(column.rows[1], "Test Value")
    assert.equal(column.rowwidth, 10)
    assert.equal(column.colwidth, 10)

    -- Invalid type
    local err = assert.throws(function()
        column:add_row(123)
    end)
    assert.match(err, "Row value must be a string")
end

function testcase.add_rows()
    local tbl = table_utils.new_table("Test")
    tbl:add_column("Name")
    tbl:add_column("Value", true)

    -- Valid rows
    tbl:add_rows({
        "Alice",
        "100",
    })
    tbl:add_rows({
        "Bob",
        "200",
    })

    assert.equal(#tbl.columns[1].rows, 2)
    assert.equal(#tbl.columns[2].rows, 2)
    assert.equal(tbl.columns[1].rows[1], "Alice")
    assert.equal(tbl.columns[2].rows[1], "100")

    -- Invalid type
    local err = assert.throws(function()
        tbl:add_rows("not_table")
    end)
    assert.match(err, "Rows must be a table of strings")

    -- Column count mismatch
    err = assert.throws(function()
        tbl:add_rows({
            "Alice",
        })
    end)
    assert.match(err, "Number of rows must match number of columns")

    -- Non-string value
    err = assert.throws(function()
        tbl:add_rows({
            "Alice",
            123,
        })
    end)
    assert.match(err, "Row#2 must be a string", false)
end

function testcase.render_basic()
    local tbl = table_utils.new_table("Test Results")
    tbl:add_column("Name")
    tbl:add_column("Value", true)
    tbl:add_rows({
        "Alice",
        "100",
    })
    tbl:add_rows({
        "Bob",
        "200",
    })

    local lines = tbl:render()
    assert.is_table(lines)
    assert.greater(#lines, 0)
    assert.equal(lines[1], "### Test Results")

    -- Verify table structure contains expected elements
    local has_header = false
    local data_count = 0

    for _, line in ipairs(lines) do
        if line:match("Name.*Value") then
            has_header = true
        elseif line:match("Alice") or line:match("Bob") then
            data_count = data_count + 1
        end
    end

    assert.is_true(has_header)
    assert.equal(data_count, 2)
end

function testcase.render_with_note()
    local tbl = table_utils.new_table("Test Results", "All values in seconds")
    tbl:add_column("Test")
    tbl:add_rows({
        "Sample",
    })

    local lines = tbl:render()
    assert.equal(lines[1], "### Test Results")
    assert.equal(lines[2], "")
    assert.equal(lines[3], "*All values in seconds*")
end

function testcase.render_empty_table()
    local tbl = table_utils.new_table("Empty Table")

    local lines = tbl:render()
    assert.is_table(lines)
    assert.greater(#lines, 0)
    assert.equal(lines[1], "### Empty Table")
end

function testcase.render_numeric_alignment()
    local tbl = table_utils.new_table("Numeric Test")
    tbl:add_column("Name")
    tbl:add_column("Value", true)
    tbl:add_rows({
        "Short",
        "1",
    })
    tbl:add_rows({
        "LongName",
        "12345",
    })

    local lines = tbl:render()

    -- Verify numeric values are present
    local values_found = 0
    for _, line in ipairs(lines) do
        if line:match("1") or line:match("12345") then
            values_found = values_found + 1
        end
    end

    assert.greater_or_equal(values_found, 2)
end

function testcase.render_non_numeric_alignment()
    local tbl = table_utils.new_table("Non-Numeric Test")
    tbl:add_column("Name")
    tbl:add_column("Description", false)
    tbl:add_rows({
        "Test1",
        "abc",
    })
    tbl:add_rows({
        "Test2",
        "123def",
    })

    local lines = tbl:render()
    assert.is_table(lines)
    assert.greater(#lines, 0)
end

function testcase.validation_errors()
    local tbl = table_utils.new_table("Test")
    tbl:add_column("Name")
    tbl:add_rows({
        "Test",
    })

    -- Test rowwidth validation
    tbl.columns[1].rowwidth = 999
    local err = assert.throws(function()
        tbl:render()
    end)
    assert.match(err, "rowwidth validation failed")

    -- Test colwidth validation
    tbl.columns[1].rowwidth = 4
    tbl.columns[1].colwidth = 999
    err = assert.throws(function()
        tbl:render()
    end)
    assert.match(err, "colwidth validation failed")
end

function testcase.render_markdown_format()
    local tbl = table_utils.new_table("Benchmark Results",
                                      "All times in milliseconds")
    tbl:add_column("Rank", true)
    tbl:add_column("Name")
    tbl:add_column("95% CI")
    tbl:add_column("CI Width", true)
    tbl:add_column("RCIW", true)
    tbl:add_column("Quality")

    tbl:add_rows({
        "1",
        "basexx v2",
        "[29.330 ms, 29.402 ms]",
        "71.888 us",
        "0.2%",
        "excellent",
    })
    tbl:add_rows({
        "2",
        "basexx v1",
        "[29.599 ms, 29.673 ms]",
        "74.290 us",
        "0.3%",
        "excellent",
    })

    -- Test default markdown format
    local lines = tbl:render()
    assert.is_table(lines)
    assert.greater(#lines, 0)

    -- Check title in markdown format
    assert.equal(lines[1], "### Benchmark Results")
    assert.equal(lines[2], "")
    assert.equal(lines[3], "*All times in milliseconds*")

    -- Check for markdown separator line with alignment indicators
    local has_separator = false
    for _, line in ipairs(lines) do
        if line:match("|%-+:?|") then
            has_separator = true
            break
        end
    end
    assert.is_true(has_separator, "Should have markdown separator line")

    -- Check data is present
    local has_data = false
    for _, line in ipairs(lines) do
        if line:match("basexx") then
            has_data = true
            break
        end
    end
    assert.is_true(has_data, "Should have data rows")
end

function testcase.render_default_format()
    local tbl = table_utils.new_table("Test")
    tbl:add_column("Name")
    tbl:add_rows({
        "Test",
    })

    -- Default should be markdown
    local lines = tbl:render()
    assert.is_table(lines)

    -- Check for markdown-style title
    assert.equal(lines[1], "### Test")

    -- Check for markdown separator line
    local has_separator = false
    for _, line in ipairs(lines) do
        if line:find("|") and line:find("%-") then
            has_separator = true
            break
        end
    end
    assert.is_true(has_separator, "Should have markdown separator line")
end

function testcase.numeric_alignment()
    local tbl = table_utils.new_table("Numeric Alignment Test")
    tbl:add_column("Index", true)
    tbl:add_column("Name")
    tbl:add_column("Score", true)

    tbl:add_rows({
        "1",
        "Alice",
        "100",
    })
    tbl:add_rows({
        "2",
        "Bob",
        "99",
    })
    tbl:add_rows({
        "10",
        "Charlie",
        "1000",
    })

    local lines = tbl:render()

    -- Check separator line has correct alignment hints
    local separator_line
    for _, line in ipairs(lines) do
        if line:match("|%-+:?|") then
            separator_line = line
            break
        end
    end

    assert.is_string(separator_line, "Should have separator line")
    -- Numeric columns should end with ':'
    local parts = {}
    for part in separator_line:gmatch("|([^|]+)") do
        parts[#parts + 1] = part
    end

    -- First column (Index) is numeric, should end with ':'
    assert.equal(parts[1]:sub(-1), ":")
    -- Second column (Name) is text, should start with ':'
    assert.equal(parts[2]:sub(1, 1), ":")
    -- Third column (Score) is numeric, should end with ':'
    assert.equal(parts[3]:sub(-1), ":")
end

function testcase.column_width_calculation()
    local tbl = table_utils.new_table("Width Test")
    tbl:add_column("A")

    -- Row longer than header
    tbl.columns[1]:add_row("Very Long Value")
    assert.equal(tbl.columns[1].colwidth, 15)

    -- Header longer than row
    tbl:add_column("Very Very Long Header Name")
    assert.equal(tbl.columns[2].colwidth, 26)
end
