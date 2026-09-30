<#
.SYNOPSIS
  Removes an old per-project copy of the "## Orchestration workflow" block
  from a project's CLAUDE.md, now that the workflow is loaded globally.

.DESCRIPTION
  Keeps "## Project rules" and anything else in the file. If nothing but an
  empty "## Project rules" section is left, deletes the file. A backup is
  saved as CLAUDE.md.bak next to it.

.EXAMPLE
  .\templates\scripts\remove-old-workflow-copy.ps1 -Project "D:\1PythonProjects\my-project"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project
)

$ErrorActionPreference = "Stop"
$ordinal = [StringComparison]::Ordinal
$lf = [string][char]10
$crlfStr = [string][char]13 + $lf
$utf8 = New-Object System.Text.UTF8Encoding($false)

$target = if (Test-Path $Project -PathType Container) { Join-Path $Project "CLAUDE.md" } else { $Project }
if (-not (Test-Path $target)) { Write-Host "No CLAUDE.md in $Project - nothing to do."; exit 0 }

$raw = [IO.File]::ReadAllText($target)
$useCrlf = $raw.Contains($crlfStr)
$p = $raw.Replace($crlfStr, $lf)

$blockHead = "## Orchestration workflow"
$start = $p.IndexOf($blockHead, $ordinal)
if ($start -lt 0) { Write-Host "No Orchestration workflow block in $target - nothing to do."; exit 0 }

Copy-Item $target "$target.bak" -Force
$next = $p.IndexOf($lf + "## ", $start + 1, $ordinal)
$rest = if ($next -lt 0) { "" } else { $p.Substring($next + 1) }
$new = $p.Substring(0, $start) + $rest

$placeholder = "<!-- Rules specific to this project."
$ph = $new.IndexOf($placeholder, $ordinal)
if ($ph -ge 0) {
    $phEnd = $new.IndexOf("-->", $ph, $ordinal)
    if ($phEnd -ge 0) { $new = $new.Substring(0, $ph) + $new.Substring($phEnd + 3) }
}

$meaningful = $new.Replace("## Project rules", "").Trim()
if ($meaningful -eq "") {
    Remove-Item $target
    Write-Host "Deleted $target (it held only the old block). Backup: $target.bak"
    exit 0
}

$new = [regex]::Replace($new, "\n{3,}", $lf + $lf)
$new = $new.Trim([char]10) + $lf
if ($useCrlf) { $new = $new.Replace($lf, $crlfStr) }
[IO.File]::WriteAllText($target, $new, $utf8)
Write-Host "Removed the old block from $target, kept the rest. Backup: $target.bak"
