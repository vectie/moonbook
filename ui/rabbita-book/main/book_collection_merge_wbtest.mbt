///|
fn merge_fixture() -> (BookCollectionState, BookCollectionArchive) {
  let current = refresh_fixture().collection
  let first = current.items[0]
  let incoming = {
    ..first,
    note: "Incoming note: ask about the twelve-team plan. <script>inert</script>",
    page: {
      ..first.page,
      content: "Incoming capacity: twelve teams.",
      retained_source: Some({
        reference: "raw/incoming.txt",
        page_digest: "b".repeat(64),
      }),
    },
  }
  let extra = {
    ..first,
    title: "Incoming decision",
    note: "Keep this new note.",
    page: {
      ..first.page,
      citation: "wiki/sources/decision.md",
      content: "New decision evidence.",
    },
  }
  let current = {
    ..current,
    title: "Current research",
    purpose: "Keep my question and synthesis.",
    history: [{ ..first, note: "Earlier current history", }],
  }
  let archive : BookCollectionArchive = {
    schema: "moonbook.research-collection.v2",
    title: "Incoming research",
    purpose: "Incoming synthesis must be visible.",
    items: [incoming, extra],
    history: [{ ..first, note: "Earlier incoming history", }],
  }
  (current, archive)
}

///|
fn merge_ready(
  current : BookCollectionState,
  archive : BookCollectionArchive,
  imported : Bool,
) -> BookCollectionState {
  let draft = book_collection_reduce(
      current,
      ArchiveDraft(archive.to_json().stringify()),
    ).0
  book_collection_reduce(
    draft,
    MergeChoice(
      draft.revision,
      draft.import_request,
      archive.items[0].page.citation,
      imported,
    ),
  ).0
}

///|
fn merge_apply(state : BookCollectionState) -> BookCollectionState {
  book_collection_reduce(
    state,
    ApplyMerge(state.revision, state.import_request),
  ).0
}

///|
test "combine saved sessions preserves order both notes histories and explicit collision choices" {
  let (current, archive) = merge_fixture()
  for imported in [false, true] {
    let ready = merge_ready(current, archive, imported)
    let merged = merge_apply(ready)
    assert_eq(merged.title, current.title)
    assert_eq(merged.purpose, current.purpose)
    assert_eq(merged.items.length(), 3)
    assert_eq(
      merged.items[0],
      if imported {
        archive.items[0]
      } else {
        current.items[0]
      },
    )
    assert_eq(merged.items[1], current.items[1])
    assert_eq(merged.items[2], archive.items[1])
    assert_eq(
      merged.history,
      current.history +
      archive.history +
      [if imported { current.items[0] } else { archive.items[0] }],
    )
    assert_eq(merged.revision, current.revision + 1)
    assert_true(merged.import_text.is_empty())
    assert_true(
      book_collection_reduce(
        ready,
        ApplyMerge(ready.revision, ready.import_request),
      ).1.is_empty(),
    )
    let roundtrip = book_collection_decode_archive(
      book_collection_archive(merged),
    ).unwrap()
    assert_eq(roundtrip.items, merged.items)
    assert_eq(roundtrip.history, merged.history)
    let edited = book_collection_reduce(
        merged,
        Note(merged.items[2].page.citation, "Edited after combine"),
      ).0
    let reordered = book_collection_reduce(
        edited,
        Move(merged.items[2].page.citation, -1),
      ).0
    assert_eq(reordered.items[1].note, "Edited after combine")
    let removed = book_collection_reduce(
        reordered,
        Remove(merged.items[0].page.citation),
      ).0
    assert_eq(removed.history, merged.history)
  }
}

