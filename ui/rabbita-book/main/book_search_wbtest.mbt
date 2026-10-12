///|
fn search_test_result(question? : String = "Lunar") -> BookSearchResult {
  {
    schema: "moonbook.search.v1",
    ok: true,
    question,
    mode: "lexical-excerpts",
    saved: false,
    paging: None,
    excerpts: [
      {
        citation: "wiki/sources/route.md",
        title: "Lunar <script>title</script>",
        excerpt: "Exact <img src=x onerror=oops> & 海风",
        score: 12,
        metadata_status: "accepted",
      },
    ],
    brief: "Exact context 海风 <script>not HTML</script>\n",
  }
}

///|
fn search_test_ready() -> BookSearchState {
  let (edited, _) = book_search_reduce(book_search_initial(), Edit("Lunar"))
  let (pending, _) = book_search_reduce(edited, Search)
  book_search_reduce(
    pending,
    Loaded(pending.request, "Lunar", Ok(search_test_result())),
  ).0
}

///|
fn search_test_html(state : BookSearchState) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(model=state, update=fn(_msg : Msg, old) { old }, view=fn(
      emit,
      model,
    ) {
      book_search_panel(emit, model)
    }),
  )
}

///|
test "search preserves previous success rejects stale fast requests and cannot select arbitrary citations" {
  let ready = search_test_ready()
  let (first, _) = book_search_reduce(ready, Search)
  let (second, _) = book_search_reduce(first, Search)
  let stale = book_search_reduce(
      second,
      Loaded(first.request, "Lunar", Ok(search_test_result(question="wrong"))),
    ).0
  assert_true(stale.pending)
  assert_eq(stale.result, ready.result)
  let failed = book_search_reduce(
      stale,
      Loaded(second.request, "Lunar", Err("offline")),
    ).0
  assert_false(failed.pending)
  assert_eq(failed.result, ready.result)
  let (changed, _) = book_search_reduce(first, Edit("New question"))
  let old = book_search_reduce(
      changed,
      Loaded(first.request, "Lunar", Ok(search_test_result())),
    ).0
  assert_eq(old.draft, "New question")
  assert_false(old.pending)
  assert_eq(old.result, ready.result)
  assert_true(
    book_search_reduce(ready, Inspect("../../elsewhere.md")).1.is_empty(),
  )
  let (inspecting, _) = book_search_reduce(
    ready,
    Inspect("wiki/sources/route.md"),
  )
  let (new_inspection, _) = book_search_reduce(
    inspecting,
    Inspect("wiki/sources/route.md"),
  )
  let page : BookSearchPage = {
    schema: "moonbook.search.v1",
    ok: true,
    question: "Lunar",
    citation: "wiki/sources/route.md",
    content: "Exact current page",
    retained_source: None,
    page: None,
  }
  let late = book_search_reduce(
      new_inspection,
      Inspected(inspecting.page_request, page.citation, Ok(page)),
    ).0
  assert_true(late.page_pending)
  assert_true(late.page is None)
  let inspected = book_search_reduce(
      late,
      Inspected(late.page_request, page.citation, Ok(page)),
    ).0
  let again = book_search_reduce(inspected, Inspect(page.citation)).0
  let unavailable = book_search_reduce(
      again,
      Inspected(again.page_request, page.citation, Err("unreadable")),
    ).0
  assert_eq(unavailable.page, None)
  assert_true(unavailable.page_error is Some(_))
}

///|
test "search empty limits no match and escaped titles excerpts page text" {
  assert_true(book_search_reduce(book_search_initial(), Search).1.is_empty())
  let too_long = { ..book_search_initial(), draft: "x".repeat(1025), }
  assert_true(book_search_reduce(too_long, Search).1.is_empty())
  let result = search_test_result()
  let html = search_test_html(search_test_ready())
  assert_true(html.contains("Search this Book"))
  assert_true(html.contains("Lunar &lt;script&gt;title&lt;/script&gt;"))
  assert_false(html.contains("<script>title"))
  assert_false(html.contains("<img src=x"))
  assert_true(html.contains("Page metadata status (unverified): accepted"))
  assert_true(html.contains("<details><summary>"))
  assert_true(html.contains("Copy context brief"))
  assert_true(html.contains("Download context brief"))
  assert_eq(
    book_search_decode(result.to_json().stringify(), "Lunar"),
    Ok(result),
  )
  assert_true(
    book_search_decode(result.to_json().stringify(), "other") is Err(_),
  )
  assert_true(book_search_decode("{}", "Lunar") is Err(_))
  let unsafe = {
    ..result,
    excerpts: [{ ..result.excerpts[0], citation: "wiki/../outside.md", }],
  }
  assert_true(
    book_search_decode(unsafe.to_json().stringify(), "Lunar") is Err(_),
  )
  let empty = { ..result, excerpts: [], }
  assert_true(
    search_test_html({ ..search_test_ready(), result: Some(empty), }).contains(
      "No matching maintained pages found",
    ),
  )
  match book_search_reduce(search_test_ready(), Copy).1 {
    [Export(question, text, download)] => {
      assert_eq(question, result.question)
      assert_eq(text, result.brief)
      assert_false(download)
    }
    _ => fail("copy must use the exact displayed result's brief")
  }
}

