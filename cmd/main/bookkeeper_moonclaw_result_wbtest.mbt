///|
fn moonclaw_result_test_ref(
  id : String,
  payload : Json,
) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: id,
    record_version: "v1",
    record_digest: @bookkeeper_store.bookkeeper_payload_digest(payload),
  }
}

///|
fn moonclaw_result_test_evidence(
  id : String,
) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "v1",
    digest: "sha256:\{id}",
    provenance_ref: "fixture://\{id}",
  }
}

///|
async test "Bookkeeper MoonClaw result ingests once into the Rabbita review queue" {
  let root = "/tmp/moonbook-moonclaw-result-\{@async.now().to_int()}"
  let deliverable_evidence = moonclaw_result_test_evidence(
    "evidence-deliverable",
  )
  let deliverable_payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "fixture": "accepted-deliverable",
  }
  let deliverable_ref = moonclaw_result_test_ref(
    "deliverable-moonclaw", deliverable_payload,
  )
  let deliverable : @bookkeeper_store.DurableBookkeeperRecord = {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: deliverable_ref,
    stage: @bookkeeper_store.DeliverableAcceptance,
    subject: None,
    links: [],
    title: "Accepted deliverable",
    summary: "The exact deliverable used by the closed-loop fixture.",
    owner_route: "bookkeeper://acceptance",
    status: "awaiting human review",
    evidence_refs: [deliverable_evidence],
    issue_refs: [],
    requires_human_review: true,
    next_action: "named-human acceptance",
    source_product: "moonbook",
    recorded_at: 10,
    payload: deliverable_payload,
    side_effects_applied: false,
  }
  inspect(
    @bookkeeper_store.persist_bookkeeper_record(root, deliverable).accepted,
    content="true",
  )
  let grant_payload : Json = { "fixture": "moonclaw-result-reviewer" }
  let grant_ref = moonclaw_result_test_ref(
    "grant-moonclaw-result", grant_payload,
  )
  ignore(
    @bookkeeper_store.install_bookkeeper_authority_grant(root, {
      contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
      grant: grant_ref,
      reviewer_id: "fixture-reviewer",
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "authority://fixture-reviewer",
      evidence_refs: [deliverable_evidence.reference_id],
      active: true,
      granted_at: 11,
    }),
  )
  let mutation_payload : Json = { "fixture": "accept-deliverable" }
  let receipt_payload : Json = { "fixture": "accept-deliverable-receipt" }
  let accepted = @bookkeeper_store.apply_governed_review(root, {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    mutation: moonclaw_result_test_ref(
      "mutation-accept-deliverable", mutation_payload,
    ),
    receipt: moonclaw_result_test_ref(
      "receipt-accept-deliverable", receipt_payload,
    ),
    stage: @bookkeeper_store.DeliverableAcceptance,
    subject: deliverable_ref,
    requested: @bookkeeper.Accept,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant: grant_ref,
      reviewer_id: "fixture-reviewer",
      authority_ref: "authority://fixture-reviewer",
      authorized: true,
      evidence_refs: [deliverable_evidence.reference_id],
    },
    evidence_refs: [deliverable_evidence],
    summary: "Named-human fixture acceptance",
    decided_at: 12,
  })
  inspect(accepted.accepted, content="true")

  let outcome_evidence = moonclaw_result_test_evidence("evidence-outcome")
  let outcome_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "fixture": "observed-outcome",
  }
  let outcome_ref = moonclaw_result_test_ref(
    "outcome-moonclaw", outcome_payload,
  )
  let outcome : @bookkeeper_store.DurableBookkeeperRecord = {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: outcome_ref,
    stage: @bookkeeper_store.OutcomeBinding,
    subject: Some(deliverable_ref),
    links: [deliverable_ref],
    title: "Observed outcome",
    summary: "Outcome evidence bound to the accepted deliverable.",
    owner_route: "bookkeeper://outcomes",
    status: "observed",
    evidence_refs: [outcome_evidence],
    issue_refs: [],
    requires_human_review: false,
    next_action: "analyze Three-Gap finding",
    source_product: "moonbook",
    recorded_at: 13,
    payload: outcome_payload,
    side_effects_applied: false,
  }
  inspect(
    @bookkeeper_store.persist_bookkeeper_record(root, outcome).accepted,
    content="true",
  )

  let snapshot = @bookkeeper_store.replay_bookkeeper_store(root)
  let request : BookkeeperMoonClawRequest = {
    contract_version: bookkeeper_moonclaw_request_contract_version(),
    request_id: "learning-fixture",
    request_version: "v1",
    subject: outcome_ref,
    objective: "Explain the observed outcome through Three-Gap theory.",
    recorded_at: 14,
  }
  let packet = bookkeeper_moonclaw_packet(request, outcome, snapshot)
  let packet_path = persist_bookkeeper_moonclaw_packet(root, request, packet)
  guard packet.metadata is Object(packet_metadata) else {
    fail("fixture packet metadata missing")
  }
  let snapshot_digest = result_required_string(
    packet_metadata, "source_snapshot_digest", "fixture packet metadata",
  )
  let packet_digest = result_required_string(
    packet_metadata, "source_packet_digest", "fixture packet metadata",
  )

  let fixture_path = moonbook_cmd_path(@env.current_dir().unwrap_or("."))
    .join(moonbook_cmd_path("docs/BOOKKEEPER_MOONCLAW_RESULT.fixture.json"))
    .to_string()
  let fixture = decode_bookkeeper_moonclaw_result(
    @json.parse(@fsx.read_file(fixture_path)),
  )
  let summary = fixture.candidate.summary
  let owner_route = fixture.candidate.owner_route
  let finding_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "candidate_schema": "three_gap_finding.v1",
    "subject": outcome_ref.to_json(),
    "learning_key": {
      "record_id": "learning-key-fixture",
      "record_version": "v1",
      "record_digest": "sha256:learning-key-fixture",
    },
    "gap_class": "information_gap",
    "transition": "unknown_to_known",
    "severity": 4,
    "owner_route": owner_route,
    "summary": summary,
    "evidence_refs": [outcome_evidence.to_json()],
    "source_snapshot_digest": snapshot_digest,
    "source_packet_digest": packet_digest,
  }
  let result : BookkeeperMoonClawResult = {
    contract_version: bookkeeper_moonclaw_result_contract_version(),
    packet_id: packet.packet_id,
    source_packet_digest: packet_digest,
    source_snapshot_digest: snapshot_digest,
    subject: outcome_ref,
    subject_stage: "outcome_binding",
    evidence_refs: [outcome_evidence],
    producer: "moonclaw",
    model: "gpt-5.6-sol",
    candidate: {
      record_id: fixture.candidate.record_id,
      record_version: fixture.candidate.record_version,
      stage: "three_gap_finding",
      title: fixture.candidate.title,
      summary,
      owner_route,
      recorded_at: fixture.candidate.recorded_at,
      links: [outcome_ref],
      issue_refs: [],
      next_action: fixture.candidate.next_action,
      payload: finding_payload,
    },
  }
  let first = ingest_bookkeeper_moonclaw_result(
    root,
    packet_path,
    result.to_json(),
  )
  inspect(first.accepted, content="true")
  inspect(first.idempotent, content="false")
  let replay = ingest_bookkeeper_moonclaw_result(
    root,
    packet_path,
    result.to_json(),
  )
  inspect(replay.accepted, content="true")
  inspect(replay.idempotent, content="true")

  let final_snapshot = @bookkeeper_store.replay_bookkeeper_store(root)
  let ui = @bookkeeper_store.project_bookkeeper_ui_state(root, final_snapshot)
  inspect(ui.three_gap_findings.length(), content="1")
  inspect(ui.three_gap_findings[0].requires_human_review, content="true")
  inspect(ui.three_gap_review.length(), content="0")
  inspect(final_snapshot.reviews.length(), content="1")
  let authorities = @bookkeeper_store.bookkeeper_authority_registry(root)
  inspect(authorities.grants.length(), content="1")

  let conflict_summary = summary + " Conflicting replay."
  let conflicting_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "candidate_schema": "three_gap_finding.v1",
    "subject": outcome_ref.to_json(),
    "learning_key": {
      "record_id": "learning-key-fixture",
      "record_version": "v1",
      "record_digest": "sha256:learning-key-fixture",
    },
    "gap_class": "information_gap",
    "transition": "unknown_to_known",
    "severity": 4,
    "owner_route": owner_route,
    "summary": conflict_summary,
    "evidence_refs": [outcome_evidence.to_json()],
    "source_snapshot_digest": snapshot_digest,
    "source_packet_digest": packet_digest,
  }
  let conflict : BookkeeperMoonClawResult = {
    contract_version: result.contract_version,
    packet_id: result.packet_id,
    source_packet_digest: result.source_packet_digest,
    source_snapshot_digest: result.source_snapshot_digest,
    subject: result.subject,
    subject_stage: result.subject_stage,
    evidence_refs: result.evidence_refs,
    producer: result.producer,
    model: result.model,
    candidate: {
      record_id: result.candidate.record_id,
      record_version: result.candidate.record_version,
      stage: result.candidate.stage,
      title: result.candidate.title,
      summary: conflict_summary,
      owner_route,
      recorded_at: result.candidate.recorded_at,
      links: result.candidate.links,
      issue_refs: [],
      next_action: result.candidate.next_action,
      payload: conflicting_payload,
    },
  }
  let rejected = ingest_bookkeeper_moonclaw_result(
    root,
    packet_path,
    conflict.to_json(),
  )
  inspect(rejected.accepted, content="false")
  assert_true(rejected.issues.any(fn(issue) { issue.contains("conflicting") }))
}
