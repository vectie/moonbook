# MoonBook

> 📚 MoonBit-native rewrite of rust-lang/mdBook + 🧱 static renderer + 🌐 local server + 🧠 persistent wiki workspace + ✨ marketing website projection + 🧭 generated journal timeline + 🎓 generated course projection

`MoonBit` `mdBook` `Wiki` `SUMMARY.md` `HTML Renderer` `Serve` `Watch` `Rabbita`

MoonBook is a MoonBit rewrite of [rust-lang/mdBook](https://github.com/rust-lang/mdBook), extended into a local wiki-maintainer workspace instead of stopping at static book generation.

The project is also motivated by [karpathy/llm-wiki.md](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): the idea that raw sources should accumulate into a persistent, maintained markdown wiki rather than being rediscovered from scratch at query time.

Current wiki workspaces use a raw-first bootstrap flow:

- MoonClaw workers stage discovered research artifacts under `raw/bootstrap/`
- MoonBook materializes those raw research envelopes into durable `wiki/*` pages
- `SKILL.md` files are repo-owned static templates copied from `seed/`, not generated at runtime

The CLI is now split more cleanly:

- `moonbook book ...` for workspace/book lifecycle
- `moonbook pack ...` for add-on installation
- `moonbook skill ...` for skill inventory, diagnostics, and live skill management
- `moonbook doctor ...` for top-level health checks
- `moonbook wiki ...` for wiki-specific operations

It is designed for:

- 📖 mdBook-style markdown books
- 🏗️ static HTML builds
- 🌐 local serve + watch workflows
- 🧾 durable markdown knowledge bases
- ✨ polished marketing websites under `site/`
- 🧭 compact history pages under `wiki/history/`
- 🧠 bounded Keeper memory for active, user, and working context
- 🧠 wiki ingest/query/review/lint flows
- 🔌 optional runtime integration through extension packs
- 🏙️ optional `moontown` add-on for town-to-book orchestration without changing the core wiki contract

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
- 🧠 small rewriteable Keeper memory between worker runs
- 🤝 agent-compatible wiki workspaces without hard-coupling to one runtime

## News

- `2026-04-22`: tightened the MoonBook/MoonClaw boundary so MoonClaw returns raw research envelopes while MoonBook owns durable wiki materialization, source quality/readiness classification, generated research-report projection, and a static `research-report` skill for article-quality synthesis
- `2026-04-17`: added `skill hub` as a dedicated live backend for managing skills across the machine, with whole-machine scan roots, in-browser editing, automatic snapshots, rollback, `/api/debug`, and SSE-driven refresh
- `2026-04-16`: refactored the CLI around top-level `book`, `pack`, `skill`, and `doctor` surfaces, and added a first skill manager with inventory, show, compare, sync, install, scaffold, and doctor commands over workspace plus seeded skills
- `2026-04-16`: added `wiki/history/journey.md` as a compact run timeline, split the generated site into marketing and journal views, and embedded a `ctc`-inspired course projection plus `wiki-course` skill route
- `2026-04-13`: added Keeper evidence and insight maintenance so persisted worker results now append support records, stage durable promotions for review, refresh keeper health pages, maintain a synthesis map, and hydrate workers with better memory/page recall
- `2026-04-15`: added an optional `site/` authored website layer for wiki workspaces, plus a dedicated marketing routine/skill boundary, and taught the build pipeline to publish it into `book/site/` alongside the rendered book and wiki
- `2026-04-19`: clarified the website split so `site/index.html` stays a standalone repo-owned source page while the live generated projections are emitted separately into `book/site/generated/`
- `2026-04-05`: split wiki maintenance internals into dedicated workspace, maintenance-plan, and review-helper files; tightened summary dedupe by page path; cleaned entity/concept/claim normalization; updated the docs to reflect the refactored wiki package layout
- `2026-04-08`: added a book-harness API surface for `accept_goal`, `produce_task_batch`, `hydrate_worker_context`, `persist_result`, `summarize_state`, and `report_health`, plus an optional `moontown` extension pack so MoonBook can act as a per-domain harness without losing its standalone wiki behavior
- `2026-04-05`: added wiki review lifecycle commands with pending/approved queues, maintenance-plan updates, query-signal propagation, stronger claim status/support/confidence handling, and review-queue lint checks
- `2026-04-05`: deepened wiki ingest so sources now update related entity pages, concept pages, relationship sections, synthesis pages, and a structured claims register instead of only generating source summaries
- `2026-04-05`: refactored MoonClaw integration into an explicit extension-pack model so wiki workspaces stay agent-agnostic by default
- `2026-04-04`: added `wiki init`, `wiki ingest`, `wiki query`, and `wiki lint` as the first persistent wiki workflow slice on top of the existing mdBook-compatible renderer/CLI
- `2026-04-04`: brought `serve` and `watch` materially closer to mdBook with polling rebuilds, `.gitignore` filtering, `--open`, `--dest-dir`, generated 404 pages, and more complete HTML output behavior

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
- 🔎 generated research-report projection with executive summary, architecture/runtime/memory sections, relationships, maturity gaps, and evidence table derived from `raw/bootstrap/` plus wiki synthesis pages
- 🧾 seeded `skills/research-report/SKILL.md` that tells keepers how to turn `research-question`, `source-screen`, `evidence-matrix`, local sources, and synthesis briefs into reader-facing reports without dumping raw table rows
- 🧭 generated journal view emitted into `book/site/generated/journal.html` from live journey and workspace state
- 🎓 generated course view emitted into `book/site/generated/course.html` from live workspace and journey state
- 🛠️ generated skill manager emitted into `book/site/generated/skills.html` with inventory, duplicate detection, bundled-reference diagnostics, copyable lifecycle commands, override drift comparison against seeded baselines, and staged sync commands for candidate bundles
- 🖥️ dedicated `skill hub` backend with a browser UI for machine-wide skill scanning, direct in-browser editing, automatic snapshots, rollback, debug inspection, and live SSE refresh
- 🧠 wiki workspace bootstrap with:
  - `raw/`
  - `keeper/`
  - `site/`
  - `wiki/`
  - `wiki/history/`
  - `index.md`
  - `log.md`
  - `AGENTS.md`
  - seeded `entities/`, `concepts/`, `synthesis/`, `queries/`, `reviews/`, and `sources/`
  - seeded `synthesis/evidence.md`, `synthesis/map.md`, plus `keeper/INSIGHTS.md`
- 📥 `wiki ingest` that:
  - imports sources
  - creates source pages
  - updates entity pages
  - updates concept pages
  - adds relationship sections from structured claims
  - adds reciprocal relationship signals to related entity/concept pages
  - updates `synthesis/overview.md`
  - updates `synthesis/claims.md`
  - updates `synthesis/map.md`
  - updates `synthesis/maintenance-plan.md`
  - queues low-confidence or contested items in `reviews/pending.md`
  - keeps `history/journey.md` compact and operator-readable as persisted work accumulates
- 🔎 `wiki query` that:
  - searches maintained wiki pages
  - synthesizes answers with citations
  - optionally saves query pages
  - updates `synthesis/query-insights.md`
  - captures query takeaways into `keeper/MEMORY.md`
  - propagates `Query Signals` into cited pages
  - updates `synthesis/map.md`
  - updates the maintenance plan
  - can queue review items for promotion
- ✅ `wiki review` that:
  - lists pending review items
  - approves or rejects them
  - moves them into `reviews/approved.md`
  - promotes approved changes back into synthesis/claims/pages and cited query pages
  - resolves linked evidence records and refreshes Keeper insights
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
  - crowded Keeper memory and missing evidence capture
- 🔌 extension-based add-ons with `moonclaw` and `moontown` packs
- 🧱 workspace-owned source semantics so placeholder files like `.gitkeep` do not become durable source pages
- 🏙️ optional `moontown` add-on that exposes a town-facing book API over the same workspace
- 🧠 Keeper memory bootstrap with `keeper/MEMORY.md`, `keeper/USER.md`, `keeper/WORKING.md`, and `keeper/POLICY.md`
- 🧾 evidence tracking in `wiki/synthesis/evidence.md` for persisted worker results and review outcomes
- 🗺️ synthesis coverage tracking in `wiki/synthesis/map.md`
- 📈 Keeper health snapshots in `keeper/INSIGHTS.md`
- 🐇 Rabbita frontend with a documentation-first operator dashboard under `ui/`, now wired to `moonbook-ui-state.json` and rebuild-triggered live refresh

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
  wiki workspace bootstrap, extension packs, ingest, query, review, book-harness APIs, and shared maintenance/workspace helpers
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
moon run cmd/main -- wiki enable moontown ./research-wiki
moon run cmd/main -- wiki book catalog ./research-wiki
moon run cmd/main -- wiki ingest ./research-wiki ./raw/article.md
moon run cmd/main -- wiki book tasks ./research-wiki "refresh synthesis for new source"
moon run cmd/main -- wiki query ./research-wiki "retrieval synthesis" --save
moon run cmd/main -- wiki review list ./research-wiki
moon run cmd/main -- wiki review approve ./research-wiki <review-id>
moon run cmd/main -- wiki lint ./research-wiki
moon run cmd/main -- build ./research-wiki
# optional: open ./research-wiki/book/site/index.html for the authored source website
# optional: open ./research-wiki/book/site/generated/index.html for the live generated projection
# optional: open ./research-wiki/book/site/generated/journal.html for the generated journal view
# optional: open ./research-wiki/book/site/generated/course.html for the generated course view
# optional: open ./research-wiki/book/site/generated/skills.html for the generated skill manager
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

On the wiki side, MoonBook now has a real persistent workspace loop with init+enable+ingest+query+review+lint+serve, bounded Keeper memory, evidence capture for persisted results, a maintained synthesis map, staged durable promotion through review, and a book-local planning task surface. It still stops short of a full domain-tuned wiki-maintainer brain: claim handling is still heuristic, synthesis planning is still lighter than a full claim graph, and the deeper MoonClaw workflow pack still needs to become the preferred operational path rather than just an optional extension.

MoonBook also now exposes a book-harness surface intended for town-level orchestrators like `moontown`, including a machine-readable catalog export for the persisted town bootstrap path. That integration stays optional and file-based. A plain MoonBook workspace still builds, serves, and behaves as a standalone wiki without requiring any external control plane.

That book-harness surface now also smooths over two integration details:

- `wiki book context` can resolve external bootstrap-style task ids onto the nearest local MoonBook task kind instead of requiring an exact task id from the latest task batch
- `wiki enable moonclaw` seeds `.moonclaw/providers.json` with the provider-task target name `moonbook`, so MoonClaw has a workspace-local manifest for `wiki book tasks/context/persist`

The `moonclaw` add-on is also aligned with MoonClaw's current role substrate: MoonBook seeds a host-owned `Keeper` policy, wiki-maintainer/review skills, and role-aware controller/worker profiles so the embedded planner feels book-specific without hard-coding MoonClaw product policy into MoonBook core.
