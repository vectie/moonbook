///|
fn repair_test_step(
  model : Model,
  action : String,
  key? : String = "",
  value? : String = "",
) -> Model {
  snapshot_test_step(model, OutcomeLesson(Repair(action, key, value)))
}

///|
fn repair_test_ready() -> Model {
  let base = history_test_model()
  let current = base.outcome_lessons.history.data.unwrap().current.unwrap()
  let base = snapshot_test_step(
    base,
    OutcomeLesson(ChooseHistoryVersion(current)),
  )
  let base = repair_test_step(base, "begin")
  let lesson = lesson_task_field(
    lesson_repair_context(base.outcome_lessons),
    "lesson",
  )
  let scope = lesson_condition_edit_text(
    lesson_task_field(lesson, "applicability"),
  )
  let mut model = base
  for
    (key, value) in [
      ("task-id", "later-task"),
      ("task-version", "4"),
      ("task-digest", "exact-task"),
      ("observation", "Later task failed <&> 東京"),
      ("evidence", "retained://failure"),
      ("conditions", scope + "\ndeadline=short"),
      ("exclude-key", "deadline"),
      ("exclude-value", "short"),
      ("version", "3"),
    ] {
    model = repair_test_step(model, "edit", key~, value~)
  }
  model
}

///|
test "repair stages exact narrower version with existing review payload" {
  let ready = repair_test_ready()
  let original = lesson_history_selected_accepted(ready.outcome_lessons.history).unwrap()
  let preview = repair_test_step(ready, "preview")
  assert_true(
    lesson_task_field(preview.outcome_lessons.repair, "preview") != Json::null(),
  )
  let staged = repair_test_step(preview, "stage")
  let payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_field(payload, "supersedes"),
    ToJson::to_json(original.record),
  )
  assert_eq(
    lesson_task_text(lesson_task_field(payload, "lesson"), "guidance"),
    lesson_task_text(lesson_record_value(original).unwrap(), "guidance"),
  )
  assert_true(
    lesson_task_text(payload, "reason").contains("factual_review_complete"),
  )
  assert_true(
    lesson_change_field(
      staged.outcome_lessons.history.change.unwrap(),
      "invalidation",
    ).contains("deadline=short"),
  )
  assert_eq(staged.outcome_lessons.repair, Json::null())
  assert_eq(
    staged.outcome_lessons.history.data.unwrap().current,
    ready.outcome_lessons.history.data.unwrap().current,
  )
  assert_true(staged.outcome_lessons.history.result is None)
}

///|
test "repair requires preview and edited case invalidates preview" {
  let ready = repair_test_ready()
  assert_true(
    repair_test_step(ready, "stage").outcome_lessons.history.change is None,
  )
  let preview = repair_test_step(ready, "preview")
  let edited = repair_test_step(
    preview,
    "edit",
    key="observation",
    value="Another observation",
  )
  assert_eq(
    lesson_task_field(edited.outcome_lessons.repair, "preview"),
    Json::null(),
  )
  assert_true(
    repair_test_step(edited, "stage").outcome_lessons.history.change is None,
  )
}

///|
test "history refresh or version switch blocks stale repair and preserves report" {
  let ready = repair_test_step(repair_test_ready(), "preview")
  let changed = {
    ..ready,
    outcome_lessons: {
      ..ready.outcome_lessons,
      request: ready.outcome_lessons.request + 1,
    },
  }
  let result = repair_test_step(changed, "stage")
  assert_true(result.outcome_lessons.history.change is None)
  assert_eq(result.outcome_lessons.repair, ready.outcome_lessons.repair)
  assert_true(result.outcome_lessons.notice.contains("changed"))
}

///|
test "repair cannot overwrite another change or begin from old accepted version" {
  let old = history_test_model()
  assert_eq(repair_test_step(old, "begin").outcome_lessons.repair, Json::null())
  let changed = history_test_change(old, "revise")
  assert_eq(
    repair_test_step(changed, "begin").outcome_lessons.repair,
    Json::null(),
  )
  let ready = repair_test_ready()
  let pending = {
    ..ready,
    outcome_lessons: { ..ready.outcome_lessons, pending: true, },
  }
  assert_eq(
    repair_test_step(pending, "discard").outcome_lessons.repair,
    ready.outcome_lessons.repair,
  )
  assert_eq(
    repair_test_step(ready, "discard").outcome_lessons.repair,
    Json::null(),
  )
}

///|
test "repair view is connected to history and escapes reported text" {
  let ready = repair_test_ready()
  let html = history_test_html(ready)
  assert_true(html.contains("Start failure case for current lesson"))
  assert_true(html.contains("Preview narrower scope"))
  assert_true(html.contains("&lt;&amp;&gt;"))
}
