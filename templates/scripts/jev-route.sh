#!/usr/bin/env bash
# jev-route.sh — atomic Jev "choice" question: who should execute this
# subtask — the orchestrator itself, or one of the subagents.
#
# Jev only ANSWERS the question. It does not decide or execute anything —
# the calling agent acts on the answer, and decides itself when the
# probability is low.
#
# Usage:
#   ~/.claude/scripts/ojc/jev-route.sh "rename variable X to Y in utils.ts"
#
# Provider (JEV_PROVIDER): "openrouter" (OPENROUTER_API_KEY) or "direct"
# (JEV_API_KEY, thejevai.com). If JEV_PROVIDER is unset, the provider is
# picked by which key is present (OpenRouter wins if only it is set).
#
# Request/response format verified live against OpenRouter System One
# (POST /api/v1/systemone, model ~typesafe/jev-latest): questions carry
# "instructions" + "criteria"; for "choice", criteria is an object
# {option: description}. The answer comes back as
#   {"answers":{"route":{"type":"choice","choice":"...","probabilities":{...},"confidence":...}}, ...}
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 \"<subtask description>\"" >&2
  exit 1
fi

TASK="$1"
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

BODY=$(python3 - "$JEV_MODEL" "$TASK" "$LANG_HINT" <<'PY'
import json, sys
model, task, lang = sys.argv[1:4]
print(json.dumps({
    "model": model,
    "state": {"request_summary": task, "language": lang},
    "questions": {
        "route": {
            "type": "choice",
            "instructions": "Which executor fits this subtask?",
            "criteria": {
                "opus-self": "Architecture, complex or ambiguous work, debugging, algorithm design, synthesis",
                "ojc-boilerplate-executor": "Mechanical or routine work: boilerplate, tests, formatting, running builds/tests/linters",
                "ojc-quick-helper": "Trivial, cheap lookup or one-line edit",
            },
        }
    },
}))
PY
)

curl -sS "$JEV_URL" \
  -H "Authorization: Bearer ${JEV_AUTH_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY"
echo
