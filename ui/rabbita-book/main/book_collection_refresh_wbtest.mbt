///|
fn refresh_fixture() -> BookSearchState {
  let old = {
    ..collection_test_page(
      content="Old synthetic capacity: eight teams. <script>inert</script>",
    ),
    retained_source: Some({
      reference: "raw/capacity-v1.txt",
      page_digest: "a".repeat(64),
    }),
  }
  let state = book_search_reduce(
      collection_test_select(book_search_initial(), old),
      CollectPage,
    ).0
  let state = book_search_reduce(
      state,
      Collection(Note(old.citation, "Resolve capacity before committing. ~~~")),
    ).0
  let state = book_search_reduce(
      collection_test_select(
        state,
        collection_test_page(
          citation="wiki/sources/other.md",
          content="Other unchanged source.",
        ),
      ),
      CollectPage,
    ).0
  collection_test_select(state, {
    ..old,
    content: "Fresh synthetic capacity: twelve teams. <script>still inert</script>",
    retained_source: Some({
      reference: "raw/capacity-v2.txt",
      page_digest: "b".repeat(64),
    }),
  })
}

///|
fn refresh_message(state : BookSearchState) -> BookSearchMsg {
  RefreshCollected(
    state.page_request,
    state.collection.revision,
    book_collection_refresh_candidate(state).unwrap(),
  )
}

///|
test "collected refresh explicit comparison preserves note position outgoing history and resumes" {
  let state = refresh_fixture()
  let before = state.collection.items
  let html = search_test_html(state)
  assert_true(html.contains("Compare with collected snapshot"))
  assert_true(html.contains("Refresh snapshot and retain history"))
  assert_true(html.contains("raw/capacity-v1.txt"))
  assert_true(html.contains("raw/capacity-v2.txt"))
  assert_true(html.contains("&lt;script&gt;still inert&lt;/script&gt;"))
  assert_false(html.contains("<script>"))
  // Rendering and closing/leaving a comparison have no mutation or fetch.
  assert_eq(state.collection.items, before)
  let (fresh, effects) = book_search_reduce(state, refresh_message(state))
  assert_true(effects.is_empty())
  assert_eq(fresh.collection.items[0].page, state.page.unwrap())
  assert_eq(fresh.collection.items[0].note, before[0].note)
  assert_eq(fresh.collection.items[1], before[1])
  assert_eq(fresh.collection.history, [before[0]])
  assert_eq(fresh.collection.revision, state.collection.revision + 1)
  assert_true(
    fresh.collection.notice.unwrap().contains("not factual acceptance"),
  )
  let stale_export = book_search_reduce(
      fresh,
      Collection(
        ExportedBrief(state.collection.revision, Ok("old export completed")),
      ),
    ).0
  assert_eq(stale_export.collection.notice, fresh.collection.notice)
  // Replayed old click is rejected; unchanged fresh inspection creates no history.
  assert_eq(
    book_search_reduce(fresh, refresh_message(state)).0.collection.history,
    fresh.collection.history,
  )
  let unchanged = book_search_reduce(fresh, refresh_message(fresh)).0
  assert_eq(unchanged.collection.revision, fresh.collection.revision)
  assert_eq(unchanged.collection.history, fresh.collection.history)
  assert_true(unchanged.collection.notice.unwrap().contains("unchanged"))
  let text = book_collection_archive(fresh.collection)
  assert_true(text.contains("moonbook.research-collection.v2"))
  let preview = book_search_reduce(
      book_search_initial(),
      Collection(ArchiveDraft(text)),
    ).0
  assert_true(preview.collection.items.is_empty())
  let resumed = book_search_reduce(preview, Collection(ResumeArchive)).0
  assert_eq(resumed.collection.items, fresh.collection.items)
  assert_eq(resumed.collection.history, [before[0]])
  assert_eq(book_collection_archive(resumed.collection), text)
  let noted = book_search_reduce(
      resumed,
      Collection(Note(before[0].page.citation, "Updated note")),
    ).0
  let again = collection_test_select(noted, {
    ..state.page.unwrap(),
    content: "Third snapshot",
  })
  let again = book_search_reduce(again, refresh_message(again)).0
  assert_eq(again.collection.history.length(), 2)
  assert_eq(again.collection.history[0], before[0])
  assert_eq(again.collection.history[1].note, "Updated note")
  assert_eq(again.collection.history[1].page, fresh.collection.items[0].page)
  let removed = book_search_reduce(
      again,
      Collection(Remove(before[0].page.citation)),
    ).0
  assert_eq(removed.collection.history, again.collection.history)
  assert_eq(
    book_collection_decode_archive(book_collection_archive(removed.collection)).unwrap().history,
    again.collection.history,
  )
}