///|
test "combine requires all collision choices and treats different notes as a conflict" {
  let (current, archive) = merge_fixture()
  let draft = book_collection_reduce(
      current,
      ArchiveDraft(archive.to_json().stringify()),
    ).0
  let unchanged = merge_apply(draft)
  assert_eq(unchanged.items, current.items)
  assert_eq(unchanged.history, current.history)
  assert_eq(unchanged.revision, current.revision)
  let notes_only = {
    ..archive,
    items: [{ ..current.items[0], note: "A second researcher's note", }],
    history: [],
  }
  let draft = book_collection_reduce(
      current,
      ArchiveDraft(notes_only.to_json().stringify()),
    ).0
  assert_eq(merge_apply(draft).items, current.items)
  let merged = merge_apply(merge_ready(current, notes_only, false))
  assert_eq(merged.history.last().unwrap().note, "A second researcher's note")
  let identical = { ..archive, items: current.items, history: [], }
  let draft = book_collection_reduce(
      current,
      ArchiveDraft(identical.to_json().stringify()),
    ).0
  let merged = merge_apply(draft)
  assert_eq(merged.items, current.items)
  assert_eq(merged.history, current.history)
  let multi = {
    ..archive,
    items: [archive.items[0], { ..current.items[1], note: "Another conflict", }],
  }
  let ready = merge_ready(current, multi, true)
  assert_eq(merge_apply(ready).items, current.items)
  let ready = book_collection_reduce(
      ready,
      MergeChoice(
        ready.revision,
        ready.import_request,
        current.items[1].page.citation,
        false,
      ),
    ).0
  assert_eq(merge_apply(ready).history.length(), 4)
}

///|
test "combine old previews edits cancelled choices changed input and replay never mutate current work" {
  let (current, archive) = merge_fixture()
  let ready = merge_ready(current, archive, true)
  let old_apply = ApplyMerge(ready.revision, ready.import_request)
  let old_choice = MergeChoice(
    ready.revision,
    ready.import_request,
    current.items[0].page.citation,
    true,
  )
  for
    action in [
      Title("Edited title"),
      Purpose("New synthesis"),
      Note(current.items[0].page.citation, "New note"),
      Move(current.items[0].page.citation, 1),
      Remove(current.items[0].page.citation),
      CancelMerge,
      ArchiveDraft("{}"),
      OpenArchive,
      ResumeArchive,
    ] {
    let changed = book_collection_reduce(ready, action).0
    let replay = book_collection_reduce(changed, old_apply).0
    assert_eq(replay.items, changed.items)
    assert_eq(replay.history, changed.history)
    assert_eq(replay.revision, changed.revision)
    let replay_choice = book_collection_reduce(changed, old_choice).0
    assert_eq(replay_choice.merge_plan, changed.merge_plan)
  }
  let merged = merge_apply(ready)
  assert_eq(book_collection_reduce(merged, old_apply).0.history, merged.history)
  let edited = book_collection_reduce(
      ready,
      Note(current.items[0].page.citation, "Edited after preview"),
    ).0
  assert_eq(merge_apply(edited).history, current.history)
  let cancel = book_collection_reduce(ready, CancelMerge).0
  assert_eq(merge_apply(cancel).history, current.history)
  let late = book_collection_reduce(
      cancel,
      ArchiveRead(ready.import_request, Ok(archive.to_json().stringify())),
    ).0
  assert_eq(late.import_request, cancel.import_request)
}

///|
test "combine limits are all or nothing and v1 archives append with empty history" {
  let (current, archive) = merge_fixture()
  let many = Array::makei(12, i => {
    ..current.items[0],
    page: { ..current.items[0].page, citation: "page-" + i.to_string(), },
  })
  let full = { ..current, items: many, }
  let draft = book_collection_reduce(
      full,
      ArchiveDraft(archive.to_json().stringify()),
    ).0
  assert_eq(merge_apply(draft).items, full.items)
  let full_history = { ..current, history: Array::make(48, current.items[0]), }
  let ready = merge_ready(full_history, archive, true)
  assert_eq(merge_apply(ready).history, full_history.history)
  assert_eq(merge_apply(ready).items, full_history.items)
  let large = {
    ..current,
    items: [
      {
        ..current.items[0],
        page: { ..current.items[0].page, content: "x".repeat(1_048_500), },
      },
    ],
    history: [],
  }
  let ready = merge_ready(large, archive, true)
  assert_eq(merge_apply(ready).items, large.items)
  assert_eq(merge_apply(ready).history, large.history)
  let legacy : Json = {
    "schema": "moonbook.research-collection.v1",
    "title": "Legacy",
    "purpose": "",
    "items": [archive.items[1]].to_json(),
  }
  let draft = book_collection_reduce(current, ArchiveDraft(legacy.stringify())).0
  let merged = merge_apply(draft)
  assert_eq(merged.items, current.items + [archive.items[1]])
  assert_eq(merged.history, current.history)
}

