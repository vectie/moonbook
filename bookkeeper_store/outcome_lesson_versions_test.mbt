///|
async test "public lesson history is an explicit empty read and missing selection is rejected" {
  let root = @fs.tmpdir(prefix="public-lesson-history-")
  assert_true(
    @bookkeeper_store.outcome_lesson_history(root, "lesson-family")
    is { "head": Null, "current": Null, "versions": [], "selections": [], .. },
  )
  let missing : @bookkeeper.VersionedRecordReference = {
    record_id: "absent",
    record_version: "1",
    record_digest: "sha256:" + "a".repeat(64),
  }
  let selection : @bookkeeper_store.OutcomeLessonSelection = {
    contract_version: "moonbook.outcome-lesson-selection.v1",
    selection_id: "selection-example",
    lesson_id: "lesson-family",
    target: missing,
    expected_head: None,
    accepted_reviews: [],
    reason: "Explicitly choose a previously accepted method",
    recorded_at: 1,
  }
  assert_false(
    @bookkeeper_store.prepare_outcome_lesson_selection(root, selection).accepted,
  )
  assert_true(
    @bookkeeper_store.replay_bookkeeper_store(root).records.is_empty(),
  )
}

///|
test "public version choice uses explicit nullable reference JSON" {
  let reference : @bookkeeper.VersionedRecordReference = {
    record_id: "review",
    record_version: "1",
    record_digest: "sha256:" + "a".repeat(64),
  }
  let selection : @bookkeeper_store.OutcomeLessonSelection = {
    contract_version: "moonbook.outcome-lesson-selection.v1",
    selection_id: "wire-choice",
    lesson_id: "family",
    target: reference,
    expected_head: Some(reference),
    accepted_reviews: [reference],
    reason: "Reviewed choice",
    recorded_at: 2,
  }
  assert_true(
    selection.to_json()
    is { "expected_head": { "record_id": "review", .. }, .. },
  )
  let decoded : @bookkeeper_store.OutcomeLessonSelection = @json.from_json(
    selection.to_json(),
  )
  assert_eq(decoded, selection)
  assert_true(
    { ..selection, expected_head: None, }.to_json()
    is { "expected_head": Null, .. },
  )
}
