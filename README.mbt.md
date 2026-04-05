# MoonBook

> 📚 MoonBit-native mdBook port + 🧱 static renderer + 🌐 local server + 🧠 persistent wiki workspace

`MoonBit` `mdBook` `Wiki` `SUMMARY.md` `HTML Renderer` `Serve` `Watch` `Rabbita`

MoonBook is a MoonBit rewrite of the mdBook toolchain, extended into a local wiki-maintainer workspace instead of stopping at static book generation.

It is designed for:

- 📖 mdBook-style markdown books
- 🏗️ static HTML builds
- 🌐 local serve + watch workflows
- 🧾 durable markdown knowledge bases
- 🧠 wiki ingest/query/review/lint flows
- 🔌 optional runtime integration through extension packs

## ✨ What MoonBook Feels Like

```text
markdown / summary / wiki workspace
  -> parse and normalize structure
  -> render to static HTML
  -> serve or watch locally
  -> ingest sources into a persistent wiki
  -> revise entities, concepts, synthesis, and review queues
```

MoonBook is strongest when you want one local system to handle:

- 📝 authored markdown books
- 🔁 repeatable static builds
- 🧭 readable navigation and rendering
- 🗂️ persistent wiki pages between sessions
- 🤝 agent-compatible wiki workspaces without hard-coupling to one runtime

## News

- `2026-04-05`: split wiki maintenance internals into dedicated workspace, maintenance-plan, and review-helper files; tightened summary dedupe by page path; cleaned entity/concept/claim normalization; updated the docs to reflect the refactored wiki package layout
- `2026-04-05`: added wiki review lifecycle commands with pending/approved queues, maintenance-plan updates, query-signal propagation, stronger claim status/support/confidence handling, and review-queue lint checks
- `2026-04-05`: deepened wiki ingest so sources now update related entity pages, concept pages, relationship sections, synthesis pages, and a structured claims register instead of only generating source summaries
- `2026-04-05`: refactored MoonClaw integration into an explicit extension-pack model so wiki workspaces stay agent-agnostic by default
- `2026-04-04`: added `wiki init`, `wiki ingest`, `wiki query`, and `wiki lint` as the first persistent wiki workflow slice on top of the existing mdBook-compatible renderer/CLI
- `2026-04-04`: brought `serve` and `watch` materially closer to mdBook with polling rebuilds, `.gitignore` filtering, `--open`, `--dest-dir`, generated 404 pages, and more complete HTML output behavior

## 🚀 Current Capabilities

- 📚 native MoonBit book/config model
- 🧭 `SUMMARY.md` parsing with numbering, nesting, parts, separators, draft chapters, duplicate detection, and README-to-index normalization
- 🏗️ end-to-end `init`, `build`, `serve`, `watch`, `load`, `test`, `clean`, and `version` commands
- 🌐 local static HTTP serving with polling rebuilds and current CLI conveniences like `--open`, `--dest-dir`, and `--watcher poll|native`
- 🧱 HTML rendering with sidebar navigation, breadcrumbs, previous/next links, local asset copying, code-block handling, tables, footnotes, raw HTML passthrough, and GitHub-style markdown layout cues
- 🧠 wiki workspace bootstrap with:
  - `raw/`
  - `wiki/`
  - `index.md`
  - `log.md`
  - `AGENTS.md`
  - seeded `entities/`, `concepts/`, `synthesis/`, `queries/`, `reviews/`, and `sources/`
- 📥 `wiki ingest` that:
  - imports sources
  - creates source pages
  - updates entity pages
  - updates concept pages
  - adds relationship sections from structured claims
  - updates `synthesis/overview.md`
  - updates `synthesis/claims.md`
  - updates `synthesis/maintenance-plan.md`
  - queues low-confidence or contested items in `reviews/pending.md`
- 🔎 `wiki query` that:
  - searches maintained wiki pages
  - synthesizes answers with citations
  - optionally saves query pages
  - updates `synthesis/query-insights.md`
  - propagates `Query Signals` into cited pages
  - updates the maintenance plan
  - can queue review items for promotion
