///|
fn closure_test_ref(
  id : String,
  digest? : String = "",
) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: id,
    record_version: "1",
    record_digest: if digest.is_blank() {
      "sha256:" + "a".repeat(64)
    } else {
      digest
    },
  }
}

///|
fn closure_test_evidence(id : String) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "1",
    digest: "sha256:" + "b".repeat(64),
    provenance_ref: "fixture://\{id}",
  }
}

///|
async fn closure_test_decide(
  root : String,
  record : DurableBookkeeperRecord,
  suffix : String,
  requested : @bookkeeper.BookkeeperDisposition,
) -> GovernedReviewReceipt {
  let reviewer_id = "closure-reviewer-\{suffix}"
  let evidence_ids = record.evidence_refs.map(reference => {
    reference.reference_id
  })
  let grant = closure_test_ref("grant-\{reviewer_id}")
  ignore(
    install_bookkeeper_authority_grant(root, {
      contract_version: bookkeeper_store_contract_version(),
      grant,
      reviewer_id,
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "authority://\{reviewer_id}",
      evidence_refs: evidence_ids,
      active: true,
      granted_at: record.recorded_at,
    }),
  )
  let result = apply_governed_review(root, {
    contract_version: bookkeeper_store_contract_version(),
    mutation: closure_test_ref("mutation-\{suffix}"),
    receipt: closure_test_ref("receipt-\{suffix}"),
    stage: record.stage,
    subject: record.record,
    requested,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant,
      reviewer_id,
      authority_ref: "authority://\{reviewer_id}",
      authorized: true,
      evidence_refs: evidence_ids,
    },
    evidence_refs: record.evidence_refs,
    summary: "Named-human decision for \{record.record.record_id}",
    decided_at: record.recorded_at + 1,
  })
  if !result.accepted {
    fail("fixture review \{suffix} rejected: \{to_repr(result.issues)}")
  }
  result.review.unwrap()
}

///|
async fn closure_test_accept(
  root : String,
  record : DurableBookkeeperRecord,
  suffix : String,
) -> GovernedReviewReceipt {
  closure_test_decide(root, record, suffix, @bookkeeper.Accept)
}

///|
async fn closure_test_source(
  root : String,
) -> (
  DurableBookkeeperRecord,
  BookkeeperTransportEnvelope,
  GovernedReviewReceipt,
  @bookkeeper.VersionedEvidenceReference,
  @bookkeeper.VersionedEvidenceReference,
) {
  let deliverable_evidence = closure_test_evidence("deliverable-evidence")
  let result_evidence = closure_test_evidence("result-evidence")
  let payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "fixture": "product-deliverable",
  }
  let deliverable : DurableBookkeeperRecord = {
    contract_version: bookkeeper_store_contract_version(),
    record: closure_test_ref(
      "deliverable-closure",
      digest=bookkeeper_payload_digest(payload),
    ),
    stage: DeliverableAcceptance,
    subject: None,
    links: [],
    title: "Fixture deliverable",
    summary: "Exact accepted fixture deliverable",
    owner_route: "owner://fixture",
    status: "awaiting human review",
    evidence_refs: [deliverable_evidence],
    issue_refs: [],
    requires_human_review: true,
    next_action: "review",
    source_product: "moonbook",
    recorded_at: 10,
    payload,
    side_effects_applied: false,
  }
  assert_true(persist_bookkeeper_record(root, deliverable).accepted)
  let deliverable_review = closure_test_accept(root, deliverable, "deliverable")
  let result : BookkeeperTransportEnvelope = {
    contract_version: bookkeeper_transport_contract_version(),
    envelope: closure_test_ref("mooncast-result"),
    direction: Ingress,
    source_product: "mooncast",
    destination_product: "moonbook",
    message_kind: "product.result",
    subject: deliverable.record,
    links: [],
    evidence_refs: [result_evidence],
    authority_ref: "authority://mooncast-result",
    recorded_at: 20,
    payload: {
      "contract_version": "moonsuite.product-result.v1",
      "accepted": true,
    },
    external_activation_allowed: false,
    side_effects_applied: false,
  }
  assert_true(persist_transport_envelope(root, result).accepted)
  (
    deliverable, result, deliverable_review, deliverable_evidence, result_evidence,
  )
}

