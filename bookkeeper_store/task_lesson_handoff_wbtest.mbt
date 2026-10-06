///|
fn lesson_handoff_test_payload() -> OutcomeLessonTaskHandoff {
  let source : Json = {
    "kind": "native_execution",
    "run_id": "run-fixture",
    "command_id": "command-fixture",
  }
  let task = (
    {
      "task_id": "task-fixture",
      "project_id": "project-fixture",
      "revision": 3,
      "title": "Synthetic accepted task",
      "source_context": { "reference": "fixture://source" },
      "accepted_report_id": "report-fixture",
      "accepted_delivery_source": source,
      "acceptance_receipt": {
        "action": "internal_acceptance",
        "report_id": "report-fixture",
        "revision": 3,
        "delivery_source": source,
        "actor_id": "fixture-reviewer",
        "event_id": "task-accept-event",
        "audit_id": "task-accept-event:audit",
        "audit_state": "available",
      },
    } : Json).stringify()
  let report = (
    {
      "report": {
        "reportGuid": "report-fixture",
        "task_id": "task-fixture",
        "summary": "Synthetic local result",
        "delivery_source": source,
      },
      "receipt": {
        "action": "report",
        "delivery_source": source,
        "report_id": "report-fixture",
        "revision": 1,
        "actor_id": "fixture-author",
        "event_id": "report-event",
        "audit_id": "report-event:audit",
        "audit_state": "available",
      },
    } : Json).stringify()
  {
    contract_version: "moonproj.book-lesson-handoff.v1",
    source_product: "moonproj",
    task: {
      record_id: "task-fixture",
      record_version: "3",
      record_digest: lesson_handoff_digest(task),
    },
    report: {
      record_id: "report-fixture",
      record_version: "1",
      record_digest: lesson_handoff_digest(report),
    },
    task_snapshot: task,
    report_snapshot: report,
    customer_acceptance: "not_asserted",
    cash: "not_asserted",
    authorizing: false,
  }
}

///|
fn lesson_handoff_test_submission(
  handoff : OutcomeLessonTaskHandoff,
  id? : String = "proj-outcome-fixture",
) -> ProductOutcomeSubmission {
  let original = submission_fixture()
  let evidence : Array[@bookkeeper.VersionedEvidenceReference] = [
    handoff.task,
    handoff.report,
  ].map(reference => {
    reference_id: reference.record_id,
    reference_version: reference.record_version,
    digest: reference.record_digest,
    provenance_ref: "fixture://moonproj/" + reference.record_id,
  })
  let ids = evidence.map(item => item.reference_id)
  {
    ..original,
    source_product: "moonproj",
    submission: submission_test_ref(id),
    evidence_refs: evidence,
    decision_evidence_id: handoff.report.record_id,
    information_gap: { ..original.information_gap, evidence_refs: ids, },
    recognition_gap: { ..original.recognition_gap, evidence_refs: ids, },
    decisiveness_gap: { ..original.decisiveness_gap, evidence_refs: ids, },
  }
}

///|
async fn lesson_handoff_test_reviewed(
  root : String,
  handoff : OutcomeLessonTaskHandoff,
  id? : String = "proj-outcome-fixture",
) -> ProductOutcomeClosureReceipt {
  let submission = lesson_handoff_test_submission(handoff, id~)
  let first = submit_product_outcome(root, submission)
  ignore(
    closure_test_accept(
      root,
      find_record(replay_bookkeeper_store(root), first.deliverable).unwrap(),
      id + "-deliverable",
    ),
  )
  let closure = submit_product_outcome(root, submission).closure.unwrap()
  ignore(
    closure_test_accept(
      root,
      find_record(replay_bookkeeper_store(root), closure.three_gap_assessment).unwrap(),
      id + "-assessment",
    ),
  )
  closure
}

///|
async test "task handoff resolves exact existing reviewed chain without writes" {
  let root = @fs.tmpdir(prefix="book-task-handoff-")
  let handoff = lesson_handoff_test_payload()
  let missing = resolve_outcome_lesson_handoff(root, handoff)
  assert_eq(lesson_handoff_text(missing, "state"), "reviewed_source_missing")
  let closure = lesson_handoff_test_reviewed(root, handoff)
  let before = replay_bookkeeper_store(root)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/task-handoff",
    @json.parse(handoff.to_json().stringify()),
  )
  assert_eq(status, 200)
  let result = lesson_handoff_field(response, "result")
  assert_eq(lesson_handoff_field(result, "handoff"), handoff.to_json())
  assert_eq(lesson_handoff_text(result, "state"), "reviewed_source_available")
  guard lesson_handoff_field(result, "sources") is [source] else {
    fail("one reviewed source")
  }
  assert_eq(
    lesson_handoff_field(source, "outcome"),
    closure.outcome_binding.to_json(),
  )
  assert_eq(
    lesson_handoff_field(source, "assessment"),
    closure.three_gap_assessment.to_json(),
  )
  assert_eq(replay_bookkeeper_store(root), before)
  ignore(lesson_handoff_test_reviewed(root, handoff, id="second-fixture"))
  assert_eq(
    lesson_handoff_text(resolve_outcome_lesson_handoff(root, handoff), "state"),
    "choose_reviewed_source",
  )
}

