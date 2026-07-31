---
name: wiki-course
description: Maintain evidence-linked reader projections that teach a specific audience through plain explanations, worked examples, practice, retrieval, and progressively deeper views.
---

# Wiki Course

## Purpose

Use this skill to teach a named reader through a course.
This is not marketing, not journaling, and not a research report.

Before drafting, read
[`references/human-readable-content.md`](references/human-readable-content.md).
It defines the MoonBook reader loop, projection levels, and release gates.

The course layer should explain the subject the reader needs to understand or
use. For a software workspace, that can include:

- actors
- data flow
- process stages
- operator choices
- why the components relate the way they do

For another domain, replace those system-specific topics with the domain's
core concepts, decisions, procedures, and evidence boundaries. Do not force a
software-workspace outline onto every book.

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

Also establish a reader contract before writing:

- a specific primary audience; `general public` is not specific enough
- what the reader already knows
- what the reader should understand or accomplish
- one main message, expressed in one to three short sentences
- the next useful action the reader should be able to take

## Educational boundary

Keep the course:

- explanatory
- modular
- plain-language
- structured
- evidence-linked
- appropriate to the named reader

Do not make it:

- a product pitch
- a debug log
- a dense wiki dump

## Recommended structure

For a beginner software course, a sequence might be:

1. what the system is
2. what the major actors do
3. how data moves
4. what a run looks like
5. where failures happen
6. what the operator can inspect

Use checkpoints, glossaries, and short examples. Change the sequence when the
reader's actual task requires a different route.

For a full workbook, write 10-12 lessons unless the user requests a different
length. Each lesson should include:

- Objective
- Plain explanation
- Why it matters
- Worked example with visible steps and result
- Exercise
- Output artifact
- Self-explanation question
- Closed-book retrieval checkpoint with a concealed answer
- Transfer task in a new situation
- Revisit prompt and `Revisit after days:` interval
- Common mistake
- Source references and important limitations

If the topic is a design/build topic, make every lesson produce a usable
artifact, such as a label JSON, tile grammar, style sheet, placement rule,
runtime binding, QA checklist, or final capstone page.

## Good explanations

Prefer:

- concrete examples
- named files and artifacts
- one concept per section
- simple diagrams or flow language
- the main message and next action in the first screenful
- familiar words, active voice, short chunks, and definitions at first use
- relevant words and visuals together when a visual materially helps
- a concrete case before asking a novice to solve an abstract case

Avoid:

- unexplained internal jargon
- giant prose blocks
- replaying every journal event
- `Deep Research Analysis` as a title
- `Verified Findings` or source audit as the main structure
- provider task status, ReviewQueued state, run ids, or raw execution logs in
  reader-facing lessons
- decorative visuals that do not teach
- readability scores as a substitute for comprehension testing

## Reader projections

Maintain one accepted body of knowledge and derive views from it. Do not write
three unrelated books whose facts can drift.

- **Learn** orients a newcomer, explains terms, shows worked examples, and
  provides retrieval checkpoints.
- **Apply** emphasizes procedures, decisions, templates, exercises, outputs,
  trade-offs, and transfer tasks.
- **Research** exposes methods, source anchors, contradictory evidence,
  uncertainty, limitations, and review lineage.

Operational state, raw execution logs, provider details, and maintenance
diagnostics belong in a separate **How maintained** disclosure. They must not
interrupt the reading path.

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

- what is the main idea
- why it matters to the named audience
- how the central mechanism or procedure works
- what a concrete example looks like
- what action or exercise comes next
- which claims are supported, uncertain, or limited

For a MoonSuite workspace course, the page may additionally teach product
roles, raw-first bootstrap, keeper behavior, durable knowledge, and the debug
path. Those are examples, not universal success criteria.

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

- a specific reader contract and one-to-three-sentence main message exist
- the page teaches rather than pitches
- the sections follow a learning sequence
- the language is plain enough for a new reader
- unfamiliar terms are defined at first use
- concrete worked examples show steps, reasoning, and results
- every lesson has a practice output, self-explanation prompt, retrieval
  checkpoint, transfer task, and positive revisit interval
- factual claims retain source references and important limitations
- the Learn, Apply, and Research projections point to the same accepted book
  revision
- maintenance details are outside the primary reading path
- a separate reviewer checks that simplification did not change the claim
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

### Worked example
Wenyu Valley is an AI innovation town where buildings host civic protocols and
agents move between home books and exchange buildings.

1. Name one building's domain.
2. Attach the accepted MoonBook for that domain.
3. Route a research task to the building.
4. Show the resulting book revision only after review.

### Exercise
Write a one-paragraph product statement and list three non-goals.

### Output artifact
`docs/product-definition.md`

### Self-explanation
Why should the town link to a MoonBook projection instead of keeping a second
copy of the explanation?

### Retrieval checkpoint
Without looking back, name the owner of domain knowledge and the owner of task
movement.

<details><summary>Reveal answer</summary>MoonBook owns the accepted domain
knowledge; MoonTown owns the civic visualization and task movement.</details>

### Transfer task
Apply the same ownership test to a MoonDesk view that displays this book.

### Revisit
Three days later, explain the ownership split without looking at the lesson.

Revisit after days: 3

### Common mistake
Starting with CSS offsets or random assets before defining the role of the
space.

### Sources and limitations
Link the product contracts that define ownership. Mark any unimplemented
handoff as proposed rather than implying that it already works.
```

## Exploration Quality Contract

Every run should improve the book's ability to answer deeper and broader
questions about its topic.

- Go deeper: explain the mechanism, evidence chain, confidence boundary,
  contradiction, or internal dependency that makes the result true, weak, or
  blocked.
- Go broader: connect the result to adjacent entities, concepts, source pages,
  downstream decisions, and book-maintenance consequences.
- Generate new questions: record follow-up questions that would change the
  answer, expose missing evidence, or open a useful next investigation.
- Generate new directions: name the next durable page, review item, experiment,
  comparison, or synthesis update that should grow from this work.
- Prefer longer meaningful text over short status output when evidence exists:
  give enough context that a future keeper can resume without the chat history.
