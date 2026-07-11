---
name: standing-watch
description: Run a recurring 24/7 topic check for a MoonBook workspace, compare new evidence against the book baseline, and decide whether to update, wait, escalate, or fail without hardcoding the topic.
---

# Standing Watch

## Purpose

Use this skill when a book is assigned a long-running watch goal.
The job is not to write a fresh report every time.
The job is to decide whether the latest check found enough new, credible, relevant information to change the book.

MoonBook owns this decision because MoonBook owns:

- the domain workspace
- durable wiki state
- source pages
- review queues
- memory promotion
- generated site projection

MoonClaw may search, fetch, inspect, and package work.
MoonTown may schedule the next check.
MoonBook decides whether the check produced a meaningful book delta.

## Research Temperament

A standing watch is not only a correctness check. It should show imagination,
curiosity, and judgement.

- **Imagination**: form plausible hypotheses about what may have changed, what
  second-order effects matter, and which adjacent domains may reveal early
  signals. Do not invent facts; use imagination to choose better questions.
- **Curiosity**: ask "why now?", "who is doing this differently?", "what would
  surprise the current book?", "what weak signal could become important?", and
  "what source would change my mind?"
- **Judgement**: separate signal from noise. Prefer sources that change the
  book's understanding, not sources that merely make the run look busy.
- **Taste**: write a compact digest that a busy human can trust. A good
  no-change digest is more valuable than a bloated fake update.

For each cycle, answer these questions before deciding:

- What did I expect to find, and what did I actually find?
- What is genuinely new compared with the book baseline?
- What is important but still too weak to promote?
- What should the next watch pass investigate differently?

## Inputs

Expected inputs:

- the standing goal text
- current wiki baseline pages
- previous `wiki/history/standing-watch.md` decisions, if any
- `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`, `wiki/queries/`, and synthesis pages
- source policy or tool availability notes from the task prompt
- candidate new sources found during the current run

If the topic depends on freshness, current events, market updates, or "latest" claims, use web search or web fetch before local-only inspection when those tools are available.
If web tools are unavailable, say that clearly and choose `failed`, `needs_review`, or conservative `no_change` according to the evidence you actually have.

## Decision Model

Make one of four decisions.

### `update`

Choose `update` when the current check finds meaningful new information that should change durable book state.

Examples:

- new credible source changes a previous claim
- new product, policy, funding, launch, benchmark, incident, or market signal affects the topic
- multiple sources improve confidence enough to revise a synthesis page
- a contradiction should be recorded in claims or review pages

Expected behavior:

- write or revise the relevant wiki pages
- cite source pages or artifacts
- add memory candidates only when durable value is clear
- set `notify_town` according to importance

### `no_change`

Choose `no_change` when the check was real but did not find meaningful new information.

Examples:

- sources inspected repeat the existing baseline
- only low-quality duplicates or mirrors were found
- search returned unrelated results
- a new source exists but does not change the book yet

Expected behavior:

- do not invent wiki updates
- return a compact result
- optionally record rejected false leads
- suggest a normal or slower next check

### `needs_review`

Choose `needs_review` when there may be a meaningful delta but it should not be promoted automatically.

Examples:

- evidence conflicts with existing wiki state
- the source is plausible but low confidence
- legal, medical, financial, reputation, or safety stakes are high
- the update would materially change a recommendation or public-facing claim

Expected behavior:

- queue or request review
- preserve evidence and uncertainty
- avoid promoting contested claims as settled facts
- set `requires_review` to true

### `failed`

Choose `failed` when the watch pass could not do the required work.

Examples:

- required source tools are unavailable
- all relevant sources are inaccessible
- the task lacks a clear watch topic and cannot infer one from context
- the worker hit a provider, network, or permission error that prevents a meaningful check

Expected behavior:

- state the blocker directly
- do not pretend the topic was checked
- set `requires_review` to true if an operator decision is needed

## Baseline Comparison

Before deciding, establish the current baseline.

Read or infer:

- what the book currently believes
- which source pages support those beliefs
- what previous watch decisions already rejected or deferred
- what would count as a meaningful delta for this topic
- which pages should change if a delta is real

Do not compare only against memory in the prompt.
Use actual workspace pages when they are available.

## Source Handling

Classify each candidate source.

Use one of these statuses:

- `included`: inspected and useful
- `repeated`: already covered by the book baseline
- `excluded`: unrelated, stale, duplicate, or low quality
- `deferred`: promising but not inspected deeply enough
- `inaccessible`: identified but not readable with current tools

For sources that influence a decision, keep provenance.
Prefer source pages or raw artifacts over free-floating claims in the summary.

## Output Contract

Return exactly one JSON object when used through a provider task.

Required keys:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

The `summary` must contain these marker lines exactly once:

```text
standing_goal_decision: update | no_change | needs_review | failed
delta_score: 0-100
new_source_count: <integer>
next_check_hint: normal | slower | faster | review
checked_sources_count: <integer>
new_sources_found: <integer>
accepted_facts_count: <integer>
rejected_facts_count: <integer>
wiki_pages_changed_count: <integer>
book_changed: yes | no
```

Meaning of fields:

- `standing_goal_decision`: the decision MoonTown should record
- `delta_score`: how strongly the new evidence changes the current baseline
- `new_source_count`: count of newly useful sources, not search results
- `next_check_hint`: scheduling hint for the mayor loop
- `checked_sources_count`: count of sources actually opened, fetched, read, or
  inspected deeply enough to judge
- `new_sources_found`: count of candidate sources that were not already known,
  including rejected or deferred candidates
- `accepted_facts_count`: count of new or revised facts accepted into durable
  wiki pages, review queues, or synthesis notes
