# CLI And Layout

## Commands

### `moon run cmd/main -- book init [root]`

Compatibility-preserving top-level alias for plain book initialization.
Equivalent to `moon run cmd/main -- init [root]`.

### `moon run cmd/main -- book clean [root]`

Compatibility-preserving top-level alias for build cleanup.
Equivalent to `moon run cmd/main -- clean [root]`.

### `moon run cmd/main -- book load [root]`

Compatibility-preserving top-level alias for printing loaded book config/state.
Equivalent to `moon run cmd/main -- load [root]`.

### `moon run cmd/main -- book test [root]`

Compatibility-preserving top-level alias for the current lightweight book inspection test.
Equivalent to `moon run cmd/main -- test [root]`.

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
6. copy the optional root `site/` authored website into `book/site/` when present
7. generate a live marketing projection into `book/site/generated/` from wiki, keeper, review, and journey state when the workspace is a wiki
8. write `book/book.json`

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
2. creates `raw/bootstrap/` for generated source packets used during bootstrap discovery
3. creates `wiki/` as the rendered markdown knowledge base
4. writes `wiki/SUMMARY.md`, `wiki/Home.md`, `wiki/index.md`, and `wiki/log.md`
5. writes a root `AGENTS.md` schema file for future ingest/query/lint workflows
6. writes `book.toml` with `src = "wiki"` so the workspace can already be built and served by MoonBook
7. writes `wiki.toml` as a small machine-readable workspace descriptor
8. creates reserved directories for `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/`, `wiki/queries/`, and `wiki/sources/`
9. seeds repo-owned static `SKILL.md` templates into `skills/`
10. seeds `wiki/synthesis/claims.md`, `wiki/synthesis/maintenance-plan.md`, `wiki/synthesis/query-insights.md`, `wiki/synthesis/map.md`, `wiki/synthesis/observations.md`, `wiki/synthesis/evidence.md`, `wiki/reviews/pending.md`, and `wiki/reviews/approved.md`
11. seeds bounded Keeper memory files under `keeper/`, including `keeper/INSIGHTS.md`
12. seeds an optional `site/` marketing website projection with `index.html`, `styles.css`, and `app.js`

### `moon run cmd/main -- wiki enable <extension> [root]`

Installs an optional runtime/agent extension pack into an existing wiki workspace:

1. creates `.moonbook/extensions/`
2. writes an extension manifest for the selected pack
3. writes any extension-owned runtime/config/workspace files
4. copies extension-owned static `SKILL.md` templates from the repo seed directory
5. preserves existing files instead of overwriting them

Current supported extensions:

- `moonclaw`
- `moontown`

### `moon run cmd/main -- pack list`

Prints the currently supported extension pack ids.

### `moon run cmd/main -- pack enable <extension> [root]`

Top-level pack installer.
Equivalent to `moon run cmd/main -- wiki enable <extension> [root]`.

### `moon run cmd/main -- skill list [root]`

Prints a tabular inventory of:

- workspace `skills/`
- repo-seeded core skills under `seed/wiki/skills/`
- repo-seeded extension skills under `seed/extensions/*/skills/`

Each line includes skill name, scope, extension, and resolved `SKILL.md` path.

### `moon run cmd/main -- skill hub [root] [-n hostname] [-p port] [-o]`

Runs a dedicated live backend for machine-wide skill operations:

1. scans workspace `skills/`
2. scans repo-seeded `seed/wiki/skills/`
3. scans broader machine roots such as `$HOME/.claude/skills`, `$HOME/.claude/plugins`, `$HOME/.claude/projects`, current-working-directory ancestor skill folders, optional extra paths from `MOONBOOK_SKILL_HUB_EXTRA_PATHS` / `SKILL_HUB_EXTRA_PATHS`, and common development folders
4. writes live state under `<root>/.moonbook-skill-hub/`
5. serves a browser UI specialized for skill inventory, editing, snapshots, rollback, and debug
6. keeps the UI fresh through SSE events from `GET /api/events`

Current API surface:

- `GET /api/state`
- `GET /api/debug`
- `GET /api/snapshots?path=<skill-path>`
- `POST /api/save`
- `POST /api/rollback`
- `GET /api/events`

Current persistence layout:

- `<root>/.moonbook-skill-hub/state.json`
- `<root>/.moonbook-skill-hub/debug.json`
- `<root>/.moonbook-skill-hub/version`
- `<root>/.moonbook-skill-hub/snapshots/<skill-slug>/<timestamp>/`

### `moon run cmd/main -- skill show <name> [root]`

Prints one resolved skill record as JSON.
Current metadata includes:

