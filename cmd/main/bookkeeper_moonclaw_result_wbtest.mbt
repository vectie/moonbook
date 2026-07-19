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
async fn moonclaw_result_accept_record(
  root : String,
  record : @bookkeeper_store.DurableBookkeeperRecord,
  reviewer_id : String,
  decided_at : Int,
) -> Unit {
  let evidence_ids = record.evidence_refs.map(reference => {
    reference.reference_id
  })
  let grant_payload : Json = { "reviewer_id": reviewer_id }
  let grant = moonclaw_result_test_ref("grant-" + reviewer_id, grant_payload)
  ignore(
    @bookkeeper_store.install_bookkeeper_authority_grant(root, {
      contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
      grant,
      reviewer_id,
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "authority://" + reviewer_id,
      evidence_refs: evidence_ids,
      active: true,
      granted_at: decided_at - 1,
    }),
  )
  let result = @bookkeeper_store.apply_governed_review(root, {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    mutation: moonclaw_result_test_ref("mutation-" + reviewer_id, {
      "reviewer_id": reviewer_id,
      "kind": "mutation",
    }),
    receipt: moonclaw_result_test_ref("receipt-" + reviewer_id, {
      "reviewer_id": reviewer_id,
      "kind": "receipt",
    }),
    stage: record.stage,
    subject: record.record,
    requested: @bookkeeper.Accept,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant,
      reviewer_id,
      authority_ref: "authority://" + reviewer_id,
      authorized: true,
      evidence_refs: evidence_ids,
    },
    evidence_refs: record.evidence_refs,
    summary: "Named-human acceptance for " + record.record.record_id,
    decided_at,
  })
  assert_true(result.accepted)
}

///|
fn moonclaw_result_gap_record(
  id : String,
  outcome : @bookkeeper.VersionedRecordReference,
  learning_key : @bookkeeper.VersionedRecordReference,
  gap_class : String,
  severity : Int,
  owner_route : String,
  evidence : @bookkeeper.VersionedEvidenceReference,
  recorded_at : Int,
) -> @bookkeeper_store.DurableBookkeeperRecord {
  let transition = match gap_class {
    "information_gap" => "unknown_to_known"
    "recognition_gap" => "known_to_matters"
    "decisiveness_gap" => "matters_to_act"
    _ => "invalid"
  }
  let summary = "Reviewed " + gap_class + " finding " + id
  let payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "candidate_schema": "three_gap_finding.v1",
    "subject": outcome.to_json(),
    "learning_key": learning_key.to_json(),
    "gap_class": gap_class,
    "transition": transition,
    "severity": severity,
    "owner_route": owner_route,
    "summary": summary,
    "evidence_refs": [evidence].to_json(),
    "source_snapshot_digest": "sha256:source-snapshot-" + id,
    "source_packet_digest": "sha256:source-packet-" + id,
  }
  {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: moonclaw_result_test_ref(id, payload),
    stage: @bookkeeper_store.ThreeGapFinding,
    subject: Some(outcome),
    links: [outcome],
    title: "Three-Gap finding " + id,
    summary,
    owner_route,
    status: "awaiting human review",
    evidence_refs: [evidence],
    issue_refs: [],
    requires_human_review: true,
    next_action: "named-human review",
    source_product: "moonclaw",
    recorded_at,
    payload,
    side_effects_applied: false,
  }
}

///|
async fn moonclaw_result_fixture_json() -> Json {
  let fixture_path = moonbook_cmd_path(@env.current_dir().unwrap_or("."))
    .join(moonbook_cmd_path("docs/BOOKKEEPER_MOONCLAW_RESULT.fixture.json"))
    .to_string()
  @json.parse(@fsx.read_file(fixture_path))
}

///|
fn moonclaw_step_result_wrapper(content : String) -> Json {
  {
    "step_id": "bookkeeper-result",
    "result_decision": "accepted",
    "requires_review": false,
    "notify_town": true,
    "model": "gpt-5.6-sol",
    "content": content,
    "metadata": {},
  }
}

