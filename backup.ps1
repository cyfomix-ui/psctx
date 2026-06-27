param(
    [string]$TargetDir = ".",
    [string]$BackupDirName = "__oldsource"
)

$ErrorActionPreference = "Stop"

# 対象フォルダを解決
$target = Resolve-Path -LiteralPath $TargetDir
$targetPath = $target.Path

# バックアップ先 __oldsource
$backupDir = Join-Path $targetPath $BackupDirName
if (-not (Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# 日付時間付きZIP名
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$zipName = "DropMp4_$stamp.zip"
$zipPath = Join-Path $backupDir $zipName

# 一時作業フォルダ
$tempRoot = Join-Path $env:TEMP "DropMp4_backup_$stamp"
if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null

function Get-RelativePathFromTarget {
    param([System.IO.FileInfo]$File)
    $baseUri = New-Object System.Uri(($targetPath.TrimEnd('\') + '\'))
    $fileUri = New-Object System.Uri($File.FullName)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fileUri).ToString()).Replace('/', '\')
}

function Test-BackupExcluded {
    param([System.IO.FileInfo]$File)
    $relative = (Get-RelativePathFromTarget -File $File).ToLowerInvariant()
    $extension = $File.Extension.ToLowerInvariant()

    $excludedDirPrefixes = @(
        ".git\",
        ".venv\",
        "venv\",
        "__pycache__\",
        "__oldsource\",
        "oldsource\",
        "backup\",
        "build\",
        "dist\",
        "_cache\",
        "_logs\",
        "_browser_profiles\",
        "browser_profiles\",
        ".vscodecounter\"
    )
    foreach ($prefix in $excludedDirPrefixes) {
        if ($relative.StartsWith($prefix)) { return $true }
        if ($relative.Contains("\__pycache__\")) { return $true }
    }
    if ($relative.StartsWith("_worker\") -and $extension -ne ".md") { return $true }
    if ($relative.StartsWith("_workhistory\") -and $extension -ne ".md") { return $true }

    if ($extension -in @(".srt", ".srt2")) { return $true }
    if ($extension -in @(".m3u", ".m3u8", ".wpl", ".pls")) { return $true }
    if ($relative.StartsWith("_conf\srt\")) { return $true }
    if ($relative.StartsWith("_conf\_capture\") -and $extension -in @(".jpg", ".jpeg")) { return $true }
    return $false
}

function Get-BackupCandidateFiles {
    param(
        [string]$RootPath,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        Get-ChildItem -LiteralPath $RootPath -File -Filter $pattern -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-BackupExcluded -File $_) }
    }
}

try {
    Write-Host "==== DropMp4 source backup ===="
    Write-Host "Target : $targetPath"
    Write-Host "Output : $zipPath"
    Write-Host ""

    # バックアップ対象
    # pyソース、ps1、アイコン、画像ファイル
    $patterns = @(
        "*.py",
        "*.ps1",
        "*.ico",
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.webp",
        "*.bmp",
        "*.gif",
        "*.bat",
        "*.spec"
    )

    $files = @()

    $files += Get-BackupCandidateFiles -RootPath $targetPath -Patterns $patterns

    $confDir = Join-Path $targetPath "_conf"
    if (Test-Path -LiteralPath $confDir) {
        $files += Get-ChildItem -LiteralPath $confDir -File -Recurse -ErrorAction SilentlyContinue
    }

    foreach ($historyDirName in @("_Worker", "_WorkHistory")) {
        $historyDir = Join-Path $targetPath $historyDirName
        if (Test-Path -LiteralPath $historyDir) {
            $files += Get-ChildItem -LiteralPath $historyDir -File -Filter "*.md" -Recurse -ErrorAction SilentlyContinue
        }
    }

    $pyInstallerAssetDir = Join-Path $targetPath "pyinstaller_assets"
    if (Test-Path -LiteralPath $pyInstallerAssetDir) {
        $files += Get-ChildItem -LiteralPath $pyInstallerAssetDir -File -Recurse -ErrorAction SilentlyContinue
    }

    # 重複除去と生成物除外
    $files = $files |
        Sort-Object FullName -Unique |
        Where-Object { -not (Test-BackupExcluded -File $_) }

    if (-not $files -or $files.Count -eq 0) {
        throw "バックアップ対象ファイルが見つかりませんでした。"
    }

    Write-Host "Backup files:"
    foreach ($file in $files) {
        $relative = Get-RelativePathFromTarget -File $file
        Write-Host "  $relative"
        $dest = Join-Path $tempRoot $relative
        $destDir = Split-Path -Parent $dest
        if ($destDir -and !(Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
    }

    # メモ情報も一緒に入れる
    $manifest = Join-Path $tempRoot "_backup_manifest.txt"
    @(
        "DropMp4 backup"
        "Created : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Source  : $targetPath"
        "Output  : $zipPath"
        ""
        "Files:"
        ($files | ForEach-Object { " - $(Get-RelativePathFromTarget -File $_)  $($_.Length) bytes  $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" })
    ) | Set-Content -LiteralPath $manifest -Encoding UTF8

    # 既存ZIPがあれば消す
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host ""
    Write-Host "Backup complete."
    Write-Host $zipPath
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
