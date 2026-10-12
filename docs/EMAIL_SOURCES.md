# Search a local email export

Save a message as `.eml` from your mail client, then use the ordinary ingest path:

```text
moonbook wiki init ./research-book
moonbook wiki ingest ./research-book /absolute/path/support.eml
moonbook wiki query ./research-book "Orchid escalation desk"
```

From an initialized Book directory, `moonbook wiki ingest support.eml` and
`moonbook wiki ingest . support.eml` also work. Relative source paths are resolved
inside the selected Book. Uppercase `.EML` is accepted. An initialized Book is
required. No mailbox connection, message sending, or URL fetch is involved.

Each import copies the exact original into `raw/imported/message.eml` (with a
numeric suffix on repeats), then makes a searchable page in `wiki/sources/`.
The page includes supplied Subject, From, To, Cc, Date, Message-ID, Reply-To and
In-Reply-To headers when present, plus the complete selected plain-text body.
Search reaches late paragraphs and Unicode text, not only the opening excerpt.
The date remains the supplied header, without inferring a timezone or chronology.

In the Book search UI, inspect the matching source to see attribution and use
the existing retained-source download to recover the exact `.eml`. Collect the
source, add research notes, save/resume the collection, or download its Markdown
research brief. A brief contains the maintained source text, not attachment
bytes. The retained original may contain addresses and private attachments;
review it before sharing. Import does not authenticate senders or verify claims.
Legacy `accepted` / `verified` metadata retains its existing interpretation.
No accepted claim, review decision, or execution authority is created by MIME
parsing.

## Supported export shape

- One local message, at most 2 MiB, including attachments. Bytes are read before
  this limit is checked. Oversized inputs are rejected before retention.
- UTF-8 or US-ASCII plain text, with absent/7bit/8bit, base64, or quoted-printable
  transfer encoding. Missing charset is interpreted as UTF-8.
- Folded headers, raw UTF-8 header values, and UTF-8/US-ASCII encoded words using
  `B` (base64) or `Q` encoding. Subject limit: 400 code units.
- Multipart mixed, related, and alternative messages, including nested forms.
  Alternative chooses the first inline plain-text body; other supported
  multipart forms join inline plain-text parts in message order.
- At most 8 nested MIME levels, 64 total parts, 200 fields and 64 KiB of headers
  per part. Standard CRLF and LF line endings work.

HTML alternatives, attachments (including named text parts), embedded messages,
and unsupported non-plain MIME types are excluded from the projection. Their
bytes stay in the original; no attachment extraction, link fetching, HTML
rendering, OCR, mailbox import, thread grouping, deduplication, signature
verification or legacy charset conversion is added. MIME comments, RFC2231
parameter continuations and unusual vendor encodings are not decoded. Export
such messages as UTF-8 plain text when needed.

## Repair an unsupported or malformed export

Within the file limit, the original is retained before parsing. Invalid UTF-8,
malformed encoded words, invalid transfer encodings, broken MIME boundaries,
ambiguous duplicate MIME/attribution fields, and messages with no readable
inline plain-text body report an error containing the retained path. No partial
source page is created on parse failure. Correct or re-export the input and
import again; previous originals and source pages are not overwritten.

Imports append snapshots even for the same Message-ID. One operator/import at
a time is supported. The existing multi-file wiki updates are not transactional;
an I/O interruption after parsing can require inspecting the retained original
and retrying.
