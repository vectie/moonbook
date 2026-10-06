///|
async fn agent_review_status_case_roundtrip(
  label : String,
  cases : Array[(String, String, Bool)],
) -> Unit {
  let root = agent_test_book("review-status-" + label)
  let target = root + "-imported"
  for (path, content, _) in cases {
    @fsx.make_directory(
      @pathx.dirname(@pathx.join(root, path)),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(@pathx.join(root, path), content)
  }
  let bundle_path = @agent.pack_agent(root)
  let bundle = @agent.read_agent_bundle(bundle_path)
  @agent.import_agent_bundle(bundle_path, target) |> ignore
  for (path, content, expected) in cases {
    let exported = bundle.files.any(file => {
      file.path == path && file.review_status == "accepted"
    })
    assert_eq(
      exported,
      expected,
      msg="unexpected review classification: " + path,
    )
    let destination = @pathx.join(target, path)
    assert_eq(
      @fsx.exists(destination),
      expected,
      msg="unexpected imported file: " + path,
    )
    if expected {
      assert_eq(@fsx.read_file(destination), content)
    } else {
      assert_true(
        bundle.exclusions.any(item => {
          item.path == path &&
          item.reason == "content is not accepted for agent activation"
        }),
      )
    }
  }
  @fs.rmdir(root, recursive=true)
  @fs.rmdir(target, recursive=true)
}

///|
async test "structured accepted status exports compact and formatted procedure JSON" {
  agent_review_status_case_roundtrip("canonical", [
    (
      "memory/procedures/compact.json", "{\"status\":\"accepted\",\"steps\":[\"Run focused tests\"]}",
      true,
    ),
    (
      "memory/procedures/formatted.json", "{\n  \"status\": \"accepted\",\n  \"steps\": [\"Run focused tests\"]\n}\n",
      true,
    ),
    (
      "memory/beliefs/accepted.json", "{\"status\":\"accepted\",\"belief\":\"Supported observation\"}",
      true,
    ),
  ])
}

///|
async test "candidate and rejected status cannot be promoted by descriptive markers" {
  agent_review_status_case_roundtrip("not-approved", [
    (
      "memory/procedures/candidate-note.json", "{\"status\":\"candidate\",\"note\":\"Do not use status: accepted until review\"}",
      false,
    ),
    (
      "memory/procedures/candidate-step.json", "{\"status\":\"candidate\",\"steps\":[\"Do not use status: promoted before review\"]}",
      false,
    ),
    (
      "memory/procedures/rejected.json", "{\"status\":\"rejected\",\"note\":\"Old status: accepted is no longer valid\"}",
      false,
    ),
    (
      "memory/procedures/candidate-legacy-flag.json", "{\"status\":\"candidate\",\"accepted\":true}",
      false,
    ),
    (
      "memory/procedures/rejected-legacy-flag.json", "{\"status\":\"rejected\",\"accepted\": true}",
      false,
    ),
    (
      "memory/procedures/unknown-status.json", "{\"status\":\"needs-review\",\"accepted\": true}",
      false,
    ),
    (
      "memory/procedures/nested.json", "{\"note\":{\"status\": \"accepted\"}}", false,
    ),
    (
      "memory/procedures/index.json", "{\"procedures\":[{\"status\": \"accepted\"},{\"status\":\"candidate\"}]}",
      false,
    ),
    (
      "memory/procedures/invalid-status.json", "{\"status\":null,\"accepted\": true}",
      false,
    ),
    (
      "memory/procedures/description-only.json", "{\"description\":\"Example status: accepted\"}",
      false,
    ),
    (
      "memory/beliefs/candidate.json", "{\"status\":\"candidate\",\"note\":\"status: accepted\"}",
      false,
    ),
  ])
}

///|
async test "legacy promoted and accepted boolean retain structured meaning" {
  agent_review_status_case_roundtrip("legacy", [
    (
      "memory/procedures/promoted-compact.json", "{\"status\":\"promoted\"}", true,
    ),
    (
      "memory/procedures/promoted-formatted.json", "{\"status\": \"promoted\"}\n",
      true,
    ),
    ("memory/procedures/accepted-flag.json", "{\"accepted\":true}", true),
    (
      "memory/procedures/accepted-flag-formatted.json", "{\"accepted\": true}\n",
      true,
    ),
    (
      "memory/procedures/false-flag.json", "{\"accepted\":false,\"note\":\"status: promoted\"}",
      false,
    ),
    ("memory/procedures/string-flag.json", "{\"accepted\":\"true\"}", false),
  ])
}

///|
async test "legacy text metadata is separate from documentation prose" {
  agent_review_status_case_roundtrip("text", [
    ("memory/procedures/legacy.md", "status: promoted\n", true),
    (
      "memory/procedures/frontmatter.md", "---\ntitle: Focused test\nstatus: promoted\n---\n# Procedure\nRun focused tests.\n",
      true,
    ),
    (
      "memory/procedures/frontmatter-accepted.md", "---\nstatus: accepted\n---\n# Procedure\nRun focused tests.\n",
      true,
    ),
    (
      "memory/procedures/candidate.md", "---\nstatus: candidate\nnote: Use status: accepted only after review\n---\nstatus: promoted\n",
      false,
    ),
    (
      "memory/procedures/rejected.md", "---\nstatus: rejected\naccepted: true\n---\nstatus: promoted\n",
      false,
    ),
    (
      "memory/procedures/documentation.md", "# Documentation\n\nExample: status: promoted\n",
      false,
    ),
    (
      "memory/procedures/code-example.md", "# Metadata examples\n\n```yaml\nstatus: promoted\n```\n",
      false,
    ),
    (
      "memory/procedures/json-example.md", "# Metadata examples\n\n```json\n{\"status\": \"promoted\"}\n```\n",
      false,
    ),
    (
      "memory/procedures/nested-frontmatter.md", "---\nnote: |\n  status: promoted\n---\n",
      false,
    ),
    ("memory/procedures/unterminated.md", "---\nstatus: promoted\n", false),
    (
      "memory/procedures/conflicting.md", "---\nstatus: promoted\nstatus: candidate\n---\n",
      false,
    ),
  ])
}