///|
test "collected refresh stale callbacks cancel navigation and exact envelope binding" {
  let state = refresh_fixture()
  let message = refresh_message(state)
  let citation = state.page.unwrap().citation
  let alternatives = [
    book_search_reduce(state, Edit("cancelled comparison")).0,
    book_search_reduce(state, Search).0,
    book_search_reduce(state, Inspect(citation)).0,
    book_search_reduce(state, Collection(Note(citation, "newer note"))).0,
    book_search_reduce(state, Collection(Move(citation, 1))).0,
    book_search_reduce(state, Collection(Remove(citation))).0,
    { ..state, selected: Some("wiki/sources/other.md"), },
    {
      ..state,
      page: state.page.map(p => { ..p, question: "wrong question", }),
    },
    { ..state, page: state.page.map(p => { ..p, page: Some(99), }), },
    { ..state, page: state.page.map(p => { ..p, ok: false, }), },
  ]
  let saved = book_collection_archive(state.collection)
  let preview = book_search_reduce(state, Collection(ArchiveDraft(saved))).0
  alternatives.push(book_search_reduce(preview, Collection(ResumeArchive)).0)
  for alternate in alternatives {
    let result = book_search_reduce(alternate, message).0
    assert_eq(result.collection.items, alternate.collection.items)
    assert_eq(result.collection.history, alternate.collection.history)
    assert_eq(result.collection.revision, alternate.collection.revision)
  }
  let mut revisited = state
  for _ in 0..<3 {
    revisited = collection_test_select(revisited, state.page.unwrap())
    assert_eq(
      book_search_reduce(revisited, message).0.collection.history.length(),
      0,
    )
    assert_eq(revisited.collection.items, state.collection.items)
  }
  let pending = book_search_reduce(revisited, Inspect(citation)).0
  let stale = book_search_reduce(
      pending,
      Inspected(state.page_request, citation, Ok(state.page.unwrap())),
    ).0
  assert_true(stale.page_pending)
  assert_true(stale.page is None)
  assert_eq(book_search_reduce(stale, message).0.collection.history.length(), 0)
  let candidate = book_collection_refresh_candidate(state).unwrap()
  let forged = RefreshCollected(state.page_request, state.collection.revision, {
    ..candidate,
    page: { ..candidate.page, content: "not the inspected bytes", },
  })
  assert_eq(
    book_search_reduce(state, forged).0.collection.items,
    state.collection.items,
  )
  let deleted = book_search_reduce(state, Collection(Remove(citation))).0
  let recollected = book_search_reduce(deleted, CollectPage).0
  assert_eq(
    book_search_reduce(recollected, message).0.collection.history.length(),
    0,
  )
}

///|
test "collected refresh unchanged query context and supplied binding only change" {
  let state = refresh_fixture()
  let old = state.collection.items[0]
  let same = collection_test_select(state, {
    ..old.page,
    question: "another search angle",
  })
  let result = book_search_reduce(same, refresh_message(same)).0
  assert_eq(result.collection.items[0], old)
  assert_true(result.collection.history.is_empty())
  let binding = collection_test_select(state, {
    ..old.page,
    retained_source: state.page.unwrap().retained_source,
  })
  let result = book_search_reduce(binding, refresh_message(binding)).0
  assert_eq(result.collection.items[0].page.content, old.page.content)
  assert_eq(result.collection.history, [old])
  let title_change = {
    ..same,
    result: same.result.map(result => {
      ..result,
      excerpts: result.excerpts.map(item => {
        ..item,
        title: "Changed search title",
      }),
    }),
  }
  let result = book_search_reduce(title_change, refresh_message(title_change)).0
  assert_eq(result.collection.history, [old])
  assert_eq(result.collection.items[0].title, "Changed search title")
}

