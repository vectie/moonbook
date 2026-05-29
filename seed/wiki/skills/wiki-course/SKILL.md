---
name: wiki-course
description: Maintain an educational course projection that teaches how the workspace works through structured modules, checkpoints, and plain-language system explanations.
---

# Wiki Course

## Purpose

Use this skill to teach a reader through a course.
This is not marketing, not journaling, and not a research report.

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

For a beginner course, use a sequence like:

1. what the system is
2. what the major actors do
3. how data moves
4. what a run looks like
5. where failures happen
6. what the operator can inspect

Use checkpoints, glossaries, and short examples.

For a full workbook, write 10-12 lessons unless the user requests a different
length. Each lesson should include:

- Objective
- Plain explanation
- Why it matters
- Concrete example
- Exercise
- Output artifact
- Checkpoint
- Common mistake

If the topic is a design/build topic, make every lesson produce a usable
artifact, such as a label JSON, tile grammar, style sheet, placement rule,
runtime binding, QA checklist, or final capstone page.

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
- `Deep Research Analysis` as a title
- `Verified Findings` or source audit as the main structure
- provider task status, ReviewQueued state, run ids, or raw execution logs in
  reader-facing lessons

## Output expectations

When used through provider-task execution, return JSON with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

When the task asks for course artifacts, the artifact list should include:

- `raw/bootstrap/course-outline.md`
- `raw/bootstrap/deep-report.md` when it is intentionally used as the workbook
- `wiki/synthesis/beginner-course.md`

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
- every lesson has a practice output and checkpoint
- no research-report skeleton leaked into the course

## Example Course Shape

```markdown
# Wenyu Valley Tile-Map Design: A Beginner Workbook

## Course Goal
Teach a beginner to build Wenyu Valley from reference map to working town UI.

## Lesson 1: Name The Product Before Drawing

### Objective
Define what the town is for before placing buildings.

### Plain explanation
A game-like town needs a product model, not only scenery.

### Why it matters
Without this, roads, buildings, agents, and tasks become unrelated decorations.

### Concrete example
Wenyu Valley is an AI innovation town where buildings host civic protocols and
agents move between home books and exchange buildings.

### Exercise
Write a one-paragraph product statement and list three non-goals.

### Output artifact
`docs/product-definition.md`

### Checkpoint
A new teammate can explain what belongs in the town and what belongs in
Moondesk.

### Common mistake
Starting with CSS offsets or random assets before defining the role of the
space.
```
