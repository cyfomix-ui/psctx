#requires -version 5.1
<#
.SYNOPSIS
  Project-local PowerShell context setup command.

.USAGE
  psx <target-folder>
  psx /uninst <target-folder>
  psx <target-folder> /noamp
  psx <target-folder> /amp /showname
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PSX_Version = '0.9.2'
$script:PSX_Name    = 'PSX'
$script:PSX_Title   = 'Project-local PowerShell Context'

$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Quote-PSLiteral {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return "''" }
    return "'" + ($Value -replace "'", "''") + "'"
}

function Get-PPHProfileBlock {
    param([Parameter(Mandatory)][string]$ToolDir)

    $qToolDir = Quote-PSLiteral $ToolDir

@"
# >>> PSX managed block >>>
# This block is managed by psx. Edit .psctx.json in each project instead.
`$script:PPH_ToolDir = $qToolDir
`$script:PPH_DefaultHistoryPath = `$null
`$script:PPH_CurrentRoot = `$null
`$script:PPH_CurrentName = `$null
`$script:PPH_CurrentConfigPath = `$null
`$script:PPH_OriginalEnv = @{}
`$script:PPH_EnableAmpersandFork = `$false
`$script:PPH_ShowProjectNameInPrompt = `$false
`$script:PSX_LastCheckedLocation = `$null
`$script:PSX_ContextCache = @{}
`$script:PSX_HistoryCommandSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
`$script:PSX_MaxHistoryEntries = 1000
`$script:PSX_HistoryTrimThreshold = 1100
foreach (`$legacyCommand in @('psctx','psprojhist','pph','psctxv','Show-PSCtxVersion')) {
    `$functionPath = ("Function:\global:{0}" -f `$legacyCommand)
    `$aliasPath = ("Alias:\{0}" -f `$legacyCommand)
    if (Test-Path -LiteralPath `$functionPath) {
        Remove-Item -LiteralPath `$functionPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath `$aliasPath) {
        Remove-Item -LiteralPath `$aliasPath -Force -ErrorAction SilentlyContinue
    }
}
`$script:PSX_Version = '0.9.2'
`$script:PSX_Name    = 'PSX'
`$script:PSX_Title   = 'Project-local PowerShell Context'

try {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
} catch {
}

try {
    `$script:PPH_DefaultHistoryPath = (Get-PSReadLineOption).HistorySavePath
} catch {
    `$script:PPH_DefaultHistoryPath = `$null
}

if (-not `$script:PPH_PromptInstalled) {
    `$existingPrompt = Get-Command prompt -CommandType Function -ErrorAction SilentlyContinue
    if (`$existingPrompt) {
        `$script:PPH_OriginalPrompt = `$existingPrompt.ScriptBlock
    } else {
        `$script:PPH_OriginalPrompt = `$null
    }
    `$script:PPH_PromptInstalled = `$true
}

function global:Show-PSXVersion {
    `$psVersion = if (`$PSVersionTable.PSVersion) { `$PSVersionTable.PSVersion.ToString() } else { 'Unknown' }
    `$psEditionValue = if (`$PSVersionTable.PSEdition) { `$PSVersionTable.PSEdition } else { 'Desktop' }
    Write-Host ("PowerShell {0} ({1})" -f `$psVersion, `$psEditionValue)
    Write-Host ("PSX        {0}" -f `$script:PSX_Version)
    Write-Host ("Profile:   {0}" -f `$PROFILE)
    Write-Host ("ToolPath:  {0}" -f `$script:PPH_ToolDir)
}

function global:psx {
    param(
        [Parameter(ValueFromRemainingArguments=`$true)]
        [string[]]`$RemainingArgs
    )

    if (-not `$RemainingArgs -or `$RemainingArgs.Count -eq 0) {
        Show-PSXVersion
        return
    }

    `$first = [string]`$RemainingArgs[0]
    if (`$first -match '^(--v|--version|-v|/v|/version|version)$') {
        Show-PSXVersion
        return
    }

    & (Join-Path `$script:PPH_ToolDir 'PSX.Core.ps1') @RemainingArgs

    # Registration/unregistration may change .psctx.json in the current path.
    # Invalidate the location/context cache and apply the new state immediately.
    `$script:PSX_LastCheckedLocation = `$null
    `$script:PSX_ContextCache = @{}
    try { Set-PPHProjectContext } catch { }
}

function Get-PPHActiveHistoryPath {
    try {
        return (Get-PSReadLineOption).HistorySavePath
    } catch {
        return `$script:PPH_DefaultHistoryPath
    }
}

function Get-PPHActiveHistoryMetaPath {
    `$historyPath = Get-PPHActiveHistoryPath
    if (-not `$historyPath) {
        return `$null
    }

    `$parent = Split-Path -Parent `$historyPath
    if (-not `$parent) {
        return `$null
    }

    `$leaf = Split-Path -Leaf `$historyPath
    `$base = [System.IO.Path]::GetFileNameWithoutExtension(`$leaf)
    return (Join-Path `$parent ("{0}_psctx_history.jsonl" -f `$base))
}

function Add-PPHHistoryMetaEntry {
    param([AllowNull()][string]`$CommandLine)

    if (-not `$CommandLine -or -not `$CommandLine.Trim()) {
        return `$true
    }

    try {
        `$metaPath = Get-PPHActiveHistoryMetaPath
        if (-not `$metaPath) {
            return `$true
        }

        `$parent = Split-Path -Parent `$metaPath
        if (`$parent) {
            New-Item -ItemType Directory -Force -Path `$parent | Out-Null
        }

        `$record = [pscustomobject]@{
            Time        = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            CommandLine = [string]`$CommandLine
        }

        `$record | ConvertTo-Json -Compress -Depth 4 | Add-Content -LiteralPath `$metaPath -Encoding UTF8
    } catch {
    }

    return `$true
}

function Optimize-PSXHistoryMetadata {
    param(
        [AllowNull()][string]`$HistoryPath,
        [string[]]`$Commands
    )
    if (-not `$HistoryPath) { return }
    `$parent = Split-Path -Parent `$HistoryPath
    `$leaf = Split-Path -Leaf `$HistoryPath
    `$base = [System.IO.Path]::GetFileNameWithoutExtension(`$leaf)
    `$metaPath = Join-Path `$parent ("{0}_psctx_history.jsonl" -f `$base)
    if (-not (Test-Path -LiteralPath `$metaPath)) { return }
    try {
        `$latest = @{}
        foreach (`$line in (Get-Content -LiteralPath `$metaPath -ErrorAction Stop)) {
            if (-not `$line -or -not `$line.Trim()) { continue }
            try {
                `$obj = `$line | ConvertFrom-Json -ErrorAction Stop
                `$cmd = ([string]`$obj.CommandLine).Trim()
                if (`$cmd) { `$latest[`$cmd] = [string]`$obj.Time }
            } catch { }
        }
        `$out = New-Object System.Collections.Generic.List[string]
        foreach (`$cmd in @(`$Commands)) {
            if (-not `$cmd) { continue }
            `$time = if (`$latest.ContainsKey(`$cmd)) { `$latest[`$cmd] } else { '---- -- -- --:--:--' }
            `$record = [pscustomobject]@{ Time=`$time; CommandLine=`$cmd }
            `$out.Add((`$record | ConvertTo-Json -Compress -Depth 4)) | Out-Null
        }
        Set-Content -LiteralPath `$metaPath -Value `$out -Encoding UTF8
    } catch {
        Write-Debug ("PSX history metadata optimization failed: {0}" -f `$_.Exception.Message)
    }
}

function Optimize-PSXHistoryFile {
    param([AllowNull()][string]`$HistoryPath)

    `$script:PSX_HistoryCommandSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    if (-not `$HistoryPath -or -not (Test-Path -LiteralPath `$HistoryPath)) { return }

    try {
        `$lines = @(Get-Content -LiteralPath `$HistoryPath -ErrorAction Stop)
        `$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        `$uniqueNewestFirst = New-Object System.Collections.Generic.List[string]
        for (`$i = `$lines.Count - 1; `$i -ge 0; `$i--) {
            `$normalized = ([string]`$lines[`$i]).Trim()
            if (-not `$normalized) { continue }
            if (`$seen.Add(`$normalized)) { `$uniqueNewestFirst.Add(`$normalized) | Out-Null }
        }
        `$kept = @(`$uniqueNewestFirst | Select-Object -First `$script:PSX_MaxHistoryEntries)
        [array]::Reverse(`$kept)
        if (`$lines.Count -gt `$script:PSX_HistoryTrimThreshold -or `$kept.Count -ne `$lines.Count) {
            Set-Content -LiteralPath `$HistoryPath -Value `$kept -Encoding UTF8
        }
        foreach (`$command in `$kept) { [void]`$script:PSX_HistoryCommandSet.Add([string]`$command) }
        Optimize-PSXHistoryMetadata -HistoryPath `$HistoryPath -Commands `$kept
    } catch {
        Write-Debug ("PSX history optimization failed: {0}" -f `$_.Exception.Message)
    }
}

function Set-PPHAddToHistoryHandler {
    try {
        Set-PSReadLineOption -AddToHistoryHandler {
            param([string]`$line)
            `$normalized = if (`$null -eq `$line) { '' } else { `$line.Trim() }
            if (-not `$normalized) { return `$false }
            if (`$script:PSX_HistoryCommandSet.Contains(`$normalized)) { return `$false }
            [void]`$script:PSX_HistoryCommandSet.Add(`$normalized)
            try { Add-PPHHistoryMetaEntry -CommandLine `$normalized | Out-Null } catch { }
            return `$true
        }
    } catch {
        Write-Debug ("PSX AddToHistory handler could not be installed: {0}" -f `$_.Exception.Message)
    }
}

function Get-PPHHistoryLines {
    `$historyPath = Get-PPHActiveHistoryPath
    if (-not `$historyPath -or -not (Test-Path -LiteralPath `$historyPath)) {
        return @()
    }

    try {
        return @(Get-Content -LiteralPath `$historyPath -ErrorAction Stop | Where-Object { `$_ -and `$_.Trim().Length -gt 0 })
    } catch {
        return @()
    }
}

function Get-PPHHistoryTimeMap {
    `$map = @{}
    `$metaPath = Get-PPHActiveHistoryMetaPath
    if (-not `$metaPath -or -not (Test-Path -LiteralPath `$metaPath)) {
        return `$map
    }

    try {
        foreach (`$line in (Get-Content -LiteralPath `$metaPath -ErrorAction Stop)) {
            if (-not `$line -or -not `$line.Trim()) { continue }
            try {
                `$obj = `$line | ConvertFrom-Json -ErrorAction Stop
                if (`$obj.CommandLine) {
                    # If the same command appears more than once, show the latest timestamp.
                    `$map[[string]`$obj.CommandLine] = [string]`$obj.Time
                }
            } catch {
            }
        }
    } catch {
    }

    return `$map
}

function Get-PPHHistoryRecords {
    try { Set-PPHProjectContext } catch { }

    `$lines = @(Get-PPHHistoryLines)
    `$timeMap = Get-PPHHistoryTimeMap
    `$records = New-Object System.Collections.Generic.List[object]

    for (`$i = 0; `$i -lt `$lines.Count; `$i++) {
        `$cmd = [string]`$lines[`$i]
        `$time = `$null
        if (`$timeMap.ContainsKey(`$cmd)) {
            `$time = `$timeMap[`$cmd]
        }
        if (-not `$time) {
            `$time = '---- -- -- --:--:--'
        }

        `$records.Add([pscustomobject]@{
            Id          = `$i + 1
            Time        = `$time
            CommandLine = `$cmd
        }) | Out-Null
    }

    return `$records.ToArray()
}

function global:Show-PSCtxHistory {
    param(
        [int]`$Last = 50,
        [switch]`$All
    )

    `$records = @(Get-PPHHistoryRecords)
    if (`$records.Count -eq 0) {
        Write-Host 'No history found.' -ForegroundColor DarkGray
        return
    }

    if (`$Last -le 0) { `$Last = 50 }

    `$start = 0
    if (-not `$All -and `$records.Count -gt `$Last) {
        `$start = `$records.Count - `$Last
    }

    '{0,5}  {1,-19}  {2}' -f 'Id', 'DateTime', 'CommandLine'
    '{0,5}  {1,-19}  {2}' -f '--', '--------', '-----------'

    for (`$i = `$start; `$i -lt `$records.Count; `$i++) {
        `$r = `$records[`$i]
        '{0,5}  {1,-19}  {2}' -f `$r.Id, `$r.Time, `$r.CommandLine
    }
}

try {
    # PowerShell has a built-in alias named h -> Get-History.
    # Some profiles may already remove it, so check first. This avoids
    # a noisy 'Cannot find path Alias:\h' message when reloading $PROFILE.
    if (Test-Path Alias:h) {
        Remove-Item Alias:h -Force -ErrorAction SilentlyContinue
    }
} catch {
}
function global:h {
    Show-PSCtxHistory @args
}

function global:Invoke-PSCtxHistoryCommand {
    param(
        [Parameter(Mandatory, Position=0)]
        [int]`$Id
    )

    `$records = @(Get-PPHHistoryRecords)
    if (`$records.Count -eq 0) {
        Write-Host 'No history found.' -ForegroundColor Yellow
        return
    }

    if (`$Id -lt 1 -or `$Id -gt `$records.Count) {
        Write-Host ("History id out of range: {0}  valid: 1..{1}" -f `$Id, `$records.Count) -ForegroundColor Yellow
        return
    }

    `$commandText = [string]`$records[`$Id - 1].CommandLine
    if (-not `$commandText.Trim()) {
        Write-Host "History id is empty: `$Id" -ForegroundColor Yellow
        return
    }

    Write-Host ("! {0}: {1}" -f `$Id, `$commandText) -ForegroundColor DarkGray
    Invoke-Expression `$commandText
}

try {
    Set-Alias -Name '!' -Value Invoke-PSCtxHistoryCommand -Scope Global -Force -ErrorAction SilentlyContinue
} catch {
}

Set-PPHAddToHistoryHandler


function ConvertTo-PPHHashtable {
    param([AllowNull()]`$InputObject)

    if (`$null -eq `$InputObject) {
        return @{}
    }

    if (`$InputObject -is [hashtable]) {
        return `$InputObject
    }

    `$result = @{}
    foreach (`$prop in `$InputObject.PSObject.Properties) {
        `$value = `$prop.Value
        if (`$value -is [System.Management.Automation.PSCustomObject]) {
            `$value = ConvertTo-PPHHashtable -InputObject `$value
        }
        `$result[`$prop.Name] = `$value
    }

    return `$result
}

function Read-PPHJsonProjectConfig {
    param([Parameter(Mandatory)][string]`$ConfigPath)

    try {
        `$raw = Get-Content -LiteralPath `$ConfigPath -Raw -ErrorAction Stop
        if (-not `$raw -or -not `$raw.Trim()) {
            return @{}
        }
        `$obj = `$raw | ConvertFrom-Json -ErrorAction Stop
        return (ConvertTo-PPHHashtable -InputObject `$obj)
    } catch {
        Write-Warning "Failed to load project context: `$ConfigPath"
        Write-Warning `$_.Exception.Message
        return @{}
    }
}

function Read-PPHLegacyPs1ProjectConfig {
    param([Parameter(Mandatory)][string]`$ConfigPath)

    # Legacy .psctx.ps1 is intentionally NOT executed.
    # This avoids ExecutionPolicy / unsigned-script failures and also keeps
    # project configuration data-only. Only the simple PSCtx-generated
    # hashtable format is parsed here.
    `$loaded = @{}

    try {
        `$text = Get-Content -LiteralPath `$ConfigPath -Raw -ErrorAction Stop
    } catch {
        Write-Warning "Failed to read legacy project context: `$ConfigPath"
        return `$loaded
    }

    if (`$text -match "(?m)^\s*Name\s*=\s*'((?:''|[^'])*)'") {
        `$loaded.Name = (`$matches[1] -replace "''", "'")
    }

    if (`$text -match '(?m)^\s*EnableAmpersandFork\s*=\s*\`$(true|false)') {
        `$loaded.EnableAmpersandFork = ([string]`$matches[1] -ieq 'true')
    }

    if (`$text -match '(?m)^\s*ShowProjectNameInPrompt\s*=\s*\`$(true|false)') {
        `$loaded.ShowProjectNameInPrompt = ([string]`$matches[1] -ieq 'true')
    }

    `$envMap = @{}
    if (`$text -match '(?s)Env\s*=\s*@\{(?<body>.*?)\}') {
        `$body = [string]`$matches['body']
        foreach (`$m in [regex]::Matches(`$body, "'((?:''|[^'])*)'\s*=\s*'((?:''|[^'])*)'")) {
            `$key = `$m.Groups[1].Value -replace "''", "'"
            `$val = `$m.Groups[2].Value -replace "''", "'"
            if (`$key) { `$envMap[`$key] = `$val }
        }
    }
    `$loaded.Env = `$envMap

    return `$loaded
}

function Get-PPHProjectContext {
    try { `$providerPath = (Get-Location).ProviderPath } catch { return `$null }
    if (-not `$providerPath) { return `$null }
    try { `$providerPath = [System.IO.Path]::GetFullPath(`$providerPath).TrimEnd('\') } catch { }

    if (`$script:PSX_ContextCache.ContainsKey(`$providerPath)) {
        `$cached = `$script:PSX_ContextCache[`$providerPath]
        if (`$cached -is [string] -and `$cached -eq '__PSX_NONE__') { return `$null }
        return `$cached
    }

    `$visited = New-Object System.Collections.Generic.List[string]
    `$dir = Get-Item -LiteralPath `$providerPath -ErrorAction SilentlyContinue
    if (-not `$dir) { return `$null }

    while (`$dir) {
        `$visited.Add(`$dir.FullName) | Out-Null
        `$jsonFile = Join-Path `$dir.FullName '.psctx.json'
        `$legacyFile = Join-Path `$dir.FullName '.psctx.ps1'
        `$ctxFile = `$null
        `$loaded = @{}
        if (Test-Path -LiteralPath `$jsonFile) {
            `$ctxFile = `$jsonFile
            `$loaded = Read-PPHJsonProjectConfig -ConfigPath `$jsonFile
        } elseif (Test-Path -LiteralPath `$legacyFile) {
            `$ctxFile = `$legacyFile
            `$loaded = Read-PPHLegacyPs1ProjectConfig -ConfigPath `$legacyFile
        }
        if (`$ctxFile) {
            `$name = `$loaded.Name
            if (-not `$name) { `$name = Split-Path `$dir.FullName -Leaf }
            `$result = [pscustomobject]@{ Root=`$dir.FullName; Name=[string]`$name; ConfigPath=`$ctxFile; Config=`$loaded }
            foreach (`$path in `$visited) { `$script:PSX_ContextCache[`$path] = `$result }
            return `$result
        }
        `$dir = `$dir.Parent
    }

    foreach (`$path in `$visited) { `$script:PSX_ContextCache[`$path] = '__PSX_NONE__' }
    return `$null
}

function Restore-PPHProjectEnv {
    foreach (`$key in @(`$script:PPH_OriginalEnv.Keys)) {
        `$oldValue = `$script:PPH_OriginalEnv[`$key]
        if (`$null -eq `$oldValue) {
            Remove-Item "Env:`$key" -ErrorAction SilentlyContinue
        } else {
            Set-Item "Env:`$key" `$oldValue -ErrorAction SilentlyContinue
        }
    }
    `$script:PPH_OriginalEnv = @{}
}

function Apply-PPHProjectEnv {
    param([hashtable]`$EnvMap)

    Restore-PPHProjectEnv

    if (-not `$EnvMap) {
        return
    }

    foreach (`$key in `$EnvMap.Keys) {
        `$script:PPH_OriginalEnv[`$key] = [Environment]::GetEnvironmentVariable(`$key, 'Process')
        Set-Item "Env:`$key" ([string]`$EnvMap[`$key]) -ErrorAction SilentlyContinue
    }
}

function Import-PPHHistory {
    param([AllowNull()][string]`$HistoryPath)
    # PSReadLine session history is intentionally not cleared/replayed here.
    # Replaying thousands of entries made directory changes visibly slow.
    Optimize-PSXHistoryFile -HistoryPath `$HistoryPath
}

function Set-PPHReadLineHistoryPath {
    param([Parameter(Mandatory)][string]`$HistoryPath)

    `$parent = Split-Path -Parent `$HistoryPath
    if (`$parent) {
        New-Item -ItemType Directory -Force -Path `$parent | Out-Null
    }
    if (-not (Test-Path -LiteralPath `$HistoryPath)) {
        New-Item -ItemType File -Force -Path `$HistoryPath | Out-Null
    }

    try {
        Set-PSReadLineOption -HistorySavePath `$HistoryPath -HistorySaveStyle SaveIncrementally -HistoryNoDuplicates
    } catch {
        Set-PSReadLineOption -HistorySavePath `$HistoryPath -HistorySaveStyle SaveIncrementally
    }
}

function Set-PPHProjectContext {
    try { `$currentLocation = (Get-Location).ProviderPath } catch { return }
    if (`$currentLocation -and `$script:PSX_LastCheckedLocation -and `$currentLocation -ieq `$script:PSX_LastCheckedLocation) { return }
    `$script:PSX_LastCheckedLocation = `$currentLocation
    `$ctx = Get-PPHProjectContext

    if (`$null -eq `$ctx) {
        if (`$script:PPH_CurrentRoot -ne `$null) {
            if (`$script:PPH_DefaultHistoryPath) {
                Set-PPHReadLineHistoryPath -HistoryPath `$script:PPH_DefaultHistoryPath
                Import-PPHHistory -HistoryPath `$script:PPH_DefaultHistoryPath
            }

            Restore-PPHProjectEnv
            `$script:PPH_CurrentRoot = `$null
            `$script:PPH_CurrentName = `$null
            `$script:PPH_CurrentConfigPath = `$null
            `$script:PPH_EnableAmpersandFork = `$false
            `$script:PPH_ShowProjectNameInPrompt = `$false
        }
        return
    }

    if (`$script:PPH_CurrentRoot -eq `$ctx.Root -and `$script:PPH_CurrentConfigPath -eq `$ctx.ConfigPath) {
        return
    }

    `$safeHostName = `$Host.Name -replace '[\\/:*?"<>|]', '_'
    `$histFile = Join-Path `$ctx.Root (Join-Path '.pslocal\PSReadLine' "`$safeHostName`_history.txt")

    Set-PPHReadLineHistoryPath -HistoryPath `$histFile
    Import-PPHHistory -HistoryPath `$histFile

    `$envMap = `$null
    if (`$ctx.Config.ContainsKey('Env') -and `$ctx.Config.Env -is [hashtable]) {
        `$envMap = `$ctx.Config.Env
    }
    Apply-PPHProjectEnv -EnvMap `$envMap

    `$script:PPH_CurrentRoot = `$ctx.Root
    `$script:PPH_CurrentName = `$ctx.Name
    `$script:PPH_CurrentConfigPath = `$ctx.ConfigPath
    `$script:PPH_EnableAmpersandFork = [bool]`$ctx.Config.EnableAmpersandFork
    `$script:PPH_ShowProjectNameInPrompt = [bool]`$ctx.Config.ShowProjectNameInPrompt
}

function global:Start-PSPHBackground {
    param(
        [string]`$CommandText,
        [string]`$EncodedCommandText
    )

    if (`$EncodedCommandText) {
        `$CommandText = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(`$EncodedCommandText))
    }

    if (-not `$CommandText -or -not `$CommandText.Trim()) {
        return
    }

    `$cwd = (Get-Location).ProviderPath
    `$name = 'bg:' + (`$CommandText.Trim() -replace '\s+', ' ')
    if (`$name.Length -gt 48) {
        `$name = `$name.Substring(0, 48)
    }

    `$job = Start-Job -Name `$name -ScriptBlock {
        param(`$WorkingDirectory, `$Command)
        if (`$WorkingDirectory) {
            Set-Location -LiteralPath `$WorkingDirectory
        }
        Invoke-Expression `$Command
    } -ArgumentList `$cwd, `$CommandText

    Write-Host ("[bg:{0}] {1}" -f `$job.Id, `$CommandText.Trim()) -ForegroundColor DarkGray
}

function global:bgjobs {
    Get-Job
}

function global:bgout {
    param([Parameter(Mandatory)][int]`$Id)
    Receive-Job -Id `$Id -Keep
}

function global:bgkill {
    param([Parameter(Mandatory)][int]`$Id)
    Stop-Job -Id `$Id -ErrorAction SilentlyContinue
    Remove-Job -Id `$Id -Force -ErrorAction SilentlyContinue
}

