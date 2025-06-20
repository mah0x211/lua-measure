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
local concat = table.concat
local sub = string.sub
local find = string.find

--- @param pathname string
--- @return string normalized_path
local function realpath(pathname)
    if type(pathname) ~= "string" then
        error("path must be a string", 2)
    end

    -- extract path segments
    local segs = {}
    local pos = 1
    local head, tail = find(pathname, '/+')
    while head do
        -- セグメントの終端まで探す
        segs[#segs + 1] = sub(pathname, pos, head - 1)
        pos = tail + 1
        head, tail = find(pathname, '/+', pos)
    end

    -- extract the last segment
    if pos <= #pathname then
        segs[#segs + 1] = sub(pathname, pos)
    end

    -- normalize segments
    local list = {}
    for i = 1, #segs do
        local seg = segs[i]
        if seg == '..' then
            -- pop the last segment if it exists
            if #list > 0 then
                list[#list] = nil
            end
        elseif seg ~= '.' then
            -- add valid segment to the list
            list[#list + 1] = seg
        end
    end

    return concat(list, '/')
end

return realpath
