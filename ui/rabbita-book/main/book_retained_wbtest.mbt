///|
fn retained_test_source() -> BookRetainedSource {
  {
    reference: "raw/source.txt",
    page_digest: "sha256:" + "a".repeat(64),
    digest: "sha256:" + "b".repeat(64),
    size: 2,
    bytes_base64: "SGk=",
    text: Some("Hi"),
  }
}

///|
fn retained_test_page() -> BookSearchPage {
  let source = retained_test_source()
  {
    schema: "moonbook.search.v1",
    ok: true,
    question: "Lunar",
    citation: "wiki/sources/route.md",
    content: "Maintained summary only",
    page: None,
    retained_source: Some({
      reference: source.reference,
      page_digest: source.page_digest,
    }),
  }
}

///|
fn retained_test_ready() -> BookSearchState {
  let page = retained_test_page()
  let selected = book_search_reduce(search_test_ready(), Inspect(page.citation)).0
  book_search_reduce(
    selected,
    Inspected(selected.page_request, page.citation, Ok(page)),
  ).0
}

///|
test "retained reader new search edit selection reinspection repeated click reload and wrong identities discard stale bytes" {
  let ready = retained_test_ready()
  let source = retained_test_source()
  let (pending, effects) = book_search_reduce(ready, ReadRetained)
  assert_true(
    effects is [ReadSource(_, "Lunar", "wiki/sources/route.md", _, _)],
  )
  let reply = BookSearchMsg::Retained(
    pending.source_request,
    "Lunar",
    "wiki/sources/route.md",
    source.page_digest,
    Ok(source),
  )
  let loaded = book_search_reduce(pending, reply).0
  assert_eq(loaded.source, Some(source))
  assert_true(
    book_search_reduce(loaded, DownloadRetained).1 is [ExportSource(_, bytes)] &&
    bytes == source,
  )
  for
    event in [
      BookSearchMsg::Edit("New question"),
      Search,
      Inspect("wiki/sources/route.md"),
      ReadRetained,
    ] {
    let newer = book_search_reduce(loaded, event).0
    assert_true(newer.source is None)
    assert_true(book_search_reduce(newer, reply).0.source is None)
    assert_true(book_search_reduce(newer, DownloadRetained).1.is_empty())
  }
  assert_true(book_search_reduce(book_search_initial(), reply).0.source is None)
  assert_true(
    book_search_reduce(book_search_initial(), DownloadRetained).1.is_empty(),
  )
  for
    wrong in [
      BookSearchMsg::Retained(
        pending.source_request,
        "Other",
        "wiki/sources/route.md",
        source.page_digest,
        Ok(source),
      ),
      Retained(
        pending.source_request,
        "Lunar",
        "wiki/sources/other.md",
        source.page_digest,
        Ok(source),
      ),
      Retained(
        pending.source_request,
        "Lunar",
        "wiki/sources/route.md",
        "sha256:" + "c".repeat(64),
        Ok(source),
      ),
      Retained(
        pending.source_request,
        "Lunar",
        "wiki/sources/route.md",
        source.page_digest,
        Ok({ ..source, reference: "raw/other.txt", }),
      ),
    ] {
    assert_true(book_search_reduce(pending, wrong).0.source is None)
  }
  let failed = book_search_reduce(
      pending,
      Retained(
        pending.source_request,
        "Lunar",
        "wiki/sources/route.md",
        source.page_digest,
        Err("Binding changed"),
      ),
    ).0
  assert_eq(failed.page, ready.page)
  assert_true(failed.source is None)
  assert_true(search_test_html(failed).contains("Binding changed"))
  let html = search_test_html(loaded)
  assert_true(html.contains("Complete page text"))
  assert_true(html.contains("Complete retained UTF-8 text"))
  assert_true(html.contains("Retained bytes at inspection"))
  assert_true(html.contains("Download inspected retained bytes"))
  assert_true(
    search_test_html({ ..loaded, source: Some({ ..source, text: None, }), }).contains(
      "No active preview",
    ),
  )
  let unavailable = {
    ..ready,
    page: Some({ ..retained_test_page(), retained_source: None, }),
  }
  assert_true(book_search_reduce(unavailable, ReadRetained).1.is_empty())
  assert_true(
    search_test_html(unavailable).contains("Retained source unavailable"),
  )
  let nullable : Json = {
    "schema": "moonbook.search.v1",
    "ok": true,
    "question": "Lunar",
    "citation": "wiki/sources/route.md",
    "content": "Readable page",
    "retained_source": Json::null(),
  }
  assert_true(
    book_search_decode_page(
      nullable.stringify(),
      "Lunar",
      "wiki/sources/route.md",
    )
    is Ok({ retained_source: None, .. }),
  )
}

