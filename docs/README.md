# MoonBook Documentation Guide

MoonBook is the durable executable book for MoonSuite. It owns accepted book
truth: raw sources, wiki pages, review queues, generated sites, book-owned
tools, app artifacts, events, and accepted outputs.

## Scope And Boundary

MoonBook owns:

- book/workspace lifecycle and `SUMMARY.md`/Markdown structure
- durable `raw/`, `wiki/`, `skills/`, `schemas/`, `tools/`, `apps/`, and
  generated-site surfaces
- wiki ingest, query, review, lint, standing-watch decisions, and generated
  knowledge bundles
- executable-book events and accepted artifact records
- seeded book skills and extension packs

MoonBook does not own agent execution, town scheduling, desktop projection,
suite metrics, or shared filesystem contracts. MoonClaw executes bounded work,
Moontown coordinates standing/cross-book work, Moondesk projects and edits
books, MoonStat observes, and MoonLib defines shared layout.

## Reading Order

1. [../README.md](../README.md): product overview and capabilities.
2. [EXECUTABLE_BOOK_BOUNDARY.md](EXECUTABLE_BOOK_BOUNDARY.md): core product
   boundary and event contract.
3. [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md): package architecture.
4. [CLI_AND_LAYOUT.md](CLI_AND_LAYOUT.md): CLI and workspace layout.
5. [FEATURE_MATRIX.md](FEATURE_MATRIX.md): feature status.
6. [EXTENSION_PACKS.md](EXTENSION_PACKS.md): optional runtime integration.
7. [WIKI_WORKFLOW.md](WIKI_WORKFLOW.md): wiki lifecycle.
8. [RENDERER_STATUS.md](RENDERER_STATUS.md): renderer status.

## Implementation Guidance

Book truth should be inspectable as files. Runtime integrations may stage
results, but accepted knowledge and executable artifacts must be persisted as
MoonBook-owned records or reviewable files. Seeded skills should remain
templates or book-local files, not hidden runtime behavior.

## Testing Guidance

```sh
moon check
moon test
moon info
moon fmt
```

For renderer changes, test book build, serve/watch, generated site paths, local
assets, navigation, and Markdown edge cases. For wiki or executable-book
changes, test ingest/query/review/lint, event persistence, review-required
state, and accepted artifact paths.

## Worth Noticing

- MoonBook must run as its own checkout; do not require sibling MoonClaw,
  Moontown, or Moondesk source trees.
- MoonCode artifacts are normal book artifacts only after persistence/review.
- Extension packs should be optional and configured, not hard dependencies.
- Generated output belongs under book output paths; source docs and templates
  should remain readable before any runtime runs.

## Future Plan

- Make the Code side as first-class as the Wiki side: `tools/`, `apps/`,
  package manifests, tests, review receipts, and executable promotion.
- Continue tightening knowledge bundle and graph contracts for suite consumers.
- Keep standing-watch and reverse-document routines book-local and inspectable.
- Add stronger end-to-end coverage for generated app-tool and executable-book
  promotion.
