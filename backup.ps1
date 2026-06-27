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
$projectName = Split-Path -Leaf $targetPath
if (-not $projectName) {
    $projectName = "backup"
}
$safeProjectName = ($projectName -replace '[<>:"/\\|?*]', "_")
$zipName = "${safeProjectName}_$stamp.zip"
$zipPath = Join-Path $backupDir $zipName

# 一時作業フォルダ
$tempRoot = Join-Path $env:TEMP "${safeProjectName}_backup_$stamp"
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
        ".pslocal\",
        ".venv\",
        "venv\",
        "--x\",
        "__pycache__\",
        "__oldsource\",
        "oldsource\",
        "backup\",
        "build\",
        "dist\",
        "_worker\",
        "_workhistory\",
        "_workerarchive\",
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
    if ($relative -in @("agents.md", ".psctx.ps1")) { return $true }
    if ($relative -like ".psctx.ps1.disabled_*") { return $true }

    if ($extension -in @(".srt", ".srt2")) { return $true }
    if ($extension -in @(".m3u", ".m3u8", ".wpl", ".pls")) { return $true }
    if ($extension -eq ".zip") { return $true }
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
    Write-Host "==== Project source backup ===="
    Write-Host "Target : $targetPath"
    Write-Host "Output : $zipPath"
    Write-Host ""

    # バックアップ対象
    # スクリプト、ドキュメント、設定、画像ファイル
    $patterns = @(
        "*.py",
        "*.ps1",
        "*.psm1",
        "*.psd1",
        "*.cmd",
        "*.md",
        "*.txt",
        "*.json",
        "*.yml",
        "*.yaml",
        "*.xml",
        "*.ico",
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.webp",
        "*.bmp",
        "*.gif",
        "*.bat",
        "*.spec",
        "LICENSE"
    )

    $files = @()

    $files += Get-BackupCandidateFiles -RootPath $targetPath -Patterns $patterns

    $confDir = Join-Path $targetPath "_conf"
    if (Test-Path -LiteralPath $confDir) {
        $files += Get-ChildItem -LiteralPath $confDir -File -Recurse -ErrorAction SilentlyContinue
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
        "$projectName backup"
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
