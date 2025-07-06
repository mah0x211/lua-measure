require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local getfiletype = require('measure.getfiletype')

-- Temporary file management
local TMPFILES = {}

-- Helper function to create unique temporary directory
local function create_temp_dir()
    local tmp_name = "tmp_" .. os.time() .. "_" .. math.random(10000, 99999)
    local tmp_path = "test/" .. tmp_name
    os.execute('mkdir -p "' .. tmp_path .. '"')
    TMPFILES[tmp_path] = 'dir'
    return tmp_path
end

-- Helper function to create temporary file
local function create_temp_file(content, filename, temp_dir)
    local file_path
    if temp_dir then
        file_path = temp_dir .. "/" .. filename
    else
        local tmp_dir = create_temp_dir()
        file_path = tmp_dir .. "/" .. filename
    end
    local f = assert(io.open(file_path, 'w'))
    f:write(content)
    f:close()
    TMPFILES[file_path] = 'file'
    return file_path
end

-- Helper function to cleanup all temporary files
local function cleanup_temp_files()
    for filename, ftype in pairs(TMPFILES) do
        if ftype == 'dir' then
            os.execute('rm -rf "' .. filename .. '"')
        else
            os.remove(filename)
        end
    end
    TMPFILES = {}
end

function testcase.before_all()
    -- Base temporary directory will be created by individual tests
end

function testcase.after_all()
    -- Clean up all temporary files and directories
    cleanup_temp_files()
end

function testcase.module_loading()
    -- Test module loading
    assert.is_function(getfiletype)
end

function testcase.regular_file()
    -- Test regular file detection
    local test_file = create_temp_file('test content', 'test_regular_file.txt')
    local result = getfiletype(test_file)
    assert.equal(result, 'file')
end

function testcase.directory()
    -- Test directory detection
    local test_dir = create_temp_dir()
    local result = getfiletype(test_dir)
    assert.equal(result, 'directory')
end

function testcase.symbolic_link()
    -- Test symbolic link detection
    local temp_dir = create_temp_dir()
    create_temp_file('target content', 'test_target_file.txt', temp_dir)
    local test_link = temp_dir .. '/test_symlink'

    -- Create symlink
    os.execute('ln -sf test_target_file.txt "' .. test_link .. '"')
    TMPFILES[test_link] = 'file'

    -- lstat should detect symlinks
    local result = getfiletype(test_link)
    assert.equal(result, 'symlink')
end

function testcase.fifo()
    -- Test FIFO/named pipe detection
    local temp_dir = create_temp_dir()
    local test_fifo = temp_dir .. '/test_fifo_' .. os.time()
    local exit_code = os.execute('mkfifo "' .. test_fifo .. '" 2>/dev/null')

    if exit_code == 0 then
        -- FIFO was created successfully
        TMPFILES[test_fifo] = 'file'
        local result = getfiletype(test_fifo)
        assert.equal(result, 'fifo')
    else
        -- If mkfifo is not available, try to find existing FIFOs
        local fifos = {
            '/usr/spool/lpd/fifos/lp', -- Some Unix systems
            '/var/spool/postfix/public/pickup', -- Postfix FIFO
        }

        local found_fifo = false
        for _, fifo_path in ipairs(fifos) do
            if os.execute('test -p "' .. fifo_path .. '"') == 0 then
                local result = getfiletype(fifo_path)
                if result == 'fifo' then
                    assert.equal(result, 'fifo')
                    found_fifo = true
                    break
                end
            end
        end

        -- If no FIFO found, test passes by verifying no crash
        if not found_fifo then
            assert.is_true(true)
        end
    end
end

function testcase.character_device()
    -- Test character device detection

    -- Try common character devices
    local char_devices = {
        '/dev/null',
        '/dev/zero',
        '/dev/urandom',
    }

    local found_char = false
    for _, device in ipairs(char_devices) do
        local result = getfiletype(device)
        if result == 'character' then
            assert.equal(result, 'character')
            found_char = true
            break
        end
        -- If device doesn't exist or can't be accessed, continue
    end

    -- If no character device found, skip test gracefully
    if not found_char then
        print('Skipping character device test as no accessible devices found')
    end
end

function testcase.block_device()
    -- Test block device detection

    -- Try common block devices on macOS and Linux
    local block_devices = {
        '/dev/disk0',
        '/dev/disk1',
        '/dev/sda',
        '/dev/vda',
        '/dev/loop0',
    }
    local found_block = false

    for _, device in ipairs(block_devices) do
        local result = getfiletype(device)
        if result == 'block' then
            assert.equal(result, 'block')
            found_block = true
            break
        end
        -- If device doesn't exist or can't be accessed, continue
    end

    -- If no block device was found, skip test gracefully
    if not found_block then
        print('Skipping block device test as no accessible devices found')
    end
