///|
/// Explicit environment opt-in retains artifacts for the cross-product fixture.
async test "portable journey exports accepted Desk learning plus explicitly selected output bytes" {
  guard @env.get_env_var("MOONBOOK_PORTABLE_FIXTURE_MODE") is Some("export") else {
    return
  }
  let dir = @env.get_env_var("MOONBOOK_PORTABLE_FIXTURE_DIR").unwrap()
  let accepted = @env.get_env_var("MOONBOOK_DESK_ACCEPTED_PACKAGE").unwrap()
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let root = dir + "/sender-book"
  @agent.import_agent_bundle(accepted, root) |> ignore
  @fsx.make_directory(
    root + "/outputs/app/assets",
    recursive=true,
    exists_ok=true,
  )
  // Representative transport fixtures: file extensions are labels, not a claim
  // every format is rendered or executable. The PNG, CSV, HTML and text are
  // usable simple outputs; office/binary bytes exercise opaque byte fidelity.
  let fixtures : Array[(String, String, Bytes)] = [
    (
      "report.pdf", "application/pdf", b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n",
    ),
    (
      "slides.pptx",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      [80, 75, 3, 4, 0, 255, 128],
    ),
    (
      "document.docx",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      [80, 75, 3, 4, 1, 255, 128],
    ),
    (
      "workbook.xlsx",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      [80, 75, 3, 4, 2, 255, 128],
    ),
    ("numbers.csv", "text/csv", @utf8.encode("label,value\n收入,42\n")),
    (
      "result.png",
      "image/png",
      @base64.decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ1sAAAAASUVORK5CYII=",
        ignore_whitespace=false,
      ),
    ),
    ("opaque.bin", "application/octet-stream", [0, 255, 1, 128, 2, 127]),
    (
      "answer.md",
      "text/markdown",
      @utf8.encode(
        "# Result\n\nPortable evidence with tail clause 保留完整。\n",
      ),
    ),
    (
      "result.json", "application/json", b"{\"result\":42,\"source\":\"fixture\"}\n",
    ),
  ]
  let selections : Array[@agent.PortableOutputSelection] = []
  let expected : Array[Json] = []
  for i, (name, mime_type, bytes) in fixtures {
    @fsx.write_bytes(root + "/outputs/" + name, bytes, create=0o644)
    let selection : @agent.PortableOutputSelection = {
      artifact_id: "output-" + i.to_string(),
      label: name,
      mime_type,
      included: true,
      files: [{ source_path: "outputs/" + name, path: name, }],
      reference: None,
      declared_digest: None,
      preview_path: None,
      app_entrypoint: None,
    }
    selections.push(selection)
    expected.push({
      "path": "portable/outputs/" + selection.artifact_id + "/" + name,
      "digest": "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes)),
      "size_bytes": bytes.length(),
    })
  }
  @fsx.write_to_file(
    root + "/outputs/app/index.html",
    "<!doctype html><html><link rel=stylesheet href=assets/style.css><p>Portable app output</p></html>\n",
    create=0o644,
  )
  @fsx.write_to_file(
    root + "/outputs/app/assets/style.css",
    "body { color: #234; }\n",
    create=0o644,
  )
  selections.push({
    artifact_id: "html-app",
    label: "Selected static HTML and asset",
    mime_type: "text/html",
    included: true,
    files: [
      { source_path: "outputs/app/index.html", path: "index.html", },
      { source_path: "outputs/app/assets/style.css", path: "assets/style.css", },
    ],
    reference: None,
    declared_digest: None,
    preview_path: None,
    app_entrypoint: Some("index.html"),
  })
  selections.push({
    artifact_id: "reference-only",
    label: "Large publisher-side artifact, not transferred",
    mime_type: "video/mp4",
    included: false,
    files: [],
    reference: Some("artifact:publisher-large-video"),
    declared_digest: None,
    preview_path: None,
    app_entrypoint: None,
  })
  @fsx.write_to_file(
    dir + "/outputs-selection.json",
    selections.to_json().stringify(indent=2),
    create=0o644,
  )
  let package = @agent.pack_agent(
    root,
    version="portable-v1",
    output=dir + "/sender-v1.moonbook-agent",
    outputs=selections,
  )
  let source = @agent.describe_portable_source(package)
  @fsx.write_to_file(
    dir + "/source.json",
    source.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  let bundle = @agent.read_agent_bundle(package)
  assert_eq(source.included_output_count, 10)
  assert_eq(source.reference_only_count, 1)
  assert_eq(
    bundle.files
    .filter(file => {
      file.path.has_prefix("memory/") && file.path.contains("desk-")
    })
    .length(),
    4,
  )
  for file in bundle.files {
    if file.path.has_prefix("memory/") && file.path.contains("desk-") {
      let text = @utf8.decode(
        @base64.decode(file.content, ignore_whitespace=false),
      )
      assert_true(text.contains("## Acceptance provenance"))
      assert_true(text.contains("moondesk.learning-proposal.v1"))
    }
  }
  @fsx.write_to_file(
    dir + "/expected-outputs.json",
    expected.to_json().stringify(indent=2),
    create=0o644,
  )
  // The original carried package remains untouched after publisher evolution.
  @fsx.write_to_file(
    root + "/IDENTITY.md",
    "# Changed active publisher\n",
    create=0o644,
  )
  @fsx.write_to_file(
    root + "/outputs/answer.md",
    "# New v2 output\n",
    create=0o644,
  )
  @agent.pack_agent(
    root,
    version="portable-v2",
    output=dir + "/sender-v2.moonbook-agent",
    outputs=selections,
  )
  |> ignore
  @fsx.write_to_file(
    dir + "/source-v2.json",
    @agent.describe_portable_source(dir + "/sender-v2.moonbook-agent")
    .to_json()
    .stringify(indent=2) +
    "\n",
    create=0o644,
  )
}

