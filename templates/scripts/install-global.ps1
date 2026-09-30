<#
.SYNOPSIS
  Installs or updates the OJC scheme for ALL projects on this machine.

.DESCRIPTION
  - Puts the Orchestration workflow block from templates/CLAUDE.md into the
    global ~/.claude/CLAUDE.md, between <!-- OJC:START --> and
    <!-- OJC:END -->. On an update only that block is replaced; the rest of
    the file (your own global rules) is kept. Backup: CLAUDE.md.bak.
  - Replaces an old "@~/.claude/ojc-workflow.md" import line with the block
    and deletes ~/.claude/ojc-workflow.md if present.
  - Copies subagents to ~/.claude/agents/ and Jev scripts to
    ~/.claude/scripts/ojc/.
  Safe to run again after every git pull.

.EXAMPLE
  .\templates\scripts\install-global.ps1
#>
$ErrorActionPreference = "Stop"
$ordinal = [StringComparison]::Ordinal
$lf = [string][char]10
$crlfStr = [string][char]13 + $lf
$utf8 = New-Object System.Text.UTF8Encoding($false)

$templates = Resolve-Path (Join-Path $PSScriptRoot "..")
$claude = Join-Path $HOME ".claude"
$agentsDir = Join-Path $claude "agents"
$scriptsDir = Join-Path $claude "scripts\ojc"
New-Item -ItemType Directory -Force -Path $agentsDir, $scriptsDir | Out-Null

Copy-Item (Join-Path $templates "agents\*.md") $agentsDir -Force
Copy-Item (Join-Path $templates "scripts\jev-*.sh"), (Join-Path $templates "scripts\jev-*.ps1") $scriptsDir -Force

$startMark = "<!-- OJC:START -->"
$endMark = "<!-- OJC:END -->"
$oldImport = "@~/.claude/ojc-workflow.md"

$block = [IO.File]::ReadAllText((Join-Path $templates "CLAUDE.md")).Replace($crlfStr, $lf).Trim([char]10)

$globalMd = Join-Path $claude "CLAUDE.md"
if (Test-Path $globalMd) {
    $raw = [IO.File]::ReadAllText($globalMd)
    $useCrlf = $raw.Contains($crlfStr) -or -not $raw.Contains($lf)
    $g = $raw.Replace($crlfStr, $lf)
    Copy-Item $globalMd "$globalMd.bak" -Force
} else {
    $useCrlf = $true
    $g = ""
}

$s = $g.IndexOf($startMark, $ordinal)
$e = $g.IndexOf($endMark, $ordinal)
if ($s -ge 0 -and $e -gt $s) {
    $new = $g.Substring(0, $s) + $block + $g.Substring($e + $endMark.Length)
    $action = "Updated the OJC block in"
} elseif ($g.Contains($oldImport)) {
    $new = $g.Replace($oldImport, $block)
    $action = "Replaced the old import line with the OJC block in"
} elseif ($g.Trim() -eq "") {
    $new = $block
    $action = "Created"
} else {
    $new = $g.TrimEnd([char]10) + $lf + $lf + $block
    $action = "Appended the OJC block to"
}

$new = $new.TrimEnd([char]10) + $lf
if ($useCrlf) { $new = $new.Replace($lf, $crlfStr) }
[IO.File]::WriteAllText($globalMd, $new, $utf8)
Write-Host "$action $globalMd"
if (Test-Path "$globalMd.bak") { Write-Host "Backup: $globalMd.bak" }

$oldFile = Join-Path $claude "ojc-workflow.md"
if (Test-Path $oldFile) {
    Remove-Item $oldFile
    Write-Host "Deleted old $oldFile"
}

Write-Host "Agents and Jev scripts copied. Restart Claude Code sessions."