///|
extern "js" fn retained_native_wire() -> @js.Promise =
  #| async () => { const path = globalThis.process?.env?.MOONBOOK_RETAINED_WIRE; return path ? await (await import('node:fs/promises')).readFile(path,'utf8') : ''; }

///|
extern "js" fn retained_native_binary_wire() -> @js.Promise =
  #| async () => { const path = globalThis.process?.env?.MOONBOOK_RETAINED_BINARY_WIRE; return path ? await (await import('node:fs/promises')).readFile(path,'utf8') : ''; }

///|
extern "js" fn retained_export_finish(
  state : @js.Value,
  suffix : String,
) -> @js.Promise =
  #| async (state, suffix) => {
  #|   const bytes = new Uint8Array(await state.blob.arrayBuffer());
  #|   const result = {base64:btoa(Array.from(bytes, b=>String.fromCharCode(b)).join('')),size:bytes.length,filename:state.filename,clicked:state.click,type:state.blob.type};
  #|   if(state.nav)Object.defineProperty(globalThis,'navigator',state.nav);else delete globalThis.navigator;
  #|   globalThis.document=state.doc; URL.createObjectURL=state.create; URL.revokeObjectURL=state.revoke;
  #|   const output=globalThis.process?.env?.MOONBOOK_RETAINED_UI_RECEIPT;
  #|   if(output)await (await import('node:fs/promises')).writeFile(output + suffix,JSON.stringify(result,null,2));
  #|   return JSON.stringify(result);
  #| }

