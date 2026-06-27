# PSCtx - プロジェクト別 PowerShell コンテキスト

PSCtx は、PowerShell の動作をプロジェクトフォルダごとに
切り替えるための軽量ツールです。

履歴、上下キーで出る履歴、環境変数、プロンプト表示、
小さなシェル補助機能を、現在のフォルダに応じて切り替えます。

英語では次のように説明できます。

> Project-local PowerShell Context

日本語では、次のような位置づけです。

> フォルダ別 PowerShell 履歴・環境切替

## 主な機能

- プロジェクトごとに PSReadLine 履歴を分離
- 上下キーで出る履歴もプロジェクトごとに分離
- `.psctx.ps1` から環境変数を自動適用
- 管理対象かどうかをプロンプト先頭に表示
- `h`、`!5`、`cmd &` などの簡易操作を追加
- `psx --v` で PowerShell と PSCtx のバージョンを表示
- Windows PowerShell 5.1 と PowerShell 7.x に対応

## プロンプト表示

PSCtx が読み込まれていて、現在フォルダが未登録の場合、
プロンプトの先頭にグレーの `# ` を表示します。

```text
# 2026-06-27 10:21:15 [C:\Users\YourName] PS>
```

現在フォルダが登録済みプロジェクト配下の場合、
プロンプトの先頭に白の `$ ` を表示します。

```text
$ 2026-06-27 10:21:15 [D:\tools\SampleProject] PS>
```

`# ` は「PSCtx は起動しているが、通常状態」、
`$ ` は「プロジェクト設定が有効」という意味です。

## インストール

PSCtx 一式を任意の固定フォルダに展開します。

例:

```text
D:\tools\PowerShellContext\
```

そのフォルダで次を実行します。

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-PSCtx.ps1
. $PROFILE
```

これにより、現在の PowerShell プロファイルに PSCtx が
読み込まれるようになります。

PowerShell 5.1 と PowerShell 7.x では `$PROFILE` の場所が
異なります。両方で使う場合は、それぞれの PowerShell で
一度ずつインストールしてください。

## プロジェクト登録

対象フォルダを登録するには次を実行します。

```powershell
psctx D:\tools\SampleProject
```

現在のフォルダを登録する場合は次です。

```powershell
psctx .
```

登録すると、対象フォルダに次が作成されます。

```text
.psctx.ps1
.pslocal\PSReadLine\
```

`.psctx.ps1` はプロジェクト用設定です。
`.pslocal` は履歴などのローカルデータです。

## プロジェクト解除

登録を解除するには次を実行します。

```powershell
psctx /uninst D:\tools\SampleProject
```

現在フォルダを解除する場合は次です。

```powershell
psctx /uninst .
```

標準では履歴フォルダは残します。
履歴も消す場合は `/purge` を付けます。

```powershell
psctx /uninst D:\tools\SampleProject /purge
```

## 履歴操作

`h` で PSCtx 管理下の履歴を番号付きで表示します。

```powershell
h
```

表示例:

```text
   Id  DateTime             CommandLine
   --  --------             -----------
    1  2026-06-27 09:33:36  ll
    2  2026-06-27 09:33:38  dir
    3  2026-06-27 09:33:44  cd D:\tools\SampleProject\
```

番号を指定して履歴を実行できます。

```powershell
!5
```

または:

```powershell
! 5
```

明示的な関数形式も使えます。

```powershell
Invoke-PSCtxHistoryCommand -Id 5
```

## `&` によるバックグラウンド実行

管理対象プロジェクト内では、行末の `&` を検出し、
PowerShell ジョブとして実行できます。

```powershell
notepad .\.psctx.ps1 &
dotnet build &
```

これは Unix の fork そのものではありません。
PowerShell の `Start-Job` 相当へ変換する補助機能です。

ジョブ操作には次を使えます。

```powershell
bgjobs
bgout 1
bgkill 1
```

この機能を使わないプロジェクトは、登録時に `/noamp` を
指定します。

```powershell
psctx D:\tools\SampleProject /noamp
```

## バージョン確認

PowerShell と PSCtx の両方のバージョンを表示します。

```powershell
psx --v
```

表示例:

```text
PowerShell 7.6.3 (Core)
PSCtx      0.7.1
Profile:   C:\Users\YourName\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
ToolPath:  D:\tools\PowerShellContext
```

次のコマンドでも PSCtx バージョンを確認できます。

```powershell
psctx /version
psctx -v
psctxv
```

## 更新方法

PSCtx のバージョンアップ時に、各プロジェクトで再度
`psctx` を実行する必要はありません。

通常の更新手順は次の通りです。

```text
1. 新しい PSCtx ファイルを既存のツールフォルダへ上書き展開
2. そのフォルダで Install-PSCtx.ps1 を一度だけ実行
3. . $PROFILE を実行、または PowerShell を開き直す
```

既存プロジェクトの `.psctx.ps1` や `.pslocal` はそのまま
使えます。

新しい設定項目が増えた場合でも、古い `.psctx.ps1` は
基本的にそのまま動きます。新機能を使いたい場合だけ、
対象プロジェクトの `.psctx.ps1` を編集してください。

## PowerShell 5.1 について

PSCtx は PowerShell 5.1 以上を対象にしています。

PowerShell 7.x のプロファイル例:

```text
C:\Users\YourName\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Windows PowerShell 5.1 のプロファイル例:

```text
C:\Users\YourName\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

PSReadLine が古い場合は、次で更新できます。

```powershell
Install-Module PSReadLine -Scope CurrentUser -Force
```

## よくある質問

### プロジェクトに入ったあと、設定は維持されますか？

はい。登録済みプロジェクトのルート、またはその配下の
サブフォルダにいる間は、そのプロジェクトの設定が維持されます。

別の登録済みプロジェクトへ移動すると、そちらの設定へ
切り替わります。

未登録フォルダへ移動すると、通常状態へ戻ります。

### バージョンアップのたびに各フォルダで再登録が必要ですか？

不要です。

PSCtx 本体は PowerShell の `$PROFILE` にインストールされます。
プロジェクト登録は `.psctx.ps1` を作る処理なので、
一度登録済みなら通常はそのまま使えます。

本体更新時は、PSCtx ツールフォルダで `Install-PSCtx.ps1` を
一度実行すれば十分です。

### 未登録フォルダで `# ` が出るのはなぜですか？

PSCtx が読み込まれていることを示すためです。

`# ` は「PSCtx は起動中だが、このフォルダは管理対象外」
という状態を表します。

### 登録済みフォルダで `$ ` が出るのはなぜですか？

`$ ` は「このフォルダでは PSCtx のプロジェクト設定が有効」
という意味です。

履歴、上下キー履歴、環境変数、補助コマンドが、現在の
プロジェクト用に切り替わっています。

### `h` の ID と `!5` の ID は同じですか？

はい。現在の PSCtx では一致します。

PowerShell 標準の `h` は `Get-History` のエイリアスですが、
PSCtx では履歴再実行と一致するように、独自の `h` へ
上書きしています。

### `!5` と `! 5` の両方が使えますか？

はい。どちらも使えます。

```powershell
!5
! 5
```

内部的には、PSReadLine の Enter キー処理で検出し、
履歴実行関数へ渡しています。

### 履歴の日時はどこから取っていますか？

PSReadLine 標準の履歴ファイルには日時がありません。

PSCtx は追加の JSONL ファイルに日時を記録します。
そのため、日時表示は PSCtx 導入後の履歴から有効です。

古い履歴は、日時が表示できない場合があります。

### `cmd &` は Bash の fork と同じですか？

同じではありません。

PowerShell には Unix シェルと同じ fork 構文はありません。
PSCtx では、行末 `&` を PowerShell ジョブへ変換することで、
似た使い勝手を提供します。

### `psx --v` でエラーが出たことがあるのはなぜですか？

PowerShell は変数名の大文字小文字を区別しません。

以前の版では内部変数 `$psEdition` が、組み込みの読み取り専用
変数 `$PSEdition` と衝突しました。0.7.1 で修正済みです。

### PowerShell 5.1 でも使えますか？

基本的に使えます。

ただし PowerShell 5.1 と 7.x では `$PROFILE` の場所が別です。
両方で使う場合は、両方の PowerShell でインストールしてください。

また、古い PSReadLine では一部機能が動かない可能性があります。
その場合は PSReadLine を更新してください。

### `.pslocal` は GitHub に上げてもいいですか？

上げないでください。

履歴には、パス、サーバー名、トークン、認証情報に近い文字列が
含まれる可能性があります。

`.gitignore` には次を入れてください。

```gitignore
.pslocal/
```

## セキュリティ上の注意

`.psctx.ps1` は PowerShell スクリプトです。
信頼できるフォルダのものだけを使ってください。

`.pslocal` には履歴が入るため、公開リポジトリへ含めないで
ください。

## ライセンス

MIT License。
