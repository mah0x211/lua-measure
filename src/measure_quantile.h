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

#ifndef measure_quantile_h
#define measure_quantile_h

#include <float.h>
#include <math.h>

/**
 * Normal Quantile Function (Inverse Normal Distribution)
 * Computes the quantile function (inverse CDF) of the standard normal
 * distribution Using AS 241 (Applied Statistics Algorithm 241) by Wichura
 * (1988) Maximum error < 2e-16 for double precision
 *
 * @param p Probability (0 < p < 1)
 * @return z-value corresponding to the given probability, or NaN if p is
 * invalid
 */
static inline double measure_normal_quantile(double p)
{
    // Validate input
    if (p <= 0.0 || p >= 1.0) {
        return NAN;
    }

    // Constants for AS 241 algorithm
    const double SPLIT1 = 0.425;
    const double SPLIT2 = 5.0;
    const double CONST1 = 0.180625;
    const double CONST2 = 1.6;

    // Coefficients for central region
    const double A[] = {
        3.3871328727963666080,    1.3314166789178437745e+2,
        1.9715909503065514427e+3, 1.3731693765509461125e+4,
        4.5921953931549871457e+4, 6.7265770927008700853e+4,
        3.3430575583588128105e+4, 2.5090809287301226727e+3,
    };

    const double B[] = {
        1.0,
        4.2313330701600911252e+1,
        6.8718700749205790830e+2,
        5.3941960214247511077e+3,
        2.1213794301586595867e+4,
        3.9307895800092710610e+4,
        2.8729085735721942674e+4,
        5.2264952788528545610e+3,
    };

    // Coefficients for tail region
    const double C[] = {
        1.42343711074968357734,    4.63033784615654529590,
        5.76949722146069140550,    3.64784832476320460504,
        1.27045825245236838258,    2.41780725177450611770e-1,
        2.27238449892691845833e-2, 7.74545014278341407640e-4,
    };

    const double D[] = {
        1.0,
        2.05319162663775882187,
        1.67638483018380384940,
        6.89767334985100004550e-1,
        1.48103976427480074590e-1,
        1.51986665636164571966e-2,
        5.47593808499534494600e-4,
        1.05075007164441684324e-9,
    };

    // Very extreme tail coefficients
    const double E[] = {
        6.65790464350110377720,    5.46378491116411436990,
        1.78482653991729133580,    2.96560571828504891230e-1,
        2.65321895265761230930e-2, 1.24266094738807843860e-3,
        2.71155556874348757815e-5, 2.01033439929228813265e-7,
    };

    const double F[] = {
        1.0,
        5.99832206555887937690e-1,
        1.36929880922735805310e-1,
        1.48753612908506148525e-2,
        7.86869131145613259100e-4,
        1.84631831751005468180e-5,
        1.42151175831644588870e-7,
        2.04426310338993978564e-15,
    };

    double q = p - 0.5;
    double r, val;

    if (fabs(q) <= SPLIT1) {
        // Central region
        r   = CONST1 - q * q;
        val = q *
              (((((((A[7] * r + A[6]) * r + A[5]) * r + A[4]) * r + A[3]) * r +
                 A[2]) *
                    r +
                A[1]) *
                   r +
               A[0]) /
              (((((((B[7] * r + B[6]) * r + B[5]) * r + B[4]) * r + B[3]) * r +
                 B[2]) *
                    r +
                B[1]) *
                   r +
               B[0]);
    } else {
        // Tail regions
        if (q < 0) {
            r = p;
        } else {
            r = 1.0 - p;
        }

        if (r <= 0.0) {
            return 0.0; // Should not happen due to input validation
        }

        r = sqrt(-log(r));

        if (r <= SPLIT2) {
            // Near tail
            r   = r - CONST2;
            val = (((((((C[7] * r + C[6]) * r + C[5]) * r + C[4]) * r + C[3]) *
                         r +
                     C[2]) *
                        r +
                    C[1]) *
                       r +
                   C[0]) /
                  (((((((D[7] * r + D[6]) * r + D[5]) * r + D[4]) * r + D[3]) *
                         r +
                     D[2]) *
                        r +
                    D[1]) *
                       r +
                   D[0]);
        } else {
            // Far tail
            r   = r - SPLIT2;
            val = (((((((E[7] * r + E[6]) * r + E[5]) * r + E[4]) * r + E[3]) *
                         r +
                     E[2]) *
                        r +
                    E[1]) *
                       r +
                   E[0]) /
                  (((((((F[7] * r + F[6]) * r + F[5]) * r + F[4]) * r + F[3]) *
                         r +
                     F[2]) *
                        r +
                    F[1]) *
                       r +
                   F[0]);
        }

        if (q < 0) {
            val = -val;
        }
    }

    return val;
}

/**
 * Get z-value for a given confidence level using Normal Quantile Function
 *
 * @param confidence_level Confidence level (0 < confidence_level < 1)
 * @return z-value for the given confidence level, or NaN if confidence_level is
 * invalid
 */
static inline double measure_get_z_value_exact(double confidence_level)
{
    // Validate input
    if (confidence_level <= 0.0 || confidence_level >= 1.0) {
        return NAN;
    }

    // Calculate alpha (significance level)
    double alpha = 1.0 - confidence_level;

    // For two-sided confidence interval, use alpha/2
    double p = 1.0 - alpha / 2.0;

    return measure_normal_quantile(p);
}

#endif // measure_quantile_h
