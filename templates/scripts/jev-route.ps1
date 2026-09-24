<#
.SYNOPSIS
  jev-route.ps1 — atomic Jev "choice" question: who should execute this
  subtask — the orchestrator itself, or one of the subagents.

.DESCRIPTION
  Native Windows/PowerShell equivalent of jev-route.sh. Jev only ANSWERS
  the question — it does not decide or execute anything. The calling agent
  acts on the answer and decides itself when the probability is low.

  Provider (JEV_PROVIDER): "openrouter" (OPENROUTER_API_KEY) or "direct"
  (JEV_API_KEY, thejevai.com). If JEV_PROVIDER is unset, the provider is
  picked by which key is present (OpenRouter wins if only it is set).

  Request/response format verified live against OpenRouter System One
  (POST /api/v1/systemone, model ~typesafe/jev-latest): questions carry
  "instructions" + "criteria"; for "choice", criteria is an object
  {option: description}. Answer: answers.route = {type, choice,
  probabilities, confidence}.

.EXAMPLE
  & "$HOME\.claude\scripts\ojc\jev-route.ps1" "rename variable X to Y in utils.ts"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Task
)

$language = if ($env:JEV_LANGUAGE) { $env:JEV_LANGUAGE } else { "en" }

$provider = $env:JEV_PROVIDER
if (-not $provider) {
    $provider = if ($env:OPENROUTER_API_KEY -and -not $env:JEV_API_KEY) { "openrouter" } else { "direct" }
}

switch ($provider) {
    "direct" {
        if (-not $env:JEV_API_KEY) {
            Write-Error "Set JEV_API_KEY (or OPENROUTER_API_KEY with JEV_PROVIDER=openrouter)"
            exit 1
        }
        $jevUrl     = "https://thejevai.com/v1/systemone"
        $jevAuthKey = $env:JEV_API_KEY
        $jevModel   = if ($env:JEV_MODEL) { $env:JEV_MODEL } else { "jev-latest" }
    }
    "openrouter" {
        if (-not $env:OPENROUTER_API_KEY) {
            Write-Error "Set OPENROUTER_API_KEY"
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

$body = [ordered]@{
    model     = $jevModel
    state     = [ordered]@{
        request_summary = $Task
        language        = $language
    }
    questions = [ordered]@{
        route = [ordered]@{
            type         = "choice"
            instructions = "Which executor fits this subtask?"
            criteria     = [ordered]@{
                "opus-self"                = "Architecture, complex or ambiguous work, debugging, algorithm design, synthesis"
                "ojc-boilerplate-executor" = "Mechanical or routine work: boilerplate, tests, formatting, running builds/tests/linters"
                "ojc-quick-helper"         = "Trivial, cheap lookup or one-line edit"
            }
        }
    }
} | ConvertTo-Json -Depth 8

try {
    $response = Invoke-RestMethod -Uri $jevUrl `
        -Method Post `
        -Headers @{ Authorization = "Bearer $jevAuthKey" } `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
}
catch {
    Write-Error "Jev request failed: $($_.Exception.Message)"
    exit 1
}

$response | ConvertTo-Json -Depth 8
