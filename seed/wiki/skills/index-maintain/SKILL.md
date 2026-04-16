---
name: index-maintain
description: Keep index and navigation surfaces clean, stable, and representative of the maintained wiki.
---

# Index Maintain

## Purpose

Use this skill to keep `wiki/index.md` and nearby navigation surfaces representative of the actual maintained wiki.

## Inputs

Read:

1. `wiki/index.md`
2. `wiki/SUMMARY.md`
3. newly touched wiki pages
4. `wiki/log.md` when recent changes matter

## Main questions

Determine:

- which pages deserve index visibility
- which entries are stale
- which labels are too noisy or too narrow
- whether a collapsed or merged page should be removed from navigation

## Good index maintenance

Good navigation is:

- stable
- high-signal
- ontology-aware
- not cluttered

## Bad index maintenance

Avoid:

- listing every weak page
- leaving dead entries after merges
- using labels that only make sense in one run
- duplicating the same concept under multiple weak names

## Anti-patterns

- index churn without content value
- token-derived labels
- ignoring summary/index drift

## Checklist

Before finishing, confirm:

- new important pages are represented
- dead or weak entries are removed or merged
- labels are stable
- navigation got clearer, not bigger

## Example good label

- "Raw-first bootstrap"

## Example bad label

- "Interesting thing from latest run"

## Escalation rules

Escalate when:

- the index is drifting from real workspace structure
- duplicate entries represent the same concept
- page labels are becoming too task-shaped

## Final reminder

Navigation quality is part of knowledge quality.

## Additional heuristics

Prefer labels that are:

- durable
- human-readable
- concept-shaped
- stable across runs

Avoid labels that are:

- based on one transient task
- overly long
- dependent on internal jargon without explanation

## Example navigation improvement

- replace two weak entries with one stable concept entry and one strong source entry
