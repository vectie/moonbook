///|
async test "research collection actual socket across two searches preserves Book and supplies compiled UI evidence" {
  let root = @fs.tmpdir(prefix="book-collection-")
  defer @fs.rmdir(root, recursive=true)
  ignore(@wiki.init_workspace(root))
  let inputs = [
    (
      "aurora-pilot-plan.md", "Aurora Q4 pilot plan", "The plan proposes twelve teams. Treat this as intended scope, not a commitment.",
    ),
    (
      "aurora-onboarding-capacity.md", "Aurora onboarding capacity", "Counterevidence: eight sessions are currently supported. Four teams need a second week or extra staffing.",
    ),
  ]
  let sources : Array[(String, String, String, String)] = []
  for (name, question, note) in inputs {
    let content = match @env.get_env_var("MOONBOOK_COLLECTION_SAMPLES") {
      Some(path) => @fs.read_file(path + "/" + name).text()
      None => "# " + question + "\nSynthetic example: " + note + "\n"
    }
    let source = root + "/raw/" + name
    @fs.write_file(
      source,
      content,
      create_mode=@fs.CreateOrTruncate,
      permission=0o644,
    )
    let ingested = @wiki.ingest_source(root, source)
    let citation = ingested.page_path[root.length() + 1:].to_owned()
    sources.push(
      (question, citation, note, @wiki.query_page_text(root, citation)),
    )
  }
  @fs.write_file(
    root + "/wiki/sources/unselected.md",
    "# Private unrelated record\nUNSELECTED_PRIVATE_SENTINEL\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  let asset = match @env.get_env_var("MOONBOOK_COLLECTION_JS") {
    Some(path) => {
      let bytes = @fs.read_file(path).binary()
      @fs.mkdir(root + "/apps")
      @fs.mkdir(root + "/apps/moonbook")
      @fs.write_file(
        root + "/apps/moonbook/main.js",
        bytes,
        create_mode=@fs.CreateOrTruncate,
        permission=0o644,
      )
      Some(bytes)
    }
    None => None
  }
  let before : Map[String, Json] = Map([])
  retained_snapshot(root, "", before)
  let server = @moonwiki.Server::new("127.0.0.1", 0)
  defer server.close()
  let headers = { "content-type": "application/json" }
  let origin = "http://127.0.0.1:" + server.port().to_string()
  let selections : Array[Json] = @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_directory(root, workspace_root=Some(root)),
      no_wait=true,
      allow_failure=true,
    )
    if asset is Some(expected) {
      let (status, bytes) = @http.get(origin + "/apps/moonbook/main.js")
      assert_eq(status.code, 200)
      assert_eq(bytes.binary(), expected)
      assert_true(bytes.text().contains("Collect inspected page"))
      assert_true(bytes.text().contains("moonbook-research-brief.md"))
      assert_true(bytes.text().contains("moonbook-research-collection.json"))
      assert_true(bytes.text().contains("Replace collection and resume"))
    }
    let selections : Array[Json] = []
    for (question, citation, note, expected_page) in sources {
      let (status, response) = @http.post(
        origin + "/api/book/query",
        ({ "question": question, "page": 0 } : Json).stringify(),
        headers=socket_test_headers(headers),
      )
      assert_eq(status.code, 200)
      let query = @json.parse(response.text())
      guard query is { "excerpts": Array(excerpts), .. } else {
        fail("no query excerpts")
      }
      assert_true(
        excerpts.any(item => {
          item is { "citation": String(path), .. } && path == citation
        }),
      )
      let (status, inspection) = @http.post(
        origin + "/api/book/query/inspect",
        ({ "question": question, "page": 0, "citation": citation } : Json).stringify(),
        headers=socket_test_headers(headers),
      )
      assert_eq(status.code, 200)
      let inspected = @json.parse(inspection.text())
      guard inspected
        is {
          "content": String(content),
          "retained_source": { "page_digest": String(digest), .. },
          ..
        } else {
        fail("missing inspected binding")
      }
      assert_eq(content, expected_page)
      assert_eq(digest, @wiki.executable_sha256(content))
      selections.push({
        "question": question,
        "citation": citation,
        "note": note,
        "response": query,
        "inspection": inspected,
        "expected_page": expected_page,
      })
    }
    selections
  })
  let after : Map[String, Json] = Map([])
  retained_snapshot(root, "", after)
  assert_eq(before, after)
  if @env.get_env_var("MOONBOOK_COLLECTION_WIRE") is Some(path) {
    @fs.write_file(
      path,
      (
        {
          "socket_verified": true,
          "book_unchanged": true,
          "compiled_ui_asset_served": asset is Some(_),
          "selections": selections,
        } : Json).stringify(indent=2),
      create_mode=@fs.CreateOrTruncate,
      permission=0o644,
    )
  }
}
