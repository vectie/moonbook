# Read retained source from Book search

1. Open the ordinary Book application and search maintained pages
2. Select **Inspect maintained page** for a result
3. When its generated source binding is available, select **Read retained source**
4. Read the complete retained UTF-8 text beside the maintained page, or select **Download inspected retained bytes**

The source panel shows its Book-relative reference, byte count, and SHA-256.
Downloads are `application/octet-stream` blobs made from the exact bytes already
inspected. They do not fetch or re-read the file. Re-read explicitly to obtain
current bytes. Editing or submitting a search, selecting/re-inspecting a page,
and reloading discard retained-byte state; stale responses cannot restore it.

## Meaning and limits

- These are **retained bytes at inspection**, not a claim of byte equivalence to
  the original ingest and not factual verification
- A remote capture can itself be an excerpt; reading the full retained capture
  does not retrieve the remote website or reconstruct its original content
- The complete retained file must fit within 2 MiB. Oversized files are not
  silently truncated or downloaded partially
- Valid UTF-8 without binary control characters is displayed only as escaped
  text. Binary or invalid UTF-8 bytes have no active preview, but the same bounded
  exact-byte download remains available
- Missing, unreadable, ambiguous, malformed, nonregular, or symlinked retained
  files make the optional retained reader unavailable. The maintained page can
  still be inspected
- The host computes SHA-256 over the returned bytes. The UI validates the byte
  encoding, size, reference, page identity and text; it also independently
  cross-checks SHA-256 when WebCrypto is available. An existing HTTP LAN host
  does not require a new HTTPS setup just for this feature

## Read-only boundary

`POST /api/book/query/inspect` adds an optional `retained_source` descriptor to
the existing maintained-page response. The descriptor has a Book-relative
reference and the SHA-256 of the complete inspected maintained page.

`POST /api/book/query/retained-source` accepts the search question, selected
maintained-page citation, and its inspected `page_digest`. The selected citation
must still be among the question's current lexical results. The host re-reads
the maintained page, checks the complete page digest, resolves its unique
generated `Raw source` provenance header, and checks the page again after the
raw-file read. Any page change requires a fresh inspection.

Only the generated provenance-header shape on a `wiki/sources/` page with
`moonbook_type: source` is recognized. Its label must be a canonical `raw/`
reference and its link must be exactly the generated relative link. Arbitrary
Markdown links, code-fence examples, URL targets, absolute paths, traversal,
encoded path syntax, and duplicate provenance declarations do not authorize a
read. There is no user-requested raw-path, root, or remote-fetch endpoint.

Filesystem reads use anchored directory descriptors and `O_NOFOLLOW` for every
component. They reject nonregular files, excess size, and observed modifications
during reading. Both the page and retained file remain bounded. Search and
inspection do not write Book source files, indexes, reviews, query pages, keeper
records, or journals.

## Verification

Focused native tests exercise the actual socket dispatcher, generated ingest
with more than 24 lines, Unicode/CRLF, binary payloads, missing/changed binding,
unsafe references, symlinks, nonregular and oversized files. They compare Book
content, directory membership, file kind/size, mtime and ctime before and after.
Compiled UI tests carry the native wire through production decoders, reducers,
escaped view rendering and Blob download interception. The ordinary CLI build
installs the independently compiled UI asset. These checks are not a live
graphical-browser run.
