///|
const AgentBundleMaxFileBytes : Int = 16 * 1024 * 1024

///|
fn agent_sha256_bytes(content : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(content))
}

///|
fn agent_basename(path : String) -> String {
  let parts = path.split("/").to_array()
  if parts.is_empty() {
    path
  } else {
    parts[parts.length() - 1].to_owned()
  }
}

///|
fn agent_slug(value : String) -> String {
  let builder = StringBuilder::new()
  let mut dash = false
  let mut wrote_any = false
  for rune in value.to_lower() {
    let code = rune.to_int()
    if (code >= 97 && code <= 122) || (code >= 48 && code <= 57) {
      builder.write_char(rune)
      dash = false
      wrote_any = true
    } else if !dash && wrote_any {
      builder.write_char('-')
      dash = true
    }
  }
  let result = builder.to_string()
  let result = if result.has_suffix("-") {
    result[:result.length() - 1].to_owned()
  } else {
    result
  }
  if result == "" {
    "agent"
  } else {
    result
  }
}

///|
fn agent_version_valid(version : String) -> Bool {
  let value = version.trim()
  if value == "" || value.length() > 64 {
    return false
  }
  for rune in value {
    let code = rune.to_int()
    if !((code >= 97 && code <= 122) ||
      (code >= 65 && code <= 90) ||
      (code >= 48 && code <= 57) ||
      rune == '.' ||
      rune == '-' ||
      rune == '_') {
      return false
    }
  }
  true
}

///|
fn agent_relative_path_safe(path : String) -> Bool {
  let value = path.trim().to_owned()
  value != "" &&
  value != "." &&
  value != ".." &&
  !@pathx.is_absolute(value) &&
  !value.has_prefix("../") &&
  !value.contains("/../") &&
  !value.contains("\\") &&
  @pathx.normalize(value) == value
}

///|
fn agent_role_for_path(path : String) -> String {
  if path == "IDENTITY.md" || path == "AGENTS.md" || path == "KEEPER.md" {
    "identity"
  } else if path == "USER.md" || path == "keeper/USER.md" {
    "preference"
  } else if path == "ROUTINES.md" ||
    path == "RESOLVER.md" ||
    path == "keeper/POLICY.md" {
    "policy"
  } else if path == "MEMORY.md" ||
    path == "keeper/MEMORY.md" ||
    path.has_prefix("memory/beliefs/") {
    "memory"
  } else if path.has_prefix("memory/procedures/") ||
    path.has_prefix("memory/beliefs/") {
    "procedure"
  } else if path.has_prefix("skills/") {
    "skill"
  } else if path.has_prefix("schemas/") {
    "schema"
  } else if path.has_prefix("tools/") {
    "tool"
  } else if path.has_prefix("apps/") || path.has_prefix("portable/app-tool/") {
    "app"
  } else if path.has_prefix("capabilities/") {
    "capability"
  } else if path.has_prefix("evaluations/") {
    "evaluation"
  } else if path == "wiki/history/standing-watch.md" {
    "schedule"
  } else if path.has_prefix("extensions/") {
    "extension"
  } else if path.has_prefix("wiki/") {
    "knowledge"
  } else {
    "artifact"
  }
}

///|
fn agent_sensitivity_for_path(path : String) -> String {
  if path == "USER.md" || path == "keeper/USER.md" {
    "user-private"
  } else {
    "book-exportable"
  }
}

///|
fn agent_content_has_secret(content : Bytes) -> Bool {
  let text = @utf8.decode_lossy(content).to_lower()
  [
    "-----begin private key", "-----begin openssh private key", "\"api_key\": \"",
    "\"api-key\": \"", "\"access_token\": \"", "\"refresh_token\": \"", "\"password\": \"",
    "sk-proj-", "xoxb-",
  ].any(marker => text.contains(marker))
}

