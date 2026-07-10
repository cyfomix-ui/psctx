#requires -version 5.1
$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $toolDir 'PSX.Core.ps1') @args
exit $LASTEXITCODE
