///|
async fn lesson_test_source(root : String) -> OutcomeLessonDraft {
  let submission = submission_fixture()
  let pending = submit_product_outcome(root, submission)
  let deliverable = find_record(
    replay_bookkeeper_store(root),
    pending.deliverable,
  ).unwrap()
  ignore(closure_test_accept(root, deliverable, "lesson-deliverable"))
  let closure = submit_product_outcome(root, submission).closure.unwrap()
  let assessment = find_record(
    replay_bookkeeper_store(root),
    closure.three_gap_assessment,
  ).unwrap()
  let review = closure_test_accept(root, assessment, "lesson-assessment")
  {
    contract_version: "moonbook.outcome-lesson.v1",
    lesson_id: "research-brief-lesson",
    lesson_version: "1",
    title: "Check source contradictions before comparing vendors",
    guidance: "Preserve the exact conflicting quotations and test the decisive claim before the next vendor comparison.\nDo not infer customer acceptance from internal review.",
    outcome: closure.outcome_binding,
    assessment: closure.three_gap_assessment,
    assessment_review: review.receipt,
    applicability: [
      { key: "customer_id", value: "customer-a", },
      { key: "decision_kind", value: "vendor-comparison", },
    ],
    invalidation: [{ key: "evidence_state", value: "superseded", }],
    recorded_at: 200,
  }
}

///|
fn lesson_test_query(
  conditions : Array[OutcomeLessonCondition],
) -> OutcomeLessonQuery {
  {
    contract_version: "moonbook.outcome-lesson-query.v1",
    target_task: submission_test_ref("moonproj/task-2"),
    conditions,
  }
}

///|
fn lesson_test_matches(result : Json) -> Array[Json] raise {
  guard result is { "matches": Array(values), .. } else {
    fail("missing matches")
  }
  values
}

///|
async test "reviewed lesson survives replay and retrieves original conditions and evidence" {
  let root = @fs.tmpdir(prefix="moonbook-reviewed-lesson-")
  let draft = lesson_test_source(root)
  let original = replay_bookkeeper_store(root)
  let prepared = prepare_outcome_lesson(root, draft)
  assert_true(prepared.accepted)
  assert_false(prepared.idempotent)
  assert_true(prepare_outcome_lesson(root, draft).idempotent)
  let query = lesson_test_query(draft.applicability)
  assert_eq(
    lesson_test_matches(retrieve_outcome_lessons(root, query)).length(),
    0,
  )
  let candidate = find_record(
    replay_bookkeeper_store(root),
    prepared.event.unwrap(),
  ).unwrap()
  let review = closure_test_accept(root, candidate, "lesson-accept")
  ignore(rebuild_bookkeeper_projection(root))
  let before = replay_bookkeeper_store(root)
  let result = retrieve_outcome_lessons(root, query)
  let matches = lesson_test_matches(result)
  assert_eq(matches.length(), 1)
  guard matches[0]
    is {
      "lesson": lesson,
      "review": actual_review,
      "outcome": outcome,
      "assessment_review": source_review,
      ..
    } else {
    fail("missing exact lesson chain")
  }
  assert_eq(lesson, candidate.to_json())
  assert_eq(actual_review, review.to_json())
  assert_eq(outcome, find_record(original, draft.outcome).unwrap().to_json())
  assert_eq(
    source_review,
    closure_find_review(original, draft.assessment_review).unwrap().to_json(),
  )
  assert_eq(retrieve_outcome_lessons(root, query), result)
  assert_eq(replay_bookkeeper_store(root), before)
  for record in original.records {
    assert_eq(find_record(before, record.record), Some(record))
  }
  assert_eq(outcome_lesson_draft(candidate), Some(draft))
}

///|
async test "reviewed lesson excludes wrong customer missing conditions and invalidation" {
  let root = @fs.tmpdir(prefix="moonbook-lesson-scope-")
  let draft = lesson_test_source(root)
  let prepared = prepare_outcome_lesson(root, draft)
  let candidate = find_record(
    replay_bookkeeper_store(root),
    prepared.event.unwrap(),
  ).unwrap()
  ignore(closure_test_accept(root, candidate, "lesson-scope"))
  for
    conditions in [
      [
        { key: "customer_id", value: "customer-b", },
        { key: "decision_kind", value: "vendor-comparison", },
      ],
      [{ key: "decision_kind", value: "vendor-comparison", }],
      [
        { key: "customer_id", value: "customer-a", },
        { key: "decision_kind", value: "different-decision", },
      ],
      draft.applicability + [{ key: "evidence_state", value: "superseded", }],
    ] {
    assert_eq(
      lesson_test_matches(
        retrieve_outcome_lessons(root, lesson_test_query(conditions)),
      ).length(),
      0,
    )
  }
  assert_eq(
    lesson_test_matches(
      retrieve_outcome_lessons(
        root,
        lesson_test_query(
          draft.applicability + [{ key: "project_id", value: "proj-2", }],
        ),
      ),
    ).length(),
    1,
  )
}

