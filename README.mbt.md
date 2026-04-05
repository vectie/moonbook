# Moonbook

> MoonBit-native mdBook port with a Rabbita frontend and an incremental compatibility layer over the original Rust implementation.

`MoonBit` `mdBook` `SUMMARY.md` `HTML Renderer` `CLI` `Rabbita`

Moonbook is a MoonBit rewrite of the mdBook toolchain currently focused on:

- loading and modeling books in MoonBit
- parsing `SUMMARY.md`
- building a static HTML output tree
- serving the built book over local HTTP
- watching source files and rebuilding on change
- respecting the book root `.gitignore` during polling rebuilds
- preserving mdBook-style navigation and many markdown rendering behaviors
- exposing a native CLI flow for `init`, `build`, `serve`, `watch`, `load`, `test`, and `clean`
- adding first wiki-workspace flows with `moonbook wiki init`, `moonbook wiki enable`, `moonbook wiki ingest`, `moonbook wiki query`, and `moonbook wiki lint`

The project is not at full upstream parity yet. The current state is a working vertical slice with a growing set of mdBook-compatible cases.

## Current Capabilities

- native MoonBit book/config model
- `book.toml` loading for core book/build/rust fields
- `SUMMARY.md` parsing with numbering, nesting, parts, separators, and draft chapters
- end-to-end `init`, `build`, `serve`, `watch`, `load`, `test`, `clean`, and `version` commands
- `moonbook wiki init` scaffolding for `raw/` + `wiki/` workspaces that can be built by MoonBook
- `moonbook wiki enable` for installing optional agent/runtime extension packs into a wiki workspace
- `moonbook wiki ingest` for one-source-at-a-time source ingestion that now also updates related entity pages, concept pages, synthesis pages, and a lightweight claims register
- `moonbook wiki query` for page search, answer synthesis from wiki pages, and saved query pages that also update durable query insights
- `moonbook wiki lint` for orphan/index/placeholder/stale-wording/simple-contradiction plus missing-concept and weak-synthesis health checks against the maintained wiki layer
- extension-based runtime integration with the first `moonclaw` pack
- HTML output with sidebar navigation, breadcrumbs, and previous/next links
- markdown rendering for the implemented mdBook-compatible cases listed in [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md)
- copied local asset handling for images and raw HTML references
- configured extra HTML CSS/JS asset copying and `CNAME` emission
- mdBook-style code block handling for playground and hidden-line cases
- local static hosting of the generated book
- Rabbita frontend scaffolding under `ui/`

## Quick Start

From the repo root:

```bash
moon check
moon run cmd/main -- init ./book-example
moon run cmd/main -- build ./book-example
moon run cmd/main -- serve ./book-example -n 127.0.0.1 -p 3000 -o

moon run cmd/main -- wiki init ./research-wiki
moon run cmd/main -- wiki enable moonclaw ./research-wiki
moon run cmd/main -- wiki ingest ./research-wiki ./raw/article.md
moon run cmd/main -- wiki query ./research-wiki "retrieval synthesis" --save
moon run cmd/main -- wiki lint ./research-wiki
moon run cmd/main -- build ./research-wiki
moon run cmd/main -- watch ./book-example -o
moon run cmd/main -- load ./book-example
moon run cmd/main -- test ./book-example
moon run cmd/main -- clean ./book-example
```

Useful commands:

```bash
moon run cmd/main -- version
moon test html
moon test summary
moon test driver
```

## Project Layout

- `core/`
  mdBook-style domain model and config decoding
- `summary/`
  `SUMMARY.md` parser and numbering logic
- `driver/`
  book initialization, loading, preprocessing, and manifest writing
- `html/`
  static HTML renderer and markdown compatibility layer
- `cmd/main/`
  native CLI entrypoint
- `wiki/`
  wiki workspace bootstrap, extension scaffolding, ingest, query, and lint flows
- `internal/`
  copied filesystem and path helpers adapted from MoonClaw
- `ui/`
  Rabbita frontend work

## Docs

- [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md)
  comprehensive implemented cases and renderer behavior
- [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md)
  commands, output files, and package structure
- [docs/PORT_STATUS.md](/Users/kq/Workspace/moonbook/docs/PORT_STATUS.md)
  current parity boundary, known gaps, and next major work areas

## Current Boundary

Moonbook currently behaves like a partial mdBook replacement for straightforward books. It includes static `serve`, polling `watch`, current CLI conveniences like `--open` and `--dest-dir`, generated 404 output, and some `output.html.*` support, but it does not yet provide full upstream behavior for websocket live reload, true native watcher parity, themes, search, preprocessors/plugins, print output, or the complete markdown/rendering edge-case surface of Rust mdBook.

MoonBook also now includes the first wiki-server milestones: `moonbook wiki init` creates an agent-agnostic workspace with `raw/` immutable sources, a `wiki/` markdown knowledge base, `index.md`, `log.md`, and an `AGENTS.md` schema file. `moonbook wiki enable <extension>` installs optional runtime packs, with `moonclaw` as the first supported extension. That extension writes `moonclaw.json`, `moonclaw.jobs.json`, `IDENTITY.md`, `USER.md`, `ROUTINES.md`, and `MEMORY.md`, plus a manifest under `.moonbook/extensions/`. `moonbook wiki ingest` now goes beyond a source page: it imports a source, generates a durable wiki source page under `wiki/sources/`, updates related `wiki/entities/` and `wiki/concepts/` pages, updates `wiki/synthesis/overview.md`, updates `wiki/synthesis/claims.md`, and records all touched pages in `SUMMARY.md`, `index.md`, and `log.md`. `moonbook wiki query` searches the maintained wiki pages, synthesizes an answer with citations, and with `--save` files the result back into `wiki/queries/` plus `wiki/synthesis/query-insights.md`. `moonbook wiki lint` checks for orphan pages, missing index references, placeholder sections, stale wording, simple contradictory `X is Y` claims, missing concept pages, and weak synthesis/claim coverage, and records the lint pass in `wiki/log.md`. The workspace is now capable of init+enable+ingest+query+lint+serve while keeping the core wiki contract separate from any one agent runtime.
