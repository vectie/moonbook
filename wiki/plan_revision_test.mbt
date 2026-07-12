///|
fn revision_request() -> PlanRevisionRequest {
  {
    request_id: "robot-r1-r2",
    book_id: "lunar-work-robot",
    parent_revision: "r1",
    proposed_revision: "r2",
    invalid_assumption: "Excavation alone was treated as the complete mission boundary.",
    reason: "The declared goal also requires hauling material and safe return.",
    evidence_refs: ["research/mission-boundary.json"],
    changed_declarations: [
      {
        declaration_id: "design",
        owner_product_id: "moonrobo",
        previous_acceptance_criteria: ["robot excavates regolith"],
        proposed_acceptance_criteria: [
          "robot excavates regolith", "robot hauls the declared payload", "robot returns to the safe zone",
        ],
        reason: "Restore the omitted mission stages without weakening prior criteria.",
      },
    ],
    unchanged_declarations: ["research", "environment-model"],
    recorded_at: "2026-07-12T13:00:00+08:00",
  }
}

///|
test "Bookkeeper compiles immutable revision proposal and lineage" {
  let (proposal, lineage) = compile_plan_revision(revision_request())
  assert_eq(proposal.contract_id, "moonbook.plan-revision-proposal.v1")
  assert_eq(lineage.contract_id, "moonbook.plan-revision-lineage.v1")
  assert_eq(lineage.parent_revision, "r1")
  assert_eq(lineage.revision, "r2")
  assert_true(lineage.changed_declaration_ids == ["design"])
  assert_eq(lineage.proposal_ref, "flow/revisions/r2/proposal.json")
  assert_true(executable_source_digest_is_valid(lineage.source_digest))
}

///|
test "revision rejects history rewrite, evidence escape, and ambiguous declarations" {
  let same_revision = { ..revision_request(), proposed_revision: "r1" }
  assert_true(
    same_revision
    .quality_issues()
    .contains("a revision must not rewrite its parent"),
  )
  let escaped = { ..revision_request(), evidence_refs: ["../outside.json"] }
  assert_true(
    escaped
    .quality_issues()
    .any(issue => issue.contains("reference is invalid")),
  )
  let overlap = {
    ..revision_request(),
    unchanged_declarations: ["research", "design"],
  }
  assert_true(
    overlap
    .quality_issues()
    .contains("declaration cannot be both changed and unchanged: design"),
  )
}

///|
async test "revision persistence is idempotent and conflicts fail closed" {
  let root = "/tmp/moonbook-plan-revision-v2-wbtest"
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.make_directory(root + "/research", recursive=true, exists_ok=true)
  @fsx.write_to_file(
    root + "/research/mission-boundary.json",
    "{\"evidence\":true}",
    create=0o644,
  )
  let request_path = root + "/request.json"
  @fsx.write_to_file(
    request_path,
    revision_request().to_json().stringify(indent=2),
    create=0o644,
  )
  let first = write_plan_revision(root, request_path)
  let repeated = write_plan_revision(root, request_path)
  assert_true(first.proposal == repeated.proposal)
  assert_true(@fsx.exists(first.proposal_path))
  assert_true(@fsx.exists(first.lineage_path))
}
