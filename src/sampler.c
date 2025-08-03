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

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
// measure headers
#include "measure_samples.h"
// lua
#include <lauxlib.h>
#include <lua.h>

#ifndef LUA_OK
# define LUA_OK 0
#endif

#define SAMPLER_MT "measure.sampler"

typedef struct {
    lua_State *L;
    measure_samples_t *samples; // pointer to the samples object
    int warmup;                 // warmup duration in seconds
    int clear;                  // whether to clear samples before running
} sampler_t;

static inline int is_lua_error(lua_State *L, int rc)
{
    switch (rc) {
    case LUA_OK:
        // function executed successfully
        return 0;
    case LUA_ERRRUN:
        // function raised an error
        lua_pushfstring(L, "runtime error: %s", lua_tostring(L, -1));
        return -1;
    case LUA_ERRMEM:
        // memory allocation error
        lua_pushfstring(L, "memory error: %s", lua_tostring(L, -1));
        return -1;
    case LUA_ERRERR:
        // error while handling the error
        lua_pushfstring(L, "error handling error: %s", lua_tostring(L, -1));
        return -1;
#ifdef LUA_ERRGCMM
    case LUA_ERRGCMM:
        // garbage collection error
        lua_pushfstring(L, "garbage collection error: %s", lua_tostring(L, -1));
        return -1;
#endif
    default:
        // unknown error
        lua_pushfstring(L, "unknown error: %s", lua_tostring(L, -1));
        return -1;
    }
}

static int sampling_lua(sampler_t *s)
{
    lua_State *L    = s->L;
    size_t capacity = s->samples->capacity;

    // confirm that the first argument is a function
    luaL_checktype(L, 1, LUA_TFUNCTION);

    // clear the samples if requested
    if (s->clear) {
        measure_samples_clear(s->samples);
    }

    // preprocess the samples object
    measure_samples_preprocess(s->samples, L);

    for (size_t i = s->samples->count; i < capacity; i++) {
        // push the function again, as it may have been removed from the stack
        lua_pushvalue(L, 1);
        lua_pushboolean(L, 0);

        // initialize a sample data structure.
        if (measure_samples_init_sample(s->samples, L) < 0) {
            lua_pushfstring(L, "failed to initialize sample: %s",
                            strerror(errno));
            return -1;
        }

        // call the function with is_warmup=false
        int rc = lua_pcall(L, 1, 0, 0);

        // update an initialized sample data structure.
        if (measure_samples_update_sample(s->samples, L) < 0) {
            lua_pushfstring(L, "failed to add sample: %s", strerror(errno));
            return -1;
        }

        // check if the function call was successful
        if (is_lua_error(L, rc)) {
            return -1;
        }
    }

    // postprocess the samples object
    measure_samples_postprocess(s->samples, L);

    // no errors
    return 0;
}

static int warmup_lua(sampler_t *s)
{
    if (s->warmup > 0) {
        lua_State *L             = s->L;
        // get the current time in nanoseconds
        const uint64_t warmup_ns = MEASURE_SEC2NSEC(s->warmup);
        uint64_t ns              = 0;
        uint64_t elpased_ns      = 0;

        // confirm that the first argument is a function
        luaL_checktype(L, 1, LUA_TFUNCTION);

        ns = measure_getnsec();
        while (elpased_ns < warmup_ns) {
            // call the function with is_warmup=true
            lua_pushvalue(L, 1);
            lua_pushboolean(L, 1);
            if (is_lua_error(L, lua_pcall(L, 1, 0, 0))) {
                return -1;
            }
            // get the elapsed time in nanoseconds
            elpased_ns = measure_getnsec() - ns;
        }
    }

    // no errors
    return 0;
}

static int run_lua(lua_State *L)
{
    sampler_t s = {
        .L      = L,
        .warmup = 0, // default to no warmup
        .clear  = 0, // default to not clearing samples before running
    };
    int rv = 0;

    // check required function argument
    luaL_checktype(L, 1, LUA_TFUNCTION);
    // check required samples argument
    s.samples = luaL_checkudata(L, 2, MEASURE_SAMPLES_MT);
    if (!lua_isnoneornil(L, 3)) {
        // check optional warmup argument
        luaL_checktype(L, 3, LUA_TNUMBER);
        lua_Integer iv = luaL_checkinteger(L, 3);
        s.warmup       = (iv < 0) ? 0 : (int)iv;
    }
    if (!lua_isnoneornil(L, 4)) {
        // check optional clear argument
        luaL_checktype(L, 4, LUA_TBOOLEAN);
        s.clear = lua_toboolean(L, 4);
    }
    lua_settop(L, 2); // clear stack except for the function and samples object

    // if warmup is greater than 0, run the function for warmup iterations
    rv = warmup_lua(&s);
    if (rv != 0) {
        // if there was an error during warmup, return the error
        lua_pushboolean(L, 0);
        lua_insert(L, -2);
        return 2;
    }

    // run the sampling function
    rv = sampling_lua(&s);
    if (rv != 0) {
        // if there was an error during sampling, return the error
        lua_pushboolean(L, 0);
        lua_insert(L, -2);
        return 2;
    }

    lua_pushboolean(L, 1);
    return 1;
}

LUALIB_API int luaopen_measure_sampler(lua_State *L)
{
    lua_pushcfunction(L, run_lua);
    return 1;
}
