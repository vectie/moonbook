# Search a static book offline

After the ordinary `moonbook build <root>`, open the generated book and choose
**Search this Book** in its table of contents. The page lives at
`<build-dir>/__moonbook/search.html`. Keep the entire generated book folder to
follow results to chapters; the search page itself needs no server, API, fetch,
external script, font, account or network connection. It works from local files
or static hosting with JavaScript enabled. Without JavaScript, use the contents.

Enter words or a literal code fragment. All whitespace-separated words must
occur in a chapter's title or complete Markdown. Matching is JavaScript Unicode
case-insensitive literal matching: punctuation such as `[a+b]` is not a regular
expression. There is no fuzzy, semantic, accent-normalized or generated answer.
Title-matched words rank first; ties follow SUMMARY order. Results show title,
source-relative path and a short source excerpt. Follow a title to read the
chapter. Previous/Next results reaches all matches, twenty at a time. Editing
the search resets to the first page. Empty and no-match states are explicit.

## Scope and refresh

The index is a replaceable projection of exactly the loaded, preprocessed,
non-draft chapters rendered by that build, including nested chapters. `README`
chapters link to their normalized `index.html` outputs. Unlisted files, original
raw evidence, separate keeper/review journals and other books are not scanned.
If a journal or other file is explicitly included as a chapter in SUMMARY, its
complete Markdown is included like any other chapter.

Search includes the complete chapter Markdown, not only visible prose. Code,
metadata, comments and hidden-line syntax can appear in excerpts and the embedded
index. Check chapter contents before sharing a static build. It does not embed
original attachments or claim that imported labels were reviewed. Source text
is inert in search results; the existing chapter renderer retains its own raw
HTML behavior. The query is local and transient, never sent or saved.

Rebuild after editing sources or SUMMARY. Search reflects the build snapshot,
not the live wiki. Opening an old exported folder searches that older snapshot.
Generation does not update source files or claim/review status. Missing chapter
input is reported by the existing loader before building. `__moonbook/` is now
reserved for generated reader tools: an authored chapter, configured asset or
404 output in that directory produces an explicit build conflict instead of
being overwritten by search. Move that output out of the reserved directory.

The page embeds the full chapter index, so its size and search time grow with
the selected book. Queries are limited to 200 UTF-16 code units and twenty
whitespace-separated terms; no index or matching result is silently truncated.
Each excerpt is at most 60 code points before and 180 from its first match,
with ellipses when cropped. Other matching words may be outside that excerpt.

## Checks

`html/renderer_search_wbtest.mbt` checks exact JSON text, complete escaping,
SUMMARY order, drafts, nested links, empty state and output conflicts, alongside
the existing renderer tests. `static_search_tests` exercises the ordinary
`driver.load` and `MDBook.build` against an actual temporary source book, checks
reproducible output, edited-source rebuild, missing input and source preservation.
Set `MOONBOOK_STATIC_SEARCH_EVIDENCE` to an existing directory to retain its book.

Run `node scripts/static-search.test.mjs <generated-search.html>` on that retained
fixture. This executes the exact generated script and data in controlled DOM
objects, covering real generated chapter results/links, title order, all-term
matching, Unicode, literal punctuation, inert text, paging and query limits.
These are native filesystem and Node/DOM-contract checks, not a mounted browser,
visual/accessibility audit, OS action, production deployment or complete product
qualification. The Rabbita live-book query workflow is unchanged.