try {
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param(`$key, `$arg)

        try {
            `$line = `$null
            `$cursor = `$null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]`$line, [ref]`$cursor)

            # Bash-style history recall: ! 123
            # Implemented here so the line is rewritten before PowerShell parses '!'.
            if (`$line -match '^\s*!\s*(\d+)\s*$') {
                `$historyId = [int]`$matches[1]
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Invoke-PSCtxHistoryCommand -Id `$historyId")
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
                return
            }

            if (`$script:PPH_EnableAmpersandFork -and `$line -match '^\s*(.+?)\s*&\s*$') {
                `$cmd = `$matches[1].Trim()
                if (`$cmd) {
                    `$bytes = [Text.Encoding]::Unicode.GetBytes(`$cmd)
                    `$b64 = [Convert]::ToBase64String(`$bytes)
                    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Start-PSPHBackground -EncodedCommandText '`$b64'")
                    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
                    return
                }
            }
        } catch {
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
} catch {
}

function global:prompt {
    try {
        Set-PPHProjectContext
    } catch {
    }

    # PSX marker:
    #   '# ' gray  = PSX is loaded, but current folder is not a registered context.
    #   '$ ' white = current folder is inside a registered project context.
    if (`$script:PPH_CurrentRoot) {
        Write-Host '$ ' -ForegroundColor White -NoNewline
    } else {
        Write-Host '# ' -ForegroundColor DarkGray -NoNewline
    }

    if (`$script:PPH_CurrentRoot -and `$script:PPH_CurrentName -and `$script:PPH_ShowProjectNameInPrompt) {
        Write-Host ("[`$(`$script:PPH_CurrentName)] ") -ForegroundColor Cyan -NoNewline
    }

    if (`$script:PPH_OriginalPrompt) {
        `$result = & `$script:PPH_OriginalPrompt
        if (`$null -ne `$result) {
            return `$result
        }
        return ''
    }

    return "PS `$(`$executionContext.SessionState.Path.CurrentLocation)`$('>' * (`$nestedPromptLevel + 1)) "
}
# <<< PSX managed block <<<
"@
}