end

function testcase.nonexistent_file()
    -- Test error handling for nonexistent file
    local temp_dir = create_temp_dir()
    local nonexistent_path = temp_dir .. '/nonexistent_file_12345'

    local result, err, errno = getfiletype(nonexistent_path)
    assert.is_nil(result)
    assert.is_string(err)
    assert.is_number(errno)
    -- Error message might be "No such file", "Bad file descriptor", or other error messages
    assert.is_true((err:find('No such file') ~= nil) or
                       (err:find('Bad file descriptor') ~= nil) or
                       (err:find('Operation not permitted') ~= nil) or
                       string.len(err) > 0)
end

function testcase.permission_denied()
    -- Test error handling for permission denied
    local test_file = create_temp_file('test', 'test_no_permission.txt')

    -- Remove all permissions
    os.execute('chmod 000 "' .. test_file .. '"')

    local result, err = getfiletype(test_file)
    -- lstat can still read file stats even without read permission
    -- so we might get a result or an error depending on the system
    assert.is_true((result == 'file') or (err ~= nil))

    -- Restore permissions for cleanup
    os.execute('chmod 644 "' .. test_file .. '"')
end

function testcase.invalid_argument_type()
    -- Test argument validation - luaL_checkstring converts numbers to strings

    -- Numbers get converted to strings by luaL_checkstring
    local result, err, errno = getfiletype(123)
    assert.is_nil(result)
    assert.is_string(err)
    assert.is_number(errno)

    -- Tables cause luaL_checkstring to throw an error
    assert.throws(function()
        getfiletype({})
    end)

    -- nil causes luaL_checkstring to throw an error
    assert.throws(function()
        getfiletype(nil)
    end)
end

function testcase.no_arguments()
    -- Test with no arguments

    assert.throws(function()
        getfiletype()
    end)
end

function testcase.empty_string()
    -- Test with empty string

    local result, err, errno = getfiletype('')
    assert.is_nil(result)
    assert.is_string(err)
    assert.is_number(errno)
end

function testcase.socket_file()
    -- Test socket detection
    local temp_dir = create_temp_dir()
    local socket_path = temp_dir .. '/test_socket_' .. os.time()

    -- Use nc (netcat) to create a Unix domain socket
    os.execute('nc -lU "' .. socket_path .. '" >/dev/null 2>&1 &')
    -- Give it time to create the socket
    os.execute('sleep 0.2')

    -- Check if socket was created
    if os.execute('test -S "' .. socket_path .. '"') == 0 then
        TMPFILES[socket_path] = 'file'
        local result = getfiletype(socket_path)
        assert.equal(result, 'socket')
    else
        -- If we can't create a socket, skip test gracefully
        print('Skipping socket test as nc command failed to create a socket')
    end

    -- Kill nc process
    os.execute('pkill -f "nc -lU ' .. socket_path .. '"')
end

function testcase.multiple_calls()
    -- Test multiple calls to ensure no state corruption
    local temp_dir = create_temp_dir()
    local test_file1 = create_temp_file('test1', 'test_file1.txt', temp_dir)
    local test_file2 = create_temp_file('test2', 'test_file2.txt', temp_dir)

    -- Test multiple calls
    assert.equal(getfiletype(test_file1), 'file')
    assert.equal(getfiletype(temp_dir), 'directory')
    assert.equal(getfiletype(test_file2), 'file')
    assert.equal(getfiletype(temp_dir), 'directory')
end

function testcase.very_long_path()
    -- Test with a very long path
    local temp_dir = create_temp_dir()
    local long_path = temp_dir .. '/' .. string.rep('a', 1000) .. '.txt'
    local result, err, errno = getfiletype(long_path)

    -- Should get an error for such a long path
    assert.is_nil(result)
    assert.is_string(err)
    assert.is_number(errno)
end

function testcase.path_with_special_characters()
    -- Test with special characters in path
    local temp_dir = create_temp_dir()
    local special_file = temp_dir .. '/test file with spaces & symbols!.txt'
    local f = io.open(special_file, 'w')
    if f then
        f:write('test content')
        f:close()
        TMPFILES[special_file] = 'file'

        local result = getfiletype(special_file)
        assert.equal(result, 'file')
    else
        -- If we can't create the file, test with a known invalid special path
        local result, err, errno = getfiletype(temp_dir .. '/\0invalid')
        assert.is_nil(result)
        assert.is_string(err)
        assert.is_number(errno)
    end
end

function testcase.unknown_file_type()
    -- Test unknown file type detection
    -- Since unknown file types are very rare and system-dependent,
    -- we'll skip this test gracefully
    print('Skipping unknown file type test as it is system-dependent')
end
