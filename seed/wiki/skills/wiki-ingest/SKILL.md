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

MoonBook should express research ingest as a five-phase semantic graph:

1. `bootstrap_gather`
2. `source_materialize`
3. `knowledge_revise`
4. `marketing_project`
5. `review_finalize`

These are domain phases, not implementation details.

MoonClaw may execute each phase with one worker or several workers.
If a phase is too broad, MoonClaw should split it into bounded child tasks.
If a task cannot be split safely, MoonClaw should return a blocker instead of hanging.

The clean rule is:

- MoonBook owns what each phase means
- MoonClaw owns how each phase is executed without becoming unbounded

`marketing_project` is intentionally separate from `knowledge_revise`.
Do not ask one worker to write ontology updates, a deep research article, and
buyer-facing marketing copy in the same pass. That produces planning headings,
source audits, and process residue in the generated page. The marketing worker
loads `skills/wiki-marketing/SKILL.md`, reads the already prepared research
envelope, and writes only `raw/bootstrap/marketing-brief.md`.

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
- MoonClaw should return raw research artifacts; MoonBook owns durable `wiki/*` materialization from those artifacts

## Research artifact contract

Research bootstrap is not complete until the workspace contains a visible research trail.
This is stricter than a generic summary because later readers need to know what was searched,
what was screened out, what evidence supports the synthesis, and what remains uncertain.

For research-shaped bootstrap tasks, produce these files under `raw/bootstrap/`:

- `research-question.md`
- `search-log.md`
- `source-screen.md`
- `evidence-matrix.md`
- `local-sources.md`
- `synthesis-brief.md`
- `deep-report.md`
- `marketing-brief.md` when the book is expected to publish a product website

If a file cannot be produced, still explain the blocker in the closest artifact you can write.
For example, if web search is unavailable, write `search-log.md` with:

- the intended query angles
- the unavailable tool or permission
- what local sources were used instead
- what confidence penalty this creates

### `research-question.md`

This file states the exact research question before gathering starts.
It should include:

- the user's requested topic
- the scope boundaries
- the target audience
- the claims that need verification
- what output shape is expected

Good:

- "Research the relationship between Moontown, MoonBook, and MoonClaw as a product stack. Verify local repo claims against project files and public sources when available."

Bad:

- "Research MoonBook."

### `search-log.md`

This file records search behavior.
It is not a final report.
It should include:

- each query angle attempted
- whether the search was web, local repo, package registry, docs, or code search
- the result count or qualitative result
- sources followed
- sources rejected as unrelated
- tool availability notes

Use multiple angles for public research:

- project names together
- each project name alone
- organization or author names
- package registry names
- official docs
- architecture and related terms
- false-lead pruning, especially for ambiguous names

### `source-screen.md`

This file explains inclusion and exclusion.
Each candidate source should be marked as:

- `included`
- `excluded`
- `deferred`
- `inaccessible`

For each candidate include:

- title or path
- type: local repo, official docs, package registry, public page, generated artifact, user-provided source
- reason
- reliability notes
- next action

Candidate inventories are not verified source coverage.
A candidate source page must not satisfy durable coverage unless the source was actually inspected.

### `evidence-matrix.md`

This file connects claims to evidence.
Use a compact table with columns like:

- claim or theme
- source
- evidence
- support level
- uncertainty
- target wiki page

Do not put unsupported product copy here.
If the claim is an inference, label it as an inference.
If sources disagree, record the contradiction instead of smoothing it away.

### `local-sources.md`

This file records local repository or filesystem inspection.
Include:

- paths inspected
- high-signal files read
- paths skipped
- access failures
- important excerpts summarized in your own words
- target pages suggested by the local evidence

Never promote `.gitkeep`, generated cache files, empty scaffolds, or pure config placeholders as substantive source material.

### `synthesis-brief.md`

This file is the final research brief for this bootstrap cycle.
It should only make claims supported by `evidence-matrix.md` or inspected local sources.
It should include:

- executive answer
- relationship-level synthesis
- what is verified
- what is provisional
- contradictions or false leads
- recommended durable wiki pages
- recommended marketing projection angle, if relevant

This is the artifact the generated site should project first.
If it is missing, the site should remain diagnostic.

### `deep-report.md`

This file is the reader-facing research article.
Use `skills/research-report/SKILL.md`.

It must not be a status report about the ingest run.
It should compete with a polished deep-research page:

- direct executive summary
- ecosystem or topic context
- architecture and operating model
- technical proof from inspected sources
- relationship and comparison sections
- maturity and gap analysis
- at least one table
- at least one Mermaid diagram when relationships matter
- final evidence and limits section

If the evidence is not good enough to write this article, do not write a thin
article. Return a blocker that says which sources or tool capabilities are
missing.

