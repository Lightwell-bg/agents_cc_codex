#!/usr/bin/env bash
# jev-route.sh — atomic Jev "choice" question: who should execute this
# subtask — the orchestrator itself, or one of the subagents.
#
# Jev only ANSWERS the question. It does not decide or execute anything —
# this script (and, above it, the calling agent) is what actually acts on
# the answer, with a low-confidence fallback to human/self judgement.
#
# Usage:
#   JEV_API_KEY=... ./jev-route.sh "rename variable X to Y in utils.ts"
#
# NOTE: this uses the endpoint, model id and question/state shape described
# in the vendor's "Jev AI API & AI Agents" guide (POST .../v1/systemone,
# model jev-latest, {state, questions}). The exact response field names are
# illustrative — verify against https://thejevai.com/docs before relying on
# this in production; APIs like this version faster than local scripts do.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 \"<subtask description>\"" >&2
  exit 1
fi

TASK="$1"
: "${JEV_API_KEY:?set JEV_API_KEY}"
LANG_HINT="${JEV_LANGUAGE:-en}"

STATE_JSON=$(python3 - "$TASK" "$LANG_HINT" <<'PY'
import json, sys
task, lang = sys.argv[1], sys.argv[2]
print(json.dumps({"request_summary": task, "language": lang}))
PY
)

curl -sS https://thejevai.com/v1/systemone \
  -H "Authorization: Bearer ${JEV_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"jev-latest\",
    \"state\": ${STATE_JSON},
    \"questions\": {
      \"route\": {
        \"type\": \"choice\",
        \"options\": [\"opus-self\", \"boilerplate-executor\", \"quick-helper\"],
        \"prompt\": \"Which route fits this subtask: opus-self (architecture, complex/ambiguous work, synthesis), boilerplate-executor (mechanical/routine work), or quick-helper (trivial/cheap lookups)?\"
      }
    }
  }"
