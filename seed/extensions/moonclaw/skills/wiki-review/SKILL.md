---
name: wiki-review
description: Review skill for consistency, support, and maintenance quality in a MoonBook wiki workspace.
---

# Wiki Review

## Purpose

Use this extension review skill after a MoonClaw wiki-maintainer or revision run.
The goal is to validate quality before the result is treated as trustworthy.

## Inputs

Read:

1. changed `raw/bootstrap/*` packets, if any
2. changed wiki pages
3. `wiki/index.md`
4. `wiki/log.md`
5. relevant evidence and review pages

## References

Load these only when the extension review needs more exact policy:

- `references/moonclaw-review-gate.md`
  - use when deciding whether a controller result should be accepted, blocked, or sent back for another pass

## Main checks

Check for:

- missing or weak raw packets
- unsupported claims
- broken or missing links
- stale wording
- contradiction handling quality
- missing index/log maintenance
- administrative-only output being mislabeled as success

## Output behavior

Findings first.
If clean, state residual risk.

When used through provider-task execution, return strict JSON.

## Anti-patterns

- saying "looks fine" with no specifics
- ignoring missing `raw/bootstrap/*` artifacts in bootstrap runs
- approving ontology damage because the text reads smoothly

## Checklist

Before finishing, confirm:

- the run had real source grounding
- the changed pages are coherent
- the output class matches what actually changed
- the next action is clear if the run is weak

## Example good finding

- "The run produced raw/bootstrap/moonbook-overview.md and a maintained source page, but the entity page revision is still under-supported and should stay in review."

## Example bad finding

- "Looks mostly fine."

## Escalation rules

Escalate when:

- source grounding is missing
- the run claims success with empty artifacts
- the ontology got noisier
- contradictions were ignored

## Final reminder

This review is a quality gate.
Do not treat it as a courtesy pass.

## Additional diagnostic questions

Ask:

- did the run produce the raw artifacts it claimed
- did the run revise the durable pages it claimed
- is the summary stronger than the evidence
- would a future operator understand the failure from this review alone

## Example blocker wording

- "Blocked approval: bootstrap artifacts exist, but no substantive maintained page was produced and the result was mislabeled as progress."

## Example clean-pass wording

- "Clean enough to proceed: raw packets were written, one maintained source page was updated, and the remaining risk is only low-confidence synthesis wording."

## Operator reminder

If the review cannot tell a future operator what was actually weak, the review is incomplete.
This should read like a quality gate, not a courtesy note.
Name the weak boundary directly.
