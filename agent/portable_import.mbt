///|
pub struct PortableImportReceipt {
  contract : String
  source : PortableSource
  listing_id : String
  publisher_principal_id : String
  tenant_id : String
  binding_digest : String
  installation_receipt_id : String
  local_target_root : String
  local_book_id : String
  imported_at : Int64
  member_bytes_verified : Bool
  status : String
} derive(Debug, Eq, ToJson, FromJson)

///|
async fn portable_check_members(
  bundle : AgentBundle,
  root : String,
) -> Array[String] {
  let changed : Array[String] = []
  for file in bundle.files {
    let matches = try {
      agent_check_target(root, file.path)
      let bytes = @fsx.read_bytes(@pathx.join(root, file.path))
      bytes.length() == file.size_bytes &&
      agent_sha256_bytes(bytes) == file.digest
    } catch {
      _ => false
    }
    if !matches {
      changed.push(file.path)
    }
  }
  changed
}

///|
/// Recheck actual current members against the retained package, without
/// repacking or treating an old import receipt as a current-content proof.
pub async fn verify_portable_import_members(
  package_path : String,
  target_root : String,
) -> Array[String] {
  let (_, bundle) = portable_source_from_bytes(
    @fsx.read_bytes(package_path),
    package_path,
  )
  portable_check_members(bundle, @pathx.normalize(target_root))
}

///|
/// Import a locally supplied file after exact preflight against a Town binding.
/// No destination is initialized before preflight. Existing targets conflict.
pub async fn import_agent_bundle_exact(
  package_path : String,
  target_root : String,
  binding_path : String,
) -> PortableImportReceipt {
  let binding : PortableTownBinding = @json.from_json(
    @json.parse(@fsx.read_file(binding_path)),
  )
  portable_check_binding(binding)
  // Pin one immutable in-memory package snapshot. The importer cannot reread a
  // changed input file after preflight and accidentally install different bytes.
  let (actual, bundle) = portable_source_from_bytes(
    @fsx.read_bytes(package_path),
    package_path,
  )
  guard { ..actual, package_filename: binding.source.package_filename, } ==
    binding.source else {
    fail("package does not match the expected portable source")
  }
  let root = @pathx.normalize(target_root)
  guard !@fsx.exists(root) else { fail("exact import target already exists") }
  // Exact-import provenance belongs to the recipient, not a package member.
  guard !bundle.files.any(file => {
    file.path == "state/portable-source-binding.json"
  }) else {
    fail("package conflicts with the exact import receipt")
  }
  @wiki.init_workspace(root) |> ignore
  let installed = apply_agent_bundle_value(bundle, root, "import-exact")
  let drift = portable_check_members(bundle, root)
  guard drift.is_empty() else {
    fail(
      "incomplete exact import; member verification failed: " + drift.join(", "),
    )
  }
  let receipt : PortableImportReceipt = {
    contract: "moonbook.portable_import_receipt.v1",
    source: binding.source,
    listing_id: binding.listing_id,
    publisher_principal_id: binding.publisher_principal_id,
    tenant_id: binding.tenant_id,
    binding_digest: binding.binding_digest,
    installation_receipt_id: installed.receipt_id,
    local_target_root: root,
    local_book_id: @wiki.book_identity(root),
    imported_at: @env.now().to_int64(),
    member_bytes_verified: true,
    status: "complete",
  }
  @fsx.write_to_file(
    @pathx.join(root, "state/portable-source-binding.json"),
    receipt.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  receipt
}
