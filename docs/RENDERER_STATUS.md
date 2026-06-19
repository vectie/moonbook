# Renderer Status

MoonBook is a standalone executable-book and wiki workspace system. This page
tracks the current book-rendering and workspace gaps without treating another
project as the target product.

## What Is Solid Right Now

- native MoonBit model for books/config
- `SUMMARY.md` parsing for the currently documented cases
- end-to-end local CLI flow for `book init`, `build`, `serve`, `watch`,
  `book load`, `book test`, and `book clean`
- first wiki bootstrap flow with `moonbook wiki init`
- first extension-based runtime integration flow with `moonbook wiki enable`
- optional `moontown` extension runtime for town-facing book orchestration
- `moontown`-aligned catalog export for persisted town bootstrap
- first wiki ingest/query/review/lint flows
- reusable extension API flow with `moonbook wiki extension`
- extension manifests under `.moonbook/extensions/`
- static HTML generation for normal chapter trees
- broad markdown coverage for common book content
- stable heading/link behavior for many inline cases
- playground and hidden-line treatment for code blocks
- local static HTTP serving of the built book
- local polling watcher that rebuilds on source/config changes
- common `serve`/`watch` CLI options like `--open`, `--dest-dir`, and
  `--watcher`
- `.gitignore`-aware polling rebuild filtering
- generated 404 pages with `site-url` handling
- configured extra CSS/JS assets and `CNAME` output

## What Is Still Missing

### CLI/Workflow Gaps

- served live reload websocket
- true native filesystem watcher backend for `--watcher native`
- stronger `book test` coverage for rendered links and code snippets
- richer `book init` templates for executable books, wiki extensions, and app books
- plugin/preprocessor command execution under MoonBook-owned contracts
- renderer extension points with explicit safety and review boundaries

### Config Gaps

- broader HTML-output configuration owned by MoonBook
- deeper lint analysis for missing concept/entity pages and richer
  contradiction resolution beyond the current structural checks
- first-class preprocessor configuration
- theme/search/playground configuration as MoonBook-native settings
- redirect and print-specific config support

### Wiki/Agent Gaps

- ingest updates source pages plus first-pass `entities/`, `concepts/`,
  reciprocal relationship sections, `synthesis/overview.md`,
  `synthesis/claims.md`, `synthesis/map.md`, `synthesis/maintenance-plan.md`,
  and pending review items, but richer domain-specific synthesis maintenance is
  still early
- query is still keyword-ranked page synthesis rather than a deeper
  read-plan-update workflow
- `moonclaw` and `moontown` are the current extension packs
- `moonclaw.jobs.json` is role-aware and aligned with the current
  wiki-maintainer pack shape; the boundary is raw research artifact collection
  in MoonClaw and durable wiki materialization in MoonBook
- research-envelope materialization is working, but richer domain-specific
  materialization still needs more structure
- the extension API and catalog export are file/CLI-oriented today; they are
  not yet a stronger service boundary
- claim tracking is stronger now with support/confidence/status/superseded
  markers plus an evidence page for persisted results, but it is still
  heuristic rather than a true claim graph with explicit evidence weighting
- review workflow has list/approve/reject commands, approved pages, durable
  promotion staging, evidence-status updates, and broader query-page promotion,
  but it still lacks a richer operator UI and full merge-policy system

### Rendering Gaps

- complete markdown edge-case coverage
- search output generation
- print renderer
- complete theme assets and theming behavior
- syntax highlighting integration
- more edge cases around HTML trees, escapes, and markdown nesting

### Frontend Gaps

- Rabbita has a real operator/dashboard surface and can consume
  rebuild-triggered workspace state refresh, but it is still not a fully
  integrated live editor/operator product
- no integrated live preview with rebuild-triggered browser refresh

## Suggested Next Work

High-value next steps:

1. deepen wiki synthesis beyond the current overview/claims/maintenance-plan/
   evidence pages into richer domain-specific multi-page revisions
2. turn review approvals into stronger page-specific revisions and merge-policy
   enforcement across more page families
3. make research-envelope materialization smarter about source IDs, entity
   relationships, and contradiction-aware synthesis
4. strengthen the `moontown` extension runtime around explicit town/book
   readiness, event, and review contracts
5. turn the seeded MoonClaw wiki job profiles into a real domain workflow pack
6. continue renderer coverage with MoonBook-native rendering tests

## Documentation Rule

When renderer or workspace behavior changes, update
[docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md)
first. If the change affects command behavior or repo structure, also update
[docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md).
If it changes product readiness, update this file.
