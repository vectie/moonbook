///|
fn revision_rehearsal_test_step(
  model : Model,
  kind : String,
  field? : String = "",
  value? : String = "",
  case_id? : String = "",
) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      RevisionRehearsal(
        lesson_revision_rehearsal_action(
          model.outcome_lessons.history,
          kind,
          field~,
          value~,
          case_id~,
        ),
      ),
    ),
  )
}

///|
fn revision_rehearsal_test_ready() -> Model {
  let base = history_test_change(history_test_model(), "revise")
  let mut model = revision_rehearsal_test_step(base, "begin")
  for
    (id, name, input, original, revised, required) in [
      (
        "case-1", "Useful <&> 東京", "Routine task", "Source: useful", "Source: useful",
        "Source:",
      ),
      (
        "case-2", "Adverse", "Uncertain task", "invented", "Source: uncertainty",
        "Source:\nuncertainty",
      ),
    ] {
    for
      (field, value) in [
        ("name", name),
        ("input", input),
        ("original", original),
        ("revised", revised),
        ("required", required),
        ("forbidden", "invented"),
      ] {
      model = revision_rehearsal_test_step(
        model,
        "edit",
        field~,
        value~,
        case_id=id,
      )
    }
  }
  model
}

///|
test "contrasting rehearsal controller stages exact v1 revision then uses existing save and review lanes" {
  let ready = revision_rehearsal_test_ready()
  let initial = ready.outcome_lessons
  let change = initial.history.change.unwrap()
  let original = lesson_record_value(change.original).unwrap()
  let compared = revision_rehearsal_test_step(ready, "compare")
  assert_eq(
    lesson_task_field(
      lesson_task_field(
        compared.outcome_lessons.history.change.unwrap().revision_rehearsal,
        "preview",
      ),
      "ready",
    ),
    true.to_json(),
  )
  assert_true(
    lesson_history_payload(compared.outcome_lessons.history) is Err(_),
  )
  let staged = revision_rehearsal_test_step(compared, "stage")
  let staged = snapshot_test_step(
    staged,
    OutcomeLesson(EditHistory("version", "new-final-version")),
  )
  let payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_text(lesson_task_field(payload, "lesson"), "lesson_version"),
    "new-final-version",
  )
  assert_eq(
    lesson_task_text(payload, "contract_version"),
    "moonbook.outcome-lesson-revision.v1",
  )
  assert_eq(
    lesson_task_field(payload, "supersedes"),
    ToJson::to_json(change.original.record),
  )
  let lesson = lesson_task_field(payload, "lesson")
  assert_eq(
    lesson_task_text(lesson, "guidance"),
    lesson_change_field(change, "guidance"),
  )
  for
    key in [
      "lesson_id", "outcome", "assessment", "assessment_review", "applicability",
      "invalidation",
    ] {
    assert_eq(
      lesson_task_field(lesson, key),
      lesson_task_field(original, key),
      msg=key,
    )
  }
  assert_true(
    lesson_task_text(payload, "reason").contains(
      "Operator-reported contrasting-case rehearsal",
    ),
  )
  assert_true(
    lesson_task_text(payload, "reason").contains("\"model_executed\": false"),
  )
  assert_true(lesson_task_text(payload, "reason").contains("Useful <&> 東京"))
  assert_eq(
    staged.outcome_lessons.history.data.unwrap().current,
    initial.history.data.unwrap().current,
  )
  assert_eq(staged.outcome_lessons.fields, initial.fields)
  assert_eq(staged.outcome_lessons.handoff, initial.handoff)
  assert_eq(staged.outcome_lessons.comparison, initial.comparison)
  assert_eq(staged.outcome_lessons.repair, initial.repair)
  assert_false(staged.outcome_lessons.pending)
  let saving = snapshot_test_step(staged, OutcomeLesson(SubmitHistoryChange))
  assert_true(saving.outcome_lessons.pending)
  assert_eq(saving.outcome_lessons.history.pending_operation, "revise")
  assert_eq(
    lesson_history_payload(saving.outcome_lessons.history).unwrap(),
    payload,
  )
  assert_eq(
    snapshot_test_step(saving, OutcomeLesson(SubmitHistoryChange)).outcome_lessons.request,
    saving.outcome_lessons.request,
  )
}

