///|
fn collection_test_page(
  citation? : String = "wiki/sources/route.md",
  content? : String = "# Lunar evidence\n~~~\n<script>inactive</script>\n海风\n",
) -> BookSearchPage {
  {
    schema: "moonbook.search.v1",
    ok: true,
    question: "Lunar",
    citation,
    content,
    retained_source: None,
    page: None,
  }
}

///|
fn collection_test_select(
  state : BookSearchState,
  page : BookSearchPage,
) -> BookSearchState {
  let result = {
    ..search_test_result(question=page.question),
    excerpts: [{ ..search_test_result().excerpts[0], citation: page.citation, }],
  }
  let edited = book_search_reduce(state, Edit(page.question)).0
  let loading = book_search_reduce(edited, Search).0
  let ready = book_search_reduce(
      loading,
      Loaded(loading.request, page.question, Ok(result)),
    ).0
  let selecting = book_search_reduce(ready, Inspect(page.citation)).0
  book_search_reduce(
    selecting,
    Inspected(selecting.page_request, page.citation, Ok(page)),
  ).0
}

///|
test "research collection collect across searches annotate reorder remove and exact inert export" {
  let first = collection_test_page()
  let selected = collection_test_select(book_search_initial(), first)
  let collected = book_search_reduce(selected, CollectPage).0
  assert_eq(collected.collection.items.length(), 1)
  let edited = book_search_reduce(
      collected,
      Collection(
        Note(
          first.citation,
          "Use only for pilot scope.\n~~~\n# not a source heading",
        ),
      ),
    ).0
  let duplicate = book_search_reduce(edited, CollectPage).0
  assert_eq(duplicate.collection.items, edited.collection.items)
  assert_true(
    duplicate.collection.notice.unwrap().contains("Already collected"),
  )
  let second = {
    ..collection_test_page(
      citation="wiki/sources/capacity.md",
      content="# Capacity\nEight onboarding slots, not twelve.\n",
    ),
    question: "capacity",
  }
  let comparing = collection_test_select(edited, second)
  assert_eq(comparing.collection.items, edited.collection.items)
  let mut state = book_search_reduce(comparing, CollectPage).0
  state = book_search_reduce(state, Collection(Title("Q4 pilot decision"))).0
  state = book_search_reduce(
      state,
      Collection(
        Purpose("Compare the plan with available onboarding capacity."),
      ),
    ).0
  state = book_search_reduce(
      state,
      Collection(
        Note(second.citation, "Counterevidence: capacity needs reconciliation."),
      ),
    ).0
  let original_order = state.collection.items
  state = book_search_reduce(state, Collection(Move(second.citation, -1))).0
  assert_eq(state.collection.items[0].page, second)
  assert_eq(original_order[0].page, first)
  state = book_search_reduce(state, Collection(Move(second.citation, 1))).0
  assert_eq(state.collection.items, original_order)
  assert_eq(
    book_search_reduce(state, Collection(Move(first.citation, -1))).0.collection.items,
    original_order,
  )
  let before_remove = state
  state = book_search_reduce(state, Collection(Remove(first.citation))).0
  assert_eq(state.collection.items.length(), 1)
  assert_eq(state.collection.items[0].page, second)
  state = before_remove
  let brief = book_collection_brief(state.collection)
  assert_true(brief.contains(first.content))
  assert_true(brief.contains(second.content))
  assert_true(brief.contains("~~~~text\n# Lunar evidence\n~~~"))
  assert_true(brief.contains("not factual review or accepted knowledge"))
  assert_true(brief.contains("not supplied by the host"))
  for message in [BookCollectionMsg::CopyBrief, DownloadBrief] {
    guard book_search_reduce(state, Collection(message)).1
      is [ExportCollection(revision, text, download)] else {
      fail("collection export missing")
    }
    assert_eq(revision, state.collection.revision)
    assert_eq(text, brief)
    assert_eq(download, message is DownloadBrief)
  }
  let rendered = search_test_html(state)
  assert_true(rendered.contains("Research collection (2/12)"))
  assert_true(rendered.contains("Read collected snapshot"))
  assert_true(rendered.contains("&lt;script&gt;inactive&lt;/script&gt;"))
  assert_false(rendered.contains("<script>inactive"))
  assert_true(rendered.contains("value=\"Q4 pilot decision\""))
  let stale = book_search_reduce(
      state,
      Collection(ExportedBrief(state.collection.revision - 1, Ok("stale"))),
    ).0
  assert_false(stale.collection.notice == Some("stale"))
  let failed = book_search_reduce(
      state,
      Collection(
        ExportedBrief(
          state.collection.revision,
          Err("Clipboard denied; use Download."),
        ),
      ),
    ).0
  assert_eq(failed.collection.items, state.collection.items)
  assert_true(failed.collection.notice.unwrap().contains("Clipboard denied"))
  let changed = book_search_reduce(state, Edit("new question")).0
  assert_eq(
    book_search_reduce(changed, CollectPage).0.collection.items,
    state.collection.items,
  )
  let pending = book_search_reduce(state, Search).0
  assert_eq(
    book_search_reduce(pending, CollectPage).0.collection.items,
    state.collection.items,
  )
  assert_eq(book_search_initial().collection.items.length(), 0)
}

