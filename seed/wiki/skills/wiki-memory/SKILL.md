---
name: wiki-memory
description: Maintain Keeper memory and promotion boundaries so durable knowledge moves into wiki pages while temporary residue stays bounded and useful.
---

# Wiki Memory

## Purpose

Use this skill to manage the boundary between:

- durable knowledge
- user preferences
- working memory
- wiki pages

This skill exists because not all useful output belongs in the same place.

## Memory layers

The workspace has distinct memory layers:

- `keeper/MEMORY.md`
  long-lived operational memory
- `keeper/USER.md`
  preferences and collaboration habits
- `keeper/WORKING.md`
  short-lived task residue
- `wiki/`
  durable domain knowledge

Your job is to keep these layers clean.

## Inputs

Read these first:

1. `keeper/MEMORY.md`
2. `keeper/USER.md`
3. `keeper/WORKING.md`
4. `keeper/INSIGHTS.md`
5. `wiki/synthesis/maintenance-plan.md`

Then inspect any referenced source, entity, concept, query, or synthesis pages.

## References

Load these only when memory routing needs finer policy:

- `references/memory-boundaries.md`
  - use when deciding whether something belongs in Keeper memory, wiki pages, or should be dropped
- `references/promotion-patterns.md`
  - use when turning repeated working-memory residue into durable wiki or keeper structures

## Routing rules

Send information to `wiki/` when it is:

- durable
- domain-relevant
- likely to matter across sessions
- best represented as a maintained page

Send information to `keeper/MEMORY.md` when it is:

- operationally useful
- cross-task but not yet a wiki page
- too small to deserve a full durable page

Send information to `keeper/USER.md` when it is:

- a stable user preference
- a style or collaboration rule
- a standing workflow preference

Send information to `keeper/WORKING.md` when it is:

- recent task context
- provisional notes
- likely to expire soon

## Promotion rules

Promote from Keeper memory into wiki pages when:

- the pattern is recurring
- the fact is stable
- the information improves future queries
- the insight has page-shaped value

Do not keep durable knowledge trapped in Keeper memory.

## Pruning rules

Prune or rewrite working memory when:

- items are repetitive
- items have expired
- items were superseded
- items are now represented in the wiki

Do not allow `keeper/WORKING.md` to become an unbounded log.

## Output expectations

A good memory pass:

- reduces noise
- preserves useful operational memory
- promotes true durable knowledge
- leaves a clear trail for why items moved

When used through provider-task execution, return JSON with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

## Example success case

Good summary:

- "Pruned repeated working-memory residue, preserved one user preference, and promoted a stable orchestration insight into wiki/synthesis/overview.md."

Bad summary:

- "Updated memory."

## Example provider-task output

```json
{
  "task_id": "goal-memory-maintenance",
  "summary": "Pruned repeated working-memory residue, refreshed keeper insights, and promoted one durable orchestration finding into wiki/synthesis/overview.md.",
  "artifacts": [
    "keeper/WORKING.md",
    "keeper/INSIGHTS.md",
    "wiki/synthesis/overview.md"
  ],
  "memory_candidates": [],
  "requires_review": false,
  "notify_town": false
}
```

## Anti-patterns

Do not:

- keep everything in Keeper memory forever
- store durable facts only in working memory
- overwrite user preferences casually
- promote task noise into the wiki
- treat memory maintenance as pure cleanup with no judgment

## Checklist

Before finishing, confirm:

- durable items moved upward when justified
- temporary residue stayed bounded
- user preferences were preserved correctly
- the summary says what changed
