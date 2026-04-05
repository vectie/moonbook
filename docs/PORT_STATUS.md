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

- ingest still mostly creates source pages instead of revising `entities/`, `concepts/`, and `synthesis/`
- query is still keyword-ranked page synthesis rather than a deeper agentic read-plan-update workflow
- `moonclaw` is the only extension pack today
- `moonclaw.jobs.json` is a seeded profile template, not a domain-tuned job pack
- no claim model for supersession, support strength, or explicit confidence
- no review/approval workflow for agent-proposed wiki edits

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

1. upgrade `wiki ingest` to create and revise `entities/`, `concepts/`, and `synthesis/` pages
2. generalize the extension-pack format beyond the first `moonclaw` pack
3. turn the seeded MoonClaw wiki job profiles into a real domain workflow pack
4. continue renderer parity with more mdBook rendering tests
5. connect Rabbita to real built-book state and navigation

## Documentation Rule

When new compatibility work lands, update [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md) first. If the change affects command behavior or repo structure, also update [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md). If it changes the parity boundary, update this file.
