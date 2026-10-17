///|
test "find literal phrases across every field with Unicode safe original excerpts" {
  let before = restore_fixture()
  for
    phrase in [
      "TWELVE TEAMS", "  twelve teams  ", "New note", "capacity-v2", "bbbbbbbb",
      "Lunar", "wiki/sources/route.md",
    ] {
    let state = book_collection_reduce(before, FindText(phrase)).0
    assert_true(
      book_collection_find(state).any(hit => !hit.historical && hit.index == 0),
    )
  }
  let item = {
    ..before.items[0],
    title: "Distinct title",
    note: "海风😀 [a+b].* $1",
  }
  let state = {
    ..before,
    items: [item],
    history: [],
    find_text: "distinct TITLE",
  }
  assert_eq(book_collection_find(state)[0].excerpts[0].0, "Title")
  let state = { ..state, find_text: "海风😀 [a+b].* $1", }
  assert_eq(book_collection_find(state)[0].excerpts, [
    ("Researcher note", item.note),
  ])
  assert_eq(book_collection_find_excerpt("AA aab ZZ", "a+b"), "")
  assert_eq(
    book_collection_find_excerpt(
      "x [ ] \\ ( ) ^ $ ? * . + { } | y", "[ ] \\ ( ) ^ $ ? * . + { } |",
    ),
    "x [ ] \\ ( ) ^ $ ? * . + { } | y",
  )
  assert_eq(
    book_collection_find_excerpt("ÄPFEL 海风😀", "äpfel"),
    "ÄPFEL 海风😀",
  )
  assert_eq(
    book_collection_find_excerpt(
      "😀".repeat(100) + "Match" + "🌙".repeat(100),
      "MATCH",
    ),
    "…" + "😀".repeat(70) + "Match" + "🌙".repeat(70) + "…",
  )
  assert_eq(
    book_collection_find_excerpt("first MATCH then match", "match"),
    "first MATCH then match",
  )
}

///|
test "finder scope counts history positions duplicates and nonmutation" {
  let before = restore_fixture()
  let historical = before.history[0]
  let before = { ..before, history: [before.items[1], historical, historical], }
  let json = book_collection_archive(before)
  let brief = book_collection_brief(before)
  let (state, effects) = book_collection_reduce(before, FindText("eight teams"))
  assert_true(effects.is_empty())
  let hits = book_collection_find(state)
  assert_eq(hits.length(), 2)
  assert_eq(hits[0].index, 1)
  assert_eq(hits[1].index, 2)
  assert_true(hits[0].historical)
  let active = book_collection_reduce(state, FindScope("active")).0
  assert_true(book_collection_find(active).is_empty())
  let history = book_collection_reduce(active, FindScope("history")).0
  assert_eq(book_collection_find(history), hits)
  assert_eq(
    book_collection_reduce(history, FindScope("bad")).0.find_scope,
    "history",
  )
  assert_eq(book_collection_archive(history), json)
  assert_eq(book_collection_brief(history), brief)
  assert_eq(history.revision, before.revision)
  assert_eq(history.import_request, before.import_request)
  assert_eq(
    book_collection_reduce(history, FindText("x".repeat(201))).0.find_text,
    history.find_text,
  )
  assert_eq(
    book_collection_reduce(history, FindText("x".repeat(200))).0.find_text.length(),
    200,
  )
  for phrase in ["", " \n\t ", "unmatched phrase"] {
    assert_true(
      book_collection_find({ ..history, find_text: phrase, }).is_empty(),
    )
  }
  let restored = book_collection_reduce(
      history,
      RestoreHistory(history.revision, hits[1].index),
    ).0
  assert_eq(restored.items[0], historical)
  assert_eq(restored.history, [before.items[1], historical, before.items[0]])
  let all = book_collection_reduce(restored, FindScope("all")).0
  assert_eq(book_collection_find(all).length(), 2)
  assert_false(book_collection_find(all)[0].historical)
  assert_eq(book_collection_find(all)[1].index, 1)
  let edited = book_collection_reduce(
      history,
      Note(history.items[0].page.citation, "new note"),
    ).0
  assert_eq(
    book_collection_reduce(
      edited,
      RestoreHistory(history.revision, hits[0].index),
    ).0.items,
    edited.items,
  )
}

