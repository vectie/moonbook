///|
async test "accepted task outcome can enter review through the production lesson handler" {
  let root = @fs.tmpdir(prefix="book-outcome-ui-intake-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/outcome-import",
    @json.parse(
      (
        { "handoff": handoff.to_json(), "submission": submission.to_json() } :
        Json).stringify(),
    ),
  )
  assert_eq(status, 200, msg=response.stringify())
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(response, "result"), "handoff"),
    handoff.to_json(),
  )
  assert_eq(
    lesson_handoff_field(
      lesson_handoff_field(response, "result"),
      "activation_authorized",
    ),
    false.to_json(),
  )
  guard lesson_handoff_field(
      lesson_handoff_field(response, "result"),
      "outcome_submissions",
    )
    is [progress] else {
    fail("the exact imported outcome should be available for review")
  }
  assert_eq(
    lesson_handoff_text(progress, "state"),
    "deliverable_review_required",
  )
  assert_true(replay_bookkeeper_store(root).reviews.is_empty())
}

///|
fn task_outcome_test_entry(response : Json) -> Json raise {
  guard lesson_handoff_field(
      lesson_handoff_field(response, "result"),
      "outcome_submissions",
    )
    is [progress] else {
    fail("expected one exact outcome submission")
  }
  progress
}

///|
async fn task_outcome_test_call(
  root : String,
  operation : String,
  handoff : OutcomeLessonTaskHandoff,
  submission : Json,
) -> Json {
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/" + operation,
    @json.parse(
      ({ "handoff": handoff.to_json(), "submission": submission } : Json).stringify(),
    ),
  )
  assert_eq(status, 200, msg=response.stringify())
  response
}

///|
async fn task_outcome_test_review(
  root : String,
  response : Json,
  suffix : String,
  disposition : @bookkeeper.BookkeeperDisposition,
) -> Unit {
  guard lesson_handoff_field(task_outcome_test_entry(response), "next_record")
    is Object(_) else {
    fail("next review reference must be an object: " + response.stringify())
  }
  let reference : @bookkeeper.VersionedRecordReference = @json.from_json(
    lesson_handoff_field(task_outcome_test_entry(response), "next_record"),
  )
  let record = find_record(replay_bookkeeper_store(root), reference).unwrap()
  ignore(closure_test_decide(root, record, suffix, disposition))
}

///|
async test "outcome continuation uses existing human reviews and stops before capability proposals" {
  let root = @fs.tmpdir(prefix="book-outcome-ui-flow-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  let imported = task_outcome_test_call(
    root,
    "outcome-import",
    handoff,
    submission.to_json(),
  )
  let first = replay_bookkeeper_store(root)
  assert_eq(first.records.length(), 1)
  assert_eq(first.envelopes.length(), 1)
  assert_true(first.reviews.is_empty())
  assert_eq(
    task_outcome_test_call(
      root,
      "outcome-import",
      handoff,
      submission.to_json(),
    ),
    imported,
  )
  assert_eq(
    lesson_handoff_field(
      task_outcome_test_call(
        root,
        "outcome-continue",
        handoff,
        submission.submission.to_json(),
      ),
      "result",
    ),
    lesson_handoff_field(imported, "result"),
  )
  assert_eq(replay_bookkeeper_store(root), first)
  task_outcome_test_review(root, imported, "ui-deliverable", @bookkeeper.Accept)
  ignore(rebuild_bookkeeper_projection(root))
  let readback = resolve_outcome_lesson_handoff(root, handoff)
  guard lesson_handoff_field(readback, "outcome_submissions") is [progress] else {
    fail("progress")
  }
  assert_eq(lesson_handoff_text(progress, "state"), "continue_required")
  let continued = task_outcome_test_call(
    root,
    "outcome-continue",
    handoff,
    submission.submission.to_json(),
  )
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(continued), "state"),
    "assessment_review_required",
  )
  let before_review = replay_bookkeeper_store(root)
  assert_eq(before_review.records.length(), 3)
  assert_eq(before_review.reviews.length(), 1)
  assert_eq(
    task_outcome_test_call(
      root,
      "outcome-continue",
      handoff,
      submission.submission.to_json(),
    ),
    continued,
  )
  assert_eq(replay_bookkeeper_store(root), before_review)
  task_outcome_test_review(root, continued, "ui-assessment", @bookkeeper.Accept)
  let reviewed = replay_bookkeeper_store(root)
  let ready = task_outcome_test_call(
    root,
    "outcome-continue",
    handoff,
    submission.submission.to_json(),
  )
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(ready), "state"),
    "reviewed_source_available",
  )
  assert_eq(replay_bookkeeper_store(root), reviewed)
  ignore(
    task_outcome_test_call(
      root,
      "outcome-import",
      handoff,
      submission.to_json(),
    ),
  )
  assert_eq(replay_bookkeeper_store(root), reviewed)
  assert_false(
    reviewed.records.any(record => record.stage == CapabilityProposal),
  )
  assert_false(reviewed.envelopes.any(envelope => envelope.direction == Egress))
  guard lesson_handoff_field(lesson_handoff_field(ready, "result"), "sources")
    is [source] else {
    fail("reviewed source")
  }
  let draft : OutcomeLessonDraft = {
    contract_version: "moonbook.outcome-lesson.v1",
    lesson_id: "outcome-ui-lesson",
    lesson_version: "1",
    title: "Retain the exact result",
    guidance: "Check the exact evidence before reuse.",
    outcome: @json.from_json(lesson_handoff_field(source, "outcome")),
    assessment: @json.from_json(lesson_handoff_field(source, "assessment")),
    assessment_review: @json.from_json(
      lesson_handoff_field(source, "assessment_review"),
    ),
    applicability: [{ key: "project_id", value: "project-fixture", }],
    invalidation: [],
    recorded_at: 105,
  }
  let lesson = prepare_outcome_lesson(root, draft)
  assert_true(lesson.accepted)
  assert_eq(replay_bookkeeper_store(root).reviews, reviewed.reviews)
}

