<#
.SYNOPSIS
  Installs or updates the OJC scheme for ALL projects on this machine.

.DESCRIPTION
  Copies from this repo into ~/.claude:
    templates/ojc-workflow.md -> ~/.claude/ojc-workflow.md
    templates/agents/*.md     -> ~/.claude/agents/
    templates/scripts/jev-*   -> ~/.claude/scripts/ojc/
  and adds the line "@~/.claude/ojc-workflow.md" to ~/.claude/CLAUDE.md once,
  so Claude Code loads the workflow in every project. Existing content of
  ~/.claude/CLAUDE.md is kept. Safe to run again after every git pull.

.EXAMPLE
  .\templates\scripts\install-global.ps1
#>
$ErrorActionPreference = "Stop"

$templates = Resolve-Path (Join-Path $PSScriptRoot "..")
$claude = Join-Path $HOME ".claude"
$agentsDir = Join-Path $claude "agents"
$scriptsDir = Join-Path $claude "scripts\ojc"
New-Item -ItemType Directory -Force -Path $agentsDir, $scriptsDir | Out-Null

Copy-Item (Join-Path $templates "ojc-workflow.md") (Join-Path $claude "ojc-workflow.md") -Force
Copy-Item (Join-Path $templates "agents\*.md") $agentsDir -Force
Copy-Item (Join-Path $templates "scripts\jev-*.sh"), (Join-Path $templates "scripts\jev-*.ps1") $scriptsDir -Force

$globalMd = Join-Path $claude "CLAUDE.md"
$import = "@~/.claude/ojc-workflow.md"
$current = if (Test-Path $globalMd) { [IO.File]::ReadAllText($globalMd) } else { "" }
if ($current.Contains($import)) {
    Write-Host "Import line already in $globalMd"
} else {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $prefix = if ($current.Length -gt 0 -and -not $current.EndsWith("`n")) { "`r`n" } else { "" }
    [IO.File]::AppendAllText($globalMd, $prefix + $import + "`r`n", $utf8)
    Write-Host "Added import line to $globalMd"
}

Write-Host "Installed: $claude\ojc-workflow.md, agents, scripts\ojc"
Write-Host "Restart Claude Code sessions to load the new rules."
