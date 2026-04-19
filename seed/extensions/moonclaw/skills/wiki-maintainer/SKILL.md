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
11. Treat `bootstrap_gather` as a multi-worker fan-out phase when the source surface is broad. Prefer several narrow gather lanes over one catch-all gather worker.
12. Gather workers do not own final ingest success. They own focused evidence collection and packet production for one lane.
13. When the imported keeper proposal includes semantic phases, execution mode, max parallel workers, or gather lane specs, treat those as book-owned intent and preserve them unless the source surface is obviously tiny.

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
- using one gather worker to read every repo, every subsystem, and every evidence type
- failing to separate docs, implementation, topology, and cross-project evidence into bounded gather lanes
- writing packets but not ingesting them into the wiki
- changing only administrative pages
- returning vague summaries with empty artifacts

If any of these happen, return a blocker instead of success.

## Checklist

Before finishing, confirm:

- raw packets exist when bootstrap discovery was needed
- gather work was split into narrow lanes when the source surface was broad
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

## Gather fan-out rule

When the task is a weak-coverage research bootstrap, the default gather shape should be:

1. docs lane
2. implementation lane
3. architecture lane
4. optional cross-project lane

Each lane should:

- inspect only a small high-signal slice
- produce packet-ready evidence, not final synthesis
- report concrete source paths
- name candidate entities and concepts
- say explicitly whether the lane is strong enough for materialization

If the proposal already names lane specs, use those exact lane specs first.
Do not silently collapse them into one worker.

Do not collapse these back into a single gather sweep unless the source set is obviously tiny.
