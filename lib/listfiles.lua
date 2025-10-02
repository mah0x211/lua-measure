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
local format = string.format
local popen = io.popen
local getfiletype = require('measure.getfiletype')

--- List benchmark files from the specified pathname.
--- @param pathname string The pathname to load the benchmark files from.
--- @return string[]? pathnames A list of benchmark file pathnames.
--- @return string? err An error message if loading failed, nil otherwise.
--- @throws error if the pathname is not a string.
local function listfiles(pathname)
    if type(pathname) ~= 'string' then
        error('pathname must be a string', 2)
    end

    local t = getfiletype(pathname)
    if t == 'file' then
        -- if pathname is pointing to a file, just use it
        return {
            pathname,
        }
    end

    if t == 'directory' then
        -- if pathname is pointing to a directory, retrieve the all entries
        local pathnames = {}
        -- Escape pathname for shell command
        local escaped_path = pathname:gsub("'", "'\\''")
        local ls, err = popen("ls -1 '" .. escaped_path .. "'")
        if not ls then
            return nil, format('failed to list directory %s: %s', pathname, err)
        end

        -- collect all files that match the pattern
        for entry in ls:lines() do
            if find(entry, '_bench.lua$') then
                pathnames[#pathnames + 1] = pathname .. '/' .. entry
            end
        end
        return pathnames
    end

    -- pathname is neither a file nor a directory
    return nil,
           format('pathname %s must point to a file or directory', pathname)
end

return listfiles
