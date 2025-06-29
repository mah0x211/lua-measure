# Measure Samples モジュール設計書

バージョン: 0.1.0  
日付: 2025-06-29

## 概要

Measure Samples モジュールは、パフォーマンスベンチマーク用の統合されたサンプルとガベージコレクション（GC）データ管理機能を提供します。実行時間測定とGCメトリクスを統一された列指向データ構造で組み合わせ、ベンチマーク実行中の実行時間とメモリ割り当てパターンの両方について包括的な洞察を提供します。

## 目的

このモジュールは、measureシステムのコアデータ収集コンポーネントとして機能します：
- 高精度でナノ秒単位の実行時間サンプルを収集
- ガベージコレクションメトリクス（操作前後のメモリ使用量、割り当て量）を追跡
- 効率的な統計分析のための列指向データ形式を提供
- サンプリング中のGC状態を自動管理
- GC設定をサンプルオブジェクトに直接統合

## モジュール構造

```lua
-- モジュール: measure.samples
local samples = require('measure.samples')

-- 容量とオプションのGC設定でサンプルオブジェクトを作成
local s = samples(capacity, gc_step)

-- 利用可能なメソッド:
-- s:capacity()  -- 容量を取得
-- s:dump()      -- 列指向データを取得
-- #s            -- 現在のカウントを取得
```

## 主要コンポーネント

### 1. データ構造

モジュールは時間とGCメトリクスを組み合わせた統一データ構造を使用します：

```c
typedef struct {
    uint64_t time_ns;    // 実行時間（ナノ秒）
    size_t before_kb;    // 操作前のメモリ使用量（KB）
    size_t after_kb;     // 操作後のメモリ使用量（KB）
    size_t allocated_kb; // 操作中に割り当てられたメモリ（KB）
} measure_samples_data_t;

typedef struct {
    size_t capacity;              // サンプルの最大数
    size_t count;                 // 現在のサンプル数
    size_t base_kb;               // 初期GC後のメモリベースライン
    int saved_gc_pause;           // 保存されたGCポーズ値
    int saved_gc_stepmul;         // 保存されたGCステップ乗数
    int gc_step;                  // GC設定
    int ref_data;                 // Luaレジストリ参照
    measure_samples_data_t *data; // サンプル配列
} measure_samples_t;
```

### 2. GC設定

`gc_step` パラメータはガベージコレクションの動作を制御します：

- **-1**: サンプリング中はGC無効
- **0**: 各サンプル前にフルGC（デフォルト）
- **>0**: KB単位の閾値でステップGC

### 3. 自動GC管理

モジュールはサンプリング中にGC状態を自動的に管理します：

```c
// サンプリング前
measure_samples_preprocess(samples, L);
// サンプリング中
measure_samples_init_sample(samples, L);
measure_samples_update_sample(samples, L);
// サンプリング後
measure_samples_postprocess(samples, L);
```

## API リファレンス

### コンストラクタ

#### `samples(capacity, gc_step)`

新しいサンプルオブジェクトを作成します。

**パラメータ:**
- `capacity` (integer): サンプルの最大数（デフォルト: 1000）
- `gc_step` (integer, オプション): GC設定（デフォルト: 0）

**戻り値:**
- 成功時: サンプルオブジェクト
- 失敗時: `nil, error_message`

**例:**
```lua
local samples = require('measure.samples')
local s1 = samples(100)        -- 容量100、フルGC
local s2 = samples(100, -1)    -- 容量100、GC無効
local s3 = samples(100, 1024)  -- 容量100、1024KBでステップGC
```

### メソッド

#### `samples:capacity()`

サンプルオブジェクトの最大容量を返します。

**戻り値:**
- `integer`: サンプルの最大数

#### `samples:dump()`

効率的な分析のために列指向形式で収集されたデータを返します。

**戻り値:**
- `table`: 以下のフィールドを持つ列指向データ構造：
  - `time_ns`: ナノ秒単位の実行時間の配列
  - `before_kb`: 各操作前のメモリ使用量の配列（KB）
  - `after_kb`: 各操作後のメモリ使用量の配列（KB）
  - `allocated_kb`: 各操作中に割り当てられたメモリの配列（KB）

**例:**
```lua
local data = samples:dump()
print("平均時間:", calculate_mean(data.time_ns))
print("総割り当て量:", sum(data.allocated_kb))
print("メモリ効率:", analyze_allocation_pattern(data))
```

