///|
fn practice_correction_test_step(
  model : Model,
  action : LessonPracticeCorrectionMsg,
) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      PracticeCorrection(
        model.outcome_lessons.teaching_brief.revision,
        model.outcome_lessons.request,
        lesson_practice_correction_owner(model),
        action,
      ),
    ),
  )
}

///|
fn practice_correction_test_history() -> Model {
  let base = practice_test_recorded()
  let entry = base.outcome_lessons.browser.data.unwrap().lessons[0]
  let history : LessonHistory = {
    contract_version: "moonbook.outcome-lesson-history.v1",
    lesson_id: base.outcome_lessons.teaching_brief.practice.session.unwrap().teaching.items[0].snapshot.lesson_id,
    current: Some(entry.lesson.record),
    head: Some(entry.review.receipt),
    accepted_reviews: [entry.review.receipt],
    versions: [
      { lesson: entry.lesson, reviews: [entry.review], current: true, },
    ],
    selections: [],
  }
  {
    ..base,
    outcome_lessons: {
      ..base.outcome_lessons,
      history: {
        ..initial_lesson_history_workspace(),
        lesson_id: history.lesson_id,
        read_ready: true,
        data: Some(history),
        selected: Some(entry.lesson.record),
      },
    },
  }
}

///|
fn practice_correction_test_ready() -> Model {
  let model = snapshot_test_step(
    practice_correction_test_history(),
    OutcomeLesson(StartHistoryChange("revise")),
  )
  let model = revision_rehearsal_test_step(model, "begin")
  let mut model = practice_correction_test_step(model, Choose(0))
  for
    (key, value) in [
      ("kind", "adverse"),
      ("name", "Observed invented completion time"),
      ("required", "Source:"),
      ("forbidden", "02:00"),
    ] {
    model = practice_correction_test_step(model, Edit(key, value))
  }
  model
}

///|
fn practice_correction_test_cases(model : Model) -> Array[Json] {
  lesson_evolution_array(
    lesson_task_field(
      model.outcome_lessons.history.change.unwrap().revision_rehearsal,
      "cases",
    ),
  )
}

