#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$main = Join-Path $toolDir 'psctx.ps1'

if (-not (Test-Path -LiteralPath $main)) {
    throw "psctx.ps1 was not found in: $toolDir"
}

& $main /removeprofile
