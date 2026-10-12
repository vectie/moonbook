///|
test "portable collection roundtrips notes order source metadata and continues editing" {
  let first = {
    ..collection_test_page(),
    retained_source: Some({
      reference: "retained/demo.txt",
      page_digest: "a".repeat(64),
    }),
    page: Some(2),
  }
  let second = collection_test_page(
    citation="wiki/sources/second.md",
    content="# Budget\nEight slots 🌙\n",
  )
  let selected = collection_test_select(book_search_initial(), first)
  let selected = {
    ..selected,
    result: selected.result.map(result => {
      ..result,
      paging: Some({
        page: 2,
        page_size: 8,
        matched_count: 1,
        window_count: 1,
        has_next: false,
        truncated: false,
        fresh_scan: true,
      }),
    }),
  }
  let state = book_search_reduce(selected, CollectPage).0
  let state = book_search_reduce(
      collection_test_select(state, second),
      CollectPage,
    ).0
  let state = book_search_reduce(
      state,
      Collection(Note(second.citation, "Capacity counterevidence")),
    ).0
  let state = book_search_reduce(state, Collection(Move(second.citation, -1))).0
  let state = book_search_reduce(state, Collection(Title("Pilot sources"))).0
  let state = book_search_reduce(
      state,
      Collection(Purpose("Resolve capacity before setting dates.")),
    ).0
  let json = book_collection_archive(state.collection)
  let reset = book_search_initial()
  let preview = book_search_reduce(reset, Collection(ArchiveDraft(json))).0
  assert_eq(preview.collection.items.length(), 0)
  assert_true(
    search_test_html(preview).contains("Ready to resume: Pilot sources"),
  )
  let resumed = book_search_reduce(preview, Collection(ResumeArchive)).0
  assert_eq(resumed.collection.items, state.collection.items)
  assert_eq(resumed.collection.title, state.collection.title)
  assert_eq(resumed.collection.purpose, state.collection.purpose)
  assert_eq(book_collection_archive(resumed.collection), json)
  assert_true(resumed.collection.notice.unwrap().contains("supplied data"))
  assert_eq(
    book_collection_brief(resumed.collection),
    book_collection_brief(state.collection),
  )
  let edited = book_search_reduce(
      resumed,
      Collection(Note(second.citation, "Updated after reopening")),
    ).0
  assert_eq(edited.collection.items[0].note, "Updated after reopening")
  let removed = book_search_reduce(edited, Collection(Remove(first.citation))).0
  assert_eq(removed.collection.items.length(), 1)
  assert_true(
    book_search_reduce(removed, Collection(DownloadArchive)).1
    is [ExportArchive(_, _)],
  )
  let opening = book_search_reduce(removed, Collection(OpenArchive)).0
  let manual = book_search_reduce(
      opening,
      Collection(ArchiveDraft("newer paste")),
    ).0
  let stale = book_search_reduce(
      manual,
      Collection(ArchiveRead(opening.collection.import_request, Ok(json))),
    ).0
  assert_eq(stale.collection.import_text, "newer paste")
}

///|
test "portable collection invalid archives keep existing work and imported text stays inert" {
  let state = book_search_reduce(
      collection_test_select(book_search_initial(), collection_test_page()),
      CollectPage,
    ).0
  let archive = book_collection_decode_archive(
    book_collection_archive(state.collection),
  ).unwrap()
  for
    text in [
      "not json",
      { ..archive, schema: "future", }.to_json().stringify(),
      { ..archive, items: archive.items + archive.items, }.to_json().stringify(),
      { ..archive, purpose: "x".repeat(4001), }.to_json().stringify(),
      {
        ..archive,
        items: [
          {
            ..archive.items[0],
            page: { ..archive.items[0].page, content: "x".repeat(1048577), },
          },
        ],
      }
      .to_json()
      .stringify(),
    ] {
    let preview = book_search_reduce(state, Collection(ArchiveDraft(text))).0
    let rejected = book_search_reduce(preview, Collection(ResumeArchive)).0
    assert_eq(rejected.collection.items, state.collection.items)
    assert_eq(rejected.collection.revision, state.collection.revision)
    assert_true(
      rejected.collection.notice.unwrap().contains("Current collection kept"),
    )
  }
  let hostile = { ..archive, title: "<script>alert(1)</script>", }
  let preview = book_search_reduce(
      state,
      Collection(ArchiveDraft(hostile.to_json().stringify())),
    ).0
  assert_false(search_test_html(preview).contains("<script>alert(1)</script>"))
  assert_true(
    book_collection_decode_archive(
      book_collection_archive(book_collection_initial()),
    )
    is Ok(_),
  )
}

