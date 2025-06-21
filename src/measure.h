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

#ifndef measure_h
#define measure_h

#include <stdint.h>
#include <time.h>

#define MEASURE_SEC2NSEC(s) ((uint64_t)(s) * 1000000000ULL)

/**
 * @brief get current time in nanoseconds.
 * This function uses CLOCK_MONOTONIC_RAW to get the time.
 * CLOCK_MONOTONIC_RAW is not affected by NTP adjustments and provides a
 * high-resolution timer that is suitable for measuring time intervals.
 * It is available on Linux and macOS.
 * @return uint64_t the current time in nanoseconds since the epoch.
 */
static inline uint64_t measure_getnsec(void)
{
    struct timespec ts = {0};
    (void)clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return MEASURE_SEC2NSEC(ts.tv_sec) + (uint64_t)ts.tv_nsec;
}

#endif /* measure_h */