function Install-PPHProfileBlock {
    param([Parameter(Mandatory)][string]$ToolDir)

    $profilePath = $PROFILE
    $profileDir = Split-Path -Parent $profilePath
    if ($profileDir) {
        New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    }

    if (-not (Test-Path -LiteralPath $profilePath)) {
        New-Item -ItemType File -Force -Path $profilePath | Out-Null
    }

    $existing = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $existing) { $existing = '' }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = "$profilePath.pph_backup_$stamp"
    Copy-Item -LiteralPath $profilePath -Destination $backup -Force

    $block = Get-PPHProfileBlock -ToolDir $ToolDir
    $pattern = '(?s)# >>> (?:PerProjectPowerShellHistory|PSCtx|PSX) managed block >>>.*?# <<< (?:PerProjectPowerShellHistory|PSCtx|PSX) managed block <<<'

    if ($existing -match $pattern) {
        $newContent = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block })
    } else {
        $newContent = $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
    }

    Set-Content -LiteralPath $profilePath -Value $newContent -Encoding UTF8
    return $profilePath
}

function Add-ToolDirToUserPath {
    param([Parameter(Mandatory)][string]$ToolDir)

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $current) { $current = '' }

    $parts = $current -split ';' | Where-Object { $_ -and $_.Trim() }
    $exists = $false
    foreach ($p in $parts) {
        try {
            if ([System.IO.Path]::GetFullPath($p).TrimEnd('\') -ieq [System.IO.Path]::GetFullPath($ToolDir).TrimEnd('\')) {
                $exists = $true
                break
            }
        } catch {
        }
    }

    if (-not $exists) {
        $newPath = if ($current.Trim()) { $current.TrimEnd(';') + ';' + $ToolDir } else { $ToolDir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = $env:Path.TrimEnd(';') + ';' + $ToolDir
        return $true
    }

    return $false
}

function Remove-ToolDirFromUserPath {
    param([Parameter(Mandatory)][string]$ToolDir)

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $current) { return $false }

    $changed = $false
    $target = [System.IO.Path]::GetFullPath($ToolDir).TrimEnd('\')
    $parts = foreach ($p in ($current -split ';')) {
        if (-not $p.Trim()) { continue }
        try {
            $full = [System.IO.Path]::GetFullPath($p).TrimEnd('\')
            if ($full -ieq $target) {
                $changed = $true
                continue
            }
        } catch {
        }
        $p
    }

    if ($changed) {
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    }
    return $changed
}

function Remove-PPHProfileBlock {
    $profilePath = $PROFILE
    if (-not (Test-Path -LiteralPath $profilePath)) { return $false }

    $existing = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
    if (-not $existing) { return $false }

    $pattern = '(?s)\r?\n?# >>> (?:PerProjectPowerShellHistory|PSCtx|PSX) managed block >>>.*?# <<< (?:PerProjectPowerShellHistory|PSCtx|PSX) managed block <<<\r?\n?'
    if ($existing -notmatch $pattern) { return $false }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item -LiteralPath $profilePath -Destination "$profilePath.pph_backup_$stamp" -Force
    $newContent = [regex]::Replace($existing, $pattern, '')
    Set-Content -LiteralPath $profilePath -Value $newContent.TrimEnd() -Encoding UTF8
    return $true
}

function Add-PPHGitIgnoreEntry {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $gitignore = Join-Path $ProjectRoot '.gitignore'
    if (-not (Test-Path -LiteralPath $gitignore)) {
        Set-Content -LiteralPath $gitignore -Value ".pslocal/`r`n" -Encoding UTF8
        return
    }

    $content = Get-Content -LiteralPath $gitignore -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch '(?m)^\.pslocal/\s*$') {
        Add-Content -LiteralPath $gitignore -Value ".pslocal/"
    }
}


function Write-PPHProjectConfig {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$EnableAmpersandFork,
        [Parameter(Mandatory)][bool]$ShowProjectNameInPrompt
    )

    $ctxFile = Join-Path $ProjectRoot '.psctx.json'
    $legacyFile = Join-Path $ProjectRoot '.psctx.ps1'

    if (Test-Path -LiteralPath $ctxFile) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        Copy-Item -LiteralPath $ctxFile -Destination "$ctxFile.bak_$stamp" -Force
    }

    # Keep legacy config as a backup if it exists, but do not overwrite it.
    # The runtime prefers .psctx.json, so the unsigned .psctx.ps1 no longer
    # has to be executed under AllSigned / RemoteSigned policies.
    if ((Test-Path -LiteralPath $legacyFile) -and -not (Test-Path -LiteralPath "$legacyFile.legacy")) {
        try {
            Copy-Item -LiteralPath $legacyFile -Destination "$legacyFile.legacy" -Force
        } catch {
        }
    }

    $config = [ordered]@{
        Name                    = $Name
        EnableAmpersandFork     = $EnableAmpersandFork
        ShowProjectNameInPrompt = $ShowProjectNameInPrompt
        Env                     = [ordered]@{}
    }

    $json = $config | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $ctxFile -Value $json -Encoding UTF8
    $script:PSX_ContextCache = @{}
}