///|
async test "outcome continuation retains rejected and nonfinal review states" {
  for
    (label, disposition) in [
      ("reject", @bookkeeper.Reject),
      ("revise", @bookkeeper.Revise),
      ("escalate", @bookkeeper.Escalate),
    ] {
    let root = @fs.tmpdir(prefix="book-outcome-ui-decision-")
    let handoff = lesson_handoff_test_payload()
    let submission = lesson_handoff_test_submission(handoff)
    let imported = task_outcome_test_call(
      root,
      "outcome-import",
      handoff,
      submission.to_json(),
    )
    task_outcome_test_review(root, imported, "ui-" + label, disposition)
    let before = replay_bookkeeper_store(root)
    let continued = task_outcome_test_call(
      root,
      "outcome-continue",
      handoff,
      submission.submission.to_json(),
    )
    assert_eq(
      lesson_handoff_text(task_outcome_test_entry(continued), "state"),
      if label == "reject" {
        "deliverable_rejected"
      } else {
        "deliverable_review_required"
      },
    )
    assert_eq(replay_bookkeeper_store(root), before)
  }
  let root = @fs.tmpdir(prefix="book-outcome-ui-assessment-reject-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  let imported = task_outcome_test_call(
    root,
    "outcome-import",
    handoff,
    submission.to_json(),
  )
  task_outcome_test_review(
    root,
    imported,
    "reject-flow-deliverable",
    @bookkeeper.Accept,
  )
  let continued = task_outcome_test_call(
    root,
    "outcome-continue",
    handoff,
    submission.submission.to_json(),
  )
  task_outcome_test_review(
    root,
    continued,
    "reject-flow-assessment",
    @bookkeeper.Reject,
  )
  let before = replay_bookkeeper_store(root)
  let rejected = task_outcome_test_call(
    root,
    "outcome-continue",
    handoff,
    submission.submission.to_json(),
  )
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(rejected), "state"),
    "assessment_rejected",
  )
  assert_eq(replay_bookkeeper_store(root), before)
}

///|
async test "outcome import rejects incomplete changed or differently bound submissions without writes" {
  let root = @fs.tmpdir(prefix="book-outcome-ui-invalid-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  ignore(
    task_outcome_test_call(
      root,
      "outcome-import",
      handoff,
      submission.to_json(),
    ),
  )
  let before = replay_bookkeeper_store(root)
  for
    invalid in [
      { ..submission, outcome_summary: "changed meaning", },
      { ..submission, source_product: "moonclaw", },
      { ..submission, capability_change_digest: Some(""), },
      { ..submission, evidence_refs: [submission.evidence_refs[0]], },
      {
        ..submission,
        evidence_refs: submission.evidence_refs.map(evidence => {
          ..evidence,
          reference_version: "999",
        }),
      },
      {
        ..submission,
        evidence_refs: submission.evidence_refs.map(evidence => {
          ..evidence,
          digest: "sha256:" + "f".repeat(64),
        }),
      },
    ] {
    let (status, _) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/outcome-import",
      { "handoff": handoff.to_json(), "submission": invalid.to_json() },
    )
    assert_eq(status, 422)
    assert_eq(replay_bookkeeper_store(root), before)
  }
  for
    reference in [
      submission_test_ref("absent"),
      { ..submission.submission, record_digest: "sha256:" + "e".repeat(64), },
    ] {
    let (status, _) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/outcome-continue",
      { "handoff": handoff.to_json(), "submission": reference.to_json() },
    )
    assert_eq(status, 422)
    assert_eq(replay_bookkeeper_store(root), before)
  }
  let other = @fs.tmpdir(prefix="book-outcome-other-root-")
  let (status, _) = outcome_lesson_request(
    other,
    "/api/bookkeeper/lessons/outcome-continue",
    {
      "handoff": handoff.to_json(),
      "submission": submission.submission.to_json(),
      "root": root,
    },
  )
  assert_eq(status, 422)
  assert_true(replay_bookkeeper_store(other).records.is_empty())
  let (status, _) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/outcome-import",
    {
      "handoff": { ..handoff, task_snapshot: handoff.task_snapshot + " ", }.to_json(),
      "submission": submission.to_json(),
    },
  )
  assert_eq(status, 422)
  assert_eq(replay_bookkeeper_store(root), before)
}

