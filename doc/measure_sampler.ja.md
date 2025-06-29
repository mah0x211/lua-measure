# Measure Sampler モジュール設計書

バージョン: 0.1.0  
日付: 2025-06-29

## 概要

Measure Sampler モジュールは、パフォーマンス測定を簡素化する関数ベースのベンチマーク実行エンジンを提供します。オブジェクト管理の複雑さを排除し、統合された時間とガベージコレクションデータ収集による実行に焦点を当てた、クリーンな3引数APIを実装し、合理化されたエラーハンドリングを提供します。

## 目的

このモジュールは、measureシステムのベンチマーク実行エンジンとして機能します：
- 精密なタイミングとGC測定でベンチマーク関数を実行
- シンプルな関数ベースAPI（オブジェクトのインスタンス化不要）を提供
- 測定収集とは別にウォームアップ実行を処理
- 統一されたデータ収集のためにmeasure.samplesとシームレスに統合
- サンプルオブジェクトを通じてGC状態を自動管理
- 明確な失敗報告を伴う堅牢なエラーハンドリングを提供

## モジュール構造

```lua
-- モジュール: measure.sampler
local sampler = require('measure.sampler')

-- 3つの引数を持つ関数ベースAPI
local success, error_message = sampler(
    benchmark_function,  -- ベンチマークする関数
    samples_object,      -- measure.samplesオブジェクト（GC設定を含む）
    warmup_seconds       -- オプションのウォームアップ時間（デフォルト: 0）
)
```

## 主要コンポーネント

### 1. 関数ベースアーキテクチャ

サンプラーはオブジェクトではなく直接関数呼び出しとして実装されています：

```c
static int run_lua(lua_State *L)
{
    sampler_t s = {.L = L};
    
    // 引数を検証
    luaL_checktype(L, 1, LUA_TFUNCTION);           // ベンチマーク関数
    s.samples = luaL_checkudata(L, 2, MEASURE_SAMPLES_MT); // サンプルオブジェクト
    lua_Integer iv = luaL_optinteger(L, 3, 0);     // オプションのウォームアップ
    s.warmup = (iv < 0) ? 0 : (int)iv;
    
    // ウォームアップとサンプリングを実行
    if (s.warmup > 0) warmup_lua(&s);
    return sampling_lua(&s);
}
```

### 2. 統合されたサンプリングプロセス

サンプリングプロセスはサンプルオブジェクトと密接に統合されています：

```c
static int sampling_lua(sampler_t *s)
{
    lua_State *L = s->L;
    size_t sample_size = s->samples->capacity;
    
    // サンプルオブジェクトの前処理（GC状態をセットアップ）
    measure_samples_preprocess(s->samples, L);
    
    for (size_t i = 0; i < sample_size; i++) {
        // サンプルを初期化（開始時間とメモリを記録）
        measure_samples_init_sample(s->samples, L);
        
        // ベンチマーク関数を実行
        lua_pushvalue(L, 1);
        lua_pushboolean(L, 0);  // is_warmup = false
        int rc = lua_pcall(L, 1, 0, 0);
        
        // サンプルを更新（終了時間とメモリを記録）
        measure_samples_update_sample(s->samples, L);
        
        // エラーを処理
        if (is_lua_error(L, rc)) return -1;
    }
    
    // サンプルオブジェクトの後処理（GC状態を復元）
    measure_samples_postprocess(s->samples, L);
    return 0;
}
```

### 3. ウォームアップ実行

ウォームアップ実行は測定収集とは別に行われます：

```c
static int warmup_lua(sampler_t *s)
{
    if (s->warmup > 0) {
        const uint64_t warmup_ns = MEASURE_SEC2NSEC(s->warmup);
        uint64_t start_time = measure_getnsec();
        
        while ((measure_getnsec() - start_time) < warmup_ns) {
            lua_pushvalue(L, 1);
            lua_pushboolean(L, 1);  // is_warmup = true
            lua_pcall(L, 1, 0, 0);
        }
    }
    return 0;
}
```

## API リファレンス

### メイン関数

#### `sampler(benchmark_function, samples_object, warmup_seconds)`

ベンチマーク関数を実行し、パフォーマンスデータを収集します。

