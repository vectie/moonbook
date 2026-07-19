///|
fn bridge_test_evidence(id : String) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "v1",
    digest: "sha256:" + id,
    provenance_ref: "fixture://" + id,
  }
}

///|
fn bridge_test_payload(contract_version : String, id : String) -> Json {
  { "contract_version": contract_version, "fixture": id }
}

///|
fn bridge_test_record(
  stage : BookkeeperStage,
  id : String,
  payload : Json,
  links : Array[@bookkeeper.VersionedRecordReference],
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference],
) -> DurableBookkeeperRecord {
  {
    contract_version: bookkeeper_store_contract_version(),
    record: {
      record_id: id,
      record_version: "v1",
      record_digest: bookkeeper_payload_digest(payload),
    },
    stage,
    subject: None,
    links,
    title: "Bridge fixture " + id,
    summary: "Bridge fixture summary " + id,
    owner_route: "owner://bridge",
    status: "awaiting human review",
    evidence_refs,
    issue_refs: [],
    requires_human_review: stage.is_reviewable(),
    next_action: "continue governed bridge",
    source_product: "fixture",
    recorded_at: 100,
    payload,
    side_effects_applied: false,
  }
}

///|
async fn bridge_test_accept(
  root : String,
  record : DurableBookkeeperRecord,
  reviewer : String,
  decided_at : Int,
) -> GovernedReviewReceipt {
  let evidence_ids = record.evidence_refs.map(reference => {
    reference.reference_id
  })
  let grant_ref : @bookkeeper.VersionedRecordReference = {
    record_id: "grant:" + reviewer,
    record_version: "v1",
    record_digest: "sha256:grant-" + reviewer,
  }
  ignore(
    install_bookkeeper_authority_grant(root, {
      contract_version: bookkeeper_store_contract_version(),
      grant: grant_ref,
      reviewer_id: reviewer,
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "authority://" + reviewer,
      evidence_refs: evidence_ids,
      active: true,
      granted_at: decided_at - 1,
    }),
  )
  let result = apply_governed_review(root, {
    contract_version: bookkeeper_store_contract_version(),
    mutation: {
      record_id: "mutation:" + reviewer + ":" + record.record.record_id,
      record_version: "v1",
      record_digest: "sha256:mutation-" + reviewer + record.record.record_id,
    },
    receipt: {
      record_id: "receipt:" + reviewer + ":" + record.record.record_id,
      record_version: "v1",
      record_digest: "sha256:receipt-" + reviewer + record.record.record_id,
    },
    stage: record.stage,
    subject: record.record,
    requested: @bookkeeper.Accept,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant: grant_ref,
      reviewer_id: reviewer,
      authority_ref: "authority://" + reviewer,
      authorized: true,
      evidence_refs: evidence_ids,
    },
    evidence_refs: record.evidence_refs,
    summary: "Named-human acceptance for " + record.record.record_id,
    decided_at,
  })
  assert_true(result.accepted)
  result.review.unwrap()
}

