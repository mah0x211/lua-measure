require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local listfiles = require('measure.listfiles')

local TMPDIR
local TEST_DIRS = {}
local TEST_FILES = {}

function testcase.before_all()
    -- Create temporary directory structure once
    TMPDIR = os.tmpname()
    os.remove(TMPDIR)

    -- Define directory structure (order matters: parents before children)
    TEST_DIRS = {
        TMPDIR,
        TMPDIR .. '/dir',
        TMPDIR .. '/dir/subdir',
        TMPDIR .. '/empty',
        TMPDIR .. '/space dir',
    }

    -- Create directories
    for _, dir in ipairs(TEST_DIRS) do
        assert(os.execute('mkdir -p "' .. dir .. '"'))
    end

    -- Define test files
    TEST_FILES = {
        -- Single file test
        TMPDIR .. '/single_bench.lua',

        -- Directory test files
        TMPDIR .. '/dir/test1_bench.lua',
        TMPDIR .. '/dir/test2_bench.lua',
        TMPDIR .. '/dir/another_bench.lua',
        TMPDIR .. '/dir/notbench.lua', -- should not match
        TMPDIR .. '/dir/bench_test.lua', -- should not match

        -- Subdirectory file (should not be found)
        TMPDIR .. '/dir/subdir/sub_bench.lua',

        -- Space in path test
        TMPDIR .. '/space dir/my_bench.lua',
    }

    -- Create files
    for _, filepath in ipairs(TEST_FILES) do
        assert(io.open(filepath, 'w')):close()
    end
end

function testcase.after_all()
    -- Cleanup temporary files and directories safely
    if TMPDIR then
        -- Remove all files
        for _, filepath in ipairs(TEST_FILES) do
            os.remove(filepath)
        end

        -- Remove directories in reverse order (children before parents)
        for i = #TEST_DIRS, 1, -1 do
            os.remove(TEST_DIRS[i])
        end
    end
end

function testcase.listfiles_with_file()
    -- Test with single file
    local filepath = TMPDIR .. '/single_bench.lua'
    local files, err = listfiles(filepath)
    assert.is_nil(err)
    assert.equal(files, {
        filepath,
    })
end

function testcase.listfiles_with_directory()
    -- Test with directory containing mixed files
    local files, err = listfiles(TMPDIR .. '/dir')
    assert.is_nil(err)

    local expected = {
        TMPDIR .. '/dir/another_bench.lua',
        TMPDIR .. '/dir/test1_bench.lua',
        TMPDIR .. '/dir/test2_bench.lua',
    }

    table.sort(files)
    table.sort(expected)
    assert.equal(files, expected)
end

function testcase.listfiles_with_empty_directory()
    -- Test with empty directory
    local files, err = listfiles(TMPDIR .. '/empty')
    assert.is_nil(err)
    assert.equal(files, {})
end

function testcase.listfiles_with_space_in_path()
    -- Test with directory path containing spaces
    local files, err = listfiles(TMPDIR .. '/space dir')
    assert.is_nil(err)
    assert.equal(files, {
        TMPDIR .. '/space dir/my_bench.lua',
    })
end

function testcase.listfiles_with_nonexistent_path()
    -- Test with non-existent path
    local files, err = listfiles('/nonexistent/path')
    assert.is_nil(files)
    assert.match(err, 'must point to a file or directory')
end

function testcase.listfiles_with_invalid_type()
    -- Test with invalid argument type
    local ok, err = pcall(listfiles, nil)
    assert.is_false(ok)
    assert.match(err, 'pathname must be a string')
end
