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
local sub = string.sub
local format = string.format
local concat = table.concat
local pcall = pcall
local loadfile = loadfile
local pairs = pairs
local realpath = require('measure.realpath')
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

--- Load benchmark file and return the registered benchmark spec.
--- @param pathname string The pathname of the Lua file to load.
--- @return table? target A table containing the loaded benchmark spec.
--- @return any err An error message if the loading failed, nil otherwise.
local function loadfiles(pathname)
    if type(pathname) ~= 'string' then
        error('pathname must be a string', 2)
    end

    local filename = realpath(pathname)
    local ok, err = evalfile(filename)
    if not ok then
        return nil, err
    end

    -- check if the file registered a benchmark spec
    local specs = registry.get()
    registry.clear()
    for k, spec in pairs(specs) do
        -- if suffix is equal to filename, then it is registered
        if sub(k, -#filename) == filename then
            -- check if the spec is valid
            local errs = spec:verify_describes()
            if errs then
                return nil, format('ignore an invalid spec %s: %s', filename,
                                   concat(errs, '\n> '))
            end

            return {
                filename = filename,
                spec = spec,
            }
        end
    end

end

return loadfiles
