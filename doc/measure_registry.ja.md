# Measure Registryモジュール設計書

バージョン: 0.1.0  
日付: 2025-06-17

## 概要

Measure Registryモジュールは、ファイルスコープのベンチマーク仕様を管理し、ソースファイルごとに整理されたすべてのベンチマークのレジストリを維持します。どのベンチマークがどのファイルに属するかを追跡しながら、ベンチマークファイル間の分離を提供します。

## 目的

このモジュールは以下を行う中央レジストリとして機能します：
- ファイル固有のベンチマーク仕様の作成と管理
- ファイル名をベンチマーク仕様にマッピングするレジストリの維持
- ライフサイクル関数のフック管理の提供
- 新しいベンチマークdescribeオブジェクトの作成

## モジュール構造

```lua
-- モジュール: measure.registry
local describe = require('measure.describe')

-- すべてのファイル仕様のレジストリ
local Registry = {}

-- パブリックAPI
return {
    get = get,
    new = new,
}
```

## コアコンポーネント

### 1. レジストリテーブル

ベンチマークファイル名をその仕様にマッピングするグローバルレジストリ：

```lua
--- @type table<string, measure.registry.spec>
local Registry = {}
```

### 2. Registry Specクラス

各ベンチマークファイルは独自のspecインスタンスを取得します：

```lua
--- @class measure.registry.spec
--- @field filename string ベンチマークファイルのファイル名
--- @field hooks table<string, function> ベンチマークのフック
--- @field describes table<string, measure.describe> ベンチマークのdescribe
local Spec = {}
Spec.__index = Spec
```

### 3. フック管理

```lua
function Spec:set_hook(name, fn)
    local HookNames = {
        before_all = true,
        before_each = true,
        after_each = true,
        after_all = true,
    }
    
    if not HookNames[name] then
        return false, ('Error: unknown hook %q'):format(tostring(name))
    elseif type(fn) ~= 'function' then
        return false, ('Error: %q must be a function'):format(name)
    end
    
    local v = self.hooks[name]
    if type(v) == 'function' then
        return false, ('Error: %q cannot be defined twice'):format(name)
    end
    
    self.hooks[name] = fn
    return true
end
```

### 4. Describe作成

```lua
function Spec:new_describe(name, namefn)
    -- 新しいdescribeオブジェクトを作成
    local desc, err = new_describe(name, namefn)
    if not desc then
        return nil, err
    end
    
    -- 重複名をチェック
    if self.describes[name] then
        return nil, ('name %q already exists, it must be unique'):format(name)
    end
    
    -- describeリストとマップに追加
    self.describes[#self.describes + 1] = desc
    self.describes[name] = desc
    return desc
end
```

## 主要関数

### new()

現在のベンチマークファイルのspecを作成または取得します：

```lua
local function new()
    -- 呼び出し元からファイルパスを取得
    local filename = get_caller_filename()
    
    local spec = Registry[filename]
    if spec then
        return spec
    end
    
    -- 新しいspecを作成
    spec = setmetatable({
        filename = filename,
        hooks = {},
        describes = {},
    }, Spec)
    
    Registry[filename] = spec
    return spec
end
```

### get()

レジストリ全体を返します：

```lua
local function get()
    return Registry
end
```

## レジストリ構造

レジストリは2レベル構造を維持します：

```
Registry = {
    "/path/to/benchmark/example_bench.lua" = {
        filename = "/path/to/benchmark/example_bench.lua",
        hooks = {
            before_all = function() ... end,
            after_each = function() ... end,
        },
        describes = {
            [1] = describe1,
            [2] = describe2,
            ["Benchmark Name 1"] = describe1,
            ["Benchmark Name 2"] = describe2,
        }
    },
    "/path/to/benchmark/another_bench.lua" = { ... }
}
```

## 統合ポイント

### Measureモジュール
- `new()`を呼び出してファイル固有のspecを取得
- フックとdescribe管理にspecメソッドを使用

### Describeモジュール
- レジストリはインスタンス作成のためにdescribeモジュールをインポート
- describeオブジェクトをmeasureモジュールに返す

## ファイル分離

各ベンチマークファイルは、measureモジュールを要求すると自動的に独自のspecを取得します。ファイル名はコールスタックから決定され、手動設定なしで適切な分離を保証します。

## エラーメッセージ

モジュールは説明的なエラーメッセージを提供します：
- `Error: unknown hook "invalid_hook"`
- `Error: before_all must be a function`
- `Error: before_all cannot be defined twice`
- `name "Test" already exists, it must be unique`

## 使用フロー

1. ベンチマークファイルがmeasureモジュールを要求
2. Measureモジュールが`registry.new()`を呼び出す
3. レジストリがそのファイルのspecを作成/取得
4. Specがそのファイルのフックとdescribeを管理
5. レジストリがランナーアクセス用のマッピングを維持

## セキュリティ考慮事項

1. **ファイル名ベースの分離**: 各ファイルが独自の名前空間を取得
2. **重複防止**: 名前はファイル内で一意である必要がある
3. **型検証**: すべての入力が保存前に検証される
4. **クロスファイルアクセスなし**: ファイルは他のファイルのspecにアクセスできない

## 実装例

```lua
-- ベンチマークファイル内: example_bench.lua
local measure = require('measure')

-- これにより、レジストリに"example_bench.lua"のspecが作成される
measure.before_all = function() ... end

-- これにより、example_bench.lua specにdescribeが追加される
measure.describe('Test 1').run(function() ... end)
```

## ランナー統合

ランナーは登録されたすべてのベンチマークにアクセスできます：

```lua
local registry = require('measure.registry')
local all_specs = registry.get()

for filename, spec in pairs(all_specs) do
    print("Running benchmarks from:", filename)
    -- フックとベンチマークを実行
end
```
