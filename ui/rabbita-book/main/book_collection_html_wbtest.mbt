///|
fn html_brief_fixture() -> BookCollectionState {
  let before = restore_fixture()
  let first : BookCollectionItem = {
    title: "Capacity <Q4> & \"plan\" 海风😀",
    note: "  Researcher note only: reconcile eight vs twelve.\r\n<script>note()</script>\n",
    page: {
      ..before.items[0].page,
      question: "What supports launch? <&> é",
      citation: "wiki/sources/<capacity>&\".md",
      page: Some(1),
      content: "\nSource-only evidence: 中文 😀 é\n\t12 teams proposed, 8 supported.\r\n</div><script>alert('x')</script><img src=\"https://invalid.test/x\" onerror=\"x()\">\n<script src='remote.js'></script>\n~~~\nLAST LINE 🌙\n",
      retained_source: Some({
        reference: "raw/<capacity>&\".txt",
        page_digest: "sha256:<supplied>&\"",
      }),
    },
  }
  {
    ..before,
    title: "Aurora research <brief> 海风😀",
    purpose: "Question: can the pilot support twelve teams?\nSynthesis: the capacity source supports eight.\n<iframe src=\"https://invalid.test\"></iframe>",
    items: [
      first,
      {
        ..before.items[1],
        title: "Capacity counterevidence",
        note: "",
        page: {
          ..before.items[1].page,
          content: "Eight teams supported.\nSECOND END",
          retained_source: None,
          page: None,
        },
      },
    ],
    history: [
      {
        ..before.history[0],
        note: "HISTORY NOTE EXCLUDED",
        page: {
          ..before.history[0].page,
          content: "HISTORY SNAPSHOT EXCLUDED",
        },
      },
    ],
  }
}

///|
extern "js" fn html_brief_structure(html : String, count : Int) -> Bool =
  #| (html, count) => {
  #|   const ids = [...html.matchAll(/\bid="([^"]*)"/g)].map(m => m[1]);
  #|   const hrefs = [...html.matchAll(/\bhref="([^"]*)"/g)].map(m => m[1]);
  #|   const tags = [...html.matchAll(/<\/?([a-zA-Z][a-zA-Z0-9]*)\b/g)].map(m => m[1].toLowerCase());
  #|   const allowed = new Set(['html','head','meta','title','style','body','main','header','p','h1','h2','h3','section','div','nav','ol','li','a','article','dl','dt','dd','span','footer']);
  #|   return new Set(ids).size === ids.length && ids.length === 2 + 3 * count && hrefs.every(h => h.startsWith('#') && ids.includes(h.slice(1))) && hrefs.length === 1 + 4 * count && tags.every(t => allowed.has(t)) && !/<[^>]*\s(?:src|on\w+|srcdoc)\s*=/i.test(html) && !/url\s*\(|@import/i.test(html);
  #| }

///|
extern "js" fn html_brief_before(
  html : String,
  first : String,
  second : String,
) -> Bool =
  #| (html, first, second) => html.indexOf(first) >= 0 && html.indexOf(first) < html.indexOf(second)

///|
test "HTML brief includes exact escaped full Unicode text and local navigation without history" {
  let state = html_brief_fixture()
  let before = book_collection_archive(state)
  let html = book_collection_html(state)
  assert_true(html.starts_with("<!doctype html>\n<html lang=\"en\">"))
  assert_true(html.contains("<meta charset=\"utf-8\">"))
  assert_true(html.contains("default-src 'none'"))
  assert_true(html.contains("@media print"))
  assert_true(html_brief_structure(html, 2))
  assert_true(html.contains("Aurora research &lt;brief&gt; 海风😀"))
  assert_true(html.contains("What supports launch? &lt;&amp;&gt; é"))
  assert_true(html.contains("wiki/sources/&lt;capacity&gt;&amp;&quot;.md"))
  assert_true(html.contains("raw/&lt;capacity&gt;&amp;&quot;.txt"))
  assert_true(html.contains("sha256:&lt;supplied&gt;&amp;&quot;"))
  assert_true(
    html.contains(
      "<div class=\"verbatim\">\nSource-only evidence: 中文 😀 é\n\t12 teams proposed, 8 supported.&#13;\n&lt;/div&gt;&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;&lt;img src=&quot;https://invalid.test/x&quot; onerror=&quot;x()&quot;&gt;\n&lt;script src=&#39;remote.js&#39;&gt;&lt;/script&gt;\n~~~\nLAST LINE 🌙\n</div>",
    ),
  )
  assert_true(
    html.contains(
      "  Researcher note only: reconcile eight vs twelve.&#13;\n&lt;script&gt;note()&lt;/script&gt;\n",
    ),
  )
  assert_true(html.contains("2 (one-based)"))
  assert_true(html.contains("Historical snapshots in the resumable JSON: 1"))
  assert_false(html.contains("HISTORY NOTE EXCLUDED"))
  assert_false(html.contains("HISTORY SNAPSHOT EXCLUDED"))
  assert_true(html_brief_before(html, "id=\"note-1\"", "id=\"snapshot-1\""))
  assert_true(html_brief_before(html, "LAST LINE 🌙", "SECOND END"))
  assert_eq(book_collection_archive(state), before)
  assert_eq(book_collection_html(state), html)
}