///|
async test "rejected lesson remains historical and a revised version needs its own review" {
  let root = @fs.tmpdir(prefix="moonbook-lesson-rejected-")
  let draft = lesson_test_source(root)
  let first = prepare_outcome_lesson(root, draft)
  let candidate = find_record(
    replay_bookkeeper_store(root),
    first.event.unwrap(),
  ).unwrap()
  ignore(
    closure_test_decide(root, candidate, "lesson-reject", @bookkeeper.Reject),
  )
  assert_true(prepare_outcome_lesson(root, draft).idempotent)
  assert_false(
    prepare_outcome_lesson(root, { ..draft, guidance: "Changed in place", }).accepted,
  )
  let revised = prepare_outcome_lesson(root, {
    ..draft,
    lesson_version: "2",
    guidance: "Narrow the lesson to the quoted contradictions only.",
  })
  assert_true(revised.accepted)
  let query = lesson_test_query(draft.applicability)
  assert_eq(
    lesson_test_matches(retrieve_outcome_lessons(root, query)).length(),
    0,
  )
  let second = find_record(
    replay_bookkeeper_store(root),
    revised.event.unwrap(),
  ).unwrap()
  ignore(closure_test_accept(root, second, "lesson-revision"))
  assert_eq(
    lesson_test_matches(retrieve_outcome_lessons(root, query)).length(),
    1,
  )
  let final_state = replay_bookkeeper_store(root)
  assert_eq(find_record(final_state, candidate.record), Some(candidate))
  assert_eq(
    product_outcome_exact_human_decision(
      final_state,
      candidate.record,
      DeliverableAcceptance,
    ).unwrap().disposition,
    @bookkeeper.Reject,
  )
}

///|
async test "lesson preparation rejects missing source and narrowed metadata cannot bypass record admission" {
  let root = @fs.tmpdir(prefix="moonbook-lesson-invalid-")
  let draft = lesson_test_source(root)
  let baseline = replay_bookkeeper_store(root)
  for
    invalid in [
      { ..draft, applicability: [], },
      {
        ..draft,
        applicability: [
          { key: "customer_id", value: "a", },
          { key: "customer_id", value: "b", },
        ],
      },
      { ..draft, outcome: submission_test_ref("missing"), },
      { ..draft, assessment_review: submission_test_ref("missing-review"), },
      { ..draft, recorded_at: 1, },
      { ..draft, invalidation: draft.applicability, },
    ] {
    assert_false(prepare_outcome_lesson(root, invalid).accepted)
  }
  let outcome = find_record(baseline, draft.outcome).unwrap()
  let record = outcome_lesson_record(draft, outcome)
  assert_false(
    persist_bookkeeper_record(root, { ..record, summary: "hidden change", }).accepted,
  )
  assert_eq(replay_bookkeeper_store(root), baseline)
}

///|
async test "ambiguous final lesson reviews never produce retrievable guidance" {
  let root = @fs.tmpdir(prefix="moonbook-lesson-ambiguous-")
  let draft = lesson_test_source(root)
  let prepared = prepare_outcome_lesson(root, draft)
  let record = find_record(
    replay_bookkeeper_store(root),
    prepared.event.unwrap(),
  ).unwrap()
  ignore(closure_test_accept(root, record, "lesson-first"))
  ignore(closure_test_decide(root, record, "lesson-second", @bookkeeper.Reject))
  try
    retrieve_outcome_lessons(root, lesson_test_query(draft.applicability))
  catch {
    error => assert_true(error.to_string().contains("ambiguous"))
  } noraise {
    _ => fail("ambiguous reviews cannot retrieve a lesson")
  }
}

///|
async test "existing host lesson routes persist review and return UI-shaped scoped retrieval" {
  let root = @fs.tmpdir(prefix="moonbook-lesson-routes-")
  let draft = lesson_test_source(root)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/prepare",
    draft.to_json(),
  )
  assert_eq(status, 200)
  guard response
    is {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "ok": true,
      "operation": "prepare",
      "result": { "accepted": true, "event": reference, .. },
      ..
    } else {
    fail("prepare response differs from UI contract")
  }
  let reference : @bookkeeper.VersionedRecordReference = @json.from_json(
    reference,
  )
  let original = replay_bookkeeper_store(root)
  let (retry_status, retry) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/prepare",
    draft.to_json(),
  )
  assert_eq(retry_status, 200)
  assert_true(retry is { "result": { "idempotent": true, .. }, .. })
  assert_eq(replay_bookkeeper_store(root), original)
  let candidate = find_record(original, reference).unwrap()
  ignore(closure_test_accept(root, candidate, "route-accept"))
  let (read_status, readback) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/retrieve",
    lesson_test_query(draft.applicability).to_json(),
  )
  assert_eq(read_status, 200)
  assert_true(
    readback
    is {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "operation": "retrieve",
      "ok": true,
      "result": {
        "matches": [
          {
            "lesson": { "record": _, .. },
            "review": { "reviewer": { "reviewer_id": _, .. }, .. },
            ..
          },
        ],
        ..
      },
      ..
    },
  )
  assert_eq(
    outcome_lesson_request(root, "/api/bookkeeper/lessons/prepare", {}).0,
    422,
  )
  assert_eq(outcome_lesson_request(root, "/unsupported", {}).0, 404)
}