///|
fn agent_review_status_for_path(path : String, content : Bytes) -> String {
  let text = @utf8.decode_lossy(content).to_lower()
  if path.has_prefix("wiki/") {
    if text.contains("review_status: accepted") {
      "accepted"
    } else {
      "pending-review"
    }
  } else if path.has_prefix("memory/procedures/") ||
    path.has_prefix("memory/beliefs/") {
    if text.contains("\"status\": \"promoted\"") ||
      text.contains("status: promoted") ||
      text.contains("\"accepted\": true") {
      "accepted"
    } else {
      "candidate"
    }
  } else if path.has_prefix("capabilities/") || path.has_prefix("evaluations/") {
    if text.contains("\"adoption_authorized\": true") ||
      text.contains("\"result\": \"pass\"") ||
      text.contains("review_status: accepted") {
      "accepted"
    } else {
      "candidate"
    }
  } else {
    "accepted"
  }
}

///|
fn agent_export_file_allowed(path : String, review_status : String) -> Bool {
  if path.has_prefix("wiki/") && path != "wiki/history/standing-watch.md" {
    review_status == "accepted"
  } else if path.has_prefix("memory/procedures/") ||
    path.has_prefix("memory/beliefs/") ||
    path.has_prefix("capabilities/") ||
    path.has_prefix("evaluations/") {
    review_status == "accepted"
  } else {
    true
  }
}

///|
async fn agent_collect_file(
  root : String,
  relative : String,
  files : Array[AgentBundleFile],
  exclusions : Array[AgentBundleExclusion],
) -> Unit {
  if !agent_relative_path_safe(relative) ||
    files.any(file => file.path == relative) {
    return
  }
  let absolute = @pathx.join(root, relative)
  if !@fsx.exists(absolute) {
    return
  }
  let content = @fsx.read_bytes(absolute)
  if content.length() > AgentBundleMaxFileBytes {
    exclusions.push({
      path: relative,
      reason: "file exceeds portable-agent size policy",
    })
    return
  }
  if agent_content_has_secret(content) {
    exclusions.push({
      path: relative,
      reason: "possible credential or private key",
    })
    return
  }
  if @utf8.decode_lossy(content).contains(root) {
    exclusions.push({
      path: relative,
      reason: "contains a machine-local absolute path",
    })
    return
  }
  let review_status = agent_review_status_for_path(relative, content)
  if !agent_export_file_allowed(relative, review_status) {
    exclusions.push({
      path: relative,
      reason: "content is not accepted for agent activation",
    })
    return
  }
  files.push({
    path: relative,
    role: agent_role_for_path(relative),
    encoding: "base64",
    digest: agent_sha256_bytes(content),
    size_bytes: content.length(),
    review_status,
    sensitivity: agent_sensitivity_for_path(relative),
    content: @base64.encode(content, padding=true),
  })
}

///|
async fn agent_collect_tree(
  root : String,
  relative : String,
  files : Array[AgentBundleFile],
  exclusions : Array[AgentBundleExclusion],
) -> Unit {
  if !agent_relative_path_safe(relative) {
    return
  }
  let absolute = @pathx.join(root, relative)
  if !@fsx.exists(absolute) {
    return
  }
  match @fs.kind(absolute, follow_symlink=false) {
    Directory =>
      for child in @fsx.list_directory(absolute) {
        agent_collect_tree(
          root,
          relative + "/" + agent_basename(child),
          files,
          exclusions,
        )
      }
    Regular => agent_collect_file(root, relative, files, exclusions)
    _ =>
      exclusions.push({
        path: relative,
        reason: "symlinks and special files are not portable",
      })
  }
}

///|
fn agent_unsigned_bundle(bundle : AgentBundle) -> AgentBundle {
  { ..bundle, bundle_digest: "", }
}

///|
fn agent_bundle_digest(bundle : AgentBundle) -> String {
  @wiki.executable_sha256(agent_unsigned_bundle(bundle).to_json().stringify())
}

///|
fn agent_book_revision(files : Array[AgentBundleFile]) -> String {
  @wiki.executable_sha256(
    files.map(file => file.path + "|" + file.digest).join("\n"),
  )
}

///|
fn agent_dependency_lock(
  component : String,
  contract : String,
  version_range : String,
  required : Bool,
  capabilities : Array[String],
  migration : String,
) -> AgentDependencyLock {
  let capabilities = capabilities.copy()
  capabilities.sort()
  let unsigned : Json = {
    "component": component,
    "contract": contract,
    "version_range": version_range,
    "required": required,
    "capabilities": capabilities,
    "migration": migration,
  }
  {
    component,
    contract,
    version_range,
    required,
    capabilities,
    migration,
    lock_digest: @wiki.executable_sha256(unsigned.stringify()),
  }
}

