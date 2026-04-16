# Raw-First Ingest Contract

## Purpose

This reference defines the exact contract for raw-first ingest runs.
Use it when the top-level ingest skill needs stricter detail.

## Non-negotiable sequence

1. inspect real source material
2. write one or more packets into `raw/bootstrap/` when the source is bootstrap-oriented
3. ingest those packets into durable wiki pages
4. update `wiki/index.md`
5. append to `wiki/log.md`
6. return a result JSON that matches what really happened

## What counts as a substantive source

Good sources:

- architecture docs
- code comments with domain meaning
- READMEs with real behavior
- design notes
- runtime/provider/task definitions
- tests that reveal intended behavior

Bad sources:

- `.gitkeep`
- empty files
- generated placeholders
- bare directory listings
- purely decorative files

## Required bootstrap packet structure

Each packet under `raw/bootstrap/` should include:

- title
- provenance section with inspected paths
- concise synopsis
- evidence bullets
- entity candidates
- concept candidates
- unresolved questions
- suggested durable page targets

## Durable output minimum

An ingest run is not successful unless it writes at least one of:

- `wiki/sources/*.md`
- `wiki/entities/*.md`
- `wiki/concepts/*.md`
- `wiki/queries/*.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`

Admin-only pages do not satisfy the contract.

## JSON result rules

`summary` must name the actual work.

`artifacts` must list concrete written files.

`memory_candidates` must reflect either:

- durable findings worth promotion
- or blockers with next actions

If only `raw/bootstrap/*` changed, the run is a blocker, not a success.

## Strong summary example

`Wrote raw/bootstrap/moonclaw-runtime.md, created wiki/sources/moonclaw-source.md, updated wiki/entities/moonclaw.md, and refreshed wiki/index.md plus wiki/log.md.`

## Weak summary to reject

`Completed provider task Bootstrap ingest and population.`