///|
test "collected refresh bounded history text metadata and legacy migration are all or nothing" {
  let state = refresh_fixture()
  let full = {
    ..state,
    collection: {
      ..state.collection,
      history: Array::make(48, state.collection.items[0]),
    },
  }
  let denied = book_search_reduce(full, refresh_message(full)).0
  assert_eq(denied.collection.history, full.collection.history)
  assert_eq(denied.collection.items, full.collection.items)
  assert_true(denied.collection.notice.unwrap().contains("48"))
  let big = collection_test_select(state, {
    ..state.page.unwrap(),
    content: "x".repeat(1048576),
  })
  let denied = book_search_reduce(big, refresh_message(big)).0
  assert_eq(denied.collection.items, state.collection.items)
  assert_eq(denied.collection.history, state.collection.history)
  assert_true(denied.collection.notice.unwrap().contains("including history"))
  let metadata = collection_test_select(state, {
    ..state.page.unwrap(),
    retained_source: Some({ reference: "x".repeat(4097), page_digest: "b", }),
  })
  let denied = book_search_reduce(metadata, refresh_message(metadata)).0
  assert_eq(denied.collection.items, state.collection.items)
  assert_true(denied.collection.notice.unwrap().contains("Refresh refused"))
  let history_big = {
    ..state,
    collection: {
      ..state.collection,
      history: [
        {
          ..state.collection.items[0],
          page: {
            ..state.collection.items[0].page,
            content: "h".repeat(1048570),
          },
        },
      ],
    },
  }
  let extra = collection_test_select(
    history_big,
    collection_test_page(
      citation="wiki/sources/extra.md",
      content="another source",
    ),
  )
  assert_eq(
    book_search_reduce(extra, CollectPage).0.collection.items,
    history_big.collection.items,
  )
  let legacy : Json = {
    "schema": "moonbook.research-collection.v1",
    "title": "Legacy",
    "purpose": "",
    "items": state.collection.items.to_json(),
  }
  let migrated = book_collection_decode_archive(legacy.stringify()).unwrap()
  assert_eq(migrated.items, state.collection.items)
  assert_true(migrated.history.is_empty())
  let malformed : Json = {
    "schema": "moonbook.research-collection.v2",
    "title": "Legacy",
    "purpose": "",
    "items": state.collection.items.to_json(),
  }
  assert_true(book_collection_decode_archive(malformed.stringify()) is Err(_))
  let archive = book_collection_decode_archive(
    book_collection_archive(state.collection),
  ).unwrap()
  for
    invalid in [
      { ..archive, history: Array::make(49, state.collection.items[0]), },
      {
        ..archive,
        history: [{ ..state.collection.items[0], note: "x".repeat(4001), }],
      },
      {
        ..archive,
        history: [
          {
            ..state.collection.items[0],
            page: { ..state.page.unwrap(), content: "x".repeat(1048576), },
          },
        ],
      },
      {
        ..archive,
        history: [
          {
            ..state.collection.items[0],
            page: { ..state.page.unwrap(), schema: "bad", },
          },
        ],
      },
    ] {
    assert_true(
      book_collection_decode_archive(invalid.to_json().stringify()) is Err(_),
    )
  }
}

///|
extern "js" fn refresh_write_evidence(
  archive : String,
  brief : String,
  html : String,
) -> @js.Promise =
  #| async (archive,brief,html)=>{const root=process.env.MOONBOOK_REFRESH_EVIDENCE;if(!root)return false;const fs=await import("node:fs/promises");await fs.writeFile(root+"/refreshed-collection.json",archive);await fs.writeFile(root+"/refreshed-brief.md",brief);await fs.writeFile(root+"/refreshed-comparison.html",html);return true;}

///|
test "collected refresh synthetic production Blob save file reopen resume and brief download" {
  @js.async_test(async fn() {
    let state = refresh_fixture()
    let fresh = book_search_reduce(state, refresh_message(state)).0
    guard book_search_reduce(fresh, Collection(DownloadArchive)).1
      is [ExportArchive(_, archive)] else {
      fail("archive effect missing")
    }
    let capture = search_export_capture_start()
    let _ : String = book_collection_archive_download(archive).wait().cast()
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
    assert_eq(downloaded, archive)
    archive_file_capture_start(downloaded)
    let opened : String = book_collection_archive_open().wait().cast()
    archive_file_capture_finish()
    let preview = book_search_reduce(
        book_search_initial(),
        Collection(ArchiveDraft(opened)),
      ).0
    let resumed = book_search_reduce(preview, Collection(ResumeArchive)).0
    assert_eq(resumed.collection.items, fresh.collection.items)
    assert_eq(resumed.collection.history, [state.collection.items[0]])
    let brief_capture = search_export_capture_start()
    guard book_search_reduce(resumed, Collection(DownloadBrief)).1
      is [ExportCollection(_, brief, true)] else {
      fail("brief missing")
    }
    let _ : String = book_collection_export(brief, true).wait().cast()
    let captured : String = paging_export_capture_finish(brief_capture)
      .wait()
      .cast()
    guard @json.parse(captured)
      is { "download": String(downloaded_brief), "clicked": true, .. } else {
      fail("brief Blob missing")
    }
    assert_eq(downloaded_brief, brief)
    assert_true(brief.contains("twelve teams"))
    assert_false(brief.contains("eight teams"))
    assert_true(
      brief.contains(
        "Historical snapshots retained in the resumable JSON archive: 1",
      ),
    )
    let _ : Bool = refresh_write_evidence(
        downloaded,
        downloaded_brief,
        search_test_html(state),
      )
      .wait()
      .cast()
  })
}
