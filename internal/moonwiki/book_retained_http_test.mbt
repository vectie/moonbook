///|
fn retained_page(reference : String, target? : String = "") -> String {
  let target = if target == "" { "../../" + reference } else { target }
  "---\nmoonbook_type: source\n---\n\n# Lunar retained source\n\n- Raw source: [" +
  reference +
  "](" +
  target +
  ")\n- Ingested at: `1`\n\n## Extract\n\n```text\nLunar excerpt only\n```\n"
}

///|
async fn retained_request(
  root : String,
  route : String,
  payload : Json,
) -> (Int, Json) {
  @moonwiki.book_search_http_response(
    root,
    "POST",
    "/api/book/query/" + route,
    { "content-type": "application/json" },
    payload.stringify(),
  )
}

///|
async fn retained_inspect(
  root : String,
  citation? : String = "wiki/sources/retained.md",
) -> Json {
  let (status, response) = retained_request(root, "inspect", {
    "question": "Lunar",
    "citation": citation,
  })
  assert_eq(status, 200)
  response
}

///|
async fn retained_snapshot(
  root : String,
  relative : String,
  out : Map[String, Json],
) -> Unit {
  let dir = if relative == "" { root } else { root + "/" + relative }
  for name in @fs.readdir(dir, include_hidden=true, sort=true) {
    let rel = if relative == "" { name } else { relative + "/" + name }
    let path = root + "/" + rel
    let kind = @fs.kind(path, follow_symlink=false)
    let mtime = @fs.mtime(path, follow_symlink=false)
    let ctime = @fs.ctime(path, follow_symlink=false)
    if kind is Directory {
      out[rel] = { "kind": "directory", "mtime": mtime, "ctime": ctime }
      retained_snapshot(root, rel, out)
    } else if kind is Regular {
      let bytes = @fs.read_file(path).binary()
      out[rel] = {
        "kind": "regular",
        "mtime": mtime,
        "ctime": ctime,
        "size": bytes.length(),
        "bytes": @base64.encode(bytes),
      }
    } else {
      out[rel] = { "kind": "nonregular", "mtime": mtime, "ctime": ctime }
    }
  }
}

///|
async test "retained source real native HTTP generated ingest complete Unicode CRLF bytes and immutable Book metadata" {
  let root = @fs.tmpdir(prefix="book-retained-wire-")
  ignore(@wiki.init_workspace(root))
  let raw = "# Lunar retained 海风\r\n" +
    "Line 海风🛰️ <script>inactive()</script>\r\n".repeat(30) +
    "Final line beyond ingest excerpt.\r\n"
  @fs.write_file(
    root + "/raw/retained.md",
    raw,
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  let ingested = @wiki.ingest_source(root, root + "/raw/retained.md")
  let citation = ingested.page_path[root.length() + 1:].to_owned()
  let page = @wiki.query_page_text(root, citation)
  assert_false(page.contains("Final line beyond ingest excerpt."))
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
    let (search_status, search_bytes) = @http.post(
      base,
      ({ "question": "Lunar" } : Json).stringify(),
      headers=socket_test_headers(headers),
    )
    assert_eq(search_status.code, 200)
    let (inspect_status, inspect_bytes) = @http.post(
      base + "/inspect",
      ({ "question": "Lunar", "citation": citation } : Json).stringify(),
      headers=socket_test_headers(headers),
    )
    assert_eq(inspect_status.code, 200)
    let inspected = @json.parse(inspect_bytes.text())
    guard inspected
      is {
        "retained_source": {
          "page_digest": String(page_digest),
          "reference": "raw/retained.md",
          ..
        },
        ..
      } else {
      fail("generated ingest source descriptor missing")
    }
    let payload : Json = {
      "question": "Lunar",
      "citation": citation,
      "page_digest": page_digest,
      "root": "/ignored",
      "path": "/etc/passwd",
      "url": "https://must-not-fetch.invalid",
    }
    let (status, data) = @http.post(
      base + "/retained-source",
      payload.stringify(),
      headers=socket_test_headers(headers),
    )
    assert_eq(status.code, 200)
    let source = @json.parse(data.text())
    guard source
      is {
        "source": {
          "text": String(text),
          "bytes_base64": String(encoded),
          "size": Number(size),
          "digest": String(digest),
          ..
        },
        ..
      } else {
      fail("missing current retained bytes")
    }
    assert_eq(text, raw)
    assert_eq(@base64.decode(encoded), @utf8.encode(raw))
    assert_eq(size, @utf8.encode(raw).length().to_double())
    assert_eq(digest, @wiki.executable_sha256(raw))
    (
      {
        "question": "Lunar",
        "citation": citation,
        "response": @json.parse(search_bytes.text()),
        "inspect_response": inspected,
        "source_response": source,
        "expected_base64": @base64.encode(@utf8.encode(raw)),
        "expected_text": raw,
        "socket_verified": true,
      } : Json)
  })
  let after : Map[String, Json] = Map([])
  retained_snapshot(root, "", after)
  assert_eq(
    before,
    after,
    msg="Book bytes, directory membership, size, kind, mtime and ctime unchanged",
  )
  match @env.get_env_var("MOONBOOK_RETAINED_WIRE") {
    Some(path) =>
      @fs.write_file(
        path,
        (
          {
            "wire": wire,
            "book_unchanged": true,
            "metadata_before": before,
            "metadata_after": after,
          } : Json).stringify(indent=2),
        create_mode=@fs.CreateOrTruncate,
        permission=0o644,
      )
    None => ()
  }
}

