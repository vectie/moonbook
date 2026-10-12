# Searchable DOCX sources

MoonBook ingests `.docx` files through MoonLeaf's DOCX reader and
`TextDocument::plain_text()`. Headings, paragraphs, list text, and table-cell text
join the ordinary source-page and lexical-query workflow. The source page keeps
the reader's complete text projection rather than only the usual 24-line
preview, so later sections and tables remain searchable. Matching query excerpts
prefer the relevant extracted line over a general source summary.

The original file is copied byte-for-byte into `raw/imported/` and linked from
the source page. Files already under `raw/` stay in place. Uppercase `.DOCX` works
too. An otherwise readable DOCX without text remains an attachment, with an
explicit no-readable-text message.

## Local setup and use

Keep these repositories as siblings:

```text
workspace/
  moonbook/  # includes moon.work
  moonleaf/ # accepted DOCX reader, 0.1.16
```

The committed `moon.work` resolves `vectie/moonleaf` to `../moonleaf`. This feature
uses Leaf commit `ce0e1ae60dc408e7a4489b6908fc3c830aaa3a3d`; there is no copied
parser or change to Leaf. MoonBook's existing dependencies remain unchanged;
Leaf brings its declared `hustcer/fzip@0.8.5` dependency.

```text
moon run cmd/main -- wiki init /tmp/company-book
moon run cmd/main -- wiki ingest /tmp/company-book /absolute/path/handbook.docx
moon run cmd/main -- wiki query /tmp/company-book "escalation desk"
moon run cmd/main -- build /tmp/company-book
moon run cmd/main -- serve /tmp/company-book -n 127.0.0.1 -p 3456
```

Open the generated source page to read the extract. Book Search's source
inspection and retained-source action also expose the original DOCX as a binary
attachment. No provider, office application, or conversion service is needed for
extraction.

## Scope and checks

This is text extraction, not layout reconstruction or OCR. It uses Leaf's
existing reader and plain-text limits (at most 1,000,000 UTF-16 code units).
Images, page geometry, headers/footers, and unsupported document structures are
not promised as searchable content. Existing Book query/retained-source reads
remain limited to 2 MiB per maintained page or original attachment. A reader
error names the DOCX file and reports the underlying failure.

`wiki/ingest_docx_wbtest.mbt` makes a real OPC/ZIP DOCX with a heading, a CJK
paragraph, and a table after 30 paragraphs. It checks ingestion, source-page
text, existing `query_wiki` citations and matching excerpts, exact retained
bytes, and reopening the retained attachment with Leaf. A second case checks
empty-text DOCX retention. Query excerpt behavior has a focused regression test
in `wiki/query.mbt`.

```text
moon test wiki/ingest_docx_wbtest.mbt --target native
moon test wiki/query.mbt --target native
moon build cmd/main --target native
```
