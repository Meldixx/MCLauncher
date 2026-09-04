$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$SafePatcher = Join-Path $Root 'apply-ui-fixes.ps1'
if (-not (Test-Path -LiteralPath $SafePatcher -PathType Leaf)) {
    throw 'apply-ui-fixes.ps1 was not found. Run git pull.'
}
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $SafePatcher
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
