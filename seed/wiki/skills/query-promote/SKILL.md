---
name: query-promote
description: Decide when a good answer should be promoted into the maintained wiki as durable knowledge.
---

# Query Promote

## Purpose

Use this skill to decide whether a query answer deserves promotion into the durable wiki.

## Inputs

Read:

1. the answer itself
2. cited pages
3. `wiki/synthesis/query-insights.md`
4. target pages that may receive the promoted content

## Promotion criteria

Promote when the answer:

- will likely matter again
- synthesizes multiple maintained pages
- adds a stable explanation
- improves future retrieval and understanding

Do not promote when the answer:

- is disposable
- is weakly supported
- only reformulates one source page

## Target selection

Possible targets:

- `wiki/queries/*.md`
- `wiki/synthesis/overview.md`
- `wiki/concepts/*.md`
- `wiki/entities/*.md`
- review queue when the answer is promising but risky

## Anti-patterns

- saving every answer
- promoting weak synthesis into claims
- writing query notes with no citations

## Checklist

Before finishing, confirm:

- the answer has lasting value
- the target page is appropriate
- evidence is visible
- disposable residue stayed out of the durable wiki

## Example good promotion

- save a cross-project explanation into `wiki/queries/` because it synthesizes multiple maintained pages and will likely be asked again

## Example bad promotion

- save a one-off status answer that only restates one debug page

## Escalation rules

Escalate when:

- the answer sounds strong but the wiki support is thin
- the target page is unclear
- the answer should become review-gated rather than directly promoted

## Additional heuristics

Prefer promotion when the answer:

- names a reusable distinction
- explains a failure boundary clearly
- connects multiple repos or systems

Avoid promotion when the answer:

- is just a transient status check
- depends on one administrative page
- would age out quickly

## Example high-value note

- a query note explaining why Moontown can route correctly while MoonClaw still fails at materialization

## Operator reminder

Promotion quality matters more than promotion volume.
Prefer one durable note with real value over five weak saved answers.
If in doubt, keep the answer provisional and add a follow-up instead.
Promotion is a trust decision.
