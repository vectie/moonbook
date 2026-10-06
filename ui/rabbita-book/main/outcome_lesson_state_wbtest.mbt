///|
fn lesson_workspace_fixture() -> OutcomeLessonWorkspace {
  let source = draft_test_record("assessment").record.to_json()
  let initial = initial_outcome_lesson_workspace()
  let prepared = {
    ..initial,
    source: Some({
      "outcome": source,
      "assessment": source,
      "assessment_review": source,
    }),
    source_label: "Assessment fixture",
    lesson_id: "one-stable-id",
    recorded_at: 200,
  }
  let title = lesson_ui_edit(prepared, "title", "Compare the source evidence")
  let guidance = lesson_ui_edit(
    title, "guidance", "  Exact authored guidance <&> 中文\nSecond line  ",
  )
  let customer = lesson_ui_edit(guidance, "customer", "customer-a")
  lesson_ui_edit(customer, "decision", "vendor-comparison")
}

///|
test "lesson form emits canonical source bindings and failure retry preserves every byte" {
  let state = lesson_workspace_fixture()
  let payload = lesson_ui_payload(state, "prepare").unwrap()
  assert_true(
    payload
    is {
      "contract_version": "moonbook.outcome-lesson.v1",
      "lesson_id": "one-stable-id",
      "guidance": "  Exact authored guidance <&> 中文\nSecond line  ",
      "applicability": [_, _],
      ..
    },
  )
  let pending = { ..state, request: 20, pending: true, }
  let failed = lesson_ui_finished(
    pending,
    20,
    "prepare",
    Err("connection interrupted"),
  )
  assert_eq(lesson_ui_payload(failed, "prepare").unwrap(), payload)
  assert_false(failed.pending)
  assert_true(failed.notice.contains("Your draft is still here"))
  let ignored_edit = lesson_ui_edit(pending, "guidance", "changed while saving")
  assert_eq(
    lesson_field(ignored_edit, "guidance"),
    lesson_field(state, "guidance"),
  )
}

///|
test "new task context clears prior results and ignores stale completion" {
  let state = lesson_workspace_fixture()
  let task = lesson_ui_edit(state, "task-id", "task-2")
  let task = lesson_ui_edit(task, "task-digest", "sha256:" + "a".repeat(64))
  let task = lesson_ui_edit(task, "query-customer", "customer-a")
  let task = lesson_ui_edit(task, "query-decision", "vendor-comparison")
  let pending = { ..task, request: 50, pending: true, }
  let result : Json = {
    "contract_version": "moonbook.outcome-lesson-retrieval.v1",
    "matches": [],
    "exclusions": [],
  }
  let completed = lesson_ui_finished(pending, 50, "retrieve", Ok(result))
  let newer = lesson_ui_edit(completed, "task-id", "task-3")
  assert_true(newer.result is None)
  let stale = lesson_ui_finished(newer, 50, "retrieve", Ok(result))
  assert_true(stale.result is None)
  assert_eq(lesson_field(stale, "task-id"), "task-3")
  assert_true(
    lesson_ui_payload(stale, "retrieve").unwrap()
    is { "target_task": { "record_id": "task-3", .. }, .. },
  )
  assert_eq(lesson_field(stale, "guidance"), lesson_field(state, "guidance"))
}

///|
test "lesson submission double click and ordinary record changes preserve author context" {
  let model = {
    ..draft_test_model(),
    outcome_lessons: lesson_workspace_fixture(),
  }
  let saving = snapshot_test_step(model, OutcomeLesson(Submit("prepare")))
  assert_true(saving.outcome_lessons.pending)
  let again = snapshot_test_step(saving, OutcomeLesson(Submit("prepare")))
  assert_eq(again.outcome_lessons.request, saving.outcome_lessons.request)
  assert_eq(again.outcome_lessons.lesson_id, saving.outcome_lessons.lesson_id)
  let selected = snapshot_test_step(
    model,
    SelectBookkeeperItem(draft_test_item("second")),
  )
  assert_eq(selected.outcome_lessons.source, model.outcome_lessons.source)
  assert_eq(selected.outcome_lessons.fields, model.outcome_lessons.fields)
}