**パラメータ:**
- `benchmark_function` (function): ベンチマークする関数
  - `is_warmup` ブール値パラメータを受け取ります
  - 測定対象の操作を実行する必要があります
- `samples_object` (measure.samples): 結果とGC設定を格納するオブジェクト
- `warmup_seconds` (integer, オプション): ウォームアップ時間（秒）（デフォルト: 0）

**戻り値:**
- 実行成功時: `true`
- 失敗時: `false, error_message`

**例:**
```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')(1000, 0) -- 容量1000、フルGC

local ok, err = sampler(function(is_warmup)
    if not is_warmup then
        -- 測定中のみ重い操作を実行
        return expensive_calculation()
    else
        -- ウォームアップ中は軽い操作
        simple_calculation()
    end
end, samples, 2) -- 2秒のウォームアップ

if not ok then
    print("ベンチマーク失敗:", err)
else
    print("ベンチマーク正常完了")
    local data = samples:dump()
    print("平均時間 (μs):", calculate_mean(data.time_ns) / 1000)
end
```

## 使用例

### 基本的なベンチマーク

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

-- フルGCでサンプルオブジェクトを作成
local s = samples(1000, 0)

-- ウォームアップなしのシンプルなベンチマーク
local ok = sampler(function(is_warmup)
    -- 関数は常に同じ操作を実行
    local sum = 0
    for i = 1, 10000 do
        sum = sum + i
    end
    return sum
end, s)

