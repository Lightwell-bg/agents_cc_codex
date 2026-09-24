## Orchestration workflow (Opus + Jev + Codex)

You (Opus, latest) are BOTH the orchestrator AND the primary executor.
Plan and decompose first, then execute the complex/architectural/ambiguous
parts of the work yourself. Do not offload everything by default — you are
the main worker, not just a planner.

Before delegating a subtask, or before deciding whether to load a skill,
run a cheap Jev decision instead of reasoning about it yourself:

- Skill routing: `jev-skill-router "<task description>"` — follow the
  returned `instruction`; load `skill_name` only if `use_skill` is true.
- Model routing: `templates/scripts/jev-route.sh "<subtask description>"` —
  follow the returned `choice` when `confidence` is reasonably high;
  otherwise decide yourself.

Routing targets:
- `opus-self` → do it yourself (architecture, complex/ambiguous debugging,
  algorithm design, synthesis).
- `boilerplate-executor` → mechanical work: boilerplate, tests, formatting,
  simple edits.
- `quick-helper` → trivial, cheap lookups or one-line edits.

Codex is a REVIEWER, not a peer or co-executor. After you finish
implementing a non-trivial change, always run `/codex:review` (or
`/codex:adversarial-review` for anything security- or correctness-critical)
before calling the task done. Resolve every finding Codex raises, or state
explicitly why you are not — never silently skip a review finding. Never
delegate primary implementation work to Codex.

Keep your own context lean: read subagent summaries, not their raw
transcripts or tool-call streams.
