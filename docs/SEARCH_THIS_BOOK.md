# Search this Book

The existing Rabbita operator at `/apps/moonbook/` has a **Search this Book**
panel directly below its overview. Enter a question, search, inspect a ranked
maintained page, and copy or download a plain-text context brief. This panel is
separate from the reviewed-lesson browser and all review/acceptance workflows.

To compare evidence across several questions, inspect a result and choose
**Collect inspected page**. The [Research collection](RESEARCH_COLLECTION.md)
keeps selected snapshots and researcher notes in this tab, supports ordering
and removal, and exports a single Markdown brief. Download before reloading.

## What the result means

- The UI invokes read-only `wiki.query_wiki_page(root, question, page)`.
  The legacy no-page HTTP and CLI contract remains `query_wiki(..., save=false)`
  with its original top-three results. The host owns `root`; request fields such as `root` or `save` cannot
  select another Book or turn on saving.
- Ranking is the existing case-insensitive lexical score: title matches,
  occurrence counts, and maintained-page-family weights; equal scores sort by
  Book-relative path. Three results are returned per page, within a maximum
  window of 30 matches (ten pages). The UI reports the fresh matched count,
  accessible window and truncation; refine the question to reach other pages.
- Excerpts are the native query's exact maintained metadata summary when one
  exists, otherwise its selected matching line. They can be truncated to 220
  UTF-16 code units plus `...`. An excerpt need not be an exact question match
  when the native engine selects a maintained summary.
- Search is not generated synthesis, semantic search, a factual review, or an
  acceptance decision. Page `status:` metadata is copied as informative,
  unverified text. An imported `accepted` or `verified` label makes no claim
  about factual correctness or original-task acceptance.
- Titles and excerpts lead; citation paths, lexical score and metadata live in
  each card's disclosure. All source text renders as escaped text, not HTML.
- Search, Previous/Next results, Inspect and Read retained source each scan
  current maintained pages afresh. No transactional snapshot is retained.
  Inspect binds the exact question, zero-based results page and citation and
  accepts only a citation currently ranked on that page. Deletion or re-ranking
  returns a visible conflict instead of inspecting a different hit.
  It reads the actual complete maintained page from this Book, not a fabricated
  static HTML URL. A page may have changed since the displayed search; the UI
  says that explicitly. If it no longer ranks, search again.
- Copy, download and the readable brief disclosure use the same host-returned
  text, in the same rank order, with the same titles, excerpts and citations.
  Downloads are UTF-8 `text/plain`, named `moonbook-context.txt`. Clipboard needs
  browser permission and a secure context (localhost normally qualifies). A
  denied clipboard leaves results intact and offers download/selectable text.
- Search and inspect write no query pages, source pages, keeper state, review
  state, or Bookkeeper journal. The existing CLI `--save` capability remains
  available separately; this UI never calls it.

## Startup

Use the committed module dependencies, installed in private `.mooncakes`
directories at the repository root and `ui/rabbita-book/` respectively. The
Rabbita module requires `moonbit-community/rabbita@0.12.4`. The recovered
toolchain for this delivery is Moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9.

From the MoonBook checkout:

```sh
moon build --target native --release --strip -j 1 --frozen cmd/main
moon -C ui/rabbita-book build --target js --release --frozen
MOONBOOK_MODULE_ROOT="$PWD" _build/native/release/build/cmd/main/main.exe serve /absolute/path/to/book -n 127.0.0.1 -p 3000
```

Open `http://127.0.0.1:3000/apps/moonbook/#book-search`. `serve` uses the existing
Book build/install flow and ships the compiled Rabbita assets. A static-only
export can show the panel but cannot run search; the UI reports the missing
live API. Existing `build`/`serve` regeneration writes output assets; this is
separate from the read-only query routes.

For an explicitly disposable demo, initialize it first with:

```sh
_build/native/release/build/cmd/main/main.exe wiki init /absolute/disposable/demo-book
```