///|
test "HTML empty and missing metadata are explicit including empty supplied labels" {
  let empty = book_collection_initial()
  let html = book_collection_html(empty)
  assert_true(html_brief_structure(html, 0))
  assert_true(html.contains("No current selections"))
  assert_true(html.contains("No research question or synthesis supplied"))
  assert_true(book_collection_reduce(empty, DownloadHtml).1.is_empty())
  let before = html_brief_fixture()
  let item = {
    ..before.items[0],
    title: "",
    note: "",
    page: {
      ..before.items[0].page,
      question: "",
      content: "",
      retained_source: Some({ reference: "", page_digest: "", }),
      page: Some(2147483647),
    },
  }
  let html = book_collection_html({ ..before, items: [item, before.items[1]], })
  assert_true(html.contains("Untitled selection"))
  assert_true(html.contains("Not supplied (empty label)."))
  assert_true(html.contains("No researcher note supplied."))
  assert_true(html.contains("The supplied snapshot is empty."))
  assert_true(html.contains("Not supplied by the host for this page."))
  assert_true(html.contains("Not supplied by the inspection."))
  assert_true(html.contains("2147483648 (one-based)"))
  assert_true(
    html.contains("No retrieval timestamp or factual approval is inferred."),
  )
  assert_true(html_brief_structure(html, 2))
}

///|
test "HTML preserves maximum collection text authoring and metadata budgets without truncation" {
  let before = html_brief_fixture()
  let item = before.items[0]
  let state = {
    ..before,
    title: "T".repeat(160),
    purpose: "海".repeat(4000),
    items: Array::makei(12, i => {
      ..item,
      title: "t".repeat(16384),
      note: "n".repeat(4000),
      page: {
        ..item.page,
        citation: "c".repeat(4093) + i.to_string(),
        question: "q".repeat(16384),
        content: if i == 11 {
          "<&".repeat(524280) + "LAST END 😀 海风!!"
        } else {
          ""
        },
        retained_source: Some({
          reference: "r".repeat(4096),
          page_digest: "d".repeat(256),
        }),
      },
    }),
    history: Array::make(48, { ..item, page: { ..item.page, content: "", }, }),
  }
  // 1,048,560 + 16 UTF-16 code units; exactly the combined snapshot budget.
  assert_eq(state.items[11].page.content.length(), 1048576)
  assert_true(
    book_collection_decode_archive(book_collection_archive(state)) is Ok(_),
  )
  let html = book_collection_html(state)
  assert_true(html_brief_structure(html, 12))
  assert_true(
    html.contains("&lt;&amp;".repeat(524280) + "LAST END 😀 海风!!"),
  )
  assert_true(html.contains("海".repeat(4000)))
  assert_true(html.contains("n".repeat(4000)))
  assert_true(html.contains("r".repeat(4096)))
  assert_true(html.contains("Historical snapshots in the resumable JSON: 48"))
  let excess = {
    ..state,
    items: state.items.map(i => {
      ..i,
      page: { ..i.page, content: i.page.content + "x", },
    }),
  }
  assert_true(
    book_collection_decode_archive(book_collection_archive(excess)) is Err(_),
  )
  assert_eq(
    book_collection_reduce(state, Title("x".repeat(161))).0.title,
    state.title,
  )
  assert_eq(
    book_collection_reduce(state, Purpose("x".repeat(4001))).0.purpose,
    state.purpose,
  )
  assert_eq(
    book_collection_reduce(
      state,
      Note(state.items[0].page.citation, "x".repeat(4001)),
    ).0.items,
    state.items,
  )
}

