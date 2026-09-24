<#
.SYNOPSIS
  jev-gate.ps1 — cheap first check before a potentially risky tool call.

.DESCRIPTION
  Native Windows/PowerShell equivalent of jev-gate.sh. This is step 2 of the
  5-step guardrail order, NOT the final authority:
    1. normalize tool name + arguments               (caller's job)
    2. ask Jev a narrow risk/approval question        (this script)
    3. run deterministic allowlist + permission check (caller's job, after this)
    4. ambiguous cases -> escalate to confirmation/human
    5. execute with an idempotency key + audit log

  Jev never authorizes the action by itself. For destructive or external
  actions, require agreement from several controls, not a single
  probability threshold.

  Provider selection: same as jev-route.ps1 (JEV_PROVIDER, or auto by key).

  Format verified live against OpenRouter System One: "score" takes
  "criteria" as an ordered array of levels, "noul" takes only
  "instructions". Answers: answers.risk = {type, score, confidence},
  answers.needs_human_review = {type, noul}.

.EXAMPLE
  & "$HOME\.claude\scripts\ojc\jev-gate.ps1" -ProposedArguments "rm -rf build/" -ToolName "Bash"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProposedArguments,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ToolName
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
        proposed_tool      = $ToolName
        proposed_arguments = $ProposedArguments
        language           = $language
    }
    questions = [ordered]@{
        risk               = [ordered]@{
            type         = "score"
            instructions = "How severe would it be if this tool call executed against unintended state?"
            criteria     = @("low", "medium", "high", "critical")
        }
        needs_human_review = [ordered]@{
            type         = "noul"
            instructions = "Should a human approve this tool call before it runs?"
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

# Caller MUST still apply its own deterministic allowlist/permission check
# (step 3) and escalate on ambiguity (step 4) before executing (step 5).