///|
async test "portable journey imports the original file using recipient Town expectation and rejects newer file" {
  guard @env.get_env_var("MOONBOOK_PORTABLE_FIXTURE_MODE") is Some("import") else {
    return
  }
  let dir = @env.get_env_var("MOONBOOK_PORTABLE_FIXTURE_DIR").unwrap()
  let inbox = dir + "/recipient-inbox"
  @fsx.make_directory(inbox, recursive=true, exists_ok=true)
  let package = inbox + "/carried-v1.moonbook-agent"
  // Explicit local file transfer. Town has carried the descriptor, not bytes.
  @fsx.write_bytes(
    package,
    @fsx.read_bytes(dir + "/sender-v1.moonbook-agent"),
    create=0o644,
  )
  let binding_path = dir + "/town-binding.json"
  let binding : @agent.PortableTownBinding = @json.from_json(
    @json.parse(@fsx.read_file(binding_path)),
  )
  let rejected = dir + "/recipient-suite/books/rejected-v2"
  let error_message = try
    @agent.import_agent_bundle_exact(
      dir + "/sender-v2.moonbook-agent",
      rejected,
      binding_path,
    )
  catch {
    error => "\{error}"
  } noraise {
    _ => fail("v2 cannot satisfy retained v1 expectation")
  }
  assert_false(@fsx.exists(rejected))
  let target = dir + "/recipient-suite/books/different-local-name"
  let receipt = @agent.import_agent_bundle_exact(package, target, binding_path)
  assert_eq(receipt.source, binding.source)
  assert_true(receipt.local_book_id != receipt.source.agent_id)
  assert_true(@agent.verify_portable_import_members(package, target).is_empty())
  assert_true(@fsx.exists(target + "/book.toml"))
  assert_false(@fsx.exists(target + "/book.json"))
  assert_true(
    @fsx.read_file(target + "/portable/outputs/output-7/answer.md") !=
    @fsx.read_file(dir + "/sender-book/outputs/answer.md"),
  )
  let bundle = @agent.read_agent_bundle(package)
  let proofs : Array[Json] = []
  for file in bundle.files {
    let bytes = @fsx.read_bytes(target + "/" + file.path)
    assert_eq(bytes, @base64.decode(file.content, ignore_whitespace=false))
    proofs.push({
      "path": file.path,
      "digest": file.digest,
      "size_bytes": bytes.length(),
      "bytes_identical": true,
    })
  }
  @fsx.write_to_file(
    dir + "/roundtrip-proof.json",
    (
      {
        "contract": "moonbook.portable_roundtrip_proof.v1",
        "transfer": "explicit_local_file_copy",
        "town_transferred_package_bytes": false,
        "publisher_changed_after_export": true,
        "source": receipt.source,
        "binding_digest": receipt.binding_digest,
        "receipt": receipt,
        "member_proofs": proofs,
        "newer_file_rejected_before_target_creation": true,
        "rejection": error_message,
        "model_or_supervisor_invocations": 0,
        "office_fixture_scope": "opaque byte fidelity, no rendering or execution claim",
        "desk_discovery_pending": true,
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
}
