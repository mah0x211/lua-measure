# Measure Describeモジュール設計書

バージョン: 0.2.0  
日付: 2025-06-18

## 概要

Measure Describeモジュールは、個々のベンチマーク仕様をカプセル化するベンチマーク記述オブジェクトを定義します。流暢なAPIのためのベンチマークプロパティ、検証ロジック、メソッド実装を定義する構造化された方法を提供します。

## 目的

このモジュールは以下を行うベンチマークdescribeオブジェクトを作成・管理します：
- ベンチマーク設定と関数の保存
- メソッド呼び出し順序と引数の検証
- 相互排他性ルールの強制
- 無効な使用に対する明確なエラーメッセージの提供

## モジュール構造

```lua
-- モジュール: measure.describe
local type = type
local format = string.format
local floor = math.floor

local Describe = {}
Describe.__index = Describe

-- ファクトリ関数
local function new_describe(name, namefn)
    -- describeインスタンスを作成して返す
end

return new_describe
```

## コアコンポーネント

### 1. Describeクラス

ベンチマーク記述のメインクラス：

```lua
--- @class measure.describe
--- @field spec measure.describe.spec
local Describe = {}
Describe.__index = Describe
Describe.__tostring = function(self)
    return format('measure.describe %q', self.spec.name)
end
```

### 2. ベンチマーク仕様

```lua
--- @class measure.describe.spec
--- @field name string ベンチマークの名前
--- @field namefn function|nil ベンチマーク名を記述する関数
--- @field options table ベンチマークのオプション
--- @field setup function|nil ベンチマークのsetup関数
--- @field setup_once function|nil ベンチマークのsetup_once関数
--- @field run function|nil ベンチマークのrun関数
--- @field measure function|nil ベンチマークのmeasure関数
--- @field teardown function|nil ベンチマークのteardown関数
```

## メソッド実装

### options()

ベンチマーク実行パラメータを設定：

```lua
function Describe:options(opts)
    local spec = self.spec
    if type(opts) ~= 'table' then
        return false, 'argument must be a table'
    elseif spec.options then
        return false, 'options cannot be defined twice'
    elseif spec.setup or spec.setup_once or spec.run or spec.measure then
        return false, 
               'options must be defined before setup(), setup_once(), run() or measure()'
    end
    
    -- オプションを検証
    if opts.context and type(opts.context) ~= 'table' and 
       type(opts.context) ~= 'function' then
        return false, 'options.context must be a table or a function'
    end
    
    if opts.repeats and type(opts.repeats) ~= 'number' and 
       type(opts.repeats) ~= 'function' then
        return false, 'options.repeats must be a number or a function'
    end
    
    -- warmup、sample_sizeの追加検証...
    
    spec.options = opts
    return true
end
```

### setup() / setup_once()

相互排他性を持つ初期化ロジックを定義：

```lua
function Describe:setup(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.setup then
        return false, 'cannot be defined twice'
    elseif spec.setup_once then
        return false, 'cannot be defined if setup_once() is defined'
    elseif spec.run or spec.measure then
        return false, 'must be defined before run() or measure()'
    end
    
    spec.setup = fn
    return true
end

function Describe:setup_once(fn)
    -- setup/setup_once相互排他性を持つ同様の検証
end
```

### run() / measure()

相互排他性を持つベンチマーク実行を定義：

```lua
function Describe:run(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.run then
        return false, 'cannot be defined twice'
    elseif spec.measure then
        return false, 'cannot be defined if measure() is defined'
    end
    
    spec.run = fn
    return true
end
```

### teardown()

クリーンアップロジックを定義：

```lua
function Describe:teardown(fn)
    local spec = self.spec
    if type(fn) ~= 'function' then
        return false, 'argument must be a function'
    elseif spec.teardown then
        return false, 'cannot be defined twice'
    elseif not spec.run and not spec.measure then
        return false, 'must be defined after run() or measure()'
    end
    
    spec.teardown = fn
    return true
end
```

## ファクトリ関数

```lua
local function new_describe(name, namefn)
    if type(name) ~= 'string' then
        return nil, ('name must be a string, got %q'):format(type(name))
    elseif namefn ~= nil and type(namefn) ~= 'function' then
        return nil, ('namefn must be a function or nil, got %q'):format(
                   type(namefn))
    end
    
    return setmetatable({
        spec = {
            name = name,
            namefn = namefn,
        },
    }, Describe)
end
```

## 検証ルール

### メソッド順序制約

1. `options()`は`setup()`、`setup_once()`、`run()`、`measure()`より前に呼び出す必要がある
2. `setup()`または`setup_once()`は`run()`または`measure()`より前に呼び出す必要がある
3. `teardown()`は`run()`または`measure()`より後に呼び出す必要がある

### 相互排他性

1. `setup()`と`setup_once()`の両方を定義できない
2. `run()`と`measure()`の両方を定義できない
3. どのメソッドも2回呼び出せない

### 必須メソッド

有効なベンチマークには、`run()`または`measure()`の少なくとも1つを定義する必要があります。

## エラー処理

すべてのメソッドは`(bool, error)`タプルを返します：
- 成功: `true, nil`
- 失敗: `false, "エラーメッセージ"`

エラーメッセージは説明的で具体的です：
- `"argument must be a table"`
- `"options cannot be defined twice"`
- `"cannot be defined if setup_once() is defined"`

## 統合ポイント

### Registryモジュール
- レジストリはファクトリ経由でdescribeインスタンスを作成
- 保存前に一意性を検証

### Measureモジュール
- メタテーブル__callを通じてメソッドを呼び出す
- ユーザーへのエラー伝播を処理

## 使用例

```lua
-- レジストリによって作成
local desc = new_describe('String Concat', function(i)
    return 'iteration ' .. i
end)

-- measureモジュールを通じたメソッドチェーン
desc:options({ warmup = 10 })
desc:setup(function(i, ctx) return "test" end)
desc:run(function(str) return str .. str end)
```

## 型安全性

すべての入力は型の正確性が検証されます：
- 名前は文字列でなければならない
- 関数は関数でなければならない
- オプションはテーブルでなければならない
- オプション値は期待される型と一致しなければならない
