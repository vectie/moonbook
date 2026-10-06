///|
fn portable_test_selection(
  id : String,
  source : String,
) -> @agent.PortableOutputSelection {
  {
    artifact_id: id,
    label: "Explicit " + id,
    mime_type: "application/octet-stream",
    included: true,
    files: [{ source_path: source, path: "result.bin", }],
    reference: None,
    declared_digest: None,
    preview_path: None,
    app_entrypoint: None,
  }
}

///|
fn portable_test_binding(
  source : @agent.PortableSource,
) -> @agent.PortableTownBinding {
  let value : Json = {
    "contract": "moontown.portable-listing-binding.v1",
    "listing_id": "fixture-listing-v1",
    "publisher_principal_id": "owner-a",
    "tenant_id": "fixture-tenant",
    "binding_revision": 1,
    "source": source,
    "reuse_mode": "local_file_import",
    "verification_scope": "publisher_declared_expected_source",
  }
  let digest = "sha256:" +
    @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(value.stringify())))
  {
    contract: "moontown.portable-listing-binding.v1",
    listing_id: "fixture-listing-v1",
    publisher_principal_id: "owner-a",
    tenant_id: "fixture-tenant",
    binding_revision: 1,
    source,
    reuse_mode: "local_file_import",
    verification_scope: "publisher_declared_expected_source",
    binding_digest: digest,
  }
}

///|
async test "selected binary outputs exact import preserves bytes and source while legacy pack stays unchanged" {
  let root = agent_test_book("portable-outputs")
  @fsx.make_directory(root + "/outputs", recursive=true, exists_ok=true)
  let bytes : Bytes = [0, 1, 2, 127, 128, 255]
  @fsx.write_bytes(root + "/outputs/binary.bin", bytes, create=0o644)
  let selected = portable_test_selection("binary", "outputs/binary.bin")
  let reference : @agent.PortableOutputSelection = {
    ..selected,
    artifact_id: "large-reference",
    included: false,
    files: [],
    reference: Some("artifact:publisher-only-large-output"),
  }
  let legacy = @agent.build_agent_bundle(root)
  assert_false(
    legacy.files.any(file => file.path.has_prefix("portable/outputs")),
  )
  let package = @agent.pack_agent(root, outputs=[selected, reference])
  let source = @agent.describe_portable_source(package)
  assert_eq(source.included_output_count, 1)
  assert_eq(source.reference_only_count, 1)
  assert_true(
    source.outputs_manifest_path is Some("portable/outputs.manifest.v1.json"),
  )
  assert_true(@agent.verify_agent_bundle(package).ok)
  let binding = portable_test_binding(source)
  let binding_path = root + "/expected.json"
  @fsx.write_to_file(binding_path, binding.to_json().stringify(), create=0o644)
  let target = root + "-different-local-name"
  let receipt = @agent.import_agent_bundle_exact(package, target, binding_path)
  assert_eq(receipt.source, source)
  assert_true(receipt.member_bytes_verified)
  assert_eq(receipt.status, "complete")
  assert_true(receipt.local_book_id != source.agent_id)
  assert_eq(
    @fsx.read_bytes(target + "/portable/outputs/binary/result.bin"),
    bytes,
  )
  assert_true(@agent.verify_portable_import_members(package, target).is_empty())
  assert_false(@fsx.exists(target + "/portable/outputs/large-reference"))
  try @agent.import_agent_bundle_exact(package, target, binding_path) catch {
    _ => ()
  } noraise {
    _ => fail("existing target must conflict")
  }
  @fsx.write_bytes(target + "/portable/outputs/binary/result.bin", b"changed")
  assert_eq(@agent.verify_portable_import_members(package, target), [
    "portable/outputs/binary/result.bin",
  ])
  assert_eq(
    @fsx.read_file(target + "/state/portable-source-binding.json"),
    receipt.to_json().stringify(indent=2) + "\n",
  )
  @fs.rmdir(root, recursive=true)
  @fs.rmdir(target, recursive=true)
}

///|
async test "source mismatch and tampering fail before exact target creation" {
  let root = agent_test_book("portable-mismatch")
  let package = @agent.pack_agent(root)
  let source = @agent.describe_portable_source(package)
  let cases : Array[@agent.PortableSource] = [
    { ..source, agent_id: "different-agent", },
    { ..source, agent_version: "different-version", },
    { ..source, book_revision: "sha256:" + "0".repeat(64), },
    { ..source, bundle_digest: "sha256:" + "0".repeat(64), },
    { ..source, package_sha256: "sha256:" + "0".repeat(64), },
    { ..source, package_size_bytes: source.package_size_bytes + 1, },
    { ..source, file_count: source.file_count + 1, },
    { ..source, total_decoded_bytes: source.total_decoded_bytes + 1, },
    { ..source, included_output_count: 1, },
    { ..source, outputs_manifest_digest: Some("sha256:" + "0".repeat(64)), },
  ]
  for i, expected in cases {
    let binding_path = root + "/mismatch.json"
    @fsx.write_to_file(
      binding_path,
      portable_test_binding(expected).to_json().stringify(),
      create=0o644,
    )
    let target = root + "-rejected-" + i.to_string()
    try @agent.import_agent_bundle_exact(package, target, binding_path) catch {
      _ => ()
    } noraise {
      _ => fail("mismatch must fail preflight")
    }
    assert_false(@fsx.exists(target))
  }
  let rebound = root + "/different-format.moonbook-agent"
  @fsx.write_to_file(
    rebound,
    @json.parse(@fsx.read_file(package)).stringify(),
    create=0o644,
  )
  assert_true(@agent.verify_agent_bundle(rebound).ok)
  assert_true(
    @agent.describe_portable_source(rebound).package_sha256 !=
    source.package_sha256,
  )
  try @agent.verify_agent_bundle_against_source(rebound, source) catch {
    _ => ()
  } noraise {
    _ => fail("raw serialization is part of exact identity")
  }
  let original = @json.parse(@fsx.read_file(package))
  guard original is Object(fields) &&
    fields.get("files") is Some(Array(files)) &&
    files[0] is Object(first) else {
    fail("fixture bundle malformed")
  }
  first["content"] = "dGFtcGVyZWQ=".to_json()
  @fsx.write_to_file(rebound, original.stringify())
  try @agent.describe_portable_source(rebound) catch {
    _ => ()
  } noraise {
    _ => fail("inspect-only tamper must not yield verified source")
  }
  @fs.rmdir(root, recursive=true)
}

