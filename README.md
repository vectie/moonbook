# MoonBook

> 📚 MoonBit-native executable book workspace + 🧱 static renderer + 🌐 local server + 🧠 persistent wiki workspace + 🕰️ 24/7 standing-watch decisions + ✨ marketing website projection + 🧭 generated journal timeline + 🎓 generated course projection

`MoonBit` `MoonBook` `Wiki` `SUMMARY.md` `HTML Renderer` `Serve` `Watch` `Rabbita`

MoonBook is a MoonBit-native executable book and wiki workspace for durable sources, generated pages, review queues, and book-owned tools.

In the wider Moon architecture, MoonBook is the executable book: MoonWiki edits what the book says, MoonCode edits what the book can do, and MoonClaw executes bounded work. See [Executable Book Boundary](docs/EXECUTABLE_BOOK_BOUNDARY.md).

MoonBook treats a book as a live workspace: raw sources, durable wiki pages,
review queues, generated projections, executable events, and book-owned tools
are one native product surface rather than separate documentation scripts.

Current wiki workspaces use a raw-first bootstrap flow:

- MoonClaw workers stage discovered research artifacts under `raw/bootstrap/`
- MoonBook materializes those raw research envelopes into durable `wiki/*` pages
- `SKILL.md` files are repo-owned static templates copied from `seed/`, not generated at runtime
- recurring standing-watch checks are skill-guided book-local decisions: MoonBook compares the current baseline to new evidence, records `update | no_change | needs_review | failed`, and leaves scheduling to Moontown
- reverse-document work is also skill-guided: MoonBook keeps the same workspace loop while `document-reverse-engineer` deconstructs a finished document into logic, style, improvement, and regenerated draft artifacts

The CLI is now split more cleanly:

- `moonbook book ...` for workspace/book lifecycle
- `moonbook pack ...` for add-on installation
- `moonbook skill ...` for skill inventory, diagnostics, and live skill management
- `moonbook doctor ...` for top-level health checks
- `moonbook wiki ...` for wiki-specific operations

It is designed for:

- 📖 MoonBook markdown workspaces
- 🏗️ static HTML builds
- 🌐 local serve + watch workflows
- 🧾 durable markdown knowledge bases
- ✨ polished marketing websites under `site/`
- 🧭 compact history pages under `wiki/history/`
- 🧠 wiki ingest/query/review/lint flows
- 🔌 optional runtime integration through extension packs

## ✨ What MoonBook Feels Like

```text
markdown / summary / wiki / website workspace
  -> parse and normalize structure
  -> render to static HTML
  -> serve or watch locally
  -> ingest sources into a persistent wiki
  -> revise entities, concepts, synthesis, and review queues
  -> ship a polished marketing website from site/
```

MoonBook is strongest when you want one local system to handle:

- 📝 authored markdown books
- 🔁 repeatable static builds
- 🧭 readable navigation and rendering
- 🗂️ persistent wiki pages between sessions
- 🌐 a marketing-oriented website projection for demos and launches
- 🧭 a journey layer that turns noisy runs into a readable operator timeline
- 🎓 a course layer that teaches the workspace in plain language
- 🧩 a typed MoonBook knowledge bundle for suite consumers
- 🕸️ a generated graph of durable pages and cross-links
- 🤝 runtime-agnostic wiki workspaces without hard-coupling to one agent

## News