///|
test "contrasting rehearsal edits invalidate and regression can be iteratively repaired" {
  let ready = revision_rehearsal_test_step(
    revision_rehearsal_test_ready(),
    "compare",
  )
  let bad = revision_rehearsal_test_step(
    ready,
    "edit",
    field="revised",
    value="invented",
    case_id="case-1",
  )
  assert_eq(
    lesson_task_field(
      bad.outcome_lessons.history.change.unwrap().revision_rehearsal,
      "preview",
    ),
    Json::null(),
  )
  let refused = revision_rehearsal_test_step(bad, "stage")
  assert_true(lesson_history_payload(refused.outcome_lessons.history) is Err(_))
  let failed = revision_rehearsal_test_step(bad, "compare")
  assert_eq(
    lesson_task_field(
      lesson_task_field(
        failed.outcome_lessons.history.change.unwrap().revision_rehearsal,
        "preview",
      ),
      "ready",
    ),
    false.to_json(),
  )
  let fixed = revision_rehearsal_test_step(
    failed,
    "edit",
    field="revised",
    value="Source: useful",
    case_id="case-1",
  )
  let fixed = revision_rehearsal_test_step(
    fixed,
    "edit",
    field="guidance",
    value="  Exact revised <&> 東京\nKept  ",
  )
  let staged = revision_rehearsal_test_step(
    revision_rehearsal_test_step(fixed, "compare"),
    "stage",
  )
  assert_eq(
    lesson_task_text(
      lesson_task_field(
        lesson_history_payload(staged.outcome_lessons.history).unwrap(),
        "lesson",
      ),
      "guidance",
    ),
    "  Exact revised <&> 東京\nKept  ",
  )
}

///|
test "contrasting rehearsal stale current or accepted review rejects stage and poststage save" {
  let compared = revision_rehearsal_test_step(
    revision_rehearsal_test_ready(),
    "compare",
  )
  for model in [compared, revision_rehearsal_test_step(compared, "stage")] {
    let state = model.outcome_lessons
    let history = state.history
    let data = history.data.unwrap()
    for
      changed in [
        { ..data, current: Some(history_test_record("1").record), },
        { ..data, head: None, },
        { ..data, accepted_reviews: [], },
        {
          ..data,
          versions: data.versions.filter(v => {
            v.lesson.record != history_test_record("2").record
          }),
        },
      ] {
      let stale = {
        ..model,
        outcome_lessons: {
          ..state,
          history: { ..history, data: Some(changed), },
        },
      }
      let result = revision_rehearsal_test_step(stale, "stage")
      assert_eq(
        result.outcome_lessons.history.change.unwrap().revision_rehearsal,
        state.history.change.unwrap().revision_rehearsal,
      )
      assert_true(
        lesson_history_payload(result.outcome_lessons.history) is Err(_),
      )
      assert_false(
        snapshot_test_step(result, OutcomeLesson(SubmitHistoryChange)).outcome_lessons.pending,
      )
    }
  }
}

///|
test "contrasting rehearsal interruption retry pending and late controls preserve exact staged draft" {
  let compared = revision_rehearsal_test_step(
    revision_rehearsal_test_ready(),
    "compare",
  )
  let old_action = lesson_revision_rehearsal_action(
    compared.outcome_lessons.history,
    "stage",
  )
  let staged = revision_rehearsal_test_step(compared, "stage")
  let payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  let late = snapshot_test_step(
    staged,
    OutcomeLesson(RevisionRehearsal(old_action)),
  )
  assert_eq(
    lesson_history_payload(late.outcome_lessons.history).unwrap(),
    payload,
  )
  let saving = snapshot_test_step(staged, OutcomeLesson(SubmitHistoryChange))
  let ignored = revision_rehearsal_test_step(saving, "discard")
  assert_eq(
    ignored.outcome_lessons.history.change.unwrap().revision_rehearsal,
    saving.outcome_lessons.history.change.unwrap().revision_rehearsal,
  )
  let failed = lesson_history_finished(
    saving.outcome_lessons,
    saving.outcome_lessons.request,
    "revise",
    Err("interrupted transport"),
  )
  assert_eq(lesson_history_payload(failed.history).unwrap(), payload)
  let retry = snapshot_test_step(
    { ..staged, outcome_lessons: failed, },
    OutcomeLesson(SubmitHistoryChange),
  )
  assert_true(retry.outcome_lessons.pending)
  assert_eq(
    lesson_history_payload(retry.outcome_lessons.history).unwrap(),
    payload,
  )
  let closed = snapshot_test_step(staged, OutcomeLesson(DiscardHistoryChange))
  assert_true(closed.outcome_lessons.history.change is None)
  let reopened = history_test_change(closed, "revise")
  let late = snapshot_test_step(
    reopened,
    OutcomeLesson(RevisionRehearsal(old_action)),
  )
  assert_eq(
    late.outcome_lessons.history.change.unwrap().revision_rehearsal,
    Json::null(),
  )
}