///|
test "research collection bounded pages notes and source text remain all or nothing" {
  assert_true(
    book_search_reduce(book_search_initial(), Collection(DownloadBrief)).1.is_empty(),
  )
  let selected = collection_test_select(
    book_search_initial(),
    collection_test_page(content="x".repeat(1048577)),
  )
  let refused = book_search_reduce(selected, CollectPage).0
  assert_true(refused.collection.items.is_empty())
  assert_true(
    refused.collection.notice.unwrap().contains("Nothing was truncated"),
  )
  let mut state = book_search_initial()
  for index in 0..<12 {
    state = book_search_reduce(
        collection_test_select(
          state,
          collection_test_page(
            citation="wiki/sources/" + index.to_string() + ".md",
          ),
        ),
        CollectPage,
      ).0
  }
  assert_eq(state.collection.items.length(), 12)
  let full = book_search_reduce(
      collection_test_select(state, collection_test_page()),
      CollectPage,
    ).0
  assert_eq(full.collection.items, state.collection.items)
  assert_true(full.collection.notice.unwrap().contains("up to 12"))
  for
    message in [
      BookCollectionMsg::Title("x".repeat(161)),
      Purpose("x".repeat(4001)),
      Note(state.collection.items[0].page.citation, "x".repeat(4001)),
    ] {
    let rejected = book_search_reduce(state, Collection(message)).0
    assert_eq(rejected.collection.items, state.collection.items)
    assert_eq(rejected.collection.title, state.collection.title)
    assert_eq(rejected.collection.purpose, state.collection.purpose)
    assert_true(rejected.collection.notice is Some(_))
  }
  assert_eq(book_collection_block("~~~~~~"), "~~~~~~~text\n~~~~~~\n~~~~~~~\n")
}

///|
extern "js" fn collection_native_wire() -> @js.Promise =
  #| async () => { const path=globalThis.process?.env?.MOONBOOK_COLLECTION_WIRE; return path ? await (await import('node:fs/promises')).readFile(path,'utf8') : ''; }

///|
extern "js" fn collection_record_receipt(
  receipt : String,
  brief : String,
) -> @js.Promise =
  #| async (receipt, brief) => {
  #|   const fs=await import('node:fs/promises'), env=globalThis.process.env;
  #|   if(env.MOONBOOK_COLLECTION_UI_RECEIPT) await fs.writeFile(env.MOONBOOK_COLLECTION_UI_RECEIPT,receipt);
  #|   if(env.MOONBOOK_COLLECTION_EXPORT) await fs.writeFile(env.MOONBOOK_COLLECTION_EXPORT,brief);
  #|   return true;
  #| }

