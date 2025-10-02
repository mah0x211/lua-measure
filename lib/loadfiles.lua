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
local type = type
local find = string.find
local sub = string.sub
local format = string.format
local concat = table.concat
local pcall = pcall
local popen = io.popen
local loadfile = loadfile
local pairs = pairs
local realpath = require('measure.realpath')
local getfiletype = require('measure.getfiletype')
local registry = require('measure.registry')

--- Evaluate a Lua file and catch any errors.
--- @param pathname string The pathname of the Lua file to evaluate.
--- @return boolean ok true if the file was evaluated successfully, false otherwise.
--- @return string|nil err An error message if the evaluation failed, nil otherwise.
local function evalfile(pathname)
    local f, err = loadfile(pathname)
    if not f then
        return false, err
    end

    -- execute the file and catch any errors
    local ok
    ok, err = pcall(f)
    if not ok then
        return false, err
    end
    return true
end

--- Load benchmark files from the specified pathname.
--- The pathname can be a file or a directory.
--- If it is a directory, it will search for files that match the pattern
--- `*_bench.lua` and load them.
--- If it is a file, it will load the file directly.
--- If the file does not exist or cannot be loaded, it will throw an error.
--- If the file is loaded successfully, it will execute the file and check if it
--- registered a benchmark spec. If it did, it will return the spec.
--- @param pathname string The pathname to load the benchmark files from.
--- @return measure.spec[] specs A table containing the loaded benchmark specs.
--- @throws error if the pathname is not a string.
--- @throws error if the pathname is neither a file nor a directory.
--- @throws error if the file cannot be loaded or does not register a benchmark spec.
local function loadfiles(pathname)
    if type(pathname) ~= 'string' then
        error('pathname must be a string', 2)
    end

    local t = getfiletype(pathname)
    local pathnames = {}
    if t == 'file' then
        -- if pathname is pointing to a file, just use it
        pathnames[1] = pathname
    elseif t == 'directory' then
        -- if pathname is pointing to a directory, retrieve the all entries
        local ls, err = popen('ls -1 ' .. pathname)
        if not ls then
            error(format('failed to list directory %s: %s', pathname, err), 2)
        end

        -- collect all files that match the pattern
        for entry in ls:lines() do
            if find(entry, '_bench.lua$') then
                pathnames[#pathnames + 1] = pathname .. '/' .. entry
            end
        end
    else
        -- pathname is neither a file nor a directory
        error(format('pathname %s must point to a file or directory', pathname),
              2)
    end

    -- try to load the first file that exists
    local files = {}
    for _, filename in ipairs(pathnames) do
        filename = realpath(filename)

        -- evaluate the file and catch any errors
        print('loading ' .. filename)
        local ok, err = evalfile(filename)
        if not ok then
            print(format('failed to load %q: %s', filename, err), 2)
        end

        -- check if the file registered a benchmark spec
        local specs = registry.get()
        registry.clear()
        for k, spec in pairs(specs) do
            -- if suffix is equal to filename, then it is registered
            if sub(k, -#filename) ~= filename then
                print(format('> ignore an invalid entry %s for %s', k, filename))
            else
                -- check if the spec is valid
                local errs = spec:verify_describes()
                if errs then
                    print(format('> ignore an invalid spec %s', filename))
                    print('> ' .. concat(errs, '\n> '))
                else
                    files[#files + 1] = {
                        filename = filename,
                        spec = spec,
                    }
                end
            end
        end
    end

    return files
end

return loadfiles
