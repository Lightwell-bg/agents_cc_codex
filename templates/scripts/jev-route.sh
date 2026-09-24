#!/usr/bin/env bash
# jev-route.sh — cheap Jev (typesafe/jev) decision: who should execute this
# subtask — the orchestrator itself, or one of the subagents.
#
# Usage:
#   OPENROUTER_API_KEY=sk-or-v1-... ./jev-route.sh "rename variable X to Y in utils.ts"
#
# Prints the raw JSON response from the OpenRouter Decisions API, e.g.:
#   {"choice":"boilerplate-executor","confidence":4.1}
#
# NOTE: verify the exact request/response schema against the current docs
# before relying on this in production — decision-model APIs version faster
# than this file does: https://openrouter.ai/docs/guides/community/jev
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 \"<subtask description>\"" >&2
  exit 1
fi

TASK="$1"
: "${OPENROUTER_API_KEY:?set OPENROUTER_API_KEY}"

CONTEXT_JSON=$(printf '%s' "$TASK" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

curl -sS https://openrouter.ai/api/alpha/decisions \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"typesafe/jev-1.13\",
    \"question\": {
      \"type\": \"choice\",
      \"options\": [\"opus-self\", \"boilerplate-executor\", \"quick-helper\"],
      \"text\": \"Who should execute this subtask: the orchestrator itself (complex/architectural/ambiguous), the boilerplate-executor subagent (mechanical/routine), or the quick-helper subagent (trivial/cheap)?\"
    },
    \"context\": ${CONTEXT_JSON}
  }"
