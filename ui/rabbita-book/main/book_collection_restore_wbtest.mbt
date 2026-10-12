///|
fn restore_fixture() -> BookCollectionState {
  let state = refresh_fixture()
  let refreshed = book_search_reduce(state, refresh_message(state)).0.collection
  book_collection_reduce(
    refreshed,
    Note(refreshed.items[0].page.citation, "New note for the twelve-team plan."),
  ).0
}

///|
test "restore exact historical envelope and note while retaining displaced selection" {
  let before = restore_fixture()
  let historical = before.history[0]
  let action = RestoreHistory(before.revision, 0)
  let (restored, effects) = book_collection_reduce(before, action)
  assert_true(effects.is_empty())
  assert_eq(restored.items, [historical, before.items[1]])
  assert_eq(restored.history, [before.items[0]])
  assert_eq(restored.title, before.title)
  assert_eq(restored.purpose, before.purpose)
  assert_eq(restored.revision, before.revision + 1)
  assert_eq(before.history, [historical])
  assert_eq(book_collection_reduce(restored, action).0.items, restored.items)
  assert_eq(
    book_collection_reduce(restored, action).0.history,
    restored.history,
  )
  let undone = book_collection_reduce(
      restored,
      RestoreHistory(restored.revision, 0),
    ).0
  assert_eq(undone.items, before.items)
  assert_eq(undone.history, before.history)
}

///|
test "restore removed citation appends and preserves other history including identical duplicates" {
  let before = restore_fixture()
  let historical = before.history[0]
  let removed = book_collection_reduce(before, Remove(historical.page.citation)).0
  let removed = {
    ..removed,
    history: [historical, historical, before.items[0]],
  }
  let restored = book_collection_reduce(
      removed,
      RestoreHistory(removed.revision, 1),
    ).0
  assert_eq(restored.items, removed.items + [historical])
  assert_eq(restored.history, [historical, before.items[0]])
  let same = { ..restored, history: [historical], }
  let swapped = book_collection_reduce(same, RestoreHistory(same.revision, 0)).0
  assert_eq(swapped.items, same.items)
  assert_eq(swapped.history, same.history)
  assert_eq(swapped.revision, same.revision + 1)
}

///|
test "restore boundaries allow full history and budget swaps but reject missing citation when full" {
  let before = restore_fixture()
  let historical = before.history[0]
  let full = {
    ..before,
    items: Array::makei(12, i => {
      ..before.items[0],
      page: { ..before.items[0].page, citation: "page-" + i.to_string(), },
    }),
  }
  let blocked = book_collection_reduce(full, RestoreHistory(full.revision, 0)).0
  assert_eq(blocked.items, full.items)
  assert_eq(blocked.history, full.history)
  assert_eq(blocked.revision, full.revision)
  assert_true(blocked.notice.unwrap().contains("all 12"))
  let full = {
    ..full,
    history: Array::make(48, {
      ..historical,
      page: { ..historical.page, citation: "page-5", content: "", },
    }),
  }
  let full = {
    ..full,
    items: full.items.map(item => {
      ..item,
      page: {
        ..item.page,
        content: if item.page.citation == "page-5" {
          "x".repeat(1048576)
        } else {
          ""
        },
      },
    }),
  }
  let restored = book_collection_reduce(full, RestoreHistory(full.revision, 47)).0
  assert_eq(restored.items.length(), 12)
  assert_eq(restored.history.length(), 48)
  assert_eq(restored.items[5], full.history[47])
  assert_eq(restored.history[47], full.items[5])
  assert_eq(
    book_collection_decode_archive(book_collection_archive(restored)).unwrap().history,
    restored.history,
  )
  for index in [-1, 48, 999] {
    let invalid = book_collection_reduce(
        full,
        RestoreHistory(full.revision, index),
      ).0
    assert_eq(invalid.items, full.items)
    assert_eq(invalid.history, full.history)
    assert_eq(invalid.revision, full.revision)
  }
}

