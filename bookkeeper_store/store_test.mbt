///|
fn test_record_ref(id : String) -> @bookkeeper.VersionedRecordReference {
  { record_id: id, record_version: "1", record_digest: "sha256:\{id}" }
}

///|
fn test_evidence(id : String) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "1",
    digest: "sha256:\{id}",
    provenance_ref: "fixture://\{id}",
  }
}

///|
fn test_record(
  stage : BookkeeperStage,
  id : String,
  links : Array[@bookkeeper.VersionedRecordReference],
  source_product? : String = "fixture",
) -> DurableBookkeeperRecord {
  let payload_contract = match stage {
    DeliverableAcceptance | CapabilityProposal =>
      @bookkeeper.bookkeeper_contract_version()
    OutcomeBinding | ThreeGapFinding | MoonCodeWorkOrder =>
      @bookkeeper.three_gap_contract_version()
    MoonCodeResult | Evaluation | Adoption =>
      @bookkeeper.capability_adoption_contract_version()
    ThreeGapReview | CapabilityReview => bookkeeper_store_contract_version()
  }
  let payload : Json = { "contract_version": payload_contract, "fixture": id }
  {
    contract_version: bookkeeper_store_contract_version(),
    record: {
      record_id: id,
      record_version: "1",
      record_digest: bookkeeper_payload_digest(payload),
    },
    stage,
    subject: None,
    links,
    title: "Fixture \{id}",
    summary: "Replayable fixture record \{id}",
    owner_route: "owner://fixture",
    status: "awaiting review",
    evidence_refs: [test_evidence("evidence-\{id}")],
    issue_refs: [],
    requires_human_review: stage.is_reviewable(),
    next_action: "continue governed loop",
    source_product,
    recorded_at: 100,
    payload,
    side_effects_applied: false,
  }
}

///|
fn test_review(
  record : DurableBookkeeperRecord,
  id : String,
  reviewer_kind? : @bookkeeper.ReviewerKind = @bookkeeper.Human,
) -> GovernedReviewMutation {
  {
    contract_version: bookkeeper_store_contract_version(),
    mutation: test_record_ref("mutation-\{id}"),
    receipt: test_record_ref("receipt-\{id}"),
    stage: record.stage,
    subject: record.record,
    requested: @bookkeeper.Accept,
    reviewer_kind,
    reviewer: {
      grant: test_record_ref("grant-human-reviewer"),
      reviewer_id: "human-reviewer",
      authority_ref: "authority://human-reviewer",
      authorized: true,
      evidence_refs: [record.evidence_refs[0].reference_id],
    },
    evidence_refs: record.evidence_refs,
    summary: "Governed fixture review",
    decided_at: 101,
  }
}

///|
async fn install_test_reviewer(root : String) -> Unit {
  ignore(
    install_bookkeeper_authority_grant(root, {
      contract_version: bookkeeper_store_contract_version(),
      grant: test_record_ref("grant-human-reviewer"),
      reviewer_id: "human-reviewer",
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "authority://human-reviewer",
      evidence_refs: ["evidence-deliverable-1"],
      active: true,
      granted_at: 99,
    }),
  )
}

///|
async test "durable Bookkeeper replay preserves exact reviews and projections" {
  let root = "/tmp/moonbook-bookkeeper-store-\{@async.now().to_int()}"
  let deliverable = test_record(DeliverableAcceptance, "deliverable-1", [])
  install_test_reviewer(root)
  let first = persist_bookkeeper_record(root, deliverable)
  inspect(first.accepted, content="true")
  inspect(first.idempotent, content="false")
  let duplicate = persist_bookkeeper_record(root, deliverable)
  inspect(duplicate.accepted, content="true")
  inspect(duplicate.idempotent, content="true")

  let nonhuman = apply_governed_review(
    root,
    test_review(deliverable, "nonhuman", reviewer_kind=@bookkeeper.Agent),
  )
  inspect(nonhuman.accepted, content="false")
  assert_true(nonhuman.review.unwrap().disposition == @bookkeeper.Revise)

  let reviewed = apply_governed_review(
    root,
    test_review(deliverable, "deliverable"),
  )
  inspect(reviewed.accepted, content="true")
  inspect(reviewed.review.unwrap().review_complete, content="true")

  let outcome = test_record(OutcomeBinding, "outcome-1", [deliverable.record])
  let outcome_result = persist_bookkeeper_record(root, outcome)
  inspect(outcome_result.accepted, content="true")

  let envelope : BookkeeperTransportEnvelope = {
    contract_version: bookkeeper_transport_contract_version(),
    envelope: test_record_ref("envelope-1"),
    direction: Egress,
    source_product: "moonbook",
    destination_product: "moonflow",
    message_kind: "bookkeeper.outcome",
    subject: outcome.record,
    links: [deliverable.record],
    evidence_refs: outcome.evidence_refs,
    authority_ref: "authority://handoff",
    recorded_at: 102,
    payload: outcome.payload,
    external_activation_allowed: false,
    side_effects_applied: false,
  }
  let handed_off = persist_transport_envelope(root, envelope)
  inspect(handed_off.accepted, content="true")

  let replayed = replay_bookkeeper_store(root)
  inspect(replayed.records.length(), content="2")
  inspect(replayed.reviews.length(), content="1")
  inspect(replayed.envelopes.length(), content="1")
  inspect(replayed.replay_issues.length(), content="0")
  let ui = project_bookkeeper_ui_state(root, replayed)
  inspect(ui.deliverable_acceptance.length(), content="1")
  inspect(ui.deliverable_acceptance[0].status, content="accepted")
  inspect(ui.outcome_binding.length(), content="1")
  assert_true(@fsx.exists(bookkeeper_snapshot_path(root)))
  assert_true(@fsx.exists(bookkeeper_ui_state_path(root)))
}

///|
async test "transport envelopes never carry external activation authority" {
  let root = "/tmp/moonbook-bookkeeper-envelope-\{@async.now().to_int()}"
  let deliverable = test_record(
    DeliverableAcceptance,
    "deliverable-activation",
    [],
  )
  ignore(persist_bookkeeper_record(root, deliverable))
  let envelope : BookkeeperTransportEnvelope = {
    contract_version: bookkeeper_transport_contract_version(),
    envelope: test_record_ref("envelope-activation"),
    direction: Egress,
    source_product: "moonbook",
    destination_product: "moonflow",
    message_kind: "bookkeeper.receipt",
    subject: deliverable.record,
    links: [],
    evidence_refs: deliverable.evidence_refs,
    authority_ref: "authority://handoff",
    recorded_at: 102,
    payload: deliverable.payload,
    external_activation_allowed: true,
    side_effects_applied: false,
  }
  let result = persist_transport_envelope(root, envelope)
  inspect(result.accepted, content="false")
  assert_true(
    result.issues.any(fn(issue) { issue.contains("external activation") }),
  )
}

///|
async test "HTTP-style review payload cannot self-assert reviewer authority" {
  let root = "/tmp/moonbook-bookkeeper-authority-\{@async.now().to_int()}"
  let deliverable = test_record(
    DeliverableAcceptance,
    "deliverable-untrusted",
    [],
  )
  ignore(persist_bookkeeper_record(root, deliverable))
  let result = apply_governed_review(
    root,
    test_review(deliverable, "untrusted-human"),
  )
  inspect(result.accepted, content="false")
  assert_true(
    result.issues.any(fn(issue) { issue.contains("authority grant") }),
  )
  assert_true(result.review.unwrap().disposition == @bookkeeper.Revise)
}
