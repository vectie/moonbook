///|
fn rehearsal_test_request(
  lesson : OutcomeLessonDraft,
) -> OutcomeLessonRehearsal {
  {
    contract_version: "moonbook.outcome-lesson-rehearsal.v1",
    lesson,
    example_input: "Compare the vendors and retain a contradictory quotation.",
    baseline_output: "Vendor A is best. Source: retained.",
    corrected_output: "Source: retained. Contradiction: the supplier reports a different capacity. Customer acceptance: not asserted.",
    required_text: [
      "Source:", "Contradiction:", "Customer acceptance: not asserted.",
    ],
  }
}

///|
async test "rehearsed correction follows named review next-task selection revision and rollback" {
  let root = @fs.tmpdir(prefix="moonbook-rehearsal-journey-")
  let draft = lesson_test_source(root)
  let rehearsal = rehearsal_test_request(draft)
  let before = replay_bookkeeper_store(root)
  let preview = evaluate_outcome_lesson_rehearsal(rehearsal)
  assert_true(
    preview
    is {
      "baseline_passed": 1,
      "corrected_passed": 3,
      "improved": true,
      "model_executed": false,
      "activation_authorized": false,
      ..
    },
  )
  assert_eq(replay_bookkeeper_store(root), before)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/prepare-rehearsal",
    rehearsal.to_json(),
  )
  assert_eq(status, 200, msg=response.stringify())
  let saved = prepare_outcome_lesson_rehearsal(root, rehearsal)
  assert_true(saved.accepted)
  assert_true(saved.idempotent)
  let record = find_record(replay_bookkeeper_store(root), saved.event.unwrap()).unwrap()
  assert_eq(outcome_lesson_rehearsal(record), Some(rehearsal))
  let handoff = guidance_test_handoff()
  let query = guidance_test_query(handoff, draft.applicability)
  let request = guidance_test_request(handoff, query, record.record)
  let (pending, _) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/guidance-select", request,
  )
  assert_eq(pending, 422)
  ignore(closure_test_accept(root, record, "rehearsal-human"))
  let selected = select_task_guidance(root, request)
  let exported = lesson_handoff_field(selected, "lesson")
  assert_eq(
    lesson_handoff_field(exported, "reference"),
    record.record.to_json(),
  )
  assert_eq(lesson_handoff_text(exported, "guidance"), draft.guidance)
  assert_false(selected.stringify().contains("baseline_output"))
  assert_false(selected.stringify().contains("corrected_output"))
  assert_false(selected.stringify().contains("required_text"))
  // Proj already captures this unchanged guidance-selection wire on native Start.
  // This fixture makes no claim of a model run or an external service being live.
  let revision = version_revision(root, draft, record, "2")
  let changed = version_record(
    root,
    prepare_outcome_lesson_revision(root, revision),
  )
  ignore(closure_test_accept(root, changed, "rehearsal-version-two"))
  let (stale, _) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/guidance-select", request,
  )
  assert_eq(stale, 422)
  let next = select_task_guidance(
    root,
    guidance_test_request(handoff, query, changed.record),
  )
  assert_eq(
    lesson_handoff_text(lesson_handoff_field(next, "lesson"), "guidance"),
    revision.lesson.guidance,
  )
  let rollback = version_selection(root, draft, record, "restore-rehearsed")
  let rollback_record = version_record(
    root,
    prepare_outcome_lesson_selection(root, rollback),
  )
  ignore(closure_test_accept(root, rollback_record, "rehearsal-rollback"))
  let restored = select_task_guidance(root, request)
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(restored, "lesson"), "reference"),
    record.record.to_json(),
  )
  assert_eq(lesson_handoff_text(restored, "currentness"), "current")
  let final_state = replay_bookkeeper_store(root)
  assert_true(final_state.replay_issues.is_empty())
  assert_eq(find_record(final_state, record.record), Some(record))
  for original in before.records {
    assert_eq(find_record(final_state, original.record), Some(original))
  }
}

///|
async test "rehearsal failed checks changed bytes forged pass and missing review fail closed" {
  let root = @fs.tmpdir(prefix="moonbook-rehearsal-rejection-")
  let draft = lesson_test_source(root)
  let rehearsal = rehearsal_test_request(draft)
  let before = replay_bookkeeper_store(root)
  for
    invalid in [
      { ..rehearsal, corrected_output: rehearsal.baseline_output, },
      { ..rehearsal, baseline_output: rehearsal.corrected_output, },
      { ..rehearsal, required_text: [], },
      { ..rehearsal, required_text: ["Source:", "Source:"], },
      { ..rehearsal, required_text: [" "], },
      { ..rehearsal, example_input: "", },
      { ..rehearsal, corrected_output: "x".repeat(16385), },
      {
        ..rehearsal,
        lesson: {
          ..draft,
          assessment_review: submission_test_ref("unreviewed"),
        },
      },
    ] {
    assert_false(prepare_outcome_lesson_rehearsal(root, invalid).accepted)
  }
  assert_eq(replay_bookkeeper_store(root), before)
  let expected = outcome_lesson_rehearsal_record(before, rehearsal)
  let forged_payload = guidance_test_set(expected.payload, "rehearsal_result", {
    "improved": true,
  })
  let forged = {
    ..expected,
    record: {
      ..expected.record,
      record_digest: bookkeeper_payload_digest(forged_payload),
    },
    payload: forged_payload,
  }
  // No record with this identity exists yet: rejection must validate the
  // complete server-computed trial, not merely detect an existing ID conflict.
  assert_false(persist_bookkeeper_record(root, forged).accepted)
  assert_eq(replay_bookkeeper_store(root), before)
  let saved = prepare_outcome_lesson_rehearsal(root, rehearsal)
  let record = find_record(replay_bookkeeper_store(root), saved.event.unwrap()).unwrap()
  assert_false(
    prepare_outcome_lesson_rehearsal(root, {
      ..rehearsal,
      example_input: "Changed input",
    }).accepted,
  )
  ignore(
    closure_test_decide(root, record, "rehearsal-reject", @bookkeeper.Reject),
  )
  assert_eq(
    lesson_test_matches(
      retrieve_outcome_lessons(root, lesson_test_query(draft.applicability)),
    ).length(),
    0,
  )
  let (status, _) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/prepare-rehearsal",
    {},
  )
  assert_eq(status, 422)
}
