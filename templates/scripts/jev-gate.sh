#!/usr/bin/env bash
# jev-gate.sh — cheap first check before a potentially risky tool call.
#
# This is step 2 of the 5-step guardrail order, NOT the final authority:
#   1. normalize tool name + arguments            (caller's job)
#   2. ask Jev a narrow risk/approval question     (this script)
#   3. run deterministic allowlist + permission check (caller's job, after this)
#   4. ambiguous cases -> escalate to confirmation/human
#   5. execute with an idempotency key + audit log
#
# Jev never authorizes the action by itself. For destructive or external
# actions, require agreement from several controls (this score/noul answer
# AND the deterministic allowlist/permission check), not a single
# probability threshold.
#
# Usage:
#   JEV_API_KEY=... ./jev-gate.sh "rm -rf build/" "Bash"
#
# NOTE: endpoint/model/shape per the vendor guide (POST .../v1/systemone,
# model jev-latest). Verify exact response field names against
# https://thejevai.com/docs before relying on this in production.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 \"<proposed command/args>\" \"<tool name>\"" >&2
  exit 1
fi

ARGS="$1"
TOOL="$2"
: "${JEV_API_KEY:?set JEV_API_KEY}"
LANG_HINT="${JEV_LANGUAGE:-en}"

STATE_JSON=$(python3 - "$ARGS" "$TOOL" "$LANG_HINT" <<'PY'
import json, sys
args, tool, lang = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "proposed_tool": tool,
    "proposed_arguments": args,
    "language": lang,
}))
PY
)

# route + risk + human-review computed in one call, against one state
curl -sS https://thejevai.com/v1/systemone \
  -H "Authorization: Bearer ${JEV_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"jev-latest\",
    \"state\": ${STATE_JSON},
    \"questions\": {
      \"risk\": {
        \"type\": \"score\",
        \"scale\": [\"low\", \"medium\", \"high\", \"critical\"],
        \"prompt\": \"How severe would it be if this tool call executed against unintended state?\"
      },
      \"needs_human_review\": {
        \"type\": \"noul\",
        \"statement\": \"This tool call should be approved by a human before it runs.\"
      }
    }
  }"

# Caller MUST still apply its own deterministic allowlist/permission check
# (step 3) and escalate on ambiguity (step 4) before executing (step 5).
# A confident low-risk answer here is a signal, not a decision.
