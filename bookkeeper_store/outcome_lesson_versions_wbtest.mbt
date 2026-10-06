///|
async fn version_fixture() -> (
  String,
  OutcomeLessonDraft,
  DurableBookkeeperRecord,
) {
  let root = @fs.tmpdir(prefix="moonbook-versions-")
  let draft = lesson_test_source(root)
  let prepared = prepare_outcome_lesson(root, draft)
  assert_true(prepared.accepted)
  let record = find_record(
    replay_bookkeeper_store(root),
    prepared.event.unwrap(),
  ).unwrap()
  ignore(closure_test_accept(root, record, "version-original"))
  (root, draft, record)
}

///|
async fn version_revision(
  root : String,
  draft : OutcomeLessonDraft,
  previous : DurableBookkeeperRecord,
  version : String,
) -> OutcomeLessonRevision {
  let (head, _, accepted) = lesson_version_state(
    replay_bookkeeper_store(root),
    draft.lesson_id,
  )
  {
    contract_version: "moonbook.outcome-lesson-revision.v1",
    lesson: {
      ..draft,
      lesson_version: version,
      guidance: "Reviewed correction " + version,
      recorded_at: previous.recorded_at + 100,
    },
    supersedes: previous.record,
    expected_head: head,
    accepted_reviews: accepted,
    reason: "Observed repeat-task correction " + version,
  }
}

///|
async fn version_selection(
  root : String,
  draft : OutcomeLessonDraft,
  target : DurableBookkeeperRecord,
  id : String,
) -> OutcomeLessonSelection {
  let (head, _, accepted) = lesson_version_state(
    replay_bookkeeper_store(root),
    draft.lesson_id,
  )
  {
    contract_version: "moonbook.outcome-lesson-selection.v1",
    selection_id: id,
    lesson_id: draft.lesson_id,
    target: target.record,
    expected_head: head,
    accepted_reviews: accepted,
    reason: "Restore the original reviewed method",
    recorded_at: 2000,
  }
}

///|
async fn version_record(
  root : String,
  result : BookkeeperMutationResult,
) -> DurableBookkeeperRecord {
  assert_true(result.accepted, msg=result.issues.join("; "))
  find_record(replay_bookkeeper_store(root), result.event.unwrap()).unwrap()
}

///|
async fn version_mutation(
  root : String,
  record : DurableBookkeeperRecord,
  id : String,
) -> GovernedReviewMutation {
  let evidence_ids = record.evidence_refs.map(item => item.reference_id)
  let grant = closure_test_ref("version-grant-" + id)
  ignore(
    install_bookkeeper_authority_grant(root, {
      contract_version: bookkeeper_store_contract_version(),
      grant,
      reviewer_id: "named-reviewer-" + id,
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "fixture-authority-" + id,
      evidence_refs: evidence_ids,
      active: true,
      granted_at: 0,
    }),
  )
  {
    contract_version: bookkeeper_store_contract_version(),
    mutation: closure_test_ref("version-mutation-" + id),
    receipt: closure_test_ref("version-review-" + id),
    stage: record.stage,
    subject: record.record,
    requested: @bookkeeper.Accept,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant,
      reviewer_id: "named-reviewer-" + id,
      authority_ref: "fixture-authority-" + id,
      authorized: true,
      evidence_refs: evidence_ids,
    },
    evidence_refs: record.evidence_refs,
    summary: "Synthetic named-human version decision",
    decided_at: record.recorded_at + 1,
  }
}

///|
async fn version_match_refs(
  root : String,
  draft : OutcomeLessonDraft,
) -> Array[Json] {
  lesson_test_matches(
    retrieve_outcome_lessons(root, lesson_test_query(draft.applicability)),
  ).map(value => {
    match value {
      { "lesson": { "record": reference, .. }, .. } => reference
      _ => ().to_json()
    }
  })
}

