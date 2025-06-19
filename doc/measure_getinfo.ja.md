# Measure Getinfo モジュール設計書

バージョン: 0.2.0  
日付: 2025-06-20

## 概要

Measure Getinfo モジュールは、Lua のソースおよびデバッグ情報への構造化されたアクセスを提供します。ネイティブの `debug.getinfo` 関数と比較して、簡素化され、焦点を絞った API を提供し、自動的なソースコード抽出により特定の情報フィールドを取得できます。

## 目的

このモジュールは、以下の機能を提供するデバッグユーティリティとして機能します：
- ソースおよびデバッグ情報への構造化されたアクセスを提供
- パス名解析を伴うファイル情報の抽出とフォーマット
- 利用可能な場合はファイルから直接ソースコードを読み取り（Lua 関数のみ）
- 最も一般的に使用されるデバッグ情報フィールドに焦点を当てる

## モジュール構造

```lua
-- Module: measure.getinfo
local getinfo = require('measure.getinfo')

-- モジュールは単一の関数をエクスポート
return getinfo
```

## API 関数

### getinfo(...)

指定されたフィールドに基づいて構造化されたソースおよびデバッグ情報を取得します。

```lua
--- 柔軟な API でソース情報を取得
--- @param ... any (level, field1, field2, ...) または (field1, field2, ...)
--- @return table result 構造化されたソース情報
function getinfo(...)
```

#### パラメータ

関数は2つの形式で引数を受け付けます：

1. **明示的なレベル指定**: `getinfo(level, field1, field2, ...)`
   - `level` (number): スタックレベル（0 は getinfo を呼び出している関数を指す）
   - `field1, field2, ...` (string): 取得するフィールド名

2. **レベルなし**: `getinfo(field1, field2, ...)`
   - `field1, field2, ...` (string): 取得するフィールド名
   - スタックレベルは getinfo の呼び出し元にデフォルト設定

#### 戻り値

リクエストされたフィールドを含むテーブルを返します。

#### エラー

以下の場合にエラーをスローします：
- 引数が提供されていない
- 無効な最初の引数型（数値または文字列でない）
- 負のレベル値
- 文字列でないフィールド引数
- 不明なフィールド名
- コールスタックを超えるスタックレベル

## 利用可能なフィールド

モジュールは正確に4つのフィールドをサポートします：

### source

行詳細とソースコードを含むソース情報。

```lua
{
    source = {
        line_head = 10,                 -- 関数定義の最初の行
        line_tail = 20,                 -- 関数定義の最後の行
        line_current = 15,              -- 現在実行中の行
        code = "function foo()\n...",   -- 実際のソースコード（Lua 関数のみ）
    }
}
```

ファイルからロードされた Lua 関数の場合、`code` フィールドには実際のソースコードが含まれます。C 関数や文字列からロードされたコードの場合、`code` は nil になることがあります。

### file

ファイル名とパス名を含むファイル情報。

```lua
{
    file = {
        source = "@example.lua",        -- debug.getinfoからの元のソース文字列
        name = "example.lua",           -- ファイル名のみ
        pathname = "/path/to/example.lua", -- 正規化されたフルパス名
        basedir = "/current/working/dir", -- 現在の作業ディレクトリ
    }
}
```

### name

関数名情報。

```lua
{
    name = {
        name = "foo",                   -- 関数名（nil の可能性あり）
        what = "global",                -- 呼び出し方法（global、local、method、field など）
    }
}
```

### function

関数オブジェクトとメタデータ。

```lua
{
    ["function"] = {
        type = "Lua",                   -- "Lua"、"C"、または "main"
        nups = 2,                       -- アップバリューの数
    }
}
```

## 使用例

### ソース情報の取得

```lua
local getinfo = require('measure.getinfo')

-- 現在のソース情報を取得
local info = getinfo(0, 'source')
print(info.source.line_current) -- 現在の行番号
if info.source.code then
    print(info.source.code)    -- 関数のソースコード
end
```

### ファイル情報の取得

```lua
-- ファイル情報を取得
local info = getinfo(0, 'file')
print(info.file.name)        -- "example.lua"
print(info.file.pathname)    -- "/path/to/example.lua"
print(info.file.basedir)     -- "/current/working/dir"
print(info.file.source)      -- "@example.lua"
```

### 複数フィールドの取得

```lua
-- ソース、名前、関数、ファイル情報を取得
local info = getinfo(0, 'source', 'name', 'function', 'file')

print(info.file.name)
print(info.name.what)
print(info['function'].type)  -- "Lua" または "C"
```

### 関数情報の取得

```lua
local function vararg_func(a, b, ...)
    local info = getinfo(0, 'function')
    print("アップバリュー:", info['function'].nups)
end

vararg_func(1, 2, 3, 4)
```

### デフォルトレベルの使用

```lua
local function get_my_info()
    -- レベルなしでは、呼び出し元がデフォルト
    return getinfo('source', 'file')
end

local info = get_my_info()
print(info.file.name)  -- get_my_info が呼ばれたファイルを表示
```

## measure.registry との統合

measure.registry モジュールは、どのファイルがベンチマーク仕様を作成しているかを識別するために getinfo を使用します：

```lua
local getinfo = require('measure.getinfo')

function registry.new()
    -- 呼び出し元からファイルパスを取得
    local info = getinfo(1, 'file')
    if not info or not info.file then
        error("Failed to identify caller")
    end
    
    local filename = info.file.pathname
    -- filename をレジストリキーとして使用...
end
```

## 実装に関する注意事項

1. **スタックレベルの調整**: 
   - 明示的なレベル指定: getinfo と debug.getinfo を考慮して 2 を追加
   - レベルなし: デフォルトでレベル 2 を使用（getinfo -> 呼び出し元）

2. **ソース読み取り**: ソースコードは、ファイルからロードされた Lua 関数でのみ利用可能です。C 関数や文字列からロードされたコードでは、`code` フィールドは設定されません。

3. **フィールド検証**: `source`、`name`、`function`、`file` のみが有効なフィールドです。その他のフィールド名はエラーを引き起こします。

4. **パフォーマンス**: 関数は必要なすべてのオプションで `debug.getinfo` を一度呼び出し、その後リクエストされたフィールドのみを抽出します。

## エラーハンドリング

モジュールは一般的な間違いに対して明確なエラーメッセージを提供します：

```lua
-- 引数なし
getinfo()
-- エラー: at least one argument is required

-- 無効な最初の引数型
getinfo(true, 'source')
-- エラー: first argument must be number or string, got boolean

-- 負のレベル
getinfo(-1, 'source')
-- エラー: level must be a non-negative integer, got -1

-- 無効なフィールド型
getinfo(0, 123)
-- エラー: field #2 must be a string, got number

-- 不明なフィールド
getinfo(0, 'unknown')
-- エラー: field #2 must be one of "file", "function", "name", "source", got "unknown"

-- スタックレベルが高すぎる
getinfo(100, 'source')
-- エラー: failed to get debug info for level 102
```

## バージョン履歴

- **0.2.0** (2025-06-20): `file` フィールドサポートを追加、`source` フィールドからファイル情報を除外するリファクタリング
- **0.1.0** (2025-06-18): 3つのフィールドサポートを持つ初期バージョン
