<#
.SYNOPSIS
  Replaces the "## Orchestration workflow" block in a project's CLAUDE.md with
  the one from this repo's templates/CLAUDE.md. Everything else in the
  project's file, including "## Project rules", is kept.

.EXAMPLE
  .\templates\scripts\update-claude-md.ps1 -Project "D:\1PythonProjects\my-project"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project
)

$ErrorActionPreference = "Stop"
$ordinal = [StringComparison]::Ordinal
$utf8 = New-Object System.Text.UTF8Encoding($false)
$lf = [string][char]10
$crlfStr = [string][char]13 + $lf

$templatePath = Join-Path $PSScriptRoot "..\CLAUDE.md"
$target = if (Test-Path $Project -PathType Container) { Join-Path $Project "CLAUDE.md" } else { $Project }

$blockHead = "## Orchestration workflow"
$rulesHead = "## Project rules"

$t = [IO.File]::ReadAllText((Resolve-Path $templatePath)).Replace($crlfStr, $lf)
$ts = $t.IndexOf($blockHead, $ordinal)
$tr = $t.IndexOf($rulesHead, $ordinal)
if ($ts -lt 0 -or $tr -lt $ts) { throw "templates/CLAUDE.md has no Orchestration workflow / Project rules sections" }
$block = $t.Substring($ts, $tr - $ts)
$rulesSection = $t.Substring($tr).TrimEnd([char]10) + $lf

if (Test-Path $target) {
    $raw = [IO.File]::ReadAllText($target)
    $useCrlf = $raw.Contains($crlfStr)
    $p = $raw.Replace($crlfStr, $lf)
    Copy-Item $target "$target.bak" -Force
} else {
    $useCrlf = $true
    $p = ""
}

$ps = $p.IndexOf($blockHead, $ordinal)
if ($ps -ge 0) {
    $head = $p.Substring(0, $ps)
    $next = $p.IndexOf($lf + "## ", $ps + 1, $ordinal)
    $rest = if ($next -lt 0) { "" } else { $p.Substring($next + 1) }
    if ($rest.StartsWith($rulesHead, $ordinal)) {
        $new = $head + $block + $rest
    } elseif ($rest -eq "") {
        $new = $head + $block + $rulesSection
    } else {
        $new = $head + $block + $rulesSection + $lf + $rest
    }
} elseif ($p.Trim() -eq "") {
    $new = $block + $rulesSection
} else {
    $new = $block + $rulesSection + $lf + $p
}

$new = $new.TrimEnd([char]10) + $lf
if ($useCrlf) { $new = $new.Replace($lf, $crlfStr) }
[IO.File]::WriteAllText($target, $new, $utf8)

Write-Host "Updated: $target"
if (Test-Path "$target.bak") { Write-Host "Backup:  $target.bak" }