### `marketing-brief.md`

This file is the buyer-facing product story.
Use `skills/wiki-marketing/SKILL.md`.

It must not be a list of artifacts, sources, task IDs, or backend phases.
It is generated in the separate `marketing_project` phase after the evidence
matrix, synthesis brief, and deep report exist.
It should name:

- the buyer
- the pain
- the product promise
- the differentiator
- visible deliverables
- proof points
- objections
- next action

It must use exactly these level-2 headings:

- `## The Problem`
- `## The Product`
- `## Why It Wins`
- `## What You Can Ship`
- `## Who It Is For`
- `## Proof Points`
- `## Objections`
- `## Next Step`

It must not use planning, audit, or seller-note headings such as:

- `## Audience`
- `## Buyer Pain`
- `## Core Positioning`
- `## Product Promise`
- `## Differentiation`
- `## Seller-Facing Messaging Angles`
- `## Positioning Guardrails`
- `## Recommended Next Materialization`
- `## Evidence Base Used`
- `## Source IDs`
- `## Web Verification Status`

If the generated brief contains those headings, rewrite it before returning
success.

Research report and marketing brief are different:

- `deep-report.md` explains the subject in depth.
- `marketing-brief.md` sells the product outcome.
- Do not merge them.
- Do not let marketing copy replace evidence.
- Do not let evidence tables replace marketing.

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
- `raw/bootstrap/research-question.md`
- `raw/bootstrap/search-log.md`
- `raw/bootstrap/source-screen.md`
- `raw/bootstrap/local-sources.md`
- `raw/bootstrap/evidence-matrix.md`
- `raw/bootstrap/synthesis-brief.md`
- `raw/bootstrap/deep-report.md`
- `raw/bootstrap/marketing-brief.md` when website projection is required
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

- prepare gathered raw packets for MoonBook-owned durable source-page materialization
- preserve provenance and evidence
- make the evidence envelope easy for MoonBook to cite and promote

Inputs:

- raw bootstrap packet(s)
- inspected source material
- current `wiki/sources/` coverage

Outputs:

- `raw/bootstrap/evidence-matrix.md`
- stable source ids and page recommendations in the evidence matrix
- explicit materialization recommendations for MoonBook

Success looks like:

- the source ids name the source cleanly
- provenance is visible
- the page does not dump raw excerpts indiscriminately
- the page points at likely related entities or concepts
- MoonBook has enough evidence to decide what becomes `wiki/sources/*.md`

Blocker looks like:

- the packet exists but still lacks enough material to justify MoonBook materialization
- the candidate source is actually a placeholder or scaffold

### `knowledge_revise`

Goal:

- prepare entity, concept, and synthesis recommendations from the evidence envelope
- strengthen the materialization plan rather than only adding one-off source summaries

Inputs:

- evidence matrix
- entity candidates
- concept candidates
- prior synthesis pages
- claims or contradictions found during reading

Outputs:

- `raw/bootstrap/synthesis-brief.md`
- `raw/bootstrap/deep-report.md`
- entity, concept, claim, and synthesis recommendations inside the synthesis brief
- optionally query-page recommendations when the work is query-shaped

Success looks like:

- entity recommendations capture identity and relationships
- concept recommendations explain recurring ideas
- synthesis recommendations connect sources and preserve disagreement
- MoonBook has enough grounded guidance to create durable cross-links
- the deep report reads like a reader-facing article, not a run log

Blocker looks like:

- the material only supports a source note, not a maintained synthesis recommendation
- the phase would create generic buckets or empty ontology pages

### `marketing_project`

Goal:

- convert the research envelope into buyer-facing product copy
- keep marketing separate from research evidence and system bookkeeping
- produce the generated website's marketing source file

Inputs:

- `raw/bootstrap/deep-report.md`
- `raw/bootstrap/synthesis-brief.md`
- `raw/bootstrap/evidence-matrix.md`
- `skills/wiki-marketing/SKILL.md`

Outputs:

- `raw/bootstrap/marketing-brief.md`

Success looks like:

- the brief uses exactly the wiki-marketing skeleton headings
- the copy names buyer pain, product promise, advantages, deliverables, proof,
  objections, and next action
- evidence is translated into buyer value instead of dumped as source IDs
- no internal task, provider, artifact, ReviewQueued, or raw path language leaks
  into visible copy

Blocker looks like:

- missing deep report or evidence material
- invalid level-2 headings
- copy that reads like an audit, planning memo, or implementation note
- claims that cannot be supported without overclaiming

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
- the raw research envelope is complete enough for MoonBook materialization
- blockers are not disguised as success

Blocker looks like:

