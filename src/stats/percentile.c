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

// Lua binding for percentile calculation
static int percentile_lua(lua_State *L)
{
    measure_samples_t *samples = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    double p                   = luaL_checknumber(L, 2);

    if (!validate_samples(samples)) {
        return luaL_error(L, "invalid samples: contains negative time values");
    }

    if (!validate_percentile(p)) {
        return luaL_error(L, "percentile must be between 0 and 100, got %f", p);
    }

    double result = stats_percentile(samples, p);
    lua_pushnumber(L, result);
    return 1;
}

LUALIB_API int luaopen_measure_stats_percentile(lua_State *L)
{
    lua_pushcfunction(L, percentile_lua);
    return 1;
}