///|
async test "governed bridge projects, separately reviews, and emits draft-only work order" {
  let root = "/tmp/moonbook-work-order-bridge-\{@async.now().to_int()}"
  let deliverable = bridge_test_record(
    DeliverableAcceptance,
    "deliverable",
    bridge_test_payload(
      @bookkeeper.bookkeeper_contract_version(),
      "deliverable",
    ),
    [],
    [bridge_test_evidence("deliverable")],
  )
  assert_true(persist_bookkeeper_record(root, deliverable).accepted)
  ignore(bridge_test_accept(root, deliverable, "deliverable-reviewer", 110))
  let outcome = bridge_test_record(
    OutcomeBinding,
    "outcome",
    bridge_test_payload(@bookkeeper.three_gap_contract_version(), "outcome"),
    [deliverable.record],
    [bridge_test_evidence("outcome")],
  )
  assert_true(persist_bookkeeper_record(root, outcome).accepted)
  let finding_one = bridge_test_record(
    ThreeGapFinding,
    "finding-one",
    bridge_test_payload(@bookkeeper.three_gap_contract_version(), "finding-one"),
    [outcome.record],
    [bridge_test_evidence("finding-one")],
  )
  let finding_two = bridge_test_record(
    ThreeGapFinding,
    "finding-two",
    bridge_test_payload(@bookkeeper.three_gap_contract_version(), "finding-two"),
    [outcome.record],
    [bridge_test_evidence("finding-two")],
  )
  assert_true(persist_bookkeeper_record(root, finding_one).accepted)
  assert_true(persist_bookkeeper_record(root, finding_two).accepted)
  ignore(bridge_test_accept(root, finding_one, "finding-reviewer-one", 120))
  ignore(bridge_test_accept(root, finding_two, "finding-reviewer-two", 121))
  let proposal_evidence = [
    bridge_test_evidence("finding-one"),
    bridge_test_evidence("finding-two"),
  ]
  let policy : @bookkeeper.VersionedRecordReference = {
    record_id: "three-gap-policy",
    record_version: "v1",
    record_digest: "sha256:three-gap-policy",
  }
  let proposal_payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "capability_proposal.v1",
    "proposal_id": "proposal",
    "proposal_version": "v1",
    "subject": finding_one.record.to_json(),
    "capability_id": "capability",
    "capability_version": "v2",
    "change_digest": "sha256:capability-change",
    "summary": "Bridge fixture summary proposal",
    "owner_route": "owner://bridge",
    "evidence_refs": proposal_evidence.to_json(),
    "source_finding_refs": [finding_one.record, finding_two.record].to_json(),
    "promotion_policy_ref": policy.to_json(),
    "aggregation_digest": "sha256:capability-change",
    "policy_promoted": true,
    "review_required": true,
    "self_application_allowed": false,
  }
  let proposal = bridge_test_record(
    CapabilityProposal,
    "proposal",
    proposal_payload,
    [finding_one.record, finding_two.record],
    proposal_evidence,
  )
  assert_true(persist_bookkeeper_record(root, proposal).accepted)
  let proposal_review = bridge_test_accept(
    root, proposal, "proposal-reviewer", 130,
  )
  let projection_request : GovernedWorkOrderBridgeRequest = {
    contract_version: bookkeeper_work_order_bridge_contract_version(),
    proposal: proposal.record,
    proposal_review: proposal_review.receipt,
    authority_grant: proposal_review.reviewer.grant,
  }
  let projected = project_governed_mooncode_work_order(root, projection_request)
  assert_true(projected.accepted)
  let replay = project_governed_mooncode_work_order(root, projection_request)
  assert_true(replay.accepted)
  assert_true(replay.idempotent)
  let snapshot = replay_bookkeeper_store(root)
  let mut selected_work_order : DurableBookkeeperRecord? = None
  for record in snapshot.records {
    if record.stage == MoonCodeWorkOrder &&
      record.subject == Some(proposal.record) {
      selected_work_order = Some(record)
    }
  }
  let work_order = selected_work_order.unwrap()
  let denied = emit_governed_mooncode_work_order(root, {
    contract_version: bookkeeper_work_order_bridge_contract_version(),
    work_order: work_order.record,
    work_order_review: proposal_review.receipt,
    authority_grant: proposal_review.reviewer.grant,
  })
  assert_false(denied.accepted)
  let work_order_review = bridge_test_accept(
    root, work_order, "work-order-reviewer", 140,
  )
  let egress_request : GovernedWorkOrderEgressRequest = {
    contract_version: bookkeeper_work_order_bridge_contract_version(),
    work_order: work_order.record,
    work_order_review: work_order_review.receipt,
    authority_grant: work_order_review.reviewer.grant,
  }
  let emitted = emit_governed_mooncode_work_order(root, egress_request)
  assert_true(emitted.accepted)
  let emitted_replay = emit_governed_mooncode_work_order(root, egress_request)
  assert_true(emitted_replay.accepted)
  assert_true(emitted_replay.idempotent)
  let final_snapshot = replay_bookkeeper_store(root)
  let mut selected_envelope : BookkeeperTransportEnvelope? = None
  for item in final_snapshot.envelopes {
    if item.message_kind == "mooncode.work_order" &&
      item.subject == work_order.record {
      selected_envelope = Some(item)
    }
  }
  let envelope = selected_envelope.unwrap()
  assert_false(envelope.external_activation_allowed)
  assert_false(envelope.side_effects_applied)
  assert_true(envelope.payload.stringify().contains("\"auto_confirm\":false"))
  let packet_path = materialize_mooncode_draft_packet(root, {
    contract_version: bookkeeper_work_order_bridge_contract_version(),
    envelope: envelope.envelope,
  }).unwrap()
  let packet = @json.parse(@fsx.read_file(packet_path))
  assert_true(packet.stringify().contains("mooncode_work_order_controller"))
  assert_true(packet.stringify().contains("\"auto_execute\":false"))
}
