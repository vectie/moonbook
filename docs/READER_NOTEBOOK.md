# Offline reader notebook

An ordinary SUMMARY-based build now includes `__moonbook/notebook.html`.
Open **Reader notebook** in the sidebar, choose a chapter, write a note, and
choose **Save note**. **Read selected chapter** takes you back to that chapter;
the notebook link brings you back to the chapter selector. Changing the selected
chapter saves the current draft first. Clearing a note and saving removes it.

**Export Markdown notes** downloads `reading-notes.md`, including any current
unsaved draft. Notes appear in SUMMARY order with original source paths. Each
note is quoted as reader commentary, with HTML characters escaped, and the
brief explicitly separates personal notes from reviewed claims. The exported
file can be read or edited in a text editor and imported for review using the
bounded [external editing format](#edit-notes-in-a-text-editor). JSON remains the
lossless archive format, including original line endings.

## Scope and durability

- Notes live in browser local storage under the current origin plus book-output
  directory URL, not under the book title. Two books at different URLs remain
  separate even if they have the same title.
- Rebuilding at the same URL retains notes. Chapter paths are identities; changing
  a chapter title does not lose its note. Renamed or removed chapters remain in
  the selector and export under **Removed chapter**; notes are not automatically reassigned.
- Replacing a different book at the same URL reuses that URL's notebook. Export
  first and use distinct directories when hosting distinct books.
- Moving a book, switching browsers/devices, private browsing or clearing browser
  data does not transfer notes automatically. Export and import a notebook archive
  to transfer them; export regularly. Notes are not encrypted and are
  accessible to scripts on the same origin.
- Local `file:` storage varies between browsers. A locally served book gives more
  predictable storage. No network calls or account are needed for this notebook.
- A storage denial, quota error, unreadable record or unknown version makes the
  notebook tab-only. The page says so, keeps the draft usable and permits export;
  it does not overwrite unreadable existing records. Keep the tab open until you
  have exported. Leaving with an unsaved draft or tab-only notes requests the
  browser's normal departure warning, which some browsers may suppress.
- Saves merge unrelated chapter changes made by another tab. Simultaneous saves
  to the same chapter are last-save-wins, so use one editing tab per chapter.

Notes never write to the source tree, wiki, accepted claims, review queues or
server. Source content is not copied into the notebook's embedded metadata.
Without JavaScript the existing reader still works, but notebook controls do not.
An empty book produces an empty export and disables chapter editing.

## Focused evidence

Native `notebook_tests` exercises real load/build output, nested paths, repeated
builds, unchanged authored content and a missing-source failure. The HTML unit
case checks inert metadata, body exclusion and draft filtering. The Node test
executes the actual script extracted from native-generated notebook HTML with
minimal DOM/storage/Blob adapters, checking saves, revisits, multiple book scopes,
portable Markdown bytes, storage failures, retained removed chapters and tabs.
This is functional headless evidence, not browser/device compatibility evidence.

## Move or restore a notebook

1. Open **Reader notebook** from any ordinary generated chapter and choose
   **Export notebook archive**. Save `reading-notebook.json` somewhere private.
   The archive includes unsaved text without changing the currently saved note.
2. Open the notebook in the destination book copy or browser. Choose the file
   under **Import notebook archive or edited Markdown**. Nothing is uploaded or imported yet.
3. Read the source book title and the counts of new, identical, conflicting and
   removed-chapter notes. Inspect each incoming note and uncheck any you do not
   want, or use **Clear note selection** and select only the wanted entries. All
   notes start selected. Notes match exact source paths, never just chapter
   titles. A title is context for the reader, not proof of book identity.
4. For each conflict, compare the current and imported text and choose **Keep
   current note** (the default) or **Use imported note**. Choose **Import selected notes**
   to merge. Unselected notes and notes absent from the archive are retained; repeated imports do not
   duplicate identical notes. **Cancel import** leaves saved and unsaved text
   unchanged and can also cancel a file that is still loading.
5. Revisit a chapter, continue editing, or export the merged notebook again.
   Paths missing from the current SUMMARY remain editable under **Removed
   chapter** in the chapter selector, without an invented source link. Rename
   migrations and fuzzy chapter matching are deliberately not inferred.

A changed draft or other-tab save/deletion while previewing refreshes the preview
and clears all incoming selections and resets conflict choices before applying
anything. Review, select the wanted notes again, then click Import selected notes. Browser storage still has no cross-tab transaction primitive;
use a single editing tab for a chapter when possible. A storage failure retains
the merged notes in this tab, displays a warning, and permits export. Unreadable
stored data is not overwritten.

Archives use UTF-8 JSON with `format: "moonbook.reader-notebook-archive"`,
`version: 1`, a `title`, and `notes: [[sourcePath, noteText], ...]`. They contain
personal note text and chapter paths, not source bodies, browser URLs or reviewed
knowledge. Keep archives private; they are plain text, not encrypted. Existing
Markdown exports remain reading briefs and now also support the bounded
external-editing workflow below. Older briefs without MoonBook identity comments
are not importable; export a fresh copy before editing.

Imports accept up to 5 MiB of UTF-8 data and 10,000 unique notes. Titles and paths
are limited to 4,096 UTF-16 code units; paths must be nonempty strings and note
text must be a string. Invalid JSON, unsupported versions, duplicate paths,
invalid records or an oversized file fail before changing notes. Archive export
uses the same limits and reports a problem rather than producing an archive it
cannot restore; Markdown export remains available. These limits also apply to
manually prepared archives. An empty archive adds nothing and deletes nothing.

Focused tests cover the exact archive Blob, a moved-URL import/edit/re-export,
selective conflicts, no-write preview/cancel, unrelated and unsaved notes,
repeated imports, changed-tab previews, malformed files, interrupted reads,
retained removed chapters, and storage denial/quota/unreadable records. They run
the exact script emitted by the native ordinary book renderer using Node DOM,
File, Blob and storage adapters. They do not qualify a particular web browser's
file chooser, storage permissions or download UI.

## Find a note

Use **Find your notes** above the editor to search full note text, chapter titles
and original source paths. Matching is case-insensitive and requires every
space-separated search word to appear somewhere in those fields. Results remain
in SUMMARY order, followed by removed chapters. Each result includes its path,
its saved/draft/tab-only state and an inert text excerpt near a matching word.
Use **Show notes** for saved notes, the current unsaved draft, or removed chapters.
**Clear search and filters** restores all notes. Chapters without note text do
not appear; use the chapter selector to start a new note.

Searching never saves, deletes or replaces your current draft. The draft replaces
its saved version in results, including when clearing it removes that note from
results. **Open note** edits the exact matching path and first keeps a different
chapter's draft, just like changing the chapter selector. Removed-chapter notes
stay editable without a fabricated chapter link. Saves, archive imports and
other-tab storage notifications refresh discovery. Another tab's update does not
replace an active draft; opening a result without an active draft reads the latest
stored note. A stale removed-note result reports when that note has disappeared.
No search text or note content leaves the browser, and discovery does not promote
reader commentary into reviewed knowledge.

R450 focused evidence: `node scripts/reader-notebook.test.mjs --source` runs the
production multiline JavaScript extracted from the MoonBit renderer sources,
with fixture metadata and minimal Node DOM/storage adapters. It covers discovery,
navigation, imports, drafts, removed paths, inert text, storage failures and other
tabs alongside existing notebook regressions. This mode does not run MoonBit,
validate generated HTML, or qualify a real browser, file picker or download UI.
The existing generated-HTML test mode remains available for a native build.

## Track reading and resume

Use **Reading progress** in the generated Reader notebook to mark the selected
chapter read or unread. **Next unread chapter** moves to the next unmarked
chapter in SUMMARY order, wrapping to the beginning. It preserves a different
chapter's note draft using the existing notebook save behavior; if the only
unread chapter is already selected, its draft stays unsaved and untouched.
The button is disabled when all current chapters are marked read. Unmark a
chapter to put it back into the reading queue.

**Read selected chapter** remembers that exact chapter as your reading position.
Marking a chapter or choosing Next unread also remembers the position. Opening,
resuming or selecting a chapter never marks it read automatically. On the next
notebook visit, that position is selected if its source path still exists.
**Resume reading** selects the remembered chapter after browsing other notes;
use Read selected chapter to navigate to its page. Reading progress is an
explicit reader annotation, not comprehension, factual review or accepted truth.

Progress uses a separate `moonbook.reader-progress.v1:` local-storage entry
scoped to the same book-output URL as notes. It does not change source files,
note text, note archives or the Markdown brief. Notebook archives transfer notes
only, not progress. A title change preserves progress; a removed path remains in
storage but is excluded from current chapter counts and cannot be resumed. A
new path starts unread. Replacing a different book at the same URL reuses that
URL's state, so use separate book directories. Progress is plain local data,
not encrypted or synchronized across browsers/devices.

Unrelated chapter updates merge before a progress save. Other-tab changes refresh
counts and the resume position without switching your editor or replacing its
draft. Same-chapter simultaneous choices and reading positions are last-save-wins;
localStorage is not a transaction store. Invalid, unknown-version or inaccessible
progress records are not overwritten. New progress then stays in the current tab,
with a visible warning and normal departure warning after changes; some browsers
suppress departure warnings. A note-storage failure and a progress-storage
failure are independent. Empty books and removed-note-only selections cannot
create fictitious reading links.

Progress accepts at most 10,000 unique paths, each at most 4,096 UTF-16 units.
R461 evidence: `node scripts/reader-notebook.test.mjs --source` passes 37 tests
(26 notebook regressions plus 11 reading-progress cases), executing the exact
JavaScript strings composed into the production renderer with fixture metadata
and minimal Node DOM/storage adapters. Generated HTML, MoonBit compilation,
real-browser navigation/storage, and graphical UI execution were not run in
this round. No dependencies or Moon commands were needed for this bounded lane.
This advances PRD MOONBOOK-UC01/B01's readable-book journey; it does not change
review/ingest integrity meanings or qualify the whole product.

## Edit notes in a text editor

1. In the ordinary **Reader notebook**, choose **Export Markdown notes**. As
   before, this saves a current draft first. Keep a JSON archive too when you
   need exact original line endings or a backup before editing.
2. Open `reading-notes.md` in a plain-text Markdown editor. Edit the quoted note
   lines starting with `> `. Add a new quoted line for each new paragraph line;
   a blank note line is `> ` (a bare `>` also works). Keep indentation and trailing
   spaces after the quote prefix when they are part of your note.
3. Keep the introductory notice, chapter structure, and the `moonbook` comments.
   The book comment carries its source title; each chapter comment carries its
   exact source path. Display headings and `Source:` labels are reading context,
   not import identity. Changing those display labels does not reassign a note.
4. Choose **Import notebook archive or edited Markdown** and select the edited
   `.md`. The preview identifies **Edited Markdown**, its source title, new and
   identical notes, conflicts, and paths missing from this book. Nothing is saved
   yet. Inspect every incoming section and uncheck any you do not want. Review
   each selected conflicting current/imported pair and choose **Use imported
   note** only for changes you want. **Keep current note** is the default.
5. Choose **Import selected notes**, revisit the affected chapter, and continue editing
   or export again. **Cancel import** leaves saved notes and drafts untouched.

For example, the note part of a current export looks like this:

```markdown
## Introduction

Source: intro.md

<!-- moonbook.note.v1 {"path":"intro.md"} -->
> A question to revisit after reading.
>
> Add the answer here in your editor.
<!-- /moonbook.note -->
```

Use the complete exported file, including its book comment and introductory
notice. This excerpt alone is not a complete import. Comments use JSON strings;
HTML-sensitive metadata characters are escaped. Do not change the path comments
unless you intentionally want to target another exact chapter path. MoonBook does
not infer a rename from matching titles, validate that two books are identical,
or automatically rebind notes. Missing paths remain editable removed-chapter
notes with no invented link.

The format preserves supported note text including Unicode, indentation,
Markdown-like syntax, blank lines and trailing newlines. It is deliberately a
plain-text exchange, not a general Markdown parser. Notes are encoded as quoted
lines with `&`, `<`, and `>` escaped; import decodes `&amp;`, `&lt;`, and `&gt;`
once. A literal `&lt;` in note text therefore appears as `&amp;lt;` in the exported
file. Edit that escaped form when you want a literal entity name. Note lines
containing headings or MoonBook comment text stay ordinary note text after the
quote prefix. No imported Markdown, HTML, links or scripts are rendered/executed.

LF note text round-trips exactly. CRLF and bare CR line endings normalize to LF;
JSON archives retain original note line endings. A UTF-8 BOM and text-editor
CRLF files are supported. Rich-text export, arbitrary Markdown documents,
unquoted paragraphs, rewritten/deleted identity comments, and older unmarked
MoonBook briefs are unsupported. Structural errors report a line to repair;
invalid/duplicate paths or an invalid title fail the whole import. A malformed
later section does not partially import earlier sections.

Deleting a complete chapter section from the file excludes it from this import;
it does not delete the corresponding browser note. An empty quoted block imports
an empty value only when selected; to remove a stored note, clear it in the
notebook and save. Unrelated saved notes and current drafts remain in the merge.
If a draft or another tab changes during preview, the preview refreshes and
replacement choices reset before any import write. The ordinary storage-failure
and concurrent same-chapter-save limitations still apply. Reading progress is
not part of this file and stays unchanged.

The existing import limits apply: 5 MiB UTF-8, 10,000 unique notes, and 4,096
UTF-16 units per title/path. A larger Markdown brief can still be exported for
reading, but cannot be imported without reducing it to that scope. Notes stay
reader commentary; this workflow never writes book sources, wiki pages,
accepted claims, or review events. The file contains private note text and paths,
so review its scope before sharing or opening it in a cloud editor.

R476 focused evidence: `node scripts/reader-notebook.test.mjs --source` passes
43 tests (37 prior cases plus six external-editing workflows), executing the
actual production JavaScript strings with Node DOM/storage/file adapters. This
includes export, external text changes, no-write preview, selective conflict
acceptance, reload, re-export, exact Unicode paths, removed chapters, concurrent
edits, damaged-file repair and tab-only recovery. No MoonBit build, generated
HTML emission, real browser/editor/file picker, or full-product qualification
was run. This closes a bounded external-edit loop in PRD MOONBOOK-UC01/B01's
readable-book workflow without changing factual-review semantics.

## Move reading progress to another browser or book copy

The notebook now has **Move or restore reading progress**, separate from the
note archive/import controls. This closes the readable-book journey's missing
transfer of explicit read marks and resume position (PRD MOONBOOK-UC01/B01).

1. In the source notebook, choose **Export reading progress** and keep the
   downloaded `reading-progress.json`. This includes the latest read marks and
   remembered position. It does not save or include a note draft. Export a
   notebook archive separately when moving notes too.
2. Open the destination copy's **Reader notebook**, choose **Import reading
   progress**, and select that JSON file. Nothing is uploaded or written yet.
3. Inspect the source title and each exact source path. The preview distinguishes
   new read marks, existing read marks, and removed/unknown paths. Verify this is
   the intended book: a title is context, not an identity guarantee. Matching
   chapter titles or different case never imply matching source paths.
4. Optionally check **Use imported reading position**. This is off by default,
   and available only when that exact position exists in the current book.
5. Choose **Import read marks**. Read marks merge with existing marks; absent
   paths are never made unread. The editor, draft and selected chapter stay
   unchanged. Choose **Resume reading** when ready to visit the chosen position.
   **Cancel progress import** preserves everything and also cancels a file still
   being read. Repeated imports do not duplicate read marks.

Removed/unknown paths are retained as annotations and re-exported. They do not
count as current chapters or generate invented links. Renames are not inferred.
A removed imported position is shown but cannot replace the destination's
position. When a chapter returns under its exact path, its retained read mark
counts again. To deliberately mark a chapter unread, use the ordinary reading
progress button after importing; an archive is a merge, not an exact replacement
or a deletion synchronization protocol.

Changes to progress in this or another tab while reviewing cause the preview to
refresh and clear the optional position choice before any import write. Review
again and apply. Another tab's unrelated marks merge first, but localStorage
has no cross-tab transaction; simultaneous saves can still race. Use one editing
tab when possible. A storage denial, quota error or unreadable stored record
keeps imported progress in this tab with a warning. Existing unreadable data is
not overwritten. Export progress before closing the tab; the existing departure
warning may be suppressed by the browser. An unreadable original record cannot
be recovered through this workflow; exports then contain only usable tab state.

The UTF-8 JSON format is `format: "moonbook.reader-progress-archive"`,
`version: 1`, a source `title`, `read: [sourcePath, ...]`, and `last: sourcePath`
(or an empty string). Files are limited to 5 MiB; the imported and merged state
are limited to 10,000 unique nonempty read paths. Titles and paths are limited
to 4,096 UTF-16 code units. Invalid or over-limit files fail before importing
any marks. Oversized merged state is rejected unchanged. Export uses the same
validation and size limit. Progress archives contain chapter paths and reading
activity, not source bodies, notes, browser URLs or reviewed knowledge. They
are unencrypted private files; inspect their scope before sharing.

R490 focused evidence: `node scripts/reader-notebook.test.mjs --source` passes
54 cases: 43 existing notebook/progress/external-editing regressions plus 11
portable-progress cases. Tests execute the actual composed production script
with Node DOM/storage/file/Blob adapters and fixture metadata. They cover two
ordinary notebook sessions, an exported archive imported at a moved URL, reload,
re-export, additive/idempotent merge, default/optional position, draft and stored
note isolation, preview/cancel, interrupted reads, changed-tab review, unknown
paths, empty books and tab-only export recovery. Source checks verify the new
controls and script are composed into the real notebook renderer. This does not
execute MoonBit, emit native-generated HTML, exercise an actual browser's file
picker/storage/download UI, or qualify full-product/native compatibility. No
network, dependencies or Moon commands were used. Reader progress is a personal
annotation and does not establish comprehension, factual review or book truth.

## Recover notes after a chapter rename

A rebuild can replace a chapter's source path while its reader note remains
under **Removed chapter**. In **Recover a removed-chapter note**, you can now
copy that note to a current chapter, or append it to an existing note, without
editing an archive by hand. This is a manual reader annotation workflow for
PRD MOONBOOK-UC01/B01's maintained readable book. It does not establish that two
chapters are the same, rename a book file, or change accepted knowledge.

1. Choose **Removed chapter note** by its exact old source path. Only nonempty
   notes outside the current SUMMARY are listed. Save/export a notebook archive
   first if you want a portable backup, especially before replacing a note.
2. Choose **Current destination chapter**. Its title and exact path are both
   shown. No source or destination is selected automatically, even when titles
   match. An empty book has no destination until chapters are added and rebuilt.
3. Choose **Preview note recovery**. Inspect the full original note, full current
   destination note, and both paths. The current unsaved draft is included when
   it belongs to either of those paths. Preview and **Cancel recovery** make no
   storage writes and leave notes, drafts, selection and progress unchanged.
4. Choose **Copy original into empty destination**, or, for a nonempty
   destination, **Append original after current note** / **Replace current note
   with original**. No choice is preselected. Append retains the current text,
   then two LF newline characters, then the complete original. Replace discards
   the destination text only when you explicitly save that choice. Review the
   exact **Resulting destination note** before continuing.
5. Choose **Save recovered note**. Only the destination note is saved. The old
   removed-chapter note is retained, and the chapter selection stays where it
   was. If the destination is selected, its editor shows the saved result; if a
   different note is selected, its draft stays unsaved and unchanged. A source
   draft copied to the destination also remains unsaved at its original path.
6. Select the destination chapter to continue editing, reopen the notebook, or
   export an archive / Markdown brief. Both original and recovered notes remain
   available. A second click on the completed action does nothing. Starting a
   new append deliberately again appends again; this is not synchronization or
   an automatic deduplication/rename mapping.

Changing either selected path cancels the old preview. If any note or draft
changes while reviewing, **Save recovered note** refreshes the comparison and
clears its recovery choice before writing. Choose again after reviewing the new
text. If another tab deletes the original, the stale preview cannot restore it.
Unrelated stored notes are retained. As with other notebook operations, browser
localStorage has no cross-tab transaction, so simultaneous saves can still race;
prefer one editing tab.

Recovery does not move read marks, resume position, source text, chapter links
or factual-review status. Exact paths are user-chosen identifiers; there is no
fuzzy matching, title inference, or automatic migration. Notes and path labels
are displayed as inert plain text. The ordinary notebook archive format remains
version 1 and its existing export/import limits still apply. Reading-progress
transfer remains separate.

On unavailable, unreadable or quota-limited storage, recovery stays in the tab
and displays an export warning; unreadable stored bytes are not overwritten.
Export a notebook archive before closing the tab. The browser can suppress the
normal departure warning, and an export request does not prove the file was
saved. These personal notes are unencrypted browser data and exported plain
text; review their contents before sharing.

R509 focused evidence: `node scripts/reader-notebook.test.mjs --source` passes
64 cases, comprising 54 notebook regressions plus 10 recovery/composition cases.
The production composed JavaScript runs with Node DOM/storage/file/Blob adapters
and SUMMARY metadata fixtures. The new workflow exercises no-write preview and
cancel, manual exact-path copy, append/replacement, reload, continued editing,
archive/Markdown export, both draft roles, unchanged progress, changed notes,
removed originals and tab-only recovery. Set `MOONBOOK_RECOVERY_EVIDENCE` to an
existing directory to retain the actual synthetic recovered archive and brief.
No MoonBit build, generated HTML emission, graphical browser, file chooser,
keyboard/accessibility, or native/full-product qualification was run. No
network, dependencies, provider or Moon invocation was needed for this lane.


## Restore only selected notes

An archive or externally edited Markdown brief can contain useful research next
to old or irrelevant notes. Previously all new paths were imported together;
only conflicts offered a keep/replace choice. The existing notebook importer now
lets you inspect and choose individual incoming notes before restoring them.
You do not need to edit the archive JSON or delete unwanted notes afterward.

1. Choose **Import notebook archive or edited Markdown**. Inspect the source
   title, exact paths, full incoming note text, and new/identical/conflicting
   classification. Each entry also shows its current chapter title or **Removed
   chapter**. Incoming text is inert, including HTML-like text and path names.
2. Notes are initially selected for an ordinary full restore. Uncheck **Include
   incoming note for …** on unwanted entries. For a small subset, choose **Clear
   note selection** and then check only the wanted paths. **Select all incoming
   notes** restores the full selection. The selected count updates without saving
   anything. The import button is disabled when no entry is selected.
3. For selected conflicts, separately choose **Use imported note** in the
   current/imported comparison when you want replacement. **Keep current note**
   remains the default. An unchecked conflict is skipped even if its replacement
   menu still says Use imported note. Identical entries do not cause a write.
4. Choose **Import selected notes**. Only selected new notes and explicitly
   selected replacements are saved. Other saved notes, drafts, selected chapter,
   read marks and resume position stay unchanged. A kept-current or skipped
   draft stays unsaved, including a draft that clears a previously saved note.
   Use **Save note** separately when you want to save that draft.
5. Reopen the notebook or select an imported path to continue editing. Selected
   missing paths remain editable removed-chapter notes, without invented source
   links. The normal notebook archive and Markdown exports include the resulting
   notebook; these original buttons still export the whole notebook. For a focused output, use the separate [selected-note export](SELECTED_NOTE_EXPORT.md).

For example, when restoring `intro.md`, `nested/README.md` and `retired.md`,
clear the selection and include only `nested/README.md`. The other incoming
notes are not imported; an existing introduction note and its unsaved editor
text are retained. The chosen note can be edited, saved, reopened and exported
normally. Matching remains exact-path based; no title matching, chapter rename,
source-content import or book-identity verification is performed.

Preview, all/none, checkbox changes and cancellation do not write notes. If
notes or drafts change while the preview is open, applying refreshes the full
comparison, clears every inclusion checkbox and resets conflicts to Keep
current. Select the desired entries again after reviewing. The previous
selection is not silently reapplied. A completed import clears its preview;
another click does nothing. Starting a new import starts a fresh selection.
An empty file selection, cancelled load or invalid file does not import a
partial subset. Existing archive/Markdown format and file limits are unchanged;
selection happens after the whole file validates, not as a workaround for an
invalid or oversized file.

Storage failure retains only the chosen imported changes in tab state, plus
existing usable notes and the current draft. The existing warning and export
recovery still apply; unreadable stored bytes are not overwritten. No selection
can recover unreadable notes. localStorage is not transactional, and simultaneous
tab saves can still race. Prefer one editing tab. No data is uploaded and no
book source, accepted claim, reviewer status or reading-progress record changes.

R531 focused evidence: `node scripts/reader-notebook.test.mjs --source` passes
74 cases (64 preceding notebook cases, including two updated to explicitly
reselect after changed-state review, and 10 selective-import cases). It executes
the actual composed production JavaScript with fixture SUMMARY metadata and
Node DOM/storage/file/Blob adapters. Evidence includes archive transfer between
book URLs, full incoming preview, subset restore, saved/draft isolation, reload,
continued editing, selective Markdown import, exact removed-path editing,
no-write selection/cancel, changed-state reselection, tab-only recovery and
actual archive/Markdown download bytes. Set `MOONBOOK_SELECTION_EVIDENCE` to an
existing directory to retain the synthetic input and restored exports.

No MoonBit compilation, native-generated HTML, real-browser file chooser,
keyboard/accessibility, navigation/download UI, or full-product execution was
run in this round. No dependencies, network or Moon commands were needed.
This advances PRD MOONBOOK-UC01/B01's maintained readable-book workflow; personal
reader-note restoration does not complete MOONBOOK-N03's raw-source/accepted-
knowledge/review-event backup gate or MOONBOOK-N04's knowledge-access boundaries.

## Export only the notes you need

Use **Export selected notes** to review full note text and download just the
checked exact paths as a compatible JSON archive or editable Markdown brief.
This never saves drafts, and changed text requires renewed selection. See the
[selected-note export guide](SELECTED_NOTE_EXPORT.md) for steps, formats, limits
and focused verification. Keep a separate full archive for complete backup.
