///|
fn submission_test_ref(id : String) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: id,
    record_version: "1",
    record_digest: "sha256:" + "a".repeat(64),
  }
}

///|
fn submission_test_evidence(
  id : String,
  digit : Char,
) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "1",
    digest: "sha256:" + digit.to_string().repeat(64),
    provenance_ref: "fixture://\{id}",
  }
}

///|
fn submission_fixture() -> ProductOutcomeSubmission {
  let synthesis = submission_test_evidence("synthesis", 'b')
  let decision = submission_test_evidence("decision", 'c')
  {
    contract_version: product_outcome_submission_contract_version(),
    submission: submission_test_ref("moonfind-submission"),
    source_product: "moonfind",
    deliverable_title: "Reviewed synthesis",
    deliverable_summary: "MoonChat preserved the exact named-human decision.",
    outcome_summary: "One evidence-bound research idea was accepted.",
    owner_route: "moonfind://runs/run-1/review",
    evidence_refs: [synthesis, decision],
    decision_evidence_id: decision.reference_id,
    observed_at: 100,
    recorded_at: 101,
    information_gap: {
      present: true,
      severity: 2,
      summary: "One source contradiction needs a direct experiment.",
      evidence_refs: [synthesis.reference_id, decision.reference_id],
    },
    recognition_gap: {
      present: false,
      severity: 0,
      summary: "The reviewer recognized the remaining contradiction.",
      evidence_refs: [synthesis.reference_id, decision.reference_id],
    },
    decisiveness_gap: {
      present: true,
      severity: 3,
      summary: "The accepted experiment is not yet an operating rule.",
      evidence_refs: [synthesis.reference_id, decision.reference_id],
    },
    capability_id: "moonfind.cross-paper-synthesis",
    capability_version: "2",
    capability_change_digest: "sha256:" + "d".repeat(64),
    capability_summary: "Propose the reviewed evidence-routing improvement.",
  }
}

///|
async test "product submission pauses in MoonBook then replays into Three-Gap" {
  let root = @fs.tmpdir(prefix="moonbook-product-submission-")
  let submission = submission_fixture()
  let first = submit_product_outcome(root, submission)
  assert_eq(first.state, "deliverable_review_required")
  assert_true(first.deliverable_review is None)
  assert_true(first.deliverable_disposition is None)
  assert_true(first.closure is None)
  assert_false(first.activation_authorized)

  let snapshot = replay_bookkeeper_store(root)
  let deliverable = find_record(snapshot, first.deliverable).unwrap()
  guard deliverable.payload is { "product_outcome_submission": exact, .. } else {
    fail("expected exact ProductOutcomeSubmission in durable payload")
  }
  assert_eq(exact, submission.to_json())
  let evidence_ids = deliverable.evidence_refs.map(item => item.reference_id)
  let grant = submission_test_ref("submission-reviewer-grant")
  let registry = install_bookkeeper_authority_grant(root, {
    contract_version: bookkeeper_store_contract_version(),
    grant,
    reviewer_id: "research-lead",
    reviewer_kind: @bookkeeper.Human,
    authority_ref: "authority://research-lead",
    evidence_refs: evidence_ids,
    active: true,
    granted_at: 102,
  })
  assert_true(
    registry.grants.any(authority => {
      authority.reviewer_id == "research-lead" &&
      authority.authority_ref == "authority://research-lead" &&
      authority.active
    }),
  )
  let accepted = apply_governed_review(root, {
    contract_version: bookkeeper_store_contract_version(),
    mutation: submission_test_ref("submission-review-mutation"),
    receipt: submission_test_ref("submission-review-receipt"),
    stage: DeliverableAcceptance,
    subject: deliverable.record,
    requested: @bookkeeper.Accept,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant,
      reviewer_id: "research-lead",
      authority_ref: "authority://research-lead",
      authorized: true,
      evidence_refs: evidence_ids,
    },
    evidence_refs: deliverable.evidence_refs,
    summary: "Named human accepted the exact imported deliverable.",
    decided_at: 103,
  })
  assert_true(accepted.accepted)

  let second = submit_product_outcome(root, submission)
  assert_eq(second.state, "assessment_review_required")
  assert_true(second.deliverable_review is Some(_))
  assert_eq(second.deliverable_disposition, Some(@bookkeeper.Accept))
  guard second.closure is Some(closure) else {
    fail("expected outcome closure receipt")
  }
  assert_eq(closure.pending_human_gate, "three_gap_assessment")
  assert_false(closure.activation_authorized)
  assert_false(second.external_side_effects_applied)
}

///|
async test "product submission records terminal deliverable rejection" {
  let root = @fs.tmpdir(prefix="moonbook-product-submission-reject-")
  let submission = submission_fixture()
  let pending = submit_product_outcome(root, submission)
  let deliverable = find_record(
    replay_bookkeeper_store(root),
    pending.deliverable,
  ).unwrap()
  ignore(
    closure_test_decide(
      root,
      deliverable,
      "deliverable-reject",
      @bookkeeper.Reject,
    ),
  )
  let rejected = submit_product_outcome(root, submission)
  assert_eq(rejected.state, "deliverable_rejected")
  assert_eq(rejected.deliverable_disposition, Some(@bookkeeper.Reject))
  assert_true(rejected.closure is None)
  assert_false(rejected.activation_authorized)
  assert_eq(submit_product_outcome(root, submission), rejected)
}
