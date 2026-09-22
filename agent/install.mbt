///|
fn agent_installation_path(root : String) -> String {
  @pathx.join(root, "state/agent-installation.json")
}

///|
// An accepted bundle path is still unsafe when an existing destination
// component is a symlink. Check before reading rollback material or writing.
async fn agent_check_target(root : String, relative : String) -> Unit {
  if !agent_relative_path_safe(relative) ||
    @fs.kind(root, follow_symlink=false) != Directory {
    fail("agent destination is not a plain book directory")
  }
  let parts = relative.split("/").to_array()
  let mut current = root
  for index, part in parts {
    current = @pathx.join(current, part.to_owned())
    let kind = @fs.kind(current, follow_symlink=false) catch {
      @os_error.OSError(_) as error if error.is_ENOENT() => return
      error => raise error
    }
    if index + 1 < parts.length() {
      if kind != Directory {
        fail("agent destination parent is not a plain directory")
      }
    } else if kind != Regular {
      fail("agent destination is not a regular file")
    }
  }
}

///|
fn agent_receipt_relative_path(receipt_id : String) -> String {
  ".moonbook/agent/receipts/" + receipt_id + ".json"
}

///|
fn agent_path_is_protected(path : String) -> Bool {
  [
    "IDENTITY.md", "AGENTS.md", "USER.md", "ROUTINES.md", "keeper/USER.md", "keeper/POLICY.md",
  ].contains(path)
}

///|
async fn agent_bundle_for_application(bundle_path : String) -> AgentBundle {
  let verification = verify_agent_bundle(bundle_path)
  if !verification.ok {
    fail("agent bundle verification failed: " + verification.issues.join("; "))
  }
  read_agent_bundle(bundle_path)
}

///|
pub async fn plan_agent_merge(
  bundle_path : String,
  target_root : String,
) -> AgentMergePlan {
  let bundle = agent_bundle_for_application(bundle_path)
  let root = @pathx.normalize(target_root)
  if !@fsx.exists(root) {
    fail("merge target does not exist")
  }
  let add : Array[String] = []
  let replace : Array[String] = []
  let unchanged : Array[String] = []
  let protected_conflicts : Array[String] = []
  for file in bundle.files {
    agent_check_target(root, file.path)
    let target = @pathx.join(root, file.path)
    if !@fsx.exists(target) {
      add.push(file.path)
    } else {
      let current = @fsx.read_bytes(target)
      if agent_sha256_bytes(current) == file.digest {
        unchanged.push(file.path)
      } else {
        replace.push(file.path)
        if agent_path_is_protected(file.path) {
          protected_conflicts.push(file.path)
        }
      }
    }
  }
  {
    contract: agent_merge_plan_contract(),
    agent_id: bundle.agent_id,
    version: bundle.version,
    bundle_digest: bundle.bundle_digest,
    target_root: root,
    add,
    replace,
    unchanged,
    protected_conflicts,
    applies_changes: false,
  }
}

///|
/// Persist a non-applying merge preview inside the target book.
pub async fn write_agent_merge_plan(
  bundle_path : String,
  target_root : String,
) -> String {
  let plan = plan_agent_merge(bundle_path, target_root)
  agent_check_target(plan.target_root, "state/agent-merge-plan.json")
  let path = @pathx.join(plan.target_root, "state/agent-merge-plan.json")
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    path,
    plan.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  path
}

///|
async fn agent_previous_file(root : String, path : String) -> AgentPriorFile {
  let absolute = @pathx.join(root, path)
  if @fsx.exists(absolute) {
    let content = @fsx.read_bytes(absolute)
    {
      path,
      existed: true,
      encoding: "base64",
      digest: agent_sha256_bytes(content),
      content: @base64.encode(content, padding=true),
    }
  } else {
    { path, existed: false, encoding: "base64", digest: "", content: "", }
  }
}

///|
async fn agent_previous_installation(root : String) -> String {
  let path = agent_installation_path(root)
  if @fsx.exists(path) {
    @base64.encode(@fsx.read_bytes(path), padding=true)
  } else {
    ""
  }
}

