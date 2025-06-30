require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local new_metatable = require('measure.metatable')

function testcase.new_metatable_with_string_name()
    -- Test creating a class with a string name
    local cls = new_metatable('TestClass')

    -- Check that it returns a table
    assert.is_table(cls)

    -- Check __index is set to itself
    assert.equal(cls.__index, cls)

    -- Check __tostring is a function
    assert.is_function(cls.__tostring)

    -- Test tostring function directly (without creating instance)
    local str = cls.__tostring()
    assert.match(str, '^TestClass: 0x%x+$', false)
end

function testcase.new_metatable_with_empty_string_error()
    -- Test that empty string throws an error
    assert.throws(function()
        new_metatable('')
    end, 'name cannot be an empty string')
end

function testcase.new_metatable_with_function_name()
    -- Test creating a class with a function as name
    local custom_tostring = function()
        return 'CustomClass'
    end

    local cls = new_metatable(custom_tostring)

    -- Check that it returns a table
    assert.is_table(cls)

    -- Check __index is set to itself
    assert.equal(cls.__index, cls)

    -- Check __tostring is the provided function
    assert.equal(cls.__tostring, custom_tostring)

    -- Test tostring function directly
    assert.equal(cls.__tostring(), 'CustomClass')
end

function testcase.new_metatable_with_invalid_type_error()
    -- Test that invalid types throw errors
    local invalid_types = {
        123,
        true,
        false,
        {},
        nil,
    }

    for _, invalid in ipairs(invalid_types) do
        assert.throws(function()
            new_metatable(invalid)
        end, 'name must be a string or function')
    end
end

function testcase.new_metatable_metatable_inheritance()
    -- Test that created objects can be used as metatables
    local cls = new_metatable('BaseClass')

    -- Add a method to the class
    function cls.method()
        return 'method called'
    end

    -- Check __index functionality - it should point to the class itself
    assert.equal(cls.__index, cls)

    -- Check that method exists on the class
    assert.is_function(cls.method)
    assert.equal(cls.method(), 'method called')

    -- Check tostring function
    local str = cls.__tostring()
    assert.match(str, '^BaseClass: 0x%x+$', false)
end

function testcase.new_metatable_multiple_instances()
    -- Test that multiple classes have different addresses
    local cls1 = new_metatable('Class1')
    local cls2 = new_metatable('Class1')

    -- They should be different tables
    assert.not_equal(cls1, cls2)

    -- Test their tostring functions directly
    local str1 = cls1.__tostring()
    local str2 = cls2.__tostring()
    assert.not_equal(str1, str2)

    -- But both should start with the same class name
    assert.match(str1, '^Class1: 0x%x+$', false)
    assert.match(str2, '^Class1: 0x%x+$', false)
end
