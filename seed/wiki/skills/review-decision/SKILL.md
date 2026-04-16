---
name: review-decision
description: Convert pending review items into explicit approve, reject, or revise decisions with clear reasons.
---

# Review Decision

## Purpose

Use this skill to convert a pending review item into a clean explicit decision.

## Inputs

Read:

1. the pending review item
2. linked evidence
3. linked target pages
4. linked observations when relevant

## Decision options

You must choose one:

- approve
- reject
- revise

Do not leave the result ambiguous.

## Reasoning rules

A good reason should state:

- what was evaluated
- why the evidence was sufficient or insufficient
- what should happen next

## Anti-patterns

- "looks good"
- "not convinced"
- decision with no supporting reason

## Checklist

Before finishing, confirm:

- the decision is explicit
- the reason is concrete
- the next maintenance pass can act on the reason

## Example approval

- "Approved because the linked source page now supports the narrower wording and the target page is the correct durable home."

## Example revision request

- "Revision required because the evidence is plausible but the target page should be a concept page, not a claim entry."

## Example rejection

- "Rejected because the proposed insight is mostly chat residue and adds no durable value."

## Final reminder

The decision should help the next pass act correctly without re-reading the whole chat.

## Additional heuristics

Approve when:

- support is present
- the target page is right
- the wording is appropriately scoped

Revise when:

- the idea is good but the structure is wrong
- confidence should be lowered
- the promotion target should change

Reject when:

- the content is mostly noise
- the evidence is absent
- the change would harm ontology quality

## Operator value

A good review decision reduces future ambiguity.
That is the real quality bar.

## Final operator reminder

If the next pass still would not know what to do, the decision text is not good enough.
State the target page implication when possible.
State the support implication when possible.
State the next action when possible.
Ambiguity is a defect here.
