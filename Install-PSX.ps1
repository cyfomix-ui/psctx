#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$main = Join-Path $toolDir 'PSX.Core.ps1'

if (-not (Test-Path -LiteralPath $main)) {
    throw "PSX.Core.ps1 was not found in: $toolDir"
}

& $main /installtool

Write-Host ''
Write-Host 'Install completed.' -ForegroundColor Green
Write-Host 'Next step:'
Write-Host '  . $PROFILE'
Write-Host ''
Write-Host 'Then register a project, for example:'
Write-Host '  psx D:\tools\SampleProject'
Write-Host '  psx /uninst D:\tools\SampleProject'
