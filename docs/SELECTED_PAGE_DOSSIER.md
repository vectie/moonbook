# Export a selected MoonBook evidence dossier

After importing/searching a Book, choose the exact maintained-page citations you
want to read or hand off. Export their complete observed text with provenance:

```sh
moonbook wiki query ./book 'travel policy'
moonbook wiki export-pages ./book wiki/sources/policy.md wiki/concepts/onboarding.md > dossier.md
moonbook wiki export-pages ./book wiki/sources/policy.md --json > dossier.json
```

Replace the example citations with actual query/import results. The root is
required; use `.` inside a Book. Selection order is preserved. Duplicate citations
are refused. The default Markdown dossier contains numbered pages, citation,
SHA-256 and legacy metadata status, then literal fenced full-page content.
Fences expand beyond embedded backtick runs. Citation and metadata are also
fenced, so source HTML and Markdown cannot inject active dossier markup. This is
an output document, not a Markdown rendering of the selected chapters. Do not
execute its contents. As with any content export, control characters in raw
content are retained: redirect Markdown to a file rather than an untrusted terminal.

`--json` must be last. Schema `moonbook.wiki-page-dossier.v1` contains `notice`
and ordered `pages`, each with `citation`, `digest`, `metadata_status`, `content`.
JSON round-trips exact decoded content, including CRLF, Unicode, empty pages and
missing final newline. Markdown inserts a newline before a closing fence where
needed; use JSON when exact reconstruction matters. Digests use `sha256:` plus
SHA-256 of UTF-8 encoding of the exact decoded content, not raw external source
bytes or generated dossier bytes.

Unlike query briefs, this output contains complete selected pages instead of
ranked excerpts. Unlike the broad knowledge bundle, it does not normalize Book
metadata or collect all knowledge. It copies only supplied maintained citations.
No linked/raw files are followed or embedded, no raw evidence, pending-review
records or generated projections are traversed, and no source Book paths beyond
the selected citation identifiers are added. Selected pages themselves may
contain private metadata or textual references to other files. Review before
sharing; selection is not redaction or authorization to send the output.

The command changes no files, reviews, acceptance labels or permissions. Legacy
metadata retains the full single-line status value (LF or CRLF frontmatter);
only one conventional separator space after `status:` and the line terminator
are removed. Other value whitespace is preserved. Quoted/multiline YAML is not
interpreted. This is not factual approval. Reads are
sequential; their hashes identify each observation, not an atomic Book snapshot
or shared cross-Book identity. The same citation can exist in different Books;
retain the dossier with its intended Book context.

Limits: 1–32 unique pages; at most 262,144 UTF-16 code units per page and
1,048,576 total. The maintained reader additionally caps physical input at 2 MiB,
rejects symlinks, traversal and non-maintained/nonregular pages, and detects
observed per-file changes. Out-of-bounds or unreadable selection fails the whole
command before any dossier is emitted; no silent truncation. Exit 0 is success;
exit 1 prints `export-pages failed:` to stdout. Never parse failure output as JSON.
Shell redirection can truncate an existing destination before the command runs.

## Focused evidence

The retained smoke creates a Book, imports two documents, queries it, exports
selected exact pages in both orders, tests explicit/dot roots, Unicode/CRLF and
empty/final-newline cases, literal hostile Markdown/metadata, bounds and path
refusals. It verifies content hashes and that the entire Book is unchanged.
`verify.sh NEW_LABEL` replays focused native checks and smoke into new retained
evidence. This is local CLI/API qualification only; no browser, live provider,
cross-machine transfer or cumulative qualification is claimed.
