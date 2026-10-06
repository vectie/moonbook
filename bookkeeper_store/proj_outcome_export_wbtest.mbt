///|
async fn optional_import_production_export(
  path : String,
  expect_descriptor : Bool,
) -> Json {
  let exported = @json.parse(@fs.read_file(path).text())
  let handoff_json = @json.parse(lesson_handoff_text(exported, "handoff_json"))
  let submission_json = @json.parse(
    lesson_handoff_text(exported, "submission_json"),
  )
  assert_eq(handoff_json, lesson_handoff_field(exported, "handoff"))
  assert_eq(submission_json, lesson_handoff_field(exported, "submission"))
  let handoff : OutcomeLessonTaskHandoff = @json.from_json(handoff_json)
  let submission : ProductOutcomeSubmission = @json.from_json(submission_json)
  for key in optional_capability_keys() {
    guard submission_json is Object(fields) else {
      fail("submission JSON object")
    }
    assert_eq(fields.contains(key), expect_descriptor)
  }
  let root = @fs.tmpdir(prefix="book-actual-proj-outcome-")
  let initial = resolve_outcome_lesson_handoff(root, handoff)
  let import_request : Json = {
    "handoff": handoff_json,
    "submission": submission_json,
  }
  let continue_request : Json = {
    "handoff": handoff_json,
    "submission": submission.submission.to_json(),
  }
  let (status, imported) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/outcome-import", import_request,
  )
  assert_eq(status, 200, msg=imported.stringify())
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(imported), "state"),
    "deliverable_review_required",
  )
  let first = replay_bookkeeper_store(root)
  assert_true(first.reviews.is_empty())
  assert_eq(
    lesson_handoff_field(first.records[0].payload, "product_outcome_submission"),
    submission_json,
  )
  task_outcome_test_review(
    root,
    imported,
    "native-wire-deliverable",
    @bookkeeper.Accept,
  )
  let (status, ready_to_continue) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/task-handoff", handoff_json,
  )
  assert_eq(status, 200)
  let (status, continued) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/outcome-continue", continue_request,
  )
  assert_eq(status, 200, msg=continued.stringify())
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(continued), "state"),
    "assessment_review_required",
  )
  let pending = replay_bookkeeper_store(root)
  let assessment = pending.records.filter(record => {
      record.stage == ThreeGapFinding
    })[0]
  assert_eq(
    assessment.summary,
    submission.capability_summary.unwrap_or(submission.outcome_summary),
  )
  task_outcome_test_review(
    root,
    continued,
    "native-wire-assessment",
    @bookkeeper.Accept,
  )
  let (status, reviewed) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/task-handoff", handoff_json,
  )
  assert_eq(status, 200)
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(reviewed), "state"),
    "reviewed_source_available",
  )
  guard lesson_handoff_field(
      lesson_handoff_field(reviewed, "result"),
      "sources",
    )
    is [_] else {
    fail("exact reviewed source available")
  }
  let snapshot = replay_bookkeeper_store(root)
  assert_eq(snapshot.records.length(), 3)
  assert_eq(snapshot.reviews.length(), 2)
  assert_false(
    snapshot.records.any(record => record.stage == CapabilityProposal),
  )
  let (repeat_status, repeated) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/outcome-import", import_request,
  )
  assert_eq(repeat_status, 200)
  assert_eq(
    lesson_handoff_field(repeated, "result"),
    lesson_handoff_field(reviewed, "result"),
  )
  assert_eq(replay_bookkeeper_store(root), snapshot)
  let general = submit_product_outcome(root, submission)
  if expect_descriptor {
    assert_eq(general.state, "proposal_review_required")
    let proposal = find_record(
      replay_bookkeeper_store(root),
      general.closure.unwrap().capability_proposal.unwrap(),
    ).unwrap()
    assert_eq(proposal.summary, submission.capability_summary.unwrap())
    assert_eq(
      lesson_handoff_text(proposal.payload, "capability_id"),
      submission.capability_id.unwrap(),
    )
    assert_eq(
      lesson_handoff_text(proposal.payload, "change_digest"),
      submission.capability_change_digest.unwrap(),
    )
    assert_false(
      replay_bookkeeper_store(root).envelopes.any(envelope => {
        envelope.direction == Egress
      }),
    )
  } else {
    assert_eq(general.state, "closed_no_capability_change")
    assert_eq(replay_bookkeeper_store(root), snapshot)
  }
  {
    "fixture": "Actual Proj exporter serialized output consumed without reconstructing task or submission",
    "source_export_path": path,
    "handoff": handoff_json,
    "submission": submission_json,
    "initial": initial,
    "import_request": import_request,
    "imported": imported,
    "ready_to_continue": ready_to_continue,
    "continue_request": continue_request,
    "continued": continued,
    "reviewed": reviewed,
    "journal_root": root,
    "snapshot": snapshot.to_json(),
  }
}

///|
async test "actual Proj no-change and proposed-change exporter bytes enter the existing Book review route" {
  if @env.get_env_var("MOONBOOK_PROJ_OUTCOME_EXPORT") is Some(path) &&
    @env.get_env_var("MOONBOOK_PROJ_OUTCOME_WIRE") is Some(output) {
    let wire = optional_import_production_export(path, false)
    @fs.write_file(
      output,
      wire.stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
  }
  if @env.get_env_var("MOONBOOK_PROJ_FULL_OUTCOME_EXPORT") is Some(path) {
    ignore(optional_import_production_export(path, true))
  }
}
