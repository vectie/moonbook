///|
async test "default init and pack retain a no-id book and exact imported member bytes" {
  let fixture_root = @fs.tmpdir(prefix="moonbook-default-no-id-")
  let publisher_root = fixture_root + "/publisher"
  @wiki.init_workspace(publisher_root) |> ignore
  let publisher_toml = @fsx.read_file(publisher_root + "/book.toml")
  assert_eq(
    publisher_toml, "[book]\ntitle = \"LLM Wiki\"\nsrc = \"wiki\"\n\n[build]\nbuild-dir = \"book\"\n",
  )
  // Keep this a genuinely default export: do not set a Book ID, select extra
  // output members, rewrite package metadata, or add book.toml to the bundle.
  let package_path = @agent.pack_agent(
    publisher_root,
    output=fixture_root + "/default-no-id.moonbook-agent",
  )
  let package_bytes = @fsx.read_bytes(package_path)
  let source = @agent.describe_portable_source(package_path)
  let bundle = @agent.read_agent_bundle(package_path)
  assert_eq(source.agent_id, @wiki.book_identity(publisher_root))
  assert_false(bundle.files.any(file => file.path == "book.toml"))
  let source_path = fixture_root + "/source.json"
  @fsx.write_to_file(
    source_path,
    source.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  let target_root = fixture_root + "/recipient"
  let receipt = @agent.import_agent_bundle(
    package_path,
    target_root,
    expected_source=source,
  )
  assert_eq(receipt.agent_id, source.agent_id)
  assert_eq(receipt.action, "import")
  assert_eq(@fsx.read_file(target_root + "/book.toml"), publisher_toml)
  assert_eq(@fsx.read_bytes(package_path), package_bytes)
  assert_true(
    @agent.verify_portable_import_members(package_path, target_root).is_empty(),
  )
  assert_false(@fsx.exists(target_root + "/state/portable-source-binding.json"))
  // Retain paths and unmodified source JSON for the separate Desk staging and
  // import acceptance run. This is fixture provenance, not a Desk response.
  let fixture : Json = {
    "contract": "moonbook.local_import_fixture.v1",
    "fixture_root": fixture_root,
    "publisher_root": publisher_root,
    "package_path": package_path,
    "source_path": source_path,
    "source": source,
    "publisher_book_toml": publisher_toml,
    "bundle_contains_book_toml": false,
    "book_import_root": target_root,
    "book_import_receipt": receipt,
    "member_bytes_verified": true,
  }
  let fixture_path = fixture_root + "/fixture.json"
  @fsx.write_to_file(
    fixture_path,
    fixture.stringify(indent=2) + "\n",
    create=0o644,
  )
  println("default-no-id fixture: " + fixture_path)
}
