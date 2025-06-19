# Measure Registryモジュール設計書

バージョン: 0.2.0  
日付: 2025-06-19

## 概要

Measure Registryモジュールは、ベンチマーク仕様の明示的な登録を管理し、ソースファイル別に整理されたすべてのベンチマークのレジストリを維持します。仕様を明示的にファイル名と関連付けて登録する、シンプルで明示的な登録モデルを提供します。

## 目的

このモジュールは、中央レジストリとして以下の機能を提供します：
- ファイル名とベンチマーク仕様のマッピングを維持
- 登録された仕様のファイル存在を検証
- 明示的な登録と取得のAPIを提供
- レジストリクリア機能によるテストサポート

## モジュール構造

```lua
-- Module: measure.registry
local type = type
local format = string.format
local find = string.find
local tostring = tostring
local open = io.open

-- Registry of all file specifications
local Registry = {}

-- Public API
return {
    get = get,
    add = add_spec,
    clear = clear,
}
```

## 主要コンポーネント

### 1. レジストリテーブル

ベンチマークファイル名と仕様をマッピングするグローバルレジストリ：

```lua
--- @type table<string, measure.spec>
local Registry = {}
```

### 2. ファイル検証

登録されるすべての仕様は、既存のファイルと関連付けられている必要があります：

```lua
-- Ensure filename can open as a file
local file = open(filename, 'r')
if not file then
    -- filename is not a valid file
    return false, format('filename %q must point to an existing file', filename)
end
file:close()
```

### 3. 仕様タイプ検証

measure.specオブジェクトのみが登録可能です：

```lua
elseif not find(tostring(spec), '^measure%.spec') then
    return false, format('spec must be a measure.spec, got %q', tostring(spec))
end
```

## 主要関数

### add_spec()

ファイル名に関連付けられた新しいベンチマーク仕様を登録します：

```lua
local function add_spec(filename, spec)
    if type(filename) ~= 'string' then
        return false, format('filename must be a string, got %s', type(filename))
    elseif not find(tostring(spec), '^measure%.spec') then
        return false, format('spec must be a measure.spec, got %q', tostring(spec))
    end

    -- Ensure filename can open as a file
    local file = open(filename, 'r')
    if not file then
        return false, format('filename %q must point to an existing file', filename)
    end
    file:close()

    Registry[filename] = spec
    return true
end
```

### get()

レジストリ全体を返します：

```lua
local function get()
    return Registry
end
```

### clear()

レジストリをクリアします（テスト目的）：

```lua
local function clear()
    Registry = {}
end
```

## レジストリ構造

レジストリはシンプルなマッピング構造を維持します：

```
Registry = {
    "/path/to/benchmark/example_bench.lua" = spec1,
    "/path/to/benchmark/another_bench.lua" = spec2,
}
```

各仕様は`measure.spec`オブジェクトで、以下を含みます：
- `hooks`: ライフサイクルフック（`before_all`、`before_each`、`after_each`、`after_all`）のテーブル
- `describes`: 番号と名前でインデックス化されたベンチマークdescribeオブジェクトのテーブル

## 統合ポイント

### Measureモジュール
- `registry.add()`を使用して仕様を明示的に登録
- `measure.spec`オブジェクトを独立して作成
- `registry.get()`を使用してすべての登録された仕様にアクセス

### Specモジュール
- レジストリは`measure.spec`オブジェクトのみが登録されることを検証
- レジストリは仕様の参照を保存するが、仕様の作成は管理しない

## 明示的登録モデル

自動ファイルベース登録とは異なり、このモジュールは明示的な登録を必要とします：
1. `measure.spec`オブジェクトを作成
2. `registry.add(filename, spec)`を呼び出して登録
3. レジストリがファイルの存在と仕様タイプを検証
4. レジストリが後の取得のために関連付けを保存

## エラーメッセージ

モジュールは説明的なエラーメッセージを提供します：
- `filename must be a string, got number`
- `spec must be a measure.spec, got "string"`
- `filename "nonexistent.lua" must point to an existing file`

## 使用フロー

1. `measure.spec`オブジェクトを作成
2. 仕様にフックとdescribeを設定
3. `registry.add(filename, spec)`を呼び出して仕様を登録
4. レジストリがファイル名と仕様タイプを検証
5. レジストリがランナーアクセスのために関連付けを保存
6. `registry.get()`を使用してすべての登録された仕様を取得

## セキュリティ考慮事項

1. **ファイル存在検証**: すべてのファイル名は既存のファイルを指す必要がある
2. **タイプセーフティ**: `measure.spec`オブジェクトのみが登録可能
3. **入力検証**: 登録前にすべてのパラメータを検証
4. **明示的制御**: 自動動作なし、すべての登録は明示的

## 実装例

```lua
-- ベンチマークファイル内: example_bench.lua
local registry = require('measure.registry')
local new_spec = require('measure.spec')

-- 新しい仕様を作成
local spec = new_spec()

-- 仕様を設定
spec:set_hook('before_all', function() print('テスト開始') end)
local desc = spec:new_describe('パフォーマンステスト')
desc:run(function() 
    -- ベンチマークコードをここに
end)

-- 仕様を登録
local ok, err = registry.add('example_bench.lua', spec)
if not ok then
    error('仕様の登録に失敗: ' .. err)
end
```

## ランナー統合

ランナーは登録されたすべてのベンチマークにアクセスできます：

```lua
local registry = require('measure.registry')
local all_specs = registry.get()

for filename, spec in pairs(all_specs) do
    print("ベンチマーク実行中:", filename)
    -- フックとベンチマークを実行
end
```
