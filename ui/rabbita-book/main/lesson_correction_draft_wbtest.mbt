///|
fn correction_test_step(model : Model, operation : String) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      CorrectionDraft(lesson_correction_draft_action(model, operation)),
    ),
  )
}

///|
fn correction_test_fresh(model : Model) -> Model {
  let closed = snapshot_test_step(model, OutcomeLesson(DiscardHistoryChange))
  let selected = snapshot_test_step(
    closed,
    OutcomeLesson(
      ChooseHistoryVersion(
        closed.outcome_lessons.history.data.unwrap().current.unwrap(),
      ),
    ),
  )
  snapshot_test_step(selected, OutcomeLesson(StartHistoryChange("revise")))
}

///|
test "correction save cold resume compare stage and ordinary review save remain connected" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let ready = revision_rehearsal_test_ready()
  let staged = revision_rehearsal_test_step(
    revision_rehearsal_test_step(ready, "compare"),
    "stage",
  )
  let saved = correction_test_step(staged, "save")
  assert_true(
    saved.outcome_lessons.history.notice.contains("saved on this browser"),
  )
  let before = saved.outcome_lessons.history.change.unwrap()
  let fresh = correction_test_fresh(history_test_model())
  let checked = correction_test_step(fresh, "read")
  let resumed = correction_test_step(checked, "resume")
  let change = resumed.outcome_lessons.history.change.unwrap()
  assert_eq(change.fields, before.fields)
  assert_true(change.selection_id != before.selection_id)
  assert_eq(
    lesson_task_field(change.revision_rehearsal, "preview"),
    Json::null(),
  )
  assert_eq(
    lesson_task_field(change.revision_rehearsal, "staged"),
    false.to_json(),
  )
  assert_true(lesson_history_payload(resumed.outcome_lessons.history) is Err(_))
  assert_eq(
    lesson_task_field(
      lesson_revision_rehearsal_transition(
        resumed.outcome_lessons.history,
        false,
        { "kind": "inspect" },
      ),
      "current",
    ),
    true.to_json(),
  )
  let restaged = revision_rehearsal_test_step(
    revision_rehearsal_test_step(resumed, "compare"),
    "stage",
  )
  let resumed_payload = lesson_history_payload(restaged.outcome_lessons.history).unwrap()
  let original_payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_text(resumed_payload, "reason"),
    lesson_task_text(original_payload, "reason"),
  )
  assert_eq(
    lesson_task_field(resumed_payload, "supersedes"),
    lesson_task_field(original_payload, "supersedes"),
  )
  assert_eq(
    lesson_task_text(lesson_task_field(resumed_payload, "lesson"), "guidance"),
    lesson_task_text(lesson_task_field(original_payload, "lesson"), "guidance"),
  )
  let pending = snapshot_test_step(restaged, OutcomeLesson(SubmitHistoryChange))
  assert_true(pending.outcome_lessons.pending)
  assert_eq(pending.outcome_lessons.history.pending_operation, "revise")
}

///|
test "correction recovery refuses detached callbacks and changes no current draft during pending request" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let model = revision_rehearsal_test_ready()
  let old = lesson_correction_draft_action(model, "save")
  let edited = revision_rehearsal_test_step(
    model,
    "edit",
    field="guidance",
    value="New correction",
  )
  let ignored = snapshot_test_step(edited, OutcomeLesson(CorrectionDraft(old)))
  assert_eq(draft_storage_fixture_contents(), "[]")
  assert_eq(
    ignored.outcome_lessons.history.change.unwrap().revision_rehearsal,
    edited.outcome_lessons.history.change.unwrap().revision_rehearsal,
  )
  let pending = snapshot_test_step(edited, OutcomeLesson(RefreshHistory))
  let blocked = correction_test_step(pending, "save")
  assert_true(blocked.outcome_lessons.pending)
  assert_eq(draft_storage_fixture_contents(), "[]")
}

///|
test "correction replace and remove are explicit and closing the change preserves its saved copy" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let saved = correction_test_step(revision_rehearsal_test_ready(), "save")
  let copy = draft_storage_fixture_contents()
  let fresh = correction_test_fresh(saved)
  assert_eq(draft_storage_fixture_contents(), copy)
  let checked = correction_test_step(fresh, "read")
  let resumed = correction_test_step(checked, "resume")
  let before = resumed.outcome_lessons.history.change.unwrap().revision_rehearsal
  let removed = correction_test_step(resumed, "forget")
  assert_eq(draft_storage_fixture_contents(), "[]")
  assert_eq(
    removed.outcome_lessons.history.change.unwrap().revision_rehearsal,
    before,
  )
  assert_eq(
    removed.outcome_lessons.history.data.unwrap().current,
    saved.outcome_lessons.history.data.unwrap().current,
  )
}

///|
test "fresh manual edits cannot be replaced and blocked storage does not claim success" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let saved = correction_test_step(revision_rehearsal_test_ready(), "save")
  let checked = correction_test_step(correction_test_fresh(saved), "read")
  let edited = snapshot_test_step(
    checked,
    OutcomeLesson(EditHistory("title", "Keep this manual title")),
  )
  let resumed = correction_test_step(edited, "resume")
  assert_true(
    resumed.outcome_lessons.history.notice.contains(
      "current edits were not replaced",
    ),
  )
  assert_eq(
    lesson_change_field(
      resumed.outcome_lessons.history.change.unwrap(),
      "title",
    ),
    "Keep this manual title",
  )
  draft_storage_fixture_block(true)
  let blocked = correction_test_step(saved, "save")
  assert_true(
    blocked.outcome_lessons.history.notice.contains("Browser correction"),
  )
  assert_false(
    blocked.outcome_lessons.history.notice.contains("saved on this browser"),
  )
}

///|
test "correction UI exposes fresh resume checked replacement and local data removal" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let saved = correction_test_step(revision_rehearsal_test_ready(), "save")
  let ready_html = history_test_html(saved)
  assert_true(ready_html.contains("Replace checked browser copy"))
  assert_true(ready_html.contains("Remove checked browser copy"))
  assert_true(ready_html.contains("shared-device copy"))
  let checked = correction_test_step(correction_test_fresh(saved), "read")
  let html = history_test_html(checked)
  assert_true(html.contains("Resume saved correction into this fresh revision"))
  assert_true(html.contains("supplied cases"))
}