function Register-PPHProject {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$Name,
        [bool]$EnableAmpersandFork = $true,
        [bool]$ShowProjectNameInPrompt = $false
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
    }

    $root = (Resolve-Path -LiteralPath $TargetPath).ProviderPath
    if (-not $Name) { $Name = Split-Path $root -Leaf }

    Write-PPHProjectConfig -ProjectRoot $root -Name $Name -EnableAmpersandFork $EnableAmpersandFork -ShowProjectNameInPrompt $ShowProjectNameInPrompt
    New-Item -ItemType Directory -Force -Path (Join-Path $root '.pslocal\PSReadLine') | Out-Null
    Add-PPHGitIgnoreEntry -ProjectRoot $root

    return $root
}


function Unregister-PPHProject {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [bool]$Purge = $false
    )

    $root = (Resolve-Path -LiteralPath $TargetPath).ProviderPath
    $changed = $false
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    foreach ($leaf in @('.psctx.json', '.psctx.ps1')) {
        $ctxFile = Join-Path $root $leaf
        if (Test-Path -LiteralPath $ctxFile) {
            Move-Item -LiteralPath $ctxFile -Destination "$ctxFile.disabled_$stamp" -Force
            $changed = $true
        }
    }

    if ($Purge) {
        $localDir = Join-Path $root '.pslocal'
        if (Test-Path -LiteralPath $localDir) {
            Remove-Item -LiteralPath $localDir -Recurse -Force
            $changed = $true
        }
    }

    $script:PSX_ContextCache = @{}
    return [pscustomobject]@{ Root = $root; Changed = $changed }
}

