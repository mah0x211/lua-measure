# Measure Loadfiles モジュール設計文書

バージョン: 0.1.0  
日付: 2025-06-21

## 概要

Measure Loadfiles モジュールは、ベンチマークファイルの動的読み込みと実行を提供します。ディレクトリをスキャンまたは個別ファイルを処理し、安全に実行して、測定システム用の登録されたベンチマーク仕様を収集します。

## 目的

このモジュールは、ベンチマーク発見と読み込みのエントリーポイントとして機能します：
- パターンマッチング（`*_bench.lua`）を使用してベンチマークファイルを発見
- Luaベンチマークファイルを安全に読み込みと実行
- 様々なエラー条件を適切に処理
- レジストリシステムと連携してベンチマーク仕様を収集
- 単一ファイルとディレクトリベースの読み込みの両方に統一されたインターフェースを提供

## モジュール構造

```lua
-- モジュール: measure.loadfiles
local type = type
local find = string.find
local sub = string.sub
local format = string.format
local pcall = pcall
local popen = io.popen
local loadfile = loadfile
local pairs = pairs
local realpath = require('measure.realpath')
local getfiletype = require('measure.getfiletype')
local registry = require('measure.registry')

-- 安全なファイル評価のための内部関数
local function evalfile(pathname)
-- メインの公開関数
local function loadfiles(pathname)
-- loadfiles関数を返す
return loadfiles
```

## コア構成要素

### 1. ファイルパターンマッチング

ベンチマークファイルは`*_bench.lua`の命名規則に従う必要があります：

```lua
if find(entry, '_bench.lua$') then
    pathnames[#pathnames + 1] = pathname .. '/' .. entry
end
```

### 2. パスタイプ検出

単一ファイルとディレクトリの両方をサポート：

```lua
local t = getfiletype(pathname)
if t == 'file' then
    pathnames[1] = pathname
elseif t == 'directory' then
    -- ディレクトリ処理
else
    error(format('pathname %s must point to a file or directory', pathname), 2)
end
```

### 3. 安全なファイル実行

保護された評価を使用してエラーを適切に処理：

```lua
local function evalfile(pathname)
    local f, err = loadfile(pathname)
    if not f then
        return false, err
    end
    
    local ok
    ok, err = pcall(f)
    if not ok then
        return false, err
    end
    return true
end
```

## 主要関数

### evalfile(pathname)

包括的なエラーハンドリングでLuaファイルを安全に評価：

```lua
--- Luaファイルを評価し、エラーをキャッチする
--- @param pathname string 評価するLuaファイルのパス名
--- @return boolean ok ファイルが正常に評価された場合はtrue、そうでなければfalse
--- @return string|nil err 評価が失敗した場合のエラーメッセージ、そうでなければnil
local function evalfile(pathname)
    -- ステップ1: ファイル読み込み（構文検証）
    local f, err = loadfile(pathname)
    if not f then
        return false, err  -- 構文エラーまたはファイルが見つからない
    end

    -- ステップ2: ファイル実行（実行時検証）
    local ok
    ok, err = pcall(f)
    if not ok then
        return false, err  -- 実行時エラー
    end
    return true
end
```

**エラーハンドリング:**
- **構文エラー**: `loadfile()`でキャッチ（括弧の不足、無効な構文）
- **実行時エラー**: `pcall()`でキャッチ（型エラー、nilアクセス、呼び出しエラー）

### loadfiles(pathname)

ベンチマークファイルを発見、読み込み、処理するメイン関数：

```lua
--- 指定されたパス名からベンチマークファイルを読み込む
--- @param pathname string ベンチマークファイルを読み込むパス名
--- @return measure.spec[] specs 読み込まれたベンチマーク仕様を含むテーブル
--- @throws error パス名が文字列でない場合
--- @throws error パス名がファイルでもディレクトリでもない場合
local function loadfiles(pathname)
    -- 1. 入力検証
    if type(pathname) ~= 'string' then
        error('pathname must be a string', 2)
    end

    -- 2. パスタイプを判定してファイルを収集
    local pathnames = {}
    local t = getfiletype(pathname)
    
    -- 3. 発見された各ファイルを処理
    local files = {}
    for _, filename in ipairs(pathnames) do
        filename = realpath(filename)
        
        -- 4. エラーログ付きの安全実行
        print('loading ' .. filename)
        local ok, err = evalfile(filename)
        if not ok then
            print(format('failed to load %q: %s', filename, err), 2)
        end
        
        -- 5. 登録された仕様を収集
        local specs = registry.get()
        registry.clear()
        -- 仕様を処理...
    end
    
    return files
end
```

## レジストリ連携

### 仕様収集プロセス

1. **ファイル実行**: ベンチマークファイルが実行され、仕様を登録
2. **仕様収集**: レジストリから登録されたすべての仕様を取得
3. **レジストリクリア**: 次のファイルのためにレジストリをクリーン
4. **結果フィルタ**: キーサフィックスにより仕様を現在のファイルにマッチ

```lua
local specs = registry.get()
registry.clear()
for k, spec in pairs(specs) do
    -- 仕様が現在のファイルに属することを確認
    if sub(k, -#filename) == filename then
        files[#files + 1] = {
            filename = filename,
            spec = spec,
        }
    else
        print(format('ignore an invalid entry %s for %s', k, filename))
    end
end
```

## エラーハンドリングパターン

