---
name: source-diarize
description: Read one source deeply, separate substance from boilerplate, extract evidence and uncertainty, and produce a packet or summary that later wiki revision can ingest safely.
---

# Source Diarize

## Purpose

Use this skill when one source needs to be understood carefully before wiki revision.
The output of this skill should make later ingest easier and more accurate.

## Inputs

Expected inputs:

- one concrete source path
- optional question framing
- nearby maintained wiki pages for context

Read the source directly.
Do not rely on secondhand summaries if the source is available.

## Main tasks

1. separate navigation or scaffold noise from real content
2. identify the core claims
3. identify uncertainty and ambiguity
4. identify people, systems, or repos mentioned
5. identify recurring concepts
6. identify what pages should be touched

## Output shape

A good diarized account should include:

- source identity
- source type
- source date, if present
- concise synopsis
- evidence bullets
- named entities
- recurring concepts
- open questions
- suggested target pages

## Quality rules

Do not:

- copy huge excerpts
- confuse headers with claims
- over-normalize weak evidence into strong facts
- ignore uncertainty

Prefer:

- concise evidence bullets
- clean distinction between fact and inference
- page-target suggestions that match existing ontology

## Example good summary

- "This source explains MoonClaw provider-task behavior, names the extension target boundary, and implies a failure mode where generic provider results appear successful until MoonBook normalizes them."

## Example bad summary

- "This source is about MoonClaw."

## Anti-patterns

- giant excerpt dumps
- missing provenance
- no uncertainty section
- token-derived concept suggestions

## Checklist

Before finishing, confirm:

- source was read directly
- evidence bullets are concrete
- uncertainty is explicit
- target-page suggestions are useful

## Failure modes

Common failure modes:

- treating boilerplate as substance
- writing evidence bullets that are actually conclusions
- failing to name what remains unknown
- suggesting new pages when an existing page should be revised

If one of these happens, fix the structure before handing the packet to ingest.

## Minimal acceptable packet

A minimally acceptable packet should still include:

- one clear synopsis
- at least three evidence bullets
- at least one explicit uncertainty
- at least one suggested target page

If you cannot produce even that, return a blocker instead of a weak packet.