///|
test "Bookkeeper derives a stable versioned learning key from policy and outcome" {
  let subject : @bookkeeper.VersionedRecordReference = {
    record_id: "outcome-stable",
    record_version: "v3",
    record_digest: "sha256:outcome-stable-v3",
  }
  let first = bookkeeper_outcome_learning_key(subject)
  let replay = bookkeeper_outcome_learning_key(subject)
  assert_true(first == replay)
  assert_true(first.record_id.has_prefix("three-gap-learning-"))
  assert_true(first.record_version == "v1")
  let changed = bookkeeper_outcome_learning_key({
    ..subject,
    record_digest: "sha256:outcome-stable-v3-corrected",
  })
  assert_true(first != changed)
}

///|
async test "Bookkeeper MoonClaw result accepts raw canonical result" {
  let decoded = decode_bookkeeper_moonclaw_result_input(
    moonclaw_result_fixture_json(),
  )
  inspect(
    decoded.contract_version,
    content="moonbook.bookkeeper.moonclaw-result.v1",
  )
}

///|
async test "Bookkeeper MoonClaw result unwraps standard step result artifact" {
  let raw = moonclaw_result_fixture_json()
  let wrapped = moonclaw_step_result_wrapper(
    "MoonClaw completed the bounded step.\n```json\n" +
    raw.stringify() +
    "\n```\n",
  )
  let decoded = decode_bookkeeper_moonclaw_result_input(wrapped)
  inspect(decoded.packet_id, content="bookkeeper-learning-example-v1")
}

///|
async test "Bookkeeper MoonClaw result rejects multiple fenced blocks" {
  let raw = moonclaw_result_fixture_json().stringify()
  let wrapped = moonclaw_step_result_wrapper(
    "```json\n" + raw + "\n```\n```json\n" + raw + "\n```",
  )
  try decode_bookkeeper_moonclaw_result_input(wrapped) catch {
    error => assert_true("\{error}".contains("exactly one fenced JSON object"))
  } noraise {
    _ => fail("multiple fenced result blocks must be rejected")
  }
}