function Show-PSXVersion {
    $psVersion = if ($PSVersionTable.PSVersion) { $PSVersionTable.PSVersion.ToString() } else { 'Unknown' }
    $psEditionValue = if ($PSVersionTable.PSEdition) { $PSVersionTable.PSEdition } else { 'Desktop' }
    Write-Host ("PowerShell {0} ({1})" -f $psVersion, $psEditionValue)
    Write-Host ("PSX        {0}" -f $script:PSX_Version)
    Write-Host ("Profile:   {0}" -f $PROFILE)
    Write-Host ("ToolPath:  {0}" -f $ToolDir)
}

function Show-Usage {
@'
psx usage:

  psx <folder>
      Register a folder as a per-project PowerShell history/context root.

  psx /uninst <folder>
      Disable per-project history/context for that folder.
      .psctx.json / .psctx.ps1 are renamed, not deleted.

  psx /uninst <folder> /purge
      Disable and remove .pslocal history directory.

  psx <folder> /noamp
      Register without trailing-& background support.

  psx <folder> /amp
      Register with trailing-& background support. This is the default.

  psx <folder> /name MyProject
      Register with a custom project name.

  psx <folder> /showname
      Show [ProjectName] after the white $ prompt marker.

  h
      Show recent PSReadLine history with numeric ids and DateTime. Use h -All for all entries.
      Note: these ids are PSX/PSReadLine ids, not Get-History session ids.

  ! <id>
  !<id>
      Run the command shown by h for the specified PSX history id.

  psx /version
  psx -v
  psx --v
      Show PowerShell and PSX versions.

  psx /installtool
      Install/update the PowerShell profile block only.

  psx /removeprofile
      Remove the PowerShell profile block.
'@ | Write-Host
}

