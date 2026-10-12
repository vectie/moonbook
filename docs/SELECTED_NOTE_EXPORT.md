# Export a focused reader-note brief

The ordinary **Reader notebook** now lets you export only the notes needed for
a particular reading task, external edit, or transfer. Previously its JSON and
Markdown exports included the whole notebook. This completes a distinct output
step in PRD MOONBOOK-UC01/B01's maintained readable-book workflow; subset import
alone cannot prevent unrelated notes from entering an exported file.

## Use it

1. Open **Reader notebook** from an ordinary generated book's sidebar. Write or
   restore your notes normally. Scroll to **Export selected notes** and choose
   **Choose notes for export**.
2. Inspect every candidate's exact source path, chapter title, saved/draft/tab-only
   label and complete note text. No note is initially checked. Check **Include in
   export** on just the wanted notes, or use **Select all export notes** and uncheck
   unwanted entries. **Clear export selection** unchecks everything.
3. Choose **Download selected Markdown** for `selected-reading-notes.md`, or
   **Download selected archive** for `selected-reading-notebook.json`. Both
   buttons are disabled with no selection. Both formats can be downloaded from
   the same stable review. The message confirms a download request, not that a
   browser or user actually saved the file.
4. Read the resulting brief, edit the Markdown's quoted note lines, or use the
   ordinary **Import notebook archive or edited Markdown** in a destination
   notebook. Review the incoming notes and choose **Import selected notes**.
   Existing conflict handling still applies. You can reopen, edit and save the
   imported notes, then export again using either notebook export workflow.

For example, check only `nested/README.md` to transfer that chapter's research
notes without including a separate private introduction note. There is no need
to delete notes temporarily or manually remove JSON records. Candidates appear
in SUMMARY order, then removed paths in their stored order. Selection clicks do
not determine output order. The export review includes all nonempty notes,
independently of **Find your notes** search/filter settings. Clear a note's text
in the current editor and that draft deletion excludes its earlier saved text
from the review.

**Cancel selected export** discards only export choices. Reopening the review
starts with no selections. Search, notes, the selected chapter, reading marks,
resume position, pending import/recovery controls and storage are not written by
this workflow. A current unsaved note appears in the review and can be exported
without being saved. Unlike the original whole-notebook Markdown button, these
selected downloads never save the current draft. Continue to save separately
when you want that draft in this browser after closing the tab.

## Changed notes and recovery

Immediately before either download, the notebook compares its current effective
notes (latest readable storage plus the active draft) with the reviewed snapshot.
Any change, including an unrelated new note or another tab's deletion, refreshes
the complete review and clears every checkbox without downloading a file. Review
and select again. This prevents a changed note from silently entering the brief.
The review is not live synchronization: text may remain visibly old until you
reopen it or attempt a download. Saved/draft labels describe the review moment;
text equality, not a save timestamp, determines whether a new review is needed.

A selected archive contains only selected reader-note text, exact source paths,
the book title, and existing format/version fields. A Markdown brief also adds
selected chapter titles and the reader-commentary notice. Removed chapters remain
explicitly labeled and import as editable removed-chapter notes; there is no
invented link or automatic rename mapping. Neither format includes chapter
bodies, browser URLs, reading progress or unrelated note entries. A chosen note
itself may mention other private information or paths. Selection is not redaction
or permission to share, and the files are unencrypted. Inspect before sharing.

JSON uses the existing `moonbook.reader-notebook-archive` version 1 and preserves
exact text including CRLF. Markdown uses the existing bounded editable-notes
format, normalizes line endings to LF, and renders note lines as escaped reader
commentary. Keep the MoonBook comments, headings and notice when editing it.
Both formats are checked through the existing import validators before download:
5 MiB maximum UTF-8 file size, 10,000 selected notes, and 4,096 UTF-16 code units
per title/path. JSON encoding or Markdown escaping can increase size. Choose a
smaller subset when a file exceeds the limit. Validation covers only the chosen
scope; an oversized unselected note does not block a small focused brief.

When storage is denied, unreadable or quota-limited, the usable tab-only notes
and current draft can still be selected and exported. Unreadable stored bytes
are never overwritten or recovered by this operation. Keep the tab open until
saving the download yourself. This focused export is not a complete backup;
keep a separate whole-notebook archive for restoration of all notes.

## Focused verification and limits

Run from the repository root:

```sh
node scripts/reader-notebook.test.mjs --source
```

R551 passes 84 cases: 74 existing notebook regressions plus 10 selected-export
cases. The tests execute the actual composed production JavaScript from the
MoonBit renderer using fixture SUMMARY metadata and Node DOM/storage/file/Blob
adapters. They cover full review, no default selection, exact selected scope,
Unicode and original line endings, moved-book restore and further editing,
editable Markdown interoperability, stale drafts/other-tab changes, cancel,
removed chapters, cleared drafts, tab-only recovery, size-error narrowing, and
production control/script composition. Set `MOONBOOK_SELECTED_EXPORT_EVIDENCE`
to an existing directory to retain synthetic JSON and Markdown download bytes.

No MoonBit compilation, generated HTML emission, graphical browser, keyboard or
accessibility execution, file chooser/download UI, or full-product/native
qualification was run. No dependencies, registry access, Moon commands or
network were needed. Personal reader commentary does not establish factual
review or accepted book truth. This does not qualify MOONBOOK-N03's raw-source,
accepted-knowledge and review-event backup, or MOONBOOK-N04 access boundaries.
