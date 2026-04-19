---
name: wiki-ingest
description: Ingest raw sources into the wiki through MoonBook-owned semantic phases and MoonClaw-executed bounded tasks, with strict JSON results that separate durable success from blockers.
---

# Wiki Ingest

## Purpose

Use this skill when the job is to turn raw material into durable wiki coverage.
It is not a generic summarizer.
It is a phased maintainer contract for moving evidence from raw inputs into a maintained wiki.

Typical cases:

- importing a user-provided source
- bootstrapping a new book from local repositories
- revising existing wiki pages from staged raw packets
- recovering from weak, noisy, or administrative-only ingest runs

MoonBook owns the semantic decomposition.
MoonClaw owns the executable decomposition.

That means:

- MoonBook decides what ingest means for this domain
- MoonBook emits phased work instead of one giant ingest blob
- MoonClaw splits or rejects overbroad execution units
- MoonClaw enforces budgets, retries, and artifact persistence

The core workspace contract is still:

- raw material lives under `raw/`
- bootstrap packets live under `raw/bootstrap/`
- durable wiki pages live under `wiki/`

## Semantic phase graph

MoonBook should express ingest as a four-phase semantic graph:

1. `bootstrap_gather`
2. `source_materialize`
3. `knowledge_revise`
4. `review_finalize`

These are domain phases, not implementation details.

MoonClaw may execute each phase with one worker or several workers.
If a phase is too broad, MoonClaw should split it into bounded child tasks.
If a task cannot be split safely, MoonClaw should return a blocker instead of hanging.

The clean rule is:

- MoonBook owns what each phase means
- MoonClaw owns how each phase is executed without becoming unbounded

## Inputs

Expected inputs:

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
3. already-created maintained source pages under `wiki/sources/`

## References

Load these only when the task needs stricter rules than the top-level contract:

- `references/raw-first-contract.md`
  - use when packet structure, success JSON, or blocker rules need exactness
- `references/bootstrap-examples.md`
  - use when the task needs concrete repo-research examples or packet naming guidance

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

## Phase contract

### `bootstrap_gather`

Goal:

- inspect the minimum set of high-signal files
- collect provenance
- produce raw bootstrap packets
- decide whether the source material is worth durable ingest

Inputs:

- repo hints
- local paths
- source discovery hints
- weak or empty book coverage

Outputs:

- `raw/bootstrap/<slug>.md`
- a short list of candidate source pages
- a short list of candidate entities and concepts
- explicit missing-material notes if the source is too weak

Success looks like:

- the packet is readable without chat history
- provenance is preserved
- evidence bullets are concrete
- the packet can be used by the next phase without guessing

Blocker looks like:

- only scaffolding was found
- no substantive source material exists
- discovery produced no evidence worth revising

### `source_materialize`

Goal:

- convert gathered raw packets into durable source pages
- preserve provenance and evidence
- make the source page easy for later synthesis to cite

Inputs:

- raw bootstrap packet(s)
- inspected source material
- current `wiki/sources/` coverage

Outputs:

- `wiki/sources/*.md`
- updates to `wiki/index.md`
- updates to `wiki/log.md`

Success looks like:

- the source page names the source cleanly
- provenance is visible
- the page does not dump raw excerpts indiscriminately
- the page points at likely related entities or concepts

Blocker looks like:

- the packet exists but still lacks enough material to justify a durable source page
- the candidate source is actually a placeholder or scaffold

### `knowledge_revise`

Goal:

- revise entities, concepts, and synthesis pages from the materialized source
- strengthen the wiki rather than only adding one-off source summaries

Inputs:

- source pages
- entity candidates
- concept candidates
- prior synthesis pages
- claims or contradictions found during reading

Outputs:

- `wiki/entities/*.md`
- `wiki/concepts/*.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`
- optionally `wiki/queries/*.md` when the task is query-shaped

Success looks like:

