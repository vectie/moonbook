///|
async fn saved_lesson_fixture(
  root : String,
  handoff : OutcomeLessonTaskHandoff,
  id? : String = "returned-lesson",
) -> (OutcomeLessonDraft, DurableBookkeeperRecord) {
  let closure = lesson_handoff_test_reviewed(root, handoff, id~)
  let snapshot = replay_bookkeeper_store(root)
  let review = product_outcome_exact_human_decision(
    snapshot,
    closure.three_gap_assessment,
    ThreeGapFinding,
  ).unwrap()
  let draft : OutcomeLessonDraft = {
    contract_version: "moonbook.outcome-lesson.v1",
    lesson_id: id,
    lesson_version: "1",
    title: "Saved lesson <&> 中文",
    guidance: "PRIVATE GUIDANCE stays in Book",
    outcome: closure.outcome_binding,
    assessment: closure.three_gap_assessment,
    assessment_review: review.receipt,
    applicability: [{ key: "project_id", value: "PRIVATE SCOPE", }],
    invalidation: [],
    recorded_at: 200,
  }
  let record = version_record(root, prepare_outcome_lesson(root, draft))
  (draft, record)
}

///|
fn saved_lesson_entries(readback : Json) -> Array[Json] raise {
  guard lesson_handoff_field(readback, "saved_lessons") is Array(entries) else {
    fail("missing saved lesson entries")
  }
  entries
}

///|
fn saved_lesson_entry(
  entries : Array[Json],
  reference : @bookkeeper.VersionedRecordReference,
) -> Json raise {
  let matches = entries.filter(entry => {
    lesson_handoff_field(entry, "lesson") == reference.to_json()
  })
  assert_eq(matches.length(), 1)
  matches[0]
}

///|
async test "saved lesson readback distinguishes saved candidate retained rejected and deferred without writes" {
  for
    (decision, state) in [
      (@bookkeeper.Accept, "retained"),
      (@bookkeeper.Reject, "rejected"),
      (@bookkeeper.Revise, "pending"),
    ] {
    let root = @fs.tmpdir(prefix="book-saved-lesson-")
    let handoff = lesson_handoff_test_payload()
    let (_, record) = saved_lesson_fixture(root, handoff)
    let before = replay_bookkeeper_store(root)
    let pending = resolve_outcome_lesson_handoff(root, handoff)
    let entry = saved_lesson_entry(saved_lesson_entries(pending), record.record)
    assert_eq(lesson_handoff_text(entry, "state"), "pending")
    assert_true(lesson_handoff_field(entry, "review") is Null)
    assert_eq(replay_bookkeeper_store(root), before)
    let review = closure_test_decide(root, record, state, decision)
    let reviewed = replay_bookkeeper_store(root)
    let (status, response) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(status, 200)
    let result = lesson_handoff_field(response, "result")
    let entry = saved_lesson_entry(saved_lesson_entries(result), record.record)
    assert_eq(lesson_handoff_text(entry, "state"), state)
    assert_eq(lesson_handoff_field(entry, "task"), handoff.task.to_json())
    assert_eq(lesson_handoff_field(entry, "report"), handoff.report.to_json())
    assert_eq(
      lesson_handoff_text(entry, "currentness"),
      if state == "retained" {
        "current"
      } else {
        "not_retained"
      },
    )
    if decision == @bookkeeper.Revise {
      assert_true(lesson_handoff_field(entry, "review") is Null)
    } else {
      assert_eq(
        lesson_handoff_field(lesson_handoff_field(entry, "review"), "receipt"),
        review.receipt.to_json(),
      )
    }
    for
      private_text in [
        "PRIVATE GUIDANCE", "PRIVATE SCOPE", "authority://", "grant-",
      ] {
      assert_false(entry.stringify().contains(private_text))
    }
    assert_eq(replay_bookkeeper_store(root), reviewed)
    assert_eq(resolve_outcome_lesson_handoff(root, handoff), result)
  }
}