- `rejected_facts_count`: count of candidate facts rejected as duplicate,
  irrelevant, unsupported, stale, or inaccessible
- `wiki_pages_changed_count`: count of durable wiki/book pages actually created
  or revised; operational logs do not count
- `book_changed`: `yes` only when durable book knowledge changed or a review
  item was queued; `no` for ordinary `no_change` and failed/tool-blocked cycles

Strict accounting rule:

- A failed check is not evidence progress.
- A no-change check is not evidence progress.
- Generated site rebuilds, retries, journal maintenance, and operational logs do
  not count as accepted facts or changed knowledge.
- `new_source_count` must never exceed the number of newly useful sources that
  affected durable memory, review, or synthesis.

Suggested `delta_score` interpretation:

- `0-10`: no real delta
- `11-35`: weak signal or mostly repeated material
- `36-65`: meaningful update or uncertainty worth tracking
- `66-85`: major book update or review-worthy contradiction
- `86-100`: urgent update, high impact, or operator escalation

## Memory And Wiki Rules

Do not promote everything.

Durable wiki updates are appropriate when:

- the source was inspected
- the evidence changes a page
- the claim can be traced
- uncertainty is explicit

Memory candidates are appropriate when:

- they help future watch passes decide faster
- they name a recurring source, entity, query, or false lead
- they should be remembered across runs

Review is appropriate when:

- confidence is low
- the claim is consequential
- the update conflicts with existing pages
- the topic has high external risk

## Examples

### Example: no meaningful delta

Task:

```text
Watch one person company developments and update this book only when new evidence changes the baseline.
```

Good result summary:

```text
standing_goal_decision: no_change
delta_score: 7
new_source_count: 0
next_check_hint: slower
checked_sources_count: 5
new_sources_found: 2
accepted_facts_count: 0
rejected_facts_count: 2
wiki_pages_changed_count: 0
book_changed: no
Checked current sources and found only repeated advice about solo founders, AI automation, and micro-SaaS. No inspected source changed the existing baseline, so no wiki page was promoted. False leads were repeated newsletter mirrors and unrelated company-registration pages.
```

Good JSON shape:

```json
{
  "task_id": "watch-opc-standing-watch",
  "summary": "standing_goal_decision: no_change\ndelta_score: 7\nnew_source_count: 0\nnext_check_hint: slower\nChecked current sources and found only repeated advice about solo founders, AI automation, and micro-SaaS. No inspected source changed the existing baseline, so no wiki page was promoted.",
  "artifacts": [],
  "memory_candidates": [
    {
      "kind": "false_lead",
      "title": "Company-registration pages are usually off-topic for OPC strategy watch",
      "detail": "Treat registry boilerplate as excluded unless the standing goal explicitly asks for legal formation tracking.",
      "durable": true,
      "target_page": "synthesis/observations.md"
    }
  ],
  "requires_review": false,
  "notify_town": false
}
```

### Example: meaningful update

Good result summary:

```text
standing_goal_decision: update
delta_score: 58
new_source_count: 2
next_check_hint: normal
checked_sources_count: 6
new_sources_found: 3
accepted_facts_count: 4
rejected_facts_count: 1
wiki_pages_changed_count: 3
book_changed: yes
Two newly inspected sources changed the baseline: one gives concrete evidence that solo AI teams are using agentic coding systems for production work, and another gives a counterexample where operational reliability remains the bottleneck. Updated the strategy and evidence pages with provenance and uncertainty.
```

Good artifact list:

```json
[
  "wiki/sources/solo-ai-teams-2026.md",
  "wiki/synthesis/overview.md",
  "wiki/synthesis/claims.md"
]
```

### Example: review needed

Good result summary:

```text
standing_goal_decision: needs_review
delta_score: 72
new_source_count: 1
next_check_hint: review
checked_sources_count: 4
new_sources_found: 1
accepted_facts_count: 0
rejected_facts_count: 0
wiki_pages_changed_count: 1
book_changed: yes
One credible source suggests a major change to the book's investment thesis, but the claim conflicts with older evidence and has financial implications. Preserved the source and queued review instead of promoting the conclusion as settled.
```

Good behavior:

- set `requires_review` to true
- cite the contested source
- update or append `wiki/reviews/pending.md` when possible

### Example: failed check

Good result summary:

```text
standing_goal_decision: failed
delta_score: 0
new_source_count: 0
next_check_hint: review
checked_sources_count: 0
new_sources_found: 0
accepted_facts_count: 0
rejected_facts_count: 0
wiki_pages_changed_count: 0
book_changed: no
The task required current web search, but web_search and web_fetch were unavailable in this run. No current-event claim was checked, and no baseline change should be inferred.
```

## Anti-Patterns

Do not:

- write a generic report every cycle
- treat search result snippets as verified sources
- promote inaccessible sources into durable claims
- hide failed source access behind `no_change`
- create marketing copy when the task is baseline monitoring
- hardcode the topic in the procedure
- use `update` just because the worker spent time

Prefer:

- small truthful deltas
- explicit false-lead pruning
- direct source provenance
- conservative review routing
- clean machine-readable marker lines

## Checklist

Before finishing, verify:

- the standing topic was understood
- baseline pages were checked when available
- source freshness matched the task need
- each useful new source was inspected, not just listed
- repeated or excluded sources were not counted as `new_source_count`
- marker lines are present exactly once
- accounting lines are present exactly once
- `book_changed: yes` matches real durable page changes or review queue changes
- failed/no-change cycles do not report accepted facts or changed pages
- `requires_review` matches the decision
- artifact paths exist or are clearly declared as intended outputs

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
