---
name: wiki-maintainer
description: Keeper and revision skill for maintaining a MoonBook wiki workspace through raw-first bootstrap and durable page revision.
---

# Wiki Maintainer

Operate on the maintained wiki layer, not on raw chat history. Treat this as a reusable method, not a one-off prompt.

## References

Load these only when the current controller run needs exact extension-side contracts:

- `references/moonclaw-raw-first.md`
  - use when raw packet expectations, artifact requirements, or provider result quality gates need exact enforcement
- `references/controller-playbook.md`
  - use when splitting gather, prepare, revise, and review tasks across MoonClaw workers

## Rules

1. Read `RESOLVER.md`, then `wiki/index.md`.
2. Treat `raw/` as the source-of-truth boundary. For bootstrap discovery, write new source packets into `raw/bootstrap/` before claiming ingest progress.
3. Treat MoonBook's workspace logic as the owner of durable source-page creation and readiness signals.
4. Never treat placeholder files such as `.gitkeep`, empty files, or hidden workspace scaffolding as substantive sources.
5. Prefer revising existing entity, concept, source, synthesis, and query pages over creating isolated notes.
6. Update `wiki/index.md` and `wiki/log.md` whenever the maintained wiki changes.
7. Preserve uncertainty explicitly; do not flatten contradictions.
8. Prefer stable domain pages over token-derived or low-signal pages.
9. Source pages should read like durable summaries, not raw excerpt dumps.
10. Ingest is only successful when you can point to written `raw/bootstrap/*` packets and substantive maintained wiki pages. Otherwise return a blocker.

## Required Output

Return exactly one JSON object with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

Rules:

- Output JSON only.
- `artifacts` must list written `raw/bootstrap/*` packets and any durable wiki pages changed.
- If no substantive wiki pages changed, do not say "completed". Return a blocker with missing materials or the reason materialization failed.

## Concrete Example

```json
{
  "task_id": "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
  "summary": "Wrote raw/bootstrap/moonclaw-runtime.md from local repo docs, added wiki/sources/moonclaw-source.md, and refreshed wiki/index.md to expose the new maintained source.",
  "artifacts": [
    "raw/bootstrap/moonclaw-runtime.md",
    "wiki/sources/moonclaw-source.md",
    "wiki/index.md"
  ],
  "memory_candidates": [],
  "requires_review": false,
  "notify_town": false
}
```

Bad output to avoid:

```text
Completed provider task Bootstrap ingest and population.
```

## Failure modes

Common failure modes:

- reading the hints but not writing `raw/bootstrap/*`
- writing packets but not ingesting them into the wiki
- changing only administrative pages
- returning vague summaries with empty artifacts

If any of these happen, return a blocker instead of success.

## Checklist

Before finishing, confirm:

- raw packets exist when bootstrap discovery was needed
- substantive wiki pages changed
- `artifacts` lists the real paths
- the summary names the concrete work

## Escalation rules

Escalate or block when:

- hints point at repos but the worker never inspected them
- packets exist but are too weak for durable wiki revision
- the revision plan would create noisy ontology
- only administrative pages changed

Do not downgrade these to "partial success" without explaining the exact reason.

## Self-check questions

Ask yourself:

- what exact source packet did I create
- what exact durable page did I improve
- what exact evidence moved from raw to wiki
- what exact blocker prevented completion if no page changed

If you cannot answer these concretely, the run is not done.
