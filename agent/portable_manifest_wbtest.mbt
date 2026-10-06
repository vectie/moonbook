///|
async test "verified bundle rejects a self-consistent manifest with missing app member before import" {
  let root = "/tmp/portable-manifest-" + @async.now().to_string()
  @wiki.init_workspace(root) |> ignore
  @fsx.make_directory(root + "/outputs", recursive=true, exists_ok=true)
  @fsx.write_bytes(root + "/outputs/index.html", b"<p>app</p>", create=0o644)
  let selection : PortableOutputSelection = {
    artifact_id: "app",
    label: "app",
    mime_type: "text/html",
    included: true,
    files: [{ source_path: "outputs/index.html", path: "index.html", }],
    reference: None,
    declared_digest: None,
    preview_path: None,
    app_entrypoint: Some("index.html"),
  }
  let bundle = build_agent_bundle(root, outputs=[selection])
  let files = bundle.files.copy()
  for i, file in files {
    if file.path == portable_outputs_manifest_path() {
      let manifest = portable_manifest_from_files(files).unwrap()
      let outputs = manifest.outputs.copy()
      outputs[0] = {
        ..outputs[0],
        app_entrypoint: Some("portable/outputs/app/missing.html"),
      }
      let bytes = @utf8.encode({ ..manifest, outputs, }.to_json().stringify())
      files[i] = {
        ..file,
        digest: agent_sha256_bytes(bytes),
        size_bytes: bytes.length(),
        content: @base64.encode(bytes, padding=true),
      }
    }
  }
  let invalid = { ..bundle, files, book_revision: agent_book_revision(files), }
  let invalid = { ..invalid, bundle_digest: agent_bundle_digest(invalid), }
  let package = root + "/tampered.moonbook-agent"
  @fsx.write_to_file(package, invalid.to_json().stringify(), create=0o644)
  let verification = verify_agent_bundle(package)
  assert_false(verification.ok)
  assert_true(
    verification.issues.any(issue => issue.contains("app entrypoint")),
  )
  try describe_portable_source(package) catch {
    _ => ()
  } noraise {
    _ => fail("invalid app manifest cannot yield source descriptor")
  }
  @fs.rmdir(root, recursive=true)
}

///|
async test "failed exact application preserves original conflict and emits no complete receipt" {
  let root = "/tmp/portable-partial-" + @async.now().to_string()
  @wiki.init_workspace(root) |> ignore
  let bundle = build_agent_bundle(root)
  let files = bundle.files.copy()
  let bytes = b"fixture obstruction"
  files.push({
    path: "book.toml/child",
    role: "artifact",
    encoding: "base64",
    digest: agent_sha256_bytes(bytes),
    size_bytes: bytes.length(),
    review_status: "accepted",
    sensitivity: "book-exportable",
    content: @base64.encode(bytes, padding=true),
  })
  files.sort_by((a, b) => a.path.compare(b.path))
  let bundle = { ..bundle, files, book_revision: agent_book_revision(files), }
  let bundle = { ..bundle, bundle_digest: agent_bundle_digest(bundle), }
  let package = root + "/obstruction.moonbook-agent"
  @fsx.write_to_file(package, bundle.to_json().stringify(), create=0o644)
  let source = describe_portable_source(package)
  let binding : PortableTownBinding = {
    contract: "moontown.portable-listing-binding.v1",
    listing_id: "obstruction",
    publisher_principal_id: "owner",
    tenant_id: "fixture",
    binding_revision: 1,
    source,
    reuse_mode: "local_file_import",
    verification_scope: "publisher_declared_expected_source",
    binding_digest: "",
  }
  let binding = { ..binding, binding_digest: portable_binding_digest(binding), }
  let binding_path = root + "/binding.json"
  @fsx.write_to_file(binding_path, binding.to_json().stringify(), create=0o644)
  let target = root + "-partial-target"
  let error_message = try
    import_agent_bundle_exact(package, target, binding_path)
  catch {
    error => "\{error}"
  } noraise {
    _ => fail("fixture must expose initialization/application conflict")
  }
  assert_true(
    error_message.contains("destination parent is not a plain directory"),
  )
  assert_true(@fsx.exists(target))
  assert_false(@fsx.exists(target + "/state/portable-source-binding.json"))
  @fs.rmdir(root, recursive=true)
  @fs.rmdir(target, recursive=true)
}
