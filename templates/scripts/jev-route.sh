#!/usr/bin/env bash
# jev-route.sh — atomic Jev "choice" question: who should execute this
# subtask — the orchestrator itself, or one of the subagents.
#
# Jev only ANSWERS the question. It does not decide or execute anything —
# this script (and, above it, the calling agent) is what actually acts on
# the answer, with a low-confidence fallback to human/self judgement.
#
# Usage (direct TypeSafe access, default):
#   JEV_API_KEY=... ./jev-route.sh "rename variable X to Y in utils.ts"
#
# Usage (via an OpenRouter key instead — see README §11.5):
#   JEV_PROVIDER=openrouter OPENROUTER_API_KEY=sk-or-v1-... \
#     ./jev-route.sh "rename variable X to Y in utils.ts"
#
# NOTE: this uses the endpoint, model id and question/state shape described
# in the vendor's "Jev AI API & AI Agents" guide (POST .../v1/systemone,
# model jev-latest, {state, questions}). The exact response field names are
# illustrative — verify against https://thejevai.com/docs before relying on
# this in production; APIs like this version faster than local scripts do.
# The OpenRouter path/model slug below is unverified in this repo's own
# session (openrouter.ai was unreachable) — confirm against
# https://openrouter.ai/typesafe and https://openrouter.ai/docs/guides/community/jev.
# If it 404s, OpenRouter's separate Decisions API (POST /api/alpha/decisions)
# is a documented working alternative but uses a different wire format.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 \"<subtask description>\"" >&2
  exit 1
fi

TASK="$1"
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
    JEV_MODEL="${JEV_MODEL:-typesafe/jev-latest}"
    ;;
  *)
    echo "unknown JEV_PROVIDER: $PROVIDER (expected 'direct' or 'openrouter')" >&2
    exit 1
    ;;
esac

STATE_JSON=$(python3 - "$TASK" "$LANG_HINT" <<'PY'
import json, sys
task, lang = sys.argv[1], sys.argv[2]
print(json.dumps({"request_summary": task, "language": lang}))
PY
)

curl -sS "$JEV_URL" \
  -H "Authorization: Bearer ${JEV_AUTH_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${JEV_MODEL}\",
    \"state\": ${STATE_JSON},
    \"questions\": {
      \"route\": {
        \"type\": \"choice\",
        \"options\": [\"opus-self\", \"ojc-boilerplate-executor\", \"ojc-quick-helper\"],
        \"prompt\": \"Which route fits this subtask: opus-self (architecture, complex/ambiguous work, synthesis), ojc-boilerplate-executor (mechanical/routine work), or ojc-quick-helper (trivial/cheap lookups)?\"
      }
    }
  }"
