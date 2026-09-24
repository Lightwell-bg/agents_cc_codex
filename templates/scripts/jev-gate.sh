#!/usr/bin/env bash
# jev-gate.sh — cheap first check before a potentially risky tool call.
#
# This is step 2 of the 5-step guardrail order, NOT the final authority:
#   1. normalize tool name + arguments               (caller's job)
#   2. ask Jev a narrow risk/approval question        (this script)
#   3. run deterministic allowlist + permission check (caller's job, after this)
#   4. ambiguous cases -> escalate to confirmation/human
#   5. execute with an idempotency key + audit log
#
# Jev never authorizes the action by itself. For destructive or external
# actions, require agreement from several controls, not a single
# probability threshold.
#
# Usage:
#   ~/.claude/scripts/ojc/jev-gate.sh "rm -rf build/" "Bash"
#
# Provider selection: same as jev-route.sh (JEV_PROVIDER, or auto by key).
#
# Format verified live against OpenRouter System One: "score" takes
# "criteria" as an ordered array of levels, "noul" takes only
# "instructions". Answers:
#   answers.risk               -> {"type":"score","score":<0..3>,"confidence":...}
#   answers.needs_human_review -> {"type":"noul","noul":<0..1>}
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 \"<proposed command/args>\" \"<tool name>\"" >&2
  exit 1
fi

ARGS="$1"
TOOL="$2"
LANG_HINT="${JEV_LANGUAGE:-en}"

PROVIDER="${JEV_PROVIDER:-}"
if [[ -z "$PROVIDER" ]]; then
  if [[ -n "${OPENROUTER_API_KEY:-}" && -z "${JEV_API_KEY:-}" ]]; then
    PROVIDER=openrouter
  else
    PROVIDER=direct
  fi
fi

case "$PROVIDER" in
  direct)
    : "${JEV_API_KEY:?set JEV_API_KEY (or OPENROUTER_API_KEY with JEV_PROVIDER=openrouter)}"
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

BODY=$(python3 - "$JEV_MODEL" "$ARGS" "$TOOL" "$LANG_HINT" <<'PY'
import json, sys
model, args, tool, lang = sys.argv[1:5]
print(json.dumps({
    "model": model,
    "state": {"proposed_tool": tool, "proposed_arguments": args, "language": lang},
    "questions": {
        "risk": {
            "type": "score",
            "instructions": "How severe would it be if this tool call executed against unintended state?",
            "criteria": ["low", "medium", "high", "critical"],
        },
        "needs_human_review": {
            "type": "noul",
            "instructions": "Should a human approve this tool call before it runs?",
        },
    },
}))
PY
)

# risk + human-review computed in one call, against one state.
curl -sS "$JEV_URL" \
  -H "Authorization: Bearer ${JEV_AUTH_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY"
echo

# Caller MUST still apply its own deterministic allowlist/permission check
# (step 3) and escalate on ambiguity (step 4) before executing (step 5).