///|
async test "explicit output selection enforces missing excluded duplicate app and symlink boundaries" {
  let root = agent_test_book("portable-selection")
  @fsx.make_directory(root + "/outputs", recursive=true, exists_ok=true)
  @fsx.write_bytes(root + "/outputs/a.bin", b"A", create=0o644)
  @fsx.write_bytes(
    root + "/outputs/secret.bin",
    b"-----BEGIN PRIVATE KEY",
    create=0o644,
  )
  @fsx.write_bytes(root + "/outputs/b.bin", b"B", create=0o644)
  @fs.symlink(target=root + "/outputs/a.bin", root + "/outputs/link.bin")
  let a = portable_test_selection("a", "outputs/a.bin")
  let b = portable_test_selection("b", "outputs/b.bin")
  let bad : Array[Array[@agent.PortableOutputSelection]] = [
    [portable_test_selection("missing", "outputs/missing")],
    [portable_test_selection("secret", "outputs/secret.bin")],
    [portable_test_selection("link", "outputs/link.bin")],
    [portable_test_selection("outside", "../outputs/a.bin")],
    [a, a],
    [{ ..a, files: [a.files[0], a.files[0]], }],
    [
      {
        ..a,
        files: [{ source_path: "outputs/a.bin", path: "../../IDENTITY.md", }],
      },
    ],
    [{ ..a, app_entrypoint: Some("missing.html"), }],
    [{ ..a, preview_path: Some("missing.png"), }],
    [{ ..a, included: false, reference: Some("artifact:ref"), }],
  ]
  for outputs in bad {
    try @agent.build_agent_bundle(root, outputs~) catch {
      _ => ()
    } noraise {
      _ => fail("incomplete or invalid selection cannot succeed")
    }
  }
  let first = @agent.build_agent_bundle(root, outputs=[a, b])
  let reordered = @agent.build_agent_bundle(root, outputs=[b, a])
  // Existing knowledge projection timestamps can change on each pack. Only
  // explicit output canonicalization is independent of selection order.
  assert_true(
    first.files.filter(file => file.path.has_prefix("portable/outputs")) ==
    reordered.files.filter(file => file.path.has_prefix("portable/outputs")),
  )
  @fs.rmdir(root, recursive=true)
}

///|
async test "selected output size policy accepts exactly sixteen MiB and rejects one byte over" {
  let root = agent_test_book("portable-size")
  @fsx.make_directory(root + "/outputs", recursive=true, exists_ok=true)
  let path = root + "/outputs/limit.bin"
  @fsx.write_bytes(path, Bytes::make(16 * 1024 * 1024, 0), create=0o644)
  let selected = portable_test_selection("limit", "outputs/limit.bin")
  let bundle = @agent.build_agent_bundle(root, outputs=[selected])
  assert_true(
    bundle.files.any(file => {
      file.path == "portable/outputs/limit/result.bin" &&
      file.size_bytes == 16 * 1024 * 1024
    }),
  )
  @fsx.write_bytes(path, Bytes::make(16 * 1024 * 1024 + 1, 0))
  try @agent.build_agent_bundle(root, outputs=[selected]) catch {
    _ => ()
  } noraise {
    _ => fail("one byte over policy must fail explicit selection")
  }
  @fs.rmdir(root, recursive=true)
}

///|
async test "exact local identity follows existing Book basename semantics without refreshing imported pages" {
  let root = agent_test_book("portable-identities")
  let package = @agent.pack_agent(root)
  let source = @agent.describe_portable_source(package)
  let expected_path = root + "/binding.json"
  @fsx.write_to_file(
    expected_path,
    portable_test_binding(source).to_json().stringify(),
    create=0o644,
  )
  for
    (input, leaf) in [
      (root + "-targets/normal", "normal"),
      (root + "-targets/name with spaces", "name with spaces"),
      (root + "-targets/学习结果", "学习结果"),
      (root + "-targets/ignored/../normalized", "normalized"),
    ] {
    let receipt = @agent.import_agent_bundle_exact(
      package, input, expected_path,
    )
    assert_eq(receipt.local_book_id, @wiki.book_identity(input))
    assert_eq(receipt.local_book_id, leaf)
    assert_eq(receipt.source, source)
    assert_true(receipt.local_book_id != source.agent_id)
    assert_true(
      @agent.verify_portable_import_members(package, receipt.local_target_root).is_empty(),
    )
    @fs.rmdir(receipt.local_target_root, recursive=true)
  }
  @fs.rmdir(root, recursive=true)
  @fs.rmdir(root + "-targets", recursive=true)
}
