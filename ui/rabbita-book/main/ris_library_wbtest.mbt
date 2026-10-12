///|
extern "js" fn ris_collection_wire() -> @js.Promise =
  #| async () => { const dir=globalThis.process?.env?.MOONBOOK_RIS_EVIDENCE; return dir ? await (await import('node:fs/promises')).readFile(dir+'/ris-http-wire.json','utf8') : ''; }

///|
extern "js" fn ris_collection_save(
  brief : String,
  archive : String,
) -> @js.Promise =
  #| async (brief, archive) => {
  #|   const dir=globalThis.process?.env?.MOONBOOK_RIS_EVIDENCE;
  #|   if (dir) { const fs=await import('node:fs/promises'); await fs.writeFile(dir+'/ris-research-brief.md',brief); await fs.writeFile(dir+'/ris-collection.json',archive); }
  #|   return true;
  #| }

///|
test "RIS native library citations become a resumable research collection and exact Markdown download" {
  @js.async_test(async fn() {
    let input : String = ris_collection_wire().wait().cast()
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
      fail("actual native RIS library evidence required")
    }
    let mut state = book_search_initial()
    for selection in selections {
      guard selection
        is {
          "question": String(question),
          "citation": String(citation),
          "response": response,
          "inspection": inspection,
          ..
        } else {
        fail("missing native RIS selection")
      }
      guard book_search_decode(response.stringify(), question) is Ok(result) else {
        fail("RIS query decode")
      }
      guard book_search_decode_page(
          inspection.stringify(),
          question,
          citation,
          results_page=0,
        )
        is Ok(page) else {
        fail("RIS page decode")
      }
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
    assert_eq(state.collection.items.length(), 2)
    state = book_search_reduce(
        state,
        Collection(Title("Aurora onboarding literature comparison")),
      ).0
    state = book_search_reduce(
        state,
        Collection(
          Purpose(
            "Compare the synthetic eight-team onboarding result with the five-team follow-up result. These measure different stages; establish comparable definitions before using either count to plan capacity.",
          ),
        ),
      ).0
    let second = state.collection.items[1].page.citation
    state = book_search_reduce(
        state,
        Collection(
          Note(
            second, "Counterevidence: follow-up support reached fewer teams. Retrieve the full paper before judging methodology.",
          ),
        ),
      ).0
    let archive = book_collection_archive(state.collection)
    let draft = book_search_reduce(
        book_search_initial(),
        Collection(ArchiveDraft(archive)),
      ).0
    let resumed = book_search_reduce(draft, Collection(ResumeArchive)).0
    assert_eq(resumed.collection.items, state.collection.items)
    let expected = book_collection_brief(resumed.collection)
    assert_true(expected.contains("Lin, Mei"))
    assert_true(expected.contains("Chen, Li"))
    assert_true(expected.contains("Only five teams"))
    assert_true(expected.contains("Record number in retained export: 2"))
    let html = search_test_html(resumed)
    assert_true(html.contains("Aurora onboarding literature comparison"))
    let capture = search_export_capture_start()
    guard book_search_reduce(resumed, Collection(DownloadBrief)).1
      is [ExportCollection(_, text, download)] else {
      fail("no Markdown export effect")
    }
    let _ : String = book_collection_export(text, download).wait().cast()
    let captured : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(captured)
      is {
        "download": String(brief),
        "filename": "moonbook-research-brief.md",
        "clicked": true,
        ..
      } else {
      fail("no actual production download Blob")
    }
    assert_eq(brief, expected)
    let _ : Bool = ris_collection_save(brief, archive).wait().cast()
  })
}
