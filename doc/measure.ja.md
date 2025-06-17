# Measureモジュール設計書

バージョン: 0.1.0  
日付: 2025-06-17

## 概要

Measureモジュールは、内部状態への直接アクセスを防ぐ安全なメタテーブルベースAPIを実装し、ベンチマーク定義のメインエントリーポイントとして機能します。流暢なドット記法構文を使用してベンチマークを定義するための主要インターフェースを提供し、全体的な登録プロセスを管理します。

## 目的

このモジュールは、ユーザーコードと内部レジストリシステム間を調整するレジストラとして機能します。セキュリティと適切なメソッド呼び出しシーケンスを維持しながら、メタテーブルを通じて制御されたAPIサーフェスを公開します。

## モジュール構造

```lua
-- モジュール: measure
local registry = require('measure.registry')
local registrar = create_registrar()
return registrar
```

## コアコンポーネント

### 1. レジストラオブジェクト

レジストラは、メインAPIとして機能するメタテーブル制御オブジェクトです：

```lua
local registrar = setmetatable({}, {
    __newindex = hook_setter,      -- フック割り当てを処理
    __call = method_caller,        -- メソッド呼び出しを処理
    __index = method_resolver      -- プロパティアクセスを処理
})
```

### 2. 状態管理

```lua
-- 内部状態追跡
local desc = nil          -- 現在のdescribeオブジェクトまたはメソッド名
local descfn = nil        -- 呼び出し待ちメソッド
local RegistrySpec = nil  -- ファイル固有のレジストリ仕様
```

### 3. フック管理

モジュールは、直接割り当てで設定される4つのライフサイクルフックをサポートします：

- `before_all`: すべてのベンチマークの前に一度呼び出される
- `before_each`: 各ベンチマークの前に呼び出される
- `after_each`: 各ベンチマークの後に呼び出される
- `after_all`: すべてのベンチマークの後に一度呼び出される

## メタテーブル実装

### フックセッター (__newindex)

```lua
__newindex = function(_, key, fn)
    local ok, err = RegistrySpec:set_hook(key, fn)
    if not ok then
        error(err, 2)
    end
end
```

レジストリ仕様を通じてライフサイクルフックを検証し登録します。

### メソッド呼び出し器 (__call)

```lua
__call = function(self, ...)
    if desc == 'describe' then
        -- 新しいベンチマーク記述を作成
        local err
        desc, err = RegistrySpec:new_describe(...)
        if not desc then
            error(err, 2)
        end
        return self
    end
    
    if desc == nil or descfn == nil then
        error('Attempt to call measure as a function', 2)
    end
    
    -- 現在のdescribeオブジェクトでメソッドを呼び出す
    local fn = desc[descfn]
    if type(fn) ~= 'function' then
        error(('%s has no %q'):format(desc, descfn), 2)
    end
    
    local ok, err = fn(desc, ...)
    if not ok then
        error(('%s %s(): %s'):format(desc, descfn, err), 2)
    end
    
    descfn = nil
    return self
end
```

`measure.describe()`呼び出しとチェーンメソッド呼び出しの両方を処理します。

### メソッド解決器 (__index)

```lua
__index = function(self, key)
    if type(key) ~= 'string' or type(desc) == 'string' or descfn then
        error(('Attempt to access measure as a table: %q'):format(
            tostring(key)), 2)
    end
    
    if desc == nil then
        desc = key
        return self
    end
    
    descfn = key
    return self
end
```

メソッドチェーンのステートマシンを管理します。

## APIフロー

### 1. フック定義
```lua
measure.before_all = function() return {} end
measure.after_each = function(i, ctx) end
```

### 2. ベンチマーク定義
```lua
measure.describe('Name').options({}).run(function() end)
```

### 3. 状態遷移
```
初期 → describe → Describeアクティブ → メソッド → メソッド保留 → 呼び出し → Describeアクティブ
```

## 統合ポイント

### Registryモジュール
- `registry.new()`を通じて`RegistrySpec`を取得
- フック保存を`RegistrySpec:set_hook()`に委譲
- `RegistrySpec:new_describe()`経由でdescribeを作成

### Describeモジュール
- レジストリからdescribeオブジェクトを受け取る
- 検証付きでdescribeオブジェクトのメソッドを呼び出す

## エラー処理

すべてのエラーは適切なスタックレベルで伝播されます：
- フックエラー: レベル2
- Describe作成エラー: レベル2
- メソッド呼び出しエラー: レベル2

## セキュリティ考慮事項

1. **直接状態アクセスなし**: すべての状態は内部的で公開されない
2. **制御されたメソッドフロー**: ステートマシンが無効なシーケンスを防止
3. **型検証**: すべての入力が処理前に検証される
4. **エラー分離**: 適切なスタックレベルでエラーをスロー

## 使用例

```lua
local measure = require('measure')

-- フックを定義
function measure.before_all()
    return { start_time = os.time() }
end

-- ベンチマークを定義
measure.describe('Example Benchmark')
    .options({ warmup = 10 })
    .run(function()
        -- ベンチマークコード
    end)
```

## ファイルスコープ

各ベンチマークファイルは独自の`RegistrySpec`インスタンスを取得し、一貫したAPI動作を維持しながらファイル間の完全な分離を保証します。
