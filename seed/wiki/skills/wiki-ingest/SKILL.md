---
name: wiki-ingest
description: Ingest one source or bootstrap packet into the wiki by preparing raw source packets, diarizing evidence, revising durable wiki pages, and returning strict JSON results that distinguish success from blockers.
---

# Wiki Ingest

## Purpose

Use this skill when the task is to turn raw material into durable wiki coverage.
This includes:

- importing a user-provided source
- bootstrapping a new book from local repositories
- revising existing wiki pages from newly staged raw packets
- recovering from weak or administrative-only ingest runs

The core contract is simple:

- raw material lives under `raw/`
- generated bootstrap packets live under `raw/bootstrap/`
- durable wiki pages live under `wiki/`

This skill is responsible for moving work from the raw side to the durable side.

## Inputs

Expected input sources:

- a concrete `SOURCE` path under `raw/` or `raw/bootstrap/`
- an ingest-oriented task title or prompt
- optional question framing from the user
- optional bootstrap hints pointing at local repos or candidate source files
- current wiki state from `wiki/index.md`, `wiki/log.md`, and synthesis pages

Read these files first:

1. `RESOLVER.md`
2. `wiki/index.md`
3. `wiki/log.md`
4. `wiki/synthesis/maintenance-plan.md`
5. the named source path

For bootstrap discovery also inspect:

1. `raw/bootstrap/`
2. local repo hints passed in the task prompt
3. any already-created maintained source pages under `wiki/sources/`

## References

Load these only when the current task needs more detail than this top-level procedure:

- `references/raw-first-contract.md`
  - use when bootstrap packet structure, success/blocker JSON, or durable page targets need exact rules
- `references/bootstrap-examples.md`
  - use when the run needs concrete packet examples for repo research, local path hints, or multi-project ingest

## Required outputs

When running through MoonClaw provider or extension execution, return exactly one JSON object.

Required top-level keys:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

Required rules:

- output JSON only
- no markdown fences around the final answer
- no prose before or after the JSON object
- always include every top-level key
- use `[]` for empty arrays
- use `null` for missing `target_page`
- `summary` must describe the real work completed
- `artifacts` must list concrete written paths
- for bootstrap work, `artifacts` should include `raw/bootstrap/*`
- for successful ingest, `artifacts` should include at least one substantive `wiki/*` page

## Success criteria

Count the run as successful only if all of the following are true:

1. you inspected substantive source material
2. you wrote or confirmed usable raw packets when bootstrap discovery was needed
3. you created or revised at least one substantive durable wiki page
4. `wiki/index.md` and `wiki/log.md` reflect the change
5. the summary names what changed without vague filler

Substantive durable pages include:

- `wiki/sources/*.md`
- `wiki/entities/*.md`
- `wiki/concepts/*.md`
- `wiki/queries/*.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`

Administrative-only updates do not count as ingest success.

Examples of administrative-only updates:

- touching only debug pages
- touching only `maintenance-plan.md`
- touching only observations/evidence pages
- returning empty `artifacts`

## Failure and blocker rules

Do not say "completed" when:

- `artifacts` is empty
- only admin pages changed
- no usable source packet exists
- source material is too weak or too noisy
- the source is actually scaffolding or a placeholder

If you cannot produce substantive durable pages, return a blocker.

A blocker must state:

- what source paths were inspected
- what raw packets were written, if any
- what material was missing
- why no durable wiki page could be produced
- what the next highest-value follow-up should be

## Bootstrap-first workflow

Use this workflow when the book has weak coverage or the prompt says research/bootstrap.

1. inspect task-local repo hints
2. identify 1 to 5 high-signal primary files
3. read those files directly
4. write one or more source packets into `raw/bootstrap/`
5. each packet should preserve provenance, source paths, and evidence bullets
6. derive candidate source page titles
7. derive entity and concept candidates
8. ingest from the packet into durable wiki pages
9. update navigation and maintenance surfaces

The raw packet is an intermediate product, not the final goal.

## Raw packet format guidance

A good raw bootstrap packet should contain:

- packet title
- source paths inspected
- one-paragraph source synopsis
- 5 to 12 evidence bullets
- named entities
- recurring concepts
- unresolved questions
- suggested durable pages to revise

The packet should be readable by Keeper without needing chat history.

## Durable page priorities

When deciding what to revise first, use this order:

1. `wiki/sources/`
2. `wiki/entities/`
3. `wiki/concepts/`
4. `wiki/synthesis/overview.md`
5. `wiki/synthesis/claims.md`
6. `wiki/queries/` only if the work is query-shaped

Prefer revising existing pages over creating duplicates.

Prefer stable ontology over token-derived page names.

## Content quality rules

Source pages should:

- summarize the source cleanly
- preserve provenance
- avoid raw excerpt dumping
- call out uncertainty
- link to related entities and concepts

Entity pages should:

- capture identity and role
- include relationships
- avoid becoming generic buckets

Concept pages should:

- explain recurring ideas
- remain cumulative
- avoid one-off jargon fragments

Synthesis pages should:

- connect sources
- preserve disagreement
- avoid flattening contradictions

## Anti-patterns

Do not:

- treat `.gitkeep` as a source
- treat empty files as evidence
- create pages just because a word appeared once
- write vague summaries like "completed provider task"
- claim success with empty artifacts
- skip `wiki/index.md` and `wiki/log.md`
- store disposable chat residue as durable knowledge

## Concrete success example

```json
{
  "task_id": "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
  "summary": "Wrote raw/bootstrap/moontown-overview.md from local repo docs, added wiki/sources/moontown-source.md, updated wiki/entities/moontown.md, and refreshed wiki/index.md plus wiki/log.md.",
  "artifacts": [
    "raw/bootstrap/moontown-overview.md",
    "wiki/sources/moontown-source.md",
    "wiki/entities/moontown.md",
    "wiki/index.md",
    "wiki/log.md"
  ],
  "memory_candidates": [
    {
      "kind": "finding",
      "title": "Moontown routes work through MoonBook and MoonClaw",
      "detail": "The maintained source and entity pages now state that Moontown schedules domain work into MoonBook workspaces and MoonClaw execution runs.",
      "durable": true,
      "target_page": "wiki/synthesis/overview.md"
    }
  ],
  "requires_review": false,
  "notify_town": false
}
```

## Concrete blocker example

```json
{
  "task_id": "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
  "summary": "Blocked ingest: inspected repo hints and wrote raw/bootstrap/initial-notes.md, but the available materials were too shallow to support a durable source page.",
  "artifacts": [
    "raw/bootstrap/initial-notes.md"
  ],
  "memory_candidates": [
    {
      "kind": "blocker",
      "title": "Need higher-signal MoonClaw source material",
      "detail": "The inspected files were mostly navigation and setup docs. The next pass should inspect runtime, provider, and job execution files before attempting durable source-page creation.",
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
Completed provider task Bootstrap ingest and population.
```
