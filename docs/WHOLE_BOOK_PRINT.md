# Read or print a whole static book

Build the book using the ordinary `moonbook build <root>` workflow, then choose
**Read / Print whole book** in any chapter's navigation. The generated file is
`<build.build_dir>/__moonbook/print.html` (normally `book/__moonbook/print.html`).
It works when opening the build folder locally or serving the ordinary book.

The page contains every non-draft, SUMMARY-listed chapter in reading order,
including nested chapters, rendered Markdown tables/code, and footnotes. Its
contents links jump to chapter sections. Use **Print / Save PDF**, or the
browser's Print command without JavaScript. Print styling starts each chapter
on a new page, hides controls, wraps code, repeats table headings where supported,
and retains the book contents and source paths. Pagination, page size, fonts,
PDF generation and printer behavior belong to the browser and printer.

## Navigation and images

- Chapters have unique section anchors. Heading IDs and footnote IDs receive a
  chapter prefix, so the same heading or footnote name in different chapters
  does not jump to the wrong chapter.
- Relative links between rendered chapters become in-page jumps; both the
  original `README.md` name and its generated `index.html` are recognized.
  Percent-encoded chapter paths (including spaces and Unicode) are recognized.
- Links to the stripped leading chapter title remain usable.
- Relative images and other local links are rebased from their chapter location
  to the combined page. Keep the complete build folder with this HTML file;
  images are referenced, not embedded. The existing renderer determines which
  Markdown assets are copied.
- External URLs, root-relative URLs and URL schemes keep their existing meaning.
  Query-bearing chapter links keep their query and open the ordinary page.
- Each section retains its source path and an **Open chapter** link.

The projection uses the existing Markdown renderer and raw-HTML trust model;
it is not a sanitizer. Raw HTML IDs, `href`, and `src` attributes participate in
rewriting. Comments and script/style bodies are left unchanged, as are escaped
code examples. Arbitrary authored scripts, CSS selectors referring to old IDs,
legacy named anchors, `srcset`, and other advanced embedded HTML may need
author adaptation for a combined document. Custom extra theme CSS/JS is not
loaded into this deliberately simple print page.

## Rebuild and source boundary

The whole-book page is replaceable generated output, never the editable source.
Rebuild after editing source chapters to refresh it. Draft and unlisted files,
raw source directories, and arbitrary workspace files are not included unless
explicitly referenced through the existing chapter renderer. Content in included
chapters is not factually verified by rendering or printing.

`__moonbook/` is already reserved for generated reader tools. A chapter, asset,
or configured 404 output colliding with that directory is rejected before
rendering; rename the authored item. A missing SUMMARY source causes loading to
fail and leaves the preceding whole-book output and source content intact.

## Focused acceptance

`whole_book_tests` exercises real load/build/rebuild with nested chapters,
Unicode, cross-chapter and local heading links, repeated footnotes, a copied
image, tables and code, draft/unlisted exclusion, reproducibility, unchanged
source bytes, missing input, and reserved output collision. Renderer unit tests
cover path rebasing, namespace isolation and attribute parsing. The generated
HTML is independently inspected for unique IDs, resolvable in-page links and
local assets. This does not establish graphical print/PDF, full-suite, hosted,
or cross-machine qualification.
