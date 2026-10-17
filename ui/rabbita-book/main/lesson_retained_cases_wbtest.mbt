///|
fn retained_case_test_model() -> Model {
  let base = history_test_model()
  let history = base.outcome_lessons.history
  let data = history.data.unwrap()
  let current = data.versions[1].lesson
  let lesson = lesson_record_value(current).unwrap()
  let record = {
    ..current,
    payload: {
      "candidate_schema": "outcome_lesson.rehearsed.v1",
      "outcome_lesson": lesson,
      "rehearsal": {
        "contract_version": "moonbook.outcome-lesson-rehearsal.v1",
        "lesson": lesson,
        "example_input": "Retained <&> 東京\n task ",
        "baseline_output": "unsupported",
        "corrected_output": "  Source: known 東京\n exact  ",
        "required_text": ["Source:", "known"],
      },
    },
  }
  let versions = data.versions.map(version => {
    if version.lesson.record == record.record {
      { ..version, lesson: record, }
    } else {
      version
    }
  })
  let store = base.bookkeeper_store.unwrap()
  let model = {
    ..base,
    bookkeeper_store: Some({
      ..store,
      records: store.records.map(value => {
        if value.record == record.record {
          record
        } else {
          value
        }
      }),
    }),
    outcome_lessons: {
      ..base.outcome_lessons,
      history: { ..history, data: Some({ ..data, versions, }), },
    },
  }
  history_test_change(model, "revise")
}

///|
fn retained_case_test_ready() -> Model {
  let base = retained_case_test_model()
  let mut model = revision_rehearsal_test_step(
    base,
    "reuse",
    case_id="retained-1",
  )
  model = revision_rehearsal_test_step(
    model,
    "edit",
    field="revised",
    value="Source: known new output",
    case_id="case-1",
  )
  for
    (field, value) in [
      ("name", "New adverse task"),
      ("input", "Another actual example"),
      ("original", "unsupported"),
      ("revised", "Source: uncertainty"),
      ("required", "Source:\nuncertainty"),
    ] {
    model = revision_rehearsal_test_step(
      model,
      "edit",
      field~,
      value~,
      case_id="case-2",
    )
  }
  model
}

///|
test "retained teaching example enters real revision controller with blank new output and immutable provenance" {
  let original = retained_case_test_model()
  let model = revision_rehearsal_test_step(
    original,
    "reuse",
    case_id="retained-1",
  )
  let state = model.outcome_lessons.history.change.unwrap().revision_rehearsal
  guard lesson_task_field(state, "cases") is Array(cases) else { panic() }
  assert_eq(cases.length(), 2)
  assert_eq(lesson_task_text(cases[0], "input"), "Retained <&> 東京\n task ")
  assert_eq(
    lesson_task_text(cases[0], "original"),
    "  Source: known 東京\n exact  ",
  )
  assert_eq(lesson_task_text(cases[0], "revised"), "")
  assert_eq(
    lesson_task_field(lesson_task_field(cases[0], "retained_from"), "lesson"),
    ToJson::to_json(
      original.outcome_lessons.history.change.unwrap().original.record,
    ),
  )
  assert_eq(
    model.outcome_lessons.history.data.unwrap().current,
    original.outcome_lessons.history.data.unwrap().current,
  )
  assert_eq(model.outcome_lessons.fields, original.outcome_lessons.fields)
  assert_eq(model.outcome_lessons.handoff, original.outcome_lessons.handoff)
  let changed = revision_rehearsal_test_step(
    model,
    "edit",
    field="original",
    value="forged",
    case_id="case-1",
  )
  assert_eq(
    changed.outcome_lessons.history.change.unwrap().revision_rehearsal,
    state,
  )
  assert_true(changed.outcome_lessons.history.notice.contains("read-only"))
  let html = history_test_html(model)
  assert_true(html.contains("Reuse this lesson"))
  assert_true(html.contains("Retained &lt;&amp;&gt; 東京"))
  assert_false(html.contains("Retained <&> 東京"))
  assert_true(html.contains("Fresh revised output is required"))
}

///|
test "retained examples compare and stage through existing immutable revision save dispatch" {
  let ready = retained_case_test_ready()
  let model = revision_rehearsal_test_step(
    revision_rehearsal_test_step(ready, "compare"),
    "stage",
  )
  let payload = lesson_history_payload(model.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_text(payload, "contract_version"),
    "moonbook.outcome-lesson-revision.v1",
  )
  let reason = lesson_task_text(payload, "reason")
  assert_true(reason.contains("retained_from"))
  assert_true(reason.contains("single_example"))
  assert_true(reason.contains("Source: known new output"))
  let saved = snapshot_test_step(model, OutcomeLesson(SubmitHistoryChange))
  assert_true(saved.outcome_lessons.pending)
  assert_eq(saved.outcome_lessons.history.pending_operation, "revise")
  assert_eq(
    lesson_history_payload(saved.outcome_lessons.history).unwrap(),
    payload,
  )
  assert_eq(
    model.outcome_lessons.history.data.unwrap().current,
    ready.outcome_lessons.history.data.unwrap().current,
  )
}
