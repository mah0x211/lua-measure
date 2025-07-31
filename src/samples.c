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
#include "stats/common.h"

static int percentile_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_Integer p        = luaL_checkinteger(L, 2);
    double result        = NAN;

    if (p < 0 || p > 100) {
        luaL_error(L, "percentile must be between 0 and 100, got %d", p);
    } else if (s->count) {
        result = stats_percentile(s, (double)p);
    }
    lua_pushnumber(L, result);
    return 1;
}

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
    if (s->name[0] != '\0') {
        lua_pushstring(L, s->name);
        lua_setfield(L, 2, "name");
    }

    lua_pushinteger(L, s->capacity);
    lua_setfield(L, 2, "capacity");

    lua_pushinteger(L, s->count);
    lua_setfield(L, 2, "count");

    lua_pushinteger(L, s->gc_step);
    lua_setfield(L, 2, "gc_step");

    lua_pushnumber(L, s->cl);
    lua_setfield(L, 2, "cl");

    lua_pushnumber(L, s->rciw);
    lua_setfield(L, 2, "rciw");

    lua_pushinteger(L, s->sum);
    lua_setfield(L, 2, "sum");

    lua_pushinteger(L, s->min);
    lua_setfield(L, 2, "min");

    lua_pushinteger(L, s->max);
    lua_setfield(L, 2, "max");

    lua_pushnumber(L, s->M2);
    lua_setfield(L, 2, "M2");

    lua_pushnumber(L, s->mean);
    lua_setfield(L, 2, "mean");

    lua_pushinteger(L, s->base_kb);
    lua_setfield(L, 2, "base_kb");

    return 1;
}

static int stddev_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    if (s->count < 2) {
        lua_pushnumber(L, 0.0);
    } else {
        lua_pushnumber(L, sqrt(s->M2 / (s->count - 1)));
    }
    return 1;
}

static int variance_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    if (s->count < 2) {
        lua_pushnumber(L, 0.0);
    } else {
        lua_pushnumber(L, s->M2 / (s->count - 1));
    }
    return 1;
}

static int mean_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    if (s->count == 0) {
        lua_pushnumber(L, NAN);
    } else {
        lua_pushnumber(L, s->mean);
    }
    return 1;
}

static int max_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    if (s->count == 0) {
        lua_pushnumber(L, NAN);
    } else {
        lua_pushinteger(L, s->max);
    }
    return 1;
}

static int min_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    if (s->count == 0) {
        lua_pushnumber(L, NAN);
    } else {
        lua_pushinteger(L, s->min);
    }
    return 1;
}

static int rciw_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushnumber(L, s->rciw);
    return 1;
}

static int cl_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushnumber(L, s->cl);
    return 1;
}

static int gc_step_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushinteger(L, s->gc_step);
    return 1;
}

static int capacity_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushinteger(L, s->capacity);
    return 1;
}

static int name_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    // If name is empty, return the pointer address as a string
    // This is useful for debugging or when the name is not set
    if (s->name[0] == '\0') {
        lua_pushfstring(L, "%p", (void *)s);
    } else {
        lua_pushstring(L, s->name);
    }
    return 1;
}

static int count_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    lua_pushinteger(L, s->count);
    return 1;
}

