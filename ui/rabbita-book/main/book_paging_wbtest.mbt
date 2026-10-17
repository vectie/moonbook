///|
fn paging_test_result(page : Int32) -> BookSearchResult {
  let base = search_test_result()
  let count = if page == 0 { 3 } else { 1 }
  {
    ..base,
    paging: Some({
      page,
      page_size: 3,
      matched_count: 4,
      window_count: 4,
      has_next: page == 0,
      truncated: false,
      fresh_scan: true,
    }),
    excerpts: Array::makei(count, index => {
      ..base.excerpts[0],
      citation: "wiki/sources/p-" + (page * 3 + index).to_string() + ".md",
    }),
    brief: "Exact displayed page " + page.to_string() + " 海风\n",
  }
}

///|
fn paging_test_ready() -> BookSearchState {
  let pending = book_search_reduce(
      { ..book_search_initial(), draft: "Lunar", },
      Search,
    ).0
  book_search_reduce(
    pending,
    Loaded(pending.request, "Lunar", Ok(paging_test_result(0))),
  ).0
}

///|
test "paging navigation scopes all callbacks and exact export to displayed query page citation" {
  let ready = paging_test_ready()
  assert_true(book_search_reduce(ready, Navigate(-1)).1.is_empty())
  assert_true(book_search_reduce(ready, Navigate(9)).1.is_empty())
  let (pending, effects) = book_search_reduce(ready, Navigate(1))
  assert_true(effects is [Query(_, "Lunar", 1)])
  assert_eq(pending.requested_page, 1)
  assert_true(
    book_search_reduce(pending, Inspect("wiki/sources/p-0.md")).1.is_empty(),
  )
  let wrong = book_search_reduce(
      pending,
      Loaded(pending.request, "Lunar", Ok(paging_test_result(0))),
    ).0
  assert_true(wrong.error is Some(_))
  assert_eq(wrong.result, ready.result)
  let later = book_search_reduce(
      pending,
      Loaded(pending.request, "Lunar", Ok(paging_test_result(1))),
    ).0
  let result = paging_test_result(1)
  assert_eq(later.result, Some(result))
  assert_true(book_search_reduce(later, Navigate(2)).1.is_empty())
  let citation = result.excerpts[0].citation
  let (selecting, effect) = book_search_reduce(later, Inspect(citation))
  assert_true(effect is [ReadPage(_, "Lunar", _, Some(1))])
  let page = { ..retained_test_page(), citation, page: Some(1), }
  let selected = book_search_reduce(
      selecting,
      Inspected(selecting.page_request, citation, Ok(page)),
    ).0
  let reading = book_search_reduce(selected, ReadRetained).0
  let previous = book_search_reduce(reading, Navigate(0)).0
  assert_true(previous.page is None)
  assert_true(previous.source is None)
  let stale = book_search_reduce(
      previous,
      Inspected(selecting.page_request, citation, Ok(page)),
    ).0
  assert_true(stale.page is None)
  let stale_source = book_search_reduce(
      previous,
      Retained(
        reading.source_request,
        "Lunar",
        citation,
        retained_test_source().page_digest,
        Ok(retained_test_source()),
      ),
    ).0
  assert_true(stale_source.source is None)
  let changed = book_search_reduce(pending, Edit("new question")).0
  assert_true(
    book_search_reduce(changed, Loaded(pending.request, "Lunar", Ok(result))).0.result ==
    ready.result,
  )
  let wrong_page = { ..page, page: Some(0), }
  assert_true(
    book_search_reduce(
      selecting,
      Inspected(selecting.page_request, citation, Ok(wrong_page)),
    ).0.page
    is None,
  )
  let stale_export = book_search_reduce(
      later,
      Exported("Lunar", paging_test_result(0).brief, Ok("wrong page copied")),
    ).0
  assert_true(stale_export.notice is None)
  for msg in [BookSearchMsg::Copy, Download] {
    assert_true(
      book_search_reduce(later, msg).1 is [Export("Lunar", text, _)] &&
      text == result.brief,
    )
  }
  let html = search_test_html(later)
  assert_true(html.contains("Results page 2"))
  assert_true(html.contains("[4] Lunar"))
  assert_true(html.contains("Next results"))
  assert_true(html.contains("Rankings can change"))
  assert_eq(
    book_search_decode(result.to_json().stringify(), "Lunar"),
    Ok(result),
  )
  let invalid = {
    ..result,
    paging: Some({ ..result.paging.unwrap(), has_next: true, }),
  }
  assert_true(
    book_search_decode(invalid.to_json().stringify(), "Lunar") is Err(_),
  )
  let truncated = {
    ..result,
    paging: Some({
      page: 9,
      page_size: 3,
      matched_count: 35,
      window_count: 30,
      has_next: false,
      truncated: true,
      fresh_scan: true,
    }),
  }
  assert_true(
    search_test_html({ ..later, result: Some(truncated), }).contains(
      "Results truncated to the first 30 matches",
    ),
  )
  let empty_page = {
    ..result,
    excerpts: [],
    paging: Some({
      ..result.paging.unwrap(),
      matched_count: 3,
      window_count: 3,
    }),
  }
  assert_eq(
    book_search_decode(empty_page.to_json().stringify(), "Lunar"),
    Ok(empty_page),
  )
  let empty_html = search_test_html({ ..later, result: Some(empty_page), })
  assert_true(empty_html.contains("other pages still match"))
  assert_false(empty_html.contains("No matching maintained pages found"))
}