///|
test "contrasting rehearsal guards ordinary edits and supports explicit discard without losing revision" {
  let staged = revision_rehearsal_test_step(
    revision_rehearsal_test_step(revision_rehearsal_test_ready(), "compare"),
    "stage",
  )
  let edited = snapshot_test_step(
    staged,
    OutcomeLesson(EditHistory("guidance", "Different ordinary edit")),
  )
  assert_true(lesson_history_payload(edited.outcome_lessons.history) is Err(_))
  let discarded = revision_rehearsal_test_step(edited, "discard")
  assert_eq(
    lesson_task_text(
      lesson_task_field(
        lesson_history_payload(discarded.outcome_lessons.history).unwrap(),
        "lesson",
      ),
      "guidance",
    ),
    "Different ordinary edit",
  )
  let no_history = {
    ..edited,
    outcome_lessons: {
      ..edited.outcome_lessons,
      history: { ..edited.outcome_lessons.history, data: None, },
    },
  }
  assert_eq(
    revision_rehearsal_test_step(no_history, "discard").outcome_lessons.history.change.unwrap().revision_rehearsal,
    Json::null(),
  )
}

///|
test "contrasting rehearsal requires accepted current and connected view escapes supplied fragments" {
  let legacy = history_test_change(history_test_model(multiple=true), "revise")
  assert_eq(
    revision_rehearsal_test_step(legacy, "begin").outcome_lessons.history.change.unwrap().revision_rehearsal,
    Json::null(),
  )
  let selection = history_test_change(history_test_model(), "select")
  assert_eq(
    revision_rehearsal_test_step(selection, "begin").outcome_lessons.history.change.unwrap().revision_rehearsal,
    Json::null(),
  )
  let ready = revision_rehearsal_test_step(
    revision_rehearsal_test_ready(),
    "compare",
  )
  let html = history_test_html(ready)
  for
    text in [
      "Rehearse revision on contrasting cases", "Guidance to rehearse", "Supplied output using original guidance",
      "Forbidden fragments", "Stage exact guidance", "&lt;&amp;&gt;", "original fail → revised pass",
      "Save revision for review",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("Useful <&>"))
}

///|
test "rehearsal owner survives discard and rejects all prior instance controls after same revision restart" {
  let base = history_test_change(history_test_model(), "revise")
  let old_begin = lesson_revision_rehearsal_action(
    base.outcome_lessons.history,
    "begin",
  )
  let started = revision_rehearsal_test_step(base, "begin")
  let before = started.outcome_lessons.history.change.unwrap()
  let actions = [
    lesson_revision_rehearsal_action(
      started.outcome_lessons.history,
      "edit",
      field="guidance",
      value="Detached old guidance",
    ),
    lesson_revision_rehearsal_action(started.outcome_lessons.history, "discard"),
    lesson_revision_rehearsal_action(started.outcome_lessons.history, "stage"),
    lesson_revision_rehearsal_action(started.outcome_lessons.history, "compare"),
  ]
  let cleared = revision_rehearsal_test_step(started, "discard")
  assert_true(
    cleared.outcome_lessons.history.change.unwrap().revision_rehearsal_epoch !=
    before.revision_rehearsal_epoch,
  )
  let stale_begin = snapshot_test_step(
    cleared,
    OutcomeLesson(RevisionRehearsal(old_begin)),
  )
  assert_eq(
    stale_begin.outcome_lessons.history.change.unwrap().revision_rehearsal,
    Json::null(),
  )
  let restarted = revision_rehearsal_test_step(cleared, "begin")
  let after = restarted.outcome_lessons.history.change.unwrap()
  assert_eq(after.selection_id, before.selection_id)
  assert_eq(
    lesson_task_field(after.revision_rehearsal, "revision"),
    lesson_task_field(before.revision_rehearsal, "revision"),
  )
  for action in actions {
    let rejected = snapshot_test_step(
      restarted,
      OutcomeLesson(RevisionRehearsal(action)),
    )
    assert_eq(
      rejected.outcome_lessons.history.change.unwrap().revision_rehearsal,
      after.revision_rehearsal,
    )
    assert_eq(
      rejected.outcome_lessons.history.change.unwrap().revision_rehearsal_epoch,
      after.revision_rehearsal_epoch,
    )
  }
}
