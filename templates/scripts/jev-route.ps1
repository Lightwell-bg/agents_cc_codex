<#
.SYNOPSIS
  jev-route.ps1 — atomic Jev "choice" question: who should execute this
  subtask — the orchestrator itself, or one of the subagents.

.DESCRIPTION
  Native Windows/PowerShell equivalent of jev-route.sh, for machines without
  WSL or Git Bash. Jev only ANSWERS the question — it does not decide or
  execute anything. Apply the answer yourself, with a low-confidence
  fallback to your own judgement.

  NOTE: endpoint, model id and question/state shape follow the vendor's
  "Jev AI API & AI Agents" guide (POST .../v1/systemone, model jev-latest,
  {state, questions}). Exact response field names are illustrative — verify
  against https://thejevai.com/docs before relying on this in production.

.PARAMETER Task
  Short description of the subtask to route.

.EXAMPLE
  $env:JEV_API_KEY = "..."
  .\jev-route.ps1 "rename variable X to Y in utils.ts"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Task
)

if (-not $env:JEV_API_KEY) {
    Write-Error "Set JEV_API_KEY first, e.g.: `$env:JEV_API_KEY = 'your-key'"
    exit 1
}

$language = if ($env:JEV_LANGUAGE) { $env:JEV_LANGUAGE } else { "en" }

$body = @{
    model     = "jev-latest"
    state     = @{
        request_summary = $Task
        language         = $language
    }
    questions = @{
        route = @{
            type    = "choice"
            options = @("opus-self", "boilerplate-executor", "quick-helper")
            prompt  = "Which route fits this subtask: opus-self (architecture, complex/ambiguous work, synthesis), boilerplate-executor (mechanical/routine work), or quick-helper (trivial/cheap lookups)?"
        }
    }
} | ConvertTo-Json -Depth 6

try {
    $response = Invoke-RestMethod -Uri "https://thejevai.com/v1/systemone" `
        -Method Post `
        -Headers @{ Authorization = "Bearer $($env:JEV_API_KEY)" } `
        -ContentType "application/json" `
        -Body $body
}
catch {
    Write-Error "Jev request failed: $($_.Exception.Message)"
    exit 1
}

$response | ConvertTo-Json -Depth 6
