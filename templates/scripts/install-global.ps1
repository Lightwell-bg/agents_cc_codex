<#
.SYNOPSIS
  Copies the shared tools of the OJC scheme into ~/.claude:
  subagents -> ~/.claude/agents/, Jev scripts -> ~/.claude/scripts/ojc/.
  Does not touch any CLAUDE.md. Safe to run again after every git pull.

.EXAMPLE
  .\templates\scripts\install-global.ps1
#>
$ErrorActionPreference = "Stop"

$templates = Resolve-Path (Join-Path $PSScriptRoot "..")
$claude = Join-Path $HOME ".claude"
$agentsDir = Join-Path $claude "agents"
$scriptsDir = Join-Path $claude "scripts\ojc"
New-Item -ItemType Directory -Force -Path $agentsDir, $scriptsDir | Out-Null

Copy-Item (Join-Path $templates "agents\*.md") $agentsDir -Force
Copy-Item (Join-Path $templates "scripts\jev-*.sh"), (Join-Path $templates "scripts\jev-*.ps1") $scriptsDir -Force

Write-Host "Copied subagents to $agentsDir and Jev scripts to $scriptsDir"