///|
async test "outcome continuation resumes interrupted intake using the saved exact submission" {
  let source_root = @fs.tmpdir(prefix="book-outcome-source-")
  let root = @fs.tmpdir(prefix="book-outcome-partial-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  ignore(
    task_outcome_test_call(
      source_root,
      "outcome-import",
      handoff,
      submission.to_json(),
    ),
  )
  let record = replay_bookkeeper_store(source_root).records[0]
  assert_true(persist_bookkeeper_record(root, record).accepted)
  let readback = resolve_outcome_lesson_handoff(root, handoff)
  guard lesson_handoff_field(readback, "outcome_submissions") is [progress] else {
    fail("progress")
  }
  assert_eq(lesson_handoff_text(progress, "state"), "continue_required")
  let recovered = task_outcome_test_call(
    root,
    "outcome-continue",
    handoff,
    submission.submission.to_json(),
  )
  assert_eq(
    lesson_handoff_text(task_outcome_test_entry(recovered), "state"),
    "deliverable_review_required",
  )
  assert_eq(replay_bookkeeper_store(root).records, [record])
  assert_eq(replay_bookkeeper_store(root).envelopes.length(), 1)
  assert_true(replay_bookkeeper_store(root).reviews.is_empty())
}

///|
async test "concurrent outcome retries create one assessment and ambiguous review blocks continuation" {
  let root = @fs.tmpdir(prefix="book-outcome-concurrent-")
  let handoff = lesson_handoff_test_payload()
  let submission = lesson_handoff_test_submission(handoff)
  let imported = task_outcome_test_call(
    root,
    "outcome-import",
    handoff,
    submission.to_json(),
  )
  task_outcome_test_review(
    root,
    imported,
    "concurrent-deliverable",
    @bookkeeper.Accept,
  )
  let results : Array[Json] = []
  @async.with_task_group(group => {
    for _ in 0..<4 {
      group.spawn_bg(() => {
        results.push(
          task_outcome_test_call(
            root,
            "outcome-continue",
            handoff,
            submission.submission.to_json(),
          ),
        )
      })
    }
  })
  assert_eq(results.length(), 4)
  assert_true(
    results.all(response => {
      lesson_handoff_text(task_outcome_test_entry(response), "state") ==
      "assessment_review_required"
    }),
  )
  let snapshot = replay_bookkeeper_store(root)
  assert_eq(snapshot.records.length(), 3)
  assert_eq(snapshot.reviews.length(), 1)
  assert_eq(snapshot.envelopes.length(), 1)
  task_outcome_test_review(
    root,
    imported,
    "conflicting-deliverable",
    @bookkeeper.Reject,
  )
  let before = replay_bookkeeper_store(root)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/outcome-continue",
    {
      "handoff": handoff.to_json(),
      "submission": submission.submission.to_json(),
    },
  )
  assert_eq(status, 422)
  assert_true(lesson_handoff_text(response, "error").contains("ambiguous"))
  assert_eq(replay_bookkeeper_store(root), before)
}

