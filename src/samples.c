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

    // Create a table with 8 fields (4 data arrays + 4 metadata fields)
    lua_createtable(L, 0, 8);

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

    // Add metadata fields
    lua_pushinteger(L, s->capacity);
    lua_setfield(L, 2, "capacity");

    lua_pushinteger(L, s->count);
    lua_setfield(L, 2, "count");

    lua_pushinteger(L, s->gc_step);
    lua_setfield(L, 2, "gc_step");

    lua_pushinteger(L, s->base_kb);
    lua_setfield(L, 2, "base_kb");

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

/**
 * Create a new measure_samples_t userdata object with the specified capacity
 * and GC step size.
 *
 * @param L Lua state
 * @param capacity Capacity of the samples array
 * @param gc_step GC step size in KB (0 for full GC)
 * @param ptr Pointer to store the created measure_samples_t object (optional)
 * @return Number of results pushed onto the stack (1 for the new object)
 */
static void new_measure_samples(lua_State *L, size_t capacity, int gc_step,
                                measure_samples_t **ptr)
{
    // create new measure_samples_t userdata object
    measure_samples_t *s = lua_newuserdata(L, sizeof(measure_samples_t));

    memset(s, 0, sizeof(measure_samples_t));
    s->ref_data = LUA_NOREF;
    s->capacity = (size_t)capacity;
    s->gc_step  = (gc_step < 0) ? -1 : (int)gc_step;
    luaL_getmetatable(L, MEASURE_SAMPLES_MT);
    lua_setmetatable(L, -2);

    // allocate memory for the data array
    s->data = (measure_samples_data_t *)lua_newuserdata(
        L, sizeof(measure_samples_data_t) * s->capacity);
    s->ref_data = luaL_ref(L, LUA_REGISTRYINDEX);
    // Initialize the data array to zero
    memset(s->data, 0, sizeof(measure_samples_data_t) * s->capacity);

    // If ptr is provided, set it to point to the new samples object
    if (ptr) {
        *ptr = s;
    }
}

#if LUA_VERSION_NUM < 502
# define lua_rawlen(L, idx) lua_objlen(L, idx)
#endif

#if LUA_VERSION_NUM < 503
# define lua_isinteger(L, idx)                                                 \
     (lua_type(L, idx) == LUA_TNUMBER &&                                       \
      (lua_Number)lua_tointeger(L, idx) == lua_tonumber(L, idx))
#endif

static int restore_lua(lua_State *L)
{
    measure_samples_t *s = NULL;
    size_t capacity      = 0;
    size_t count         = 0;
    int gc_step          = 0;
    size_t base_kb       = 0;
    lua_Integer iv       = 0;
    int top              = 0;

#define GET_IVALUE_FIELD(field_name, cond, ...)                                \
    do {                                                                       \
        lua_getfield(L, 1, (field_name));                                      \
        luaL_argcheck(L, lua_isinteger(L, -1), 1,                              \
                      "field '" field_name "' must be a integer");             \
        iv = lua_tointeger(L, -1);                                             \
        lua_pop(L, 1);                                                         \
        if (cond) {                                                            \
            lua_pushnil(L);                                                    \
            lua_pushfstring(L,                                                 \
                            "invalid field '" field_name "': " __VA_ARGS__);   \
            return 2;                                                          \
        }                                                                      \
    } while (0)

    // validate capacity field
    GET_IVALUE_FIELD("capacity", iv <= 0, "must be > 0");
    capacity = (size_t)iv;

    // validate count field
    GET_IVALUE_FIELD("count", iv < 0 || (size_t)iv > capacity,
                     "must be >= 0 and <= capacity");
    count = (size_t)iv;

    // validate gc_step field
    GET_IVALUE_FIELD("gc_step", 0);
    gc_step = (iv < 0) ? -1 : (int)iv;

    // validate base_kb field
    GET_IVALUE_FIELD("base_kb", iv <= 0, "must be > 0");
    base_kb = (size_t)iv;

#undef GET_IVALUE_FIELD

    // Create samples object
    new_measure_samples(L, capacity, gc_step, &s);
    s->count   = count;
    s->base_kb = base_kb;

    // Check if the table has the required fields
    top = lua_gettop(L);

#define CHECK_TABLE_FIELD(field)                                               \
    do {                                                                       \
        /* Check if field exists and is a table */                             \
        lua_getfield(L, 1, (#field));                                          \
        luaL_argcheck(L, lua_istable(L, -1), 1,                                \
                      "field '" #field "' must be a table");                   \
        /* Check if field is an array and its length matches count */          \
        if (lua_rawlen(L, -1) != count) {                                      \
            lua_pushnil(L);                                                    \
            lua_pushliteral(L, "field '" #field                                \
                               "' array size does not match 'count'");         \
            return 2;                                                          \
        }                                                                      \
    } while (0)

#define TIME_NS_FIELD (top + 1)
    CHECK_TABLE_FIELD(time_ns);
#define BEFORE_KB_FIELD (top + 2)
    CHECK_TABLE_FIELD(before_kb);
#define AFTER_KB_FIELD (top + 3)
    CHECK_TABLE_FIELD(after_kb);
#define ALLOCATED_KB_FIELD (top + 4)
    CHECK_TABLE_FIELD(allocated_kb);

#undef CHECK_TABLE_FIELD

    // Fill data from table arrays (only up to count)
    for (size_t i = 1; i <= count; i++) {
#define COPY_ARRAY_VALUE(field, idx)                                           \
    do {                                                                       \
        lua_rawgeti(L, (idx), i);                                              \
        if (!lua_isinteger(L, -1) || (iv = lua_tointeger(L, -1)) < 0) {        \
            lua_pushnil(L);                                                    \
            lua_pushfstring(                                                   \
                L, "field '" #field "[%d]' must be a integer >= 0", (int)i);   \
            return 2;                                                          \
        }                                                                      \
        lua_pop(L, 1);                                                         \
        s->data[i - 1].field = (typeof(s->data[i - 1].field))iv;               \
    } while (0)

        // Copy values from each field array
        COPY_ARRAY_VALUE(time_ns, TIME_NS_FIELD);
        COPY_ARRAY_VALUE(before_kb, BEFORE_KB_FIELD);
        COPY_ARRAY_VALUE(after_kb, AFTER_KB_FIELD);
        COPY_ARRAY_VALUE(allocated_kb, ALLOCATED_KB_FIELD);
    }

    // Clean up the stack and return the new measure_samples_t object
    lua_settop(L, top);
    return 1;
}

static int new_lua(lua_State *L)
{
    if (!lua_istable(L, 1)) {
        lua_Integer capacity = luaL_optinteger(L, 1, 1000);
        lua_Integer gc_step  = luaL_optinteger(L, 2, 0);
        if (capacity <= 0) {
            lua_pushnil(L);
            lua_pushliteral(L, "capacity must be > 0");
            return 2;
        }

        // create new measure_samples_t userdata object
        new_measure_samples(L, (size_t)capacity, (int)gc_step, NULL);
        return 1;
    }

    // If the first argument is a table, try to restore from it
    return restore_lua(L);
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

        // Protect metatable from external access
        lua_pushliteral(L, "metatable is protected");
        lua_setfield(L, -2, "__metatable");

        lua_pop(L, 1);
    }

    // push the constructor function
    lua_pushcfunction(L, new_lua);
    return 1;
}