///|
test "research collection actual native HTTP inspections cross compiled selection note ordering and clipboard Blob" {
  @js.async_test(async fn() {
    let input : String = collection_native_wire().wait().cast()
    if input.is_empty() {
      return
    }
    guard @json.parse(input)
      is {
        "socket_verified": true,
        "book_unchanged": true,
        "selections": Array(selections),
        ..
      } else {
      fail("actual native HTTP evidence required")
    }
    let mut state = book_search_initial()
    for selection in selections {
      guard selection
        is {
          "question": String(question),
          "citation": String(citation),
          "response": response,
          "inspection": inspection,
          "expected_page": String(expected_page),
          "note": String(note),
          ..
        } else {
        fail("bad native selection")
      }
      let fixture = search_capture_transport(response.stringify())
      guard book_search_post(
          "/api/book/query",
          { "question": question, "page": 0 },
          send=(method_, route, body) => {
            search_send_capture(fixture, method_, route, body)
          },
        )
        is Ok(body) else {
        fail("transport")
      }
      guard book_search_decode(body, question) is Ok(result) else {
        fail("query decode")
      }
      let editing = book_search_reduce(state, Edit(question)).0
      let loading = book_search_reduce(editing, Search).0
      let ready = book_search_reduce(
          loading,
          Loaded(loading.request, question, Ok(result)),
        ).0
      guard book_search_decode_page(
          inspection.stringify(),
          question,
          citation,
          results_page=0,
        )
        is Ok(page) else {
        fail("inspection decode")
      }
      assert_eq(page.content, expected_page)
      let selecting = book_search_reduce(ready, Inspect(citation)).0
      let inspected = book_search_reduce(
          selecting,
          Inspected(selecting.page_request, citation, Ok(page)),
        ).0
      state = book_search_reduce(inspected, CollectPage).0
      state = book_search_reduce(state, Collection(Note(citation, note))).0
    }
    assert_eq(state.collection.items.length(), 2)
    state = book_search_reduce(
        state,
        Collection(Title("Aurora Q4 pilot: launch scope review")),
      ).0
    state = book_search_reduce(
        state,
        Collection(
          Purpose(
            "The plan proposes twelve pilot teams, but the current onboarding note supports eight. Reconcile that gap with the onboarding owner before fixing the launch scope. These notes are research, not an approval decision.",
          ),
        ),
      ).0
    let second = state.collection.items[1].page.citation
    state = book_search_reduce(state, Collection(Move(second, -1))).0
    assert_eq(state.collection.items[0].page.citation, second)
    let prior = state
    let removed = book_search_reduce(state, Collection(Remove(second))).0
    assert_eq(removed.collection.items.length(), 1)
    state = prior
    let rendered = search_test_html(state)
    assert_true(rendered.contains("Aurora Q4 pilot"))
    assert_true(rendered.contains("eight"))
    let expected = book_collection_brief(state.collection)
    assert_false(expected.contains("UNSELECTED_PRIVATE_SENTINEL"))
    let capture = search_export_capture_start()
    for message in [BookCollectionMsg::CopyBrief, DownloadBrief] {
      guard book_search_reduce(state, Collection(message)).1
        is [ExportCollection(revision, text, download)] else {
        fail("export effect")
      }
      assert_eq(text, expected)
      let message : String = book_collection_export(text, download)
        .wait()
        .cast()
      state = book_search_reduce(
          state,
          Collection(ExportedBrief(revision, Ok(message))),
        ).0
    }
    let exported : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(exported)
      is {
        "clipboard": String(copied),
        "download": String(downloaded),
        "filename": "moonbook-research-brief.md",
        "clicked": true,
        ..
      } else {
      fail("clipboard Blob evidence missing")
    }
    assert_eq(copied, expected)
    assert_eq(downloaded, expected)
    assert_true(state.collection.notice.unwrap().contains("download requested"))
    let _ : Bool = collection_record_receipt(
        (
          {
            "status": "PASS",
            "native_http_inspections": 2,
            "book_unchanged": true,
            "compiled_reducer_actions": [
              "search", "inspect", "collect", "title", "purpose", "note", "move",
              "remove", "copy", "download", "export_completion",
            ],
            "clipboard_blob_exact": true,
            "selected_scope_only": true,
            "graphical_browser": "not run",
            "os_clipboard_download": "controlled test doubles",
          } : Json).stringify(indent=2),
        downloaded,
      )
      .wait()
      .cast()
  })
}
