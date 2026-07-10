# PowerShellをちょっとBashライクにするps1

Windows で開発していると、PowerShell は十分に強力である一方、プロジェクトを行き来する運用では少しだけ不便に感じる場面があります。

たとえば、あるフォルダでは `dotnet build` や `git tag` を多用し、別のフォルダでは `python`、`flutter`、`ffmpeg`、`yt-dlp` などを使う。さらにプロジェクトごとに環境変数も少し変えたい。ところが、PowerShell の履歴は基本的にシェル全体で共有されるため、上矢印で過去コマンドを呼び出すと、別プロジェクトのコマンドが混ざります。

Unix 系のシェルに慣れていると、ディレクトリ単位で環境を切り替えたり、履歴を再利用したり、末尾に `&` を付けて処理を裏で走らせたりしたくなります。PowerShell にも同等の機能はありますが、日常の開発作業に合わせて小さくまとまったものが欲しくなりました。

そこで作ったのが **PSX** です。

正式には **Project-local PowerShell Context**。日本語では「プロジェクト別 PowerShell コンテキスト」と呼んでいます。

## 目的

PSX の目的は、PowerShell を Bash に置き換えることではありません。

目的はもっと限定的です。

- プロジェクトごとに履歴を分ける
- 上下キーで出る履歴もプロジェクトごとに分ける
- プロジェクトごとに環境変数を切り替える
- 現在のフォルダが PSX 管理下かどうかをプロンプトで確認できるようにする
- `h` と `!id` で履歴を再実行できるようにする
- 必要なフォルダだけ、行末 `&` で簡易バックグラウンド実行できるようにする

PowerShell の操作感を少しだけ Bash ライクに寄せるための ps1 です。

## 何が困っていたか

PowerShell の履歴は便利ですが、複数プロジェクトを横断していると混ざります。

たとえば、以下のような構成で作業しているとします。

```text
D:\tools\WinPicker
D:\tools\DropMp4
D:\tools\MvSuite
D:\tools\Ko-no-mi Tube
```

それぞれビルド手順も使うコマンドも違います。

WinPicker では `dotnet publish` を使う。DropMp4 ではログやメディア変換を確認する。MvSuite では別のビルドや ZIP 作成を行う。こうした作業が同じ履歴に混ざると、履歴検索や上矢印での再実行が少しずつ面倒になります。

単に履歴保存ファイルを変えるだけなら、PSReadLine の `HistorySavePath` でできます。しかし、それだけでは上下キーで表示されるメモリ上の履歴までは分離されません。

PSX では、プロジェクトを移動したタイミングで次の処理を行います。

1. そのプロジェクト専用の履歴ファイルへ切り替える
2. PSReadLine のメモリ履歴をクリアする
3. そのプロジェクトの履歴だけを読み直す
4. 必要な環境変数を適用する
5. プロンプトの状態表示を更新する

これにより、保存履歴だけでなく、上下キーで出る履歴もプロジェクト単位になります。

## インストール

PSX は PowerShell スクリプトです。管理者権限は不要です。

任意のフォルダに展開して、以下を実行します。

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-PSX.ps1
. $PROFILE
```

インストール時に `$PROFILE` へ管理ブロックを追加し、ツールフォルダをユーザー `PATH` に追加します。

以後は次のコマンドが使えます。

```powershell
psx
```

バージョン確認は短く `psx --v` としました。
PowerShell 自体のバージョンと PSX のバージョンを同時に出します。

```powershell
psx --v
```

```text
PowerShell 7.5.2 (Core)
PSX      0.8.2
Profile:   C:\Users\kazu\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
ToolPath:  D:\tools\PSX
```

PowerShell の種類やバージョンが変わると、PSReadLine の挙動やプロファイルの場所が変わることがあります。そのため、PSX 側のバージョンだけでなく、実際に起動している PowerShell のバージョンも同時に見えるようにしています。

## プロジェクトを登録する

たとえば `D:\tools\WinPicker` を登録する場合は、次のようにします。

```powershell
psx D:\tools\WinPicker
```

現在のフォルダを登録する場合は、これだけです。

```powershell
psx .
```

登録すると、対象フォルダに次のファイルとフォルダが作られます。

```text
.psctx.json
.pslocal\PSReadLine\
```

`.psctx.json` はプロジェクト設定ファイルです。

`.pslocal` は履歴保存用のローカルフォルダです。履歴には機微情報が含まれる可能性があるため、GitHub には上げない前提です。登録時に `.gitignore` へ次の行を自動で追加します。

```gitignore
.pslocal/
```

## プロンプト表示

PSX が読み込まれているが、現在フォルダが未登録の場合は、先頭にグレーの `# ` を出します。

```text
# 2026-06-27 09:30:00 [C:\Users\kazu] PS>
```

登録済みフォルダ配下に入ると、先頭に白の `$ ` を出します。

```text
$ 2026-06-27 09:33:36 [D:\tools\WinPicker] PS>
```

