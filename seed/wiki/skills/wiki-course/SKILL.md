---
name: wiki-course
description: Maintain an educational course projection that teaches how the workspace works through structured modules, checkpoints, and plain-language system explanations.
---

# Wiki Course

## Purpose

Use this skill to teach the system.
This is not marketing and not journaling.

The course layer should explain:

- actors
- data flow
- process stages
- operator choices
- why the components relate the way they do

## Inputs

Read these first:

1. `wiki/index.md`
2. `wiki/history/journey.md`
3. `wiki/synthesis/map.md`
4. `wiki/synthesis/evidence.md`

Then inspect:

- relevant source pages
- key entity and concept pages
- current generated course output if it exists

## Educational boundary

Keep the course:

- explanatory
- modular
- plain-language
- structured

Do not make it:

- a product pitch
- a debug log
- a dense wiki dump

## Recommended structure

Use a sequence like:

1. what the system is
2. what the major actors do
3. how data moves
4. what a run looks like
5. where failures happen
6. what the operator can inspect

Use checkpoints, glossaries, and short examples.

## Good explanations

Prefer:

- concrete examples
- named files and artifacts
- one concept per section
- simple diagrams or flow language

Avoid:

- unexplained internal jargon
- giant prose blocks
- replaying every journal event

## Output expectations

When used through provider-task execution, return JSON with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

## Success criteria

A good course page should let a new reader answer:

- what are Moontown, MoonBook, and MoonClaw
- what does raw-first bootstrap mean
- what is the keeper doing
- where does durable knowledge live
- where can failures be debugged

## Example success summary

- "Refreshed the course projection to explain raw/bootstrap staging, keeper ingest, durable page revision, and the debug path from observations to journal and evidence."

## Anti-patterns

Do not:

- write like a press release
- assume the reader already knows the repos
- copy journal content verbatim
- replace the wiki with simplified but inaccurate claims

## Checklist

Before finishing, confirm:

- the page teaches rather than pitches
- the sections follow a learning sequence
- the language is plain enough for a new reader
- concrete file and workflow examples are included
