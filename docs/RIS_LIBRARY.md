# Import a research library from RIS

Bring a local reference-manager export into MoonBook as individually searchable
papers. Each reference gets its own maintained source citation, complete exported
metadata and abstract, and a link to the retained original export. Search for an
author, DOI, title or phrase in an abstract, inspect the reference, then collect
it into your research brief using the existing Book Search application.

## Use

Export a selected group of references from your reference manager as UTF-8 RIS.
Include abstracts if you want to search their content. Then run:

```text
moonbook wiki init /tmp/research-book
moonbook wiki import-ris /tmp/research-book /absolute/path/library.ris
moonbook wiki query /tmp/research-book "guided setup"
moonbook build /tmp/research-book
moonbook serve /tmp/research-book -n 127.0.0.1 -p 3456
```

`import-ris` prints JSON with the retained export path and the record number,
title, Book-relative citation and page path for each reference. The root may be
omitted when running inside the initialized Book. Relative input paths resolve
inside that Book, consistently with `wiki ingest`.

Open `/apps/moonbook/#book-search`, search, choose **Inspect maintained page**,
then **Collect inspected page**. Compare supporting and conflicting papers,
write notes and synthesis, and save a resumable collection or download the
Markdown brief. See [Research collection](RESEARCH_COLLECTION.md). **Read
retained source** opens the whole original export; the page identifies which
record it came from. An export can contain references beyond the selected page,
so inspect its scope before sharing retained bytes.

`examples/ris-library/synthetic-library.ris` contains two synthetic references:
an eight-team onboarding study and a five-team follow-up counterstudy. Nothing
in that example is a real publication, DOI, or observed research result.

## Supported input

- UTF-8, with or without a BOM, LF or CRLF lines
- Standard `TY  - JOUR` start and `ER  -` end markers, with a blank line between
  records optional; every record needs a nonempty type and a title
- Title aliases `TI`, `T1`, or `CT`; repeated `AU`/`A1` authors, keywords and
  other fields remain separate and in their original order
- Familiar fields get readable labels: date (`PY`/`Y1`), publication
  (`T2`/`JO`/`JF`/`JA`), abstract (`AB`/`N2`), DOI, URL, volume, issue, pages,
  publisher, ISSN/ISBN, notes and export identifier
- Any other uppercase two-letter/digit tag is retained as an additional field
- Non-tagged lines continue the preceding field, including multiline abstracts.
  Projection whitespace is normalized; the original bytes retain exact spacing
  and blank lines. Metadata and URLs render as inert fenced text.

The format mapping was checked against the primary
[Zotero RIS translator](https://github.com/zotero/translators/blob/master/RIS.js).
MoonBook implements this bounded reader independently; it does not embed that
translator or claim every vendor-specific RIS dialect is supported.

## Boundaries

The export is read locally, with no account, provider, network lookup, DOI
resolution or attachment import. Metadata and abstracts are supplied text, not
the complete paper or factual verification. Existing `accepted`/`verified`
source labels retain their legacy meaning; importing does not perform human
claim review or promote new guidance. Bibliography import adds source pages,
navigation and an ingest log, without generating inferred entities or claims.

An initialized Book is required. Up to 2 MiB of input, 500 records, 1,000 fields
per record, 131,072 UTF-16 code units per record and a 400-code-unit title are
supported. The file is read before the byte-limit check; split large exports in
the reference manager. Over-limit files are rejected before retention. Within
that file bound, original bytes are retained before parsing, including on a
malformed UTF-8 or record error. The error names their path. All records are
parsed before source pages are created, so a malformed later record does not
import the earlier records partially.

Repeated imports deliberately append new raw snapshots and new citations. They
do not deduplicate by title or DOI, merge libraries, or change earlier pages.
Run one import at a time. An I/O interruption after parsing can leave completed
pages; preserve the raw export and inspect those pages before choosing whether
to retry. This is not an atomic multi-file transaction.

## Checks

`wiki/ris_import_wbtest.mbt` covers metadata aliases, repeated fields, unknown
fields, multiline and Unicode abstracts, parse/size bounds, exact BOM/CRLF byte
retention, individual lexical queries, and preservation on malformed/repeated
imports. `internal/moonwiki/ris_library_http_test.mbt` exercises actual local
TCP search, complete-page inspection and exact retained-export reads, and
checks that those reads leave the Book unchanged.
Set `MOONBOOK_RIS_CLI` to an absolute path to the built ordinary CLI to also
exercise imports with an omitted root and an explicit `.` root in a child
process, plus the nonzero exit and retained source for malformed input.

`ui/rabbita-book/main/ris_library_wbtest.mbt` takes those native HTTP responses
through the compiled production search/inspection decoders and collection
reducers, saves and resumes a collection, and captures the exact Markdown Blob
from the production download function. It uses controlled DOM/Blob test doubles,
not a mounted graphical browser or a physical OS download. Set
`MOONBOOK_RIS_EVIDENCE` to a directory when running the native HTTP test and then
the UI test to retain the wire, resumable archive and actual research brief.