- `2026-06-28`: added the seeded `document-reverse-engineer` routine so a finished document can enter MoonBook from the reverse side: deconstruction, argument map, style profile, improvement plan, and regenerated draft over the same durable workspace loop
- `2026-06-19`: added the native `moonbook.book_state.v1` snapshot plus `moonbook.knowledge_bundle.v1`, generated graph files, `wiki state`, `wiki bundle`, `wiki graph`, and lint checks for missing MoonBook page metadata so suite tools can consume book state through concise MoonBook contracts instead of scraping wiki pages
- `2026-05-18`: added MoonBook-side standing-watch support for 24/7 topic monitoring: seeded `skills/standing-watch/SKILL.md`, dedicated `standing-watch` book tasks, worker context with baseline/history, result marker contracts, and durable `wiki/history/standing-watch.md` decision records
- `2026-04-22`: tightened the MoonBook/MoonClaw boundary so MoonClaw returns raw research envelopes while MoonBook owns durable wiki materialization, source quality/readiness classification, generated research-report projection, and a static `research-report` skill for article-quality synthesis
- `2026-04-22`: made `book/site/index.html` open the live generated marketing projection so readers no longer land on the generic authored source-site shell after build
- `2026-04-17`: added `skill hub` as a dedicated live backend for managing skills across the machine, with whole-machine scan roots, in-browser editing, automatic snapshots, rollback, `/api/debug`, and SSE-driven refresh
- `2026-04-16`: refactored the CLI around top-level `book`, `pack`, `skill`, and `doctor` surfaces, and added a first skill manager with inventory, show, compare, sync, install, scaffold, and doctor commands over workspace plus seeded skills
- `2026-04-16`: added `wiki/history/journey.md` as a compact run timeline, split the generated site into marketing and journal views, and embedded a `ctc`-inspired course projection plus `wiki-course` skill route
- `2026-04-15`: added an optional `site/` authored website layer for wiki workspaces, plus a dedicated marketing routine/skill boundary, and taught the build pipeline to publish it into `book/site/` alongside the rendered book and wiki
- `2026-04-19`: clarified the website split so `site/index.html` stays a standalone repo-owned source page while the live generated projections are emitted separately into `book/site/generated/`
- `2026-04-05`: split wiki maintenance internals into dedicated workspace, maintenance-plan, and review-helper files; tightened summary dedupe by page path; cleaned entity/concept/claim normalization; updated the docs to reflect the refactored wiki package layout
- `2026-04-05`: added wiki review lifecycle commands with pending/approved queues, maintenance-plan updates, query-signal propagation, stronger claim status/support/confidence handling, and review-queue lint checks
- `2026-04-05`: deepened wiki ingest so sources now update related entity pages, concept pages, relationship sections, synthesis pages, and a structured claims register instead of only generating source summaries
- `2026-04-05`: refactored MoonClaw integration into an explicit extension-pack model so wiki workspaces stay agent-agnostic by default
- `2026-04-04`: added `wiki init`, `wiki ingest`, `wiki query`, and `wiki lint` as the first persistent wiki workflow slice on top of the MoonBook renderer and CLI
- `2026-04-04`: hardened `serve` and `watch` with polling rebuilds, `.gitignore` filtering, `--open`, `--dest-dir`, generated 404 pages, and more complete HTML output behavior

## 🚀 Current Capabilities

