---
name: wiki-lint
description: Inspect the maintained wiki for structural drift, semantic weakness, missing coverage, review pressure, and noisy ontology, then convert the findings into concrete maintenance actions.
---

# Wiki Lint

## Purpose

Use this skill to evaluate the health of a wiki workspace.
The goal is not to produce generic complaints.
The goal is to produce actionable maintenance pressure.

## Inputs

Read these first:

1. `wiki/index.md`
2. `wiki/log.md`
3. `wiki/synthesis/map.md`
4. `wiki/synthesis/evidence.md`
5. `wiki/synthesis/maintenance-plan.md`
6. `keeper/INSIGHTS.md`

Then inspect targeted pages based on what you find.

## Output expectations

A useful lint pass must:

- identify concrete problems
- separate structural from semantic issues
- point at affected pages
- propose the next maintenance actions
- avoid repeating already-known issues unless they materially worsened

When running through provider-task execution, return JSON with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

## Structural checks

Look for:

- orphan pages
- pages missing from `wiki/index.md`
- placeholder sections still left in maintained pages
- missing raw links on source pages
- stale `log.md` / `index.md` maintenance
- review items with broken references

## Semantic checks

Look for:

- contradictory claims
- weak synthesis
- unsupported assertions
- duplicate or noisy ontology
- concept pages that should be merged
- missing concept pages implied by repeated discussion
- entity pages that exist but say almost nothing

## Coverage checks

Check whether the wiki has:

- real source coverage
- real entity coverage
- real concept coverage
- enough evidence records
- enough review throughput

If the wiki is still bootstrapping, say that clearly.

## Maintenance-plan rules

Do not just complain.
Convert findings into follow-up work:

- what page should be revised
- why it matters
- what source or evidence is missing
- whether review is required

## Severity rules

Use rough severity internally:

- critical: contradictions, unsupported synthesis used as fact
- medium: missing coverage, stale planning, weak review throughput
- low: cosmetic or navigation issues

Prioritize by impact, not by how easy the fix is.

## Anti-patterns

Do not:

- call everything "needs improvement"
- list 20 low-signal issues before 1 serious issue
- confuse missing coverage with contradiction
- ask for more sources when the real issue is bad page structure

## Good output shape

Summaries should sound like:

- "Detected weak concept coverage and one unsupported synthesis claim."
- "Detected review backlog growth and stale evidence maintenance."

Not:

- "Lint completed."

## Good provider-task example

```json
{
  "task_id": "goal-health-lint",
  "summary": "Detected weak concept coverage, one unsupported synthesis claim, and a growing review backlog; updated the maintenance plan with targeted follow-up actions.",
  "artifacts": [
    "wiki/synthesis/maintenance-plan.md",
    "wiki/log.md"
  ],
  "memory_candidates": [
    {
      "kind": "finding",
      "title": "Concept coverage is lagging source growth",
      "detail": "The wiki now has source and entity coverage, but concept coverage remains too sparse for stable synthesis.",
      "durable": false,
      "target_page": null
    }
  ],
  "requires_review": false,
  "notify_town": false
}
```

## Bad output to avoid

```text
The wiki looks okay overall.
```
