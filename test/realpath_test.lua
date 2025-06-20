require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local realpath = require('measure.realpath')

function testcase.realpath_basic_path()
    -- Test basic path normalization
    local result = realpath('a/b/c')
    assert.equal(result, 'a/b/c')
end

function testcase.realpath_empty_string()
    -- Test empty string input
    local result = realpath('')
    assert.equal(result, '')
end

function testcase.realpath_root_path()
    -- Test root path
    local result = realpath('/')
    assert.equal(result, '')
end

function testcase.realpath_single_slash()
    -- Test multiple consecutive slashes
    local result = realpath('a//b///c')
    assert.equal(result, 'a/b/c')
end

function testcase.realpath_current_directory()
    -- Test current directory (.) removal
    local result = realpath('a/./b/./c')
    assert.equal(result, 'a/b/c')
end

function testcase.realpath_parent_directory()
    -- Test parent directory (..) handling
    local result = realpath('a/b/../c')
    assert.equal(result, 'a/c')
end

function testcase.realpath_multiple_parent_directories()
    -- Test multiple parent directories
    local result = realpath('a/b/c/../../d')
    assert.equal(result, 'a/d')
end

function testcase.realpath_parent_beyond_root()
    -- Test parent directory beyond available segments
    local result = realpath('a/../..')
    assert.equal(result, '')
end

function testcase.realpath_complex_path()
    -- Test complex path with mixed elements
    local result = realpath('a/./b/../c/d/../../e')
    assert.equal(result, 'a/e')
end

function testcase.realpath_trailing_slash()
    -- Test path with trailing slash
    local result = realpath('a/b/c/')
    assert.equal(result, 'a/b/c')
end

function testcase.realpath_leading_slash()
    -- Test path with leading slash
    local result = realpath('/a/b/c')
    assert.equal(result, '/a/b/c')
end

function testcase.realpath_only_dots()
    -- Test path with only dots
    local result = realpath('./.')
    assert.equal(result, '')
end

function testcase.realpath_only_parent_dots()
    -- Test path with only parent dots
    local result = realpath('../..')
    assert.equal(result, '')
end

function testcase.realpath_mixed_separators()
    -- Test path with mixed current and parent directories
    local result = realpath('a/./b/../c/./d')
    assert.equal(result, 'a/c/d')
end

function testcase.realpath_deep_nesting()
    -- Test deeply nested path
    local result = realpath('a/b/c/d/e/f/g')
    assert.equal(result, 'a/b/c/d/e/f/g')
end

function testcase.realpath_deep_parent_navigation()
    -- Test deep parent navigation
    local result = realpath('a/b/c/d/e/../../../f')
    assert.equal(result, 'a/b/f')
end

function testcase.realpath_error_non_string()
    -- Test error handling for non-string input
    assert.throws(function()
        realpath(123)
    end, 'path must be a string')
end

function testcase.realpath_error_nil()
    -- Test error handling for nil input
    assert.throws(function()
        realpath(nil)
    end, 'path must be a string')
end

function testcase.realpath_error_table()
    -- Test error handling for table input
    assert.throws(function()
        realpath({})
    end, 'path must be a string')
end

function testcase.realpath_error_function()
    -- Test error handling for function input
    assert.throws(function()
        realpath(function()
        end)
    end, 'path must be a string')
end

function testcase.realpath_single_segment()
    -- Test single segment path
    local result = realpath('file')
    assert.equal(result, 'file')
end

function testcase.realpath_current_dir_only()
    -- Test only current directory
    local result = realpath('.')
    assert.equal(result, '')
end

function testcase.realpath_parent_dir_only()
    -- Test only parent directory
    local result = realpath('..')
    assert.equal(result, '')
end

function testcase.realpath_absolute_with_navigation()
    -- Test absolute path with navigation
    local result = realpath('/a/b/../c')
    assert.equal(result, '/a/c')
end

function testcase.realpath_absolute_root_navigation()
    -- Test absolute path navigation to root
    local result = realpath('/a/..')
    assert.equal(result, '')
end

function testcase.realpath_backslash_mixed()
    -- Test path with mixed separators (Unix-style)
    local result = realpath('a\\b/c')
    assert.equal(result, 'a\\b/c')
end

function testcase.realpath_spaces_in_path()
    -- Test path with spaces
    local result = realpath('a/b c/d')
    assert.equal(result, 'a/b c/d')
end

function testcase.realpath_special_characters()
    -- Test path with special characters
    local result = realpath('a/b-c_d.txt')
    assert.equal(result, 'a/b-c_d.txt')
end

function testcase.realpath_hidden_files()
    -- Test path with hidden files (dot prefix)
    local result = realpath('a/.hidden/file')
    assert.equal(result, 'a/.hidden/file')
end

function testcase.realpath_multiple_consecutive_parent()
    -- Test multiple consecutive parent directories
    local result = realpath('a/../../..')
    assert.equal(result, '')
end

function testcase.realpath_leading_parent()
    -- Test path starting with parent directory
    local result = realpath('../a/b')
    assert.equal(result, 'a/b')
end

function testcase.realpath_absolute_beyond_root()
    -- Test absolute path going beyond root
    local result = realpath('/../..')
    assert.equal(result, '')
end

function testcase.realpath_complex_empty_segments()
    -- Test complex path with multiple empty segments
    local result = realpath('a///b//./c//../d')
    assert.equal(result, 'a/b/d')
end

function testcase.realpath_only_slashes()
    -- Test path with only slashes
    local result = realpath('///')
    assert.equal(result, '')
end

function testcase.realpath_parent_at_start_and_end()
    -- Test parent directories at start and end
    local result = realpath('../a/b/..')
    assert.equal(result, 'a')
end

function testcase.realpath_current_and_parent_mixed()
    -- Test mixed current and parent with complex navigation
    local result = realpath('./a/../b/./c/../d')
    assert.equal(result, 'b/d')
end

function testcase.realpath_absolute_complex_navigation()
    -- Test absolute path with complex navigation
    local result = realpath('/a/./b/../c/d/../e')
    assert.equal(result, '/a/c/e')
end

function testcase.realpath_file_extension_variations()
    -- Test paths with various file extensions
    local result = realpath('dir/file.tar.gz')
    assert.equal(result, 'dir/file.tar.gz')
end

function testcase.realpath_unicode_like_names()
    -- Test paths that might contain unicode-like patterns
    local result = realpath('a/café/b')
    assert.equal(result, 'a/café/b')
end
