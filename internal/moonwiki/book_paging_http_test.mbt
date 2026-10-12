///|
async test "paged search zero one three four many ties bounded fresh rank and unchanged Book" {
  let root = @fs.tmpdir(prefix="book-paging-")
  defer @fs.rmdir(root, recursive=true)
  ignore(@wiki.init_workspace(root))
  let question = "needle"
  let headers = { "content-type": "application/json" }
  async fn request(route : String, body : Json) -> (Int, Json) {
    @moonwiki.book_search_http_response(
      root,
      "POST",
      "/api/book/query" + route,
      headers,
      body.stringify(),
    )
  }
  for count in 0..<=35 {
    if count > 0 {
      @fs.write_file(
        root + "/wiki/sources/p-" + (99 + count).to_string() + ".md",
        "# Evidence\nneedle 海风 <script>inactive</script>\n",
        create=0o644,
      )
    }
    if [0, 1, 3, 4, 35].contains(count) {
      let before : Map[String, Json] = Map([])
      retained_snapshot(root, "", before)
      let first = @wiki.query_wiki_page(root, question, 0)
      let second = @wiki.query_wiki_page(root, question, 1)
      let legacy = @wiki.query_wiki(root, question)
      assert_eq(first.result.excerpts.to_json(), legacy.excerpts.to_json())
      assert_eq(first.paging.matched_count, count)
      assert_eq(first.paging.has_next, count > 3)
      assert_eq(first.paging.truncated, count > 30)
      assert_eq(
        second.result.excerpts.length(),
        if count <= 3 {
          0
        } else if count == 4 {
          1
        } else {
          3
        },
      )
      assert_true(first.result.saved_page is None)
      if count > 0 && count <= 3 {
        let empty_brief = @wiki.query_window_context_brief(second)
        assert_true(empty_brief.contains("other pages still match"))
        assert_false(empty_brief.contains("No matching maintained pages found"))
      }
      if count >= 4 {
        assert_eq(second.result.citations[0], "wiki/sources/p-103.md")
      }
      let after : Map[String, Json] = Map([])
      retained_snapshot(root, "", after)
      assert_eq(before, after)
    }
  }
  let last = @wiki.query_wiki_page(root, question, 9)
  assert_eq(last.result.citations, [
    "wiki/sources/p-127.md", "wiki/sources/p-128.md", "wiki/sources/p-129.md",
  ])
  assert_false(last.paging.has_next)
  assert_eq(last.paging.window_count, 30)
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 9,
      "citation": "wiki/sources/p-130.md",
    }).0,
    409,
  )
  for
    bad in [
      (-1).to_json(),
      (10).to_json(),
      1.5.to_json(),
      "1".to_json(),
      Json::null(),
      1.0e100.to_json(),
    ] {
    assert_eq(request("", { "question": question, "page": bad }).0, 400)
  }
  let selected = "wiki/sources/p-103.md"
  let changed_content = "# Evidence\nneedle 海风 <script>inactive</script>\nUpdated context at inspection.\n"
  @fs.write_file(root + "/" + selected, changed_content)
  let current = request("/inspect", {
    "question": question,
    "page": 1,
    "citation": selected,
  })
  assert_eq(current.0, 200)
  assert_true(
    current.1 is { "content": String(text), .. } && text == changed_content,
  )
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 1,
      "citation": selected,
    }).0,
    200,
  )
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 0,
      "citation": selected,
    }).0,
    409,
  )
  assert_eq(
    request("/inspect", { "question": question, "citation": selected }).0,
    409,
  )
  assert_eq(
    request("/inspect", {
      "question": "absent",
      "page": 1,
      "citation": selected,
    }).0,
    409,
  )
  @fs.write_file(root + "/" + selected, "# Promoted\nneedle ".repeat(20))
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 1,
      "citation": selected,
    }).0,
    409,
  )
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 0,
      "citation": selected,
    }).0,
    200,
  )
  @fs.remove(root + "/" + selected)
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 0,
      "citation": selected,
    }).0,
    409,
  )
  let outside = @fs.tmpdir(prefix="book-paging-outside-")
  defer @fs.rmdir(outside, recursive=true)
  @fs.write_file(outside + "/secret.md", "# needle\nneedle", create=0o644)
  @fs.symlink(target=outside + "/secret.md", root + "/wiki/sources/link.md")
  assert_eq(@wiki.query_wiki_page(root, question, 1).paging.matched_count, 34)
  assert_eq(
    request("/inspect", {
      "question": question,
      "page": 1,
      "citation": "wiki/sources/link.md",
    }).0,
    409,
  )
  @fs.write_file(
    root + "/wiki/sources/large.md",
    "x".repeat(2097153),
    create=0o644,
  )
  assert_eq(request("", { "question": question, "page": 1 }).0, 422)
  @fs.remove(root + "/wiki/sources/large.md")
  @fs.chmod(root + "/wiki/sources/p-100.md", 0)
  assert_eq(request("", { "question": question, "page": 1 }).0, 422)
  @fs.chmod(root + "/wiki/sources/p-100.md", 0o644)
}