///|
test "retained actual native HTTP wire through compiled UI decoder reducer escaped complete view and exact Blob download" {
  book_test_async(async fn() {
    let input : String = retained_native_wire().wait().cast()
    if input.is_empty() {
      return
    }
    guard @json.parse(input)
      is {
        "book_unchanged": true,
        "wire": {
          "socket_verified": true,
          "question": String(question),
          "citation": String(citation),
          "response": search,
          "inspect_response": inspect_,
          "source_response": retained,
          "expected_base64": String(expected),
          "expected_text": String(expected_text),
          ..
        },
        ..
      } else {
      fail("missing actual native socket and unchanged metadata evidence")
    }
    guard book_search_decode(search.stringify(), question) is Ok(result) else {
      fail("search decoder failed")
    }
    guard book_search_decode_page(inspect_.stringify(), question, citation)
      is Ok(page) &&
      page.retained_source is Some(descriptor) else {
      fail("inspect decoder failed")
    }
    let fixture = search_capture_transport(retained.stringify())
    let payload : Json = {
      "question": question,
      "citation": citation,
      "page_digest": descriptor.page_digest,
    }
    guard book_search_post("/api/book/query/retained-source", payload, send=(
        method_,
        route,
        body,
      ) => search_send_capture(fixture, method_, route, body))
      is Ok(text) else {
      fail("retained transport failed")
    }
    guard book_search_decode_source(text, question, citation, descriptor)
      is Ok(source) else {
      fail("retained decoder failed")
    }
    let verified : Bool = book_search_verify_source(
        source.bytes_base64,
        source.digest,
        source.size,
        source.text,
      )
      .wait()
      .cast()
    assert_true(verified)
    assert_eq(source.bytes_base64, expected)
    assert_eq(source.text, Some(expected_text))
    assert_eq(@json.parse(search_captured_calls(fixture)), [
      {
        "method": "POST",
        "route": "/api/book/query/retained-source",
        "body": payload,
      },
    ])
    assert_true(
      book_search_decode_source(text, "wrong", citation, descriptor) is Err(_),
    )
    assert_true(
      book_search_decode_source(
        text, question, "wiki/sources/wrong.md", descriptor,
      )
      is Err(_),
    )
    assert_true(
      book_search_decode_source(text, question, citation, {
        ..descriptor,
        page_digest: "sha256:" + "a".repeat(64),
      })
      is Err(_),
    )
    let invalid = try {
      let _ : Bool = book_search_verify_source(
          source.bytes_base64,
          "sha256:" + "0".repeat(64),
          source.size,
          source.text,
        )
        .wait()
        .cast()
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
    let loading = book_search_reduce(
        book_search_reduce(book_search_initial(), Edit(question)).0,
        Search,
      ).0
    let ready = book_search_reduce(
        loading,
        Loaded(loading.request, question, Ok(result)),
      ).0
    let selecting = book_search_reduce(ready, Inspect(citation)).0
    let selected = book_search_reduce(
        selecting,
        Inspected(selecting.page_request, citation, Ok(page)),
      ).0
    let reading = book_search_reduce(selected, ReadRetained).0
    let displayed = book_search_reduce(
        reading,
        Retained(
          reading.source_request,
          question,
          citation,
          descriptor.page_digest,
          Ok(source),
        ),
      ).0
    let html = search_test_html(displayed)
    assert_true(html.contains("Final line beyond ingest excerpt."))
    assert_true(
      html.contains("海风🛰️ &lt;script&gt;inactive()&lt;/script&gt;"),
    )
    assert_false(html.contains("<script>inactive()"))
    guard book_search_reduce(displayed, DownloadRetained).1
      is [ExportSource(_, snapshot)] else {
      fail("exact download snapshot missing")
    }
    assert_eq(snapshot, source)
    let capture = search_export_capture_start()
    let _ : String = book_search_download_source(
        snapshot.bytes_base64,
        snapshot.reference,
      )
      .wait()
      .cast()
    let receipt : String = retained_export_finish(capture, "").wait().cast()
    guard @json.parse(receipt)
      is {
        "base64": String(downloaded),
        "clicked": true,
        "type": "application/octet-stream",
        "filename": "moonbook-retained-retained.md",
        ..
      } else {
      fail("exact download missing")
    }
    assert_eq(downloaded, expected)
  })
}

///|
test "retained binary native HTTP wire remains exact in compiled UI download without active preview" {
  book_test_async(async fn() {
    let input : String = retained_native_binary_wire().wait().cast()
    if input.is_empty() {
      return
    }
    guard @json.parse(input)
      is {
        "response": response,
        "page_digest": String(page_digest),
        "socket_verified": true,
        ..
      } else {
      fail("binary native HTTP evidence missing")
    }
    let descriptor : BookRetainedDescriptor = {
      reference: "raw/source.bin",
      page_digest,
    }
    guard book_search_decode_source(
        response.stringify(),
        "Lunar",
        "wiki/sources/retained.md",
        descriptor,
      )
      is Ok(source) else {
      fail("binary decoding failed")
    }
    assert_true(source.text is None)
    assert_eq(source.bytes_base64, "AP8BDQo=")
    let verified : Bool = book_search_verify_source(
        source.bytes_base64,
        source.digest,
        source.size,
        source.text,
      )
      .wait()
      .cast()
    assert_true(verified)
    let capture = search_export_capture_start()
    let _ : String = book_search_download_source(
        source.bytes_base64,
        source.reference,
      )
      .wait()
      .cast()
    let receipt : String = retained_export_finish(capture, ".binary")
      .wait()
      .cast()
    guard @json.parse(receipt)
      is {
        "base64": "AP8BDQo=",
        "size": 5,
        "clicked": true,
        "type": "application/octet-stream",
        "filename": "moonbook-retained-source.bin",
        ..
      } else {
      fail("binary bytes were transformed")
    }
  })
}