///|
async test "Bookkeeper MoonClaw result rejects wrong fenced schema" {
  let wrapped = moonclaw_step_result_wrapper(
    "```json\n{\"contract_version\":\"wrong.result.v1\"}\n```",
  )
  try decode_bookkeeper_moonclaw_result_input(wrapped) catch {
    error => assert_true("\{error}".contains("missing candidate"))
  } noraise {
    _ => fail("wrong fenced result schema must be rejected")
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
  let performance_evidence = moonclaw_result_test_evidence(
    "evidence-performance",
  )
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
    evidence_refs: [
      outcome_evidence, deliverable_evidence, performance_evidence,
    ],
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
  let learning_key = bookkeeper_moonclaw_learning_key(outcome)
  guard result_required_json(
      packet_metadata, "result_contract", "fixture packet metadata",
    )
    is { "learning_key": packet_learning_key, .. } else {
    fail("fixture packet result contract is missing learning_key")
  }
  assert_true(packet_learning_key == learning_key.to_json())
  let canonical_evidence = bookkeeper_moonclaw_canonical_evidence([outcome])
  let packet_evidence = result_evidence_references(
    result_required_json(
      packet_metadata, "canonical_evidence_refs", "fixture packet metadata",
    ),
    "fixture packet canonical evidence",
  )
  assert_true(packet_evidence == canonical_evidence)
  assert_true(packet_evidence.length() == 3)
  assert_true(packet_evidence[0].reference_id == "evidence-outcome")
  assert_true(packet_evidence[1].reference_id == "evidence-deliverable")
  assert_true(packet_evidence[2].reference_id == "evidence-performance")

  let fixture = decode_bookkeeper_moonclaw_result(
    moonclaw_result_fixture_json(),
  )
  let summary = fixture.candidate.summary
  let owner_route = fixture.candidate.owner_route
  let finding_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "candidate_schema": "three_gap_finding.v1",
    "subject": outcome_ref.to_json(),
    "learning_key": learning_key.to_json(),
    "gap_class": "information_gap",
    "transition": "unknown_to_known",
    "severity": 4,
    "owner_route": owner_route,
    "summary": summary,
    "evidence_refs": canonical_evidence.to_json(),
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
    evidence_refs: canonical_evidence,
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
  let invented_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "candidate_schema": "three_gap_finding.v1",
    "subject": outcome_ref.to_json(),
    "learning_key": {
      "record_id": "model-invented-learning-key",
      "record_version": "v1",
      "record_digest": "sha256:model-invented-learning-key",
    },
    "gap_class": "information_gap",
    "transition": "unknown_to_known",
    "severity": 4,
    "owner_route": owner_route,
    "summary": summary,
    "evidence_refs": canonical_evidence.to_json(),
    "source_snapshot_digest": snapshot_digest,
    "source_packet_digest": packet_digest,
  }
  let invented = {
    ..result,
    candidate: { ..result.candidate, payload: invented_payload },
  }
  try
    ingest_bookkeeper_moonclaw_result(root, packet_path, invented.to_json())
  catch {
    error =>
      assert_true(
        "\{error}".contains(
          "learning_key must exactly copy the MoonBook packet",
        ),
      )
  } noraise {
    _ => fail("model-invented learning_key must be rejected")
  }
  let summary_mismatch = {
    ..result,
    candidate: {
      ..result.candidate,
      summary: result.candidate.summary + " model-only variation",
    },
  }
  try
    ingest_bookkeeper_moonclaw_result(
      root,
      packet_path,
      summary_mismatch.to_json(),
    )
  catch {
    error =>
      assert_true(
        "\{error}".contains("summary or owner route does not match candidate"),
      )
  } noraise {
    _ => fail("candidate and payload summary mismatch must be rejected")
  }
  let owner_route_mismatch = {
    ..result,
    candidate: {
      ..result.candidate,
      owner_route: result.candidate.owner_route + "/model-only-variation",
    },
  }
  try
    ingest_bookkeeper_moonclaw_result(
      root,
      packet_path,
      owner_route_mismatch.to_json(),
    )
  catch {
    error =>
      assert_true(
        "\{error}".contains("summary or owner route does not match candidate"),
      )
  } noraise {
    _ => fail("candidate and payload owner_route mismatch must be rejected")
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
    "learning_key": learning_key.to_json(),
    "gap_class": "information_gap",
    "transition": "unknown_to_known",
    "severity": 4,
    "owner_route": owner_route,
    "summary": conflict_summary,
    "evidence_refs": canonical_evidence.to_json(),
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

///|
async test "MoonBook owns capability promotion policy and aggregation receipt" {
  let root = "/tmp/moonbook-capability-promotion-\{@async.now().to_int()}"
  let deliverable_payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "fixture": "promotion-deliverable",
  }
  let deliverable_evidence = moonclaw_result_test_evidence(
    "promotion-deliverable-evidence",
  )
  let deliverable : @bookkeeper_store.DurableBookkeeperRecord = {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: moonclaw_result_test_ref(
      "promotion-deliverable", deliverable_payload,
    ),
    stage: @bookkeeper_store.DeliverableAcceptance,
    subject: None,
    links: [],
    title: "Promotion deliverable",
    summary: "Accepted deliverable for deterministic promotion.",
    owner_route: "owner://learning",
    status: "awaiting human review",
    evidence_refs: [deliverable_evidence],
    issue_refs: [],
    requires_human_review: true,
    next_action: "review",
    source_product: "moonbook",
    recorded_at: 100,
    payload: deliverable_payload,
    side_effects_applied: false,
  }
  assert_true(
    @bookkeeper_store.persist_bookkeeper_record(root, deliverable).accepted,
  )
  moonclaw_result_accept_record(root, deliverable, "promotion-deliverable", 101)
  let outcome_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "fixture": "promotion-outcome",
  }
  let outcome : @bookkeeper_store.DurableBookkeeperRecord = {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: moonclaw_result_test_ref("promotion-outcome", outcome_payload),
    stage: @bookkeeper_store.OutcomeBinding,
    subject: Some(deliverable.record),
    links: [deliverable.record],
    title: "Promotion outcome",
    summary: "Outcome feeding the deterministic slow loop.",
    owner_route: "owner://learning",
    status: "observed",
    evidence_refs: [moonclaw_result_test_evidence("promotion-outcome-evidence")],
    issue_refs: [],
    requires_human_review: false,
    next_action: "classify gaps",
    source_product: "moonbook",
    recorded_at: 102,
    payload: outcome_payload,
    side_effects_applied: false,
  }
  assert_true(
    @bookkeeper_store.persist_bookkeeper_record(root, outcome).accepted,
  )
  let learning_key = bookkeeper_outcome_learning_key(outcome.record)
  let information = moonclaw_result_gap_record(
    "finding-a-information",
    outcome.record,
    learning_key,
    "information_gap",
    4,
    "owner://learning",
    moonclaw_result_test_evidence("evidence-information"),
    103,
  )
  let recognition = moonclaw_result_gap_record(
    "finding-b-recognition",
    outcome.record,
    learning_key,
    "recognition_gap",
    3,
    "owner://learning",
    moonclaw_result_test_evidence("evidence-recognition"),
    104,
  )
  let decisiveness = moonclaw_result_gap_record(
    "finding-c-decisiveness",
    outcome.record,
    learning_key,
    "decisiveness_gap",
    5,
    "owner://learning",
    moonclaw_result_test_evidence("evidence-decisiveness"),
    105,
  )
  let low_recognition = moonclaw_result_gap_record(
    "finding-d-low-recognition",
    outcome.record,
    learning_key,
    "recognition_gap",
    1,
    "owner://learning",
    moonclaw_result_test_evidence("evidence-low-recognition"),
    106,
  )
  let mixed_key = moonclaw_result_gap_record(
    "finding-e-mixed-key",
    outcome.record,
    { ..learning_key, record_digest: "sha256:mixed-learning-key" },
    "information_gap",
    4,
    "owner://learning",
    moonclaw_result_test_evidence("evidence-mixed-key"),
    107,
  )
  let wrong_owner = moonclaw_result_gap_record(
    "finding-f-wrong-owner",
    outcome.record,
    learning_key,
    "information_gap",
    4,
    "owner://different",
    moonclaw_result_test_evidence("evidence-wrong-owner"),
    108,
  )
  let unreviewed = moonclaw_result_gap_record(
    "finding-g-unreviewed",
    outcome.record,
    learning_key,
    "information_gap",
    4,
    "owner://learning",
    moonclaw_result_test_evidence("evidence-unreviewed"),
    109,
  )
  let findings = [
    information, recognition, decisiveness, low_recognition, mixed_key, wrong_owner,
    unreviewed,
  ]
  for finding in findings {
    assert_true(
      @bookkeeper_store.persist_bookkeeper_record(root, finding).accepted,
    )
  }
  for
    item in [
      (information, "information-reviewer", 110),
      (recognition, "recognition-reviewer", 111),
      (decisiveness, "decisiveness-reviewer", 112),
      (low_recognition, "low-reviewer", 113),
      (mixed_key, "mixed-reviewer", 114),
      (wrong_owner, "owner-reviewer", 115),
    ] {
    let (finding, reviewer, decided_at) = item
    moonclaw_result_accept_record(root, finding, reviewer, decided_at)
  }
  let snapshot = @bookkeeper_store.replay_bookkeeper_store(root)
  let request : BookkeeperMoonClawRequest = {
    contract_version: bookkeeper_moonclaw_request_contract_version(),
    request_id: "capability-promotion",
    request_version: "v1",
    subject: information.record,
    objective: "Propose the repeated evidence-bound capability improvement.",
    recorded_at: 116,
  }
  let packet = bookkeeper_moonclaw_packet(request, information, snapshot)
  let packet_path = persist_bookkeeper_moonclaw_packet(root, request, packet)
  guard packet.metadata is Object(metadata) else {
    fail("promotion packet metadata missing")
  }
  let snapshot_digest = result_required_string(
    metadata, "source_snapshot_digest", "promotion packet",
  )
  let packet_digest = result_required_string(
    metadata, "source_packet_digest", "promotion packet",
  )
  let policy = bookkeeper_capability_promotion_policy()
  guard result_required_json(metadata, "result_contract", "promotion packet")
    is {
      "promotion_policy": packet_policy,
      "aggregation_digest_source": "moonbook",
      ..
    } else {
    fail("promotion packet omits MoonBook-owned policy metadata")
  }
  assert_true(packet_policy == policy.to_json())
  let make_result = fn(
    records : Array[@bookkeeper_store.DurableBookkeeperRecord],
    policy_ref : @bookkeeper.VersionedRecordReference,
  ) -> BookkeeperMoonClawResult raise {
    let links = records.map(record => record.record)
    let evidence = bookkeeper_moonclaw_capability_evidence(records)
    let summary = "Add the reviewed evidence-routing capability."
    let payload : Json = {
      "contract_version": @bookkeeper.bookkeeper_contract_version(),
      "candidate_schema": "capability_proposal.v1",
      "proposal_id": "proposal-policy-owned",
      "proposal_version": "v1",
      "subject": information.record.to_json(),
      "capability_id": "capability://evidence-routing",
      "capability_version": "v2",
      "change_digest": "sha256:evidence-routing-v2",
      "summary": summary,
      "owner_route": "owner://learning",
      "evidence_refs": evidence.to_json(),
      "source_finding_refs": links.to_json(),
      "promotion_policy_ref": policy_ref.to_json(),
      "source_snapshot_digest": snapshot_digest,
      "source_packet_digest": packet_digest,
    }
    {
      contract_version: bookkeeper_moonclaw_result_contract_version(),
      packet_id: packet.packet_id,
      source_packet_digest: packet_digest,
      source_snapshot_digest: snapshot_digest,
      subject: information.record,
      subject_stage: "three_gap_finding",
      evidence_refs: evidence,
      producer: "moonclaw",
      model: "gpt-5.6-sol",
      candidate: {
        record_id: "proposal-policy-owned",
        record_version: "v1",
        stage: "capability_proposal",
        title: "Evidence routing capability",
        summary,
        owner_route: "owner://learning",
        recorded_at: 117,
        links,
        issue_refs: [],
        next_action: "named-human proposal review",
        payload,
      },
    }
  }
  let invalid_policy = make_result([information, recognition, decisiveness], {
    ..policy.policy,
    record_digest: "sha256:model-invented-policy",
  })
  try
    ingest_bookkeeper_moonclaw_result(
      root,
      packet_path,
      invalid_policy.to_json(),
    )
  catch {
    error => assert_true("\{error}".contains("exact promotion policy"))
  } noraise {
    _ => fail("model-invented promotion policy must be rejected")
  }
  for
    item in [
      (
        [information, low_recognition, decisiveness],
        "does not satisfy MoonBook promotion policy",
      ),
      (
        [information, recognition, decisiveness, mixed_key],
        "does not satisfy MoonBook promotion policy",
      ),
      (
        [information, recognition, decisiveness, wrong_owner],
        "does not satisfy MoonBook promotion policy",
      ),
      (
        [information, recognition, decisiveness, unreviewed],
        "named-human accepted record",
      ),
    ] {
    let (records, expected) = item
    try
      ingest_bookkeeper_moonclaw_result(
        root,
        packet_path,
        make_result(records, policy.policy).to_json(),
      )
    catch {
      error => assert_true("\{error}".contains(expected))
    } noraise {
      _ => fail("invalid promotion inputs must be rejected")
    }
  }
  let promoted = ingest_bookkeeper_moonclaw_result(
    root,
    packet_path,
    make_result([information, recognition, decisiveness], policy.policy).to_json(),
  )
  assert_true(promoted.accepted)
  let final_snapshot = @bookkeeper_store.replay_bookkeeper_store(root)
  let mut stored : @bookkeeper_store.DurableBookkeeperRecord? = None
  for record in final_snapshot.records {
    if record.record.record_id == "proposal-policy-owned" {
      stored = Some(record)
    }
  }
  let stored = stored.unwrap()
  guard stored.payload
    is {
      "aggregation_digest": String(aggregation_digest),
      "policy_promoted": true,
      "review_required": true,
      "self_application_allowed": false,
      ..
    } else {
    fail("MoonBook did not persist canonical promotion fields")
  }
  assert_true(aggregation_digest.has_prefix("sha256:"))
  assert_true(aggregation_digest != "sha256:evidence-routing-v2")
}
