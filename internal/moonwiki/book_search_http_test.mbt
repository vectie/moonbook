///|
async fn search_snapshot(
  root : String,
  relative : String,
  files : Map[String, String],
) -> Unit {
  let dir = if relative == "" { root } else { root + "/" + relative }
  for name in @fs.readdir(dir, include_hidden=true, sort=true) {
    let rel = if relative == "" { name } else { relative + "/" + name }
    match @fs.kind(root + "/" + rel, follow_symlink=false) {
      Directory => search_snapshot(root, rel, files)
      Regular => files[rel] = @fs.read_file(root + "/" + rel).text()
      _ => files[rel] = "nonregular"
    }
  }
}

///|
async test "Book search real temporary Book native query socket host and immutable export fixture" {
  let root = @fs.tmpdir(prefix="book-search-")
  ignore(@wiki.init_workspace(root))
  let page = "---\nstatus: accepted\nsummary: \"海风 Lunar <script>alert('x')</script> & exact summary\"\n---\n# Lunar <b>route</b>\n\n海风 lunar route lunar route.\nFinal complete page line.\n"
  @fs.write_file(
    root + "/wiki/sources/route.md",
    page,
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.write_file(
    root + "/wiki/sources/tie-a.md",
    "# Terrain\nLunar terrain.\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.write_file(
    root + "/wiki/sources/tie-b.md",
    "# Terrain\nLunar terrain.\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.mkdir(root + "/.moonbook/bookkeeper", recursive=true)
  @fs.write_file(
    root + "/.moonbook/bookkeeper/journal.jsonl",
    "{\"sentinel\":\"unchanged\"}\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  let before : Map[String, String] = Map([])
  search_snapshot(root, "", before)
  let question = "Lunar 海风"
  let native = @wiki.query_wiki(root, question, save=false)
  assert_eq(native.excerpts.length(), 3)
  assert_eq(native.excerpts[0].citation, "wiki/sources/route.md")
  assert_eq(native.excerpts[1].citation, "wiki/sources/tie-a.md")
  assert_eq(native.excerpts[2].citation, "wiki/sources/tie-b.md")
  assert_true(native.saved_page is None)
  assert_eq(native.related_pages.length(), 0)
  let headers = { "content-type": "application/json" }
  let body : Json = {
    "question": question,
    "root": "/untrusted-other-book",
    "save": true,
  }
  let (status, response) = @moonwiki.book_search_http_response(
    root,
    "POST",
    "/api/book/query",
    headers,
    body.stringify(),
  )
  assert_eq(status, 200)
  guard response
    is { "excerpts": excerpts, "brief": String(brief), "saved": false, .. } else {
    fail("missing search fields")
  }
  assert_eq(excerpts, native.excerpts.to_json())
  assert_eq(brief, @wiki.query_context_brief(native))
  let inspect_body : Json = {
    "question": question,
    "citation": native.citations[0],
  }
  let (inspect_status, inspected) = @moonwiki.book_search_http_response(
    root,
    "POST",
    "/api/book/query/inspect",
    headers,
    inspect_body.stringify(),
  )
  assert_eq(inspect_status, 200)
  guard inspected is { "content": String(content), .. } else {
    fail("missing page")
  }
  assert_eq(content, page)
  // Exercise the actual server dispatcher and bounded socket body reader too.
  let server = @moonwiki.Server::new("127.0.0.1", 0)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_directory(root, workspace_root=Some(root)),
      no_wait=true,
      allow_failure=true,
    )
    let url = "http://127.0.0.1:" +
      server.port().to_string() +
      "/api/book/query"
    let (http_response, data) = @http.post(
      url,
      body.stringify(),
      headers=socket_test_headers(headers),
    )
    assert_eq(http_response.code, 200)
    assert_eq(@json.parse(data.text()), response)
    let (oversized, _) = @http.post(
      url,
      "x".repeat(16385),
      headers=socket_test_headers(headers),
    )
    assert_eq(oversized.code, 413)
  })
  let after : Map[String, String] = Map([])
  search_snapshot(root, "", after)
  assert_eq(
    before,
    after,
    msg="Every Book source, review, keeper and journal file must remain unchanged",
  )
  match @env.get_env_var("MOONBOOK_SEARCH_WIRE") {
    Some(path) => {
      let wire : Json = {
        "question": question,
        "response": response,
        "inspect_response": inspected,
        "expected_brief": brief,
        "expected_page": page,
        "native_excerpts": native.excerpts,
        "book_unchanged": true,
        "socket_verified": true,
      }
      @fs.write_file(
        path,
        wire.stringify(indent=2),
        create_mode=@fs.CreateOrTruncate,
        permission=0o644,
      )
    }
    None => ()
  }
}

