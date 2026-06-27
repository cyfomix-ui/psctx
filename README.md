# PSCtx - Project-local PowerShell Context

PSCtx is a lightweight PowerShell helper for project folders.

It switches command history, environment variables, prompt markers,
and small shell conveniences according to the folder you are in.

In Japanese, this tool can be described as:

> プロジェクト別 PowerShell コンテキスト

or more plainly:

> フォルダ別 PowerShell 履歴・環境切替

## Main features

- Separate PSReadLine history per project folder.
- Separate Up/Down arrow history per project folder.
- Load project-local environment variables from `.psctx.ps1`.
- Show a prompt marker for managed and unmanaged folders.
- Add Bash-like conveniences such as `h`, `!5`, and `cmd &`.
- Provide `psx --v` to show both PowerShell and PSCtx versions.
- Work with Windows PowerShell 5.1 and PowerShell 7.x.

## Prompt markers

When PSCtx is loaded but the current folder is not managed,
the prompt starts with a gray `# ` marker.

```text
# 2026-06-27 10:21:15 [C:\Users\YourName] PS>
```

When the current folder is inside a managed project,
the prompt starts with a white `$ ` marker.

```text
$ 2026-06-27 10:21:15 [D:\tools\SampleProject] PS>
```

The marker is intentionally small. It tells you whether the
current shell context is managed by PSCtx.

## Installation

Extract the PSCtx files into a stable folder, for example:

```text
D:\tools\PowerShellContext\
```

Then run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-PSCtx.ps1
. $PROFILE
```

This installs PSCtx into the current PowerShell profile.

PowerShell 5.1 and PowerShell 7.x have different profile paths.
If you want to use both, run the installer once from each shell.

## Register a project folder

Register a project folder with:

```powershell
psctx D:\tools\SampleProject
```

You can also register the current folder:

```powershell
psctx .
```

PSCtx creates the following files in the project folder:

```text
.psctx.ps1
.pslocal\PSReadLine\
```

`.psctx.ps1` stores project-local settings.
`.pslocal` stores local history data and should not be committed.

## Unregister a project folder

To unregister a project folder:

```powershell
psctx /uninst D:\tools\SampleProject
```

To unregister the current folder:

```powershell
psctx /uninst .
```

By default, the local history folder is preserved.
To remove it as well:

```powershell
psctx /uninst D:\tools\SampleProject /purge
```

## History commands

`h` displays PSCtx-managed history with command IDs.

```powershell
h
```

Example:

```text
   Id  DateTime             CommandLine
   --  --------             -----------
    1  2026-06-27 09:33:36  ll
    2  2026-06-27 09:33:38  dir
    3  2026-06-27 09:33:44  cd D:\tools\SampleProject\
```

Run a history item by ID:

```powershell
!5
```

or:

```powershell
! 5
```

The explicit function form also works:

```powershell
Invoke-PSCtxHistoryCommand -Id 5
```

## Background command helper

Inside a managed project folder, PSCtx can treat a trailing `&`
as a background-job request.

```powershell
notepad .\.psctx.ps1 &
dotnet build &
```

This is not a Unix fork. Internally PSCtx maps the command to
a PowerShell job so that the prompt returns immediately.

Useful helper commands:

```powershell
bgjobs
bgout 1
bgkill 1
```

If you do not want this behavior for a project, register it with:

```powershell
psctx D:\tools\SampleProject /noamp
```

## Version commands

Show both PowerShell and PSCtx versions:

```powershell
psx --v
```

Example:

```text
PowerShell 7.6.3 (Core)
PSCtx      0.7.1
Profile:   C:\Users\YourName\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
ToolPath:  D:\tools\PowerShellContext
```

You can also use:

```powershell
psctx /version
psctx -v
psctxv
```

## Update policy

You do not need to register every project again when PSCtx itself
is updated.

A typical update is:

```text
1. Extract the new PSCtx files over the existing tool folder.
2. Run Install-PSCtx.ps1 once from the PSCtx tool folder.
3. Reload the profile or restart PowerShell.
```

Existing project files such as `.psctx.ps1` and `.pslocal` remain
valid.

If a new version introduces new project options, old projects still
work. Edit `.psctx.ps1` only when you want to use the new options.

## PowerShell 5.1 support

PSCtx targets PowerShell 5.1 or later.

Windows PowerShell 5.1 and PowerShell 7.x use different profile
folders. Install PSCtx once for each shell if you use both.

PowerShell 7.x profile example:

```text
C:\Users\YourName\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Windows PowerShell 5.1 profile example:

```text
C:\Users\YourName\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

If PSReadLine is too old on PowerShell 5.1, update it with:

```powershell
Install-Module PSReadLine -Scope CurrentUser -Force
```

## FAQ

### Does PSCtx keep settings after entering a project folder?

Yes. A project context stays active while you are inside that
project folder or any of its subfolders.

When you move to another managed project, PSCtx switches to that
project context.

When you move to an unmanaged folder, PSCtx returns to the normal
context.

### Do I need to reinstall PSCtx for every project after an update?

No. PSCtx itself is installed into your PowerShell profile.

Each project is registered separately by creating `.psctx.ps1`.
After a PSCtx update, you usually only need to reinstall the PSCtx
runtime into the profile once.

### Why does `# ` appear in an unmanaged folder?

`# ` means PSCtx is loaded, but the current folder is not managed.
It is a status marker, not an error.

### Why does `$ ` appear in a managed folder?

`$ ` means PSCtx is active for the current project folder.
History, environment variables, and helpers are using the project
context.

### Why did old history entries have no timestamp?

Standard PSReadLine history files do not store timestamps.

PSCtx records timestamps in an additional JSONL file. Commands run
after this feature was added can show date and time. Older entries
may not have timestamp data.

### Why did `h` and `!5` originally point to different commands?

PowerShell already has `h` as an alias for `Get-History`.

PSCtx now overrides `h` so that the displayed ID matches the command
used by `!5` and `Invoke-PSCtxHistoryCommand`.

### Why did `psx --v` once show a read-only variable error?

PowerShell variable names are case-insensitive.

An internal variable named `$psEdition` collided with the built-in
read-only `$PSEdition`. PSCtx 0.7.1 fixed this by renaming the
internal variable.

### Is `cmd &` the same as Bash fork?

No. PSCtx does not implement Unix process forking.

It provides a Bash-like shortcut by converting a trailing `&` into
a PowerShell job.

### Is `.pslocal` safe to commit?

No. Do not commit `.pslocal`.

Command history may contain paths, server names, tokens, or other
sensitive data.

Add this to `.gitignore`:

```gitignore
.pslocal/
```

## Security notes

`.psctx.ps1` is a PowerShell script file. Treat it as code.
Only use `.psctx.ps1` files from folders you trust.

`.pslocal` may contain command history. Do not publish it.

## License

MIT License.
