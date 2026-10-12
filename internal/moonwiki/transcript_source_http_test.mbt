///|
async test "timed transcript crosses real HTTP search inspection and exact raw download without Book mutation" {
  let root = @fs.tmpdir(prefix="book-transcript-http-")
  defer @fs.rmdir(root, recursive=true)
  ignore(@wiki.init_workspace(root))
  let raw = "WEBVTT - Aurora workshop\r\n\r\nintro\r\n00:00.000 --> 00:04.000\r\n<v Alex>Welcome to the synthetic workshop.\r\n\r\nfeedback\r\n00:12:34.500 --> 00:12:40.000\r\n<v Mei &amp; Lin>跨团队复盘发现支持不足。 Orchid escalation desk closes Friday. 🚀</v>\r\n\r\n00:12:41.000 --> 00:12:44.000\r\n<v Alex>&lt;script&gt;literal example&lt;/script&gt; ``` stays inert.\r\n"
  let source_path = root + "/Aurora workshop.vtt"
  @fs.write_file(source_path, raw, create=0o644)
  let imported = @wiki.ingest_source(root, source_path)
  let citation = "wiki/sources/transcript-aurora-workshop.md"
  assert_true(imported.page_path.has_suffix(citation))
  let before : Map[String, Json] = Map([])
  retained_snapshot(root, "", before)
  let server = @moonwiki.Server::new("127.0.0.1", 0)
  defer server.close()
  let origin = "http://127.0.0.1:" + server.port().to_string()
  let headers = { "content-type": "application/json" }
  let wire : Json = @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_directory(root, workspace_root=Some(root)),
      no_wait=true,
      allow_failure=true,
    )
    let question = "跨团队复盘"
    let (status, response) = @http.post(
      origin + "/api/book/query",
      ({ "question": question, "page": 0 } : Json).stringify(),
      headers~,
    )
    assert_eq(status.code, 200)
    let query = @json.parse(response.text())
    guard query is { "excerpts": Array(excerpts), .. } else {
      fail("missing transcript excerpts")
    }
    assert_true(
      excerpts.any(item => {
        item is { "citation": String(path), "excerpt": String(text), .. } &&
        path == citation &&
        text.contains(question) &&
        text.contains("00:12:34.500") &&
        text.contains("Mei & Lin")
      }),
    )
    let (status, response) = @http.post(
      origin + "/api/book/query/inspect",
      ({ "question": question, "page": 0, "citation": citation } : Json).stringify(),
      headers~,
    )
    assert_eq(status.code, 200)
    let inspection = @json.parse(response.text())
    guard inspection
      is {
        "content": String(content),
        "retained_source": { "page_digest": String(digest), .. },
        ..
      } else {
      fail("missing transcript inspection")
    }
    assert_true(content.contains("[00:12:34.500 --> 00:12:40.000] Mei & Lin:"))
    assert_true(content.contains("````text"))
    let (status, response) = @http.post(
      origin + "/api/book/query/retained-source",
      (
        {
          "question": question,
          "page": 0,
          "citation": citation,
          "page_digest": digest,
        } : Json).stringify(),
      headers~,
    )
    assert_eq(status.code, 200)
    let retained = @json.parse(response.text())
    guard retained is { "source": { "bytes_base64": String(encoded), .. }, .. } else {
      fail("missing transcript raw bytes")
    }
    assert_eq(@base64.decode(encoded), @utf8.encode(raw))
    {
      "question": question,
      "citation": citation,
      "response": query,
      "inspection": inspection,
      "retained_source_response": retained,
    }
  })
  let after : Map[String, Json] = Map([])
  retained_snapshot(root, "", after)
  assert_eq(before, after)
  if @env.get_env_var("MOONBOOK_TRANSCRIPT_EVIDENCE") is Some(path) {
    @fs.write_file(path + "/http-workshop.vtt", raw, create=0o644)
    @fs.write_file(
      path + "/transcript-http-wire.json",
      (
        { "socket_verified": true, "book_unchanged": true, "selection": wire } :
        Json).stringify(indent=2),
      create=0o644,
    )
  }
}
