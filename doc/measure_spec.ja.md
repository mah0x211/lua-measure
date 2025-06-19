# Measure Specモジュール設計書

バージョン: 0.1.0  
日付: 2025-06-19

## 概要

Measure Specモジュールは、ライフサイクルフックとベンチマークdescribeオブジェクトを管理するベンチマーク仕様オブジェクトを作成するファクトリー関数を提供します。各specは、ファイルのベンチマーク設定のコンテナーとして機能します。

## 目的

このモジュールは、以下の機能を持つベンチマーク仕様の基盤として機能します：
- ベンチマークファイル用の独立したspecオブジェクトを作成
- ライフサイクルフック（`before_all`、`before_each`、`after_each`、`after_all`）を管理
- ベンチマークdescribeオブジェクトを作成・管理
- フック名とdescribeの一意性の検証を提供

## モジュール構造

```lua
-- Module: measure.spec
local new_describe = require('measure.describe')
local type = type
local format = string.format
local setmetatable = setmetatable
local concat = table.concat

-- Valid hook names
local HOOK_NAMES = {
    before_all = true,
    before_each = true,
    after_each = true,
    after_all = true,
}

-- Spec metatable
local Spec = require('measure.metatable')('measure.spec')

-- Public API
return new_spec
```

## 主要コンポーネント

### 1. Specクラス

各specはメタテーブルベースのオブジェクトです：

```lua
--- @class measure.spec
--- @field hooks table<measure.spec.hookname, function> The hooks for the benchmark
--- @field describes table The describes for the benchmark
local Spec = require('measure.metatable')('measure.spec')
```

### 2. フック管理

```lua
function Spec:set_hook(name, fn)
    if type(name) ~= 'string' then
        return false, format('name must be a string, got %s', type(name))
    elseif type(fn) ~= 'function' then
        return false, format('fn must be a function, got %s', type(fn))
    elseif not HOOK_NAMES[name] then
        return false,
               format('Invalid hook name %q, must be one of: %s', name,
                      concat(HOOK_NAMES), ', ')
    end

    local v = self.hooks[name]
    if type(v) == 'function' then
        return false, format('Hook %q already exists, it must be unique', name)
    end

    self.hooks[name] = fn
    return true
end
```

### 3. Describe作成

```lua
function Spec:new_describe(name, namefn)
    -- Create new describe object
    local desc, err = new_describe(name, namefn)
    if not desc then
        return nil, err
    end

    -- Check for duplicate names
    if self.describes[name] then
        return nil, format('name %q already exists, it must be unique', name)
    end

    -- Add to describes list and map
    local idx = #self.describes + 1
    self.describes[idx] = desc
    self.describes[name] = desc
    return desc
end
```

## 主要関数

### new_spec()

新しいspecオブジェクトを作成します：

```lua
local function new_spec()
    -- Create new spec
    return setmetatable({
        hooks = {},
        describes = {},
    }, Spec)
end
```

## フックタイプ

モジュールは4つのライフサイクルフックをサポートします：

1. **before_all**: spec内のすべてのベンチマーク前に一度実行
2. **before_each**: 各ベンチマーク反復前に実行
3. **after_each**: 各ベンチマーク反復後に実行  
4. **after_all**: spec内のすべてのベンチマーク後に一度実行

## Spec構造

各specオブジェクトは以下を含みます：

```
spec = {
    hooks = {
        before_all = function() ... end,    -- オプション
        before_each = function() ... end,   -- オプション
        after_each = function() ... end,    -- オプション
        after_all = function() ... end,     -- オプション
    },
    describes = {
        [1] = describe1,                    -- インデックスアクセス
        [2] = describe2,
        ["Benchmark Name 1"] = describe1,   -- 名前ベースアクセス
        ["Benchmark Name 2"] = describe2,
    }
}
```

## 統合ポイント

### Registryモジュール
- Registryは`tostring(spec)`パターンマッチングを使用してspecオブジェクトを検証
- Registryはファイルベース整理のためにspec参照を保存

### Describeモジュール
- Specはdescribeファクトリー関数をインポート
- Specはdescribeオブジェクトを作成し、ライフサイクルを管理
- Describeオブジェクトはインデックスと名前の両方で保存

### Metatableモジュール
- Specは一貫した`__tostring`動作のためにメタテーブルを使用
- オブジェクトアイデンティティとタイプチェックを提供

## エラーメッセージ

モジュールは説明的なエラーメッセージを提供します：
- `name must be a string, got number`
- `fn must be a function, got string`
- `Invalid hook name "invalid_hook", must be one of: "before_all", "before_each", "after_each", "after_all"`
- `Hook "before_all" already exists, it must be unique`
- `name "Test" already exists, it must be unique`

## 検証ルール

### フック検証
1. フック名は文字列である必要がある
2. フック関数は関数である必要がある
3. フック名は4つの有効なタイプの1つである必要がある
4. 各フックタイプはspec毎に一度だけ設定可能

### Describe検証
1. Describe名は文字列である必要がある
2. 名前関数（提供された場合）は関数である必要がある
3. Describe名はspec内で一意である必要がある
4. Describeはインデックスと名前の両方でアクセス可能

## 使用例

```lua
local new_spec = require('measure.spec')

-- 新しいspecを作成
local spec = new_spec()

-- ライフサイクルフックを設定
spec:set_hook('before_all', function()
    print('テスト環境をセットアップ中')
end)

spec:set_hook('after_all', function()
    print('テスト環境をクリーンアップ中')
end)

-- ベンチマークdescribeを作成
local desc1 = spec:new_describe('文字列連結')
desc1:run(function()
    local result = 'hello' .. 'world'
end)

local desc2 = spec:new_describe('テーブル挿入')
desc2:run(function()
    local t = {}
    table.insert(t, 'value')
end)

-- describeにアクセス
print(#spec.describes)              -- 2
print(spec.describes[1])            -- desc1
print(spec.describes['テーブル挿入']) -- desc2
```

## 独立性

各specオブジェクトは完全に独立しています：
- 個別のhooksテーブル
- 個別のdescribesテーブル  
- spec間で共有状態なし
- 複数のspecが同時に存在可能

## セキュリティ考慮事項

1. **タイプセーフティ**: すべての入力は保存前に検証
2. **一意性**: フックとdescribe名は一意である必要がある
3. **分離**: 各specは独立した状態を維持
4. **検証**: 包括的な入力検証により無効状態を防止

## 設計パターン

### ファクトリーパターン
- `new_spec()`はファクトリー関数として機能
- 完全に初期化されたspecオブジェクトを返す
- すべてのspec間で一貫した初期化

### ビルダーパターン
- Specは段階的に設定される
- `set_hook()`と`new_describe()`でspecを構築
- 各メソッドが検証とエラーハンドリングを提供

### レジストリパターン
- Describeはインデックスと名前アクセスパターンの両方で保存
- 反復と直接ルックアップの両方をサポート
- 参照整合性を維持