///|
async test "revision review selects exact guidance and rejected deferred revisions leave current unchanged" {
  let (root, draft, original) = version_fixture()
  let original_snapshot = replay_bookkeeper_store(root)
  let rejected = version_revision(root, draft, original, "2")
  let rejected_record = version_record(
    root,
    prepare_outcome_lesson_revision(root, rejected),
  )
  ignore(
    closure_test_decide(
      root,
      rejected_record,
      "version-reject",
      @bookkeeper.Reject,
    ),
  )
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  let revised = version_revision(root, draft, original, "3")
  let record = version_record(
    root,
    prepare_outcome_lesson_revision(root, revised),
  )
  assert_true(prepare_outcome_lesson_revision(root, revised).idempotent)
  ignore(closure_test_decide(root, record, "version-defer", @bookkeeper.Revise))
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  let mutation = version_mutation(root, record, "version-accept")
  let accepted = apply_governed_review(root, mutation)
  assert_true(accepted.accepted)
  assert_true(apply_governed_review(root, mutation).idempotent)
  assert_eq(version_match_refs(root, draft), [record.record.to_json()])
  let snapshot = replay_bookkeeper_store(root)
  assert_true(snapshot.replay_issues.is_empty())
  for old in original_snapshot.records {
    assert_eq(find_record(snapshot, old.record), Some(old))
  }
  for old in original_snapshot.reviews {
    assert_true(snapshot.reviews.contains(old))
  }
  let history = outcome_lesson_history(root, draft.lesson_id)
  assert_true(history is { "versions": [_, _, _], "selections": [], .. })
  assert_false(
    prepare_outcome_lesson_revision(root, {
      ..revised,
      reason: "overwrite same identity",
    }).accepted,
  )
}

///|
async test "reviewed rollback restores original context with every version decision retained across replay" {
  let (root, draft, original) = version_fixture()
  let revised = version_revision(root, draft, original, "2")
  let record = version_record(
    root,
    prepare_outcome_lesson_revision(root, revised),
  )
  let revision_mutation = version_mutation(root, record, "rollback-revision")
  assert_true(apply_governed_review(root, revision_mutation).accepted)
  let selection = version_selection(root, draft, original, "rollback-one")
  let choice = version_record(
    root,
    prepare_outcome_lesson_selection(root, selection),
  )
  assert_eq(version_match_refs(root, draft), [record.record.to_json()])
  let mutation = version_mutation(root, choice, "rollback-one")
  assert_true(apply_governed_review(root, mutation).accepted)
  assert_true(prepare_outcome_lesson_selection(root, selection).idempotent)
  assert_true(apply_governed_review(root, mutation).idempotent)
  assert_true(apply_governed_review(root, revision_mutation).idempotent)
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  let history = outcome_lesson_history(root, draft.lesson_id)
  assert_true(history is { "versions": [_, _], "selections": [_], .. })
  let before = replay_bookkeeper_store(root)
  // Projection loss does not remove journal history or change current guidance.
  @fs.write_file(
    bookkeeper_snapshot_path(root),
    "{}",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    bookkeeper_ui_state_path(root),
    "{}",
    create_mode=CreateOrTruncate,
  )
  ignore(rebuild_bookkeeper_projection(root))
  assert_eq(replay_bookkeeper_store(root), before)
  assert_eq(outcome_lesson_history(root, draft.lesson_id), history)
  assert_true(
    lesson_test_matches(
      retrieve_outcome_lessons(
        root,
        lesson_test_query([{ key: "customer_id", value: "other", }]),
      ),
    ).is_empty(),
  )
  assert_true(
    lesson_test_matches(
      retrieve_outcome_lessons(
        root,
        lesson_test_query(draft.applicability + draft.invalidation),
      ),
    ).is_empty(),
  )
  @fs.write_file(
    root + "/expected-history.json",
    history.stringify(),
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/query.json",
    lesson_test_query(draft.applicability).to_json().stringify(),
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/expected-retrieval.json",
    retrieve_outcome_lessons(root, lesson_test_query(draft.applicability)).stringify(),
    create_mode=CreateNew,
  )
  println("LESSON_VERSION_RESTART_FIXTURE=" + root)
}

///|
async test "legacy accepted versions stay retrievable until an explicit reviewed choice" {
  let (root, draft, original) = version_fixture()
  let second = version_record(
    root,
    prepare_outcome_lesson(root, {
      ..draft,
      lesson_version: "10",
      guidance: "Independent legacy version",
    }),
  )
  ignore(closure_test_accept(root, second, "legacy-ten"))
  assert_eq(version_match_refs(root, draft), [
    original.record.to_json(),
    second.record.to_json(),
  ])
  assert_true(
    outcome_lesson_history(root, draft.lesson_id)
    is { "head": Null, "current": Null, "versions": [_, _], .. },
  )
  let choice = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "choose-legacy"),
    ),
  )
  ignore(closure_test_accept(root, choice, "choose-legacy"))
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  assert_true(
    outcome_lesson_history(root, draft.lesson_id) is { "versions": [_, _], .. },
  )
}

