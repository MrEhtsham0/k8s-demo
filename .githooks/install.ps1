# Enable this repo's Git hooks for the current clone (local config only).
# Safe to re-run.
#
#   .\.githooks\install.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $Root ".git"))) {
    # worktree / normal clone: .git may be a file; still require git
}
Set-Location $Root

git rev-parse --is-inside-work-tree | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "not inside a git repository."
    exit 1
}

git config --local core.hooksPath .githooks
$current = git config --local --get core.hooksPath
Write-Host "OK: core.hooksPath → $current"
Write-Host "    Hooks are active for this clone only (each clone runs install once)."
Write-Host "    Tip: new teammates can run: .\src\scripts\bootstrap.ps1"
