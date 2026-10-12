///|
async test "RIS library references cross native HTTP search inspection and exact retained export" {
  let root = @fs.tmpdir(prefix="book-ris-http-")
  defer @fs.rmdir(root, recursive=true)
  ignore(@wiki.init_workspace(root))
  let raw = "TY  - JOUR\nTI  - Aurora onboarding study\nAU  - Lin, Mei\nAB  - Eight teams completed guided setup.\nER  -\nTY  - RPRT\nTI  - Aurora capacity counterstudy\nAU  - Chen, Li\nAB  - Only five teams received follow-up support.\nER  -\n"
  let source_path = root + "/library.ris"
  @fs.write_file(source_path, raw, create=0o644)
  let imported = @wiki.import_ris(root, source_path)
  let before : Map[String, Json] = Map([])
  retained_snapshot(root, "", before)
  let server = @moonwiki.Server::new("127.0.0.1", 0)
  defer server.close()
  let origin = "http://127.0.0.1:" + server.port().to_string()
  let headers = { "content-type": "application/json" }
  let selections : Array[Json] = @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_directory(root, workspace_root=Some(root)),
      no_wait=true,
      allow_failure=true,
    )
    let selections : Array[Json] = []
    for reference in imported.references {
      let question = reference.title
      let citation = reference.citation
      let (status, response) = @http.post(
        origin + "/api/book/query",
        ({ "question": question, "page": 0 } : Json).stringify(),
        headers~,
      )
      assert_eq(status.code, 200)
      let query = @json.parse(response.text())
      guard query is { "excerpts": Array(excerpts), .. } else {
        fail("missing query excerpts")
      }
      assert_true(
        excerpts.any(item => {
          item is { "citation": String(path), .. } && path == citation
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
        fail("missing RIS page or retained export binding")
      }
      assert_true(
        content.contains(
          "Record number in retained export: " +
          reference.record_number.to_string(),
        ),
      )
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
      guard retained
        is { "source": { "bytes_base64": String(encoded), .. }, .. } else {
        fail("missing retained RIS bytes")
      }
      assert_eq(@base64.decode(encoded), @utf8.encode(raw))
      selections.push({
        "question": question,
        "citation": citation,
        "response": query,
        "inspection": inspection,
        "retained_source_response": retained,
        "expected_page": content,
        "note": "Synthetic bibliography reference",
      })
    }
    selections
  })
  let after : Map[String, Json] = Map([])
  retained_snapshot(root, "", after)
  assert_eq(before, after)
  if @env.get_env_var("MOONBOOK_RIS_EVIDENCE") is Some(path) {
    @fs.write_file(path + "/http-library.ris", raw, create=0o644)
    @fs.write_file(
      path + "/ris-http-wire.json",
      (
        {
          "socket_verified": true,
          "book_unchanged": true,
          "selections": selections,
        } : Json).stringify(indent=2),
      create=0o644,
    )
  }
}