- ✅ `wiki review` that:
  - lists pending review items
  - approves or rejects them
  - moves them into `reviews/approved.md`
  - promotes approved changes back into synthesis/claims pages
- 🩺 `wiki lint` that checks:
  - orphan pages
  - missing index entries
  - placeholder sections
  - stale wording
  - simple contradictions
  - missing concept pages
  - weak synthesis/claim coverage
  - unqueued low-confidence claims
  - review backlog growth
- 🔌 extension-based runtime integration with `moonclaw` as the first pack
- 🐇 Rabbita frontend scaffolding under `ui/`

## 🧩 Main Subsystems

- `core`
  mdBook-style book model and config decoding
- `summary`
  `SUMMARY.md` parsing and numbering logic
- `driver`
  book initialization, loading, preprocessing, manifest writing, and build orchestration
- `html`
  static HTML shell and markdown rendering layer
- `cmd/main`
  native CLI entrypoint
- `wiki`
  wiki workspace bootstrap, extension packs, ingest, query, review, lint, and shared maintenance/workspace helpers
- `internal`
  filesystem/path/server helpers adapted where needed from MoonClaw
- `ui`
  Rabbita frontend work

## ⚡ Quick Start

From the repo root:

```bash
cd ~/Workspace/moonbook
```

Check the project:

```bash
moon check
```

Create and build a normal book:

```bash
moon run cmd/main -- init ./book-example
moon run cmd/main -- build ./book-example
moon run cmd/main -- serve ./book-example -n 127.0.0.1 -p 3000 -o
```

Create a wiki workspace:

```bash
moon run cmd/main -- wiki init ./research-wiki
moon run cmd/main -- wiki enable moonclaw ./research-wiki
moon run cmd/main -- wiki ingest ./research-wiki ./raw/article.md
moon run cmd/main -- wiki query ./research-wiki "retrieval synthesis" --save
moon run cmd/main -- wiki review list ./research-wiki
moon run cmd/main -- wiki review approve ./research-wiki <review-id>
moon run cmd/main -- wiki lint ./research-wiki
moon run cmd/main -- build ./research-wiki
```

Useful validation commands:

```bash
moon test summary
moon test driver
moon test html
moon test wiki
```

## Docs

- [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md)
  concrete implemented cases and compatibility behavior
- [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md)
  commands, output files, workspace layout, and package organization
- [docs/SYSTEM_ARCHITECTURE.md](/Users/kq/Workspace/moonbook/docs/SYSTEM_ARCHITECTURE.md)
  book-vs-wiki architecture, package boundaries, and extension separation
- [docs/WIKI_WORKFLOW.md](/Users/kq/Workspace/moonbook/docs/WIKI_WORKFLOW.md)
  current init/ingest/query/review/lint loop for persistent wiki workspaces
- [docs/EXTENSION_PACKS.md](/Users/kq/Workspace/moonbook/docs/EXTENSION_PACKS.md)
  extension-pack model and the current MoonClaw integration boundary
- [docs/PORT_STATUS.md](/Users/kq/Workspace/moonbook/docs/PORT_STATUS.md)
  current parity boundary, remaining gaps, and suggested next work

## Current Boundary

MoonBook is not full upstream mdBook parity yet. It already handles a large local vertical slice, but it still lacks full theme/search/print parity, websocket live reload, a true native watcher backend, external renderer/preprocessor execution, and the full markdown/rendering edge-case surface of Rust mdBook.

On the wiki side, MoonBook now has a real persistent workspace loop with init+enable+ingest+query+review+lint+serve, but it still stops short of a full domain-tuned wiki-maintainer brain. Claim handling is still heuristic, review approvals mostly promote synthesis/claims rather than deep page-specific rewrites, and the deeper MoonClaw workflow pack still needs to become the preferred operational path rather than just an optional extension.
