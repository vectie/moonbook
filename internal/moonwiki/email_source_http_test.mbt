///|
async test "EML source crosses native HTTP search inspection and byte exact retained original" {
  let root = @fs.tmpdir(prefix="book-eml-http-")
  defer @fs.rmdir(root, recursive=true)
  ignore(@wiki.init_workspace(root))
  let body = "Synthetic customer feedback.\n" +
    "Earlier context.\n".repeat(32) +
    "跨团队复盘发现支持不足。 Orchid escalation desk closes Friday.\n"
  let raw = "From: Mei <mei@example.invalid>\r\nTo: Founder <founder@example.invalid>\r\nSubject: Aurora support follow-up\r\nDate: Thu, 08 Oct 2026 10:00:00 +0000\r\nMessage-ID: <aurora-42@example.invalid>\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n" +
    @base64.encode(@utf8.encode(body)) +
    "\r\n"
  let source_path = root + "/support.eml"
  @fs.write_file(
    source_path,
    raw,
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  let imported = @wiki.ingest_source(root, source_path)
  let citation = "wiki/sources/email-aurora-support-follow-up.md"
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
      headers=socket_test_headers(headers),
    )
    assert_eq(status.code, 200)
    let query = @json.parse(response.text())
    guard query is { "excerpts": Array(excerpts), .. } else {
      fail("missing EML excerpts")
    }
    assert_true(
      excerpts.any(item => {
        item is { "citation": String(path), "excerpt": String(text), .. } &&
        path == citation &&
        text.contains(question)
      }),
    )
    let (status, response) = @http.post(
      origin + "/api/book/query/inspect",
      ({ "question": question, "page": 0, "citation": citation } : Json).stringify(),
      headers=socket_test_headers(headers),
    )
    assert_eq(status.code, 200)
    let inspection = @json.parse(response.text())
    guard inspection
      is {
        "content": String(content),
        "retained_source": { "page_digest": String(digest), .. },
        ..
      } else {
      fail("missing EML inspection")
    }
    assert_true(content.contains("From: Mei <mei@example.invalid>"))
    assert_true(content.contains("Message-ID: <aurora-42@example.invalid>"))
    let (status, response) = @http.post(
      origin + "/api/book/query/retained-source",
      (
        {
          "question": question,
          "page": 0,
          "citation": citation,
          "page_digest": digest,
        } : Json).stringify(),
      headers=socket_test_headers(headers),
    )
    assert_eq(status.code, 200)
    let retained = @json.parse(response.text())
    guard retained is { "source": { "bytes_base64": String(encoded), .. }, .. } else {
      fail("missing original EML bytes")
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
  if @env.get_env_var("MOONBOOK_EML_EVIDENCE") is Some(path) {
    @fs.write_file(
      path + "/http-support.eml",
      raw,
      create_mode=@fs.CreateOrTruncate,
      permission=0o644,
    )
    @fs.write_file(
      path + "/email-http-wire.json",
      (
        { "socket_verified": true, "book_unchanged": true, "selection": wire } :
        Json).stringify(indent=2),
      create_mode=@fs.CreateOrTruncate,
      permission=0o644,
    )
  }
}
