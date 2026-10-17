///|
fn rehearsal_ui_fixture() -> OutcomeLessonWorkspace {
  let state = lesson_workspace_fixture()
  let state = lesson_ui_edit(
    state, "rehearsal-input", "Compare the same two sources.",
  )
  let state = lesson_ui_edit(state, "rehearsal-baseline", "Source: one")
  let state = lesson_ui_edit(
    state, "rehearsal-corrected", "Source: one. Contradiction: two",
  )
  lesson_ui_edit(state, "rehearsal-checks", "Source:\nContradiction:")
}

///|
test "rehearsal requires exact current draft and clear preserves authored guidance" {
  let state = rehearsal_ui_fixture()
  assert_true(lesson_rehearsal_save_payload(state) is Err(_))
  let ready = lesson_rehearsal_try(state)
  let payload = lesson_rehearsal_save_payload(ready).unwrap()
  assert_true(
    payload
    is {
      "contract_version": "moonbook.outcome-lesson-rehearsal.v1",
      "lesson": { "lesson_id": "one-stable-id", .. },
      ..
    },
  )
  let changed = lesson_ui_edit(ready, "guidance", "A later correction")
  assert_true(changed.rehearsal_result is None)
  assert_true(lesson_rehearsal_save_payload(changed) is Err(_))
  let another_source = { ..ready, recorded_at: ready.recorded_at + 1, }
  assert_true(lesson_rehearsal_save_payload(another_source) is Err(_))
  let cleared = lesson_rehearsal_clear(ready)
  assert_false(lesson_rehearsal_has_inputs(cleared))
  assert_true(cleared.rehearsal_result is None)
  assert_eq(
    lesson_ui_payload(cleared, "prepare"),
    lesson_ui_payload(state, "prepare"),
  )
}

///|
test "rehearsal save guards duplicate clicks failed writes and ordinary save data loss" {
  let state = lesson_rehearsal_try(rehearsal_ui_fixture())
  let model = { ..draft_test_model(), outcome_lessons: state, }
  let ordinary = snapshot_test_step(model, OutcomeLesson(Submit("prepare")))
  assert_false(ordinary.outcome_lessons.pending)
  assert_true(
    ordinary.outcome_lessons.notice.contains("not be silently discarded"),
  )
  let saving = snapshot_test_step(
    model,
    OutcomeLesson(Submit("prepare-rehearsal")),
  )
  assert_true(saving.outcome_lessons.pending)
  let again = snapshot_test_step(
    saving,
    OutcomeLesson(Submit("prepare-rehearsal")),
  )
  assert_eq(again.outcome_lessons.request, saving.outcome_lessons.request)
  let cleared = snapshot_test_step(saving, OutcomeLesson(ClearRehearsal))
  assert_eq(cleared.outcome_lessons.rehearsal_request, state.rehearsal_request)
  let failed = lesson_ui_finished(
    saving.outcome_lessons,
    saving.outcome_lessons.request,
    "prepare-rehearsal",
    Err("interrupted"),
  )
  assert_eq(
    lesson_rehearsal_save_payload(failed),
    lesson_rehearsal_save_payload(state),
  )
  let stale = lesson_ui_finished(
    state,
    saving.outcome_lessons.request,
    "prepare-rehearsal",
    Ok({ "accepted": true }),
  )
  assert_true(stale.result is None)
}

///|
test "rehearsal is reachable and clearly labels the real next-run selection boundary" {
  let model = {
    ..draft_test_model(),
    outcome_lessons: lesson_rehearsal_try(rehearsal_ui_fixture()),
  }
  let html = book_test_render_component(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=outcome_lesson_workspace_view,
    ),
  )
  for
    text in [
      "Teach once", "Try correction on the same example", "Save rehearsal-backed lesson for review",
      "No model or tool runs here", "Proj captures that version", "Clear rehearsal and keep lesson draft",
    ] {
    assert_true(html.contains(text), msg=text)
  }
}