///|
extern "js" fn merge_write_evidence(
  current : String,
  incoming : String,
  combined : String,
  brief : String,
  html : String,
) -> @js.Promise =
  #| async (current,incoming,combined,brief,html)=>{const root=process.env.MOONBOOK_MERGE_EVIDENCE;if(!root)return false;const fs=await import("node:fs/promises");for(const [name,data] of Object.entries({"current-session.json":current,"incoming-session.json":incoming,"combined-session.json":combined,"combined-brief.md":brief,"combination-preview.html":html}))await fs.writeFile(root+"/"+name,data);return true;}

///|
test "combine production file reader JSON Blob escaped preview and edited Markdown Blob" {
  book_test_async(async fn() {
    let (current, archive) = merge_fixture()
    let incoming = archive.to_json().stringify(indent=2)
    archive_file_capture_start(incoming)
    let opened : String = book_collection_archive_open().wait().cast()
    archive_file_capture_finish()
    let opening = book_collection_reduce(current, OpenArchive).0
    let draft = book_collection_reduce(
        opening,
        ArchiveRead(opening.import_request, Ok(opened)),
      ).0
    assert_eq(draft.items, current.items)
    let ready = book_collection_reduce(
        draft,
        MergeChoice(
          draft.revision,
          draft.import_request,
          current.items[0].page.citation,
          true,
        ),
      ).0
    let html = search_test_html({ ..book_search_initial(), collection: ready, })
    assert_true(html.contains("Incoming synthesis must be visible."))
    assert_true(html.contains("Use incoming active"))
    assert_true(html.contains("&lt;script&gt;inert&lt;/script&gt;"))
    assert_false(html.contains("<script>inert</script>"))
    let merged = merge_apply(ready)
    let edited = book_collection_reduce(
        merged,
        Note(
          merged.items[2].page.citation,
          "Edited after combining both reading sessions.",
        ),
      ).0
    guard book_collection_reduce(edited, DownloadArchive).1
      is [ExportArchive(_, json)] else {
      fail("archive effect missing")
    }
    let capture = search_export_capture_start()
    let _ : String = book_collection_archive_download(json).wait().cast()
    let captured : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(captured)
      is {
        "download": String(downloaded),
        "filename": "moonbook-research-collection.json",
        "clicked": true,
        ..
      } else {
      fail("JSON Blob missing")
    }
    assert_eq(downloaded, json)
    archive_file_capture_start(downloaded)
    let reopened : String = book_collection_archive_open().wait().cast()
    archive_file_capture_finish()
    let resumed = book_collection_reduce(
        book_collection_reduce(
          book_collection_initial(),
          ArchiveDraft(reopened),
        ).0,
        ResumeArchive,
      ).0
    assert_eq(resumed.items, edited.items)
    assert_eq(resumed.history, edited.history)
    guard book_collection_reduce(resumed, DownloadBrief).1
      is [ExportCollection(_, brief, true)] else {
      fail("brief effect missing")
    }
    let capture = search_export_capture_start()
    let _ : String = book_collection_export(brief, true).wait().cast()
    let captured : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(captured)
      is { "download": String(downloaded_brief), "clicked": true, .. } else {
      fail("Markdown Blob missing")
    }
    assert_eq(downloaded_brief, brief)
    assert_true(brief.contains("Incoming capacity: twelve teams."))
    assert_true(brief.contains("Edited after combining both reading sessions."))
    assert_true(
      brief.contains(
        "Historical snapshots retained in the resumable JSON archive: 3",
      ),
    )
    let _ : Bool = merge_write_evidence(
        book_collection_archive(current),
        incoming,
        downloaded,
        downloaded_brief,
        html,
      )
      .wait()
      .cast()
  })
}
