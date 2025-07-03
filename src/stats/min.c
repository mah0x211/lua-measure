/**
 *  Copyright (C) 2025 Masatoshi Fukunaga
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

#include "common.h"
#include <lauxlib.h>
#include <lua.h>
#include <math.h>

// Lua binding for minimum calculation
static int min_lua(lua_State *L)
{
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);

    if (!validate_samples(samples)) {
        return luaL_error(L, "invalid samples: contains negative time values");
    }

    // Check for empty data - return NaN for empty samples
    if (samples->count == 0) {
        lua_pushnumber(L, NAN);
        return 1;
    }

    uint64_t min_val = stats_min(samples);
    lua_pushinteger(L, (lua_Integer)min_val);
    return 1;
}

LUALIB_API int luaopen_measure_stats_min(lua_State *L)
{
    lua_pushcfunction(L, min_lua);
    return 1;
}