- name
- scope
- origin
- extension
- path
- bundled references
- override/shadow relationships
- line count

### `moon run cmd/main -- skill compare <name[@extension]> [root]`

Prints a machine-readable drift report for the selected skill against its nearest baseline.
Current behavior:

- prefers a workspace-owned skill when the same name exists in multiple scopes
- compares a workspace override against its seeded baseline
- compares a seeded skill against its workspace shadow when one exists
- reports changed shared lines, selected-only lines, baseline-only lines, first change line, and short excerpts from both sides

### `moon run cmd/main -- skill sync <name[@extension]> [root]`

Stages a reviewable candidate bundle for a workspace-owned skill override.
Current behavior:

- requires a workspace-owned skill plus a seeded baseline
- copies the workspace skill tree into `skill-candidates/<slug>/workspace/`
- copies the seeded baseline tree into `skill-candidates/<slug>/baseline/`
- writes `skill-candidates/<slug>/SYNC.json` with the latest compare summary and source paths
- does not mutate repo `seed/` directories directly

### `moon run cmd/main -- skill install <name[@extension]> [root]`

Copies one seeded skill into workspace `skills/` so it becomes locally owned and editable.
Current behavior:

- resolves the named skill from repo-seeded core or extension packs
- prefers the core-seeded variant when the same name also exists in extension packs
- accepts `name@extension` when you want the extension-specific variant explicitly
- preserves bundled `references/` and other skill files by copying the whole skill directory

### `moon run cmd/main -- skill scaffold <name> [root]`

Creates a new workspace-owned skill template under `skills/<slug>/`.
The scaffold includes:

- a substantial `SKILL.md` skeleton with boundary, inputs, outputs, workflow, and quality-bar sections
- empty `references/` and `agents/` directories for later expansion

### `moon run cmd/main -- skill doctor [root]`

Runs skill inventory diagnostics:

- duplicate skill names across scopes
- missing bundled `references/` files
- workspace overrides of seeded skills
- missing descriptions

### `moon run cmd/main -- doctor [root]`

Runs a top-level MoonBook health check:

1. runs `skill doctor`
2. if the root looks like a wiki workspace, also prints wiki health and coverage summary
3. otherwise reports that wiki health was skipped

### `moon run cmd/main -- wiki book accept [root] <goal>`

Runs the town-to-book acceptance check and prints JSON:

1. inspects the current book state
2. plans a local task batch for the goal
3. returns whether the goal is accepted into book-local planning

### `moon run cmd/main -- wiki book tasks [root] <goal>`

Produces a machine-readable local task batch for a town-issued goal:

1. inspects current book state and review backlog
2. derives local review, synthesis, analysis, or ingest-follow-up tasks
3. emits a dedicated planning task when health signals or goal wording indicate planning pressure
4. prints a JSON task batch

### `moon run cmd/main -- wiki book context [root] <goal> [--task <task-id>]`

Hydrates a worker-ready context bundle:

1. derives the local task batch for the goal
2. selects the first task or the requested `--task`
3. if the requested `--task` is an external bootstrap-style id, resolves it onto the nearest local MoonBook task kind when possible
4. packages prompt, policy lines, routine lines, relevance-ranked context pages, Keeper memory slices, and memory summary
5. prints a JSON worker context bundle

### `moon run cmd/main -- wiki book persist [root] <result.json>`

Persists a machine-readable worker result back into the book:

1. reads a JSON `BookResult`
2. appends it to `wiki/synthesis/observations.md`
3. records a support entry in `wiki/synthesis/evidence.md`
4. syncs non-durable memory candidates into bounded Keeper memory files
5. promotes immediately-safe durable memory candidates into target pages
6. refreshes `keeper/INSIGHTS.md`
7. updates `wiki/synthesis/maintenance-plan.md`
8. optionally queues a review item for staged durable promotion
9. appends a persist event to `wiki/log.md`

### `moon run cmd/main -- wiki book catalog [root]`

Prints a JSON catalog record aligned with the current `moontown` persisted book-provider boundary:

- book id
- display name
- purpose
- workspace root
- memory scope
- tags
- skills

### `moon run cmd/main -- wiki book summary [root]`

Prints a JSON summary of current book-local state.

### `moon run cmd/main -- wiki book health [root]`

Prints a JSON health report for the book.

### `moon run cmd/main -- wiki ingest [root] <source>`

Ingests one source into an existing wiki workspace:

1. resolves the source path
2. rejects hidden placeholders, empty files, and workspace scaffolding such as `.gitkeep`
3. copies it into `raw/imported/` when it is outside the workspace raw tree
4. derives a source title from the first heading or first non-empty line
5. writes a source page to `wiki/sources/<slug>.md`
6. extracts lightweight candidate entities and concepts from text sources
7. creates or updates related `wiki/entities/*.md` pages
8. creates or updates related `wiki/concepts/*.md` pages
9. adds relationship entries to relevant entity pages when structured claims point at entities or concepts
10. adds reciprocal relationship entries to related entity/concept pages
11. creates or updates `wiki/synthesis/overview.md`
12. creates or updates `wiki/synthesis/claims.md` with structured claim entries, ids, kinds, related pages, support counts, status, and superseded markers when claim-like statements are detected
13. refreshes `wiki/synthesis/map.md`
14. creates or updates `wiki/synthesis/maintenance-plan.md` with a multi-page follow-up entry
15. queues contested or low-confidence claim updates in `wiki/reviews/pending.md`
16. appends touched pages to `wiki/SUMMARY.md`
17. canonicalizes the relevant sections in `wiki/index.md`
18. appends an ingest event to `wiki/log.md`

### `moon run cmd/main -- wiki query [root] <question> [--save]`

Queries the maintained wiki layer instead of raw files:

1. scans markdown pages under `wiki/`
2. ranks pages using simple keyword relevance
3. prints a synthesized markdown answer with page citations
4. with `--save`, writes the result to `wiki/queries/<slug>.md`
5. with `--save`, also updates `wiki/synthesis/query-insights.md`
6. with `--save`, also appends a condensed insight into `keeper/MEMORY.md`
7. with `--save`, propagates `Query Signals` into cited entity/concept/source pages
8. with `--save`, updates `wiki/synthesis/maintenance-plan.md`
9. with `--save`, refreshes `wiki/synthesis/map.md`
10. with `--save`, can queue a pending review item for promoting the answer into maintained wiki pages
11. with `--save`, also updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`

### `moon run cmd/main -- wiki review list [root]`

Lists pending review items with:

- review id
- review kind
- status
- title

### `moon run cmd/main -- wiki review approve [root] <review-id>`

Approves one pending review item:

1. removes it from `wiki/reviews/pending.md`
2. appends it to `wiki/reviews/approved.md`
3. promotes the approved result back into synthesis pages or staged durable target pages
4. for claim reviews, updates `wiki/synthesis/claims.md`
5. for query reviews, updates `wiki/synthesis/overview.md` plus cited entity/concept/source pages
6. updates linked evidence records when present
7. refreshes `wiki/synthesis/map.md`
8. refreshes `keeper/INSIGHTS.md`
9. updates `wiki/synthesis/maintenance-plan.md`
10. appends a review event to `wiki/log.md`

### `moon run cmd/main -- wiki review reject [root] <review-id>`

Rejects one pending review item:

1. removes it from `wiki/reviews/pending.md`
2. appends it to `wiki/reviews/approved.md` with rejected status
3. updates `wiki/synthesis/maintenance-plan.md`
4. appends a review event to `wiki/log.md`

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
10. detects low-confidence claims that are not actually queued in the review system
11. detects growing low-confidence review backlog
12. detects crowded Keeper memory and missing evidence capture
13. prints a markdown lint report
14. appends a lint event to `wiki/log.md`

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

Contains the first wiki-oriented subsystem. It currently handles workspace initialization, optional runtime extension scaffolding, one-source-at-a-time ingestion, wiki-first querying with optional saved query pages, review lifecycle commands, town-facing book-harness APIs, lint-style health checks, and shared internal helpers for workspace resolution plus maintenance-plan/review-page updates. Future deeper contradiction analysis should live here rather than inside the mdBook driver or HTTP server packages.

Related architecture docs:

- [SYSTEM_ARCHITECTURE.md](/Users/kq/Workspace/moonbook/docs/SYSTEM_ARCHITECTURE.md)
- [WIKI_WORKFLOW.md](/Users/kq/Workspace/moonbook/docs/WIKI_WORKFLOW.md)
- [EXTENSION_PACKS.md](/Users/kq/Workspace/moonbook/docs/EXTENSION_PACKS.md)

Current package organization:

- `init.mbt`
  workspace bootstrap and seeded wiki files
- `extensions.mbt`
  optional runtime/agent extension installation
- `bookapi.mbt`
  reusable town-facing book harness APIs for planning, context hydration, result persistence, catalog export, summary, and health
- `keeper_memory.mbt`
  bounded Keeper memory bootstrap, recall snapshots, and result-sync rules
- `keeper_evidence.mbt`
  evidence records for persisted worker results and review outcomes
- `keeper_insights.mbt`
  derived Keeper health signals and cleanup suggestions
- `ingest.mbt`
  source import, entity/concept extraction, relationship updates, and claims maintenance
- `query.mbt`
  wiki-first ranking, answer synthesis, saved query pages, and query-signal propagation
- `review.mbt`
  pending review listing plus approve/reject lifecycle actions
- `lint.mbt`
  structural and review/claim health checks
- `workspace.mbt`
  shared workspace path resolution
- `maintenance.mbt`
  shared synthesis maintenance-plan writing
- `review_helpers.mbt`
  shared parsing and normalization for review pages

### Wiki Workspace Files

Created by `moonbook wiki init`:

- `raw/`
  immutable source material
- `site/`
  optional repo-owned source website copied to `book/site/` during build and serve
- `site/index.html`
  landing page scaffold for the repo-owned source website; it should remain valid even before generated projections exist
- `site/styles.css`
  expressive visual system for the repo-owned source website
- `site/app.js`
  lightweight reveal and interaction behavior for the repo-owned source website
- `book/site/generated/index.html`
  live generated marketing projection built from current workspace state
- `book/site/generated/marketing-state.json`
  machine-readable snapshot used by the generated marketing projection
- `book/site/generated/journal.html`
  generated journal view built from live workspace and journey state
- `book/site/generated/course.html`
  generated educational course view built from live workspace and journey state
- `book/site/generated/skills.html`
  generated skill manager view built from workspace, core-seed, and extension-seed skill inventory
- `book/site/generated/skills-state.json`
  machine-readable skill inventory and diagnostics snapshot used by the generated skill manager
- `wiki/history/journey.md`
  compact operator timeline distilled from persisted book results
- `wiki/history/debug-journal.md`
  detailed debug trail for intermediate material preparation and result quality
  includes explicit readiness signals such as source, entity, concept, and query counts plus `substantive_coverage_ready`
- `keeper/MEMORY.md`
  bounded reusable domain memory for Keeper
- `keeper/USER.md`
  stable user preferences and collaboration habits
- `keeper/WORKING.md`
  short-lived active task and observation memory
- `keeper/POLICY.md`
  Keeper admission and promotion rules
- `keeper/INSIGHTS.md`
  derived Keeper health and suggested cleanups
- `wiki/`
  maintained markdown pages for the knowledge base
- `wiki/sources/`
  durable source summary pages generated from raw material
- `wiki/queries/`
  saved query pages and durable analysis notes
- `wiki/entities/`
  maintained entity pages
- `wiki/concepts/`
  maintained concept pages
- `wiki/synthesis/`
  maintained synthesis pages and research readiness signals
- `wiki/synthesis/claims.md`
  lightweight structured claims with confidence/support/status/superseded markers when present
- `wiki/synthesis/maintenance-plan.md`
  queued multi-page maintenance actions produced by ingest, query, and review flows
- `wiki/synthesis/query-insights.md`
  durable insights captured from saved queries
- `wiki/synthesis/map.md`
  coverage and maintenance view across entities, concepts, claims, and open loops
- `wiki/synthesis/observations.md`
  persisted worker results and promoted observations
- `wiki/synthesis/evidence.md`
  evidence records linked to persisted results and review outcomes
- `wiki/reviews/pending.md`
  queued review items for contested claims or high-value query promotions
- `wiki/reviews/approved.md`
  accepted or resolved review items
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
  seeds role-aware wiki controller/worker profiles aligned with MoonClaw's role substrate
- `.moonclaw/providers.json`
  seeds the provider-task target named `moonbook` so MoonClaw can resolve provider-backed `wiki book tasks/context/persist`
  the provider metadata points back at `moon run cmd/main -- wiki book ...` from the MoonBook module cwd
- `IDENTITY.md`, `USER.md`, `ROUTINES.md`, `MEMORY.md`, `KEEPER.md`
  MoonClaw-managed workspace context files
- `skills/wiki-maintainer/SKILL.md`
  host-owned keeper/revision skill for MoonBook wiki maintenance
- `skills/wiki-review/SKILL.md`
  host-owned review skill for MoonBook wiki consistency checks

### `moontown` Extension Pack

Installed by `moonbook wiki enable moontown [root]`:

- `moontown.book.json`
  machine-readable manifest describing the optional town-to-book API commands plus catalog export
- `BOOK_API.md`
  human-readable guide for the town-facing book boundary

This pack does not change the core wiki directories or make MoonBook depend on Moontown at runtime. It only advertises the optional book-harness surface over the same workspace.

### `ui/`

Contains Rabbita frontend work. The current Rabbita package renders a documentation-first operator dashboard for MoonBook, loads generated workspace state from `moonbook-ui-state.json`, and subscribes to rebuild-triggered live refresh when a serve-time event endpoint is available.
