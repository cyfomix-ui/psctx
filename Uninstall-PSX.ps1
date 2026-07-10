#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$main = Join-Path $toolDir 'PSX.Core.ps1'

if (-not (Test-Path -LiteralPath $main)) {
    throw "PSX.Core.ps1 was not found in: $toolDir"
}

& $main /removeprofile