#### `#samples`

収集されたサンプルの現在の数を返します。

**戻り値:**
- `integer`: 収集されたサンプル数

## 使用例

### 基本的な使用方法

```lua
local samples = require('measure.samples')
local sampler = require('measure.sampler')

-- フルGCモードでサンプルを作成
local s = samples(1000, 0)

-- ベンチマークを実行
local ok = sampler(function()
    -- ここにベンチマークコードを記述
    local result = expensive_calculation()
    return result
end, s)

-- 結果を分析
if ok then
    local data = s:dump()
    print("収集されたサンプル数:", #s)
    print("平均時間 (μs):", calculate_mean(data.time_ns) / 1000)
    print("総割り当て量 (KB):", sum(data.allocated_kb))
end
```

### GCパフォーマンス分析

```lua
-- 異なるGCモードを比較
local samples_disabled = samples(100, -1)  -- GC無効
local samples_full = samples(100, 0)       -- フルGC
local samples_step = samples(100, 1024)    -- ステップGC

local function benchmark_func()
    local t = {}
    for i = 1, 1000 do
        t[i] = string.rep("data", 100)
    end
    return t
end

-- 異なるGCモードでベンチマークを実行
sampler(benchmark_func, samples_disabled)
sampler(benchmark_func, samples_full) 
sampler(benchmark_func, samples_step)

-- 割り当てパターンを比較
local data_disabled = samples_disabled:dump()
local data_full = samples_full:dump()
local data_step = samples_step:dump()

print("GC無効 - 平均割り当て量:", calculate_mean(data_disabled.allocated_kb))
print("フルGC - 平均割り当て量:", calculate_mean(data_full.allocated_kb))
print("ステップGC - 平均割り当て量:", calculate_mean(data_step.allocated_kb))
```

## 統合ポイント

### measure.samplerとの統合

サンプルオブジェクトはサンプラー関数に直接渡されます：

```lua
local ok, error_msg = sampler(benchmark_function, samples_object, warmup_time)
```

### 統計分析との統合

列指向形式により効率的な統計操作が可能になります：

```lua
local data = samples:dump()

-- 時間統計
local time_stats = {
    mean = calculate_mean(data.time_ns),
    median = calculate_median(data.time_ns),
    std_dev = calculate_std_dev(data.time_ns),
    percentiles = calculate_percentiles(data.time_ns, {50, 95, 99})
}

-- メモリ統計
local memory_stats = {
    total_allocated = sum(data.allocated_kb),
    avg_allocation = calculate_mean(data.allocated_kb),
    peak_usage = max(data.after_kb)
}
```

## パフォーマンス考慮事項

### メモリ効率

- データはキャッシュ効率のために連続配列に格納
- 列指向形式によりメモリアクセスオーバーヘッドを最小化
- Lua userdata管理によりサンプルデータのガベージコレクションを防止

### GCの影響

- **GC無効** (`-1`): 最速の実行、ただしメモリが蓄積される可能性
- **フルGC** (`0`): 一貫したベースライン、ただし最高のオーバーヘッド
- **ステップGC** (`>0`): バランスの取れたアプローチ、割り当て閾値でGCをトリガー

### 統計分析

- 列形式によりベクトル化された操作が可能
- データ変換なしで特定のメトリクスに直接アクセス
- 大きなサンプルセット（>10,000サンプル）で効率的

## エラーハンドリング

### コンストラクタエラー

```lua
local s, err = samples(0)  -- 無効な容量
if not s then
    print("エラー:", err)  -- "capacity must be > 0"
end
```

### 容量オーバーフロー

モジュールは容量制限を適切に処理します：
- 新しいベンチマーク開始時にサンプリングが自動的にリセット
- バッファオーバーフローなし - 容量制限でサンプリング停止
- サンプラーの戻り値によるエラー報告

### メモリ管理

- Luaガベージコレクションによる自動クリーンアップ
- レジストリ参照により早すぎる解放を防止
- Cメモリ割り当ての安全な処理

## バージョン履歴

- **0.1.0** (2025-06-29): 統合GC機能を持つ初回リリース
  - 列指向データ形式
  - 統一された時間とGC測定
  - 自動GC状態管理
  - 3つのGCモード：無効、フル、ステップ