- entity pages capture identity and relationships
- concept pages explain recurring ideas
- synthesis pages connect sources and preserve disagreement
- the wiki gains durable cross-links, not just more notes

Blocker looks like:

- the material only supports a source note, not a maintained synthesis update
- the phase would create generic buckets or empty ontology pages

### `review_finalize`

Goal:

- check that the ingest actually improved the wiki
- catch empty success-shaped outputs
- decide whether the result is promotable or should stay blocked

Inputs:

- the outputs of the previous phases
- `wiki/index.md`
- `wiki/log.md`
- any claim or contradiction notes

Outputs:

- a final JSON result
- review notes if needed
- any pending follow-up that should be handed back to the town or keeper

Success looks like:

- the summary names the actual work
- artifacts are concrete
- the wiki state reflects the new knowledge
- blockers are not disguised as success

Blocker looks like:

- artifacts are empty
- only admin pages changed
- the run could not produce a durable page
- the final summary would otherwise say "completed" without substance

## Execution splitting rules

MoonClaw may run each semantic phase with multiple workers.
Use that when it lowers risk.

For `bootstrap_gather`, assume multiple bounded workers by default when the goal spans more than one repo, subsystem, or evidence type.
Do not let one gather worker own the whole discovery surface unless the source set is obviously tiny.

Good splits:

- one worker gathers repo or product docs
- one worker gathers implementation evidence from code and config
- one worker gathers architecture or cross-project topology notes
- one worker consolidates or prepares the resulting packets for materialization
- one worker materializes source pages
- one worker revises entity and concept pages
- one worker reviews the final state

Bad splits:

- one worker tries to do discovery, synthesis, review, and finalization in one unbounded loop
- one worker is asked to "research everything" with no phase boundary
- one worker is left to infer success from administrative updates alone

If a handoff is still too large, MoonClaw should:

- split it into 2 to 4 bounded child tasks
- keep each child task tied to concrete outputs
- reject the handoff if the contract is still vague

### Gather lane contract

Each gather worker should own one narrow lane.
Good lane shapes:

1. docs lane
2. implementation lane
3. architecture lane
4. cross-project relation lane

Each lane should produce:

- inspected source paths
- one focused packet section or one standalone `raw/bootstrap/*.md` packet
- candidate entities
- candidate concepts
- unresolved questions
- a lane-local readiness judgment

Each lane should avoid:

- re-reading everything another gather lane already covered
- claiming final ingest success
- rewriting durable wiki pages directly unless the assigned phase is no longer gather
- returning generic prose like "completed gathering"

The gather phase is complete only when the combined lane outputs are strong enough for `source_materialize`.

## Success criteria

Count the run as successful only if all of the following are true:

1. substantive source material was inspected
2. bootstrap packets were written when needed
3. at least one durable wiki page was created or revised
4. `wiki/index.md` and `wiki/log.md` reflect the change
5. the summary names the actual work without vague filler

Substantive durable pages include:

- `wiki/sources/*.md`
- `wiki/entities/*.md`
- `wiki/concepts/*.md`
- `wiki/queries/*.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`

Administrative-only updates do not count as ingest success.

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
5. derive candidate source page titles
6. derive entity and concept candidates
7. ingest from the packet into durable wiki pages
8. update navigation and maintenance surfaces
9. finalize only after the wiki contains durable substance

The raw packet is an intermediate product, not the final goal.

When the goal spans several repos or components, change step 2 into a gather fan-out:

2a. select a docs lane
2b. select an implementation lane
2c. select an architecture or topology lane
2d. optionally select a cross-project linkage lane

Keep each lane small enough that one worker can finish it reliably without needing to rediscover the entire system.

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
- let one worker own the entire ingest lifecycle when the phases can be separated

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
  "notify_town": true
}
```

## Final reminder

The goal is not to return a success-shaped JSON object.
The goal is to make the wiki better.

If the phases cannot produce durable knowledge, stop early and say so.
