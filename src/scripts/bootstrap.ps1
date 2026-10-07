# One-time (or anytime) setup for a fresh clone: deps + Git hooks.
# Usage: .\src\scripts\bootstrap.ps1
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

Write-Host "==> uv sync"
uv sync

Write-Host "==> Git hooks"
& "$Root\.githooks\install.ps1"

Write-Host "OK: bootstrap complete"