///|
test "lesson conditions require useful unique values and preserve equals inside values" {
  assert_true(
    lesson_ui_conditions("a", "comparison", "customer_id=b") is Err(_),
  )
  assert_true(lesson_ui_conditions("", "", "invalid line") is Err(_))
  assert_eq(lesson_ui_conditions("", "", "source=a=b").unwrap(), [
    { "key": "source", "value": "a=b" },
  ])
  assert_true(
    lesson_ui_payload(initial_outcome_lesson_workspace(), "prepare") is Err(_),
  )
}

///|
test "lesson workspace provides ordinary author retrieve controls and truthful empty results" {
  let state = {
    ..lesson_workspace_fixture(),
    result: Some({
      "contract_version": "moonbook.outcome-lesson-retrieval.v1",
      "matches": [],
      "exclusions": [],
    }),
  }
  let model = { ..draft_test_model(), outcome_lessons: state, }
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=outcome_lesson_workspace_view,
    ),
  )
  for
    label in [
      "Make and reuse a lesson", "What should we do next time?", "When to use this lesson",
      "Save lesson for review", "Find useful lessons", "No matching reviewed lessons",
      "Next task ID", "Exact authored guidance &lt;&amp;&gt; 中文",
    ] {
    assert_true(html.contains(label), msg=label)
  }
}

///|
test "lesson HTTP decode binds responses to exact task and refuses unconfirmed save" {
  let query : Json = { "target_task": "task-2", "conditions": [] }
  let result : Json = {
    "contract_version": "moonbook.outcome-lesson-retrieval.v1",
    "query": query,
    "matches": [],
    "exclusions": [],
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
  let wire : Json = {
    "schema": "moonbook.outcome-lesson-operation.v1",
    "ok": true,
    "operation": "retrieve",
    "result": result,
  }
  let response : BookkeeperBrowserResponse = {
    ok: true,
    status: 200,
    body: wire.stringify(),
    error: None,
  }
  assert_eq(
    decode_outcome_lesson_response("retrieve", query, response),
    Ok(result),
  )
  assert_true(
    decode_outcome_lesson_response(
      "retrieve",
      { "target_task": "task-3" },
      response,
    )
    is Err(_),
  )
  let unconfirmed : Json = {
    "schema": "moonbook.outcome-lesson-operation.v1",
    "ok": true,
    "operation": "prepare",
    "result": { "accepted": false },
  }
  assert_true(
    decode_outcome_lesson_response("prepare", {}, {
      ..response,
      body: unconfirmed.stringify(),
    })
    is Err(_),
  )
}

///|
test "using the same reviewed assessment twice preserves lesson identity and authored content" {
  let base = governed_test_model("ThreeGapFinding")
  let snapshot = base.bookkeeper_store.unwrap()
  let record = {
    ..snapshot.records[0],
    subject: Some(draft_test_record("outcome").record),
  }
  let model = {
    ..base,
    bookkeeper_store: Some({ ..snapshot, records: [record], }),
    outcome_lessons: lesson_ui_edit(
      initial_outcome_lesson_workspace(),
      "guidance",
      "My current draft",
    ),
  }
  let first = snapshot_test_step(model, OutcomeLesson(UseSelected))
  assert_false(first.outcome_lessons.lesson_id.is_empty())
  let second = snapshot_test_step(first, OutcomeLesson(UseSelected))
  assert_eq(second.outcome_lessons.lesson_id, first.outcome_lessons.lesson_id)
  assert_eq(
    second.outcome_lessons.recorded_at,
    first.outcome_lessons.recorded_at,
  )
  assert_eq(
    lesson_field(second.outcome_lessons, "guidance"),
    "My current draft",
  )
  let rejected = { ..snapshot.reviews[0], disposition: "Reject", }
  let rejected_model = {
    ..model,
    bookkeeper_store: Some({
      ..snapshot,
      records: [record],
      reviews: [rejected],
    }),
  }
  assert_true(lesson_selected_source(rejected_model) is Err(_))
}