///|
fn agent_dependency_lock_valid(lock : AgentDependencyLock) -> Bool {
  if lock.component.trim() == "" ||
    lock.contract.trim() == "" ||
    lock.version_range.trim() == "" ||
    lock.migration.trim() == "" {
    return false
  }
  let expected = agent_dependency_lock(
    lock.component,
    lock.contract,
    lock.version_range,
    lock.required,
    lock.capabilities,
    lock.migration,
  )
  expected.capabilities == lock.capabilities &&
  expected.lock_digest == lock.lock_digest
}

///|
fn agent_default_memory_policy() -> AgentMemoryPolicy {
  let policy = @wiki.keeper_memory_policy()
  {
    contract: policy.contract,
    active_entry_limit: policy.active_entry_limit,
    preference_entry_limit: policy.preference_entry_limit,
    working_entry_limit: policy.working_entry_limit,
    active_character_limit: policy.active_character_limit,
    preference_character_limit: policy.preference_character_limit,
    working_character_limit: policy.working_character_limit,
  }
}

///|
fn agent_memory_metrics(
  files : Array[AgentBundleFile],
  exclusions : Array[AgentBundleExclusion],
) -> AgentMemoryMetrics {
  let exported = files
    .filter(file => {
      file.role == "memory" ||
      file.role == "procedure" ||
      file.role == "preference"
    })
    .length()
  let rejected = exclusions
    .filter(item => {
      item.path == "USER.md" ||
      item.path.has_prefix("keeper/") ||
      item.path.has_prefix("memory/")
    })
    .length()
  {
    admitted: exported,
    rejected,
    deduplicated: 0,
    expired: 0,
    promoted: files.filter(file => file.role == "procedure").length(),
    exported,
  }
}

///|
fn agent_default_compatibility() -> AgentCompatibility {
  let dependency_locks = [
    agent_dependency_lock(
      "moonclaw",
      "moonclaw-task-stream.v2",
      ">=2 <3",
      true,
      ["general-agent", "typed-fragments", "durable-turns"],
      "Upgrade the task-stream adapter before activation.",
    ),
    agent_dependency_lock(
      "moonfort",
      "moonfort-artifact.v1",
      ">=1 <2",
      true,
      ["isolated-execution", "artifact-receipts", "explicit-promotion"],
      "Re-run capability trials in a compatible sandbox.",
    ),
    agent_dependency_lock(
      "moontown",
      "moontown-standing-goal.v1",
      ">=1 <2",
      false,
      ["standing-goals", "leases", "result-delivery"],
      "Import watch intent disabled until a compatible scheduler is available.",
    ),
    agent_dependency_lock(
      "moongate",
      "moongate-route.v1",
      ">=1 <2",
      true,
      ["model-routing", "latency-metrics", "token-metrics", "cost-metrics"],
      "Re-evaluate adopted capabilities on a compatible route.",
    ),
  ]
  {
    moonclaw_contract: "moonclaw-task-stream.v2",
    moonfort_contract: "moonfort-artifact.v1",
    moontown_contract: "moontown-standing-goal.v1",
    moongate_contract: "moongate-route.v1",
    required_capabilities: [
      "workspace.read", "workspace.relative-paths", "artifact.typed-location", "sandbox.required-for-executable-artifacts",
    ],
    dependency_locks,
  }
}

///|
fn agent_default_export_policy() -> AgentExportPolicy {
  {
    accepted_knowledge_only: true,
    include_working_memory: false,
    include_runtime_state: false,
    include_credentials: false,
    relative_paths_only: true,
  }
}