///|
async test "actual Proj bytes produce an ordered outcome review wire without preseeded outcome records" {
  if @env.get_env_var("MOONBOOK_OUTCOME_SOURCE") is Some(source) &&
    @env.get_env_var("MOONBOOK_OUTCOME_WIRE") is Some(output) {
    let handoff : OutcomeLessonTaskHandoff = @json.from_json(
      @json.parse(@fs.read_file(source).text()),
    )
    let root = @fs.tmpdir(prefix="book-outcome-native-wire-")
    let submission = lesson_handoff_test_submission(
      handoff,
      id="outcome-native-wire",
    )
    let import_request : Json = {
      "handoff": handoff.to_json(),
      "submission": submission.to_json(),
    }
    let continue_request : Json = {
      "handoff": handoff.to_json(),
      "submission": submission.submission.to_json(),
    }
    let initial = resolve_outcome_lesson_handoff(root, handoff)
    assert_eq(
      lesson_handoff_field(initial, "outcome_submissions"),
      Json::array([]),
    )
    let imported = task_outcome_test_call(
      root,
      "outcome-import",
      handoff,
      submission.to_json(),
    )
    task_outcome_test_review(
      root,
      imported,
      "native-wire-deliverable",
      @bookkeeper.Accept,
    )
    let (ready_status, ready_to_continue) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(ready_status, 200)
    let continued = task_outcome_test_call(
      root,
      "outcome-continue",
      handoff,
      submission.submission.to_json(),
    )
    task_outcome_test_review(
      root,
      continued,
      "native-wire-assessment",
      @bookkeeper.Accept,
    )
    let (status, reviewed) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(status, 200)
    assert_eq(
      lesson_handoff_text(task_outcome_test_entry(reviewed), "state"),
      "reviewed_source_available",
    )
    let snapshot = replay_bookkeeper_store(root)
    assert_eq(snapshot.reviews.length(), 2)
    assert_eq(snapshot.records.length(), 3)
    assert_false(
      snapshot.records.any(record => record.stage == CapabilityProposal),
    )
    let wire : Json = {
      "fixture": "synthetic exact Proj producer bytes plus current native outcome handlers",
      "handoff": handoff.to_json(),
      "submission": submission.to_json(),
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
    @fs.write_file(
      output,
      wire.stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
  }
}

///|
async test "outcome review readback and exact retries survive a fresh process" {
  if @env.get_env_var("MOONBOOK_OUTCOME_RESTART_WIRE") is Some(path) {
    let wire = @json.parse(@fs.read_file(path).text())
    let root = lesson_handoff_text(wire, "journal_root")
    let expected : BookkeeperStoreSnapshot = @json.from_json(
      lesson_handoff_field(wire, "snapshot"),
    )
    assert_eq(replay_bookkeeper_store(root), expected)
    let handoff : OutcomeLessonTaskHandoff = @json.from_json(
      lesson_handoff_field(wire, "handoff"),
    )
    let (status, readback) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(status, 200)
    assert_eq(readback, lesson_handoff_field(wire, "reviewed"))
    for
      (operation, request_key) in [
        ("outcome-import", "import_request"),
        ("outcome-continue", "continue_request"),
      ] {
      let (status, response) = outcome_lesson_request(
        root,
        "/api/bookkeeper/lessons/" + operation,
        @json.parse(lesson_handoff_field(wire, request_key).stringify()),
      )
      assert_eq(status, 200)
      assert_eq(
        lesson_handoff_field(response, "result"),
        lesson_handoff_field(readback, "result"),
      )
      assert_eq(replay_bookkeeper_store(root), expected)
    }
  }
}

///|
async test "actual UI serialized outcome requests advance the native handler from an empty Book" {
  if @env.get_env_var("MOONBOOK_OUTCOME_UI_REQUESTS") is Some(request_path) &&
    @env.get_env_var("MOONBOOK_OUTCOME_RESTART_WIRE") is Some(wire_path) {
    let requests = @json.parse(@fs.read_file(request_path).text())
    let wire = @json.parse(@fs.read_file(wire_path).text())
    let root = @fs.tmpdir(prefix="book-outcome-ui-native-roundtrip-")
    let (status, imported) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/outcome-import",
      lesson_handoff_field(requests, "import_request"),
    )
    assert_eq(status, 200, msg=imported.stringify())
    assert_eq(imported, lesson_handoff_field(wire, "imported"))
    assert_true(replay_bookkeeper_store(root).reviews.is_empty())
    task_outcome_test_review(
      root,
      imported,
      "native-wire-deliverable",
      @bookkeeper.Accept,
    )
    let (status, continued) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/outcome-continue",
      lesson_handoff_field(requests, "continue_request"),
    )
    assert_eq(status, 200, msg=continued.stringify())
    assert_eq(continued, lesson_handoff_field(wire, "continued"))
    task_outcome_test_review(
      root,
      continued,
      "native-wire-assessment",
      @bookkeeper.Accept,
    )
    let handoff = lesson_handoff_field(
      lesson_handoff_field(requests, "import_request"),
      "handoff",
    )
    let (status, reviewed) = outcome_lesson_request(
      root, "/api/bookkeeper/lessons/task-handoff", handoff,
    )
    assert_eq(status, 200)
    assert_eq(reviewed, lesson_handoff_field(wire, "reviewed"))
    assert_eq(
      replay_bookkeeper_store(root).to_json(),
      lesson_handoff_field(wire, "snapshot"),
    )
    println(
      "UI_OUTCOME_NATIVE_ROUNDTRIP=passed; imported exact UI request into empty Book, separately reviewed and continued, retained exact serialized response and journal",
    )
  }
}
