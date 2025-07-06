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

#include "measure_quantile.h"
#include <lauxlib.h>
#include <lua.h>

/**
 * Lua binding for get_z_value_exact function
 * Usage: local z = quantile(confidence_level)
 *
 * @param L Lua state
 * @return 1 (the z-value result)
 */
static int quantile_lua(lua_State *L)
{
    double confidence_level = luaL_checknumber(L, 1);
    double result           = measure_get_z_value_exact(confidence_level);
    lua_pushnumber(L, result);
    return 1;
}

/**
 * Module initialization function
 * This function is called when the module is loaded with require()
 */
int luaopen_measure_quantile(lua_State *L)
{
    lua_pushcfunction(L, quantile_lua);
    return 1;
}