///|
fn closure_test_request(
  deliverable : DurableBookkeeperRecord,
  result : BookkeeperTransportEnvelope,
  review : GovernedReviewReceipt,
  deliverable_evidence : @bookkeeper.VersionedEvidenceReference,
  result_evidence : @bookkeeper.VersionedEvidenceReference,
) -> ProductOutcomeClosureRequest {
  {
    contract_version: product_outcome_closure_contract_version(),
    request: closure_test_ref("closure-request"),
    source_product: "mooncast",
    deliverable: deliverable.record,
    result: result.envelope,
    deliverable_review: review.receipt,
    observed_at: 30,
    recorded_at: 31,
    outcome_summary: "The delivered episode missed its retention target.",
    owner_route: "mooncast://production-capability",
    evidence_refs: [result_evidence, deliverable_evidence],
    information_gap: {
      present: true,
      severity: 2,
      summary: "The audience drop-off point was unknown before delivery.",
      evidence_refs: [result_evidence.reference_id],
    },
    recognition_gap: {
      present: false,
      severity: 0,
      summary: "The operator recognized the measured drop-off.",
      evidence_refs: [result_evidence.reference_id],
    },
    decisiveness_gap: {
      present: true,
      severity: 3,
      summary: "No accepted edit rule addressed the drop-off.",
      evidence_refs: [
        deliverable_evidence.reference_id,
        result_evidence.reference_id,
      ],
    },
    capability_id: "mooncast-retention-edit-rule",
    capability_version: "2",
    capability_change_digest: "sha256:" + "a".repeat(64),
    capability_summary: "Propose a reviewed retention-aware edit rule.",
  }
}

///|
async test "product outcome closure advances only through named-human gates" {
  let root = "/tmp/moonbook-outcome-closure-\{@async.now().to_int()}"
  let (
    deliverable,
    result,
    deliverable_review,
    deliverable_evidence,
    result_evidence,
  ) = closure_test_source(root)
  let request = closure_test_request(
    deliverable, result, deliverable_review, deliverable_evidence, result_evidence,
  )
  let first = close_product_outcome(root, request)
  assert_eq(first.state, "assessment_review_required")
  assert_true(first.capability_proposal is None)
  assert_true(first.moonflow_handoff is None)
  assert_true(first.assessment_disposition is None)
  assert_false(first.activation_authorized)

  let after_first = replay_bookkeeper_store(root)
  let assessment = find_record(after_first, first.three_gap_assessment).unwrap()
  assert_true(assessment.stage == ThreeGapFinding)
  guard assessment.payload is { "assessment": Object(gaps), .. } else {
    fail("expected deterministic Three-Gap assessment payload")
  }
  assert_true(gaps["information_gap"] is { "present": True, .. })
  assert_true(gaps["recognition_gap"] is { "present": False, .. })
  ignore(closure_test_accept(root, assessment, "assessment"))

  let second = close_product_outcome(root, request)
  assert_eq(second.state, "proposal_review_required")
  assert_true(second.assessment_review is Some(_))
  assert_eq(second.assessment_disposition, Some(@bookkeeper.Accept))
  assert_true(second.capability_proposal is Some(_))
  assert_true(second.proposal_review is None)
  assert_false(second.activation_authorized)

  let after_second = replay_bookkeeper_store(root)
  let proposal = find_record(after_second, second.capability_proposal.unwrap()).unwrap()
  assert_true(proposal.stage == CapabilityProposal)
  ignore(closure_test_accept(root, proposal, "proposal"))

  let third = close_product_outcome(root, request)
  assert_eq(third.state, "reviewed_proposal_handed_off")
  assert_true(third.proposal_review is Some(_))
  assert_eq(third.proposal_disposition, Some(@bookkeeper.Accept))
  assert_true(third.moonflow_handoff is Some(_))
  assert_false(third.activation_authorized)
  assert_false(third.external_side_effects_applied)

  let replay = close_product_outcome(root, request)
  assert_true(replay == third)
  let final_snapshot = replay_bookkeeper_store(root)
  assert_true(final_snapshot.records.length() == 4)
  assert_true(final_snapshot.reviews.length() == 3)
  assert_true(final_snapshot.envelopes.length() == 2)
  let handoff = closure_find_envelope(
    final_snapshot,
    third.moonflow_handoff.unwrap(),
  ).unwrap()
  assert_eq(handoff.message_kind, "bookkeeper.capability-proposal.reviewed")
  assert_false(handoff.external_activation_allowed)
  assert_false(handoff.side_effects_applied)
}