- artifacts are empty
- only admin pages changed
- the run could not produce a complete raw research envelope
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
- one worker writes the evidence matrix and synthesis brief
- one worker writes the deep research report using `skills/research-report/SKILL.md`
- one worker writes the marketing brief using `skills/wiki-marketing/SKILL.md`
- one worker reviews whether MoonBook can safely materialize the envelope

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
- rewriting durable wiki pages directly instead of returning a raw research envelope for MoonBook
- returning generic prose like "completed gathering"

The gather phase is complete only when the combined lane outputs are strong enough for `source_materialize`.

## Success criteria

Count the run as successful only if all of the following are true:

1. substantive source material was inspected
2. bootstrap packets were written when needed
3. all required research artifacts exist under `raw/bootstrap/`
4. `deep-report.md` reads like a real article, not a run status page
5. `marketing-brief.md` uses the exact marketing skeleton and reads like product marketing, not an evidence inventory, when website projection is requested
6. the evidence matrix and synthesis brief explain what MoonBook should materialize
7. the summary names the actual work without vague filler

MoonBook, not MoonClaw, decides what becomes durable:

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

If you cannot produce the complete raw research envelope, return a blocker.

A blocker must state:

- what source paths were inspected
- what raw packets were written, if any
- what material was missing
- why MoonBook cannot safely materialize durable wiki pages yet
- what the next highest-value follow-up should be

## Bootstrap-first workflow

Use this workflow when the book has weak coverage or the prompt says research/bootstrap.

1. inspect task-local repo hints
2. identify 1 to 5 high-signal primary files
3. read those files directly
4. write one or more source packets into `raw/bootstrap/`
5. derive candidate source page titles
6. derive entity and concept candidates
7. write `evidence-matrix.md`
8. write `synthesis-brief.md`
9. write `deep-report.md` through the research-report skill
10. run the separate `marketing_project` phase
11. write `marketing-brief.md` through the wiki-marketing skill when a website projection is needed
12. return the raw artifact envelope so MoonBook can materialize durable wiki pages

The raw research envelope is the worker's final goal.
Durable wiki materialization is MoonBook's responsibility.

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

## Materialization recommendations

When recommending what MoonBook should revise first, use this order:

1. `wiki/sources/`
2. `wiki/entities/`
3. `wiki/concepts/`
4. `wiki/synthesis/overview.md`
5. `wiki/synthesis/claims.md`
6. `wiki/queries/` only if the work is query-shaped

Prefer revising existing pages over creating duplicates.

Prefer stable ontology over token-derived page names.

## Content quality rules

Recommended source pages should:

- summarize the source cleanly
- preserve provenance
- avoid raw excerpt dumping
- call out uncertainty
- link to related entities and concepts

Recommended entity pages should:

- capture identity and role
- include relationships
- avoid becoming generic buckets

Recommended concept pages should:

- explain recurring ideas
- remain cumulative
- avoid one-off jargon fragments

Recommended synthesis pages should:

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
- claim that MoonClaw wrote durable wiki pages when it only prepared raw artifacts
- store disposable chat residue as durable knowledge
- let one worker own the entire ingest lifecycle when the phases can be separated

## Concrete success example

```json
{
  "task_id": "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
  "summary": "Completed raw research artifacts for the Moontown, MoonBook, and MoonClaw relationship: question, search log, source screen, local source digest, evidence matrix, and synthesis brief.",
  "artifacts": [
    "raw/bootstrap/research-question.md",
    "raw/bootstrap/search-log.md",
    "raw/bootstrap/source-screen.md",
    "raw/bootstrap/local-sources.md",
    "raw/bootstrap/evidence-matrix.md",
    "raw/bootstrap/synthesis-brief.md",
    "raw/bootstrap/deep-report.md",
    "raw/bootstrap/marketing-brief.md"
  ],
  "memory_candidates": [
    {
      "kind": "finding",
      "title": "MoonBook should materialize the research envelope",
      "detail": "The evidence matrix and synthesis brief contain enough source-backed material for MoonBook to promote into durable source, entity, concept, and synthesis pages.",
      "durable": false,
      "target_page": null
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
  "summary": "Blocked ingest: inspected repo hints and wrote raw/bootstrap/initial-notes.md, but the available materials were too shallow to complete evidence-matrix.md or synthesis-brief.md.",
  "artifacts": [
    "raw/bootstrap/initial-notes.md"
  ],
  "memory_candidates": [
    {
      "kind": "blocker",
      "title": "Need higher-signal MoonClaw source material",
      "detail": "The inspected files were mostly navigation and setup docs. The next pass should inspect runtime, provider, and job execution files before MoonBook attempts durable materialization.",
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
The goal is to return a complete, auditable research envelope that MoonBook can turn into a better wiki.

If the phases cannot produce grounded research artifacts, stop early and say so.
