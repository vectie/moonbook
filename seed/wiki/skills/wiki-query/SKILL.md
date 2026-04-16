---
name: wiki-query
description: Answer a question from the maintained wiki with citations, preserve uncertainty, and decide whether the answer should be promoted into durable wiki pages instead of remaining chat-only output.
---

# Wiki Query

## Purpose

Use this skill for question answering over the maintained wiki layer.
This is not a raw-document search skill.
The default assumption is:

- durable wiki pages are the primary evidence surface
- raw files are secondary and should only be consulted for gap checks

## Inputs

Expected inputs include:

- a user question
- current `wiki/index.md`
- related source, entity, concept, query, and synthesis pages
- optional saved-query context
- current review and evidence state when the answer may be promoted

Always read first:

1. `wiki/index.md`
2. `wiki/log.md`
3. the highest-signal pages relevant to the question

If the question appears to require a gap check, also inspect:

- `wiki/synthesis/maintenance-plan.md`
- `wiki/synthesis/evidence.md`
- raw sources only when wiki coverage is weak

## References

Load these only when the top-level query flow is not enough:

- `references/promotion-contract.md`
  - use when deciding whether an answer belongs in `wiki/queries/` or should update another durable page
- `references/query-note-examples.md`
  - use when saved-query structure, citation style, or blocker phrasing needs a concrete model

## Output mode

When used as a conversational analysis step, the answer may be markdown.

When used through provider-task execution, return exactly one JSON object with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

## Core behavior

1. locate the most relevant wiki pages
2. answer from durable pages first
3. cite page paths
4. preserve uncertainty and disagreement
5. identify whether the answer has durable value
6. if durable, recommend or create a query page under `wiki/queries/`

## Success criteria

A good query result:

- cites maintained page paths
- distinguishes evidence from inference
- does not flatten disagreement
- says what is unknown
- promotes durable value when justified

## Promotion rules

Promote the answer into the wiki when:

- the answer is likely to be asked again
- it synthesizes multiple maintained pages
- it exposes a useful comparison
- it turns scattered signals into one stable explanation

Do not promote when:

- the answer is purely ephemeral
- the evidence is too weak
- the answer is only a chat reformulation of one page

## Preferred durable targets

Use these targets by default:

1. `wiki/queries/*.md` for answer-shaped durable notes
2. `wiki/synthesis/overview.md` for cross-source synthesis improvements
3. `wiki/concepts/*.md` when the answer clarifies a recurring concept
4. `wiki/entities/*.md` when the answer updates one entity cleanly

## Citation rules

Always cite page paths, not vague phrases like:

- "the wiki says"
- "the notes indicate"
- "a prior result showed"

Prefer citations such as:

- `wiki/sources/moontown-source.md`
- `wiki/concepts/domain-harness.md`
- `wiki/synthesis/overview.md`

## Uncertainty rules

Use explicit uncertainty language when needed:

- evidence is partial
- the pages disagree
- the answer depends on an inference
- a likely missing source has not been ingested yet

Do not hide these conditions.

## Anti-patterns

Do not:

- answer from raw files by default
- cite paths you did not inspect
- turn weak hints into strong claims
- save every answer automatically
- overwrite an existing durable answer without checking its history

## Query-note structure

A good saved query note usually includes:

- title
- question
- answer summary
- cited pages
- unresolved uncertainty
- follow-up questions

## Good provider-task example

```json
{
  "task_id": "goal-refresh-synthesis-analysis",
  "summary": "Answered the current cross-project research question from maintained wiki pages and saved a durable note under wiki/queries/cross-project-research.md.",
  "artifacts": [
    "wiki/queries/cross-project-research.md",
    "wiki/synthesis/query-insights.md",
    "wiki/log.md"
  ],
  "memory_candidates": [
    {
      "kind": "finding",
      "title": "Moontown planning depends on MoonBook coverage quality",
      "detail": "The saved query note explains that Moontown can route work correctly, but answer quality still depends on MoonBook coverage and MoonClaw materialization quality.",
      "durable": true,
      "target_page": "wiki/synthesis/overview.md"
    }
  ],
  "requires_review": false,
  "notify_town": false
}
```

## Good blocker example

```json
{
  "task_id": "goal-refresh-synthesis-analysis",
  "summary": "Blocked durable query promotion: the wiki has enough material for a provisional answer but not enough support for a stable saved query note.",
  "artifacts": [],
  "memory_candidates": [
    {
      "kind": "blocker",
      "title": "Need more maintained source coverage",
      "detail": "The query could be answered provisionally, but the maintained source layer is still too sparse to justify a durable note.",
      "durable": false,
      "target_page": null
    }
  ],
  "requires_review": true,
  "notify_town": false
}
```

## Bad output to avoid

```text
Here is a quick answer with no citations.
```
