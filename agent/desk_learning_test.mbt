///|
fn desk_learning_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn desk_learning_text(value : Json, key : String) -> String {
  match desk_learning_field(value, key) {
    String(value) => value
    _ => ""
  }
}

///|
fn desk_learning_path(record : Json) -> String {
  let tree = if desk_learning_text(record, "kind") == "procedure" {
    "procedures"
  } else {
    "beliefs"
  }
  let key = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(desk_learning_text(record, "id"))),
  )
  "memory/" + tree + "/desk-" + key + ".md"
}

///|
async test "accepted Desk Markdown lesson kinds survive pack and import without promotion" {
  let root = agent_test_book("desk-markdown")
  let target = root + "-imported"
  let paths : Array[String] = []
  for kind in ["knowledge", "preference", "procedure", "capability"] {
    let tree = if kind == "procedure" { "procedures" } else { "beliefs" }
    let path = "memory/" + tree + "/desk-lesson-" + kind + ".md"
    @fsx.make_directory(
      @pathx.join(root, "memory/" + tree),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(
      @pathx.join(root, path),
      "---\nstatus: accepted\nlesson_kind: \"" +
      kind +
      "\"\nproposal_id: \"lesson-" +
      kind +
      "\"\nworkspace_id: \"origin-workspace\"\ndecided_at: \"2026-10-02T12:01:00Z\"\n---\n\n# Accepted Desk lesson\n\nFull human-reviewed " +
      kind +
      " lesson.\n",
    )
    paths.push(path)
  }
  for status in ["proposed", "rejected"] {
    @fsx.write_to_file(
      @pathx.join(root, "memory/procedures/" + status + ".md"),
      "---\nstatus: " +
      status +
      "\nlesson_kind: procedure\n---\n\nExample status: accepted must not admit this record.\n",
    )
  }
  let bundle_path = @agent.pack_agent(root, version="3.2.1")
  let bundle = @agent.read_agent_bundle(bundle_path)
  assert_true(@agent.verify_agent_bundle(bundle_path).ok)
  @agent.import_agent_bundle(bundle_path, target) |> ignore
  for path in paths {
    assert_true(
      bundle.files.any(file => {
        file.path == path && file.review_status == "accepted"
      }),
    )
    assert_eq(
      @fsx.read_file(@pathx.join(target, path)),
      @fsx.read_file(@pathx.join(root, path)),
    )
  }
  assert_false(
    bundle.files.any(file => {
      file.path == "memory/procedures/proposed.md" ||
      file.path == "memory/procedures/rejected.md"
    }),
  )
  assert_false(bundle.files.any(file => file.path.has_prefix("capabilities/")))
  @fs.rmdir(root, recursive=true)
  @fs.rmdir(target, recursive=true)
}

///|
/// Set MOONBOOK_DESK_LEARNING_FIXTURE to the actual Desk producer fixture.
/// Missing/malformed producer output is a failure when that explicit check is run.
async test "actual Desk acceptance exports full portable content and original provenance" {
  guard @env.get_env_var("MOONBOOK_DESK_LEARNING_FIXTURE") is Some(fixture_dir) else {
    return
  }
  let fixture = @json.parse(
    @fsx.read_file(@pathx.join(fixture_dir, "fixture.json")),
  )
  let root = desk_learning_text(fixture, "book_root")
  guard root != "" else { fail("Desk producer root missing") }
  guard desk_learning_field(fixture, "accepted") is Array(accepted) else {
    fail("Desk acceptance records missing")
  }
  assert_eq(accepted.length(), 4)
  // Finish a minimal Book fixture with standard missing files only. Existing
  // accepted lesson bytes, identity metadata and unrelated memory must survive.
  @wiki.init_workspace(root) |> ignore
  guard desk_learning_field(fixture, "protected") is Object(preserved) else {
    fail("Protected source baselines missing")
  }
  for path, content in preserved {
    assert_eq(@fsx.read_file(@pathx.join(root, path)).to_json(), content)
  }
  let bundle_path = @agent.pack_agent(
    root,
    version="3.2.1",
    output=@pathx.join(fixture_dir, "accepted-lessons.moonbook-agent"),
  )
  let bundle = @agent.read_agent_bundle(bundle_path)
  assert_true(@agent.verify_agent_bundle(bundle_path).ok)
  let target = @pathx.join(fixture_dir, "imported-" + @async.now().to_string())
  @agent.import_agent_bundle(bundle_path, target) |> ignore
  let proofs : Array[Json] = []
  for record in accepted {
    let receipt = desk_learning_field(record, "book_learning")
    let path = desk_learning_path(record)
    guard bundle.files.iter().find_first(file => file.path == path)
      is Some(file) else {
      fail("Actual Desk lesson missing from exported bundle: " + path)
    }
    assert_eq(desk_learning_text(receipt, "status"), "persisted")
    assert_eq(desk_learning_text(receipt, "path"), path)
    assert_eq(file.review_status, "accepted")
    assert_eq(file.digest, desk_learning_text(receipt, "revision"))
    let original = @fsx.read_file(@pathx.join(root, path))
    let imported = @fsx.read_file(@pathx.join(target, path))
    assert_eq(imported, original)
    assert_true(
      imported.contains(
        "lesson_kind: " +
        desk_learning_text(record, "kind").to_json().stringify(),
      ),
    )
    assert_true(imported.contains(desk_learning_text(record, "detail")))
    assert_true(imported.contains(desk_learning_text(record, "source")))
    assert_true(imported.contains(desk_learning_text(record, "workspace_id")))
    assert_true(imported.contains(desk_learning_text(record, "decided_at")))
    assert_true(imported.contains(desk_learning_text(record, "created_at")))
    assert_true(imported.contains(desk_learning_text(record, "id")))
    assert_true(imported.contains("moondesk.learning-proposal.v1"))
    let marker = "## Acceptance provenance\n\n```json\n"
    let start = imported.rev_find(marker).unwrap() + marker.length()
    let provenance = @json.parse(
      imported[start:imported.length() - "\n```\n".length()].to_owned(),
    )
    guard record is Object(fields) else { fail("Invalid producer record") }
    let expected = fields.copy()
    expected.remove("book_learning") |> ignore
    assert_eq(provenance, Json::object(expected))
    proofs.push({
      "path": path,
      "revision": file.digest,
      "kind": desk_learning_text(record, "kind"),
      "bytes_identical": true,
      "origin_proposal_id": desk_learning_text(record, "id"),
    })
  }
  for key in ["proposed", "rejected"] {
    let record = desk_learning_field(fixture, key)
    let id = desk_learning_text(record, "id")
    assert_true(id != "")
    let path = desk_learning_path(record)
    assert_false(bundle.files.any(file => file.path == path))
    assert_false(@fsx.exists(@pathx.join(target, path)))
  }
  assert_eq(
    bundle.files
    .filter(file => {
      file.path.has_prefix("memory/beliefs/desk-") ||
      file.path.has_prefix("memory/procedures/desk-")
    })
    .length(),
    4,
  )
  for path in ["keeper/USER.md", "memory/beliefs/unrelated.md"] {
    assert_eq(
      @fsx.read_file(@pathx.join(target, path)),
      @fsx.read_file(@pathx.join(root, path)),
    )
  }
  for path, content in preserved {
    assert_eq(@fsx.read_file(@pathx.join(root, path)).to_json(), content)
  }
  let installation : @agent.AgentInstallationState = @json.from_json(
    @json.parse(
      @fsx.read_file(@pathx.join(target, "state/agent-installation.json")),
    ),
  )
  assert_eq(installation.agent_id, bundle.agent_id)
  assert_eq(installation.version, bundle.version)
  assert_eq(installation.bundle_digest, bundle.bundle_digest)
  assert_false(
    bundle.files.any(file => {
      file.path.has_prefix(".moonbook/desk-learning-tmp/") ||
      file.path.contains("proposals.v1.json")
    }),
  )
  @fsx.write_to_file(
    @pathx.join(fixture_dir, "roundtrip-proof.json"),
    (
      {
        "agent_id": bundle.agent_id,
        "version": bundle.version,
        "book_revision": bundle.book_revision,
        "bundle_digest": bundle.bundle_digest,
        "bundle_path": bundle_path,
        "import_root": target,
        "lessons": Json::array(proofs),
        "unaccepted_excluded": true,
        "unrelated_memory_unchanged": true,
        "installation_tuple_preserved": true,
        "native_town_hydration_tested": false,
      } : Json).stringify(indent=2),
  )
}
