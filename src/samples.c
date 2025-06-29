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

#include "measure_samples.h"

static int dump_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_settop(L, 1);

    // Create a table with 4 fields for column-oriented format
    lua_createtable(L, 0, 4);

    // Create time_ns, before_kb, after_kb and allocated_kb arrays
    lua_createtable(L, s->count, 0); // 3: time_ns
    lua_createtable(L, s->count, 0); // 4: before_kb
    lua_createtable(L, s->count, 0); // 5: after_kb
    lua_createtable(L, s->count, 0); // 6: allocated_kb
    for (size_t i = 0; i < s->count; i++) {
        int idx = i + 1;
        lua_pushinteger(L, s->data[i].time_ns);
        lua_rawseti(L, 3, idx);
        lua_pushinteger(L, s->data[i].before_kb);
        lua_rawseti(L, 4, idx);
        lua_pushinteger(L, s->data[i].after_kb);
        lua_rawseti(L, 5, idx);
        lua_pushinteger(L, s->data[i].allocated_kb);
        lua_rawseti(L, 6, idx);
    }
    lua_setfield(L, 2, "allocated_kb");
    lua_setfield(L, 2, "after_kb");
    lua_setfield(L, 2, "before_kb");
    lua_setfield(L, 2, "time_ns");

    return 1;
}

static int count_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushinteger(L, s->count);
    return 1;
}

static int capacity_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushinteger(L, s->capacity);
    return 1;
}

static int tostring_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushfstring(L, MEASURE_SAMPLES_MT ": %p", (void *)s);
    return 1;
}

static int gc_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    // NOTE: LUA_NOREF is special values in Lua.
    // LUA_NOREF means no reference. This values is can be passed to
    // luaL_unref() to safely remove references without causing errors.
    luaL_unref(L, LUA_REGISTRYINDEX, s->ref_data);
    s->ref_data = LUA_NOREF;
    return 0;
}

static int new_lua(lua_State *L)
{
    lua_Integer capacity = luaL_optinteger(L, 1, 1000);
    lua_Integer gc_step  = luaL_optinteger(L, 2, 0);
    measure_samples_t *s = NULL;

    if (capacity <= 0) {
        lua_pushnil(L);
        lua_pushliteral(L, "capacity must be > 0");
        return 2;
    }
    lua_settop(L, 0);

    // create new measure_samples_t userdata object
    s = lua_newuserdata(L, sizeof(measure_samples_t));
    memset(s, 0, sizeof(measure_samples_t));
    s->ref_data = LUA_NOREF;
    s->capacity = capacity;
    s->gc_step  = (gc_step < 0) ? 0 : (int)gc_step;
    luaL_getmetatable(L, MEASURE_SAMPLES_MT);
    lua_setmetatable(L, -2);

    // allocate memory for the data array
    s->data = (measure_samples_data_t *)lua_newuserdata(
        L, sizeof(measure_samples_data_t) * capacity);
    s->ref_data = luaL_ref(L, LUA_REGISTRYINDEX);
    memset(s->data, 0, sizeof(uint64_t) * capacity);

    return 1;
}

LUALIB_API int luaopen_measure_samples(lua_State *L)
{
    // create metatable
    if (luaL_newmetatable(L, MEASURE_SAMPLES_MT)) {
        struct luaL_Reg mmethod[] = {
            {"__gc",       gc_lua      },
            {"__tostring", tostring_lua},
            {"__len",      count_lua   },
            {NULL,         NULL        }
        };
        struct luaL_Reg method[] = {
            {"capacity", capacity_lua},
            {"dump",     dump_lua    },
            {NULL,       NULL        }
        };

        // metamethods
        for (struct luaL_Reg *ptr = mmethod; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        // methods
        lua_createtable(L, 0, 1);
        for (struct luaL_Reg *ptr = method; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        lua_setfield(L, -2, "__index");
        lua_pop(L, 1);
    }

    // push the constructor function
    lua_pushcfunction(L, new_lua);
    return 1;
}