///|
async test "Book search empty unicode no match unreadable unsafe and bounded inputs" {
  let root = @fs.tmpdir(prefix="book-search-edge-")
  ignore(@wiki.init_workspace(root))
  let headers = { "content-type": "application/json" }
  async fn query(text : String) -> (Int32, Json) {
    let body : Json = { "question": text }
    @moonwiki.book_search_http_response(
      root,
      "POST",
      "/api/book/query",
      headers,
      body.stringify(),
    )
  }
  assert_eq(query("").0, 400)
  assert_eq(query("a").0, 422)
  assert_eq(query("?!").0, 422)
  assert_eq(query("x".repeat(1025)).0, 400)
  let (empty_status, empty) = query("nonexistentterm")
  assert_eq(empty_status, 200)
  assert_true(empty is { "excerpts": [], .. })
  @fs.write_file(
    root + "/wiki/sources/海风.md",
    "# 海风🛰️\n海风 observations.\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  assert_true(query("海风").1 is { "excerpts": [_, ..], .. })
  let outside = @fs.tmpdir(prefix="book-search-outside-")
  @fs.write_file(
    outside + "/outside.md",
    "# Outside\nsecrets lunar\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.symlink(target=outside + "/outside.md", root + "/wiki/sources/link.md")
  @fs.symlink(target=outside, root + "/wiki/sources/linked-dir")
  assert_true(query("secrets").1 is { "excerpts": [], .. })
  for
    citation in [
      "../outside.md", "wiki/../../outside.md", "wiki/sources/link.md", "wiki/sources/linked-dir/outside.md",
      "/etc/passwd",
    ] {
    let body : Json = { "question": "海风", "citation": citation }
    assert_eq(
      @moonwiki.book_search_http_response(
        root,
        "POST",
        "/api/book/query/inspect",
        headers,
        body.stringify(),
      ).0,
      409,
    )
    let rejected = try {
      ignore(@wiki.query_page_text(root, citation))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  @fs.write_file(
    root + "/wiki/sources/unreadable.md",
    "# Unreadable\n海风\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.chmod(root + "/wiki/sources/unreadable.md", 0)
  assert_eq(query("海风").0, 422)
  @fs.chmod(root + "/wiki/sources/unreadable.md", 0o644)
  @fs.write_file(
    root + "/wiki/sources/large.md",
    "x".repeat(2097153),
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  assert_eq(query("海风").0, 422)
  assert_eq(
    @moonwiki.book_search_http_response(
      root, "GET", "/api/book/query", headers, "",
    ).0,
    405,
  )
  assert_eq(
    @moonwiki.book_search_http_response(
      root,
      "POST",
      "/api/book/query",
      { "content-type": "text/plain" },
      "{}",
    ).0,
    415,
  )
  assert_eq(
    @moonwiki.book_search_http_response(
      root,
      "POST",
      "/api/book/query",
      { "content-type": "application/json", "sec-fetch-site": "cross-site" },
      "{}",
    ).0,
    403,
  )
  assert_eq(
    @moonwiki.book_search_http_response(
      root, "POST", "/api/book/query", headers, "{broken",
    ).0,
    400,
  )
  assert_eq(
    @moonwiki.book_search_http_response(
      root,
      "POST",
      "/api/book/query",
      headers,
      "x".repeat(16385),
    ).0,
    413,
  )
}