///|
/// Build a portable agent entirely from accepted, allow-listed MoonBook state.
pub async fn build_agent_bundle(
  root : String,
  version? : String = "1.0.0",
) -> AgentBundle {
  if !agent_version_valid(version) {
    fail("agent version must be a nonempty portable identifier")
  }
  let normalized_root = @pathx.normalize(root)
  let knowledge = @wiki.generate_knowledge_bundle(normalized_root)
  let files : Array[AgentBundleFile] = []
  let exclusions : Array[AgentBundleExclusion] = []
  for
    relative in [
      "IDENTITY.md", "AGENTS.md", "USER.md", "ROUTINES.md", "RESOLVER.md", "MEMORY.md",
      "KEEPER.md", "keeper/USER.md", "keeper/MEMORY.md", "keeper/POLICY.md", "wiki/history/standing-watch.md",
    ] {
    agent_collect_file(normalized_root, relative, files, exclusions)
  }
  for page in knowledge.pages {
    agent_collect_file(normalized_root, page.path, files, exclusions)
  }
  for
    relative in [
      "skills", "schemas", "tools", "apps", "portable/app-tool", "extensions", "memory/procedures",
      "memory/beliefs", "capabilities", "evaluations",
    ] {
    agent_collect_tree(normalized_root, relative, files, exclusions)
  }
  files.sort_by((left, right) => left.path.compare(right.path))
  exclusions.sort_by((left, right) => left.path.compare(right.path))
  let created_at = @env.now().to_int64()
  let initial : AgentBundle = {
    contract: agent_bundle_contract(),
    agent_id: knowledge.book_id,
    version,
    book_revision: agent_book_revision(files),
    created_at,
    knowledge_contract: knowledge.contract,
    compatibility: agent_default_compatibility(),
    export_policy: agent_default_export_policy(),
    memory_policy: agent_default_memory_policy(),
    memory_metrics: agent_memory_metrics(files, exclusions),
    files,
    exclusions,
    bundle_digest: "",
  }
  { ..initial, bundle_digest: agent_bundle_digest(initial), }
}

///|
/// Write one self-contained `.moonbook-agent` JSON artifact.
pub async fn pack_agent(
  root : String,
  version? : String = "1.0.0",
  output? : String,
) -> String {
  let bundle = build_agent_bundle(root, version~)
  let normalized_root = @pathx.normalize(root)
  let path = output.unwrap_or(
    @pathx.join(
      normalized_root,
      "book/agents/" +
      agent_slug(bundle.agent_id) +
      "-" +
      version +
      ".moonbook-agent",
    ),
  )
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    path,
    bundle.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  path
}

///|
pub async fn read_agent_bundle(path : String) -> AgentBundle {
  @json.from_json(@json.parse(@fsx.read_file(path)))
}

///|
pub async fn inspect_agent_bundle(path : String) -> AgentBundleInspection {
  let bundle = read_agent_bundle(path)
  let total_bytes = bundle.files.fold(init=0, (total, file) => {
    total + file.size_bytes
  })
  {
    contract: bundle.contract,
    agent_id: bundle.agent_id,
    version: bundle.version,
    book_revision: bundle.book_revision,
    bundle_digest: bundle.bundle_digest,
    file_count: bundle.files.length(),
    total_bytes,
    files: bundle.files.map(file => {
      path: file.path,
      role: file.role,
      digest: file.digest,
      size_bytes: file.size_bytes,
      review_status: file.review_status,
      sensitivity: file.sensitivity,
    }),
    exclusions: bundle.exclusions,
    compatibility: bundle.compatibility,
    export_policy: bundle.export_policy,
    memory_policy: bundle.memory_policy,
    memory_metrics: bundle.memory_metrics,
  }
}