///|
async test "retained source malformed duplicate remote absolute traversal symlink missing oversized and nonregular unavailable while page stays readable" {
  let root = @fs.tmpdir(prefix="book-retained-edge-")
  ignore(@wiki.init_workspace(root))
  @fs.write_file(
    root + "/raw/source.txt",
    "Lunar full source",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  let original = retained_page("raw/source.txt")
  let invalid_pages = [
    retained_page("raw/source.txt", target="https://outside.invalid/source"),
    retained_page("/etc/passwd"),
    retained_page("raw/../../outside"),
    retained_page("raw/./source.txt"),
    retained_page("raw//source.txt"),
    retained_page("raw/a\\source.txt"),
    retained_page("raw/%2e%2e/source.txt"),
    retained_page("raw/source.txt") + "\n- Raw source: malformed duplicate\n",
    original.replace_all(old="- Raw source: [", new="- Raw source: malformed ["),
    "# Lunar\n\n```text\n- Raw source: [raw/source.txt](../../raw/source.txt)\n```\n",
    "# Lunar\n[raw/source.txt](../../raw/source.txt)\n",
    original.replace_all(
      old="moonbook_type: source",
      new="moonbook_type: concept",
    ),
    retained_page("raw/missing.txt"),
  ]
  for page in invalid_pages {
    @fs.write_file(
      root + "/wiki/sources/retained.md",
      page,
      create_mode=@fs.CreateOrTruncate,
      permission=0o644,
    )
    let inspected = retained_inspect(root)
    assert_true(inspected is { "retained_source": Null, .. })
    assert_eq(@wiki.query_page_text(root, "wiki/sources/retained.md"), page)
  }
  let outside = @fs.tmpdir(prefix="book-retained-outside-")
  @fs.write_file(
    outside + "/secret.txt",
    "Lunar outside",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.symlink(target=outside + "/secret.txt", root + "/raw/link.txt")
  @fs.symlink(target=outside, root + "/raw/linkdir")
  @fs.mkdir(root + "/raw/directory")
  @fs.write_file(
    root + "/raw/oversized.txt",
    "x".repeat(2097153),
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  for
    reference in [
      "raw/link.txt", "raw/linkdir/secret.txt", "raw/directory", "raw/oversized.txt",
    ] {
    @fs.write_file(
      root + "/wiki/sources/retained.md",
      retained_page(reference),
      create_mode=@fs.CreateOrTruncate,
      permission=0o644,
    )
    assert_true(retained_inspect(root) is { "retained_source": Null, .. })
  }
  @fs.write_file(
    root + "/wiki/sources/retained.md",
    original,
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  assert_true(retained_inspect(root) is { "retained_source": { .. }, .. })
  @fs.rename(root + "/raw", root + "/saved-raw")
  @fs.symlink(target=root + "/saved-raw", root + "/raw")
  assert_true(retained_inspect(root) is { "retained_source": Null, .. })
}

///|
async test "retained source binds citation and whole maintained page rejects changed binding and returns binary bytes without preview" {
  let root = @fs.tmpdir(prefix="book-retained-binding-")
  ignore(@wiki.init_workspace(root))
  @fs.write_file(
    root + "/raw/source.bin",
    b"\x00\xff\x01\r\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  let page = retained_page("raw/source.bin")
  @fs.write_file(
    root + "/wiki/sources/retained.md",
    page,
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  guard retained_inspect(root)
    is { "retained_source": { "page_digest": String(digest), .. }, .. } else {
    fail("missing binary descriptor")
  }
  let payload : Json = {
    "question": "Lunar",
    "citation": "wiki/sources/retained.md",
    "page_digest": digest,
  }
  let (status, response) = retained_request(root, "retained-source", payload)
  assert_eq(status, 200)
  guard response
    is {
      "source": { "text": Null, "bytes_base64": String(encoded), "size": 5, .. },
      ..
    } else {
    fail("binary source must have no preview")
  }
  assert_eq(@base64.decode(encoded), b"\x00\xff\x01\r\n")
  let server = @moonwiki.Server::new("127.0.0.1", 0)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_directory(root, workspace_root=Some(root)),
      no_wait=true,
      allow_failure=true,
    )
    let (http_status, bytes) = @http.post(
      "http://127.0.0.1:" +
      server.port().to_string() +
      "/api/book/query/retained-source",
      payload.stringify(),
      headers={ "content-type": "application/json" },
    )
    assert_eq(http_status.code, 200)
    assert_eq(@json.parse(bytes.text()), response)
  })
  match @env.get_env_var("MOONBOOK_RETAINED_BINARY_WIRE") {
    Some(path) =>
      @fs.write_file(
        path,
        (
          {
            "response": response,
            "page_digest": digest,
            "socket_verified": true,
          } : Json).stringify(indent=2),
        create_mode=@fs.CreateOrTruncate,
        permission=0o644,
      )
    None => ()
  }
  for citation in ["wiki/sources/missing.md", "../outside", "raw/source.bin"] {
    assert_eq(
      retained_request(root, "retained-source", {
        "question": "Lunar",
        "citation": citation,
        "page_digest": digest,
      }).0,
      409,
    )
  }
  assert_eq(
    retained_request(root, "retained-source", {
      "question": "nomatch",
      "citation": "wiki/sources/retained.md",
      "page_digest": digest,
    }).0,
    409,
  )
  @fs.write_file(
    root + "/wiki/sources/retained.md",
    page + "\nMaintained page changed.\n",
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  assert_eq(retained_request(root, "retained-source", payload).0, 409)
  @fs.write_file(
    root + "/wiki/sources/retained.md",
    retained_page("raw/other.bin"),
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  assert_eq(retained_request(root, "retained-source", payload).0, 409)
  @fs.write_file(
    root + "/wiki/sources/retained.md",
    page,
    create_mode=@fs.CreateOrTruncate,
    permission=0o644,
  )
  @fs.remove(root + "/raw/source.bin")
  assert_eq(retained_request(root, "retained-source", payload).0, 409)
  assert_true(
    retained_inspect(root)
    is { "content": String(_), "retained_source": Null, .. },
  )
}