The recovery workspace additionally requires process-scoped `HOME`, `MOON_HOME`
and `PATH` from `RECOVERY_USAGE.md`, and serializes every native build/test with
its shared `native-build.lock`. Do not nest locks. No Mac, provider, credentials,
push, or trust-policy change is required for this feature.

## API and limits

`POST /api/book/query` accepts `{"question":"…","page":0}`.
`POST /api/book/query/inspect` accepts `{"question":"…","page":1,"citation":"wiki/…md"}`.
Retained-source requests also carry the same `page` plus the inspected page's
`page_digest`. `page` must be an integer from 0 through 9. Omit it only for the
legacy top-three contract. Responses echo `page` on inspection/source reads;
search responses include `paging` with `page`, `page_size`, `matched_count`,
`window_count`, `has_next`, `truncated`, and `fresh_scan`.
Both require `application/json`, reject browser cross-site requests, and return
`moonbook.search.v1` JSON with `cache-control: no-store`.

- Request body: 16 KiB, enforced while reading the socket (including chunked
  bodies), before JSON parsing
- Question: nonblank, at most 1024 UTF-16 code units; at least one native
  searchable term of two code units; no NUL
- Maintained pages: at most 10,000 `.md` files, maximum directory depth 32,
  maximum 2 MiB per read; no silent partial result if a selected scan read fails
- Only the requested page's excerpts are returned, with no full-page text
  duplicated in a search response. Out-of-range-for-current-results pages
  within 0–9 return empty excerpts and fresh counts; navigate back or search.
- Symlink files/directories are not followed by the scan; citations reject
  absolute paths, traversal, backslashes, NUL, symlink components, and
  nonregular files. The host does not expose a generic filesystem reader
- Scaffolding, reviews, saved queries, and planning/debug paths remain excluded
  by the production query's existing filters
- No-match/empty Books return an explicit empty result, not an invented answer
- Unreadable, oversized or invalid-UTF-8 pages fail visibly; prior UI results
  and their labelled question remain available
- Requests have a 20-second browser timeout. Monotonic request IDs discard old
  search and inspect completions. Editing the question invalidates its pending
  response. A failed new query preserves previous successful results; exports
  still refer to the explicitly displayed successful question
- Page navigation clears inspected pages/retained bytes and invalidates pending
  search, inspect and retained-source callbacks. Export completion notices are
  bound to the exact displayed brief; a late callback from another page is ignored.

This is a local Book host feature, not a multi-tenant server authorization
system. The scan/read checks do not lock out another process concurrently
rewriting Book files. Large Books can be slow because every eligible page is
scanned; no background index or language model is used.

## Tests

Native black-box tests in `internal/moonwiki/book_search_http_test.mbt` create a
real temporary Book, call the production query, cross the actual TCP host,
inspect complete page text, enforce request bounds, and compare a recursive
before/after snapshot of all Book files including review, keeper and journal.
They cover Unicode, deterministic tie order, no-match, invalid/empty questions,
unreadable/oversized files, unsafe citations and symlink exclusion.

UI tests in `main/book_search_wbtest.mbt` cover request races, failures, escaped
rendering and exports. With `MOONBOOK_SEARCH_WIRE` pointing to the native test's
JSON and `MOONBOOK_SEARCH_UI_RECEIPT` to an output file, the mandatory crossing
uses the native host response through the real browser transport adapter,
decoder, reducer, view, clipboard function and download Blob. Every exported
byte must equal the native context brief. Clipboard/DOM/browser download effects
are controlled test doubles; this is not evidence of a real OS clipboard or
physical browser download.

Paged native regressions in `book_paging_http_test.mbt` additionally cover
0/1/3/4/35 matches, deterministic ties, last-window truncation, invalid page
numbers, later-page inspection, query/page mismatch, deleted/re-ranked hits,
symlinks, oversized/unreadable pages and unchanged bytes/metadata. The
`MOONBOOK_PAGING_WIRE` and `MOONBOOK_PAGING_UI_RECEIPT` crossing runs real local
socket search → next page → inspect → retained source, then the compiled UI's
decoder, reducer, escaped view, clipboard and Blob export. It is not mounted
graphical-browser or keyboard/accessibility qualification.