///|
async test "paged search actual socket later page inspection retained bytes and UI wire" {
  let root = @fs.tmpdir(prefix="book-paging-wire-")
  defer @fs.rmdir(root, recursive=true)
  ignore(@wiki.init_workspace(root))
  for index in 0..<3 {
    @fs.write_file(
      root + "/wiki/sources/first-" + index.to_string() + ".md",
      "# Lunar\n" + "Lunar ".repeat(30),
      create=0o644,
    )
  }
  let content = retained_page("raw/later.md") +
    "\nFinal complete later page line 海风 <script>inactive</script>.\n"
  let raw = "Complete retained later-page bytes 海风\r\n"
  @fs.write_file(root + "/wiki/sources/later.md", content, create=0o644)
  @fs.write_file(root + "/raw/later.md", raw, create=0o644)
  let before : Map[String, Json] = Map([])
  retained_snapshot(root, "", before)
  let server = @moonwiki.Server::new("127.0.0.1", 0)
  defer server.close()
  let headers = { "content-type": "application/json" }
  let base = "http://127.0.0.1:" + server.port().to_string() + "/api/book/query"
  let wire = @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_directory(root, workspace_root=Some(root)),
      no_wait=true,
      allow_failure=true,
    )
    async fn post(route : String, payload : Json) -> Json {
      let (status, data) = @http.post(
        base + route,
        payload.stringify(),
        headers~,
      )
      assert_eq(status.code, 200)
      @json.parse(data.text())
    }
    let first = post("", { "question": "Lunar", "page": 0 })
    let response = post("", { "question": "Lunar", "page": 1 })
    let citation = "wiki/sources/later.md"
    let inspected = post("/inspect", {
      "question": "Lunar",
      "page": 1,
      "citation": citation,
    })
    guard inspected
      is {
        "page": 1,
        "content": String(actual),
        "retained_source": { "page_digest": String(digest), .. },
        ..
      } else {
      fail("missing inspection")
    }
    assert_eq(actual, content)
    let source = post("/retained-source", {
      "question": "Lunar",
      "page": 1,
      "citation": citation,
      "page_digest": digest,
    })
    guard source
      is { "page": 1, "source": { "text": String(actual_raw), .. }, .. } else {
      fail("missing retained bytes")
    }
    assert_eq(actual_raw, raw)
    let expected = @wiki.query_wiki_page(root, "Lunar", 1)
    (
      {
        "first_response": first,
        "response": response,
        "inspect_response": inspected,
        "source_response": source,
        "expected_page": content,
        "expected_source": raw,
        "expected_brief": @wiki.query_window_context_brief(expected),
        "socket_verified": true,
      } : Json)
  })
  let after : Map[String, Json] = Map([])
  retained_snapshot(root, "", after)
  assert_eq(before, after)
  if @env.get_env_var("MOONBOOK_PAGING_WIRE") is Some(path) {
    @fs.write_file(
      path,
      (
        {
          "wire": wire,
          "book_unchanged": true,
          "metadata_before": before,
          "metadata_after": after,
        } : Json).stringify(indent=2),
      create=0o644,
    )
  }
}
