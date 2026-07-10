# PSX - Project-local PowerShell Context

**PSX** is a lightweight PowerShell script set that switches your shell context per project folder.

It separates PSReadLine history by project, reloads the in-memory up/down-key history when you move between registered folders, applies project-local environment variables, adds prompt markers, and provides small Bash-like conveniences such as `h`, `!<id>`, and trailing `&` background execution.

日本語では **「プロジェクト別 PowerShell コンテキスト」**、または **「フォルダ別 PowerShell 履歴・環境切替」** です。

---

## Features

- Per-project PowerShell command history
- Per-project up/down-key history isolation
- Project-local environment variables through `.psctx.json`
- Prompt marker showing whether the current folder is managed
  - `# ` in gray: PSX is loaded, but the current folder is not registered
  - `$ ` in white: the current folder is inside a registered PSX project
- Bash-like history display and replay
  - `h`
  - `!5`
  - `! 5`
- Optional trailing `&` background execution per project
  - `notepad .\.psctx.json &`
  - `dotnet build &`
- One-command project registration and unregistration
- Does not require administrator privileges

---

## Target environment

PSX is designed for Windows development environments.

| Item | Status |
| --- | --- |
| Windows PowerShell 5.1 | Targeted |
| PowerShell 7.x on Windows | Targeted |
| PSReadLine | Required |
| Windows Terminal | Supported if PSReadLine is available |
| Administrator privileges | Not required |
| Linux/macOS PowerShell | Not the primary target |

The scripts use `#requires -version 5.1`, `$PROFILE`, PSReadLine, and Windows-style helper `.cmd` launchers.

---

## Installation

Extract this repository or ZIP file to any folder, for example:

```powershell
D:\tools\PSX
```

Then run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-PSX.ps1
. $PROFILE
```

The installer updates your PowerShell profile and adds the tool folder to the user `PATH`.

After installation, the recommended command is:

```powershell
psx
```

Backward-compatible aliases are also available:

```powershell
psx
psx
```

`psx` is the recommended name.

---

## Register a project folder

Register a project folder:

```powershell
psx D:\tools\WinPicker
```

Register the current folder:

```powershell
psx .
```

Register with a custom project name:

```powershell
psx D:\tools\WinPicker /name WinPicker
```

Register and show the project name in the prompt:

```powershell
psx D:\tools\WinPicker /showname
```

Register without trailing `&` background support:

```powershell
psx D:\tools\WinPicker /noamp
```

---

## What registration creates

For a registered folder such as `D:\tools\WinPicker`, PSX creates:

```text
D:\tools\WinPicker\
  .psctx.json
  .pslocal\
    PSReadLine\
      ConsoleHost_history.txt
      ConsoleHost_history_psx_history.jsonl
```

It also adds this entry to the project `.gitignore`:

```gitignore
.pslocal/
```

Do not commit `.pslocal/`. Command history may contain tokens, internal paths, server names, or other sensitive information.

---

## Project config: `.psctx.json`

A project config file looks like this:

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

Environment variables in `Env` are applied only while the shell is inside that project folder or its subfolders.

When you leave the registered folder, PSX restores the previous environment values and returns to the normal PowerShell history file.

---

## Prompt markers

When PSX is loaded but the current folder is not registered:

```text
# 2026-06-27 09:30:00 [C:\Users\kazu] PS>
```

When the current folder is inside a registered project:

```text
$ 2026-06-27 09:33:36 [D:\tools\WinPicker] PS>
```

The mark is intentionally small. It only tells you whether the current folder is under PSX control.

---

## Per-project history

Inside a registered project, command history is saved to:

```text
.pslocal\PSReadLine\ConsoleHost_history.txt
```

The up/down-key history is also reloaded when you enter or leave a registered project. This avoids mixing commands from unrelated projects.

For example:

```text
D:\tools\WinPicker\
  uses WinPicker history

D:\tools\DropMp4\
  uses DropMp4 history

C:\Users\kazu\
  uses normal PowerShell history