この表示は、現在のフォルダが PSX の管理対象かどうかだけを示します。プロンプトを派手にするためではなく、状態を見失わないための最小限のマーカーです。

## プロジェクト設定

`.psctx.json` は次のような内容です。

```powershell
@{
    Name = 'WinPicker'

    EnableAmpersandFork = $true
    ShowProjectNameInPrompt = $false

    Env = @{
        # 'DOTNET_NOLOGO' = '1'
        # 'DOTNET_CLI_TELEMETRY_OPTOUT' = '1'
    }
}
```

`Env` に書いた環境変数は、そのプロジェクト配下にいる間だけ適用されます。別のプロジェクトに移動すればそのプロジェクトの設定に切り替わり、未登録フォルダに出れば通常状態へ戻ります。

## 履歴を表示する

PSX は `h` を履歴表示コマンドとして使います。

```powershell
h
```

表示例です。

```text
   Id  DateTime             CommandLine
   --  --------             -----------
    1  2026-06-27 09:33:36  ll
    2  2026-06-27 09:33:38  dir
    3  2026-06-27 09:33:44  cd D:\tools\WinPicker\
```

PowerShell 標準の `h` は `Get-History` のエイリアスですが、PSX ではあえて上書きしています。理由は、`h` で表示した Id と、次の `!id` で実行する Id を一致させるためです。

## 履歴を再実行する

```powershell
!3
```

または、スペースありでも実行できます。

```powershell
! 3
```

明示的には、次と同じです。

```powershell
Invoke-PSCtxHistoryCommand -Id 3
```

Bash の履歴展開そのものではありません。PSReadLine の Enter キー処理で `!数字` を検出し、PowerShell が解釈する前に PSX のコマンドへ置き換えています。

## 行末 `&` の扱い

プロジェクト設定で `EnableAmpersandFork = $true` の場合、行末 `&` を簡易バックグラウンド実行として扱います。

```powershell
notepad .\.psctx.json &
dotnet build &
```

内部的には PowerShell の `Start-Job` を使っています。Unix の fork と同じものではありませんが、「コマンドを投げてシェルの制御を戻す」という用途には近い感覚で使えます。

ジョブは次のコマンドで確認します。

```powershell
bgjobs
```

出力を見る場合です。

```powershell
bgout 1
```

停止して削除する場合です。

```powershell
bgkill 1
```

この機能はプロジェクト単位で有効・無効を切り替えられます。

## 解除

プロジェクトの PSX 設定を外すには、次のようにします。

```powershell
psx /uninst D:\tools\WinPicker
```

`.psctx.json` は削除せず、リネームします。

履歴フォルダも含めて削除する場合は `/purge` を付けます。

```powershell
psx /uninst D:\tools\WinPicker /purge
```

PSX 自体を PowerShell プロファイルから外す場合は、ツールフォルダで次を実行します。

```powershell
.\Uninstall-PSX.ps1
```

## 注意点

PSX は便利な反面、注意すべき点があります。

まず、`.psctx.json` は PowerShell コードとして実行されます。信頼できないリポジトリやフォルダにある `.psctx.json` を無条件に使うべきではありません。

次に、`.pslocal` には履歴が保存されます。履歴にはトークン、認証情報、サーバー名、内部パスなどが入ることがあります。必ず `.gitignore` に入れ、GitHub に上げないようにします。

また、PSX は `$PROFILE` を変更します。変更前のプロファイルはバックアップされますが、既に複雑なプロンプトや PSReadLine 設定を持っている環境では、導入後の表示やキーバインドを確認してください。

## 対象環境

想定している環境は Windows です。

- Windows PowerShell 5.1
- PowerShell 7.x on Windows
- PSReadLine が使える環境
- Windows Terminal または標準 PowerShell コンソール

Linux/macOS の PowerShell は主対象ではありません。Windows で複数の開発フォルダを行き来する用途に絞っています。

## まとめ

PSX は大きなフレームワークではありません。

PowerShell の日常操作を、プロジェクト単位で少し整理するための小さな ps1 です。

Bash のような操作感を完全に再現するのではなく、Windows の PowerShell に必要な範囲だけを足す。そのために、履歴、環境、プロンプト、簡易バックグラウンド実行をプロジェクト単位にまとめました。

複数の開発フォルダを行き来する人にとって、履歴が混ざらないだけでも作業の見通しはかなり良くなります。PowerShell を普段使いしているなら、こういう小さなコンテキスト管理は意外と効きます。


## 実行ポリシーへの対応

初期版ではプロジェクト設定を `.psctx.ps1` として保存していた。
しかし、PowerShell の実行ポリシーが `AllSigned` などに
設定されている環境では、未署名スクリプトとして読み込みが
拒否される可能性がある。

そのため、PSX 0.8.2 以降では設定ファイルを
`.psctx.json` に変更した。プロジェクト移動時には JSON を
データとして読み込むだけで、設定ファイル自体を実行しない。
これは履歴・環境切替ツールとして、より安全で自然な構成である。