///|
async test "stale and concurrent revision acceptances produce only one current head" {
  let (root, draft, original) = version_fixture()
  let mutations : Array[GovernedReviewMutation] = []
  for i in 2..<8 {
    let revision = version_revision(root, draft, original, i.to_string())
    let record = version_record(
      root,
      prepare_outcome_lesson_revision(root, revision),
    )
    mutations.push(
      version_mutation(root, record, "concurrent-" + i.to_string()),
    )
  }
  let results : Array[BookkeeperMutationResult] = []
  @async.with_task_group(group => {
    for mutation in mutations {
      group.spawn_bg(() => results.push(apply_governed_review(root, mutation)))
    }
  })
  assert_eq(results.filter(result => result.accepted).length(), 1)
  assert_eq(results.filter(result => !result.accepted).length(), 5)
  assert_eq(version_match_refs(root, draft).length(), 1)
  assert_true(replay_bookkeeper_store(root).replay_issues.is_empty())
}

///|
async test "ABA rollback and changed accepted legacy history reject stale choices" {
  let (root, draft, original) = version_fixture()
  let second = version_record(
    root,
    prepare_outcome_lesson_revision(
      root,
      version_revision(root, draft, original, "2"),
    ),
  )
  ignore(closure_test_accept(root, second, "aba-two"))
  let stale = version_record(
    root,
    prepare_outcome_lesson_revision(
      root,
      version_revision(root, draft, second, "3"),
    ),
  )
  let stale_mutation = version_mutation(root, stale, "aba-stale")
  for (target, id) in [(original, "aba-back"), (second, "aba-forward")] {
    let choice = version_record(
      root,
      prepare_outcome_lesson_selection(
        root,
        version_selection(root, draft, target, id),
      ),
    )
    ignore(closure_test_accept(root, choice, id))
  }
  assert_eq(version_match_refs(root, draft), [second.record.to_json()])
  assert_false(apply_governed_review(root, stale_mutation).accepted)
  let choice = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "late-legacy"),
    ),
  )
  let choice_mutation = version_mutation(root, choice, "late-legacy")
  let legacy = version_record(
    root,
    prepare_outcome_lesson(root, {
      ..draft,
      lesson_version: "legacy-late",
      guidance: "Another independent accepted artifact",
    }),
  )
  ignore(closure_test_accept(root, legacy, "late-legacy-accept"))
  assert_false(apply_governed_review(root, choice_mutation).accepted)
  assert_eq(version_match_refs(root, draft), [second.record.to_json()])
}

///|
async test "version choices reject wrong family source digests and unaccepted targets" {
  let (root, draft, original) = version_fixture()
  let selection = version_selection(root, draft, original, "bad-target")
  for
    invalid in [
      { ..selection, lesson_id: "foreign-family", },
      {
        ..selection,
        target: {
          ..original.record,
          record_digest: "sha256:" + "f".repeat(64),
        },
      },
      {
        ..selection,
        target: { ..original.record, record_version: "missing", },
      },
      { ..selection, accepted_reviews: [], },
      { ..selection, expected_head: Some(closure_test_ref("not-the-head")), },
      { ..selection, reason: "", },
    ] {
    assert_false(prepare_outcome_lesson_selection(root, invalid).accepted)
  }
  let pending = version_record(
    root,
    prepare_outcome_lesson(root, { ..draft, lesson_version: "pending", }),
  )
  assert_false(
    prepare_outcome_lesson_selection(root, {
      ..selection,
      target: pending.record,
    }).accepted,
  )
  let revised = version_revision(root, draft, original, "2")
  assert_false(
    prepare_outcome_lesson_revision(root, {
      ..revised,
      lesson: {
        ..revised.lesson,
        assessment_review: closure_test_ref("other-review"),
      },
    }).accepted,
  )
  assert_false(
    prepare_outcome_lesson_revision(root, {
      ..revised,
      supersedes: pending.record,
    }).accepted,
  )
  assert_false(
    prepare_outcome_lesson_selection(
      @fs.tmpdir(prefix="foreign-lesson-root-"),
      selection,
    ).accepted,
  )
  let malformed : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "outcome_lesson.v2",
    "revision": revised.to_json(),
  }
  assert_false(
    persist_bookkeeper_record(root, {
      ..original,
      record: {
        record_id: "malformed-version",
        record_version: "1",
        record_digest: bookkeeper_payload_digest(malformed),
      },
      payload: malformed,
    }).accepted,
  )
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
}