///|
extern "js" fn paging_native_wire() -> @js.Promise =
  #| async () => { const path=globalThis.process?.env?.MOONBOOK_PAGING_WIRE; return path ? await (await import('node:fs/promises')).readFile(path,'utf8') : ''; }

///|
extern "js" fn paging_record_receipt(text : String) -> @js.Promise =
  #| async text => { const path=globalThis.process?.env?.MOONBOOK_PAGING_UI_RECEIPT; if(path) await (await import('node:fs/promises')).writeFile(path,text); return true; }

///|
extern "js" fn paging_export_capture_finish(state : @js.Value) -> @js.Promise =
  #| async state => {
  #|   const result={clipboard:state.clipboard,download:await state.blob.text(),filename:state.filename,clicked:state.click};
  #|   if(state.nav)Object.defineProperty(globalThis,'navigator',state.nav);else delete globalThis.navigator;
  #|   globalThis.document=state.doc;URL.createObjectURL=state.create;URL.revokeObjectURL=state.revoke;
  #|   return JSON.stringify(result);
  #| }

///|
test "paged actual native socket crosses compiled UI later navigation inspection retained source and exact clipboard Blob" {
  book_test_async(async fn() {
    let input : String = paging_native_wire().wait().cast()
    if input.is_empty() {
      return
    }
    guard @json.parse(input)
      is {
        "book_unchanged": true,
        "wire": {
          "socket_verified": true,
          "first_response": first,
          "response": response,
          "inspect_response": inspect_,
          "source_response": retained,
          "expected_page": String(expected_page),
          "expected_source": String(expected_source),
          "expected_brief": String(expected_brief),
          ..
        },
        ..
      } else {
      fail("actual socket evidence missing")
    }
    guard book_search_decode(first.stringify(), "Lunar") is Ok(first) else {
      fail("first page decoder")
    }
    let loading = book_search_reduce(
        { ..book_search_initial(), draft: "Lunar", },
        Search,
      ).0
    let first_state = book_search_reduce(
        loading,
        Loaded(loading.request, "Lunar", Ok(first)),
      ).0
    let next = book_search_reduce(first_state, Navigate(1)).0
    assert_eq(next.requested_page, 1)
    let fixture = search_capture_transport(response.stringify())
    let payload : Json = { "question": "Lunar", "page": 1 }
    guard book_search_post("/api/book/query", payload, send=(
        method_,
        route,
        body,
      ) => search_send_capture(fixture, method_, route, body))
      is Ok(body) else {
      fail("transport")
    }
    guard book_search_decode(body, "Lunar") is Ok(result) else {
      fail("later page decoder")
    }
    assert_eq(@json.parse(search_captured_calls(fixture)), [
      { "method": "POST", "route": "/api/book/query", "body": payload },
    ])
    assert_eq(result.brief, expected_brief)
    let ready = book_search_reduce(
        next,
        Loaded(next.request, "Lunar", Ok(result)),
      ).0
    assert_eq(ready.result, Some(result))
    let citation = "wiki/sources/later.md"
    guard book_search_decode_page(
        inspect_.stringify(),
        "Lunar",
        citation,
        results_page=1,
      )
      is Ok(page) &&
      page.retained_source is Some(descriptor) else {
      fail("later inspection")
    }
    assert_true(
      book_search_decode_page(
        inspect_.stringify(),
        "Lunar",
        citation,
        results_page=0,
      )
      is Err(_),
    )
    assert_eq(page.content, expected_page)
    let selecting = book_search_reduce(ready, Inspect(citation)).0
    let selected = book_search_reduce(
        selecting,
        Inspected(selecting.page_request, citation, Ok(page)),
      ).0
    guard book_search_decode_source(
        retained.stringify(),
        "Lunar",
        citation,
        descriptor,
        results_page=1,
      )
      is Ok(source) else {
      fail("retained later page decoder")
    }
    assert_true(
      book_search_decode_source(
        retained.stringify(),
        "Lunar",
        citation,
        descriptor,
        results_page=0,
      )
      is Err(_),
    )
    assert_eq(source.text, Some(expected_source))
    let verified : Bool = book_search_verify_source(
        source.bytes_base64,
        source.digest,
        source.size,
        source.text,
      )
      .wait()
      .cast()
    assert_true(verified)
    let reading = book_search_reduce(selected, ReadRetained).0
    let displayed = book_search_reduce(
        reading,
        Retained(
          reading.source_request,
          "Lunar",
          citation,
          descriptor.page_digest,
          Ok(source),
        ),
      ).0
    let html = search_test_html(displayed)
    assert_true(html.contains("Results page 2"))
    assert_true(
      html.contains(
        "Final complete later page line 海风 &lt;script&gt;inactive&lt;/script&gt;",
      ),
    )
    assert_true(html.contains("Complete retained later-page bytes 海风"))
    assert_false(html.contains("<script>inactive"))
    let capture = search_export_capture_start()
    for msg in [BookSearchMsg::Copy, Download] {
      guard book_search_reduce(displayed, msg).1
        is [Export(_, content, download)] else {
        fail("export")
      }
      assert_eq(content, expected_brief)
      let _ : String = book_search_export(content, download).wait().cast()
    }
    let receipt : String = paging_export_capture_finish(capture).wait().cast()
    guard @json.parse(receipt)
      is {
        "clipboard": String(copied),
        "download": String(downloaded),
        "clicked": true,
        ..
      } else {
      fail("missing clipboard and Blob")
    }
    assert_eq(copied, expected_brief)
    assert_eq(downloaded, expected_brief)
    guard book_search_reduce(displayed, DownloadRetained).1
      is [ExportSource(_, snapshot)] else {
      fail("later retained download missing")
    }
    assert_eq(snapshot, source)
    let source_capture = search_export_capture_start()
    let _ : String = book_search_download_source(
        snapshot.bytes_base64,
        snapshot.reference,
      )
      .wait()
      .cast()
    let source_receipt : String = retained_export_finish(
        source_capture, ".paging",
      )
      .wait()
      .cast()
    guard @json.parse(source_receipt)
      is { "base64": String(downloaded_source), "clicked": true, .. } else {
      fail("later retained Blob missing")
    }
    assert_eq(downloaded_source, source.bytes_base64)
    let _ : Bool = paging_record_receipt(
        (
          {
            "socket_verified": true,
            "page": 1,
            "citation": citation,
            "book_unchanged": true,
            "brief": expected_brief,
            "clipboard": copied,
            "download": downloaded,
            "source_digest": source.digest,
            "escaped_view": true,
          } : Json).stringify(indent=2),
      )
      .wait()
      .cast()
  })
}