# -------------------- argument parsing --------------------
$raw = @($args)
$mode = 'register'
$target = $null
$name = $null
$enableAmp = $true
$showName = $false
$purge = $false

for ($i = 0; $i -lt $raw.Count; $i++) {
    $a = [string]$raw[$i]
    switch -Regex ($a) {
        '^(\/|--?)(h|help|\?)$' { Show-Usage; exit 0 }
        '^(\/|--?)(v|version)$' { Show-PSXVersion; exit 0 }
        '^version$' { Show-PSXVersion; exit 0 }
        '^(\/|-)(installtool|install)$' { $mode = 'installtool'; continue }
        '^(\/|-)(removeprofile|uninstalltool|tooluninst)$' { $mode = 'removeprofile'; continue }
        '^(\/|-)(uninst|uninstall|remove)$' { $mode = 'unregister'; continue }
        '^(\/|-)(purge)$' { $purge = $true; continue }
        '^(\/|-)(amp|enableamp|fork)$' { $enableAmp = $true; continue }
        '^(\/|-)(noamp|disableamp|nofork)$' { $enableAmp = $false; continue }
        '^(\/|-)(showname)$' { $showName = $true; continue }
        '^(\/|-)(name)$' {
            if ($i + 1 -ge $raw.Count) { throw 'Missing value after /name.' }
            $i++
            $name = [string]$raw[$i]
            continue
        }
        default {
            if (-not $target) { $target = $a }
            else { throw "Unexpected argument: $a" }
        }
    }
}

