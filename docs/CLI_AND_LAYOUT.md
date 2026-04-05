# CLI And Layout

## Commands

### `moon run cmd/main -- init <root>`

Creates a minimal book project:

- `<root>/book.toml`
- `<root>/.gitignore`
- `<root>/src/SUMMARY.md`
- `<root>/src/chapter_1.md`
- `<root>/book/`

Current defaults:

- source directory: `src`
- build directory: `book`
- first chapter: `chapter_1.md`

### `moon run cmd/main -- build <root>`

Build pipeline:

1. load config
2. parse `src/SUMMARY.md`
3. load chapter files
4. preprocess README chapter paths into `index.*`
5. render HTML output
6. write `book/book.json`

### `moon run cmd/main -- serve <root> [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]`

Runs a local static HTTP server for the built book:

1. load config
2. optionally override the build directory
3. build the book into `build.build_dir`
4. optionally open the served URL in the system browser
5. bind an HTTP server
6. serve `index.html` at `/`
7. serve files directly from the build directory
8. serve `404.html` for missing paths when present
9. poll for source/config changes and rebuild the served output

### `moon run cmd/main -- wiki init [root]`

Bootstraps a wiki workspace instead of a plain mdBook:

1. creates `raw/` for immutable source material
2. creates `wiki/` as the rendered markdown knowledge base
3. writes `wiki/SUMMARY.md`, `wiki/Home.md`, `wiki/index.md`, and `wiki/log.md`
4. writes a root `AGENTS.md` schema file for future ingest/query/lint workflows
5. writes `book.toml` with `src = "wiki"` so the workspace can already be built and served by MoonBook
6. writes `wiki.toml` as a small machine-readable workspace descriptor
7. creates reserved directories for `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/`, `wiki/queries/`, and `wiki/sources/`

### `moon run cmd/main -- wiki enable <extension> [root]`

Installs an optional runtime/agent extension pack into an existing wiki workspace:

1. creates `.moonbook/extensions/`
2. writes an extension manifest for the selected pack
3. writes any extension-owned runtime/config/workspace files
4. preserves existing files instead of overwriting them

Current supported extensions:

- `moonclaw`

### `moon run cmd/main -- wiki ingest [root] <source>`

Ingests one source into an existing wiki workspace:

1. resolves the source path
2. copies it into `raw/imported/` when it is outside the workspace raw tree
3. derives a source title from the first heading or first non-empty line
4. writes a source page to `wiki/sources/<slug>.md`
5. extracts lightweight candidate entities and concepts from text sources
6. creates or updates related `wiki/entities/*.md` pages
7. creates or updates related `wiki/concepts/*.md` pages
8. creates or updates `wiki/synthesis/overview.md`
9. creates or updates `wiki/synthesis/claims.md` when claim-like statements are detected
10. appends touched pages to `wiki/SUMMARY.md`
11. updates the relevant sections in `wiki/index.md`
12. appends an ingest event to `wiki/log.md`

### `moon run cmd/main -- wiki query [root] <question> [--save]`

Queries the maintained wiki layer instead of raw files:

