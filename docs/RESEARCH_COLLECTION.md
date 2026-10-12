# Collect a research brief

Use **Research collection** in the ordinary MoonBook application to compare
evidence from several searches and leave with a readable Markdown or self-contained offline HTML brief.

## Walkthrough

To research papers from a reference-manager export, first use
[Import a research library from RIS](RIS_LIBRARY.md). Each imported reference
has its own searchable citation and can be collected using this workflow.

1. Start a live Book server and open `/apps/moonbook/#book-search`, following
   [Search this Book](SEARCH_THIS_BOOK.md#startup).
2. Search for a decision or topic, then choose **Inspect maintained page**.
3. Read the complete page and choose **Collect inspected page**. This stores
   that inspection's complete text, citation and search question in this tab.
4. Search for a different angle or counterevidence and collect another page.
   Earlier selections survive new searches, paging, failed queries and fresh
   inspections. Open **Read collected snapshot** to compare the saved text.
5. Set the brief title, write your research question and synthesis, and add a
   note to each selection. Use **Move earlier**, **Move later**, or **Remove
   selection** to shape the brief.
6. Review **Preview exact research brief**. **Copy research brief** and
   **Download research brief (.md)** export exactly that text, in your order.
   **Download offline brief (.html)** provides the same current selections as a
   navigable, printable single-file reading artifact.
   For an editable checkpoint, choose **Save resumable collection (.json)**
   before closing, navigating away, or reloading the application.
7. In a later session, expand **Resume or combine a saved collection**. Choose **Open
   collection JSON** or paste the file text, review the title and citations,
   then choose **Replace collection and resume**. Save current work first:
   replacement is explicit. To keep both sessions, use the separate combination workflow below.
8. Continue editing notes, reordering and removing selections. Download a fresh
   JSON checkpoint or a Markdown brief. The same snapshots and supplied source
   labels survive the round trip; no source is re-fetched automatically.

## Combine two saved reading sessions

1. Resume your first collection, or keep the collection you are editing. Save a
   separate JSON checkpoint if you want to return to that exact session.
2. In **Resume or combine a saved collection**, open or paste the second JSON.
   This only stages the file and does not replace current work.
3. Open **Combine with current collection**. Confirm for yourself that the
   sessions belong to the same Book. Citations are Book-relative: the same
   citation in two different Books does not prove the same source. Combining
   cannot authenticate or infer Book identity.
4. Read the incoming title and synthesis. The current title and synthesis are
   kept, not automatically concatenated or replaced. Copy any incoming wording
   you want into the normal synthesis editor. Editing current work invalidates
   previous collision choices; make those choices again afterward.
5. For every differing same-citation selection, compare the complete snapshots
   and notes. Choose **Keep current active** or **Use incoming active**. The
   chosen snapshot and its own note occupy the current selection's position;
   the unchosen complete snapshot and note are retained in history. A note-only
   difference is a collision too. Exact identical items are included once.
6. Review the resulting active and historical counts, then choose **Combine
   collections and retain snapshots**. Current selection order stays unchanged;
   new citations append in the incoming archive's order. Both existing history
   arrays are retained in their internal order, current then incoming, followed
   by displaced collision items. This is grouped retention, not a global timeline.
7. Continue editing notes and order, then save fresh resumable JSON or download
   a Markdown brief. JSON contains both histories and unchosen collision notes;
   Markdown contains only the current selection and a historical count.

**Cancel combination choices** leaves current work untouched. Closing the panel
also applies nothing. Edited current work, replaced intake, resume, cancellation
and old rendered apply buttons cannot reuse older collision decisions. There is
no server write, source acceptance, re-fetch, or new authority. Both v1 and v2
inputs use the existing decoder; the result remains v2. The same 12 active,
48 historical and 1,048,576 complete-text code-unit limits apply to the entire
combination. An unresolved collision or limit failure keeps all current work.
No history is silently removed. Combining the same file deliberately again can
repeat historical entries; an old double-click cannot apply twice.

## Refresh a collected citation without losing your note

1. In the same Book, search for the collected citation and choose **Inspect
   maintained page** again. An inspection alone never changes the collection.
2. Open **Compare with collected snapshot** below that inspection. Compare the
   complete collected and fresh text, titles, and supplied retained-source
   reference/digest labels. Your current note is shown too. Titles still come
   from search and may predate inspection; digest labels remain host-supplied.
3. If you want the replacement, choose **Refresh snapshot and retain history**.
   Your note and selection position stay the same. The outgoing complete page
   envelope, title and note are appended to **Retained snapshot history**.
   Closing the comparison or searching elsewhere makes no replacement.
4. Choose **Save resumable collection (.json)** to keep current selections and
   all outgoing history. Resume that file explicitly to recover both. The
   Markdown brief includes current selections and a history count; it is not a
   backup of outgoing versions. JSON includes those versions and historical
   notes, even if you subsequently remove the active selection. Check that
   expanded sharing scope before sending JSON to someone else.

Matching text, title and supplied source binding is reported as unchanged;
changing only the search question or results page creates no historical version.
A changed source binding counts as a change even when the text is identical.
The refresh button is bound to the exact completed inspection and collection
revision shown in the comparison. Late inspection callbacks, older rendered
buttons, note edits, reordering, remove/recollect, and resume cannot apply an old
replacement. Reopen the current comparison after editing. Nothing is fetched or
accepted automatically, and refresh makes no server write or review decision.

Book-relative citations do not identify a Book globally. After resuming a file,
confirm that you are inspecting the same Book; the feature cannot authenticate
an imported archive or infer cross-Book identity. Within each input history, explicit retention order is preserved. Combining places
current history before incoming history and then displaced collision snapshots;
that grouping is not a global chronology or an inferred retrieval timestamp.

For example, collect the Aurora pilot plan and the onboarding capacity note
from `examples/research-collection/`. Compare the proposed twelve teams with
the eight supported by the current capacity note. Record that discrepancy as
your research note rather than interpreting either import as an approved fact.
The brief provides the selected evidence for a later decision.

## What is retained and what is not

- The active collection is transient in-memory state. It is not automatically
  saved to the Book, browser storage, or an account; reload loses unsaved work.
  A downloaded Markdown brief is a reading artifact. The separate versioned
  JSON archive restores the title, synthesis, selections, notes, ordering and
  complete snapshots through the explicit resume workflow.
- Imported archives are supplied data, including all purported digest and
  retained-source labels. Resuming does not authenticate the file or verify it
  against this Book. Reinspect the original Book to check freshness. Never treat
  an archive as permission, source acceptance, or a canonical Book import.
- Each Book-relative citation refers to the current host's Book. The export
  is a set of independently inspected snapshots, not an atomic Book revision.
  The title is copied from the search result and can predate the inspection.
- Recollecting an existing citation keeps the earlier snapshot and its note.
  Use the explicit comparison and refresh workflow above to retain the note,
  position and outgoing historical snapshot.
- Host-reported maintained-page SHA-256 and retained-source reference are
  included when the inspection supplies them. Other maintained pages clearly
  say the host did not supply those fields. This does not claim independent
  client hashing, original-source verification, or factual acceptance.
- The brief includes complete selected maintained-page text and your notes,
  but not retained original files, unselected pages, keeper records or review
  journals. Check the selected content before sharing the downloaded file.
- Source text and researcher notes render as escaped text in the application
  and inert fenced text in the Markdown brief, including embedded HTML or
  Markdown fences. It does not create active source links or execute HTML.
- Limits are 12 active pages, 48 outgoing historical snapshots, and 1,048,576
  UTF-16 code units of total complete page text across active and historical
  snapshots,
  160 for the title, and 4,000 each for synthesis and notes. Exceeding a limit
  keeps existing content and reports the problem, with no truncation or silent
  history eviction. A refresh must fit both outgoing and replacement snapshots.
  At a limit, save the collection before explicitly starting another collection.
- JSON intake accepts files up to 16 MiB and text up to 8,388,608 UTF-16 code
  units. Exports use `moonbook.research-collection.v2`, with required history,
  distinct nonempty active citations, valid page envelopes and bounded metadata
  for both active and historical snapshots. Legacy
  `moonbook.research-collection.v1` files without a history field are explicitly
  read as having no history and saved as v2. Old clients reject v2 rather than
  silently losing outgoing versions. Bad/oversized input keeps the active
  collection. Unknown schema versions do not silently migrate.
  Preserve the downloaded JSON structure when transferring the archive rather
  than manually rewriting snapshot metadata fields.
- Clipboard denial leaves the collection intact; download or select the exact
  preview. A download request is not proof the browser saved a file. A late
  export completion cannot label a subsequently edited collection exported.

The feature uses the existing read-only query and inspection endpoints. It
adds no server write, acceptance transition, source import, or new permission.
It does not alter legacy `accepted` or `verified` metadata semantics.

## Restore an earlier research snapshot

Open **Retained snapshot history**, then expand the numbered citation you want.
Read its historical title, complete inspection metadata/text and researcher
note. The number is its position in retained history, not a date or version
identifier. Where that citation is active, expand **Compare active snapshot
that will move to history** to inspect both complete envelopes before choosing
**Restore historical snapshot N as active**.

Restoration moves the selected historical entry into its existing active
position, including its original note. The displaced active entry, including
any newer note, moves to the end of history. Other history entries keep their
order. If the citation is no longer active, restoration appends it and removes
only that exact historical entry. Duplicate historical entries are not silently
deduplicated. Title and synthesis for the collection remain unchanged.

At 12 active selections, a missing citation cannot append; the UI explains how
to free a slot. Replacement still works at 12 active/48 historical snapshots or
the full text budget because no snapshot is duplicated or discarded. To undo a
replacement, restore the displaced entry now at the end of history. Older
buttons cannot act after an edit, reorder, refresh, combine, resume or another
restoration. Restoring also invalidates pending combination choices.

Save the resumable JSON to keep both active and historical snapshots. Markdown
includes only the newly active selections. Restoring is local research editing:
it does not update maintained Book pages, re-fetch a source, verify freshness,
accept a claim or rewrite original retained files. Imported source/digest labels
remain supplied data. There is no autosave.

## Find a retained claim or research note

Use **Find in collection snapshots** to enter a literal phrase. Choose **Active
and history**, **Active only**, or **History only**. Matching snapshots remain
in original order: active selections first, then retained history. The result
number identifies the original position, not a rank, time or version. Identical
historical entries are separate results. Empty/whitespace queries show no hits;
**Clear phrase** clears only the search text.

Search covers title, Book-relative citation, original search question, researcher
note, complete snapshot text, retained-source reference and supplied page digest.
Each matching field shows its first match with up to 70 Unicode code points on
either side. Expand the complete inspection and note to see all content. The
phrase is limited to 200 UTF-16 code units. Matching uses JavaScript Unicode
case-insensitive literal semantics, with outer whitespace ignored. Regex
operators are literal; there is no fuzzy matching, accent normalization,
stemming, or equivalence between all case expansions such as `ss` and `ß`.

For a historical result, compare its complete envelope and note with the active
entry, then choose **Restore matching historical snapshot N**. This is the same
explicit, revision-guarded restoration described above. The result list updates
from the resulting collection; the restored snapshot may move out of a
history-only search. Missing citations cannot append when all 12 active slots
are full. Search edits alone do not alter collection revision or invalidate a
correct restore action; actual collection edits invalidate older actions.

This searches in-memory retained snapshots, including resumed supplied data,
not live Book pages or raw file contents. Collection title/synthesis are edited
separately and are not snapshot fields. Search text/scope are transient and are
not saved in JSON. Search never filters the archive or reading brief: JSON
still includes every active and historical snapshot; Markdown and HTML include
every active selection. Save your collection before leaving. There is no autosave,
source fetch, review decision or freshness/authenticity assertion.

## Read or print an offline HTML brief

Choose **Download offline brief (.html)** in the existing research collection.
Open `moonbook-research-brief.html` in a browser. No server, network connection,
script, font download or other external resource is needed. Use the contents
links to reach a selection, its researcher note or its complete snapshot. Use
the browser's Print command to print or save a PDF; print styles keep all source
text expanded and begin each selection on a new page. Printer pagination and
font availability remain browser-dependent.

The file contains the current title, question/synthesis, ordered notes and all
complete current maintained-page snapshots. Researcher-authored synthesis and
notes are labelled separately from source content. Each selection keeps its
search title, Book-relative citation, original question, search-page number when
supplied, and supplied retained-source reference/digest. Missing or empty source
labels and absent search-page metadata are explicit. Inspection time and factual
review are not recorded by this collection and are never inferred. A supplied
digest is a label, not independent integrity or factual verification.

All supplied text is escaped, including titles, notes, citations, digest labels
and embedded source markup. Only fixed local navigation links are active. A
restrictive content-security policy adds defense in depth. Original retained
files, unselected pages and historical snapshot contents/notes are not embedded.
The history count is visible, but this current-snapshot reading projection is
not a backup or resumable format. Save the existing JSON v2 separately to keep
history and resume authoring. The archive schema and host remain unchanged.

HTML is generated from the collection revision at the click, including unsaved
edits, reordering and removal. Finder text/scope never filters it. The button is
disabled when there are no current selections. A late download completion cannot
label a newer edited collection exported. A download request is not confirmation
that the browser persisted the file. The existing 12 active / 48 historical /
1,048,576 complete-text code-unit and authoring/metadata limits still apply, with
no extra renderer truncation. Current Unicode text, spacing and line breaks are
retained in escaped pre-wrapped text blocks.

## Verification

`main/book_collection_html_wbtest.mbt` exercises exact Unicode/full snapshot
rendering, ordered anchored sections, hostile markup, absent/empty metadata,
empty collections, maximum text and metadata budgets, current edits/reorder/
remove, unfiltered scope, stale success/failure completions and rejected downloads.
It runs the production HTML effect/downloader and verifies actual UTF-8 Blob
bytes, MIME and fixed filename, then saves real JSON and reopens it through the
production file reader into fresh state before exporting equivalent HTML.
`MOONBOOK_HTML_EVIDENCE` names an existing directory for the synthetic JSON,
actual HTML/Markdown, Blob receipt and production authoring-panel rendering.
DOM/file-picker/URL/timer calls use controlled doubles; no graphical-browser,
native-host or OS-download qualification is implied.


`main/book_collection_find_wbtest.mbt` exercises literal/Unicode matching, each
field, scopes, original positions/duplicates, late matches at the full text
budget, 60 results, capacity refusals, stale restoration, escaped rendering and
production Blob/file-reader save/reopen. With `MOONBOOK_FIND_EVIDENCE` naming an
existing directory it records a synthetic starting archive, search HTML and
actual recovered JSON/Markdown downloads. Controlled browser API doubles do
not qualify mounted-browser interaction or OS download persistence.

`main/book_collection_restore_wbtest.mbt` tests full-envelope/note swaps,
missing-citation append, exact duplicate history, undo, stale/double actions,
capacity/text limits and invalidation of combination choices. Its production
render/Blob/file-reader test saves before/restored JSON, the reopened Markdown
brief and escaped comparison HTML when `MOONBOOK_RESTORE_EVIDENCE` names an
existing output directory. Controlled DOM/file-picker doubles do not qualify a
mounted graphical browser, OS download persistence or a fresh native server.

`main/book_collection_merge_wbtest.mbt` tests both collision choices, note-only
collisions, exact duplicates, retained history/order, further edits, stale and
cancelled previews, all-or-nothing limits and v1/v2 round trips. With
`MOONBOOK_MERGE_EVIDENCE` pointing at an existing directory, its compiled
production file-reader and Blob test writes current/incoming/combined JSON,
an edited Markdown brief and escaped combination preview HTML. These use
synthetic supplied snapshots and controlled DOM/file-picker doubles, not a
mounted browser or new native server inspection.


`main/book_collection_refresh_wbtest.mbt` tests explicit refresh, complete
old/new snapshot and source binding retention, note/order preservation, repeat
navigation, stale callbacks and replayed clicks, unchanged inspection,
all-or-nothing limits, legacy intake and v2 archive roundtrip. Its synthetic
production Blob/file-reader test records the actual downloaded JSON, Markdown
brief and escaped comparison rendering when `MOONBOOK_REFRESH_EVIDENCE` names
an existing output directory. It uses controlled DOM/file-picker doubles, not a
graphical browser or a fresh native server inspection.

`main/book_collection_archive_wbtest.mbt` additionally crosses actual native
HTTP snapshots through JSON download, file-reader intake, explicit resume,
continued note editing and Markdown export. The production Blob and file reader
use controlled DOM/file-picker doubles. `MOONBOOK_ARCHIVE_EVIDENCE` selects the
output directory for the actual portable archive and resumed brief.

`main/book_collection_wbtest.mbt` tests production reducers for collection,
editing, ordering, removal, duplicate preservation, limits, stale callbacks and
exports. The native crossing accepts a wire fixture produced through actual
local TCP query/inspection requests, then uses the compiled UI transport,
decoders, reducers, escaped rendering, clipboard function and download Blob.
`MOONBOOK_COLLECTION_WIRE`, `MOONBOOK_COLLECTION_UI_RECEIPT` and
`MOONBOOK_COLLECTION_EXPORT` select those retained evidence paths. The exported
sample brief is captured from the actual compiled production download function.

Clipboard/DOM/download effects use controlled test doubles. No mounted browser,
keyboard/accessibility, OS clipboard, macOS or office-application qualification
is claimed by those tests.
