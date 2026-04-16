---
name: wiki-marketing
description: Maintain the marketing website projection so it presents the workspace clearly, highlights strengths and current value, and remains distinct from the detailed wiki and journal layers.
---

# Wiki Marketing

## Purpose

Use this skill to project the workspace as a product-facing website.
This layer is not the same as:

- the detailed wiki
- the journal timeline
- the course projection

Its job is to explain why the system matters and what it can do now.

## Inputs

Read these first:

1. `wiki/synthesis/overview.md`
2. `wiki/index.md`
3. `wiki/synthesis/map.md`
4. `keeper/INSIGHTS.md`
5. current generated site state, if present

Inspect the journal only when:

- there is a major recent change worth surfacing
- current capability claims depend on recent progress

## Marketing boundary

Keep this layer:

- compressed
- audience-facing
- stable
- advantage-oriented

Do not make it:

- a debug log
- a replay of journal entries
- a raw dump of task artifacts

## What to highlight

Prefer highlighting:

- clear capabilities
- operating model
- why the system is different
- current readiness
- concrete outputs users can inspect

Do not name competitor products.
Horizontal framing is allowed, but keep it generic.

## Content structure

A good marketing page usually includes:

1. headline
2. clear system description
3. key capability sections
4. workflow or architecture summary
5. proof surfaces or links into the wiki
6. current status or traction hints

## Sources of truth

The marketing site should be grounded in maintained state:

- real coverage
- real generated pages
- real workflow capabilities

Do not market features that do not actually exist.

## Tone rules

Write with confidence, but do not oversell.

Good:

- concrete
- fast to understand
- product-shaped
- visually intentional

Bad:

- vague hype
- debug-heavy
- roadmap-only claims presented as shipped

## Output expectations

When running through provider-task execution, return JSON with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

`artifacts` should normally include:

- `site/index.html`
- generated marketing state files
- related wiki pages if the marketing pass also improved navigation

## Example success case

Good summary:

- "Refreshed the marketing projection to clarify the raw-first bootstrap workflow, keeper ingest boundary, and current live capability surfaces."

Bad summary:

- "Updated website."

## Anti-patterns

Do not:

- dump maintenance-plan bullets into the site
- confuse journal with marketing
- hide current limitations when they materially affect the promise
- describe the system only in internal jargon

## Checklist

Before finishing, confirm:

- the page feels product-facing
- claims match actual workspace state
- links point users toward deeper wiki pages
- journal content was not copied verbatim into marketing