if ok then
    local data = s:dump()
    print("収集されたサンプル数:", #s)
    print("最短時間 (ns):", min(data.time_ns))
    print("最長時間 (ns):", max(data.time_ns))
    print("割り当てられたメモリ (KB):", sum(data.allocated_kb))
end
```

### ウォームアップとメモリ分析

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

-- ステップGC（1MB割り当て時にトリガー）でサンプルを作成
local s = samples(100, 1024)

local ok, err = sampler(function(is_warmup)
    if is_warmup then
        -- 軽いウォームアップ - 小さなオブジェクトのみ作成
        local temp = {}
        for i = 1, 100 do
            temp[i] = i
        end
    else
        -- 実際のベンチマーク - 大量のメモリを割り当て
        local data = {}
        for i = 1, 1000 do
            data[i] = string.rep("benchmark", 100)
        end
        return data
    end
end, s, 3) -- 3秒のウォームアップ

if ok then
    local data = s:dump()
    print("実行分析:")
    print("  総サンプル数:", #s)
    print("  平均時間 (μs):", calculate_mean(data.time_ns) / 1000)
    print("  サンプルあたりの平均割り当て量 (KB):", calculate_mean(data.allocated_kb))
    print("  ピークメモリ使用量 (KB):", max(data.after_kb))
else
    print("ベンチマーク失敗:", err)
end
```

### エラーハンドリングと検証

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

local s = samples(50, -1) -- 最高速度のためにGCを無効化

-- エラーハンドリングをテスト
local ok, err = sampler(function(is_warmup)
    if not is_warmup then
        -- 測定中にエラーをシミュレート
        if math.random() < 0.1 then
            error("ランダムなベンチマーク失敗")
        end
        
        -- 通常の操作
        return calculate_something()
    end
end, s, 1)

if not ok then
    print("予期されたエラーが発生:", err)
    print("部分的に収集されたサンプル数:", #s)
else
    print("すべてのサンプルが正常に収集されました:", #s)
end
```

### 比較分析

```lua
local sampler = require('measure.sampler')
local samples = require('measure.samples')

-- 2つの異なるアルゴリズムを比較
local function algorithm_a()
    local result = {}
    for i = 1, 1000 do
        result[i] = i * i
    end
    return result
end

local function algorithm_b()
    local result = {}
    for i = 1, 1000 do
        table.insert(result, i * i)
    end
    return result
end

-- アルゴリズムAをベンチマーク
local samples_a = samples(100, 0)
local ok_a = sampler(algorithm_a, samples_a, 1)

-- アルゴリズムBをベンチマーク
local samples_b = samples(100, 0)
local ok_b = sampler(algorithm_b, samples_b, 1)

if ok_a and ok_b then
    local data_a = samples_a:dump()
    local data_b = samples_b:dump()
    
    print("アルゴリズムA - 平均時間 (μs):", calculate_mean(data_a.time_ns) / 1000)
    print("アルゴリズムB - 平均時間 (μs):", calculate_mean(data_b.time_ns) / 1000)
    print("パフォーマンス比:", calculate_mean(data_b.time_ns) / calculate_mean(data_a.time_ns))
end
```

## 統合ポイント

### measure.samplesとの統合

サンプラー関数にはデータ収集とGC動作の両方を設定するサンプルオブジェクトが必要です：

```lua
local samples_fast = samples(1000, -1)    -- GC無効
local samples_stable = samples(1000, 0)   -- フルGCモード
local samples_balanced = samples(1000, 512) -- 512KBでステップGC

-- 異なるGC戦略で同じベンチマーク
sampler(benchmark_func, samples_fast)     -- 最速実行
sampler(benchmark_func, samples_stable)   -- 最も一貫した結果
sampler(benchmark_func, samples_balanced) -- バランスの取れたアプローチ
```

### 統計分析ライブラリとの統合

関数ベースAPIは分析ワークフローとクリーンに統合されます：

```lua
local function run_benchmark(func, samples_config, warmup_time)
    local s = samples(samples_config.capacity, samples_config.gc_step)
    local ok, err = sampler(func, s, warmup_time)
    
    if ok then
        return s:dump()
    else
        error("ベンチマーク失敗: " .. err)
    end
end

-- 複数の設定を実行
local configs = {
    {capacity = 1000, gc_step = -1, name = "fast"},
    {capacity = 1000, gc_step = 0, name = "stable"},
    {capacity = 1000, gc_step = 1024, name = "balanced"}
}

for _, config in ipairs(configs) do
    local data = run_benchmark(test_function, config, 2)
    analyze_and_report(data, config.name)
end
```

## パフォーマンス考慮事項

### 実行オーバーヘッド

- 関数呼び出しのオーバーヘッドは最小限（単一のC関数）
- ベンチマーク実行ごとのオブジェクト割り当てなし
- サンプルオブジェクトとの直接統合によりデータコピーを削減
- ウォームアップと測定フェーズが明確に分離

### メモリ管理

- ベンチマーク実行間での永続的な状態なし
- Luaガベージコレクションによる自動クリーンアップ
- Cレベルのサンプル管理により中間割り当てを防止
- GC状態はサンプルオブジェクトを通じて完全に管理

### エラーハンドリングのパフォーマンス

- ベンチマーク実行中の高速エラー検出
- 最初のエラーで早期終了
- パフォーマンス影響なしの詳細なエラー報告
- エラー後でもクリーンな状態復元

## エラーハンドリング

### 引数検証

```lua
-- 無効な関数
local ok, err = sampler("not a function", samples_obj)
-- 戻り値: false, "bad argument #1 to 'sampler' (function expected, got string)"

-- 無効なサンプルオブジェクト
local ok, err = sampler(function() end, "not samples")
-- 戻り値: false, "bad argument #2 to 'sampler' (measure.samples expected, got string)"

-- 無効なウォームアップ
local ok, err = sampler(function() end, samples_obj, "invalid")
-- 戻り値: false, "bad argument #3 to 'sampler' (number expected, got string)"
```

### 実行時エラー

```lua
local ok, err = sampler(function(is_warmup)
    if not is_warmup then
        error("ベンチマーク実行時エラー")
    end
end, samples_obj)
-- 戻り値: false, "runtime error: ベンチマーク実行時エラー"
```

### メモリエラー

```lua
-- 容量超過（サンプルオブジェクトにより自動処理）
local small_samples = samples(2, 0)
local ok = sampler(function() end, small_samples) -- 2サンプルのみ実行
-- 戻り値: true（容量に自動的に制限）
```

## バージョン履歴

- **0.1.0** (2025-06-29): 関数ベースAPIでの初回リリース
  - 3引数関数インターフェース
  - 統合されたサンプルオブジェクト処理
  - サンプルを通じた自動GC状態管理
  - 分離されたウォームアップと測定フェーズ
  - 包括的なエラーハンドリング