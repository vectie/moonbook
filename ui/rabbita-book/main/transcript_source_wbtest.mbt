///|
extern "js" fn transcript_source_wire() -> @js.Promise =
  #| async () => { const dir=globalThis.process?.env?.MOONBOOK_TRANSCRIPT_EVIDENCE; return dir ? await (await import('node:fs/promises')).readFile(dir+'/transcript-http-wire.json','utf8') : ''; }

///|
extern "js" fn transcript_source_save(
  brief : String,
  archive : String,
) -> @js.Promise =
  #| async (brief, archive) => { const dir=globalThis.process?.env?.MOONBOOK_TRANSCRIPT_EVIDENCE; if (dir) { const fs=await import('node:fs/promises'); await fs.writeFile(dir+'/transcript-research-brief.md',brief); await fs.writeFile(dir+'/transcript-collection.json',archive); } return true; }

///|
test "native transcript becomes a resumable research brief preserving timed quotes speaker attribution and raw binding" {
  @js.async_test(async fn() {
    let input : String = transcript_source_wire().wait().cast()
    if input.is_empty() {
      return
    }
    guard @json.parse(input)
      is {
        "socket_verified": true,
        "book_unchanged": true,
        "selection": {
          "question": String(question),
          "citation": String(citation),
          "response": response,
          "inspection": inspection,
          ..
        },
        ..
      } else {
      fail("actual transcript HTTP wire required")
    }
    guard book_search_decode(response.stringify(), question) is Ok(result) else {
      fail("transcript query decode")
    }
    guard book_search_decode_page(
        inspection.stringify(),
        question,
        citation,
        results_page=0,
      )
      is Ok(page) else {
      fail("transcript inspection decode")
    }
    let editing = book_search_reduce(book_search_initial(), Edit(question)).0
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
    let collected = book_search_reduce(inspected, CollectPage).0
    assert_eq(collected.collection.items.length(), 1)
    let titled = book_search_reduce(
        collected,
        Collection(Title("Aurora interview evidence")),
      ).0
    let archive = book_collection_archive(titled.collection)
    let draft = book_search_reduce(
        book_search_initial(),
        Collection(ArchiveDraft(archive)),
      ).0
    let resumed = book_search_reduce(draft, Collection(ResumeArchive)).0
    assert_eq(resumed.collection.items, titled.collection.items)
    let html = search_test_html(inspected)
    assert_true(html.contains("00:12:34.500"))
    assert_true(html.contains("Mei &amp; Lin"))
    assert_true(html.contains("&lt;script&gt;literal example&lt;/script&gt;"))
    let expected = book_collection_brief(resumed.collection)
    assert_true(expected.contains("跨团队复盘"))
    assert_true(expected.contains("[00:12:34.500 --> 00:12:40.000] Mei & Lin:"))
    assert_true(expected.contains("raw/imported/transcript.vtt"))
    let capture = search_export_capture_start()
    guard book_search_reduce(resumed, Collection(DownloadBrief)).1
      is [ExportCollection(_, text, download)] else {
      fail("no transcript brief export")
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
      fail("no production download Blob")
    }
    assert_eq(brief, expected)
    let _ : Bool = transcript_source_save(brief, archive).wait().cast()
  })
}
