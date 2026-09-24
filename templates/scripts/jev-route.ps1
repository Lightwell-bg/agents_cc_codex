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
  # Direct TypeSafe access (default)
  $env:JEV_API_KEY = "..."
  .\jev-route.ps1 "rename variable X to Y in utils.ts"

.EXAMPLE
  # Via an OpenRouter key instead — see README §11.5. Unverified in this
  # repo's own session (openrouter.ai was unreachable); confirm the path
  # and model slug at https://openrouter.ai/typesafe before relying on it.
  $env:JEV_PROVIDER = "openrouter"
  $env:OPENROUTER_API_KEY = "sk-or-v1-..."
  .\jev-route.ps1 "rename variable X to Y in utils.ts"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Task
)

$provider = if ($env:JEV_PROVIDER) { $env:JEV_PROVIDER } else { "direct" }
$language = if ($env:JEV_LANGUAGE) { $env:JEV_LANGUAGE } else { "en" }

switch ($provider) {
    "direct" {
        if (-not $env:JEV_API_KEY) {
            Write-Error "Set JEV_API_KEY first, e.g.: `$env:JEV_API_KEY = 'your-key'"
            exit 1
        }
        $jevUrl     = "https://thejevai.com/v1/systemone"
        $jevAuthKey = $env:JEV_API_KEY
        $jevModel   = if ($env:JEV_MODEL) { $env:JEV_MODEL } else { "jev-latest" }
    }
    "openrouter" {
        if (-not $env:OPENROUTER_API_KEY) {
            Write-Error "Set OPENROUTER_API_KEY first, e.g.: `$env:OPENROUTER_API_KEY = 'sk-or-v1-...'"
            exit 1
        }
        $jevUrl     = "https://openrouter.ai/api/v1/systemone"
        $jevAuthKey = $env:OPENROUTER_API_KEY
        $jevModel   = if ($env:JEV_MODEL) { $env:JEV_MODEL } else { "~typesafe/jev-latest" }
    }
    default {
        Write-Error "Unknown JEV_PROVIDER: $provider (expected 'direct' or 'openrouter')"
        exit 1
    }
}

$body = @{
    model     = $jevModel
    state     = @{
        request_summary = $Task
        language         = $language
    }
    questions = @{
        route = @{
            type    = "choice"
            options = @("opus-self", "ojc-boilerplate-executor", "ojc-quick-helper")
            prompt  = "Which route fits this subtask: opus-self (architecture, complex/ambiguous work, synthesis), ojc-boilerplate-executor (mechanical/routine work), or ojc-quick-helper (trivial/cheap lookups)?"
        }
    }
} | ConvertTo-Json -Depth 6

try {
    $response = Invoke-RestMethod -Uri $jevUrl `
        -Method Post `
        -Headers @{ Authorization = "Bearer $jevAuthKey" } `
        -ContentType "application/json" `
        -Body $body
}
catch {
    Write-Error "Jev request failed: $($_.Exception.Message)"
    exit 1
}

$response | ConvertTo-Json -Depth 6