///|
async test "saved lesson receipt follows reviewed revision and rollback and preserves legacy current ambiguity" {
  let root = @fs.tmpdir(prefix="book-saved-lesson-history-")
  let handoff = lesson_handoff_test_payload()
  let (draft, original) = saved_lesson_fixture(root, handoff)
  ignore(closure_test_accept(root, original, "saved-original"))
  let revision = version_revision(root, draft, original, "2")
  let revised = version_record(
    root,
    prepare_outcome_lesson_revision(root, revision),
  )
  let entries = saved_lesson_entries(
    resolve_outcome_lesson_handoff(root, handoff),
  )
  assert_eq(
    lesson_handoff_text(
      saved_lesson_entry(entries, original.record),
      "currentness",
    ),
    "current",
  )
  assert_eq(
    lesson_handoff_text(saved_lesson_entry(entries, revised.record), "state"),
    "pending",
  )
  let accepted = closure_test_accept(root, revised, "saved-revision")
  let entries = saved_lesson_entries(
    resolve_outcome_lesson_handoff(root, handoff),
  )
  assert_eq(
    lesson_handoff_text(
      saved_lesson_entry(entries, original.record),
      "currentness",
    ),
    "historical",
  )
  assert_eq(
    lesson_handoff_text(
      saved_lesson_entry(entries, revised.record),
      "currentness",
    ),
    "current",
  )
  assert_eq(
    lesson_handoff_field(
      saved_lesson_entry(entries, revised.record),
      "selection_review",
    ),
    accepted.receipt.to_json(),
  )
  let selection = version_selection(root, draft, original, "return-rollback")
  let proposal = version_record(
    root,
    prepare_outcome_lesson_selection(root, selection),
  )
  ignore(closure_test_accept(root, proposal, "saved-rollback"))
  let entries = saved_lesson_entries(
    resolve_outcome_lesson_handoff(root, handoff),
  )
  assert_eq(entries.length(), 2)
  assert_eq(
    lesson_handoff_text(
      saved_lesson_entry(entries, original.record),
      "currentness",
    ),
    "current",
  )
  assert_eq(
    lesson_handoff_text(
      saved_lesson_entry(entries, revised.record),
      "currentness",
    ),
    "historical",
  )

  let legacy_root = @fs.tmpdir(prefix="book-saved-legacy-")
  let (legacy_draft, first) = saved_lesson_fixture(legacy_root, handoff)
  ignore(closure_test_accept(legacy_root, first, "legacy-first"))
  let second = version_record(
    legacy_root,
    prepare_outcome_lesson(legacy_root, { ..legacy_draft, lesson_version: "2", }),
  )
  ignore(closure_test_accept(legacy_root, second, "legacy-second"))
  let entries = saved_lesson_entries(
    resolve_outcome_lesson_handoff(legacy_root, handoff),
  )
  assert_eq(entries.length(), 2)
  for entry in entries {
    assert_eq(lesson_handoff_text(entry, "state"), "retained")
    assert_eq(lesson_handoff_text(entry, "currentness"), "legacy_unselected")
    assert_true(lesson_handoff_field(entry, "current") is Null)
    assert_true(lesson_handoff_field(entry, "selection_review") is Null)
  }
}

///|
async test "saved lesson return rejects ambiguous reviews and cannot match another exact report" {
  let root = @fs.tmpdir(prefix="book-saved-exact-")
  let handoff = lesson_handoff_test_payload()
  let (_, record) = saved_lesson_fixture(root, handoff)
  ignore(closure_test_accept(root, record, "first-final"))
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
    saved_lesson_entries(resolve_outcome_lesson_handoff(root, changed)),
    [],
  )
  let other = @fs.tmpdir(prefix="book-saved-other-")
  assert_eq(
    saved_lesson_entries(resolve_outcome_lesson_handoff(other, handoff)),
    [],
  )
  ignore(closure_test_decide(root, record, "second-final", @bookkeeper.Reject))
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/task-handoff",
    handoff.to_json(),
  )
  assert_eq(status, 422)
  assert_true(lesson_handoff_field(response, "result") is Null)
}

///|
async test "actual Proj fixture produces saved lesson return receipt through native journal and handler" {
  if @env.get_env_var("MOONPROJ_LESSON_FIXTURE_OUTPUT") is Some(path) {
    let handoff : OutcomeLessonTaskHandoff = @json.from_json(
      @json.parse(@fs.read_file(path).text()),
    )
    let root = @fs.tmpdir(prefix="book-return-wire-")
    let (_, record) = saved_lesson_fixture(root, handoff)
    let (pending_status, pending) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(pending_status, 200)
    let accepted = closure_test_accept(root, record, "actual-return")
    let before = replay_bookkeeper_store(root)
    let (status, response) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(status, 200)
    let entry = saved_lesson_entries(lesson_handoff_field(response, "result"))[0]
    assert_eq(
      lesson_handoff_field(lesson_handoff_field(entry, "review"), "receipt"),
      accepted.receipt.to_json(),
    )
    assert_eq(replay_bookkeeper_store(root), before)
    @fs.write_file(
      path + ".saved-pending.json",
      pending.stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      path + ".saved-retained.json",
      response.stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      path + ".saved-journal-root.txt",
      root,
      create_mode=CreateOrTruncate,
    )
  }
}

///|
async test "saved lesson return is identical after a fresh process replays the journal" {
  if @env.get_env_var("MOONBOOK_RETURN_RESTART_ROOT") is Some(root) &&
    @env.get_env_var("MOONPROJ_LESSON_FIXTURE_OUTPUT") is Some(path) {
    let handoff : OutcomeLessonTaskHandoff = @json.from_json(
      @json.parse(@fs.read_file(path).text()),
    )
    let expected = @json.parse(
      @fs.read_file(path + ".saved-retained.json").text(),
    )
    let before = replay_bookkeeper_store(root)
    let (status, response) = outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/task-handoff",
      handoff.to_json(),
    )
    assert_eq(status, 200)
    assert_eq(response, expected)
    assert_eq(replay_bookkeeper_store(root), before)
  }
}