1. scans markdown pages under `wiki/`
2. ranks pages using simple keyword relevance
3. prints a synthesized markdown answer with page citations
4. with `--save`, writes the result to `wiki/queries/<slug>.md`
5. with `--save`, also updates `wiki/synthesis/query-insights.md`
6. with `--save`, also updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`

### `moon run cmd/main -- wiki lint [root]`

Runs a health check against the maintained wiki layer:

1. scans markdown pages under `wiki/`
2. detects orphan pages with no inbound links and no `SUMMARY.md` entry
3. detects pages missing from `wiki/index.md`
4. detects placeholder `_None yet._` sections still left in `wiki/index.md`
5. detects source pages missing their raw-source link
6. detects time-sensitive stale wording with no explicit dates
7. detects simple contradictory `X is Y` claims across pages
8. detects missing concept pages implied by existing source/entity/synthesis content
9. detects weak synthesis coverage for sources not reflected in synthesis pages
10. prints a markdown lint report
11. appends a lint event to `wiki/log.md`

Current defaults:

- hostname: `localhost`
- port: `3000`
- watcher: `poll`

Current note:

- `--watcher native` is accepted, but currently uses the polling backend

### `moon run cmd/main -- watch <root> [-d dest-dir] [-o] [--watcher poll|native]`

Runs a polling rebuild loop for the book:

1. load config
2. optionally override the build directory
3. build the book once
4. optionally open the generated `index.html` in the system browser
5. scan `book.src/` and `book.toml`
6. apply ignore rules from the book root `.gitignore`
7. poll for changes every second
8. rebuild on detected changes

Current note:

- `--watcher native` is accepted, but currently uses the polling backend

### `moon run cmd/main -- load <root>`

Loads the book and prints the full JSON representation of:

- root
- config
- book
- summary

This is useful for debugging the parsed chapter tree and path normalization.

### `moon run cmd/main -- test <root>`

Loads the book and reports the number of Rust fenced code blocks discovered in chapter content.

### `moon run cmd/main -- clean <root>`

Deletes the build directory and reports:

- files removed
- directories removed
- bytes removed

### `moon run cmd/main -- version`

Prints the current mdBook compatibility version from [core/book.mbt](/Users/kq/Workspace/moonbook/core/book.mbt).

## Output Files

Current build outputs:

- `index.html`
- one `.html` file per non-draft chapter
- copied local assets referenced by chapter content
- copied configured `output.html.additional-css` and `output.html.additional-js` assets
- `404.html` or another configured 404 output file
- `CNAME` when `output.html.cname` is set
- `book.json`

`book.json` contains:

- book root
- parsed config
- preprocessed book tree
- parsed summary tree

## Package Layout

### `core/`

Holds the mdBook-style data model and config parsing:

- `Book`
- `BookItem`
- `Chapter`
- `SectionNumber`
- `Config`

### `summary/`

Owns parsing `SUMMARY.md` into a typed tree that the driver can load from disk.

### `driver/`

Owns:

- initialization
- loading from disk
- missing-file generation
- build orchestration
- cleaning
- manifest writing
- `serve` build preparation through the shared load/build flow

### `html/`

Owns:

- navigation rendering
- page shell rendering
- markdown-to-HTML rendering
- code block post-processing
- asset collection and copying
- configured `output.html` asset injection and `CNAME` emission

### `internal/`

Contains internal filesystem/path helpers and a minimal HTTP static server adapted from MoonClaw where needed.

### `wiki/`

Contains the first wiki-oriented subsystem. It currently handles workspace initialization, optional runtime extension scaffolding, one-source-at-a-time ingestion, wiki-first querying with optional saved query pages, and lint-style health checks. Future deeper contradiction analysis should live here rather than inside the mdBook driver or HTTP server packages.

### Wiki Workspace Files

Created by `moonbook wiki init`:

- `raw/`
  immutable source material
- `wiki/`
  maintained markdown pages for the knowledge base
- `wiki/sources/`
  source summary pages
- `wiki/queries/`
  saved query pages
- `wiki/entities/`
  reserved directory for entity pages
- `wiki/concepts/`
  reserved directory for concept pages
- `wiki/synthesis/`
  reserved directory for synthesis pages
- `wiki/synthesis/claims.md`
  lightweight extracted claims with simple confidence markers when present
- `wiki/synthesis/query-insights.md`
  durable insights captured from saved queries
- `AGENTS.md`
  wiki-maintainer schema instructions
- `wiki.toml`
  workspace descriptor
- `.moonbook/extensions/`
  installed extension manifests

### `moonclaw` Extension Pack

Installed by `moonbook wiki enable moonclaw [root]`:

- `moonclaw.json`
  points MoonClaw at the same workspace root
- `moonclaw.jobs.json`
  seeds wiki-oriented MoonClaw job profiles
- `IDENTITY.md`, `USER.md`, `ROUTINES.md`, `MEMORY.md`
  MoonClaw-managed workspace context files

### `ui/`

Contains Rabbita frontend work. The shell compiles, but the UI is not yet feature-complete relative to the CLI/HTML side.