///|
async test "product outcome closure records terminal named-human rejection" {
  let assessment_root = @fs.tmpdir(prefix="moonbook-outcome-assessment-reject-")
  let (deliverable, result, review, first_evidence, second_evidence) = closure_test_source(
    assessment_root,
  )
  let request = closure_test_request(
    deliverable, result, review, first_evidence, second_evidence,
  )
  let pending = close_product_outcome(assessment_root, request)
  let assessment = find_record(
    replay_bookkeeper_store(assessment_root),
    pending.three_gap_assessment,
  ).unwrap()
  ignore(
    closure_test_decide(
      assessment_root,
      assessment,
      "assessment-reject",
      @bookkeeper.Reject,
    ),
  )
  let rejected = close_product_outcome(assessment_root, request)
  assert_eq(rejected.state, "assessment_rejected")
  assert_eq(rejected.assessment_disposition, Some(@bookkeeper.Reject))
  assert_true(rejected.capability_proposal is None)
  assert_true(rejected.moonflow_handoff is None)
  assert_eq(close_product_outcome(assessment_root, request), rejected)

  let proposal_root = @fs.tmpdir(prefix="moonbook-outcome-proposal-reject-")
  let (deliverable, result, review, first_evidence, second_evidence) = closure_test_source(
    proposal_root,
  )
  let request = closure_test_request(
    deliverable, result, review, first_evidence, second_evidence,
  )
  let pending = close_product_outcome(proposal_root, request)
  let assessment = find_record(
    replay_bookkeeper_store(proposal_root),
    pending.three_gap_assessment,
  ).unwrap()
  ignore(closure_test_accept(proposal_root, assessment, "assessment-accept"))
  let proposed = close_product_outcome(proposal_root, request)
  let proposal = find_record(
    replay_bookkeeper_store(proposal_root),
    proposed.capability_proposal.unwrap(),
  ).unwrap()
  ignore(
    closure_test_decide(
      proposal_root,
      proposal,
      "proposal-reject",
      @bookkeeper.Reject,
    ),
  )
  let rejected = close_product_outcome(proposal_root, request)
  assert_eq(rejected.state, "proposal_rejected")
  assert_eq(rejected.proposal_disposition, Some(@bookkeeper.Reject))
  assert_true(rejected.moonflow_handoff is None)
  assert_eq(close_product_outcome(proposal_root, request), rejected)
}

///|
async test "product outcome closure rejects partial or substituted evidence" {
  let root = "/tmp/moonbook-outcome-closure-reject-\{@async.now().to_int()}"
  let (
    deliverable,
    result,
    deliverable_review,
    deliverable_evidence,
    result_evidence,
  ) = closure_test_source(root)
  let request = closure_test_request(
    deliverable, result, deliverable_review, deliverable_evidence, result_evidence,
  )
  try
    close_product_outcome(root, { ..request, evidence_refs: [result_evidence] })
  catch {
    error =>
      assert_true(
        "\{error}".contains(
          "exactly equal the canonical deliverable/result evidence set",
        ),
      )
  } noraise {
    _ => fail("partial closure evidence must fail closed")
  }
  try
    close_product_outcome(root, {
      ..request,
      deliverable_review: closure_test_ref("wrong-review"),
    })
  catch {
    error => assert_true("\{error}".contains("named-human Accept receipt"))
  } noraise {
    _ => fail("substituted review receipt must fail closed")
  }
}
