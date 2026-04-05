# Port Status

Moonbook is a partial mdBook port, not a finished drop-in replacement.

## What Is Solid Right Now

- native MoonBit model for books/config
- `SUMMARY.md` parsing for the currently documented cases
- end-to-end local CLI flow for `init`, `build`, `serve`, `watch`, `load`, `test`, and `clean`
- first wiki bootstrap flow with `moonbook wiki init`
- first extension-based runtime integration flow with `moonbook wiki enable`
- first wiki ingest flow with `moonbook wiki ingest`
- first wiki query flow with `moonbook wiki query`
- first wiki lint flow with `moonbook wiki lint`
- extension manifests under `.moonbook/extensions/`
- static HTML generation for normal chapter trees
- broad markdown coverage for common book content
- mdBook-style heading/link behavior for many inline cases
- mdBook-style playground and hidden-line treatment for code blocks
- local static HTTP serving of the built book
- local polling watcher that rebuilds on source/config changes
- common `serve`/`watch` CLI options like `--open`, `--dest-dir`, and `--watcher`
- `.gitignore`-aware polling rebuild filtering
- generated 404 pages with `site-url` handling
- configured extra CSS/JS assets and `CNAME` output

## What Is Still Missing

### CLI/Workflow Gaps

- `serve` live reload websocket
- true native filesystem watcher backend for `--watcher native`
- `test` parity with upstream behavior
- `init` parity beyond the current minimal skeleton
- plugin/preprocessor command execution
- renderer extensibility surface

### Config Gaps

- broader `output.html.*` compatibility
- deeper lint analysis for missing concept/entity pages and richer contradiction resolution beyond the current structural checks
- full `preprocessor.*` compatibility
- theme/search/playground config parity
- redirect and print-specific config support

### Wiki/Agent Gaps

- ingest now updates source pages plus first-pass `entities/`, `concepts/`, relationship sections, `synthesis/overview.md`, `synthesis/claims.md`, `synthesis/maintenance-plan.md`, and pending review items, but it still does not do rich domain-specific synthesis maintenance
- query is still keyword-ranked page synthesis rather than a deeper agentic read-plan-update workflow
- `moonclaw` is the only extension pack today
- `moonclaw.jobs.json` is a seeded profile template, not a domain-tuned job pack
- claim tracking is stronger now with support/confidence/status/superseded markers, but it is still heuristic rather than a true claim graph with explicit evidence weighting
- review workflow now has list/approve/reject commands and an approved page, but it still lacks a richer operator UI and merge-policy system

### Rendering Gaps

- full CommonMark and pulldown-cmark parity
- search output generation
- print renderer
- complete theme assets and theming behavior
- syntax highlighting integration
- more mdBook edge cases around HTML trees, escapes, and markdown nesting

### Frontend Gaps

- Rabbita is still a shell rather than a complete operator/book-reading frontend
- no integrated live preview with rebuild-triggered browser refresh

## Suggested Next Work

High-value next steps:

1. deepen wiki synthesis beyond the current overview/claims/maintenance-plan pages into richer domain-specific multi-page revisions
2. turn review approvals into stronger page-specific revisions instead of mainly synthesis/claims updates
3. generalize the extension-pack format beyond the first `moonclaw` pack
4. turn the seeded MoonClaw wiki job profiles into a real domain workflow pack
5. continue renderer parity with more mdBook rendering tests

## Documentation Rule

When new compatibility work lands, update [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md) first. If the change affects command behavior or repo structure, also update [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md). If it changes the parity boundary, update this file.