///|
extern "js" fn search_native_wire() -> @js.Promise =
  #| async () => { const path = globalThis.process?.env?.MOONBOOK_SEARCH_WIRE; return path ? await (await import('node:fs/promises')).readFile(path, 'utf8') : ''; }

///|
extern "js" fn search_capture_transport(response : String) -> @js.Value =
  #| response => ({ response, calls: [] })

///|
extern "js" fn search_send_capture(
  fixture : @js.Value,
  method_ : String,
  route : String,
  body : String,
) -> @js.Promise =
  #| async (fixture, method, route, body) => { fixture.calls.push({method, route, body: JSON.parse(body)}); return JSON.stringify({ok:true,status:200,body:fixture.response}); }

///|
extern "js" fn search_captured_calls(fixture : @js.Value) -> String =
  #| fixture => JSON.stringify(fixture.calls)

///|
extern "js" fn search_export_capture_start() -> @js.Value =
  #| () => {
  #|   const state = { clipboard: '', blob: null, filename: '', click: false, nav: Object.getOwnPropertyDescriptor(globalThis,'navigator'), doc: globalThis.document, create: URL.createObjectURL, revoke: URL.revokeObjectURL };
  #|   Object.defineProperty(globalThis,'navigator',{ configurable:true, value:{clipboard:{writeText:async text=>{state.clipboard=text;}}} });
  #|   globalThis.document={body:{appendChild(){}},createElement(){return {set download(value){state.filename=value}, click(){state.click=true},remove(){}}}};
  #|   URL.createObjectURL=blob=>{state.blob=blob; return 'blob:captured';}; URL.revokeObjectURL=()=>{};
  #|   return state;
  #| }

///|
extern "js" fn search_export_capture_finish(state : @js.Value) -> @js.Promise =
  #| async state => {
  #|   const result={clipboard:state.clipboard,download:await state.blob.text(),filename:state.filename,clicked:state.click};
  #|   if(state.nav)Object.defineProperty(globalThis,'navigator',state.nav);else delete globalThis.navigator;
  #|   globalThis.document=state.doc;URL.createObjectURL=state.create;URL.revokeObjectURL=state.revoke;
  #|   const output=globalThis.process?.env?.MOONBOOK_SEARCH_UI_RECEIPT;
  #|   if(output)await (await import('node:fs/promises')).writeFile(output,JSON.stringify(result,null,2));
  #|   return JSON.stringify(result);
  #| }

///|
test "real native Book host wire crosses production browser decoder view clipboard and download with exact parity" {
  @js.async_test(async fn() {
    let text : String = search_native_wire().wait().cast()
    if text.is_empty() {
      return
    }
    let wire = @json.parse(text)
    guard wire
      is {
        "question": String(question),
        "response": response,
        "inspect_response": inspected,
        "expected_brief": String(expected_brief),
        "expected_page": String(expected_page),
        "native_excerpts": native_excerpts,
        "book_unchanged": true,
        "socket_verified": true,
        ..
      } else {
      fail("missing native crossing evidence")
    }
    let fixture = search_capture_transport(response.stringify())
    let payload : Json = { "question": question }
    let transport = book_search_post("/api/book/query", payload, send=(
      method_,
      route,
      body,
    ) => search_send_capture(fixture, method_, route, body))
    guard transport is Ok(body) else {
      fail("browser transport rejected native wire")
    }
    guard book_search_decode(body, question) is Ok(result) else {
      fail("native response failed real decoder")
    }
    assert_eq(result.excerpts.to_json(), native_excerpts)
    assert_eq(result.brief, expected_brief)
    assert_eq(@json.parse(search_captured_calls(fixture)), [
      { "method": "POST", "route": "/api/book/query", "body": payload },
    ])
    let edited = book_search_reduce(book_search_initial(), Edit(question)).0
    let loading = book_search_reduce(edited, Search).0
    let ready = book_search_reduce(
        loading,
        Loaded(loading.request, question, Ok(result)),
      ).0
    let html = search_test_html(ready)
    for item in result.excerpts {
      assert_true(html.contains(item.citation))
    }
    assert_true(html.contains("海风 Lunar &lt;script&gt;"))
    assert_false(html.contains("<script>alert("))
    let citation = result.excerpts[0].citation
    guard book_search_decode_page(inspected.stringify(), question, citation)
      is Ok(page) else {
      fail("native page failed decoder")
    }
    assert_eq(page.content, expected_page)
    let selected = book_search_reduce(ready, Inspect(citation)).0
    let inspected_state = book_search_reduce(
        selected,
        Inspected(selected.page_request, citation, Ok(page)),
      ).0
    let full_html = search_test_html(inspected_state)
    assert_true(full_html.contains("Final complete page line."))
    assert_false(full_html.contains("<script>alert("))
    let capture = search_export_capture_start()
    for msg in [BookSearchMsg::Copy, Download] {
      guard book_search_reduce(ready, msg).1 is [Export(_, content, download)] else {
        fail("missing export")
      }
      assert_eq(content, expected_brief)
      let _ : String = book_search_export(content, download).wait().cast()
    }
    let exported : String = search_export_capture_finish(capture).wait().cast()
    guard @json.parse(exported)
      is {
        "clipboard": String(copied),
        "download": String(downloaded),
        "filename": "moonbook-context.txt",
        "clicked": true,
        ..
      } else {
      fail("browser export missing")
    }
    assert_eq(copied, expected_brief)
    assert_eq(downloaded, expected_brief)
  })
}