///|
async test "version host routes preserve exact histories and never auto accept" {
  let (root, draft, original) = version_fixture()
  let revision = version_revision(root, draft, original, "2")
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/revise",
    revision.to_json(),
  )
  assert_eq(status, 200)
  assert_true(
    response
    is { "operation": "revise", "result": { "accepted": true, .. }, .. },
  )
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  let before = replay_bookkeeper_store(root)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/history",
    { "lesson_id": draft.lesson_id },
  )
  assert_eq(status, 200)
  assert_true(
    response
    is { "operation": "history", "result": { "versions": [_, _], .. }, .. },
  )
  assert_eq(replay_bookkeeper_store(root), before)
  let selection = version_selection(root, draft, original, "route-choice")
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/select",
      selection.to_json(),
    ).0,
    200,
  )
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  assert_eq(
    outcome_lesson_request(root, "/api/bookkeeper/lessons/history", {}).0,
    422,
  )
}

///|
async test "declined rollback keeps head and stale forged acceptance fails exact journal replay" {
  let (root, draft, original) = version_fixture()
  let second = version_record(
    root,
    prepare_outcome_lesson_revision(
      root,
      version_revision(root, draft, original, "2"),
    ),
  )
  ignore(closure_test_accept(root, second, "replay-two"))
  let declined = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "decline-rollback"),
    ),
  )
  ignore(
    closure_test_decide(root, declined, "decline-rollback", @bookkeeper.Reject),
  )
  assert_eq(version_match_refs(root, draft), [second.record.to_json()])
  let stale_draft = version_selection(root, draft, original, "stale-rollback")
  let stale = version_record(
    root,
    prepare_outcome_lesson_selection(root, stale_draft),
  )
  let stale_mutation = version_mutation(root, stale, "stale-rollback")
  let chosen = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "new-rollback"),
    ),
  )
  ignore(closure_test_accept(root, chosen, "new-rollback"))
  assert_false(
    prepare_outcome_lesson_selection(root, {
      ..stale_draft,
      selection_id: "stale-new-id",
    }).accepted,
  )
  assert_false(apply_governed_review(root, stale_mutation).accepted)
  let before = replay_bookkeeper_store(root)
  let forged = review_receipt(before, stale_mutation)
  assert_true(forged.issues.is_empty())
  // Simulate an old or corrupt writer that bypasses current admission. Replay
  // must independently reject its stale accepted transition at that position.
  persist_event(root, {
    contract_version: bookkeeper_store_contract_version(),
    sequence: before.last_sequence + 1,
    event: forged.receipt,
    event_kind: "review",
    recorded_at: forged.decided_at,
    record: None,
    review: Some(forged),
    envelope: None,
  })
  assert_false(replay_bookkeeper_store(root).replay_issues.is_empty())
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/retrieve",
      lesson_test_query(draft.applicability).to_json(),
    ).0,
    422,
  )
}

///|
async test "current version applies its own reviewed context and rollback restores only original scope" {
  let (root, draft, original) = version_fixture()
  let change = version_revision(root, draft, original, "customer-b")
  let new_conditions : Array[OutcomeLessonCondition] = [
    { key: "customer_id", value: "customer-b", },
    { key: "decision_kind", value: "vendor-comparison", },
  ]
  let revised = {
    ..change,
    lesson: { ..change.lesson, applicability: new_conditions, },
  }
  let record = version_record(
    root,
    prepare_outcome_lesson_revision(root, revised),
  )
  ignore(closure_test_accept(root, record, "scope-revision"))
  assert_true(version_match_refs(root, draft).is_empty())
  assert_eq(version_match_refs(root, revised.lesson), [record.record.to_json()])
  let rollback = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "scope-rollback"),
    ),
  )
  ignore(closure_test_accept(root, rollback, "scope-rollback"))
  assert_eq(version_match_refs(root, draft), [original.record.to_json()])
  assert_true(version_match_refs(root, revised.lesson).is_empty())
}
