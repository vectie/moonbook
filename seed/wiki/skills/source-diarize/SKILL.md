---
name: source-diarize
description: Read one source deeply, separate substance from boilerplate, extract evidence and uncertainty, and produce a packet or summary that later wiki revision can ingest safely.
---

# Source Diarize

## Purpose

Use this skill when one source needs to be understood carefully before wiki revision.
The output of this skill should make later ingest easier and more accurate.

## Inputs

Expected inputs:

- one concrete source path
- optional question framing
- nearby maintained wiki pages for context

Read the source directly.
Do not rely on secondhand summaries if the source is available.

## Main tasks

1. separate navigation or scaffold noise from real content
2. identify the core claims
3. identify uncertainty and ambiguity
4. identify people, systems, or repos mentioned
5. identify recurring concepts
6. identify what pages should be touched

## Research mode

When this skill is used inside a research bootstrap, the diarization must support a visible research trail.
Do not produce a polished report first.
First produce evidence that another maintainer can audit.

The minimum research-mode outputs are:

- a screened source note for `raw/bootstrap/source-screen.md`
- one or more rows for `raw/bootstrap/evidence-matrix.md`
- local inspection notes for `raw/bootstrap/local-sources.md` when the source is a repo or file tree
- uncertainty notes for `raw/bootstrap/synthesis-brief.md`

### Source screening

Every source should be classified before it influences synthesis.
Use one of these statuses:

- `included`: directly inspected and useful for the question
- `excluded`: inspected or identified, but unrelated, duplicate, stale, or low-quality
- `deferred`: promising but not inspected yet
- `inaccessible`: identified but not readable with current tools or permissions

For each screened source record:

- title or path
- source type
- status
- why it matters or why it was rejected
- reliability level
- target wiki page, if any

Do not let a candidate list masquerade as evidence.
If the source was not read, it can guide future work but it cannot support a strong claim.

### Evidence matrix rows

For each useful source, extract evidence in a format that can be pasted into an evidence matrix.
A row should include:

- claim or theme
- exact source path or URL when available
- paraphrased evidence
- support level: strong, moderate, weak, or blocker
- uncertainty
- recommended target page

Example:

| Claim/theme | Source | Evidence | Support | Uncertainty | Target page |
| --- | --- | --- | --- | --- | --- |
| MoonBook owns durable workspace semantics | `README.md` | The source describes MoonBook as a wiki/book workspace with memory, ingest, query, lint, and projection surfaces. | moderate | Needs verification against package code for current behavior. | `wiki/entities/moonbook.md` |

### Contradiction handling

Contradictions are useful.
Do not hide them.
If the source disagrees with another source or with existing wiki state, record:

- old claim
- new claim
- source for each side
- likely explanation
- whether the older claim should be superseded, retained, or marked unresolved

### False-lead pruning

Ambiguous project names often produce unrelated public results.
When a result is unrelated, write down why it was rejected.
This prevents the next worker from rediscovering and re-evaluating the same false lead.

Examples:

- same name but unrelated organization
- unrelated product category
- stale page before the current architecture
- generated mirror with no original evidence
- package name collision

### Local repo inspection

When the source is a repository, inspect high-signal files before low-signal files:

1. `README.md`
2. `AGENTS.md`
3. `moon.mod.json`
4. top-level `docs/`
5. command entrypoints
6. package directories that match the research question
7. tests that demonstrate behavior

Do not count these as substantive:

- `.gitkeep`
- empty placeholder files
- generated build output
- dependency cache files
- lock files without surrounding explanation
- old temporary artifacts unless the question is specifically about them

## Output shape

A good diarized account should include:

- source identity
- source type
- source date, if present
- concise synopsis
- evidence bullets
- named entities
- recurring concepts
- open questions
- suggested target pages

## Quality rules

Do not:

- copy huge excerpts
- confuse headers with claims
- over-normalize weak evidence into strong facts
- ignore uncertainty
- promote inaccessible sources into verified claims
- write marketing claims before the evidence matrix exists

Prefer:

- concise evidence bullets
- clean distinction between fact and inference
- page-target suggestions that match existing ontology
- explicit source-screening status
- durable artifact paths that can be checked after the run

## Example good summary

- "This source explains MoonClaw provider-task behavior, names the extension target boundary, and implies a failure mode where generic provider results appear successful until MoonBook normalizes them."

## Example bad summary

- "This source is about MoonClaw."

## Anti-patterns

- giant excerpt dumps
- missing provenance
- no uncertainty section
- token-derived concept suggestions

## Checklist

Before finishing, confirm:

- source was read directly
- evidence bullets are concrete
- uncertainty is explicit
- target-page suggestions are useful
- source-screen status is recorded
- evidence matrix rows are ready
- false leads were marked instead of ignored
- no candidate source was treated as verified without inspection

## Failure modes

Common failure modes:

- treating boilerplate as substance
- writing evidence bullets that are actually conclusions
- failing to name what remains unknown
- suggesting new pages when an existing page should be revised
- returning generic completion text without artifact paths
- claiming that skills were unavailable without recording which skill path failed
- leaving web-search or local-inspect failures out of the research trail

If one of these happens, fix the structure before handing the packet to ingest.

## Minimal acceptable packet

A minimally acceptable packet should still include:

- one clear synopsis
- at least three evidence bullets
- at least one explicit uncertainty
- at least one suggested target page

If you cannot produce even that, return a blocker instead of a weak packet.