- 📚 native MoonBit book/config model
- 🧭 top-level CLI split into `book`, `pack`, `skill`, `doctor`, and `wiki`
- 🧭 `SUMMARY.md` parsing with numbering, nesting, parts, separators, draft chapters, duplicate detection, and README-to-index normalization
- 🏗️ end-to-end `init`, `build`, `serve`, `watch`, `load`, `test`, `clean`, and `version` commands
- 🧰 `skill list`, `skill show`, `skill compare`, `skill sync`, `skill install`, `skill scaffold`, `skill doctor`, and `skill hub` for workspace plus machine-wide skill operations
- 🌐 local static HTTP serving with polling rebuilds and current CLI conveniences like `--open`, `--dest-dir`, and `--watcher poll|native`
- 🧱 HTML rendering with sidebar navigation, breadcrumbs, previous/next links, local asset copying, code-block handling, tables, footnotes, raw HTML passthrough, and GitHub-style markdown layout cues
- 🌐 optional repo-owned `site/` source website that is copied into `book/site/` during build and serve
- ✨ generated live marketing projection emitted into `book/site/generated/` from a skill-authored `marketing-brief.md`, keeping product copy out of renderer code
- 🧭 native book-state snapshot through `moonbook wiki state [root]`, writing `.moonbook/state.json`
- 🧩 native knowledge bundle export through `moonbook wiki bundle [root]`, writing `book/knowledge/manifest.json`, `graph.json`, and `pages.json`
- 🕸️ native graph projection through `moonbook wiki graph [root]` and generated `book/site/generated/graph.json`
- 📦 generated `book/site/generated/book-state.json` plus `knowledge-bundle.json` so suite apps can read current book state through stable MoonBook contracts
- 🔎 generated research-report projection with executive summary, architecture/runtime/memory sections, relationships, maturity gaps, and evidence table derived from `raw/bootstrap/` plus wiki synthesis pages
- 🧾 seeded `skills/research-report/SKILL.md` that tells keepers how to turn `research-question`, `source-screen`, `evidence-matrix`, local sources, and synthesis briefs into reader-facing reports without dumping raw table rows
- 🧩 seeded `skills/document-reverse-engineer/SKILL.md` for turning a strong finished document into deconstruction, argument map, style profile, improvement plan, and regenerated draft artifacts
- 🕰️ seeded `skills/standing-watch/SKILL.md` for recurring topic checks that compare new evidence against the current book baseline and emit machine-readable decision, source-count, fact-count, changed-page, and `book_changed` markers
- 🧭 durable standing-watch history under `wiki/history/standing-watch.md`, written when a book-local watch result is persisted
- 🧭 generated journal view emitted into `book/site/generated/journal.html` from live journey and workspace state
- 🎓 generated course view emitted into `book/site/generated/course.html` from live workspace and journey state
- 🛠️ generated skill manager emitted into `book/site/generated/skills.html` with inventory, duplicate detection, bundled-reference diagnostics, copyable lifecycle commands, override drift comparison against seeded baselines, and staged sync commands for candidate bundles
- 🖥️ dedicated `skill hub` backend with a browser UI for machine-wide skill scanning, direct in-browser editing, automatic snapshots, rollback, debug inspection, and live SSE refresh
- 🧠 wiki workspace bootstrap with:
  - `raw/`
  - `site/`
  - `wiki/`
  - `wiki/history/`
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
  - keeps `history/journey.md` compact and operator-readable as persisted work accumulates
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
  MoonBook data model and config decoding
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
moon run cmd/main -- book init ./book-example
moon run cmd/main -- build ./book-example
moon run cmd/main -- serve ./book-example -n 127.0.0.1 -p 3000 -o
```

Create a wiki workspace:

```bash
moon run cmd/main -- wiki init ./research-wiki
moon run cmd/main -- wiki enable moonclaw ./research-wiki
moon run cmd/main -- wiki ingest ./research-wiki ./raw/article.md
moon run cmd/main -- wiki query ./research-wiki "retrieval synthesis" --save
moon run cmd/main -- wiki state ./research-wiki
moon run cmd/main -- wiki bundle ./research-wiki
moon run cmd/main -- wiki graph ./research-wiki
moon run cmd/main -- wiki extension tasks ./research-wiki "standing-watch: periodically check latest sources about one person company and update only when there is a meaningful delta"
moon run cmd/main -- wiki review list ./research-wiki
moon run cmd/main -- wiki review approve ./research-wiki <review-id>
moon run cmd/main -- wiki lint ./research-wiki
moon run cmd/main -- build ./research-wiki
# optional: open ./research-wiki/book/site/index.html for the authored source website
# optional: open ./research-wiki/book/site/generated/index.html for the live generated projection
# optional: open ./research-wiki/book/site/generated/journal.html for the generated journal view
# optional: open ./research-wiki/book/site/generated/course.html for the generated course view
# optional: open ./research-wiki/book/site/generated/skills.html for the generated skill manager
# optional: inspect ./research-wiki/.moonbook/state.json for the standalone book-state snapshot
# optional: inspect ./research-wiki/book/site/generated/book-state.json, knowledge-bundle.json, and graph.json for suite consumers
moon run cmd/main -- skill hub ./research-wiki -n 127.0.0.1 -p 3456
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
  concrete implemented cases and current behavior
- [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md)
  commands, output files, workspace layout, and package organization
- [docs/SYSTEM_ARCHITECTURE.md](/Users/kq/Workspace/moonbook/docs/SYSTEM_ARCHITECTURE.md)
  book-vs-wiki architecture, package boundaries, and extension separation
- [docs/WIKI_WORKFLOW.md](/Users/kq/Workspace/moonbook/docs/WIKI_WORKFLOW.md)
  current init/ingest/query/review/lint loop plus the forward/reverse routine model for persistent wiki workspaces
- [docs/KEEPER_CALL_CHAIN.md](/Users/kq/Workspace/moonbook/docs/KEEPER_CALL_CHAIN.md)
  detailed end-to-end call chain for MoonBook keeper packet submission into MoonClaw
- [docs/EXTENSION_PACKS.md](/Users/kq/Workspace/moonbook/docs/EXTENSION_PACKS.md)
  extension-pack model and the current MoonClaw integration boundary
- [docs/RENDERER_STATUS.md](/Users/kq/Workspace/moonbook/docs/RENDERER_STATUS.md)
  current renderer readiness, remaining gaps, and suggested next work

## Current Boundary

MoonBook already handles a large local vertical slice, but it still lacks the full renderer surface expected of a production executable-book system: theme/search/print output, websocket live reload, a true native watcher backend, external renderer/preprocessor execution under MoonBook-owned contracts, and broader markdown/HTML edge-case coverage.

On the wiki side, MoonBook now has a real persistent workspace loop with init+enable+ingest+query+review+lint+serve, but it still stops short of a full domain-tuned wiki-maintainer brain. Claim handling is still heuristic, review approvals mostly promote synthesis/claims rather than deep page-specific rewrites, and extension runtimes still need stronger use of the native book-state and executable-event contracts.
