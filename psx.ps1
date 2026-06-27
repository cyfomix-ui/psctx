#requires -version 5.1
$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $toolDir 'psctx.ps1') @args
exit $LASTEXITCODE
