# Feature Matrix

This document tracks the currently implemented moonbook behavior. It is intentionally concrete and case-oriented so new compatibility work can extend it without guessing what already exists.

## CLI

Implemented commands:

- `moonbook init [root]`
- `moonbook build [root]`
- `moonbook serve [root] [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]`
- `moonbook wiki init [root]`
- `moonbook wiki ingest [root] <source>`
- `moonbook wiki query [root] <question> [--save]`
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
- `serve --watcher native` currently falls back to the poll backend with an explicit notice
- `wiki init` scaffolds `raw/`, `wiki/`, `AGENTS.md`, `wiki.toml`, and a MoonBook-compatible `book.toml`
- `wiki init` outputs a workspace that can immediately be built with `moonbook build`
- `wiki ingest` imports sources into `raw/imported/` when needed
- `wiki ingest` generates `wiki/sources/<slug>.md`
- `wiki ingest` updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`
- `wiki query` searches markdown pages under `wiki/`
- `wiki query` returns a synthesized markdown answer with citations to wiki pages
- `wiki query --save` writes `wiki/queries/<slug>.md`
- `wiki query --save` updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`
- `wiki lint` detects orphan pages
- `wiki lint` detects pages missing from `wiki/index.md`
- `wiki lint` detects placeholder sections still left in `wiki/index.md`
- `wiki lint` detects source pages missing a raw-source link
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