///|
test "practice correction fills only pristine slot with exact task first response and unverified source" {
  let ready = practice_correction_test_ready()
  let session = ready.outcome_lessons.teaching_brief.practice.session.unwrap()
  let original = ready.outcome_lessons.history.change.unwrap().original
  let imported = practice_correction_test_step(ready, AddCase)
  assert_true(
    imported.outcome_lessons.history.notice.contains("Added observed practice"),
  )
  assert_eq(
    imported.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  assert_true(
    imported.outcome_lessons.teaching_brief.practice.correction is None,
  )
  let cases = practice_correction_test_cases(imported)
  assert_eq(cases.length(), 2)
  assert_eq(
    lesson_task_text(cases[1], "input"),
    session.teaching.items[0].exercise,
  )
  assert_eq(
    lesson_task_text(cases[1], "original"),
    session.observations[0].before,
  )
  assert_eq(lesson_task_text(cases[1], "revised"), "")
  assert_eq(
    lesson_task_field(cases[1], "practice_from"),
    lesson_practice_correction_source(session, 0),
  )
  assert_eq(
    imported.outcome_lessons.history.change.unwrap().original.record,
    original.record,
  )
  assert_eq(
    imported.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    ready.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
}

///|
test "practice correction requires authored role checks and refuses rehearsal-size mismatch without truncation" {
  let ready = practice_correction_test_ready()
  for
    altered in [
      practice_correction_test_step(ready, Edit("name", "")),
      practice_correction_test_step(
        practice_correction_test_step(ready, Edit("required", "")),
        Edit("forbidden", ""),
      ),
      practice_correction_test_step(ready, Edit("forbidden", "Source:")),
    ] {
    let before = practice_correction_test_cases(altered)
    assert_eq(
      practice_correction_test_cases(
        practice_correction_test_step(altered, AddCase),
      ),
      before,
    )
  }
  let large = practice_test_step(ready, Edit(0, "before", "x".repeat(8193)))
  let mut large = practice_correction_test_step(large, Choose(0))
  for
    (key, value) in [
      ("kind", "adverse"),
      ("name", "Too large"),
      ("required", "Source:"),
    ] {
    large = practice_correction_test_step(large, Edit(key, value))
  }
  let failed = practice_correction_test_step(large, AddCase)
  assert_true(failed.outcome_lessons.teaching_brief.notice.contains("8192"))
  assert_eq(
    failed.outcome_lessons.teaching_brief.practice.session.unwrap().observations[0].before.length(),
    8193,
  )
  assert_eq(
    practice_correction_test_cases(failed),
    practice_correction_test_cases(large),
  )
}

///|
test "practice correction blocks changed current lesson stale browser and unavailable history" {
  let ready = practice_correction_test_ready()
  let state = ready.outcome_lessons
  let history = state.history.data.unwrap()
  for
    altered in [
      {
        ..ready,
        outcome_lessons: {
          ..state,
          browser: { ..state.browser, pending: true, },
        },
      },
      {
        ..ready,
        outcome_lessons: {
          ..state,
          history: { ..state.history, read_ready: false, },
        },
      },
      {
        ..ready,
        outcome_lessons: {
          ..state,
          history: {
            ..state.history,
            data: Some({ ..history, current: None, }),
          },
        },
      },
    ] {
    let result = practice_correction_test_step(altered, AddCase)
    assert_eq(
      practice_correction_test_cases(result),
      practice_correction_test_cases(ready),
    )
    assert_true(
      result.outcome_lessons.teaching_brief.notice.contains("Recheck"),
    )
  }
  let session = state.teaching_brief.practice.session.unwrap()
  let first = session.teaching.items[0]
  let changed = {
    ..first,
    snapshot: { ..first.snapshot, guidance: "Forged imported guidance", },
  }
  let items = session.teaching.items.copy()
  items[0] = changed
  let forged = {
    ..ready,
    outcome_lessons: {
      ..state,
      teaching_brief: {
        ..state.teaching_brief,
        practice: {
          ..state.teaching_brief.practice,
          session: Some({ ..session, teaching: { ..session.teaching, items, }, }),
        },
      },
    },
  }
  assert_eq(
    practice_correction_test_cases(
      practice_correction_test_step(forged, AddCase),
    ),
    practice_correction_test_cases(ready),
  )
}

///|
test "practice history opens exact existing read route and never replaces another unsaved correction" {
  let model = practice_correction_test_step(
    practice_correction_test_history(),
    Choose(0),
  )
  let opened = practice_correction_test_step(model, OpenHistory)
  assert_true(opened.outcome_lessons.pending)
  assert_eq(opened.outcome_lessons.history.pending_operation, "history")
  assert_eq(
    opened.outcome_lessons.history.selected,
    Some(
      model.outcome_lessons.teaching_brief.practice.session.unwrap().teaching.items[0].snapshot.reference,
    ),
  )
  let ready = practice_correction_test_ready()
  let another = {
    ..ready,
    outcome_lessons: {
      ..ready.outcome_lessons,
      history: { ..ready.outcome_lessons.history, lesson_id: "another-family", },
    },
  }
  let blocked = practice_correction_test_step(another, OpenHistory)
  assert_false(blocked.outcome_lessons.pending)
  assert_eq(
    blocked.outcome_lessons.history.change.unwrap().selection_id,
    another.outcome_lessons.history.change.unwrap().selection_id,
  )
  assert_true(
    blocked.outcome_lessons.teaching_brief.notice.contains("another lesson"),
  )
}

///|
test "practice correction detached controls cannot attach changed observations or newer history" {
  let ready = practice_correction_test_ready()
  let stale = OutcomeLesson(
    PracticeCorrection(
      ready.outcome_lessons.teaching_brief.revision,
      ready.outcome_lessons.request,
      lesson_practice_correction_owner(ready),
      AddCase,
    ),
  )
  let edited = practice_test_step(ready, Edit(0, "feedback", "New evidence"))
  assert_true(edited.outcome_lessons.teaching_brief.practice.correction is None)
  assert_eq(
    practice_correction_test_cases(snapshot_test_step(edited, stale)),
    practice_correction_test_cases(ready),
  )
  let refreshed = snapshot_test_step(
    ready,
    OutcomeLesson(EditHistory("title", "New title")),
  )
  assert_eq(
    practice_correction_test_cases(snapshot_test_step(refreshed, stale)),
    practice_correction_test_cases(ready),
  )
  let rehearsed = revision_rehearsal_test_step(
    ready,
    "edit",
    field="guidance",
    value="Newer rehearsal guidance",
  )
  assert_eq(
    practice_correction_test_cases(snapshot_test_step(rehearsed, stale)),
    practice_correction_test_cases(ready),
  )
  let pending = {
    ..ready,
    outcome_lessons: { ..ready.outcome_lessons, pending: true, },
  }
  assert_eq(
    practice_correction_test_cases(snapshot_test_step(pending, stale)),
    practice_correction_test_cases(ready),
  )
}

///|
test "practice import preserves authored cases and rejects repeated exact inputs" {
  let ready = revision_rehearsal_test_step(
    practice_correction_test_ready(),
    "edit",
    field="name",
    value="Existing adverse work",
    case_id="case-2",
  )
  let existing = practice_correction_test_cases(ready)[1]
  let imported = practice_correction_test_step(ready, AddCase)
  assert_eq(practice_correction_test_cases(imported).length(), 3)
  assert_eq(practice_correction_test_cases(imported)[1], existing)
  let mut repeated = practice_correction_test_step(imported, Choose(0))
  for
    (key, value) in [
      ("kind", "adverse"),
      ("name", "Again"),
      ("required", "Source:"),
    ] {
    repeated = practice_correction_test_step(repeated, Edit(key, value))
  }
  let blocked = practice_correction_test_step(repeated, AddCase)
  assert_eq(
    practice_correction_test_cases(blocked),
    practice_correction_test_cases(imported),
  )
  assert_true(blocked.outcome_lessons.teaching_brief.notice.contains("already"))
}

///|
test "practice task and original response stay fixed while new guidance output and checks remain editable" {
  let imported = practice_correction_test_step(
    practice_correction_test_ready(),
    AddCase,
  )
  for key in ["input", "original"] {
    let blocked = revision_rehearsal_test_step(
      imported,
      "edit",
      field=key,
      value="Overwrite",
      case_id="case-2",
    )
    assert_eq(
      practice_correction_test_cases(blocked),
      practice_correction_test_cases(imported),
    )
    assert_true(
      blocked.outcome_lessons.history.notice.contains("exact observation"),
    )
  }
  let edited = revision_rehearsal_test_step(
    imported,
    "edit",
    field="revised",
    value="Source: recorded sheet. No exact hour is known.",
    case_id="case-2",
  )
  assert_eq(
    lesson_task_text(practice_correction_test_cases(edited)[1], "revised"),
    "Source: recorded sheet. No exact hour is known.",
  )
  assert_eq(
    lesson_task_field(
      practice_correction_test_cases(edited)[1],
      "practice_from",
    ),
    lesson_task_field(
      practice_correction_test_cases(imported)[1],
      "practice_from",
    ),
  )
  assert_true(
    @rabbita.render_to_string(
      @rabbita.simple_cell(
        model=edited,
        update=fn(_message : Msg, old) { old },
        view=lesson_revision_rehearsal_view,
      ),
    ).contains("after-feedback response is reference context"),
  )
}

///|
fn practice_correction_test_staged() -> Model raise {
  let mut model = practice_correction_test_step(
    practice_correction_test_ready(),
    AddCase,
  )
  for
    (key, value) in [
      (
        "guidance", "Cite the source and explicitly state when an exact time is not stated.",
      ),
      (
        "rationale", "Observed practice invented an exact hour; retain useful cited answers.",
      ),
    ] {
    model = revision_rehearsal_test_step(model, "edit", field=key, value~)
  }
  for
    (key, value) in [
      ("name", "Preserve a known answer"),
      ("input", "The source states a 03:00 start time. Report it."),
      ("original", "Source: schedule. Starts at 03:00."),
      ("revised", "Source: schedule. Starts at 03:00."),
      ("required", "Source:"),
    ] {
    model = revision_rehearsal_test_step(
      model,
      "edit",
      field=key,
      value~,
      case_id="case-1",
    )
  }
  model = revision_rehearsal_test_step(
    model,
    "edit",
    field="revised",
    value="Source: service sheet. Exports run nightly; no exact completion time is stated.",
    case_id="case-2",
  )
  let compared = revision_rehearsal_test_step(model, "compare")
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
  let staged = revision_rehearsal_test_step(compared, "stage")
  snapshot_test_step(
    staged,
    OutcomeLesson(EditHistory("version", "practice-correction-4")),
  )
}

///|
test "practice provenance survives comparison staging and ordinary review-pending revision payload" {
  let staged = practice_correction_test_staged()
  let payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_text(payload, "contract_version"),
    "moonbook.outcome-lesson-revision.v1",
  )
  let reason = lesson_task_text(payload, "reason")
  assert_true(reason.contains("practice-correction-source.v1"))
  assert_true(reason.contains("Exports finish at 02:00 UTC."))
  assert_true(reason.contains("after_feedback_response"))
  assert_true(reason.contains("\"model_executed\": false"))
  let saved = snapshot_test_step(staged, OutcomeLesson(SubmitHistoryChange))
  assert_true(saved.outcome_lessons.pending)
  assert_eq(saved.outcome_lessons.history.pending_operation, "revise")
  println("PRACTICE_CORRECTION_SAMPLE=" + payload.stringify())
}

///|
test "observed practice source survives explicit saved correction cold resumption" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let imported = practice_correction_test_step(
    practice_correction_test_ready(),
    AddCase,
  )
  let saved = correction_test_step(imported, "save")
  assert_true(
    saved.outcome_lessons.history.notice.contains("saved on this browser"),
  )
  let fresh = correction_test_fresh(practice_correction_test_history())
  let resumed = correction_test_step(
    correction_test_step(fresh, "read"),
    "resume",
  )
  assert_true(resumed.outcome_lessons.history.notice.contains("resumed"))
  assert_eq(
    lesson_task_field(
      practice_correction_test_cases(resumed)[1],
      "practice_from",
    ),
    lesson_task_field(
      practice_correction_test_cases(imported)[1],
      "practice_from",
    ),
  )
  assert_eq(
    lesson_task_text(practice_correction_test_cases(resumed)[1], "revised"),
    "",
  )
  assert_eq(
    lesson_task_field(
      resumed.outcome_lessons.history.change.unwrap().revision_rehearsal,
      "preview",
    ),
    Json::null(),
  )
}

