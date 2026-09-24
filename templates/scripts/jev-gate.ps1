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
  actions, require agreement from several controls (this score/noul answer
  AND the deterministic allowlist/permission check), not a single
  probability threshold.

  NOTE: endpoint/model/shape per the vendor guide. Verify exact response
  field names against https://thejevai.com/docs before relying on this in
  production.

.PARAMETER ProposedArguments
  The proposed command or arguments for the tool call.

.PARAMETER ToolName
  Name of the tool being gated (e.g. "Bash", "Write").

.EXAMPLE
  $env:JEV_API_KEY = "..."
  .\jev-gate.ps1 -ProposedArguments "rm -rf build/" -ToolName "Bash"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProposedArguments,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ToolName
)

if (-not $env:JEV_API_KEY) {
    Write-Error "Set JEV_API_KEY first, e.g.: `$env:JEV_API_KEY = 'your-key'"
    exit 1
}

$language = if ($env:JEV_LANGUAGE) { $env:JEV_LANGUAGE } else { "en" }

$body = @{
    model     = "jev-latest"
    state     = @{
        proposed_tool      = $ToolName
        proposed_arguments = $ProposedArguments
        language           = $language
    }
    questions = @{
        risk               = @{
            type   = "score"
            scale  = @("low", "medium", "high", "critical")
            prompt = "How severe would it be if this tool call executed against unintended state?"
        }
        needs_human_review = @{
            type      = "noul"
            statement = "This tool call should be approved by a human before it runs."
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

# Caller MUST still apply its own deterministic allowlist/permission check
# (step 3) and escalate on ambiguity (step 4) before executing (step 5).
# A confident low-risk answer here is a signal, not a decision.