///|
pub async fn verify_agent_bundle(path : String) -> AgentBundleVerification {
  let issues : Array[String] = []
  let bundle = read_agent_bundle(path) catch {
    error =>
      return {
        ok: false,
        agent_id: "",
        version: "",
        bundle_digest: "",
        checked_file_count: 0,
        issues: ["bundle cannot be decoded: \{error}"],
      }
  }
  if bundle.contract != agent_bundle_contract() {
    issues.push("unsupported contract: " + bundle.contract)
  }
  if bundle.agent_id.trim() == "" {
    issues.push("agent_id is required")
  }
  if !agent_version_valid(bundle.version) {
    issues.push("version is invalid")
  }
  if !@wiki.executable_source_digest_is_valid(bundle.book_revision) {
    issues.push("book_revision is not a canonical sha256 digest")
  }
  if !bundle.export_policy.accepted_knowledge_only ||
    bundle.export_policy.include_working_memory ||
    bundle.export_policy.include_runtime_state ||
    bundle.export_policy.include_credentials ||
    !bundle.export_policy.relative_paths_only {
    issues.push("export policy is not portable-agent safe")
  }
  if bundle.memory_policy.contract != agent_memory_policy_contract() ||
    bundle.memory_policy.active_entry_limit <= 0 ||
    bundle.memory_policy.preference_entry_limit <= 0 ||
    bundle.memory_policy.working_entry_limit <= 0 ||
    bundle.memory_policy.active_character_limit <= 0 ||
    bundle.memory_policy.preference_character_limit <= 0 ||
    bundle.memory_policy.working_character_limit <= 0 {
    issues.push("memory policy is invalid")
  }
  let expected_memory_metrics = agent_memory_metrics(
    bundle.files,
    bundle.exclusions,
  )
  if bundle.memory_metrics != expected_memory_metrics {
    issues.push("memory metrics do not match the exported file set")
  }
  let seen_dependencies : Map[String, Unit] = Map([])
  for lock in bundle.compatibility.dependency_locks {
    if seen_dependencies.contains(lock.component) {
      issues.push("duplicate dependency lock: " + lock.component)
    } else {
      seen_dependencies[lock.component] = ()
    }
    if !agent_dependency_lock_valid(lock) {
      issues.push("invalid dependency lock: " + lock.component)
    }
  }
  for required in ["moonclaw", "moonfort", "moongate"] {
    if !seen_dependencies.contains(required) {
      issues.push("missing required dependency lock: " + required)
    }
  }
  let seen : Map[String, Unit] = Map([])
  let mut previous_path = ""
  for file in bundle.files {
    if !agent_relative_path_safe(file.path) {
      issues.push("unsafe file path: " + file.path)
    }
    if seen.contains(file.path) {
      issues.push("duplicate file path: " + file.path)
    } else {
      seen[file.path] = ()
    }
    if previous_path != "" && previous_path.compare(file.path) > 0 {
      issues.push("files are not in canonical path order")
    }
    previous_path = file.path
    if file.encoding != "base64" {
      issues.push("unsupported encoding for " + file.path)
      continue
    }
    let content = @base64.decode(file.content, ignore_whitespace=false) catch {
      _ => {
        issues.push("invalid base64 content for " + file.path)
        continue
      }
    }
    if content.length() != file.size_bytes {
      issues.push("size mismatch for " + file.path)
    }
    if agent_sha256_bytes(content) != file.digest {
      issues.push("digest mismatch for " + file.path)
    }
    if file.review_status != "accepted" {
      issues.push("non-accepted active file: " + file.path)
    }
    if agent_content_has_secret(content) {
      issues.push("possible credential in " + file.path)
    }
  }
  if agent_book_revision(bundle.files) != bundle.book_revision {
    issues.push("book revision does not match the file set")
  }
  if !@wiki.executable_source_digest_is_valid(bundle.bundle_digest) ||
    agent_bundle_digest(bundle) != bundle.bundle_digest {
    issues.push("bundle digest does not match canonical content")
  }
  {
    ok: issues.is_empty(),
    agent_id: bundle.agent_id,
    version: bundle.version,
    bundle_digest: bundle.bundle_digest,
    checked_file_count: bundle.files.length(),
    issues,
  }
}

///|
pub async fn diff_agent_bundles(
  left_path : String,
  right_path : String,
) -> AgentBundleDiff {
  let left = read_agent_bundle(left_path)
  let right = read_agent_bundle(right_path)
  let left_files : Map[String, String] = Map([])
  let right_files : Map[String, String] = Map([])
  for file in left.files {
    left_files[file.path] = file.digest
  }
  for file in right.files {
    right_files[file.path] = file.digest
  }
  let added : Array[String] = []
  let removed : Array[String] = []
  let changed : Array[String] = []
  let unchanged : Array[String] = []
  for path, digest in left_files {
    match right_files.get(path) {
      None => removed.push(path)
      Some(next) if next == digest => unchanged.push(path)
      Some(_) => changed.push(path)
    }
  }
  for path, _ in right_files {
    if !left_files.contains(path) {
      added.push(path)
    }
  }
  added.sort()
  removed.sort()
  changed.sort()
  unchanged.sort()
  {
    left_agent_id: left.agent_id,
    right_agent_id: right.agent_id,
    left_version: left.version,
    right_version: right.version,
    added,
    removed,
    changed,
    unchanged,
  }
}