```

---

## `h` and history replay

Show recent PSX/PSReadLine history:

```powershell
h
```

Example output:

```text
   Id  DateTime             CommandLine
   --  --------             -----------
    1  2026-06-27 09:33:36  ll
    2  2026-06-27 09:33:38  dir
    3  2026-06-27 09:33:44  cd D:\tools\WinPicker\
```

Replay a command:

```powershell
!3
```

or:

```powershell
! 3
```

Equivalent explicit command:

```powershell
Invoke-PSXHistoryCommand -Id 3
```

Important: PSX overrides PowerShell's default `h` alias so that `h` and `!<id>` use the same history numbering.

---

## Trailing `&` background execution

If `"EnableAmpersandFork": true` in `.psctx.json`, PSX treats a trailing `&` as a simple background job request.

```powershell
notepad .\.psctx.json &
dotnet build &
```

Check jobs:

```powershell
bgjobs
```

Read job output:

```powershell
bgout 1
```

Stop and remove a job:

```powershell
bgkill 1
```

This is not a full Unix process model. Internally it uses PowerShell jobs. It is intended as a convenient project-local shortcut, not as a complete Bash emulation layer.

---

## Unregister a project folder

Disable PSX for a project:

```powershell
psx /uninst D:\tools\WinPicker
```

This renames `.psctx.json` instead of deleting it.

Disable and remove `.pslocal/` history files:

```powershell
psx /uninst D:\tools\WinPicker /purge
```

---

## Remove PSX from your PowerShell profile

From the PSX tool folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Uninstall-PSX.ps1
```

Or:

```powershell
psx /removeprofile
```

Then open a new PowerShell window.

---

## Security notes

- `.pslocal/` is intentionally local and should not be committed.
- Shell history may contain secrets or private paths.
- `.psctx.json` is a PSX data file read as JSON, but its values still affect your shell environment inside that project.
- Only register project folders you trust.
- Installation modifies `$PROFILE` and the user `PATH`.
- The profile file is backed up before being modified.

---

## License

MIT License. See [LICENSE](LICENSE).

---

# 日本語説明

## PSX とは

**PSX** は、PowerShell の状態をプロジェクトフォルダごとに切り替えるための軽量な ps1 ツールです。

主な目的は、開発フォルダごとに以下を分離・切替することです。

- コマンド履歴
- 上下キーで呼び出される PSReadLine 履歴
- 環境変数
- プロンプト表示
- 簡易的な Bash 風操作

PowerShell を Bash そのものにするツールではありません。Windows 上で複数の開発フォルダを行き来するときに、履歴や環境が混ざる問題を軽く解消するためのものです。

## インストール

任意のフォルダに展開して実行します。

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-PSX.ps1
. $PROFILE
```

## プロジェクト登録

```powershell
psx D:\tools\WinPicker
```

現在のフォルダを登録する場合:

```powershell
psx .
```

解除する場合:

```powershell
psx /uninst D:\tools\WinPicker
```

履歴フォルダも削除する場合:

```powershell
psx /uninst D:\tools\WinPicker /purge
```

## プロンプト表示

未登録フォルダではグレーの `# ` が表示されます。

```text
# 2026-06-27 09:30:00 [C:\Users\kazu] PS>
```

登録済みフォルダでは白の `$ ` が表示されます。

```text
$ 2026-06-27 09:33:36 [D:\tools\WinPicker] PS>
```

## 履歴表示と再実行

```powershell
h
```

```powershell
!5
! 5
```

`h` で表示した Id と、`!<id>` で実行する Id は一致します。

## GitHub に上げないもの

`.pslocal/` は履歴保存用のローカルフォルダです。GitHub には上げないでください。

```gitignore
.pslocal/
```

履歴にはトークン、パス、サーバー名、作業中の内部情報などが入る可能性があります。

## Execution policy and .psctx.json

PSX 0.8.2 or later stores project configuration in
`.psctx.json`. The runtime no longer executes `.psctx.ps1`
when entering a project folder, which avoids unsigned-script
errors under stricter execution policies such as `AllSigned`.

For an existing project that still has `.psctx.ps1`, run
`psx .` once in the project root to create `.psctx.json`.
The JSON file is preferred from then on.
