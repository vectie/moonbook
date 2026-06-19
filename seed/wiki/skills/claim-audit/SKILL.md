---
name: claim-audit
description: Inspect claims for support, confidence, contradiction, and overreach before they are treated as durable knowledge or promoted without review.
---

# Claim Audit

## Purpose

Use this skill when a claim is being added, revised, reviewed, or promoted.
The task is to test whether the claim deserves durable status.

## Inputs

Read:

1. `wiki/synthesis/claims.md`
2. linked evidence records
3. linked source pages
4. linked synthesis pages when relevant

## Main questions

For each claim, determine:

- what exactly is being claimed
- what supports it
- how strong the support is
- whether the wording overreaches
- whether the claim conflicts with another page

## Audit rules

Mark claims carefully when they are:

- weak
- contested
- superseded
- inference-heavy

Do not let a plausible guess become a durable fact by inertia.

## Good audited claim

A good claim:

- is specific
- has visible support
- has scoped confidence
- does not hide contradictions

## Bad audited claim

A bad claim:

- sounds polished but is weakly supported
- merges multiple ideas into one vague statement
- lacks clear evidence paths

## Anti-patterns

- approving because the claim "feels right"
- treating one mention as stable support
- ignoring explicit contradictions

## Checklist

Before finishing, confirm:

- the exact claim text was inspected
- support is real and relevant
- confidence is appropriate
- unresolved disagreement is visible

## Escalation rules

Escalate when:

- a claim is being promoted into durable status with weak support
- the claim crosses multiple pages but no synthesis reconciles them
- the claim wording is broader than the evidence

## Example good audited conclusion

- "This claim is directionally plausible but under-supported; it should remain low-confidence and stay review-gated."

## Example bad audited conclusion

- "Probably true."

## Failure modes

Common failure modes:

- auditing the page generally without auditing the specific claim
- confusing adjacent evidence with supporting evidence
- accepting strong wording for weak support
- missing a nearby contradiction

If any of these happen, mark the claim for revision or review.

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
