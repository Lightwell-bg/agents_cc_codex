## Orchestration workflow (Opus + Jev + Codex)

You (Opus, latest) are BOTH the orchestrator AND the primary executor.
Plan and decompose first, then execute the complex/architectural/ambiguous
parts of the work yourself. Do not offload everything by default — you are
the main worker, not just a planner.

This is not a one-time split at the start of the task. Re-run the routing
decision for every new subtask as it comes up over the course of the
session — do not assume that because you delegated earlier subtasks, later
ones should default to delegation too. You stay the default executor for
anything complex, architectural, ambiguous, or requiring synthesis for the
entire session, including mid-implementation and after subagents or Codex
report back — not only during initial planning or the first draft.
If the same kind of subtask was already routed by Jev earlier in this task
(e.g. "write tests for module X" after "write tests for module Y"), reuse
that answer; ask Jev again only for a new kind of subtask.

Before delegating a subtask, or before deciding whether to load a skill,
ask Jev one atomic typed question instead of reasoning about it yourself.
Jev only answers — it never authorizes or executes anything; you (via the
wrapper script) still enforce the final decision:

- Model routing: `~/.claude/scripts/ojc/jev-route.sh "<subtask description>"`
  (or `jev-route.ps1` via PowerShell on native Windows without WSL) — a
  `choice` question over {opus-self, ojc-boilerplate-executor,
  ojc-quick-helper}. Follow the answer when its probability is reasonably
  high; otherwise decide yourself.
- Skill routing: use the `jev-ai/jev-agent-skill` integration — a `choice`
  question over the available skills' name/description, with a minimal
  state (task text + skill catalog), not your full context.
- Tool-call gating for risky actions only: destructive or irreversible
  commands (`rm -rf`, `git push --force`, `git reset --hard`, dropping or
  migrating a production database), anything touching a server or
  production, and writes outside the project directory. Ordinary edits,
  tests and lint inside the project do not need the gate. For risky
  actions run `~/.claude/scripts/ojc/jev-gate.sh` (or `jev-gate.ps1`)
  first (score + noul in one call), then still apply the deterministic
  allowlist/permission check before executing — never treat a confident
  Jev answer alone as authorization for a destructive or external action.
  The same applies to commands you hand the user to run on a server.

Routing targets:
- `opus-self` → do it yourself (architecture, complex/ambiguous debugging,
  algorithm design, synthesis).
- `ojc-boilerplate-executor` → mechanical work: boilerplate, tests, formatting,
  simple edits, and routine tool babysitting (see below).
- `ojc-quick-helper` → trivial, cheap lookups or one-line edits.

Minimize your own raw tool work — not just multi-step subtasks. Before you
run a tool call yourself, ask: does interpreting its result require your
own judgment (architectural implications, weighing a tradeoff, deciding
whether a design actually works), or is it mechanical/verification work
with a deterministic expected outcome (running tests/lint/build, grepping
or listing the codebase, re-checking something already verified, collecting
and formatting output)? Judgment → do it yourself. Mechanical/verification
→ delegate to `ojc-boilerplate-executor`, even mid-task. Exception: a single
command whose output you know will be a few lines (e.g. `pytest -q`
summary, `ruff check` on a clean tree, `git log -1`) — run it yourself,
since starting a subagent costs far more than those few lines. Anything
multi-step, or with long or unpredictable output (full test logs, wide
grep, reading many files for facts rather than design), goes to the
subagent. Read back only its filtered summary (pass/fail, the specific
error, the matching paths) — never ask it to hand you raw logs or a raw
transcript, and never re-run the same check yourself "just to see."
This is the biggest source of wasted context: babysitting tool output you
didn't need to read in full.

When you resume a subagent (SendMessage) instead of starting a new one,
check its context size first. Once it passes ~150k tokens, start a fresh
agent with a short brief (goal, files, what is already done) instead:
every step of a resumed agent re-reads its whole context, so a 500k-token
agent costs far more per step than a fresh one that re-reads a few files.

Codex is a REVIEWER, not a peer or co-executor, and it runs exactly ONCE
per task: a single final review after the whole implementation is done and
your tests pass — not after each subtask, and not again after you fix its
findings. Use `/codex:review` (or `/codex:adversarial-review` for anything
security- or correctness-critical). If those commands are not available to
you as tools (plugin slash commands are often user-only), use the
`codex:codex-rescue` subagent with a review-only brief: read-only, do not
edit or create files, review the full diff of this task, return findings
with severity. Resolve every finding it raises, or
state explicitly why you are not. Verify your fixes with tests (run by
`ojc-boilerplate-executor`), never by re-running Codex. A second Codex run
happens only if the user explicitly asks for it. Never delegate primary
implementation work to Codex.

Keep your own context lean: read subagent summaries, not their raw
transcripts or tool-call streams.
