# Explore chapter connections

A source chapter often explains a decision elsewhere in the book. Open the
source and use **Referenced by** to find those decisions without searching
every chapter manually. **Links to** lists the chapters cited by the current
one. **Chapter connections** in the sidebar opens the complete linked index,
including chapters with no authored links.

## Use it

1. Write ordinary chapter links, such as `[Capacity](guide/README.md#capacity)`.
2. Run the existing `moonbook build <book-root>` command.
3. Open a rendered chapter and scroll to **Chapter connections** below its text.
4. Follow **Referenced by** to return to chapters that cite it, or **Links to**
   to read related chapters. Titles are accompanied by source paths so chapters
   with the same title can be distinguished.
5. Choose **Explore all chapter connections** to open that chapter's entry in
   `book/__moonbook/connections.html`. The full index is in SUMMARY order.
6. Edit, add, remove or retarget links in the author source and rebuild. Both
   directions update from the current chapter content; repeated builds are
   deterministic. Serve/watch use the same renderer.

For example, let `start.md` link to `guide/README.md` and `results.md`. On the
capacity page, **Referenced by** lists the decision chapter. On the decision
page, **Links to** lists capacity and results. A reverse link in capacity is a
separate directed connection; repeated links to multiple headings in capacity
still produce only one decision-to-capacity entry.

The explorer and chapter panels work as static HTML without JavaScript,
accounts or an API. Keep the entire generated build folder together. Custom
HTML CSS/JavaScript configured for normal pages also applies to the explorer;
this feature itself makes no network request. The generated projection never
edits source Markdown or turns a link into a factually reviewed claim.

## What counts

- Only non-draft, SUMMARY-listed chapters participate.
- The graph reads anchor `href` attributes from rendered chapter bodies before
  sidebar, previous/next controls or connection panels are added. Markdown
  inline/reference links, links in rendered footnotes, and raw HTML anchors can
  contribute. Images, menus and generated navigation never create connections.
- Relative chapter paths are normalized against the current rendered chapter's
  directory. Source Markdown paths, rendered HTML paths and README-to-index
  aliases resolve to the same chapter. Unicode and percent-encoded filenames
  are supported. Generated connection links percent-encode filename characters
  so spaces, ampersands, percent signs, question marks and hashes stay literal.
- Graph query normalization applies after successful ordinary rendering:
  query strings and heading fragments are ignored for chapter identity, and
  the connection opens the canonical chapter page. The inherited asset
  collector may reject query-bearing Markdown and double-quoted raw `href`
  links before this projection is generated. Single-quoted raw anchors, such
  as `<a href='index.html?mode=full#details'>Details</a>`, are the verified
  integration form. Omitting the query is another option. The asset collector
  is unchanged; connection resolution does not validate heading existence.
- Each directed pair appears once; outgoing and incoming lists follow book
  order, not the order of link occurrences. Self-links and same-page anchors
  are omitted.
- External, protocol-relative, root-relative, backslash-bearing and unlisted
  targets are omitted. A root-relative link depends on hosting location, so the
  offline explorer does not guess its Book-relative identity.
- Code examples, HTML comments, and script/style/textarea/title contents are
  not scanned as active anchors. The original renderer's Markdown and raw-HTML
  behavior still determines what is rendered.

## Limits

This is a chapter-navigation projection, not a link checker, full DOM engine,
or inferred knowledge graph. It does not fetch external URLs, include files
outside SUMMARY, scan custom scripts, or discover dynamic links. Missing and
unlisted link targets simply contribute no edge. A missing SUMMARY chapter
still causes the existing loader to fail before replacing the projection.
`__moonbook/` remains reserved for generated reader tools; a colliding author
chapter is rejected before that output is written.

The bounded HTML scanner handles quoted/unquoted attributes and ignores raw
text elements. Attribute decoding supports semicolon-terminated numeric
references and common URL/HTML named references (`amp`, `quot`, `apos`, `lt`,
`gt`, `colon`, `sol`, `quest`, `num`, `percnt`, `Tab`, `NewLine`). Other named
entities, malformed HTML, `base` elements, directory-index URLs and
JavaScript-modified targets can require explicit relative chapter links.
Author-supplied raw HTML retains the ordinary renderer's behavior; this is not
an HTML sanitizer. No new review status, permission or factual acceptance is
created.

## Focused checks

`html/renderer_connections_wbtest.mbt` checks directed deduplication, SUMMARY
order, nested/README links, source and output aliases, rendered-anchor
query/fragment handling,
Unicode and encoded filenames, one-layer entity decoding, false-positive
exclusions, empty books and isolated chapters. Existing HTML tests cover the
shared tag scanner used by whole-book rendering.

`chapter_connections_tests` exercises the ordinary native driver load/build
API, exact source preservation, deterministic repeat builds, editing and
retargeting, missing-entry output preservation, and reserved output collisions.
Set `MOONBOOK_CONNECTIONS_EVIDENCE` to retain the synthetic pilot book and both
before/after projections. `scripts/inspect-chapter-connections.py <evidence>`
parses those actual outputs, verifies the complete expected graph and four
reverse panels, and resolves every generated connection link and fragment.
These checks do not establish visual/browser, live server, deployment or full
product qualification.