///|
extern "js" fn find_write_evidence(
  before : String,
  html : String,
  restored : String,
  brief : String,
) -> @js.Promise =
  #| async (before, html, restored, brief) => { const root=process.env.MOONBOOK_FIND_EVIDENCE;if(!root)return false;const fs=await import("node:fs/promises");for(const [name,data] of Object.entries({"collection.json":before,"matching-history.html":html,"recovered-collection.json":restored,"recovered-brief.md":brief}))await fs.writeFile(root+"/"+name,data);return true; }

///|
test "find scans the complete text budget and all 60 original positions" {
  let before = restore_fixture()
  let item = before.items[0]
  let state = {
    ..before,
    find_text: "needle",
    items: Array::makei(12, index => {
      ..item,
      title: "needle",
      page: {
        ..item.page,
        citation: "active-" + index.to_string(),
        content: "",
      },
    }),
    history: Array::makei(48, index => {
      ..item,
      title: "needle",
      page: {
        ..item.page,
        citation: "history-" + index.to_string(),
        content: if index == 47 {
          "x".repeat(1048570) + "needle"
        } else {
          ""
        },
      },
    }),
  }
  let hits = book_collection_find(state)
  assert_eq(hits.length(), 60)
  assert_eq(hits[11].index, 11)
  assert_eq(hits[59].index, 47)
  assert_eq(
    hits[59].excerpts[1],
    ("Snapshot text", "…" + "x".repeat(70) + "needle"),
  )
  let blocked = book_collection_reduce(
      state,
      RestoreHistory(state.revision, hits[59].index),
    ).0
  assert_eq(blocked.items, state.items)
  assert_eq(blocked.history, state.history)
  assert_true(blocked.notice.unwrap().contains("all 12"))
}

///|
test "find render restore real archive Blob reopen and brief retain unfiltered scope" {
  book_test_async(async fn() {
    let before = restore_fixture()
    let state = book_collection_reduce(
        book_collection_reduce(before, FindText("eight teams")).0,
        FindScope("history"),
      ).0
    let html = search_test_html({ ..book_search_initial(), collection: state, })
    assert_true(html.contains("1 matching snapshots; scope: history"))
    assert_true(html.contains("Snapshot text — first matching excerpt"))
    assert_true(html.contains("Restore matching historical snapshot 1"))
    assert_true(html.contains("&lt;script&gt;inert&lt;/script&gt;"))
    assert_false(html.contains("<script>inert</script>"))
    assert_true(html.contains("Search does not limit any download"))
    let no_hits = search_test_html({
      ..book_search_initial(),
      collection: { ..state, find_scope: "active", },
    })
    assert_true(no_hits.contains("No matching snapshots in this scope"))
    let hit = book_collection_find(state)[0]
    let restored = book_collection_reduce(
        state,
        RestoreHistory(state.revision, hit.index),
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
      fail("archive Blob missing")
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
    assert_eq(resumed.items.length(), 2)
    assert_eq(resumed.find_text, "")
    assert_eq(resumed.find_scope, "all")
    guard book_collection_reduce(restored, DownloadBrief).1
      is [ExportCollection(_, brief, true)] else {
      fail("brief effect missing")
    }
    let capture = search_export_capture_start()
    let _ : String = book_collection_export(brief, true).wait().cast()
    let captured : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(captured)
      is { "download": String(downloaded_brief), "clicked": true, .. } else {
      fail("brief Blob missing")
    }
    assert_eq(downloaded_brief, brief)
    assert_true(brief.contains("eight teams"))
    assert_true(brief.contains("Other unchanged source"))
    assert_false(brief.contains("twelve teams"))
    let _ : Bool = find_write_evidence(
        book_collection_archive(before),
        html,
        downloaded,
        downloaded_brief,
      )
      .wait()
      .cast()
  })
}