///|
async test "task handoff never creates missing acceptance and rejects altered exact identity" {
  let root = @fs.tmpdir(prefix="book-task-handoff-rejections-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  let first = submit_product_outcome(root, submission)
  let before = replay_bookkeeper_store(root)
  assert_eq(
    lesson_handoff_text(resolve_outcome_lesson_handoff(root, handoff), "state"),
    "reviewed_source_missing",
  )
  assert_eq(replay_bookkeeper_store(root), before)
  ignore(
    closure_test_accept(
      root,
      find_record(before, first.deliverable).unwrap(),
      "deliverable-only",
    ),
  )
  ignore(submit_product_outcome(root, submission))
  assert_eq(
    lesson_handoff_text(resolve_outcome_lesson_handoff(root, handoff), "state"),
    "reviewed_source_missing",
  )
  for
    wrong in [
      { ..handoff, task_snapshot: handoff.task_snapshot + " ", },
      { ..handoff, report: { ..handoff.report, record_version: "2", }, },
      { ..handoff, task: { ..handoff.task, record_id: "neighbor", }, },
      { ..handoff, authorizing: true, },
      { ..handoff, customer_acceptance: "accepted", },
    ] {
    let (status, _) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      wrong.to_json(),
    )
    assert_eq(status, 422)
  }
}

///|
async test "serialized Proj producer fixture enters the real Book handler and lesson journal" {
  if @env.get_env_var("MOONPROJ_LESSON_FIXTURE_OUTPUT") is Some(path) {
    let payload = @json.parse(@fs.read_file(path).text())
    let handoff : OutcomeLessonTaskHandoff = @json.from_json(payload)
    let root = @fs.tmpdir(prefix="book-proj-serialized-handoff-")
    let closure = lesson_handoff_test_reviewed(root, handoff)
    let before = replay_bookkeeper_store(root)
    let (status, response) = outcome_lesson_request(
      root, "/api/bookkeeper/lessons/task-handoff", payload,
    )
    assert_eq(status, 200)
    let result = lesson_handoff_field(response, "result")
    guard lesson_handoff_field(result, "sources") is [source] else {
      fail("source")
    }
    let review : @bookkeeper.VersionedRecordReference = @json.from_json(
      lesson_handoff_field(source, "assessment_review"),
    )
    let draft : OutcomeLessonDraft = {
      contract_version: "moonbook.outcome-lesson.v1",
      lesson_id: "received-task",
      lesson_version: "1",
      title: "Synthetic reviewed lesson",
      guidance: "Inspect actual contradictory evidence",
      outcome: closure.outcome_binding,
      assessment: closure.three_gap_assessment,
      assessment_review: review,
      applicability: [{ key: "project_id", value: "project-fixture", }],
      invalidation: [],
      recorded_at: 200,
    }
    assert_eq(replay_bookkeeper_store(root), before)
    let saved = prepare_outcome_lesson(root, draft)
    assert_true(saved.accepted)
    assert_true(
      replay_bookkeeper_store(root).reviews.all(review => {
        review.subject != saved.event.unwrap()
      }),
    )
    @fs.write_file(
      path + ".book-readback.json",
      response.stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
  }
}

///|
async test "task handoff never matches another Book or changed captured bytes" {
  let root = @fs.tmpdir(prefix="book-task-exact-root-")
  let other = @fs.tmpdir(prefix="book-task-other-root-")
  let handoff = lesson_handoff_test_payload()
  ignore(lesson_handoff_test_reviewed(root, handoff))
  let before = replay_bookkeeper_store(root)
  assert_eq(
    lesson_handoff_text(resolve_outcome_lesson_handoff(other, handoff), "state"),
    "reviewed_source_missing",
  )
  let changed_bytes = handoff.report_snapshot + " "
  let changed = {
    ..handoff,
    report_snapshot: changed_bytes,
    report: {
      ..handoff.report,
      record_digest: lesson_handoff_digest(changed_bytes),
    },
  }
  assert_eq(
    lesson_handoff_text(resolve_outcome_lesson_handoff(root, changed), "state"),
    "reviewed_source_missing",
  )
  assert_eq(replay_bookkeeper_store(root), before)
}
