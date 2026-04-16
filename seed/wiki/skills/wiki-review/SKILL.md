---
name: wiki-review
description: Review contested or high-value wiki changes for support, consistency, ontology quality, and promotion safety before they become trusted durable knowledge.
---

# Wiki Review

## Purpose

Use this skill when the system has a pending review item or a high-risk wiki change.
The purpose is to decide whether a proposed change should be:

- approved
- rejected
- revised

This is not a generic proofreading skill.
It is a promotion-safety and knowledge-quality skill.

## Inputs

Read these first:

1. `wiki/reviews/pending.md`
2. `wiki/reviews/approved.md`
3. `wiki/synthesis/evidence.md`
4. the target pages referenced by the pending item

Then inspect:

- linked source pages
- linked entity pages
- linked concept pages
- linked synthesis pages

If the review came from a persisted result, also inspect:

- `wiki/synthesis/observations.md`
- `wiki/history/journey.md`
- `wiki/history/debug-journal.md`

## References

Load these only when the review needs more detailed policy:

- `references/review-gates.md`
  - use when approval, rejection, or revision boundaries are unclear
- `references/review-examples.md`
  - use when the decision text needs concrete examples of good and bad review outcomes

## Main questions

For every review item, answer:

1. is the proposed content actually supported
2. is the wording too strong for the evidence
3. does the change fit the existing ontology
4. would approval create contradictions or duplication
5. is the change durable enough to justify promotion

## Approval criteria

Approve when:

- evidence is real and relevant
- page targets make sense
- the ontology stays clean
- the wording matches the level of support
- the result will improve future query quality

## Rejection criteria

Reject when:

- the evidence is missing or weak
- the content duplicates a better page
- the wording overstates the evidence
- the change is mostly chat residue
- the result is administrative noise rather than durable knowledge

## Revision criteria

Request revision when:

- the idea is good but the target page is wrong
- the claim is promising but under-supported
- the page structure is weak
- the evidence exists but the explanation is unclear

## Ontology rules

Protect the wiki from noisy page growth.

Do not approve:

- token-derived page names
- duplicate concept pages
- entity pages with no clear identity
- over-fragmented source summaries

Prefer:

- merging weak pages into stronger ones
- revising established pages
- adding links and evidence instead of making new stubs

## Evidence rules

Evidence should be:

- specific
- traceable
- recent enough when time-sensitive
- relevant to the exact promoted claim

Do not confuse:

- a source existing
- with that source actually supporting the promoted statement

## Output mode

If the review is conversational, answer with findings first.

If running through provider-task execution, return JSON with:

- `task_id`
- `summary`
- `artifacts`
- `memory_candidates`
- `requires_review`
- `notify_town`

The `summary` should clearly indicate:

- approved
- rejected
- or revision required

## Example approval summary

Good:

- "Approved promotion into wiki/synthesis/claims.md after confirming the linked source pages support the revised wording and no ontology conflicts were introduced."

Bad:

- "Review complete."

## Example provider-task output

```json
{
  "task_id": "goal-review-pending",
  "summary": "Approved the pending promotion into wiki/synthesis/claims.md and refreshed evidence plus review logs.",
  "artifacts": [
    "wiki/reviews/approved.md",
    "wiki/synthesis/claims.md",
    "wiki/synthesis/evidence.md",
    "wiki/log.md"
  ],
  "memory_candidates": [],
  "requires_review": false,
  "notify_town": false
}
```

## Anti-patterns

Do not:

- approve because the idea sounds reasonable
- reject without saying why
- approve duplicate pages
- promote unsupported synthesis into claims
- ignore linked evidence records
- use generic wording like "looks good"

## Final checklist

Before finishing, confirm:

- decision is explicit
- reasons are explicit
- support level matches the decision
- touched pages are listed
- no obvious ontology damage was introduced
