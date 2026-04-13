# System Architecture

MoonBook has two major product layers in one repo:

- the mdBook-compatible book toolchain
- the persistent wiki workspace layer

They share rendering/build/serve infrastructure, but they are not the same subsystem.

## Layered View

```text
markdown books / wiki workspaces
  -> summary + config parsing
  -> book/wiki loading and maintenance
  -> HTML rendering
  -> build output tree
  -> local serve/watch
```

## Book Toolchain

The mdBook-style path is centered around these packages:

- `core/`
  core data model and config access
- `summary/`
  `SUMMARY.md` parsing and numbering
- `driver/`
  initialization, loading, preprocessing, and build orchestration
- `html/`
  page-shell rendering and markdown-to-HTML output
- `cmd/main/`
  CLI entrypoint

This layer is responsible for:

- parsing books from disk
- normalizing chapter paths
- rendering chapter HTML
- writing `book.json`
- serving and watching the generated output

## Wiki Layer

The wiki path builds on the same rendering/build infrastructure, but introduces a maintained workspace model:

- `wiki/init.mbt`
  workspace bootstrap and seeded files
- `wiki/extensions.mbt`
  optional runtime/agent extension installation
- `wiki/ingest.mbt`
  source import, extraction, relationship updates, and claim maintenance
- `wiki/query.mbt`
  wiki-first retrieval, saved query pages, and query-signal propagation
- `wiki/review.mbt`
  review lifecycle commands
- `wiki/bookapi.mbt`
  town-facing book harness APIs for planning, context hydration, result persistence, catalog export, summary, and health
- `wiki/keeper_memory.mbt`
  bounded Keeper memory bootstrap, recall snapshots, and result-sync rules
- `wiki/lint.mbt`
  structural and wiki-health checks
- `wiki/workspace.mbt`
  shared workspace path resolution
- `wiki/maintenance.mbt`
  shared maintenance-plan writing
- `wiki/review_helpers.mbt`
  review-page parsing and normalization helpers

This layer is responsible for:

- creating `raw/` + `wiki/` workspaces
- maintaining bounded Keeper memory under `keeper/`
- maintaining persistent markdown pages across ingests
- tracking lightweight claims and review queues
- saving query results back into the wiki
- exposing the wiki as a normal MoonBook build/serve target

## Workspace Contract

A wiki workspace is intentionally file-based and agent-agnostic.

Core files and directories:

- `raw/`
  immutable source material
- `keeper/`
  bounded active, user, and working memory for Keeper
- `wiki/`
  maintained markdown knowledge base
- `wiki/SUMMARY.md`
  rendered navigation tree
- `wiki/index.md`
  content catalog
- `wiki/log.md`
  append-only operational history
- `AGENTS.md`
  maintainer instructions
- `wiki.toml`
  minimal workspace descriptor

Important wiki subdirectories:

- `keeper/`
- `wiki/sources/`
- `wiki/entities/`
- `wiki/concepts/`
- `wiki/synthesis/`
- `wiki/queries/`
- `wiki/reviews/`
- `wiki/synthesis/observations.md`

## Extension Boundary

MoonBook keeps runtime integration outside the core workspace contract.

The design intent is:

- `moonbook wiki init` creates an agent-agnostic workspace
- `moonbook wiki enable <extension>` installs optional runtime-specific files
- extension manifests live under `.moonbook/extensions/`

Current extension packs:

- `moonclaw`
- `moontown`

The current `moontown` alignment is intentionally additive:

- MoonBook exports a catalog-style book record for town bootstrap
- MoonBook exposes optional book-harness commands for planning, hydration, persistence, summary, and health
- MoonBook does not take over town scheduling or worker execution

This keeps MoonBook from depending on one agent runtime while still allowing runtime-specific setup.

## Current Internal Boundaries

The current split is:

- `driver/` and `html/`
  book rendering/runtime
- `wiki/`
  persistent wiki maintenance logic
- `internal/`
  low-level helpers for filesystem, path, server, and watch behavior

What should stay out of MoonBook core:

- runtime-specific job orchestration
- provider/model-specific agent logic
- external operator UX assumptions

Those belong in extension packs or external systems like MoonClaw and Moontown.
