///|
async fn agent_test_book(label : String) -> String {
  let root = "/tmp/moonbook-agent-" +
    label +
    "-" +
    @async.now().to_int().to_string()
  @wiki.init_workspace(root) |> ignore
  @fsx.write_to_file(
    @pathx.join(root, "IDENTITY.md"),
    "# Identity\n\nPortable research assistant.\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(root, "keeper/USER.md"),
    "# Preferences\n\n- Prefer concise evidence.\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(root, "wiki/concepts/accepted.md"),
    "---\nmoonbook_type: concept\nreview_status: accepted\n---\n\n# Accepted\n\nDurable fact.\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(root, "wiki/concepts/pending.md"),
    "# Pending\n\nUnreviewed claim.\n",
    create=0o644,
  )
  root
}

///|
async test "agent bundle is portable accepted and content addressed" {
  let root = agent_test_book("portable")
  @fsx.make_directory(
    @pathx.join(root, "tools"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "tools/unsafe.json"),
    "{\"api_key\": \"sk-proj-not-exported\"}\n",
    create=0o600,
  )
  let path = pack_agent(root, version="2.1.0")
  let verification = verify_agent_bundle(path)
  assert_true(verification.ok)
  let bundle = read_agent_bundle(path)
  assert_true(bundle.created_at > 1577836800000L)
  assert_eq(bundle.contract, "moonbook.agent_bundle.v1")
  assert_eq(bundle.version, "2.1.0")
  assert_true(bundle.files.any(file => file.path == "IDENTITY.md"))
  assert_true(
    bundle.files.any(file => file.path == "wiki/concepts/accepted.md"),
  )
  assert_false(
    bundle.files.any(file => file.path == "wiki/concepts/pending.md"),
  )
  assert_false(bundle.files.any(file => file.path == "tools/unsafe.json"))
  assert_true(bundle.exclusions.any(item => item.path == "tools/unsafe.json"))
  assert_eq(bundle.memory_policy.contract, "moonbook.memory_policy.v1")
  assert_true(bundle.memory_metrics.exported > 0)
  assert_true(
    bundle.compatibility.dependency_locks.any(lock => {
      lock.component == "moonfort" &&
      lock.required &&
      lock.capabilities.contains("isolated-execution") &&
      lock.lock_digest.has_prefix("sha256:")
    }),
  )
  assert_false(bundle.to_json().stringify().contains(root))
  @fs.rmdir(root, recursive=true)
}

///|
async test "agent bundle verification detects payload tampering" {
  let root = agent_test_book("tamper")
  let path = pack_agent(root)
  let bundle = read_agent_bundle(path)
  let files = bundle.files.copy()
  guard files.length() > 0 else { fail("expected export files") }
  let replacement = @base64.encode(b"tampered", padding=true)
  let tampered = bundle
    .to_json()
    .stringify(indent=2)
    .replace(old=files[0].content, new=replacement)
    .to_string()
  let tampered_path = @pathx.join(root, "tampered.moonbook-agent")
  @fsx.write_to_file(tampered_path, tampered)
  let verification = verify_agent_bundle(tampered_path)
  assert_false(verification.ok)
  assert_true(verification.issues.any(issue => issue.contains("mismatch")))
  @fs.rmdir(root, recursive=true)
}

///|
async test "agent bundle verification detects compatibility lock tampering" {
  let root = agent_test_book("lock-tamper")
  let path = pack_agent(root)
  let bundle = read_agent_bundle(path)
  guard bundle.compatibility.dependency_locks.length() > 0 else {
    fail("expected dependency locks")
  }
  let tampered = bundle
    .to_json()
    .stringify(indent=2)
    .replace(old=">=2 <3", new=">=999")
    .to_string()
  let tampered_path = @pathx.join(root, "lock-tampered.moonbook-agent")
  @fsx.write_to_file(tampered_path, tampered + "\n")
  let verification = verify_agent_bundle(tampered_path)
  assert_false(verification.ok)
  assert_true(
    verification.issues.any(issue => issue.contains("dependency lock")),
  )
  @fs.rmdir(root, recursive=true)
}

///|
async test "agent import upgrade and rollback preserve prior book files" {
  let source = agent_test_book("source")
  let bundle_path = pack_agent(source, version="3.0.0")
  let target = "/tmp/moonbook-agent-target-" + @async.now().to_int().to_string()
  let imported = import_agent_bundle(bundle_path, target)
  assert_eq(imported.action, "import")
  assert_true(@fsx.exists(@pathx.join(target, "IDENTITY.md")))
  @fsx.write_to_file(
    @pathx.join(target, "IDENTITY.md"),
    "# Identity\n\nLocal edited identity.\n",
    create=0o644,
  )
  let plan = plan_agent_merge(bundle_path, target)
  assert_true(plan.protected_conflicts.contains("IDENTITY.md"))
  assert_false(plan.applies_changes)
  let upgraded = upgrade_agent_bundle(bundle_path, target)
  assert_true(
    @fsx.read_file(@pathx.join(target, "IDENTITY.md")).contains(
      "Portable research",
    ),
  )
  let receipt_path = ".moonbook/agent/receipts/\{upgraded.receipt_id}.json"
  let rolled_back = rollback_agent_bundle(target, receipt_path)
  assert_true(rolled_back.restored.contains("IDENTITY.md"))
  assert_true(
    @fsx.read_file(@pathx.join(target, "IDENTITY.md")).contains("Local edited"),
  )
  @fs.rmdir(source, recursive=true)
  @fs.rmdir(target, recursive=true)
}

///|
async test "agent diff reports added removed changed and unchanged paths" {
  let left_root = agent_test_book("diff-left")
  let right_root = agent_test_book("diff-right")
  @fsx.write_to_file(
    @pathx.join(right_root, "IDENTITY.md"),
    "# Identity\n\nA different assistant.\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(left_root, "skills/left"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(@pathx.join(left_root, "skills/left/SKILL.md"), "# Left\n")
  @fsx.make_directory(
    @pathx.join(right_root, "skills/right"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(right_root, "skills/right/SKILL.md"),
    "# Right\n",
  )
  let left = pack_agent(left_root, version="1.0.0")
  let right = pack_agent(right_root, version="2.0.0")
  let diff = diff_agent_bundles(left, right)
  assert_true(diff.changed.contains("IDENTITY.md"))
  assert_true(diff.removed.contains("skills/left/SKILL.md"))
  assert_true(diff.added.contains("skills/right/SKILL.md"))
  assert_true(diff.unchanged.contains("keeper/USER.md"))
  @fs.rmdir(left_root, recursive=true)
  @fs.rmdir(right_root, recursive=true)
}

///|
async test "agent upgrade rejects symlink destinations before changing outside files" {
  let source = agent_test_book("symlink-source")
  let target = agent_test_book("symlink-target")
  let external = @pathx.join(source, "outside.txt")
  @fsx.write_to_file(external, "outside must remain unchanged")
  let bundle = pack_agent(source)
  let identity = @pathx.join(target, "IDENTITY.md")
  @fs.remove(identity)
  @fs.symlink(target=external, identity)
  try upgrade_agent_bundle(bundle, target) catch {
    _ => ()
  } noraise {
    _ => fail("symlink upgrade was accepted")
  }
  assert_eq(@fsx.read_file(external), "outside must remain unchanged")
  try plan_agent_merge(bundle, target) catch {
    _ => ()
  } noraise {
    _ => fail("symlink merge inspection was accepted")
  }
  @fs.rmdir(source, recursive=true)
  @fs.rmdir(target, recursive=true)
}
