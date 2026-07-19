///|
test "Bookkeeper MoonClaw packet binds the durable snapshot and runtime profile" {
  let reference : @bookkeeper.VersionedRecordReference = {
    record_id: "outcome-1",
    record_version: "v1",
    record_digest: "sha256:outcome",
  }
  let record : @bookkeeper_store.DurableBookkeeperRecord = {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: reference,
    stage: @bookkeeper_store.OutcomeBinding,
    subject: None,
    links: [],
    title: "Observed outcome",
    summary: "An exact observed outcome for Three-Gap analysis.",
    owner_route: "bookkeeper",
    status: "observed",
    evidence_refs: [],
    issue_refs: [],
    requires_human_review: false,
    next_action: "analyze gaps",
    source_product: "moonbook",
    recorded_at: 1,
    payload: {},
    side_effects_applied: false,
  }
  let snapshot : @bookkeeper_store.BookkeeperStoreSnapshot = {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    last_sequence: 1,
    records: [record],
    reviews: [],
    envelopes: [],
    replay_issues: [],
  }
  let request : BookkeeperMoonClawRequest = {
    contract_version: bookkeeper_moonclaw_request_contract_version(),
    request_id: "learning-1",
    request_version: "v1",
    subject: reference,
    objective: "Analyze the observed outcome.",
    recorded_at: 2,
  }
  let subject = bookkeeper_moonclaw_subject_record(snapshot, request)
  let packet = bookkeeper_moonclaw_packet(request, subject, snapshot)
  assert_eq(packet.profile, "bookkeeper_three_gap_controller")
  assert_eq(
    packet.output_contract,
    bookkeeper_moonclaw_result_contract_version(),
  )
  assert_true(packet.source_path.contains("snapshot.json"))
  assert_true(packet.metadata.stringify().contains("gpt-5.6-sol"))
  assert_true(packet.metadata.stringify().contains("source_snapshot_digest"))
}
