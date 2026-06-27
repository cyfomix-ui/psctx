# PSCtx - プロジェクト別 PowerShell コンテキスト

**PSCtx** は、PowerShell の状態をプロジェクトフォルダごとに切り替えるための軽量な ps1 ツールです。

開発フォルダごとに、コマンド履歴、上下キーで呼び出される PSReadLine 履歴、環境変数、プロンプト表示を分離・切替します。また、`h` と `!<id>` による履歴再実行、行末 `&` による簡易バックグラウンド実行にも対応します。

英語名は **Project-local PowerShell Context** です。

---

## 機能

- プロジェクトごとの PowerShell 履歴分離
- 上下キーで出る PSReadLine 履歴のプロジェクト別切替
- `.psctx.json` によるプロジェクト別環境変数
- プロンプト先頭の状態マーク
  - グレーの `# `: PSCtx は読み込まれているが、現在フォルダは未登録
  - 白の `$ `: 現在フォルダは PSCtx 登録済みプロジェクト配下
- `h` による履歴表示
- `!5` / `! 5` による履歴再実行
- 行末 `&` による簡易バックグラウンド実行
- 管理者権限なしで導入可能

---

## バージョン確認

PowerShell 本体と PSCtx のバージョンは、次の短いコマンドで同時に確認できます。

```powershell
psx --v
```

表示例です。

```text
PowerShell 7.5.2 (Core)
PSCtx      0.8.2
Profile:   C:\Users\kazu\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
ToolPath:  D:\tools\PSCtx
```

同等のコマンドとして、以下も使えます。

```powershell
psctx /version
psctx -v
psctxv
```

`psx` は短縮用のコマンドです。現時点では `psctx` へ処理を渡す入口として使い、特に `psx --v` を「PowerShell/PSCtx 状態確認」の定番コマンドとして想定しています。

## 対象環境

| 項目 | 状態 |
| --- | --- |
| Windows PowerShell 5.1 | 対象 |
| PowerShell 7.x on Windows | 対象 |
| PSReadLine | 必須 |
| Windows Terminal | PSReadLine が使える場合は対象 |
| 管理者権限 | 不要 |
| Linux/macOS PowerShell | 主対象外 |

スクリプトは `#requires -version 5.1`、`$PROFILE`、PSReadLine、Windows 用 `.cmd` 補助ファイルを前提にしています。

---

## インストール

任意のフォルダに展開します。

例:

```powershell
D:\tools\PSCtx
```

そのフォルダで実行します。

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-PSCtx.ps1
. $PROFILE
```

以後、推奨コマンド名は `psctx` です。

```powershell
psctx
```

互換用に以下の別名も残しています。

```powershell
pph
psprojhist
```

---

## プロジェクト登録

指定フォルダを登録します。

```powershell
psctx D:\tools\WinPicker
```

現在のフォルダを登録します。

```powershell
psctx .
```

名前を指定して登録します。

```powershell
psctx D:\tools\WinPicker /name WinPicker
```

プロンプトにプロジェクト名も出す場合:

```powershell
psctx D:\tools\WinPicker /showname
```

行末 `&` 機能を無効にして登録する場合:

```powershell
psctx D:\tools\WinPicker /noamp
```

---

## 登録時に作られるもの

例として `D:\tools\WinPicker` を登録すると、次のような構成になります。

```text
D:\tools\WinPicker\
  .psctx.json
  .pslocal\
    PSReadLine\
      ConsoleHost_history.txt
      ConsoleHost_history_psctx_history.jsonl
```

さらに `.gitignore` に以下を追記します。

```gitignore
.pslocal/
```

`.pslocal/` は GitHub に上げないでください。履歴にはトークン、内部パス、サーバー名などの機微情報が含まれる可能性があります。

---

## `.psctx.json`

```json
{
  "Name": "WinPicker",
  "EnableAmpersandFork": true,
  "ShowProjectNameInPrompt": false,
  "Env": {
    "DOTNET_NOLOGO": "1",
    "DOTNET_CLI_TELEMETRY_OPTOUT": "1"
  }
}
```

`Env` に書いた環境変数は、そのプロジェクト配下にいる間だけ有効になります。プロジェクト外に出ると元の値へ戻します。

---

## プロンプト表示

未登録フォルダではグレーの `# ` が出ます。

```text
# 2026-06-27 09:30:00 [C:\Users\kazu] PS>
```

登録済みフォルダでは白の `$ ` が出ます。

```text
$ 2026-06-27 09:33:36 [D:\tools\WinPicker] PS>
```

---

## 履歴表示と再実行

```powershell
h
```

例:

```text
   Id  DateTime             CommandLine
   --  --------             -----------
    1  2026-06-27 09:33:36  ll
    2  2026-06-27 09:33:38  dir
    3  2026-06-27 09:33:44  cd D:\tools\WinPicker\
```

再実行:

```powershell
!3
```

または:

```powershell
! 3
```

明示的に実行する場合:

```powershell
Invoke-PSCtxHistoryCommand -Id 3
```

PSCtx は PowerShell 標準の `h` エイリアスを上書きします。これは `h` に表示される Id と `!<id>` で実行される Id を一致させるためです。

---

## 行末 `&` の簡易バックグラウンド実行

`.psctx.json` で `"EnableAmpersandFork": true` の場合、行末 `&` を PowerShell ジョブとして実行します。

```powershell
notepad .\.psctx.json &
dotnet build &
```

ジョブ確認:

```powershell
bgjobs
```

出力確認:

```powershell
bgout 1
```

停止・削除:

```powershell
bgkill 1
```

これは Unix の fork と完全に同じものではありません。PowerShell の `Start-Job` を使った簡易ショートカットです。

---

## 解除

プロジェクトの PSCtx 設定を解除します。

```powershell
psctx /uninst D:\tools\WinPicker
```

`.psctx.json` は削除せず、リネームします。

履歴ごと削除する場合:

```powershell
psctx /uninst D:\tools\WinPicker /purge
```

---

## PSCtx 自体のアンインストール

PSCtx の展開フォルダで実行します。

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Uninstall-PSCtx.ps1
```

または:

```powershell
psctx /removeprofile
```

その後、新しい PowerShell を開いてください。

---

## 注意

- `.pslocal/` はコミットしないでください。
- `.psctx.json` は PSCtx が JSON として読み込むデータファイルですが、その内容はそのプロジェクト配下のシェル環境に反映されます。
- 信頼できるプロジェクトフォルダだけを登録してください。
- インストール時に `$PROFILE` とユーザー `PATH` を変更します。
- 変更前の `$PROFILE` はバックアップされます。

---

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照してください。

## 実行ポリシーと .psctx.json

PSCtx 0.8.2 以降は、プロジェクト設定を `.psctx.json` に
保存します。以前の `.psctx.ps1` は実行しないため、
`AllSigned` などの実行ポリシーでも、プロジェクト移動時に
未署名スクリプトとしてブロックされにくくなります。

既存の `.psctx.ps1` があるフォルダでも、再度 `psctx .` を
実行すると `.psctx.json` が作成され、以後はそちらが優先
されます。