///|
test "HTML download projects current edits order removal and ignores stale completions" {
  let before = html_brief_fixture()
  guard book_collection_reduce(before, DownloadHtml).1
    is [ExportCollectionHtml(revision, old_html)] else {
    fail("HTML effect missing")
  }
  assert_eq(revision, before.revision)
  let edited = book_collection_reduce(before, Title("CURRENT TITLE")).0
  let edited = book_collection_reduce(edited, Purpose("CURRENT SYNTHESIS")).0
  let edited = book_collection_reduce(
      edited,
      Note(edited.items[1].page.citation, "CURRENT NOTE"),
    ).0
  let moved = book_collection_reduce(
      edited,
      Move(edited.items[1].page.citation, -1),
    ).0
  assert_true(
    html_brief_before(
      book_collection_html(moved),
      "SECOND END",
      "LAST LINE 🌙",
    ),
  )
  let removed = book_collection_reduce(
      moved,
      Remove(before.items[0].page.citation),
    ).0
  guard book_collection_reduce(removed, DownloadHtml).1
    is [ExportCollectionHtml(_, current)] else {
    fail("HTML effect missing")
  }
  assert_true(current.contains("CURRENT TITLE"))
  assert_true(current.contains("CURRENT SYNTHESIS"))
  assert_true(current.contains("CURRENT NOTE"))
  assert_false(current.contains("LAST LINE 🌙"))
  assert_true(old_html.contains("LAST LINE 🌙"))
  assert_true(html_brief_structure(current, 1))
  let searched = book_collection_reduce(
      book_collection_reduce(removed, FindText("no match")).0,
      FindScope("history"),
    ).0
  assert_eq(book_collection_html(searched), current)
  for result in [Ok("stale success"), Err("stale error")] {
    let stale = book_collection_reduce(removed, ExportedBrief(revision, result)).0
    assert_eq(stale.notice, removed.notice)
    assert_eq(stale.items, removed.items)
  }
  let current_notice = book_collection_reduce(
      removed,
      ExportedBrief(removed.revision, Ok("download requested")),
    ).0
  assert_eq(current_notice.notice, Some("download requested"))
  let ui = search_test_html({ ..book_search_initial(), collection: searched, })
  assert_true(ui.contains("Download offline brief (.html)"))
  assert_true(ui.contains("Neither reading format resumes a collection"))
}

///|
extern "js" fn html_brief_capture_start(fail_click : Bool) -> @js.Value =
  #| failClick => {
  #|   const s={doc:globalThis.document,create:URL.createObjectURL,revoke:URL.revokeObjectURL,timer:globalThis.setTimeout,blob:null,filename:'',clicked:false,removed:false,revoked:false,timers:[]};
  #|   globalThis.document={body:{appendChild(){}},createElement(tag){if(tag!=='a')throw Error('unexpected element');return {set download(v){s.filename=v},click(){if(failClick)throw Error('download blocked');s.clicked=true},remove(){s.removed=true}}}};
  #|   URL.createObjectURL=blob=>{s.blob=blob;return 'blob:html-brief-fixture'};URL.revokeObjectURL=url=>{if(url==='blob:html-brief-fixture')s.revoked=true};
  #|   globalThis.setTimeout=(fn,delay)=>{if(delay===1000){fn();return 0}return s.timer(fn,delay)};
  #|   return s;
  #| }

///|
extern "js" fn html_brief_capture_finish(
  s : @js.Value,
  expected : String,
) -> @js.Promise =
  #| async (s,expected) => {
  #|   try {for(const fn of s.timers)fn();const bytes=Buffer.from(await s.blob.arrayBuffer());return JSON.stringify({text:await s.blob.text(),mime:s.blob.type,filename:s.filename,size:s.blob.size,byteCount:bytes.length,bytesExact:bytes.equals(Buffer.from(expected,'utf8')),clicked:s.clicked,removed:s.removed,revoked:s.revoked});}
  #|   finally {globalThis.document=s.doc;URL.createObjectURL=s.create;URL.revokeObjectURL=s.revoke;globalThis.setTimeout=s.timer;}
  #| }

///|
extern "js" fn html_brief_tick() -> @js.Promise =
  #| async () => { await Promise.resolve(); await Promise.resolve(); }

///|
extern "js" fn html_brief_evidence(
  archive : String,
  html : String,
  receipt : String,
  ui : String,
  markdown : String,
) -> @js.Promise =
  #| async (archive,html,receipt,ui,markdown) => {const root=process.env.MOONBOOK_HTML_EVIDENCE;if(!root)return false;const fs=await import('node:fs/promises');for(const [name,data] of Object.entries({'collection.json':archive,'research-brief.html':html,'download-receipt.json':receipt,'authoring-panel.html':ui,'research-brief.md':markdown}))await fs.writeFile(root+'/'+name,data,'utf8');return true;}

