/**
 *  Copyright (C) 2022 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
// lua
#include <lauxlib.h>
#include <lua.h>

static int getfiletype_lua(lua_State *L)
{
    const char *pathname = luaL_checkstring(L, 1);
    struct stat st       = {0};
    int rc               = lstat(pathname, &st);

    // got error
    if (rc == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        lua_pushinteger(L, errno);
        return 3;
    }

    // set fields
    switch (st.st_mode & S_IFMT) {
    case S_IFBLK:
        lua_pushliteral(L, "block");
        return 1;
    case S_IFCHR:
        lua_pushliteral(L, "character");
        return 1;
    case S_IFDIR:
        lua_pushliteral(L, "directory");
        return 1;
    case S_IFIFO:
        lua_pushliteral(L, "fifo");
        return 1;
    case S_IFREG:
        lua_pushliteral(L, "file");
        return 1;
    case S_IFLNK:
        lua_pushliteral(L, "symlink");
        return 1;
    case S_IFSOCK:
        lua_pushliteral(L, "socket");
        return 1;
    default:
        lua_pushliteral(L, "unknown");
        return 1;
    }
}

LUALIB_API int luaopen_measure_getfiletype(lua_State *L)
{
    lua_pushcfunction(L, getfiletype_lua);
    return 1;
}
