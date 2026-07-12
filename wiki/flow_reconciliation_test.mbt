///|
fn flow_projection(
  status : String,
  output_digest? : String = "sha256:33183a83f83bc9ee570fbc872ec14b8f21cdcf9068d2a50d4f327f3ea7499423",
  blocker? : String = "",
  error_kind? : String = "",
) -> Json {
  let review_artifact = "books/generic-book/reviews/work-research-r1.json"
  let artifacts = if status == "accepted" {
    ["artifact://moonwiki/research-r1", review_artifact]
  } else {
    ["artifact://moonwiki/research-r1"]
  }
  {
    "protocol": "moonflow.run-projection.v3",
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
        "operation": "build-evidence-bundle",
        "input_contracts": ["moonsuite.goal.v1"],
        "output_contracts": ["moonwiki.evidence-bundle.v1"],
        "required_claim": "research-evidence",
        "input_artifacts": ["books/generic-book/flow/goals/r1.txt"],
        "timeout_ms": 60000,
        "depends_on": [],
        "input_digest": "sha256:input",
        "output_digest": output_digest,
        "artifacts": artifacts,
        "blocker": blocker,
        "error_kind": error_kind,
        "acceptance_review_id": if status == "accepted" {
          "review-work-research-r1"
        } else {
          ""
        },
        "acceptance_review_artifact": if status == "accepted" {
          review_artifact
        } else {
          ""
        },
        "acceptance_reviewer_id": if status == "accepted" {
          "book-owner-review"
        } else {
          ""
        },
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
test "accepted work becomes a provenance-bound candidate procedure" {
  let observation = @wiki.decode_flow_outcome_observation(
    flow_projection("accepted"),
    "work-research",
    "2026-07-11T10:02:00Z",
  )
  let reflection = @wiki.reflect_on_flow_outcome(observation)
  assert_true(reflection.gaps.is_empty())
  assert_eq(reflection.learned_procedures.length(), 1)
  let procedure = reflection.learned_procedures[0]
  assert_eq(procedure.status, "candidate")
  assert_true(procedure.title.contains("build-evidence-bundle"))
  assert_true(
    procedure.verification_criteria.contains("reviewed evidence is attached"),
  )
  assert_true(
    procedure.evidence_refs.contains(
      "books/generic-book/reviews/work-research-r1.json",
    ),
  )
  assert_eq(reflection.confidence, 0.98)
}

///|
test "accepted projection without typed review evidence fails closed" {
  let projection = flow_projection("accepted")
  guard projection is Object(fields) && fields["items"] is Array([Object(item)]) else {
    fail("expected flow projection fixture")
  }
  item["acceptance_review_id"] = ""
  item["acceptance_review_artifact"] = ""
  item["acceptance_reviewer_id"] = ""
  let observation = @wiki.decode_flow_outcome_observation(
    projection, "work-research", "2026-07-11T10:02:00Z",
  )
  let issues = observation.quality_issues()
  assert_true(issues.any(issue => issue.contains("acceptance_review_id")))
  assert_true(issues.any(issue => issue.contains("review artifact")))
  assert_true(issues.any(issue => issue.contains("acceptance_reviewer_id")))
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

///|
async test "acceptance rejection creates one criteria-preserving child graph" {
  let root = "/tmp/moonbook-flow-auto-recovery-wbtest"
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let projection_path = root + "/projection.json"
  @fsx.write_to_file(
    projection_path,
    flow_projection(
      "blocked",
      blocker="criterion evidence is incomplete",
      error_kind="acceptance-rejected",
    ).stringify(indent=2),
    create=0o644,
  )
  let record = @wiki.reconcile_flow_run_file(
    root, projection_path, "2026-07-12T06:30:00Z",
  )
  assert_true(!record.recovery_graph_ref.is_empty())
  let graph = @json.parse(@fsx.read_file(record.recovery_graph_path))
  let text = graph.stringify()
  assert_true(text.contains("r1-auto-recovery-5"))
  assert_true(text.contains("reviewed evidence is attached"))
  assert_true(text.contains("memory/reflections"))
  let proposal = @fsx.read_file(
    root + "/flow/revisions/r1-auto-recovery-5/automatic-recovery.json",
  )
  assert_true(proposal.contains("\"criteria_preserved\": true"))
}

///|
async test "a product process crash creates one bounded recovery child" {
  let root = "/tmp/moonbook-flow-product-restart-wbtest"
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let projection_path = root + "/projection.json"
  @fsx.write_to_file(
    projection_path,
    flow_projection(
      "blocked",
      output_digest="",
      blocker="adapter process failed or omitted its result receipt",
      error_kind="supervisor-blocked",
    ).stringify(indent=2),
    create=0o644,
  )
  let record = @wiki.reconcile_flow_run_file(
    root, projection_path, "2026-07-12T06:31:00Z",
  )
  assert_true(!record.recovery_graph_ref.is_empty())
}
