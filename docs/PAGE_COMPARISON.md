# Compare two cited MoonBook pages

`moonbook wiki compare-pages` lets a curator inspect the complete changes between
two maintained source or knowledge pages. For example, import a revised policy,
find both citations using ordinary Book search, and compare the 14-day refund
window with the new 30-day wording before deciding what knowledge to revise.
This closes the missing page-comparison step in PRD UC02/B02 and correction
review R03; it does not implement automatic correction acceptance.

## Use

```sh
moonbook wiki ingest ./book policy-before.md
moonbook wiki ingest ./book policy-after.md
moonbook wiki query ./book "refund policy"
moonbook wiki compare-pages ./book wiki/sources/BEFORE.md wiki/sources/AFTER.md
moonbook wiki compare-pages ./book wiki/sources/BEFORE.md wiki/sources/AFTER.md --json
```

Use the exact `wiki/.../*.md` citations shown by import/search. Within the Book,
you may omit the root or use `.`. Names before/after identify your chosen sides;
they do not assert chronology, revision lineage, truth or approval. Identical
citations are allowed and read once. The default human-readable text shows both
citations and content SHA-256 values, existing metadata status, counts, and every
aligned line. `--json` returns `moonbook.wiki-page-comparison.v1`.

Rows are `equal`, `remove` or `add`, each containing exact line text and its
one-based before/after line numbers. Derived JSON omits the absent line-number
property; present numbers are unwrapped integers. Removed rows have no after
line, added rows have no before line. Keeping all rows except additions rebuilds
the before text exactly; keeping all except removals rebuilds the after text.

The deterministic longest-common-subsequence alignment avoids turning one
inserted paragraph into a change to every later line. Equal alternatives prefer
removal before addition. Repeated lines can admit multiple equally valid
alignments; this is text comparison, not sentence-aware or semantic analysis.
Whitespace, Unicode, carriage returns, blank lines and a missing final newline
are preserved. A line's LF terminator is included when present. Human-readable
rows contain JSON-quoted text, so `\n`, `\r` and escaped control characters are
visible without executing terminal controls. Treat that format as plain text,
not HTML. Whole-page frontmatter/provenance changes are intentionally included.

## Identity, privacy and limits

The read-only command changes neither page nor raw source, review queue,
accepted knowledge, generated state or permissions. Legacy page metadata such
as `accepted` is displayed as metadata and does not mean factual acceptance.
Only the existing maintained-page reader is used: outside paths, traversal,
symlinks, nonregular files and generated/nonqueryable citations are refused.
Nothing is fetched from a page link. The command compares maintained Markdown,
which may be a derived summary; it does not compare linked raw documents.

Each page is limited to 256 Ki UTF-16 code units and 1,000 lines before the
quadratic alignment matrix is allocated. The underlying reader already caps
physical input at 2 MiB and detects observed per-file modifications. Larger pages
fail visibly rather than return a truncated comparison. Empty pages work. Content
hashes bind UTF-8 encoding of the exact decoded text observed for each side,
not an original external file or an atomic multi-file snapshot. Reads of two
distinct pages are sequential, so use stable Books. No review transition,
chronology repair or migration of old status labels is performed.

Success exits 0. Usage, unreadable or out-of-bounds input exits 1 with the existing
CLI-style `compare-pages failed:` diagnostic on stdout; never parse a nonzero
exit as a JSON comparison. Comparisons include full source content and private
metadata without redaction. Review them before sharing. A shell redirection can
overwrite a destination before the command starts.

## API and focused evidence

Pure `@page_compare.compare_page_text(before, after)` supports non-file callers.
Native `@wiki.compare_wiki_pages(root, before_citation, after_citation)` adds
maintained-page access and identity; `.to_text()` provides the readable view.
Four pure JS tests cover alignment and exact reconstruction across Unicode,
CRLF, empty/repeated/final-newline cases and bounds. The ordinary native CLI smoke
imports two synthetic policy revisions, searches citations, compares both
directions, handles omitted/dot/absolute roots, checks source digests and exact
reconstruction, rejects outside/symlink/malformed selections and proves the
entire fixture Book remains byte-identical across all comparisons.

Run this round's `verify.sh NEW_LABEL` to retain a fresh reproduction. Native
integration uses the exact Leaf R58 companion and original dependency graph.
No graphical browser, live provider or broad product qualification is claimed.
Cumulative qualification remains R50.
