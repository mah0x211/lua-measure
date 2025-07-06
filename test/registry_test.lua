require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local registry = require('measure.registry')
local new_spec = require('measure.spec')

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

-- Helper function to create temporary file path (not actual file)
local function create_temp_file_path(filename, temp_dir)
    local file_path
    if temp_dir then
        file_path = temp_dir .. "/" .. filename
    else
        local tmp_dir = create_temp_dir()
        file_path = tmp_dir .. "/" .. filename
    end
    -- Mark the file path for cleanup even if we don't create the actual file
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

function testcase.after_all()
    -- Clean up all temporary files and directories
    cleanup_temp_files()
end

function testcase.add_spec_valid()
    -- Clear registry for clean state
    registry.clear()

    -- Create a valid spec
    local spec = new_spec()
    local test_file = create_temp_file_path('registry_test.lua')

    -- Test adding a valid spec
    local ok, err = registry.add(test_file, spec)
    assert.is_true(ok)
    assert.is_nil(err)

    -- Verify it was added
    local reg = registry.get()
    assert.equal(reg[test_file], spec)
end

function testcase.add_spec_invalid_key()
    registry.clear()
    local spec = new_spec()

    -- Test with non-string key
    local ok, err = registry.add(123, spec)
    assert.is_false(ok)
    assert.equal(err, 'key must be a string, got number')

    ok, err = registry.add(true, spec)
    assert.is_false(ok)
    assert.equal(err, 'key must be a string, got boolean')

    ok, err = registry.add({}, spec)
    assert.is_false(ok)
    assert.equal(err, 'key must be a string, got table')
end

function testcase.add_spec_invalid_spec()
    registry.clear()

    -- Test with non-spec object
    local ok, err = registry.add('test.lua', 'not a spec')
    assert.is_false(ok)
    assert.match(err, 'spec must be a measure%.spec', false)

    ok, err = registry.add('test.lua', 123)
    assert.is_false(ok)
    assert.match(err, 'spec must be a measure%.spec', false)

    ok, err = registry.add('test.lua', {})
    assert.is_false(ok)
    assert.match(err, 'spec must be a measure%.spec', false)
end

function testcase.add_spec_nonexistent_file()
    registry.clear()
    local spec = new_spec()

    -- Test with non-existent file (now allowed)
    local ok, err = registry.add('nonexistent_file.lua', spec)
    assert.is_true(ok)
    assert.is_nil(err)

    -- Verify it was added
    local retrieved = registry.get('nonexistent_file.lua')
    assert.equal(retrieved, spec)
end

function testcase.get_empty_registry()
    -- Clear and test empty registry
    registry.clear()
    local reg = registry.get()
    assert.is_table(reg)

    -- Should be empty
    local count = 0
    for _ in pairs(reg) do
        count = count + 1
    end
    assert.equal(count, 0)
end

function testcase.get_populated_registry()
    registry.clear()

    -- Add multiple specs
    local spec1 = new_spec()
    local spec2 = new_spec()

    local temp_dir = create_temp_dir()
    local current_file = create_temp_file_path('registry_test.lua', temp_dir)
    local other_file = create_temp_file_path('spec_test.lua', temp_dir)
    registry.add(current_file, spec1)
    registry.add(other_file, spec2)

    -- Get registry
    local reg = registry.get()
    assert.is_table(reg)

    -- Verify contents
    assert.equal(reg[current_file], spec1)
    assert.equal(reg[other_file], spec2)

    -- Count entries
    local count = 0
    for key, spec in pairs(reg) do
        assert.is_string(key)
        assert.is_table(spec)
        local spec_str = tostring(spec)
        assert.is_true(spec_str:find('measure%.spec') ~= nil)
        count = count + 1
    end
    assert.equal(count, 2)
end

function testcase.clear_registry()
    -- Add some specs first
    local spec1 = new_spec()
    local spec2 = new_spec()
    local temp_dir = create_temp_dir()
    registry.add(create_temp_file_path('registry_test.lua', temp_dir), spec1)
    registry.add(create_temp_file_path('spec_test.lua', temp_dir), spec2)

    -- Verify they are there
    local reg = registry.get()
    local count = 0
    for _ in pairs(reg) do
        count = count + 1
    end
    assert(count >= 2)

    -- Clear registry
    registry.clear()

    -- Verify it's empty
    reg = registry.get()
    count = 0
    for _ in pairs(reg) do
        count = count + 1
    end
    assert.equal(count, 0)
end