///|
test "restore stale render cannot override edits resume merge refresh or prior restore" {
  let before = restore_fixture()
  let action = RestoreHistory(before.revision, 0)
  for
    edit in [
      Title("Changed"),
      Purpose("Changed"),
      Note(before.items[0].page.citation, "Edited"),
      Move(before.items[0].page.citation, 1),
      Remove(before.items[0].page.citation),
      action,
    ] {
    let changed = book_collection_reduce(before, edit).0
    let stale = book_collection_reduce(changed, action).0
    assert_eq(stale.items, changed.items)
    assert_eq(stale.history, changed.history)
    assert_eq(stale.revision, changed.revision)
  }
  let draft = book_collection_reduce(
      before,
      ArchiveDraft(book_collection_archive(before)),
    ).0
  let resumed = book_collection_reduce(draft, ResumeArchive).0
  assert_eq(book_collection_reduce(resumed, action).0.history, resumed.history)
  let (_, archive) = merge_fixture()
  let ready = merge_ready(before, archive, true)
  let restored = book_collection_reduce(ready, action).0
  assert_true(restored.merge_plan is None)
  assert_eq(merge_apply(restored).items, restored.items)
  let merged = merge_apply(ready)
  assert_eq(book_collection_reduce(merged, action).0.history, merged.history)
  let search = refresh_fixture()
  let restored = book_collection_reduce(before, action).0
  let search = { ..search, collection: restored, }
  let stale_restore = RestoreHistory(restored.revision, 0)
  let refreshed = book_search_reduce(search, refresh_message(search)).0.collection
  assert_eq(
    book_collection_reduce(refreshed, stale_restore).0.items,
    refreshed.items,
  )
  assert_eq(
    book_collection_reduce(refreshed, stale_restore).0.history,
    refreshed.history,
  )
}

///|
extern "js" fn restore_write_evidence(
  before : String,
  restored : String,
  brief : String,
  html : String,
) -> @js.Promise =
  #| async (before,restored,brief,html)=>{const root=process.env.MOONBOOK_RESTORE_EVIDENCE;if(!root)return false;const fs=await import("node:fs/promises");for(const [name,data] of Object.entries({"before-restore.json":before,"restored-session.json":restored,"restored-brief.md":brief,"restore-preview.html":html}))await fs.writeFile(root+"/"+name,data);return true;}

///|
test "restore production render JSON download reopen and Markdown export" {
  @js.async_test(async fn() {
    let before = restore_fixture()
    let html = search_test_html({ ..book_search_initial(), collection: before, })
    assert_true(html.contains("Restore historical snapshot 1 as active"))
    assert_true(
      html.contains("Compare active snapshot that will move to history"),
    )
    assert_true(html.contains("raw/capacity-v1.txt"))
    assert_true(html.contains("raw/capacity-v2.txt"))
    assert_true(html.contains("&lt;script&gt;inert&lt;/script&gt;"))
    assert_false(html.contains("<script>inert</script>"))
    let restored = book_collection_reduce(
        before,
        RestoreHistory(before.revision, 0),
      ).0
    guard book_collection_reduce(restored, DownloadArchive).1
      is [ExportArchive(_, json)] else {
      fail("archive effect missing")
    }
    let capture = search_export_capture_start()
    let _ : String = book_collection_archive_download(json).wait().cast()
    let captured : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(captured)
      is { "download": String(downloaded), "clicked": true, .. } else {
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
    assert_eq(resumed.items, restored.items)
    assert_eq(resumed.history, restored.history)
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
    assert_true(brief.contains("Old synthetic capacity: eight teams."))
    assert_false(brief.contains("Fresh synthetic capacity: twelve teams."))
    assert_true(brief.contains("Resolve capacity before committing."))
    let _ : Bool = restore_write_evidence(
        book_collection_archive(before),
        downloaded,
        downloaded_brief,
        html,
      )
      .wait()
      .cast()
  })
}
