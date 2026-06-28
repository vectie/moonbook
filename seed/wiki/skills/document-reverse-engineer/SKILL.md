---
name: document-reverse-engineer
description: Deconstruct a strong finished document into thesis, argument logic, style, evidence, and improvement artifacts, then regenerate a stronger version without generic rewriting.
---

# Document Reverse Engineer

Use this skill when the input is already a coherent or polished document and
the goal is to learn the logic behind it, preserve what works, and produce a
better version.

This is MoonBook's reverse routine:

```text
finished document -> hidden structure -> durable memory -> improved projection
```

It is the same deeper MoonBook loop as forward ingest:

```text
material -> extract durable structure -> store clean memory -> generate projection
```

The difference is the skill profile. Forward ingest starts from rough material
and grows knowledge. Reverse engineering starts from a strong artifact and
extracts its argument, style, and structural model before rewriting.

## Non-Goals

Do not treat this as:

- a generic summary
- a copyedit pass
- a sentence-by-sentence rewrite
- an SEO rewrite
- a research report unless the source document is a research report
- marketing copy unless the source document and requested projection are marketing-shaped

The output should explain the core logic behind the document before writing a
new version.

## Required Inputs

Load these files when they exist:

- the source document named by the task
- `RESOLVER.md`
- `ROUTINES.md`
- `wiki/index.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`
- `wiki/synthesis/map.md`
- `wiki/history/journey.md`
- `keeper/MEMORY.md`
- `keeper/USER.md`

If the task includes an audience, target format, product, domain, or quality
bar, treat that instruction as part of the rewrite brief.

If the source document is missing or only a placeholder, write a blocker instead
of inventing the deconstruction.

## Output Contract

Prefer this artifact shape under `raw/bootstrap/`:

- `source-document.md`
  normalized copy or pointer to the inspected finished document
- `document-deconstruction.md`
  thesis, audience, promises, assumptions, argument chain, section roles, and evidence types
- `argument-map.md`
  durable logic map with claim dependencies, weak links, hidden premises, and missing support
- `style-profile.md`
  voice, pacing, sentence texture, formatting habits, examples, and what must be preserved
- `improvement-plan.md`
  prioritized changes that would make the document clearer, stronger, more useful, or more persuasive
- `regenerated-document.md`
  rebuilt document that follows the improvement plan without blindly paraphrasing the source

Promote durable synthesis only when it is useful to future work:

- `wiki/sources/<document-slug>.md`
  source page for the inspected finished document
- `wiki/synthesis/argument-map.md`
  cross-document logic and reusable argument model
- `wiki/synthesis/style-profile.md`
  durable style notes when the user's preferred style should persist
- `wiki/synthesis/improvement-plan.md`
  reusable plan for future projection work

If the job is executed through a worker/provider result, return exactly one JSON
object with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

Use concrete artifact paths. Do not claim regenerated quality unless the files
were actually written.

## Deconstruction Pass

Read the whole document once for shape before annotating details.

Extract:

- thesis
- intended reader
- job the document performs for that reader
- explicit promises
- hidden promises
- assumptions
- section-by-section role
- argument chain
- core claims
- supporting evidence
- evidence gaps
- examples and analogies
- definitions
- repeated motifs
- emotional arc
- conclusion function

Then decide what kind of document it really is:

- explanation
- memo
- sales page
- research report
- tutorial
- strategy note
- product specification
- personal essay
- manifesto
- mixed form

Do not force the document into the user's label if the actual structure says
otherwise. Record the mismatch when it matters.

## Logic Map

Build the argument as a dependency graph in prose or compact bullets.

For each major claim, capture:

- claim
- prerequisite belief
- evidence used
- evidence missing
- section where it appears
- downstream claims that depend on it
- confidence
- revision pressure

Look for:

- leaps from observation to conclusion
- undefined terms
- repeated claims with different wording
- claims that need examples
- sections that are emotionally strong but logically unsupported
- strong facts buried too late
- conclusions that do not pay off the opening promise

The goal is not to be harsh. The goal is to expose the structure so the next
version can be deliberately better.

## Tables, Figures, and Dense Claims

When the source is a technical, market, strategy, or research report, treat
tables and figures as part of the argument rather than decoration.

For each table or figure, capture:

- title or nearest heading
- role in the argument
- claims it supports
- claims it does not prove
- numbers or categories worth preserving
- whether the regenerated document should reuse, simplify, or replace it

For dense factual claims, separate:

- source-grounded statements
- inferences from the document's own logic
- claims that need verification before external publication
- speculative forecasts

If the regenerated document is meant to be better than the source, improve the
reader's decision path. Prefer clearer tradeoff matrices, decision gates,
operating models, and action roadmaps over longer exposition.

## Style Profile

Capture what should survive the rewrite.

Include:

- voice and temperament
- sentence length pattern
- density
- paragraph rhythm
- preferred transitions
- use of examples
- level of technicality
- emotional register
- formatting conventions
- title and heading behavior
- phrases or framings worth preserving
- phrases or habits to avoid

Do not copy long passages. Preserve style as rules and small examples, not as a
verbatim source clone.

## Improvement Plan

Write a concrete plan before regenerating.

The plan should identify:

- stronger thesis
- better opening
- sections to merge
- sections to split
- missing connective tissue
- evidence to move earlier
- terms to define
- examples to add
- redundancies to remove
- ending to strengthen
- alternate projections worth generating

Prioritize changes by reader value, not by ease.

## Regeneration Rules

The rebuilt document should:

- preserve what works
- keep the true thesis visible
- strengthen weak logic
- remove redundancy
- add missing transitions
- keep useful examples
- add only support that follows from the available source or explicit user context
- avoid laundering uncertainty into confident prose
- avoid process residue such as "this deconstruction" unless the requested output is itself an analysis

Do not merely rewrite each paragraph. Rebuild the document from the extracted
logic map and style profile.

## Quality Gate

Before returning success, verify that:

- the deconstruction names a concrete thesis
- every major section has a role
- the argument map exposes at least one dependency or missing premise
- the style profile says what to preserve and what to avoid
- the improvement plan is actionable
- the regenerated document follows the plan
- the regenerated document is not a generic summary
- uncertainty and source limits are visible where they matter

If any gate fails, revise the artifact before reporting success.