///|
async fn apply_agent_bundle(
  bundle_path : String,
  target_root : String,
  action : String,
) -> AgentInstallationReceipt {
  let bundle = agent_bundle_for_application(bundle_path)
  let root = @pathx.normalize(target_root)
  if !@fsx.exists(root) {
    fail("agent installation target does not exist")
  }
  let created_at = @env.now().to_int64()
  let receipt_id = agent_slug(bundle.agent_id) +
    "-" +
    agent_slug(bundle.version) +
    "-" +
    created_at.to_string()
  let previous_files : Array[AgentPriorFile] = []
  agent_check_target(root, agent_receipt_relative_path(receipt_id))
  agent_check_target(root, "state/agent-installation.json")
  for file in bundle.files {
    agent_check_target(root, file.path)
    previous_files.push(agent_previous_file(root, file.path))
  }
  let receipt : AgentInstallationReceipt = {
    contract: agent_installation_receipt_contract(),
    receipt_id,
    action,
    agent_id: bundle.agent_id,
    version: bundle.version,
    bundle_digest: bundle.bundle_digest,
    target_root: root,
    created_at,
    applied_files: bundle.files.map(file => file.path),
    previous_files,
    previous_installation: agent_previous_installation(root),
    rollback_available: true,
  }
  let receipt_relative = agent_receipt_relative_path(receipt_id)
  let receipt_path = @pathx.join(root, receipt_relative)
  @fsx.make_directory(
    @pathx.dirname(receipt_path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  // Write the rollback material before changing any book-owned file.
  @fsx.write_to_file(
    receipt_path,
    receipt.to_json().stringify(indent=2) + "\n",
    create=0o600,
  )
  for file in bundle.files {
    let target = @pathx.join(root, file.path)
    @fsx.make_directory(
      @pathx.dirname(target).to_owned(),
      recursive=true,
      exists_ok=true,
    )
    let content = @base64.decode(file.content, ignore_whitespace=false)
    @fsx.write_bytes(target, content, create=0o644)
  }
  let state : AgentInstallationState = {
    contract: agent_installation_state_contract(),
    agent_id: bundle.agent_id,
    version: bundle.version,
    bundle_digest: bundle.bundle_digest,
    installed_at: created_at,
    receipt_path: receipt_relative,
  }
  let state_path = agent_installation_path(root)
  @fsx.make_directory(
    @pathx.dirname(state_path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    state_path,
    state.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  receipt
}

///|
/// Import into a new MoonBook workspace. Existing targets fail closed.
pub async fn import_agent_bundle(
  bundle_path : String,
  target_root : String,
) -> AgentInstallationReceipt {
  let root = @pathx.normalize(target_root)
  if @fsx.exists(root) {
    fail(
      "agent import target already exists; use merge to preview or upgrade to apply",
    )
  }
  @wiki.init_workspace(root) |> ignore
  apply_agent_bundle(bundle_path, root, "import")
}

///|
/// Apply a verified bundle to an existing book after the caller has inspected
/// the merge plan. Every overwritten file is captured in a rollback receipt.
pub async fn upgrade_agent_bundle(
  bundle_path : String,
  target_root : String,
) -> AgentInstallationReceipt {
  let root = @pathx.normalize(target_root)
  if !@fsx.exists(root) {
    fail("agent upgrade target does not exist")
  }
  apply_agent_bundle(bundle_path, root, "upgrade")
}

///|
pub async fn rollback_agent_bundle(
  target_root : String,
  receipt_ref : String,
) -> AgentRollbackResult {
  let root = @pathx.normalize(target_root)
  let receipt_path = if @pathx.is_absolute(receipt_ref) {
    @pathx.normalize(receipt_ref)
  } else {
    @pathx.join(root, receipt_ref)
  }
  let receipt : AgentInstallationReceipt = @json.from_json(
    @json.parse(@fsx.read_file(receipt_path)),
  )
  if receipt.contract != agent_installation_receipt_contract() {
    fail("unsupported agent installation receipt")
  }
  if @pathx.normalize(receipt.target_root) != root {
    fail("rollback receipt belongs to a different book")
  }
  let restored : Array[String] = []
  let removed : Array[String] = []
  agent_check_target(root, "state/agent-installation.json")
  // Validate every destination and old payload before the first rollback
  // mutation, so a late corrupt entry cannot produce a partial restoration.
  for previous in receipt.previous_files {
    agent_check_target(root, previous.path)
    if previous.existed {
      if previous.encoding != "base64" {
        fail("rollback receipt uses an unsupported encoding")
      }
      let content = @base64.decode(previous.content, ignore_whitespace=false)
      if agent_sha256_bytes(content) != previous.digest {
        fail("rollback content digest mismatch")
      }
    }
  }
  for previous in receipt.previous_files {
    if !agent_relative_path_safe(previous.path) {
      fail("rollback receipt contains an unsafe path")
    }
    let target = @pathx.join(root, previous.path)
    if previous.existed {
      if previous.encoding != "base64" {
        fail("rollback receipt uses an unsupported encoding")
      }
      let content = @base64.decode(previous.content, ignore_whitespace=false)
      if agent_sha256_bytes(content) != previous.digest {
        fail("rollback content digest mismatch for " + previous.path)
      }
      @fsx.make_directory(
        @pathx.dirname(target).to_owned(),
        recursive=true,
        exists_ok=true,
      )
      @fsx.write_bytes(target, content, create=0o644)
      restored.push(previous.path)
    } else if @fsx.exists(target) {
      @fs.remove(target)
      removed.push(previous.path)
    }
  }
  let installation_path = agent_installation_path(root)
  let installation_restored = receipt.previous_installation != ""
  if installation_restored {
    @fsx.write_bytes(
      installation_path,
      @base64.decode(receipt.previous_installation, ignore_whitespace=false),
      create=0o644,
    )
  } else if @fsx.exists(installation_path) {
    @fs.remove(installation_path)
  }
  {
    contract: agent_rollback_result_contract(),
    receipt_id: receipt.receipt_id,
    target_root: root,
    restored,
    removed,
    installation_restored,
  }
}
