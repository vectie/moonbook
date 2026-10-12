# Import a BibTeX research library

Import a local `.bib` export directly into MoonBook. Each reference becomes its
own searchable maintained source page with its citation key, complete fields,
abstract and a link to the retained original export. No conversion to RIS or
manual splitting is needed.

## Read, search and inspect

```sh
moonbook wiki init /tmp/research-book
moonbook wiki import-bibtex /tmp/research-book /absolute/path/library.bib
moonbook wiki query /tmp/research-book "guided setup"
moonbook build /tmp/research-book
moonbook serve /tmp/research-book -n 127.0.0.1 -p 3456
```

The import returns JSON listing the retained raw path and each reference's
citation key, title, ordinal, Book-relative citation and page path. Inside an
initialized Book, omit the root or use `.`; relative input paths resolve inside
that Book. Text search also matches cross-reference values and earlier imported
snapshots; the CLI shows its top three results. Use the returned page path or
paged Book Search results when those matches crowd out the desired reference.

Open the generated source chapter to read complete metadata. The existing
Book Search app also supports searching for a key, author, title or abstract,
then **Inspect maintained page** and **Read retained source**. The retained
source is the whole bibliography, which can include other references. Check its
scope before sharing. Existing research collections can use these ordinary
source pages; see [Research collection](RESEARCH_COLLECTION.md).

`examples/bibtex-library/synthetic-library.bib` contains invented onboarding and
capacity references for a repeatable local walkthrough. The studies, names and
DOI are synthetic, not factual research or publication claims.

## Bounded format

- UTF-8, optional BOM, LF or CRLF; references delimited by `{...}` or `(...)`
- Case-insensitive entry types and field names; citation key spelling retained
- Braced and quoted values, nested brace groups, numeric literals, multiline
  abstracts, Unicode, and optional final field commas
- `#` concatenation and previously defined `@string` abbreviations; standard
  three-letter month abbreviations expand to English month names
- Brace-delimited `@comment` blocks and free text between entries remain in
  the retained bytes, without becoming source pages
- All fields, including unknown fields and entire author lists, retain their
  order; normalized field names and expanded values appear in inert fenced text
- Title whitespace is normalized for navigation. Inner protection braces and
  TeX commands, including accents, remain literal text; no TeX is executed.

This is a bibliography import, not a BibTeX typesetter. It does not render TeX
accents, execute styles, resolve `crossref` inheritance, fetch URLs, resolve DOIs,
open attachments or load other files. Cross-reference keys remain visible as
supplied fields. A title must be present in each entry, even if a typesetter
could inherit one. `@preamble`, undefined/forward abbreviations, repeated string
definitions (including built-in months), duplicate fields, and duplicate keys
(case-insensitive) produce a repairable error. Export expanded literal values
or correct the bibliography and retry.

The syntax choice was checked against BibTeX author Oren Patashnik's
[BibTeXing manual](https://www.openoffice.org/bibliographic/btxdoc.html), notably
its descriptions of concatenation, string definitions, abstracts and TeX data.
This is an independent bounded parser, not complete BibTeX/biblatex parity.

## Retention and boundaries

An initialized Book is required. Imports read a local file, with no network
access. The original bytes are saved under a unique `raw/imported/references.bib`
name before UTF-8 decoding or parsing. A parse failure names that retained file
and line; a malformed later entry does not partially add earlier source pages.
A file larger than 2 MiB is rejected before retention (it is read before the
size check). Up to 500 references, 500 explicit string definitions, 1,000 fields
per reference, 131,072 expanded code units per reference/value and 400-code-unit
titles/keys are supported. Split larger exports before importing.

Reimport appends a fresh raw snapshot and fresh source pages, leaving earlier
pages unchanged. It does not deduplicate, merge or update existing references.
Run imports one at a time. I/O failure after successful parsing may leave some
completed pages; retain the export and inspect the Book before retrying. This
is not a multi-file transaction or a cross-machine restore guarantee.

Ordinary `build` retains the existing knowledge-bundle normalization: it refreshes
source-page frontmatter tags/timestamps and the generated coverage map. This
import does not change that behavior. Bibliographic body text and retained raw
bytes stay intact; do not treat generated frontmatter as an immutable import
receipt.

The existing `accepted`/`verified` metadata labels retain their legacy import
meaning. Bibliographic metadata is supplied text, not factual verification,
claim review or an accepted reusable lesson. No inferred entities or claims
are generated by this import.

## Focused checks

`wiki/bibtex_import_wbtest.mbt` checks syntax, metadata preservation, bounds,
search, full-page inspection, exact retained bytes, repeat import and malformed
input. `scripts/bibtex-library-smoke.py` uses the built ordinary CLI to initialize,
import, search and build a retained fixture, including omitted/dot/absolute root
forms and a malformed later record. It checks actual generated HTML and
source preservation. No browser mounting or external service is involved.
