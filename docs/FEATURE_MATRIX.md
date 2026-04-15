# Feature Matrix

This document tracks the currently implemented moonbook behavior. It is intentionally concrete and case-oriented so new compatibility work can extend it without guessing what already exists.

## CLI

Implemented commands:

- `moonbook init [root]`
- `moonbook build [root]`
- `moonbook serve [root] [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]`
- `moonbook wiki init [root]`
- `moonbook wiki enable <extension> [root]`
- `moonbook wiki ingest [root] <source>`
- `moonbook wiki query [root] <question> [--save]`
- `moonbook wiki book accept [root] <goal>`
- `moonbook wiki book tasks [root] <goal>`
- `moonbook wiki book context [root] <goal> [--task <task-id>]`
- `moonbook wiki book persist [root] <result.json>`
- `moonbook wiki book catalog [root]`
- `moonbook wiki book summary [root]`
- `moonbook wiki book health [root]`
- `moonbook wiki review list [root]`
- `moonbook wiki review approve [root] <review-id>`
- `moonbook wiki review reject [root] <review-id>`
- `moonbook wiki lint [root]`
- `moonbook watch [root] [-d dest-dir] [-o] [--watcher poll|native]`
- `moonbook load [root]`
- `moonbook test [root]`
- `moonbook clean [root]`
- `moonbook version`

Implemented behaviors:

- initializes `src/`, `book/`, `book.toml`, `.gitignore`, `src/SUMMARY.md`, and `src/chapter_1.md`
- loads `book.toml` if present, otherwise uses defaults
- writes built HTML output under `build.build_dir`
- `serve` performs a build first, then hosts the built output over HTTP
- `serve` supports configurable hostname and port
- `serve` supports `--dest-dir`
- `serve` supports `--open`
- `serve` accepts `--watcher poll|native`
- `serve` serves `index.html` at `/`
- `serve` serves `404.html` as a fallback when present
- `build` and `serve` copy an optional root `site/` marketing projection into `book/site/`
- `build` and `serve` generate a live marketing projection into `book/site/generated/`
- `serve --watcher native` currently falls back to the poll backend with an explicit notice
- `wiki init` scaffolds `raw/`, `wiki/`, `AGENTS.md`, `wiki.toml`, and a MoonBook-compatible `book.toml`
- `wiki init` keeps the core workspace agent-agnostic
- `wiki init` scaffolds a `site/` marketing website projection with `index.html`, `styles.css`, and `app.js`
- `wiki init` seeds a dedicated `skills/wiki-marketing/SKILL.md` routine for maintaining `site/` as a presentation layer distinct from `wiki/`
- generated marketing projection includes current status, workflow, review pressure, keeper memory, depth links, and synthesis preview from live workspace state
- `wiki init` seeds `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/`, `wiki/queries/`, and `wiki/sources/`
- `wiki init` seeds claims, maintenance-plan, query-insights, pending-review, and approved-review pages
- `wiki init` seeds an observations page for persisted book results
- `wiki init` seeds bounded Keeper memory files under `keeper/`
- `wiki init` seeds `wiki/synthesis/evidence.md`, `wiki/synthesis/map.md`, and `keeper/INSIGHTS.md`
- `wiki init` outputs a workspace that can immediately be built with `moonbook build`
- `wiki enable moonclaw` installs MoonClaw-specific runtime/config/workspace files without overwriting them
- `wiki enable moonclaw` records an extension manifest under `.moonbook/extensions/moonclaw.json`
- `wiki enable moonclaw` seeds `KEEPER.md` plus `skills/wiki-maintainer/SKILL.md` and `skills/wiki-review/SKILL.md`
- `wiki enable moonclaw` seeds role-aware controller/worker profiles with explicit `role_runtime` envelopes aligned to MoonClaw's planner substrate
- `wiki enable moonclaw` seeds `.moonclaw/providers.json` with the provider-task target name `moonbook`
- `wiki enable moontown` installs an optional town-facing book API manifest and guide without changing the core wiki contract
- `wiki enable moontown` records an extension manifest under `.moonbook/extensions/moontown.json`
- `wiki ingest` imports sources into `raw/imported/` when needed
- `wiki ingest` rejects hidden placeholders, empty files, and `.gitkeep`-style scaffolding as non-substantive sources
- `wiki ingest` generates `wiki/sources/<slug>.md`
- `wiki ingest` generates or updates related `wiki/entities/*.md` pages for lightweight extracted entities
- `wiki ingest` generates or updates related `wiki/concepts/*.md` pages for lightweight extracted concepts
- `wiki ingest` adds relationship entries to relevant entity pages based on extracted claims
- `wiki ingest` adds reciprocal relationship entries to related entity/concept pages
- `wiki ingest` updates `wiki/synthesis/overview.md` with cross-source entries
- `wiki ingest` updates `wiki/synthesis/claims.md` with structured claims, confidence markers, support counts, status, and superseded markers
- `wiki ingest` records claim id, kind, and related-page metadata inside the claims register
- `wiki ingest` updates `wiki/synthesis/map.md`
- `wiki ingest` updates `wiki/synthesis/maintenance-plan.md` with a multi-page follow-up entry
- `wiki ingest` queues contested or low-confidence updates in `wiki/reviews/pending.md`
- `wiki ingest` updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`
- `wiki ingest` canonicalizes `wiki/index.md` sections to avoid duplicate source headings
- `wiki query` searches markdown pages under `wiki/`
- `wiki query` returns a synthesized markdown answer with citations to wiki pages
- `wiki query --save` writes `wiki/queries/<slug>.md`
- `wiki query --save` updates `wiki/synthesis/query-insights.md`
- `wiki query --save` captures a condensed query insight in `keeper/MEMORY.md`
- `wiki query --save` propagates `Query Signals` into cited entity/concept/source pages
- `wiki query --save` updates `wiki/synthesis/map.md`
- `wiki query --save` updates `wiki/synthesis/maintenance-plan.md`
- `wiki query --save` can queue pending review items for promoting saved answers into maintained wiki pages
- `wiki query --save` updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`
- `wiki book accept` returns a machine-readable goal acceptance summary
- `wiki book tasks` returns a machine-readable local task batch for a town-issued goal
- `wiki book tasks` emits a dedicated planning task when health or goal wording indicates planning pressure
- `wiki book context` returns a machine-readable worker context bundle derived from book-local policy, Keeper memory, routines, and relevance-ranked durable pages
- `wiki book persist` accepts a JSON `BookResult`, appends it to `wiki/synthesis/observations.md`, records evidence in `wiki/synthesis/evidence.md`, syncs non-durable memory candidates into Keeper memory, promotes immediately-safe durable candidates into target pages, stages review-gated durable candidates, refreshes `keeper/INSIGHTS.md`, updates the maintenance plan, and can queue review
- `wiki book catalog` returns a machine-readable town catalog record with id, purpose, workspace root, memory scope, tags, and skills
- `wiki book summary` returns page/review counts plus Keeper/evidence counts and a compact state summary
- `wiki book health` returns backlog, low-confidence claim, crowded-working-memory, and missing-evidence health signals for the book
- `wiki review list` enumerates pending review ids/kinds/status/titles
- `wiki review approve` moves items from pending to approved, promotes approved changes into synthesis/claims/pages, updates linked evidence status, refreshes the synthesis map, and refreshes Keeper insights
- `wiki review approve` promotes approved query insights into cited entity/concept/source pages
- `wiki review reject` moves items from pending to approved with rejected status
- `wiki lint` detects orphan pages
- `wiki lint` detects pages missing from `wiki/index.md`
- `wiki lint` detects placeholder sections still left in `wiki/index.md`
- `wiki lint` detects source pages missing a raw-source link
- `wiki lint` detects time-sensitive stale wording with no explicit date markers
- `wiki lint` detects simple contradictory `X is Y` claims across pages
- `wiki lint` detects missing concept pages implied by existing content
- `wiki lint` detects weak synthesis/claim coverage for source pages
- `wiki lint` detects low-confidence claims that are not queued for review
- `wiki lint` detects review backlog growth from multiple active low-confidence claims
- `wiki lint` detects crowded Keeper memory
- `wiki lint` detects missing evidence capture when observations exist without evidence records
- `wiki lint` appends a lint pass to `wiki/log.md`
- `watch` performs an initial build, then polls for source/config changes
- `watch` supports `--dest-dir`
- `watch` supports `--open`
- `watch` accepts `--watcher poll|native`
- `watch --watcher native` currently falls back to the poll backend with an explicit notice
- `watch` rebuilds when files under `book.src/` or `book.toml` change
- `serve` and `watch` ignore paths matched by the book root `.gitignore`
- writes `book.json` manifest into the build directory
- `test` counts Rust fenced blocks in the loaded book
- `clean` removes the generated build directory and reports removal stats

## Config And Domain Model

Implemented config fields:

- `book.title`
- `book.authors`
- `book.src`
- `book.language`
- `book.multilingual`
- `book.description`
- `build.build-dir`
- `build.create-missing`
- `build.use-default-preprocessors`
- `rust.edition`
- dynamic `output.*` JSON access via `Config::read`
- dynamic `preprocessor.*` JSON access via `Config::read`
- `output.html.additional-css`
- `output.html.additional-js`
- `output.html.cname`
- `output.html.input-404`
- `output.html.site-url`

Implemented book model behaviors:

- `Book`, `BookItem`, `Chapter`, and `SectionNumber`
- depth-first item iteration
- flattened chapter enumeration
- draft chapters via `path = None`
- chapter display names with section numbers
- mutable chapter tree transforms via `for_each_mut` and `for_each_chapter_mut`

## SUMMARY.md Parsing

Implemented cases:

- top-level title from `# Summary`
- numbered chapters from `- [Title](path.md)` and `* [Title](path.md)`
- nested numbered chapters by indentation
- part titles from `# Part Name`
- separators from `---`
- separators preserved at nested chapter depth
- prefix chapters before numbered sections
- suffix chapters after numbered sections
- numbering continuity across separators and part titles
- empty destinations as draft chapters, for example `[Draft]()`
- duplicate chapter file detection anywhere in the summary
- HTML comment line skipping
- ignoring `## ...` subheaders instead of treating them as part titles
- absolute chapter paths loaded from disk and normalized back relative to `src/`

Implemented loader/preprocessor behaviors tied to summary data:

- chapter parents recorded in `parent_names`
- `README.*` chapter paths normalized to `index.*` for rendered output
- `source_path` preserved while the rendered path uses the normalized location
- optional creation of missing chapter files when `build.create-missing = true`

## HTML Shell And Navigation

Implemented page shell behaviors:

- generated `index.html`
- generated chapter HTML pages
- static inline stylesheet
- sidebar table of contents
- current-page highlighting
- nested navigation lists
- part titles in sidebar
- separators in sidebar
- previous/next page navigation
- chapter breadcrumbs from `parent_names`
- relative navigation links from nested pages

## Markdown Rendering

Implemented block-level cases:

- ATX headings `#` through `######`
- paragraphs with line joining
- unordered lists
- ordered lists
- ordered list start numbers, for example `3. item` -> `<ol start="3">`
- nested unordered/ordered list hierarchies
- blockquotes with `> `
- horizontal rules from `---`
- fenced code blocks with language/modifier info strings
- GitHub-style pipe tables
- table alignment from `:---`, `:---:`, and `---:`
- raw HTML block passthrough

Implemented inline cases:

- emphasis with `*text*`
- strong with `**text**`
- emphasis with `_text_`
- strong with `__text__`
- nested strong+emphasis like `**_text_**`
- inline code spans
- inline links `[label](path.md#anchor)`
- reference-style links `[label]` plus `[label]: target`
- image syntax `![alt](path)`
- autolinks like `<https://example.com/>`
- footnote references `[^name]`
- raw inline HTML passthrough
- backslash escaping for inline text such as `\<escaped>`
- `.md -> .html` rewriting for local markdown links
- anchor preservation during link rewriting
- external URLs, `mailto:`, and fragment-only links left unchanged

## Heading And Anchor Behavior

Implemented heading behaviors:

- stable slug-based heading `id` generation
- duplicate heading disambiguation with `-1`, `-2`, ...
- heading self-links
- heading IDs derived from rendered inline text rather than raw markdown syntax
- heading slug generation preserves Unicode letters
- raw HTML comments inside heading text do not pollute slug generation

## Footnotes

Implemented cases:

- footnote definition extraction from chapter body
- footnote reference superscripts
- footnote section appended at end of rendered chapter
- backlink from footnote definition to reference
- footnote content rendered through the markdown renderer

## Assets

Implemented asset handling:

- markdown image sources collected from chapter content
- raw HTML `src` and `href` attribute values collected from chapter content
- local non-markdown assets copied from `src/` into the build directory
- relative asset references preserved in generated HTML
- configured `output.html.additional-css` files copied from the book root into the build directory
- configured `output.html.additional-js` files copied from the book root into the build directory

## HTML Config Extras

Implemented output.html extras:

- `input-404` custom input file selection, defaulting to `404.md`
- `input-404 = ""` to disable not-found output generation
- `site-url` base href injection for generated 404 output
- `cname` writing to a root `CNAME` file in the build output
- `additional-css` link tag injection into generated pages
- `additional-js` script tag injection into generated pages

## Code Blocks

Implemented code-block metadata:

- comma-separated code info parsing
- language class, for example `language-rust`
- modifier classes, for example `ignore editable`

Implemented mdBook-style code-block rendering:

- Rust blocks render as playground blocks by default
- `noplayground` disables playground wrapping
- `editable` is preserved on Rust code blocks
- generic non-Rust hidden lines with default `~` prefix
- explicit hidden-line prefix via modifiers like `hidelines=!!!`
- Rust hidden-line processing for `#`-prefixed lines
- Rust escaping for `## ...` to visible `# ...`
- Rust pass-through for attribute lines like `#[attr]`
- hidden lines wrapped in `<span class="boring">`

## Raw HTML

Implemented raw HTML handling:

- raw HTML is preserved instead of escaped
- raw HTML `href` and `src` attributes participate in `.md -> .html` rewriting
- raw HTML `href` and `src` values participate in asset discovery/copying

## Known Non-Parity Areas

Not implemented yet:

- full mdBook theme system
- search index and search UI
- print renderer/output
- live reload websocket for `serve`
- true native filesystem watcher backend
- `test` parity with upstream mdBook behavior
- external preprocessors and renderers
- full `book.toml` compatibility
- complete CommonMark/pulldown-cmark parity
- redirect generation
- full built-in theme asset pipeline
- complete Rabbita UI integration with live built-book state
