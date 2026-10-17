///|
fn case_csv_test_text() -> String {
  "kind,name,input,original,revised,required,forbidden\r\nuseful,Useful <&> 東京,Known task,Source: useful,Source: useful,Source:,invented\r\nadverse,Adverse,Uncertain task,invented,Source: uncertainty,\"Source:\nuncertainty\",invented\r\n"
}

///|
fn case_csv_test_step(
  model : Model,
  kind : String,
  value? : String = "",
) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      RevisionRehearsal(
        lesson_revision_rehearsal_action(
          model.outcome_lessons.history,
          kind,
          value~,
          request_id=model.outcome_lessons.request,
        ),
      ),
    ),
  )
}

///|
fn case_csv_test_preview() -> Model {
  let base = revision_rehearsal_test_step(
    history_test_change(history_test_model(), "revise"),
    "begin",
  )
  case_csv_test_step(
    case_csv_test_step(base, "csv_edit", value=case_csv_test_text()),
    "csv_preview",
  )
}

///|
test "CSV teaching set renders exact preview and imports through ordinary save for review" {
  let preview = case_csv_test_preview()
  let initial = preview.outcome_lessons
  let change = initial.history.change.unwrap()
  let intake = lesson_task_field(change.revision_rehearsal, "intake")
  assert_eq(lesson_task_text(intake, "text"), case_csv_test_text())
  assert_eq(
    lesson_task_field(lesson_task_field(intake, "preview"), "ready"),
    true.to_json(),
  )
  let before = lesson_task_field(change.revision_rehearsal, "cases")
  guard before is Array(cases) else { panic() }
  assert_eq(lesson_task_text(cases[0], "input"), "")
  let html = history_test_html(preview)
  for
    text in [
      "Import a CSV teaching-case set", "Preview exact CSV cases", "Import exact previewed cases",
      "fill completely empty same-kind slot", "Useful &lt;&amp;&gt; 東京", "Save revision for review",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("Useful <&>"))
  let imported = case_csv_test_step(preview, "csv_import")
  let draft = imported.outcome_lessons.history.change.unwrap().revision_rehearsal
  guard lesson_task_field(draft, "cases") is Array(cases) else { panic() }
  assert_eq(cases.length(), 2)
  assert_eq(lesson_task_text(cases[0], "input"), "Known task")
  assert_eq(lesson_task_text(cases[1], "required"), "Source:\nuncertainty")
  assert_eq(lesson_task_field(draft, "preview"), Json::null())
  assert_eq(
    imported.outcome_lessons.history.data.unwrap().current,
    initial.history.data.unwrap().current,
  )
  assert_eq(
    imported.outcome_lessons.history.data.unwrap().head,
    initial.history.data.unwrap().head,
  )
  assert_eq(
    imported.outcome_lessons.history.data.unwrap().accepted_reviews,
    initial.history.data.unwrap().accepted_reviews,
  )
  assert_eq(imported.outcome_lessons.fields, initial.fields)
  assert_eq(imported.outcome_lessons.handoff, initial.handoff)
  assert_eq(imported.outcome_lessons.comparison, initial.comparison)
  assert_false(imported.outcome_lessons.pending)
  let compared = revision_rehearsal_test_step(imported, "compare")
  let staged = revision_rehearsal_test_step(compared, "stage")
  let payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_text(payload, "contract_version"),
    "moonbook.outcome-lesson-revision.v1",
  )
  assert_true(lesson_task_text(payload, "reason").contains("Known task"))
  assert_true(
    lesson_task_text(payload, "reason").contains("\"model_executed\": false"),
  )
  let saving = snapshot_test_step(staged, OutcomeLesson(SubmitHistoryChange))
  assert_true(saving.outcome_lessons.pending)
  assert_eq(saving.outcome_lessons.history.pending_operation, "revise")
  assert_eq(
    lesson_history_payload(saving.outcome_lessons.history).unwrap(),
    payload,
  )
}

///|
test "CSV refresh generation invalidates preview and detached controls even after failed request" {
  let preview = case_csv_test_preview()
  let old_action = lesson_revision_rehearsal_action(
    preview.outcome_lessons.history,
    "csv_import",
    request_id=preview.outcome_lessons.request,
  )
  let loading = snapshot_test_step(preview, OutcomeLesson(RefreshHistory))
  assert_true(loading.outcome_lessons.pending)
  let before = loading.outcome_lessons.history.change.unwrap().revision_rehearsal
  assert_eq(
    case_csv_test_step(loading, "csv_import").outcome_lessons.history.change.unwrap().revision_rehearsal,
    before,
  )
  let finished = case_csv_test_failed_refresh(preview)
  let rejected = snapshot_test_step(
    finished,
    OutcomeLesson(RevisionRehearsal(old_action)),
  )
  assert_eq(
    rejected.outcome_lessons.history.change.unwrap().revision_rehearsal,
    before,
  )
  assert_eq(
    case_csv_test_step(finished, "csv_import").outcome_lessons.history.change.unwrap().revision_rehearsal,
    before,
  )
  let fresh = case_csv_test_step(finished, "csv_preview")
  let imported = case_csv_test_step(fresh, "csv_import")
  assert_true(
    imported.outcome_lessons.history.change.unwrap().revision_rehearsal !=
    before,
  )
}

///|
test "CSV errors and oversize edit preserve draft and block old preview then recover" {
  let preview = case_csv_test_preview()
  let before = preview.outcome_lessons.history.change.unwrap().revision_rehearsal
  let invalid = case_csv_test_step(
    preview,
    "csv_edit",
    value="kind,name\nuseful,broken",
  )
  let checked = case_csv_test_step(invalid, "csv_preview")
  assert_true(history_test_html(checked).contains("Header must be exactly"))
  let failed = case_csv_test_step(checked, "csv_import")
  assert_eq(
    lesson_task_field(
      failed.outcome_lessons.history.change.unwrap().revision_rehearsal,
      "cases",
    ),
    lesson_task_field(before, "cases"),
  )
  let oversized = case_csv_test_step(
    preview,
    "csv_edit",
    value="x".repeat(131073),
  )
  let draft = oversized.outcome_lessons.history.change.unwrap().revision_rehearsal
  assert_eq(
    lesson_task_field(lesson_task_field(draft, "intake"), "preview"),
    Json::null(),
  )
  assert_eq(
    lesson_task_text(lesson_task_field(draft, "intake"), "text"),
    case_csv_test_text(),
  )
  assert_true(
    history_test_html(oversized).contains("Previous CSV text is kept"),
  )
  assert_eq(
    case_csv_test_step(oversized, "csv_import").outcome_lessons.history.change.unwrap().revision_rehearsal,
    draft,
  )
  let fresh = case_csv_test_step(
    case_csv_test_step(oversized, "csv_edit", value=case_csv_test_text()),
    "csv_preview",
  )
  assert_true(
    case_csv_test_step(fresh, "csv_import").outcome_lessons.history.change.unwrap().revision_rehearsal !=
    draft,
  )
}

///|
fn case_csv_test_failed_refresh(model : Model) -> Model {
  let loading = snapshot_test_step(model, OutcomeLesson(RefreshHistory))
  let finished = lesson_history_finished(
    loading.outcome_lessons,
    loading.outcome_lessons.request,
    "history",
    Err("interrupted transport"),
  )
  { ..loading, outcome_lessons: finished, }
}
