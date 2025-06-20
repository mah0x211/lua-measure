# Measureモジュール設計書

バージョン: 0.2.0  
日付: 2025-06-20

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
local measure = setmetatable({}, {
    __newindex = hook_setter,      -- フック割り当てを処理
    __index = allow_new_describe   -- 'describe'のプロパティアクセスを処理
})
```

### 2. 状態管理

モジュールはセキュリティとシンプルさのため最小限の内部状態を維持します。ファイル固有のレジストリ仕様は`get_spec()`関数を通じて動的に取得され、永続的な状態変数の必要性を排除します。

### 3. フック管理

モジュールは、直接割り当てで設定される4つのライフサイクルフックをサポートします：

- `before_all`: すべてのベンチマークの前に一度呼び出される
- `before_each`: 各ベンチマークの前に呼び出される
- `after_each`: 各ベンチマークの後に呼び出される
- `after_all`: すべてのベンチマークの後に一度呼び出される

## メタテーブル実装

### フックセッター (__newindex)

```lua
local function hook_setter(_, key, fn)
    local spec = get_spec()
    local ok, err = spec:set_hook(key, fn)
    if not ok then
        error(err, 2)
    end
end
```

動的に取得されたレジストリ仕様を通じてライフサイクルフックを検証し登録します。

### メソッド呼び出し器 (__call)

measureオブジェクトには`__call`メタメソッドがありません。`measure()`を直接呼び出そうとするとエラーになります。`describe`関数は`__index`メタメソッドを通じてアクセスされます。

### メソッド解決器 (__index)

```lua
local function allow_new_describe(self, key)
    if type(key) ~= 'string' or key ~= 'describe' then
        error(format('Attempt to access measure as a table: %q', tostring(key)), 2)
    end
    return new_describe
end
```

この関数は厳格なアクセス制御を実行します：
- `describe`キーへのアクセスのみを許可
- `new_describe`関数を直接返す
- measureオブジェクトへのその他のテーブルライクアクセスを防止

### Describeプロキシ実装

`new_describe`関数はメソッドチェーンを実装するプロキシオブジェクトを返します：

```lua
local function new_describe_proxy(name, desc)
    return setmetatable({}, {
        __tostring = function()
            return format('measure.describe %q', name)
        end,
        __index = function(self, method)
            if type(method) ~= 'string' then
                error(format('Attempt to access measure.describe as a table: %q',
                          tostring(method)), 2)
            end
            
            return function(...)
                local fn = desc[method]
                if type(fn) ~= 'function' then
                    error(format('%s has no method %q', tostring(self), method), 2)
                end
                
                local ok, err = fn(desc, ...)
                if not ok then
                    error(format('%s(): %s', method, err), 2)
                end
                
                return self
            end
        end,
    })
end
```

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

### 3. API使用フロー

1. `measure.describe`へのアクセスが`new_describe`関数を返す
2. `new_describe(name)`の呼び出しがdescribeオブジェクトを作成しプロキシを返す
3. プロキシメソッドへのアクセスが即座に呼び出し可能な関数を返す
4. メソッド呼び出しがチェーン用にプロキシを返す

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
2. **参照保存の防止**: セキュリティチェックを回避する参照保存を防ぐ設計
3. **型検証**: すべての入力が処理前に検証される
4. **エラー分離**: 適切なスタックレベルでエラーをスロー
5. **Describeチェーンの防止**: プロキシパターンが`measure.describe(...).describe(...)`呼び出しを防止：
   - `measure.describe`プロキシインスタンスには`describe`メソッドが存在しない
   - `describe`呼び出しをチェーンしようとすると"has no method"エラーが発生

## 使用例

```lua
local measure = require('measure')

-- フックを定義
measure.before_all = function()
    return { start_time = os.time() }
end

-- ベンチマークを定義（正しい使用法）
measure.describe('Example Benchmark')
    .options({ warmup = 10 })
    .run(function()
        -- ベンチマークコード
    end)

-- 無効な使用法（エラーになる）
-- measure.describe('Test').describe('Another')  -- Error: has no method "describe"
-- measure()  -- Error: Attempt to call measure
```

## ファイルスコープ

各ベンチマークファイルは独自の`RegistrySpec`インスタンスを取得し、一貫したAPI動作を維持しながらファイル間の完全な分離を保証します。
