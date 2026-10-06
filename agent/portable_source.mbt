///|
/// Identity of the exact file supplied by its publisher, separate from a local
/// workspace identity. package_sha256 covers the original serialization.
pub(all) struct PortableSource {
  contract : String
  bundle_contract : String
  agent_id : String
  agent_version : String
  book_revision : String
  bundle_digest : String
  package_filename : String
  package_size_bytes : Int
  package_sha256 : String
  file_count : Int
  total_decoded_bytes : Int
  outputs_manifest_path : String?
  outputs_manifest_digest : String?
  included_output_count : Int
  reference_only_count : Int
  transport : String
} derive(Debug, Eq)

///|
pub impl ToJson for PortableSource with fn to_json(self) {
  {
    "contract": self.contract,
    "bundle_contract": self.bundle_contract,
    "agent_id": self.agent_id,
    "agent_version": self.agent_version,
    "book_revision": self.book_revision,
    "bundle_digest": self.bundle_digest,
    "package_filename": self.package_filename,
    "package_size_bytes": self.package_size_bytes,
    "package_sha256": self.package_sha256,
    "file_count": self.file_count,
    "total_decoded_bytes": self.total_decoded_bytes,
    "outputs_manifest_path": self.outputs_manifest_path
    .map(value => value.to_json())
    .unwrap_or(Json::null()),
    "outputs_manifest_digest": self.outputs_manifest_digest
    .map(value => value.to_json())
    .unwrap_or(Json::null()),
    "included_output_count": self.included_output_count,
    "reference_only_count": self.reference_only_count,
    "transport": self.transport,
  }
}

///|
fn[T : @json.FromJson] portable_source_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  guard fields.get(key) is Some(value) else {
    raise @json.JsonDecodeError((path, "missing source field: " + key))
  }
  @json.from_json(value, path~)
}

///|
fn portable_nullable_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> String? raise @json.JsonDecodeError {
  match fields.get(key) {
    Some(Null) => None
    Some(String(value)) => Some(value)
    _ => raise @json.JsonDecodeError((path, "expected null or string: " + key))
  }
}

///|
pub impl @json.FromJson for PortableSource with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected portable source object"))
  }
  {
    contract: portable_source_field(fields, "contract", path),
    bundle_contract: portable_source_field(fields, "bundle_contract", path),
    agent_id: portable_source_field(fields, "agent_id", path),
    agent_version: portable_source_field(fields, "agent_version", path),
    book_revision: portable_source_field(fields, "book_revision", path),
    bundle_digest: portable_source_field(fields, "bundle_digest", path),
    package_filename: portable_source_field(fields, "package_filename", path),
    package_size_bytes: portable_source_field(
      fields, "package_size_bytes", path,
    ),
    package_sha256: portable_source_field(fields, "package_sha256", path),
    file_count: portable_source_field(fields, "file_count", path),
    total_decoded_bytes: portable_source_field(
      fields, "total_decoded_bytes", path,
    ),
    outputs_manifest_path: portable_nullable_field(
      fields, "outputs_manifest_path", path,
    ),
    outputs_manifest_digest: portable_nullable_field(
      fields, "outputs_manifest_digest", path,
    ),
    included_output_count: portable_source_field(
      fields, "included_output_count", path,
    ),
    reference_only_count: portable_source_field(
      fields, "reference_only_count", path,
    ),
    transport: portable_source_field(fields, "transport", path),
  }
}

///|
/// A publisher-declared expectation received through Town. Its digest is an
/// integrity binding, not a signature or proof Town has verified package bytes.
pub(all) struct PortableTownBinding {
  contract : String
  listing_id : String
  publisher_principal_id : String
  tenant_id : String
  binding_revision : Int
  source : PortableSource
  reuse_mode : String
  verification_scope : String
  binding_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn portable_binding_digest(binding : PortableTownBinding) -> String {
  let unsigned : Json = {
    "contract": binding.contract,
    "listing_id": binding.listing_id,
    "publisher_principal_id": binding.publisher_principal_id,
    "tenant_id": binding.tenant_id,
    "binding_revision": binding.binding_revision,
    "source": binding.source,
    "reuse_mode": binding.reuse_mode,
    "verification_scope": binding.verification_scope,
  }
  agent_sha256_bytes(@utf8.encode(unsigned.stringify()))
}

///|
fn portable_check_binding(binding : PortableTownBinding) -> Unit raise {
  guard binding.contract == "moontown.portable-listing-binding.v1" &&
    binding.listing_id.trim() != "" &&
    binding.publisher_principal_id.trim() != "" &&
    binding.tenant_id.trim() != "" &&
    binding.binding_revision == 1 &&
    binding.reuse_mode == "local_file_import" &&
    binding.verification_scope == "publisher_declared_expected_source" &&
    portable_binding_digest(binding) == binding.binding_digest else {
    fail("invalid Town portable source binding")
  }
}

///|
fn portable_source_from_bytes(
  bytes : Bytes,
  filename : String,
) -> (PortableSource, AgentBundle) raise {
  let bundle : AgentBundle = @json.from_json(@json.parse(@utf8.decode(bytes)))
  let verification = agent_verify_bundle_value(bundle)
  guard verification.ok else {
    fail("agent bundle verification failed: " + verification.issues.join("; "))
  }
  let manifest = portable_manifest_from_files(bundle.files)
  let manifest_file = bundle.files
    .iter()
    .find_first(file => file.path == portable_outputs_manifest_path())
  let outputs = manifest.map(value => value.outputs).unwrap_or([])
  let source : PortableSource = {
    contract: "moonbook.portable_source.v1",
    bundle_contract: bundle.contract,
    agent_id: bundle.agent_id,
    agent_version: bundle.version,
    book_revision: bundle.book_revision,
    bundle_digest: bundle.bundle_digest,
    package_filename: agent_basename(filename),
    package_size_bytes: bytes.length(),
    package_sha256: agent_sha256_bytes(bytes),
    file_count: bundle.files.length(),
    total_decoded_bytes: bundle.files.fold(init=0, (total, file) => {
      total + file.size_bytes
    }),
    outputs_manifest_path: manifest_file.map(file => file.path),
    outputs_manifest_digest: manifest_file.map(file => file.digest),
    included_output_count: outputs.filter(item => item.included).length(),
    reference_only_count: outputs.filter(item => !item.included).length(),
    transport: "local_file",
  }
  (source, bundle)
}

///|
/// Verify all package bytes and the output manifest before returning a source.
pub async fn describe_portable_source(package_path : String) -> PortableSource {
  let (source, _) = portable_source_from_bytes(
    @fsx.read_bytes(package_path),
    package_path,
  )
  source
}

///|
/// Exact matching ignores only a local filename change: the filename is a
/// display leaf, while the byte hash and every content identity must match.
pub async fn verify_agent_bundle_against_source(
  package_path : String,
  expected : PortableSource,
) -> PortableSource {
  let actual = describe_portable_source(package_path)
  guard { ..actual, package_filename: expected.package_filename, } == expected else {
    fail("package does not match the expected portable source")
  }
  actual
}