///|
test "production HTML effect downloads real UTF8 Blob and JSON fresh resume produces equivalent HTML" {
  @js.async_test(async fn() {
    let before = html_brief_fixture()
    let expected = book_collection_html(before)
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    let cell = Ref(before)
    fn dispatch(msg : Msg) -> @rabbita.Cmd {
      guard msg is BookSearch(Collection(message)) else {
        abort("unexpected message")
      }
      cell.val = book_collection_reduce(cell.val, message).0
      @rabbita.none
    }
    let capture = html_brief_capture_start(false)
    guard book_collection_reduce(cell.val, DownloadHtml).1 is [effect] else {
      fail("HTML effect missing")
    }
    @cmd.Scheduler::add(scheduler, book_search_effect(dispatch, effect))
    ignore(html_brief_tick().wait())
    assert_true(
      cell.val.notice.unwrap().contains("HTML brief download requested"),
    )
    let receipt : String = html_brief_capture_finish(capture, expected)
      .wait()
      .cast()
    guard @json.parse(receipt)
      is {
        "text": String(downloaded),
        "mime": "text/html;charset=utf-8",
        "filename": "moonbook-research-brief.html",
        "bytesExact": true,
        "clicked": true,
        "removed": true,
        "revoked": true,
        ..
      } else {
      fail("HTML Blob or transport mismatch")
    }
    assert_eq(downloaded, expected)
    guard book_collection_reduce(before, DownloadArchive).1
      is [ExportArchive(_, archive)] else {
      fail("JSON effect missing")
    }
    let capture = search_export_capture_start()
    let _ : String = book_collection_archive_download(archive).wait().cast()
    let receipt_json : String = paging_export_capture_finish(capture)
      .wait()
      .cast()
    guard @json.parse(receipt_json)
      is { "download": String(saved), "clicked": true, .. } else {
      fail("JSON Blob missing")
    }
    assert_eq(saved, archive)
    archive_file_capture_start(saved)
    let reopened : String = book_collection_archive_open().wait().cast()
    archive_file_capture_finish()
    let resumed = book_collection_reduce(
        book_collection_reduce(
          book_collection_initial(),
          ArchiveDraft(reopened),
        ).0,
        ResumeArchive,
      ).0
    assert_eq(book_collection_archive(resumed), saved)
    assert_eq(resumed.history, before.history)
    assert_eq(resumed.items, before.items)
    guard book_collection_reduce(resumed, DownloadHtml).1
      is [ExportCollectionHtml(_, html)] else {
      fail("resumed HTML effect missing")
    }
    assert_eq(html, expected)
    let capture = html_brief_capture_start(false)
    let _ : String = book_collection_html_download(html).wait().cast()
    let resumed_receipt : String = html_brief_capture_finish(capture, html)
      .wait()
      .cast()
    assert_eq(resumed_receipt, receipt)
    let _ : Bool = html_brief_evidence(
        saved,
        downloaded,
        receipt,
        search_test_html({ ..book_search_initial(), collection: before, }),
        book_collection_brief(resumed),
      )
      .wait()
      .cast()
  })
}

///|
test "production HTML failures preserve collection and delayed success cannot relabel an edited revision" {
  @js.async_test(async fn() {
    let before = html_brief_fixture()
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    let cell = Ref(before)
    fn dispatch(msg : Msg) -> @rabbita.Cmd {
      guard msg is BookSearch(Collection(message)) else {
        abort("unexpected message")
      }
      cell.val = book_collection_reduce(cell.val, message).0
      @rabbita.none
    }
    for fail_click in [false, true] {
      cell.val = before
      let capture = html_brief_capture_start(fail_click)
      guard book_collection_reduce(cell.val, DownloadHtml).1 is [effect] else {
        fail("HTML effect missing")
      }
      @cmd.Scheduler::add(scheduler, book_search_effect(dispatch, effect))
      cell.val = book_collection_reduce(
          cell.val,
          Note(before.items[0].page.citation, "Changed while exporting"),
        ).0
      ignore(html_brief_tick().wait())
      assert_eq(cell.val.notice, None)
      assert_eq(cell.val.items[0].note, "Changed while exporting")
      let _ : String = html_brief_capture_finish(
          capture,
          book_collection_html(before),
        )
        .wait()
        .cast()
    }
    cell.val = before
    let capture = html_brief_capture_start(true)
    guard book_collection_reduce(cell.val, DownloadHtml).1 is [effect] else {
      fail("HTML effect missing")
    }
    @cmd.Scheduler::add(scheduler, book_search_effect(dispatch, effect))
    ignore(html_brief_tick().wait())
    assert_true(cell.val.notice.unwrap().contains("HTML download unavailable"))
    assert_eq(
      book_collection_archive(cell.val),
      book_collection_archive(before),
    )
    let receipt : String = html_brief_capture_finish(
        capture,
        book_collection_html(before),
      )
      .wait()
      .cast()
    assert_true(
      @json.parse(receipt)
      is { "clicked": false, "removed": true, "revoked": true, .. },
    )
  })
}