///|
extern "js" fn archive_write_evidence(
  archive : String,
  brief : String,
) -> @js.Promise =
  #| async (archive,brief)=>{const root=process.env.MOONBOOK_ARCHIVE_EVIDENCE;if(!root)throw new Error("evidence path required");const fs=await import("node:fs/promises");await fs.writeFile(root+"/portable-collection.json",archive);await fs.writeFile(root+"/resumed-brief.md",brief);return true;}

///|
extern "js" fn archive_file_capture_start(text : String) -> Unit =
  #| text=>{globalThis.__archiveOldDocument=globalThis.document;globalThis.document={createElement(tag){if(tag!=="input")throw new Error("expected file input");return {files:[{size:new TextEncoder().encode(text).length,text:async()=>text}],click(){queueMicrotask(()=>this.onchange());}};}};}

///|
extern "js" fn archive_file_capture_finish() -> Unit =
  #| ()=>{globalThis.document=globalThis.__archiveOldDocument;delete globalThis.__archiveOldDocument;}

///|
test "portable collection actual native inspection save Blob reopen resume and edit" {
  @js.async_test(async fn() {
    let input : String = collection_native_wire().wait().cast()
    guard @json.parse(input)
      is {
        "socket_verified": true,
        "book_unchanged": true,
        "selections": Array(selections),
        ..
      } else {
      fail("native HTTP collection wire required")
    }
    let mut state = book_search_initial()
    for selection in selections {
      guard selection
        is {
          "question": String(question),
          "citation": String(citation),
          "inspection": inspection,
          "response": response,
          "expected_page": String(expected),
          ..
        } else {
        fail("selection required")
      }
      guard book_search_decode_page(
          inspection.stringify(),
          question,
          citation,
          results_page=0,
        )
        is Ok(page) else {
        fail("native page decode")
      }
      assert_eq(page.content, expected)
      let result : BookSearchResult = @json.from_json(response)
      let editing = book_search_reduce(state, Edit(question)).0
      let loading = book_search_reduce(editing, Search).0
      let ready = book_search_reduce(
          loading,
          Loaded(loading.request, question, Ok(result)),
        ).0
      let selecting = book_search_reduce(ready, Inspect(citation)).0
      let inspected = book_search_reduce(
          selecting,
          Inspected(selecting.page_request, citation, Ok(page)),
        ).0
      state = book_search_reduce(inspected, CollectPage).0
    }
    state = book_search_reduce(
        state,
        Collection(Title("Aurora research, ready to resume")),
      ).0
    state = book_search_reduce(
        state,
        Collection(
          Purpose("Compare twelve planned teams with eight onboarding slots."),
        ),
      ).0
    assert_eq(state.collection.items.length(), 2)
    let citation = state.collection.items[1].page.citation
    state = book_search_reduce(
        state,
        Collection(
          Note(
            citation, "Check this counterevidence with the onboarding owner.",
          ),
        ),
      ).0
    state = book_search_reduce(state, Collection(Move(citation, -1))).0
    guard book_search_reduce(state, Collection(DownloadArchive)).1
      is [ExportArchive(_, archive)] else {
      fail("archive effect")
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
      fail("JSON Blob capture")
    }
    assert_eq(downloaded, archive)
    archive_file_capture_start(downloaded)
    let opened : String = book_collection_archive_open().wait().cast()
    archive_file_capture_finish()
    assert_eq(opened, downloaded)
    let opening = book_search_reduce(
        book_search_initial(),
        Collection(OpenArchive),
      ).0
    let preview = book_search_reduce(
        opening,
        Collection(ArchiveRead(opening.collection.import_request, Ok(opened))),
      ).0
    let resumed = book_search_reduce(preview, Collection(ResumeArchive)).0
    assert_eq(resumed.collection.items, state.collection.items)
    let edited = book_search_reduce(
        resumed,
        Collection(
          Note(
            citation, "Resumed review: confirm eight slots before committing.",
          ),
        ),
      ).0
    let brief = book_collection_brief(edited.collection)
    assert_true(brief.contains("Resumed review"))
    assert_false(brief.contains("UNSELECTED_PRIVATE_SENTINEL"))
    let _ : Bool = archive_write_evidence(archive, brief).wait().cast()
  })
}
