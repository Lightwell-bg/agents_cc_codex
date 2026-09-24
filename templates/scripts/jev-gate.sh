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
# Usage (direct TypeSafe access, default):
#   JEV_API_KEY=... ./jev-gate.sh "rm -rf build/" "Bash"
#
# Usage (via an OpenRouter key instead — see README §11.5):
#   JEV_PROVIDER=openrouter OPENROUTER_API_KEY=sk-or-v1-... \
#     ./jev-gate.sh "rm -rf build/" "Bash"
#
# NOTE: endpoint/model/shape per the vendor guide (POST .../v1/systemone,
# model jev-latest). Verify exact response field names against
# https://thejevai.com/docs before relying on this in production. The
# OpenRouter path/model slug is unverified in this repo's own session
# (openrouter.ai was unreachable) — confirm at https://openrouter.ai/typesafe.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 \"<proposed command/args>\" \"<tool name>\"" >&2
  exit 1
fi

ARGS="$1"
TOOL="$2"
PROVIDER="${JEV_PROVIDER:-direct}"
LANG_HINT="${JEV_LANGUAGE:-en}"

case "$PROVIDER" in
  direct)
    : "${JEV_API_KEY:?set JEV_API_KEY}"
    JEV_URL="https://thejevai.com/v1/systemone"
    JEV_AUTH_KEY="$JEV_API_KEY"
    JEV_MODEL="${JEV_MODEL:-jev-latest}"
    ;;
  openrouter)
    : "${OPENROUTER_API_KEY:?set OPENROUTER_API_KEY}"
    JEV_URL="https://openrouter.ai/api/v1/systemone"
    JEV_AUTH_KEY="$OPENROUTER_API_KEY"
    JEV_MODEL="${JEV_MODEL:-~typesafe/jev-latest}"
    ;;
  *)
    echo "unknown JEV_PROVIDER: $PROVIDER (expected 'direct' or 'openrouter')" >&2
    exit 1
    ;;
esac

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
curl -sS "$JEV_URL" \
  -H "Authorization: Bearer ${JEV_AUTH_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${JEV_MODEL}\",
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
