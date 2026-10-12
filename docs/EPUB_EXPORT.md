# Offline EPUB export

Export a readable, single-file snapshot of an existing SUMMARY book:

    moon run cmd/epub --target native -- /absolute/path/to/my-book

The dedicated native command prints the output path:
`<build.build-dir>/__moonbook/book.epub` (by default `book/__moonbook/book.epub`).
Open or transfer that file with an EPUB 3 reader. No HTML build, hosted service,
network fetch or browser-print step is needed. The MoonBit API is
`@driver.export_epub(book_root)`; an already loaded `MDBook` also exposes
`export_epub()`.

## Author → export → read → revise

1. Edit `book.toml`, the chapters and `src/SUMMARY.md` as usual.
2. Export. The ebook contains only SUMMARY-listed, non-draft chapters, in SUMMARY
   order. Its clickable contents preserves chapter nesting; part labels and
   separators do not create reading pages. Draft parents with real children
   appear as non-clickable groups.
3. Read offline. Chapter links, README/index aliases, heading links and footnotes
   resolve inside the archive. Local PNG/JPEG/GIF images are included once even
   when several chapters use them. Code, tables, lists, task checkboxes and
   Unicode text use the same Markdown rendering as HTML books.
4. Revise the sources and export again. The complete archive is replaced, so
   removed chapters and unused images do not linger. The EPUB is a generated
   snapshot; annotations made in an ebook reader are not imported into MoonBook.

`book.title`, `book.authors`, `book.language` (default `en`) and
`book.description` supply metadata. A content-derived SHA-256 identifier names
this snapshot. The package modification time is the latest filesystem mtime of
its config, SUMMARY, listed chapters or images, formatted as UTC seconds.
Unchanged input bytes and mtimes produce identical archive bytes. ZIP entries
use a fixed date and are stored without compression, including the required
first `mimetype` entry. This favors simple reproducibility over compact size.

## Supported content and repairable errors

The exporter turns ordinary renderer output into parsed XHTML. It supports
Markdown headings, paragraphs, emphasis, lists, task lists, tables, blockquotes,
code blocks, rules, footnotes and images. Fenced HTML examples remain code. The
browser-only copy buttons are omitted. The output uses a small bundled reading
stylesheet; authored HTML theme CSS/JS and site projections are not exported.

Internal links must name a SUMMARY chapter or a real anchor in it. `.md`,
rendered `.html`, nested README/index aliases and percent-encoded Unicode paths
are supported. Local query strings, root-relative links, links to unlisted
chapters/downloads and missing fragments produce an error naming the chapter
and link. External `http`, `https` and `mailto` links are retained as links; no
remote resource is fetched, and following them requires the reader's network.

Images must be local PNG, JPEG or GIF files under the configured source root.
SVG, WebP, remote/data images, audio/video, embedded frames, scripts, custom
styles, and `srcset` are outside this export's scope. Supported raw HTML must
already be balanced, quoted-attribute XHTML apart from the renderer's normal
void tags and checked/disabled booleans. Common text/structural elements are
accepted; unsupported elements/attributes and XML entities fail explicitly.
This is a bounded ebook projection, not a general HTML-to-EPUB converter.

Input/render/link validation and packaging finish before an output write.
Failed validation leaves the previous complete ebook and source files unchanged.
The path-based export deliberately ignores `build.create-missing`, so missing
chapters are errors rather than new source files. Output inside the editable
source directory is rejected. A complete temporary archive is atomically
renamed into place. If an I/O interruption leaves `book.epub.pending`, inspect
that file before moving it aside and retrying; concurrent exports to the same
path are not supported. Up to 32 MiB of uncompressed publication resources is
supported, within the inherited bounded XML parser limits.

## Qualification

Focused native tests exercise the actual driver load/export route, source
preservation, repeat exports, editorial reorder/removal and repairable failures.
The retained synthetic EPUB is checked with an independent Python ZIP/XML
inspector: first stored mimetype entry, CRCs, container/package namespaces,
manifest/spine/TOC order, all local links and fragments, and exact image bytes.

The format follows the [W3C EPUB 3.3 specification](https://www.w3.org/TR/epub-33/).
No EPUB reader application, device, accessibility certification or EPUBCheck
conformance suite is qualified by these structural tests. Layout varies by
reader. Raw material and generated content retain their original review meaning;
export does not grant factual acceptance or authority.
