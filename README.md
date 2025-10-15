# lua-measure

[![test](https://github.com/mah0x211/lua-measure/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-measure/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-measure/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-measure)

lua-measure is a benchmarking command-line tool for Lua that provides statistical analysis and confidence intervals for performance measurements.


## Installation

```bash
luarocks install measure
```

## Features

lua-measure focuses on repeatable, statistically defensible benchmarking for Lua code.

- **Adaptive sampling**: Gathers additional runs automatically until the requested relative confidence interval width is achieved, avoiding under- or over-sampling.
- **Statistical comparisons**: Highlights significant differences with Welch's t-test (≤5 groups) and Scott-Knott ESD clustering (6+ groups).
- **Memory and GC visibility**: Tracks allocation per operation, peak usage, and optional GC stepping to surface runtime side effects.
- **Configurable benchmark lifecycle**: `measure.options` plus hooks such as `before_all`, `before_each`, and `after_each` let you prepare fixtures or clean up between cases.
- **Suite discovery and metadata**: Finds `*_bench.lua` files in directories, runs them sequentially, and records system information for reproducibility.


## Command-line Usage

The `measure` command provides an easy way to run benchmark files:

```bash
# Run a single benchmark file
measure path/to/benchmark_file.lua

# Run all benchmark files in a directory
measure path/to/benchmark/directory/

# Show help
measure --help

# Show version
measure --version
```


### Benchmark File Format

Benchmark suites are ordinary Lua scripts whose filenames end with `_bench.lua`. When you point `measure` at a file or directory, it `require`s each suite and executes the declared cases. The minimal ingredients are:

1. `local measure = require('measure')`
2. Optional global hooks (`measure.before_all`, `measure.after_all`) for fixture setup/teardown
3. Optional configuration via `measure.options({ confidence_level = 95, rciw = 5, warmup = 1, gc_step = 0, ... })`
4. One or more chained `describe(<name>):run(function()` blocks that contain the code to benchmark

The `example/` directory contains complete suites such as `json_bench.lua` and `base64_bench.lua`. A condensed template looks like this:

```lua
local measure = require('measure')

function measure.before_all()
    -- Load large fixtures once and share them across benchmark cases
end

measure.options({
    confidence_level = 95,
    rciw = 5,
    warmup = 1,
}).describe('my function'):run(function()
    -- Code under test; keep it synchronous and side-effect free per run
end).describe('alternative implementation'):run(function()
    -- Each describe/run pair becomes a named row in the final report
end)
```

Every `run` callback is executed repeatedly by the sampler. Avoid mutating shared state inside the callback unless the benchmark models that mutation explicitly. The first `describe(...):run(...)` you register is treated as the baseline across reports, so list your reference implementation first.

### Options Details

- **`warmup`**: Warmup duration in **seconds** (0-5, optional) - runs benchmark function for this duration before actual measurement
- **`gc_step`**: Garbage collection configuration as **integer** (optional):
  - `-1`: GC disabled during sampling
  - `0`: Full GC before each sample (default)
  - `>0`: Step GC with threshold in **KB**
- **`confidence_level`**: Statistical confidence level as **percentage** (0-100, default: 95)
- **`rciw`**: Relative confidence interval width as **percentage** (0-100, default: 5) - target precision for adaptive sampling

## Example

Running the bundled suites with `measure ./example` produces the report below (captured on macOS 15.6.1 with LuaJIT 2.1):

````bash
$ measure ./example

# Benchmark Reports

```
Runtime : Lua 5.1, JIT=enabled
Hardware: Apple M4, 10 cores (10 threads), 24.00 GB
Date    : 2025-10-15T15:14:57+09:00
Host    : Darwin, macOS 15.6.1, arm64, kernel=24.6.0
```

## Exec: ./example/base64_bench.lua

Loaded data size: 0.720334 MB

- base64
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- basexx
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- luabase64
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- base64mix
    - Sampling 30 samples (iteration 1, warmup 1 sec)

### Sampling Details

| Name      | Samples | Outliers  | Conf Level | Target RCIW | GC Mode |
|:----------|--------:|:----------|-----------:|------------:|:--------|
| base64    | 30      | 2 (6.7%)  | 95.0%      | 5.0%        | full GC |
| basexx    | 30      | 2 (6.7%)  | 95.0%      | 5.0%        | full GC |
| luabase64 | 30      | 1 (3.3%)  | 95.0%      | 5.0%        | full GC |
| base64mix | 30      | 5 (16.7%) | 95.0%      | 5.0%        | full GC |


### Memory Analysis

*Sorted by Alloc/Op (lower is better).*

| Name      | Samples | Max Alloc/Op | Alloc/Op    | Relative     | Peak Memory | Uncollected | Avg Incr. |
|:----------|--------:|-------------:|------------:|:-------------|------------:|------------:|----------:|
| base64mix | 30      |  1.92 MB/op  |  1.92 MB/op | 1.665x less  |  3.50 MB    |   0.00 KB   |  0.00 KB  |
| base64    | 30      |  3.50 MB/op  |  3.20 MB/op | baseline     |  5.31 MB    | 320.00 KB   | 11.03 KB  |
| luabase64 | 30      |  4.08 MB/op  |  4.02 MB/op | 1.258x more  |  6.15 MB    |   0.00 KB   |  0.00 KB  |
| basexx    | 30      | 36.56 MB/op  | 33.92 MB/op | 10.602x more | 40.13 MB    |   2.00 MB   | 70.69 KB  |


### Measurement Reliability Analysis

*Sorted by measurement precision (lower RCIW = more reliable)*

| Name      | CI Level                      | CI Width   | RCIW | Quality    |
|:----------|:------------------------------|-----------:|-----:|:-----------|
| basexx    | 95% [620.427 ms - 625.705 ms] |   5.278 ms | 0.8% | good       |
| base64mix | 95% [375.937 us - 380.724 us] |   4.788 us | 1.3% | acceptable |
| luabase64 | 95% [3.558 ms - 3.608 ms]     |  50.795 us | 1.4% | good       |
| base64    | 95% [9.823 ms - 9.966 ms]     | 142.780 us | 1.4% | good       |


### Performance Analysis

*Sorted by mean execution time (lower is better).*

| Name      | Ops/sec     | Mean       | p50        | p95        | p99        | StdDev     | Relative       |
|:----------|------------:|-----------:|-----------:|-----------:|-----------:|-----------:|:---------------|
| base64mix | 2.64 K op/s | 378.331 us | 376.271 us | 390.219 us | 403.829 us |   6.690 us | 26.154x faster |
| luabase64 | 279.09 op/s |   3.583 ms |   3.598 ms |   3.659 ms |   3.736 ms |  70.975 us | 2.762x faster  |
| base64    | 101.06 op/s |   9.895 ms |   9.866 ms |   9.944 ms |  10.635 ms | 199.504 us | baseline       |
| basexx    |   1.60 op/s | 623.066 ms | 623.296 ms | 632.076 ms | 634.443 ms |   7.375 ms | 62.969x slower |


## Exec: ./example/json_bench.lua

Loaded data size: 0.720334 MB

- cjson
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- simdjson
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- dkjson
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- lunajson
    - Sampling 30 samples (iteration 1, warmup 1 sec)
- yyjson
    - Sampling 30 samples (iteration 1, warmup 1 sec)

### Sampling Details

| Name     | Samples | Outliers | Conf Level | Target RCIW | GC Mode |
|:---------|--------:|:---------|-----------:|------------:|:--------|
| cjson    | 30      | 1 (3.3%) | 95.0%      | 5.0%        | full GC |
| simdjson | 30      | 1 (3.3%) | 95.0%      | 5.0%        | full GC |
| dkjson   | 30      | 1 (3.3%) | 95.0%      | 5.0%        | full GC |
| lunajson | 30      | 0 (0.0%) | 95.0%      | 5.0%        | full GC |
| yyjson   | 30      | 0 (0.0%) | 95.0%      | 5.0%        | full GC |


### Memory Analysis

*Sorted by Alloc/Op (lower is better).*

| Name     | Samples | Max Alloc/Op | Alloc/Op     | Relative    | Peak Memory | Uncollected | Avg Incr. |
|:---------|--------:|-------------:|-------------:|:------------|------------:|------------:|----------:|
| yyjson   | 30      | 819.00 KB/op | 818.37 KB/op | 1.006x less | 2.62 MB     | 4.00 KB     | 0.14 KB   |
| simdjson | 30      | 823.00 KB/op | 823.00 KB/op | -           | 2.39 MB     | 0.00 KB     | 0.00 KB   |
| cjson    | 30      | 823.00 KB/op | 823.00 KB/op | baseline    | 2.39 MB     | 0.00 KB     | 0.00 KB   |
| lunajson | 30      | 850.00 KB/op | 850.00 KB/op | 1.033x more | 2.54 MB     | 0.00 KB     | 0.00 KB   |
| dkjson   | 30      | 967.00 KB/op | 949.97 KB/op | 1.154x more | 2.57 MB     | 0.00 KB     | 0.00 KB   |


### Measurement Reliability Analysis

*Sorted by measurement precision (lower RCIW = more reliable)*

| Name     | CI Level                    | CI Width  | RCIW | Quality |
|:---------|:----------------------------|----------:|-----:|:--------|
| lunajson | 95% [7.701 ms - 7.720 ms]   | 19.456 us | 0.3% | good    |
| cjson    | 95% [2.625 ms - 2.636 ms]   | 11.610 us | 0.4% | good    |
| dkjson   | 95% [16.162 ms - 16.246 ms] | 83.914 us | 0.5% | good    |
| simdjson | 95% [1.292 ms - 1.303 ms]   | 11.456 us | 0.9% | good    |
| yyjson   | 95% [1.161 ms - 1.182 ms]   | 21.027 us | 1.8% | good    |


### Performance Analysis

*Sorted by mean execution time (lower is better).*

| Name     | Ops/sec     | Mean      | p50       | p95       | p99       | StdDev     | Relative      |
|:---------|------------:|----------:|----------:|----------:|----------:|-----------:|:--------------|
| yyjson   | 853.54 op/s |  1.172 ms |  1.161 ms |  1.228 ms |  1.244 ms |  29.380 us | 2.245x faster |
| simdjson | 770.69 op/s |  1.298 ms |  1.294 ms |  1.328 ms |  1.336 ms |  16.007 us | 2.027x faster |
| cjson    | 380.15 op/s |  2.631 ms |  2.626 ms |  2.657 ms |  2.669 ms |  16.222 us | baseline      |
| lunajson | 129.69 op/s |  7.711 ms |  7.699 ms |  7.768 ms |  7.771 ms |  27.185 us | 2.931x slower |
| dkjson   |  61.71 op/s | 16.204 ms | 16.185 ms | 16.360 ms | 16.540 ms | 117.251 us | 6.160x slower |

````

The report combines several perspectives:

- **Sampling Details** expose how many iterations were collected and whether adaptive sampling met the requested precision.
- **Memory Analysis** reports allocation and peak memory per benchmark to surface GC pressure.
- **Measurement Reliability** classifies confidence intervals so you can judge the stability of each measurement.
- **Performance Analysis** ranks implementations, shows spread (percentiles, standard deviation), and computes relative speedups against the baseline case.

Comparable pairwise significance tables (Welch's t-test or Scott-Knott ESD, depending on group count) are also included to highlight statistically meaningful differences.


## License

MIT License. See LICENSE file for details.