static int tostring_lua(lua_State *L)
{
    measure_samples_t *s = luaL_checkudata(L, 1, MEASURE_SAMPLES_MT);
    if (s->name[0] == '\0') {
        lua_pushfstring(L, MEASURE_SAMPLES_MT ": %p", (void *)s);
    } else {
        lua_pushfstring(L, MEASURE_SAMPLES_MT ": %s", s->name);
    }
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
 * @param name Name of the sample (e.g., "sample1", "sample2")
 * @param len Length of the name string
 * @param capacity Capacity of the samples array
 * @param gc_step GC step size in KB (0 for full GC)
 * @param cl Confidence level (e.g., 95.0%)
 * @param rciw Relative confidence interval width (e.g., 5.0%)
 * @return Pointer to the new measure_samples_t userdata object
 */
static measure_samples_t *new_measure_samples(lua_State *L, const char *name,
                                              size_t len, size_t capacity,
                                              int gc_step, double cl,
                                              double rciw)
{
    // create new measure_samples_t userdata object
    measure_samples_t *s = lua_newuserdata(L, sizeof(measure_samples_t));

    memset(s, 0, sizeof(measure_samples_t));
    memcpy(s->name, name, len < sizeof(s->name) ? len : sizeof(s->name) - 1);
    s->ref_data = LUA_NOREF;
    s->capacity = (size_t)capacity;
    s->gc_step  = (gc_step < 0) ? -1 : (int)gc_step;
    s->cl       = cl;
    s->rciw     = rciw;
    luaL_getmetatable(L, MEASURE_SAMPLES_MT);
    lua_setmetatable(L, -2);

    // allocate memory for the data array
    s->data = (measure_samples_data_t *)lua_newuserdata(
        L, sizeof(measure_samples_data_t) * s->capacity);
    s->ref_data = luaL_ref(L, LUA_REGISTRYINDEX);
    // Initialize the data array to zero
    memset(s->data, 0, sizeof(measure_samples_data_t) * s->capacity);

    return s;
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
    size_t len           = 0;
    const char *name     = NULL;
    size_t capacity      = 0;
    size_t count         = 0;
    int gc_step          = 0;
    double cl            = 0;
    double rciw          = 0;
    size_t base_kb       = 0;
    lua_Integer iv       = 0;
    lua_Number dv        = 0;
    int top              = 0;

    // get name field
    lua_getfield(L, 1, "name");
    if (!lua_isnoneornil(L, -1)) {
        if (!lua_isstring(L, -1)) {
            return luaL_argerror(L, 1, "field 'name' must be a string");
        }
        name = lua_tolstring(L, -1, &len);
    }
    lua_pop(L, 1); // pop name field

#define GET_DVALUE_FIELD(field_name, cond, ...)                                \
    do {                                                                       \
        lua_getfield(L, 1, (field_name));                                      \
        luaL_argcheck(L, lua_isnumber(L, -1), 1,                               \
                      "field '" field_name "' must be a number");              \
        dv = lua_tonumber(L, -1);                                              \
        lua_pop(L, 1);                                                         \
        if (cond) {                                                            \
            lua_pushnil(L);                                                    \
            lua_pushfstring(L,                                                 \
                            "invalid field '" field_name "': " __VA_ARGS__);   \
            return 2;                                                          \
        }                                                                      \
    } while (0)

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

    // validate cl field
    GET_DVALUE_FIELD("cl", dv <= 0 || dv > 100,
                     "must be in range 0 < cl <= 100");
    cl = (double)dv;

    // validate rciw field
    GET_DVALUE_FIELD("rciw", dv <= 0 || dv > 100,
                     "must be in range 0 < rciw <= 100");
    rciw = (double)dv;

    // validate base_kb field
    GET_IVALUE_FIELD("base_kb", iv <= 0, "must be > 0");
    base_kb = (size_t)iv;

#undef GET_IVALUE_FIELD

    // Create samples object
    s          = new_measure_samples(L, name, len, capacity, gc_step, cl, rciw);
    s->count   = 0;
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

#undef CHECK_TABLE_FIELD

    // Fill data from table arrays (only up to count)
    s->min = UINT64_MAX; // ensure any sample will be less
    for (size_t i = 1; i <= count; i++) {
        measure_samples_data_t data;

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
        data.field = (typeof(data.field))iv;                                   \
    } while (0)

        // Copy values from each field array
        COPY_ARRAY_VALUE(time_ns, TIME_NS_FIELD);
        COPY_ARRAY_VALUE(before_kb, BEFORE_KB_FIELD);
        COPY_ARRAY_VALUE(after_kb, AFTER_KB_FIELD);
        // update sample data and related statistics
        measure_samples_update_sample_ex(s, data.time_ns, data.before_kb,
                                         data.after_kb);
    }

    // Clean up the stack and return the new measure_samples_t object
    lua_settop(L, top);
    return 1;
}

#define DEFAULT_CAPACITY 1000
#define DEFAULT_GC_STEP  0
#define DEFAULT_CL       95.0
#define DEFAULT_RCIW     5.0

static const char *checklstring(lua_State *L, int idx, size_t *len)
{
    if (lua_isnoneornil(L, idx)) {
        return NULL;
    }
    luaL_checktype(L, idx, LUA_TSTRING);
    return lua_tolstring(L, idx, len);
}

static int new_lua(lua_State *L)
{
    if (!lua_istable(L, 1)) {
        size_t len           = 0;
        const char *name     = checklstring(L, 1, &len);
        lua_Integer capacity = luaL_optinteger(L, 2, DEFAULT_CAPACITY);
        lua_Integer gc_step  = luaL_optinteger(L, 3, DEFAULT_GC_STEP);
        lua_Number cl        = luaL_optnumber(L, 4, DEFAULT_CL);
        lua_Number rciw      = luaL_optnumber(L, 5, DEFAULT_RCIW);

        if (!lua_isnoneornil(L, 1)) {
            luaL_checktype(L, 1, LUA_TSTRING);
            name = lua_tolstring(L, 1, &len);
            if (len > 255) {
                lua_pushnil(L);
                lua_pushliteral(L, "name must be <= 255 characters");
                return 2;
            }
        }
        if (capacity <= 0) {
            lua_pushnil(L);
            lua_pushliteral(L, "capacity must be > 0");
            return 2;
        } else if (cl <= 0 || cl > 100) {
            lua_pushnil(L);
            lua_pushliteral(L, "cl must be in 0 < cl <= 100");
            return 2;
        } else if (rciw <= 0 || rciw > 100) {
            lua_pushnil(L);
            lua_pushliteral(L, "rciw must be in 0 < rciw <= 100");
            return 2;
        }

        // create new measure_samples_t userdata object
        (void)new_measure_samples(L, name, len, (size_t)capacity, (int)gc_step,
                                  cl, rciw);
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
            {"name",       name_lua      },
            {"capacity",   capacity_lua  },
            {"gc_step",    gc_step_lua   },
            {"cl",         cl_lua        },
            {"rciw",       rciw_lua      },
            {"min",        min_lua       },
            {"max",        max_lua       },
            {"mean",       mean_lua      },
            {"variance",   variance_lua  },
            {"stddev",     stddev_lua    },
            {"dump",       dump_lua      },
            // calculate statistics
            {"percentile", percentile_lua},
            {NULL,         NULL          }
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