if ($mode -eq 'installtool') {
    foreach ($legacyFile in @('psctx.cmd','psctx.ps1','psprojhist.cmd','psprojhist.ps1','pph.cmd','pph.ps1')) {
        $legacyPath = Join-Path $ToolDir $legacyFile
        if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
            Remove-Item -LiteralPath $legacyPath -Force -ErrorAction SilentlyContinue
        }
    }
    $profilePath = Install-PPHProfileBlock -ToolDir $ToolDir
    $pathAdded = Add-ToolDirToUserPath -ToolDir $ToolDir
    Write-Host "Installed psx profile block:" -ForegroundColor Green
    Write-Host "  $profilePath"
    if ($pathAdded) {
        Write-Host "Added tool folder to User PATH:" -ForegroundColor Green
        Write-Host "  $ToolDir"
    } else {
        Write-Host "Tool folder is already in User PATH."
    }
    Write-Host "Reload with: . `$PROFILE"
    exit 0
}

if ($mode -eq 'removeprofile') {
    $removed = Remove-PPHProfileBlock
    $pathRemoved = Remove-ToolDirFromUserPath -ToolDir $ToolDir
    if ($removed) { Write-Host 'Removed psx profile block.' -ForegroundColor Green }
    else { Write-Host 'No psx profile block found.' }
    if ($pathRemoved) { Write-Host 'Removed tool folder from User PATH.' -ForegroundColor Green }
    Write-Host 'Open a new PowerShell window to complete removal.'
    exit 0
}

