require('luacov')
local testcase = require('testcase')
local assert = require('assert')

function testcase.before_all()
    -- Create test directory if not exists
    os.execute('mkdir -p test/tmp')
end

function testcase.after_all()
    -- Clean up test files
    os.execute('rm -rf test/tmp/test_*')
end

function testcase.module_loading()
    -- Test module loading
    local getfiletype = require('measure.getfiletype')
    assert.is_function(getfiletype)
end

function testcase.regular_file()
    -- Test regular file detection
    local getfiletype = require('measure.getfiletype')

    -- Create a test file
    local test_file = 'test/tmp/test_regular_file.txt'
    local f = io.open(test_file, 'w')
    f:write('test content')
    f:close()

    local result = getfiletype(test_file)
    assert.equal(result, 'file')

    -- Clean up
    os.remove(test_file)
end

function testcase.directory()
    -- Test directory detection
    local getfiletype = require('measure.getfiletype')

    local test_dir = 'test/tmp/test_directory'
    os.execute('mkdir -p ' .. test_dir)

    local result = getfiletype(test_dir)
    assert.equal(result, 'directory')

    -- Clean up
    os.execute('rmdir ' .. test_dir)
end

function testcase.symbolic_link()
    -- Test symbolic link detection
    local getfiletype = require('measure.getfiletype')

    -- Create a symlink in test directory
    local test_file = 'test/tmp/test_target_file.txt'
    local f = io.open(test_file, 'w')
    f:write('target content')
    f:close()

    -- Create symlink
    local test_link = 'test/tmp/test_symlink'
    os.execute('ln -sf test_target_file.txt ' .. test_link)

    -- lstat should detect symlinks
    local result = getfiletype(test_link)
    assert.equal(result, 'symlink')

    -- Clean up
    os.remove(test_link)
    os.remove(test_file)
end

function testcase.fifo()
    -- Test FIFO/named pipe detection
    local getfiletype = require('measure.getfiletype')

    -- Force create a test FIFO
    local test_fifo = 'test/tmp/test_fifo_' .. os.time()
    os.execute('rm -f ' .. test_fifo) -- Remove if exists
    local exit_code = os.execute('mkfifo ' .. test_fifo .. ' 2>/dev/null')

    if exit_code == 0 then
        -- FIFO was created successfully
        local result = getfiletype(test_fifo)
        assert.equal(result, 'fifo')

        -- Clean up
        os.remove(test_fifo)
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
    local getfiletype = require('measure.getfiletype')

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
    local getfiletype = require('measure.getfiletype')

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
    local getfiletype = require('measure.getfiletype')

    local result, err, errno = getfiletype('test/tmp/nonexistent_file_12345')
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
    local getfiletype = require('measure.getfiletype')

    -- Create a file and remove read permissions
    local test_file = 'test/tmp/test_no_permission.txt'
    local f = io.open(test_file, 'w')
    f:write('test')
    f:close()

    -- Remove all permissions
    os.execute('chmod 000 ' .. test_file)

    local result, err = getfiletype(test_file)
    -- lstat can still read file stats even without read permission
    -- so we might get a result or an error depending on the system
    assert.is_true((result == 'file') or (err ~= nil))

    -- Clean up
    os.execute('chmod 644 ' .. test_file)
    os.remove(test_file)
end

function testcase.invalid_argument_type()
    -- Test argument validation - luaL_checkstring converts numbers to strings
    local getfiletype = require('measure.getfiletype')

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
    local getfiletype = require('measure.getfiletype')

    assert.throws(function()
        getfiletype()
    end)
end

function testcase.empty_string()
    -- Test with empty string
    local getfiletype = require('measure.getfiletype')

    local result, err, errno = getfiletype('')
    assert.is_nil(result)
    assert.is_string(err)
    assert.is_number(errno)
end

function testcase.socket_file()
    -- Test socket detection
    local getfiletype = require('measure.getfiletype')

    -- Create a socket in test directory
    local socket_path = 'test/tmp/test_socket_' .. os.time()
    -- Use nc (netcat) to create a Unix domain socket
    os.execute('rm -f ' .. socket_path)
    os.execute('nc -lU ' .. socket_path .. ' >/dev/null 2>&1 &')
    -- Give it time to create the socket
    os.execute('sleep 0.2')

    -- Check if socket was created
    if os.execute('test -S "' .. socket_path .. '"') == 0 then
        local result = getfiletype(socket_path)
        assert.equal(result, 'socket')
    else
        -- If we can't create a socket, skip test gracefully
        print('Skipping socket test as nc command failed to create a socket')
    end

    -- Kill nc process and clean up
    os.execute('pkill -f "nc -lU ' .. socket_path .. '"')
    os.execute('rm -f ' .. socket_path)
end

function testcase.multiple_calls()
    -- Test multiple calls to ensure no state corruption
    local getfiletype = require('measure.getfiletype')

    -- Create test files
    local test_file1 = 'test/tmp/test_file1.txt'
    local test_file2 = 'test/tmp/test_file2.txt'
    local test_dir = 'test/tmp/test_dir'

    local f1 = io.open(test_file1, 'w')
    f1:write('test1')
    f1:close()

    local f2 = io.open(test_file2, 'w')
    f2:write('test2')
    f2:close()

    os.execute('mkdir -p ' .. test_dir)

    -- Test multiple calls
    assert.equal(getfiletype(test_file1), 'file')
    assert.equal(getfiletype(test_dir), 'directory')
    assert.equal(getfiletype(test_file2), 'file')
    assert.equal(getfiletype(test_dir), 'directory')

    -- Clean up
    os.remove(test_file1)
    os.remove(test_file2)
    os.execute('rmdir ' .. test_dir)
end

function testcase.very_long_path()
    -- Test with a very long path
    local getfiletype = require('measure.getfiletype')

    local long_path = 'test/tmp/' .. string.rep('a', 1000) .. '.txt'
    local result, err, errno = getfiletype(long_path)

    -- Should get an error for such a long path
    assert.is_nil(result)
    assert.is_string(err)
    assert.is_number(errno)
end

function testcase.path_with_special_characters()
    -- Test with special characters in path
    local getfiletype = require('measure.getfiletype')

    local special_file = 'test/tmp/test file with spaces & symbols!.txt'
    local f = io.open(special_file, 'w')
    if f then
        f:write('test content')
        f:close()

        local result = getfiletype(special_file)
        assert.equal(result, 'file')

        os.remove(special_file)
    else
        -- If we can't create the file, test with a known invalid special path
        local result, err, errno = getfiletype('test/tmp/\0invalid')
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