function testcase.multiple_specs_same_file()
    registry.clear()

    local spec1 = new_spec()
    local spec2 = new_spec()

    -- Add first spec
    local test_file = create_temp_file_path('registry_test.lua')
    local ok, err = registry.add(test_file, spec1)
    assert.is_true(ok)
    assert.is_nil(err)

    -- Adding another spec to the same file should fail with duplicate error
    ok, err = registry.add(test_file, spec2)
    assert.is_false(ok)
    assert.match(err, 'already exists in the registry', false)

    -- Verify the first spec is still there
    local reg = registry.get()
    assert.equal(reg[test_file], spec1)
    assert.is_true(reg[test_file] ~= spec2) -- Use direct comparison
end

function testcase.spec_with_hooks_and_describes()
    registry.clear()

    -- Create a spec with hooks and describes
    local spec = new_spec()
    spec:set_hook('before_all', function()
        return 'setup'
    end)
    spec:new_describe('Test Benchmark')

    -- Add to registry
    local test_file = create_temp_file_path('registry_test.lua')
    local ok, err = registry.add(test_file, spec)
    assert.is_true(ok)
    assert.is_nil(err)

    -- Retrieve and verify
    local reg = registry.get()
    local retrieved_spec = reg[test_file]
    assert.equal(retrieved_spec, spec)
    assert.is_function(retrieved_spec.hooks.before_all)
    assert.equal(retrieved_spec.hooks.before_all(), 'setup')
    assert.equal(#retrieved_spec.describes, 1)
    assert.equal(tostring(retrieved_spec.describes[1]),
                 'measure.describe "Test Benchmark"')
end

function testcase.registry_isolation()
    registry.clear()

    -- Create independent specs
    local spec1 = new_spec()
    local spec2 = new_spec()

    -- Configure them differently
    spec1:set_hook('before_all', function()
        return 'spec1'
    end)
    spec1:new_describe('Spec1 Test')

    spec2:set_hook('after_all', function()
        return 'spec2'
    end)
    spec2:new_describe('Spec2 Test')

    -- Add to registry using temporary file paths
    local temp_dir = create_temp_dir()
    local file1 = create_temp_file_path('registry_test.lua', temp_dir)
    local file2 = create_temp_file_path('spec_test.lua', temp_dir)
    registry.add(file1, spec1)
    registry.add(file2, spec2)

    -- Verify isolation
    local reg = registry.get()
    local retrieved_spec1 = reg[file1]
    local retrieved_spec2 = reg[file2]

    assert.not_equal(retrieved_spec1, retrieved_spec2)
    assert.equal(retrieved_spec1.hooks.before_all(), 'spec1')
    assert.equal(retrieved_spec2.hooks.after_all(), 'spec2')
    assert.is_nil(retrieved_spec1.hooks.after_all)
    assert.is_nil(retrieved_spec2.hooks.before_all)
    assert.equal(retrieved_spec1.describes['Spec1 Test'].spec.name, 'Spec1 Test')
    assert.equal(retrieved_spec2.describes['Spec2 Test'].spec.name, 'Spec2 Test')
end

function testcase.get_specific_key()
    registry.clear()

    -- Add multiple specs
    local spec1 = new_spec()
    local spec2 = new_spec()

    local temp_dir = create_temp_dir()
    local key1 = create_temp_file_path('registry_test.lua', temp_dir)
    local key2 = create_temp_file_path('spec_test.lua', temp_dir)
    registry.add(key1, spec1)
    registry.add(key2, spec2)

    -- Get specific spec by key
    local retrieved_spec1 = registry.get(key1)
    local retrieved_spec2 = registry.get(key2)

    assert.equal(retrieved_spec1, spec1)
    assert.equal(retrieved_spec2, spec2)
    assert.is_true(retrieved_spec1 ~= retrieved_spec2)
end

function testcase.get_with_nil_parameter()
    registry.clear()

    -- Add a spec
    local spec = new_spec()
    local key = create_temp_file_path('registry_test.lua')
    registry.add(key, spec)

    -- Explicitly pass nil to get all specs
    local reg = registry.get(nil)
    assert.is_table(reg)
    assert.equal(reg[key], spec)

    -- Count should be 1
    local count = 0
    for _ in pairs(reg) do
        count = count + 1
    end
    assert.equal(count, 1)
end

function testcase.get_with_invalid_parameter()
    registry.clear()

    -- Test with invalid parameter types
    assert.throws(function()
        registry.get(123)
    end, 'key must be a string or nil')

    assert.throws(function()
        registry.get(true)
    end, 'key must be a string or nil')

    assert.throws(function()
        registry.get({})
    end, 'key must be a string or nil')

    assert.throws(function()
        registry.get(function()
        end)
    end, 'key must be a string or nil')
end