# Ensure global profile block exists for normal register/unregister operations.
$profilePath = Install-PPHProfileBlock -ToolDir $ToolDir

if (-not $target) { $target = '.' }

if ($mode -eq 'unregister') {
    $result = Unregister-PPHProject -TargetPath $target -Purge:$purge
    if ($result.Changed) {
        Write-Host "Disabled project-local PowerShell context for:" -ForegroundColor Green
        Write-Host "  $($result.Root)"
    } else {
        Write-Host "No active .psctx.json or .psctx.ps1 found under:" -ForegroundColor Yellow
        Write-Host "  $($result.Root)"
    }
    Write-Host "Reload with: . `$PROFILE"
    exit 0
}

$registeredRoot = Register-PPHProject -TargetPath $target -Name $name -EnableAmpersandFork:$enableAmp -ShowProjectNameInPrompt:$showName
Write-Host "Registered project-local PowerShell context for:" -ForegroundColor Green
Write-Host "  $registeredRoot"
Write-Host "Project config:"
Write-Host "  $(Join-Path $registeredRoot '.psctx.json')"
Write-Host "History folder:"
Write-Host "  $(Join-Path $registeredRoot '.pslocal\PSReadLine')"
Write-Host "PowerShell profile updated:"
Write-Host "  $profilePath"
Write-Host "Reload with: . `$PROFILE"
