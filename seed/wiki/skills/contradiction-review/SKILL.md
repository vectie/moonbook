---
name: contradiction-review
description: Compare wiki pages and find unresolved contradictions, stale synthesis, or incompatible narratives.
---

# Contradiction Review

## Purpose

Use this skill when the wiki may contain incompatible narratives, stale synthesis, or claims that no longer coexist cleanly.

## Inputs

Read:

1. `wiki/synthesis/claims.md`
2. `wiki/synthesis/overview.md`
3. the specific source, entity, and concept pages implicated by the contradiction
4. `wiki/synthesis/evidence.md` when support needs checking

## Main questions

Determine:

- whether the pages truly disagree
- whether the disagreement is factual or interpretive
- whether the contradiction is resolved by dates, scope, or updated evidence
- what page should be revised first

## Real contradiction vs phrasing difference

A real contradiction changes meaning.
A phrasing difference does not.

Do not generate noise by flagging every wording variation.

## Output expectations

A useful contradiction review should include:

- the conflicting pages
- the conflicting statements
- the likely cause
- the recommended repair path

## Repair options

Typical repairs:

- narrow one claim
- add date or scope
- mark one claim superseded
- split one synthesis paragraph into supported alternatives
- queue review when support is ambiguous

## Anti-patterns

- vague claims like "these seem inconsistent"
- contradiction flags with no page targets
- treating uncertainty as contradiction
- treating chronology as contradiction when dates solve it

## Example summary

- "Detected one real contradiction between wiki/synthesis/claims.md and wiki/synthesis/overview.md; the likely fix is to add time scope and mark the earlier wording superseded."

## Checklist

Before finishing, confirm:

- the contradiction is real
- the affected pages are named
- the repair path is concrete
- uncertainty is preserved if the issue is unresolved

## Example real contradiction

- one page says a task is handled by MoonBook
- another page says the same responsibility belongs to MoonClaw directly

## Example non-contradiction

- one page gives a high-level summary
- another page gives a narrower scoped explanation

## Escalation rules

Escalate when:

- a contradiction affects durable claims
- a contradiction is driving user-facing synthesis
- the pages cannot be reconciled without review

## Additional heuristics

Prefer the following repair order:

1. add scope
2. add date
3. narrow wording
4. mark superseded
5. queue review

Do not jump straight to page deletion unless the contradiction is only duplicate noise.