### 1. 構文エラー（loadfile失敗）
```lua
-- 例: syntax_error_bench.lua
local measure = require('measure')
local bench = measure.describe("syntax_error"
-- 閉じ括弧が不足
```
**結果**: `loadfile()`がnilとエラーメッセージを返す

### 2. 実行時エラー（pcall失敗）
```lua
-- 例: type_error_bench.lua  
local function throw_error()
    local a = 1 + {}  -- 型エラー
end
throw_error()
```
**結果**: `pcall(f)`がfalseとエラーメッセージを返す

### 3. ファイルシステムエラー
```lua
-- 存在しないパス
error(format('pathname %s must point to a file or directory', pathname), 2)

-- ディレクトリリスト失敗
error(format('failed to list directory %s: %s', pathname, err), 2)
```

## 出力構造

### 戻り値形式

```lua
{
    {
        filename = "/absolute/path/to/benchmark_bench.lua",
        spec = measure.spec_object
    },
    {
        filename = "/absolute/path/to/another_bench.lua", 
        spec = measure.spec_object
    }
}
```

### ログ出力

実行中、モジュールは情報出力を生成：

```
loading /path/to/benchmark_bench.lua
loading /path/to/another_bench.lua
failed to load "/path/to/broken_bench.lua": syntax error message
File loaded but no benchmarks defined
```

## 統合ポイント

### 依存関係

- **`measure.realpath`**: ファイルパスを絶対パスに正規化
- **`measure.getfiletype`**: パスがファイル、ディレクトリ、または無効かを判定
- **`measure.registry`**: ベンチマーク仕様を収集・管理

### 他モジュールによる使用

```lua
local loadfiles = require('measure.loadfiles')

-- 単一ファイル読み込み
local specs = loadfiles('path/to/benchmark_bench.lua')

-- ディレクトリ読み込み
local specs = loadfiles('path/to/benchmarks/')

-- 結果処理
for _, entry in ipairs(specs) do
    print("読み込み完了:", entry.filename)
    -- entry.specを使用してベンチマークを実行
end
```

## ディレクトリ処理

### ファイル発見

```lua
-- ディレクトリリストにシステムlsコマンドを使用
local ls, err = popen('ls -1 ' .. pathname)
if not ls then
    error(format('failed to list directory %s: %s', pathname, err), 2)
end

-- ベンチマークファイルをフィルタ
for entry in ls:lines() do
    if find(entry, '_bench.lua$') then
        pathnames[#pathnames + 1] = pathname .. '/' .. entry
    end
end
```

### パターンマッチングルール

- **含める**: `_bench.lua`で終わるファイル
- **除外**: その他すべてのファイル（`.txt`、`.md`、`_bench`サフィックスなしの`.lua`）

```
✓ example_bench.lua      (含まれる)
✓ performance_bench.lua  (含まれる)  
✗ helper.lua             (除外)
✗ readme.md              (除外)
✗ bench.lua              (除外 - _bench.luaで終わらない)
```

## セキュリティ考慮事項

### 1. 安全な実行
- `pcall()`を使用してユーザーコードからのクラッシュを防止
- ファイル実行エラーをシステム障害から分離
- 個別ファイルが失敗しても他のファイルの処理を継続

### 2. 入力検証
- pathname パラメータの型を検証
- 処理前にファイル/ディレクトリの存在を確認
- 無効なファイルタイプを適切に処理

### 3. エラー分離
- 個別ファイルの失敗がバッチ処理を停止しない
- デバッグ用の明確なエラーメッセージ
- ファイル間の汚染を防ぐためにレジストリをクリア

## 実装例

### 単一ファイル読み込み
```lua
local loadfiles = require('measure.loadfiles')

-- 単一ベンチマークファイルを読み込み
local specs = loadfiles('benchmarks/string_bench.lua')

for _, entry in ipairs(specs) do
    print("読み込み完了:", entry.filename)
    -- entry.specにベンチマーク仕様が含まれる
end
```

### ディレクトリ読み込み  
```lua
local loadfiles = require('measure.loadfiles')

-- ディレクトリからすべてのベンチマークファイルを読み込み
local specs = loadfiles('benchmarks/')

print(string.format("%d個のベンチマークファイルを読み込み", #specs))

for _, entry in ipairs(specs) do
    print("処理中:", entry.filename)
    -- entry.specを使用してベンチマークを実行
end
```

### エラーハンドリング
```lua
local loadfiles = require('measure.loadfiles')

-- エラーハンドリング付きで読み込み試行
local ok, result = pcall(loadfiles, 'invalid/path')
if not ok then
    print("ベンチマーク読み込み失敗:", result)
else
    print(string.format("%d個のベンチマークを正常に読み込み", #result))
end
```

## ベストプラクティス

### 1. ファイル構成
- ベンチマークファイルを専用ディレクトリに配置
- `_bench.lua`サフィックス付きの分かりやすい名前を使用
- 関連するベンチマークをサブディレクトリにグループ化

### 2. エラー回復
- 失敗したファイルの読み込み出力を監視
- ベンチマーク実行前に構文エラーを修正
- バッチ処理前に個別ファイルをテスト

### 3. パフォーマンス考慮事項
- 大きなディレクトリは処理に時間がかかる可能性
- ベンチマークを小さなグループに整理することを検討
- 多数の大きなベンチマークファイルでメモリ使用量を監視