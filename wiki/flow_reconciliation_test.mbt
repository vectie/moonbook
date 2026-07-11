///|
fn flow_projection(
  status : String,
  output_digest? : String = "sha256:33183a83f83bc9ee570fbc872ec14b8f21cdcf9068d2a50d4f327f3ea7499423",
  blocker? : String = "",
  error_kind? : String = "",
) -> Json {
  {
    "protocol": "moonflow.run-projection.v2",
    "run_id": "flow-generic-r1",
    "book_id": "generic-book",
    "declaration_revision": "r1",
    "source_digest": "sha256:7c83693394b7d8dfd98d8a3c7217cbddfa44e4b7ba5ef88c513d6da403e32f9c",
    "last_sequence": 5,
    "outcome": status,
    "items": [
      {
        "work_item_id": "work-research",
        "declaration_id": "research",
        "product_id": "moonwiki",
        "requested_authority": "observe",
        "acceptance_criteria": ["reviewed evidence is attached"],
        "status": status,
        "active_attempt_id": "attempt-research-1",
        "request_id": "request-research-1",
        "result_id": "result-research-1",
        "input_digest": "sha256:input",
        "output_digest": output_digest,
        "artifacts": ["artifact://moonwiki/research-r1"],
        "blocker": blocker,
        "error_kind": error_kind,
      },
    ],
  }
}

///|
test "adapter success becomes a cognition gap until acceptance review" {
  let observation = @wiki.decode_flow_outcome_observation(
    flow_projection("review"),
    "work-research",
    "2026-07-11T10:02:00Z",
  )
  let reflection = @wiki.reflect_on_flow_outcome(observation)
  assert_true(reflection.gaps.any(gap => gap.kind == "cognition-gap"))
  assert_true(reflection.proposed_actions.is_empty())
  assert_true(
    reflection.uncertainty.contains(
      "acceptance remains pending explicit review",
    ),
  )
}

///|
test "failed work produces bounded recovery without weakening criteria" {
  let observation = @wiki.decode_flow_outcome_observation(
    flow_projection(
      "failed",
      output_digest="",
      blocker="source timeout",
      error_kind="source-timeout",
    ),
    "work-research",
    "2026-07-11T10:02:00Z",
  )
  let reflection = @wiki.reflect_on_flow_outcome(observation)
  assert_true(reflection.gaps.any(gap => gap.kind == "execution-gap"))
  assert_eq(reflection.proposed_actions.length(), 1)
  assert_true(
    reflection.proposed_actions[0].acceptance_criteria.contains(
      "reviewed evidence is attached",
    ),
  )
}

///|
test "accepted work becomes evidence without inventing a learned procedure" {
  let observation = @wiki.decode_flow_outcome_observation(
    flow_projection("accepted"),
    "work-research",
    "2026-07-11T10:02:00Z",
  )
  let reflection = @wiki.reflect_on_flow_outcome(observation)
  assert_true(reflection.gaps.is_empty())
  assert_true(reflection.learned_procedures.is_empty())
  assert_eq(reflection.confidence, 0.98)
}

///|
async test "failed flow projection persists a compilable recovery proposal" {
  let root = "/tmp/moonbook-flow-reconciliation-wbtest"
  @fsx.make_directory(root, recursive=true)
  let projection_path = root + "/projection.json"
  @fsx.write_to_file(
    projection_path,
    flow_projection(
      "failed",
      output_digest="",
      blocker="source timeout",
      error_kind="source-timeout",
    ).stringify(indent=2),
  )
  let record = @wiki.reconcile_flow_projection_file(
    root, projection_path, "work-research", "2026-07-11T10:02:00Z",
  )
  let document = @wiki.decode_executable_document(
    @json.parse(@fsx.read_file(record.proposals_path)),
  )
  assert_true(document.quality_issues().is_empty())
  let graph = @wiki.compile_executable_document(document)
  assert_true(graph.stringify().contains("work-recover-research"))
}
