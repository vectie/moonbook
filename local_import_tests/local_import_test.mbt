///|
async fn local_import_fixture() -> (String, String) {
  let root = @fs.tmpdir(prefix="moonbook-local-import-")
  @wiki.init_workspace(root + "/publisher") |> ignore
  @fsx.write_to_file(
    root + "/publisher/IDENTITY.md",
    "# Reviewed identity\n\nLocal portable import fixture.\n",
  )
  @fsx.make_directory(
    root + "/publisher/outputs",
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_bytes(
    root + "/publisher/outputs/result.bin",
    ([0, 1, 127, 128, 255] : Bytes),
    create=0o644,
  )
  let output : @agent.PortableOutputSelection = {
    artifact_id: "binary",
    label: "Reviewed binary output",
    mime_type: "application/octet-stream",
    included: true,
    files: [{ source_path: "outputs/result.bin", path: "result.bin", }],
    reference: None,
    declared_digest: None,
    preview_path: None,
    app_entrypoint: None,
  }
  (root, @agent.pack_agent(root + "/publisher", outputs=[output]))
}

///|
async fn local_import_expect_rejection(
  package_path : String,
  target : String,
  expected_source? : @agent.PortableSource,
) -> Unit {
  try {
    match expected_source {
      Some(source) =>
        @agent.import_agent_bundle(package_path, target, expected_source=source)
      None => @agent.import_agent_bundle(package_path, target)
    }
  } catch {
    _ => ()
  } noraise {
    _ => fail("unreviewed or invalid package must be rejected")
  }
  assert_false(@fsx.exists(target))
}

///|
async test "ordinary import rejects missing malformed unsafe and tampered packages before creating a destination" {
  let (root, package_path) = local_import_fixture()
  local_import_expect_rejection(root + "/missing", root + "/missing-target")
  local_import_expect_rejection(
    root + "/missing",
    root + "/missing-parent/target",
  )
  assert_false(@fsx.exists(root + "/missing-parent"))
  let invalid = root + "/invalid.moonbook-agent"
  @fsx.write_to_file(invalid, "{not-json", create=0o644)
  local_import_expect_rejection(invalid, root + "/json-target")
  @fsx.write_to_file(invalid, "{}")
  local_import_expect_rejection(invalid, root + "/schema-target")
  let original = @fsx.read_file(package_path)
  let cases : Array[(String, Json)] = [
    ("path", "../outside.md"),
    ("encoding", "plain"),
    ("content", "not-base64!"),
    ("content", "dGFtcGVyZWQ="),
    ("review_status", "candidate"),
  ]
  for i, (field, value) in cases {
    let bundle = @json.parse(original)
    guard bundle is Object(fields) &&
      fields.get("files") is Some(Array(files)) &&
      files[0] is Object(first) else {
      fail("fixture has no package members")
    }
    first[field] = value
    @fsx.write_to_file(invalid, bundle.stringify())
    local_import_expect_rejection(invalid, root + "/invalid-" + i.to_string())
  }
  assert_false(@fsx.exists(root + "/outside.md"))
}

///|
async test "reviewed import rejects every source identity mismatch before creating a destination" {
  let (root, package_path) = local_import_fixture()
  let source = @agent.describe_portable_source(package_path)
  let wrong_digest = "sha256:" + "0".repeat(64)
  let cases : Array[@agent.PortableSource] = [
    { ..source, contract: "unexpected", },
    { ..source, bundle_contract: "unexpected", },
    { ..source, agent_id: "different-agent", },
    { ..source, agent_version: "different-version", },
    { ..source, book_revision: wrong_digest, },
    { ..source, bundle_digest: wrong_digest, },
    { ..source, package_sha256: wrong_digest, },
    { ..source, package_size_bytes: source.package_size_bytes + 1, },
    { ..source, file_count: source.file_count + 1, },
    { ..source, total_decoded_bytes: source.total_decoded_bytes + 1, },
    { ..source, outputs_manifest_path: Some("unexpected"), },
    { ..source, outputs_manifest_digest: Some(wrong_digest), },
    { ..source, included_output_count: source.included_output_count + 1, },
    { ..source, reference_only_count: source.reference_only_count + 1, },
    { ..source, transport: "unexpected", },
  ]
  for i, expected_source in cases {
    local_import_expect_rejection(
      package_path,
      root + "/mismatch-" + i.to_string(),
      expected_source~,
    )
  }
}

///|
async test "reviewed import rejects source replacement and changed serialization but accepts renamed exact bytes" {
  let (root, package_path) = local_import_fixture()
  let expected_source = @agent.describe_portable_source(package_path)
  let original = @fsx.read_bytes(package_path)
  let changed = root + "/selected.moonbook-agent"
  @fsx.write_to_file(
    changed,
    @json.parse(@fsx.read_file(package_path)).stringify(),
    create=0o644,
  )
  assert_true(@agent.verify_agent_bundle(changed).ok)
  local_import_expect_rejection(
    changed,
    root + "/reserialized-target",
    expected_source~,
  )
  @fsx.write_to_file(
    root + "/publisher/IDENTITY.md",
    "# Replacement identity\n",
  )
  @agent.pack_agent(root + "/publisher", output=changed) |> ignore
  assert_true(@agent.verify_agent_bundle(changed).ok)
  local_import_expect_rejection(
    changed,
    root + "/replacement-target",
    expected_source~,
  )
  @fsx.write_bytes(changed, original)
  let target = root + "/renamed-target"
  let receipt = @agent.import_agent_bundle(changed, target, expected_source~)
  assert_eq(receipt.action, "import")
  assert_eq(receipt.bundle_digest, expected_source.bundle_digest)
  assert_true(@agent.verify_portable_import_members(changed, target).is_empty())
  assert_false(@fsx.exists(target + "/state/portable-source-binding.json"))
}

///|
async test "ordinary and reviewed imports retain installation receipt rollback and existing-target behavior" {
  let (root, package_path) = local_import_fixture()
  let expected_source = @agent.describe_portable_source(package_path)
  let ordinary = @agent.import_agent_bundle(package_path, root + "/ordinary")
  let reviewed = @agent.import_agent_bundle(
    package_path,
    root + "/reviewed",
    expected_source~,
  )
  for receipt in [ordinary, reviewed] {
    assert_eq(receipt.contract, @agent.agent_installation_receipt_contract())
    assert_eq(receipt.action, "import")
    assert_eq(receipt.agent_id, expected_source.agent_id)
    assert_eq(receipt.version, expected_source.agent_version)
    assert_eq(receipt.bundle_digest, expected_source.bundle_digest)
    assert_true(receipt.rollback_available)
    assert_true(
      @agent.verify_portable_import_members(package_path, receipt.target_root).is_empty(),
    )
    assert_eq(
      @fsx.read_bytes(
        receipt.target_root + "/portable/outputs/binary/result.bin",
      ),
      ([0, 1, 127, 128, 255] : Bytes),
    )
    let identity = @fsx.read_bytes(receipt.target_root + "/IDENTITY.md")
    let installation = @fsx.read_bytes(
      receipt.target_root + "/state/agent-installation.json",
    )
    try
      @agent.import_agent_bundle(
        package_path,
        receipt.target_root,
        expected_source~,
      )
    catch {
      error => assert_true("\{error}".contains("target already exists"))
    } noraise {
      _ => fail("existing target must be preserved")
    }
    assert_eq(@fsx.read_bytes(receipt.target_root + "/IDENTITY.md"), identity)
    assert_eq(
      @fsx.read_bytes(receipt.target_root + "/state/agent-installation.json"),
      installation,
    )
    let rollback = @agent.rollback_agent_bundle(
      receipt.target_root,
      ".moonbook/agent/receipts/" + receipt.receipt_id + ".json",
    )
    assert_eq(rollback.receipt_id, receipt.receipt_id)
    assert_true(rollback.removed.contains("IDENTITY.md"))
    assert_false(@fsx.exists(receipt.target_root + "/IDENTITY.md"))
    assert_false(rollback.installation_restored)
  }
}

///|
async test "ordinary import preserves nested parent creation and reserves each destination exclusively" {
  let (root, package_path) = local_import_fixture()
  let target = root + "/new-parent/nested/book"
  let receipts : Array[@agent.AgentInstallationReceipt] = []
  let failures : Array[String] = []
  @async.with_task_group(group => {
    for _ in 0..<2 {
      group.spawn_bg(() => {
        try @agent.import_agent_bundle(package_path, target) catch {
          error => failures.push("\{error}")
        } noraise {
          receipt => receipts.push(receipt)
        }
      })
    }
  })
  assert_eq(receipts.length(), 1)
  assert_eq(failures.length(), 1)
  assert_true(
    @agent.verify_portable_import_members(package_path, target).is_empty(),
  )
  let dangling = root + "/dangling-target"
  let outside = root + "/never-create-outside"
  @fs.symlink(target=outside, dangling)
  try @agent.import_agent_bundle(package_path, dangling) catch {
    _ => ()
  } noraise {
    _ => fail("dangling destination symlink must not be followed")
  }
  assert_false(@fsx.exists(outside))
  assert_true(@fs.kind(dangling, follow_symlink=false) != Directory)
}

///|
async test "Town exact import retains its distinct source binding and receipt" {
  let (root, package_path) = local_import_fixture()
  let source = @agent.describe_portable_source(package_path)
  let unsigned : Json = {
    "contract": "moontown.portable-listing-binding.v1",
    "listing_id": "local-import-regression-listing",
    "publisher_principal_id": "fixture-publisher",
    "tenant_id": "fixture-tenant",
    "binding_revision": 1,
    "source": source,
    "reuse_mode": "local_file_import",
    "verification_scope": "publisher_declared_expected_source",
  }
  let binding : @agent.PortableTownBinding = {
    contract: "moontown.portable-listing-binding.v1",
    listing_id: "local-import-regression-listing",
    publisher_principal_id: "fixture-publisher",
    tenant_id: "fixture-tenant",
    binding_revision: 1,
    source,
    reuse_mode: "local_file_import",
    verification_scope: "publisher_declared_expected_source",
    binding_digest: "sha256:" +
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(unsigned.stringify())),
    ),
  }
  let binding_path = root + "/binding.json"
  @fsx.write_to_file(binding_path, binding.to_json().stringify(), create=0o644)
  let receipt = @agent.import_agent_bundle_exact(
    package_path,
    root + "/town",
    binding_path,
  )
  assert_eq(receipt.contract, "moonbook.portable_import_receipt.v1")
  assert_eq(receipt.source, source)
  assert_eq(receipt.binding_digest, binding.binding_digest)
  assert_true(receipt.member_bytes_verified)
  assert_eq(receipt.status, "complete")
  assert_eq(
    @fsx.read_file(root + "/town/state/portable-source-binding.json"),
    receipt.to_json().stringify(indent=2) + "\n",
  )
}