///|
test "rendered practice controls reach selection exact case preview and existing rehearsal" {
  let ready = practice_correction_test_ready()
  let chosen = snapshot_test_step(
    ready,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, ready),
      "Prepare practice 1 for correction",
    ),
  )
  assert_eq(
    chosen.outcome_lessons.teaching_brief.practice.correction.unwrap().index,
    0,
  )
  let html = browser_test_html(ready)
  assert_true(html.contains("Turn practice 1 into a correction case"))
  assert_true(
    html.contains("First response") || html.contains("first response"),
  )
  let imported = snapshot_test_step(
    ready,
    evolution_test_click(
      lesson_practice_correction_view(evolution_test_message, ready),
      "Add first response as original-guidance case",
    ),
  )
  assert_eq(
    lesson_task_text(practice_correction_test_cases(imported)[1], "name"),
    "Observed invented completion time",
  )
  let closed = snapshot_test_step(
    ready,
    evolution_test_click(
      lesson_practice_correction_view(evolution_test_message, ready),
      "Close practice case preparation",
    ),
  )
  assert_true(closed.outcome_lessons.teaching_brief.practice.correction is None)
  assert_eq(
    closed.outcome_lessons.teaching_brief.practice.session,
    ready.outcome_lessons.teaching_brief.practice.session,
  )
}

///|
test "resumed unverified workbook can prepare matching practice without gaining lesson or execution authority" {
  let original = practice_correction_test_history()
  let session = original.outcome_lessons.teaching_brief.practice.session.unwrap()
  let resumed = practice_test_step(
    practice_test_step(
      practice_test_step(
        practice_test_step(original, Discard),
        Intake(ToJson::to_json(session).stringify()),
      ),
      Preview,
    ),
    Restore,
  )
  let source = lesson_practice_correction_source(
    resumed.outcome_lessons.teaching_brief.practice.session.unwrap(),
    0,
  )
  assert_eq(lesson_task_field(source, "operator_reported"), true.to_json())
  assert_eq(lesson_task_field(source, "model_executed"), false.to_json())
  assert_eq(
    resumed.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    original.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
}
