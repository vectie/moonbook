///|
fn retest_test_version(
  entry : LessonBrowserEntry,
  version : String,
  guidance : String,
) -> LessonBrowserEntry {
  let value = lesson_record_value(entry.lesson).unwrap()
  let lesson = browser_test_set(
    browser_test_set(value, "lesson_version", version.to_json()),
    "guidance",
    guidance.to_json(),
  )
  let record = {
    ..entry.lesson,
    record: {
      record_id: "outcome-lesson:" +
      lesson_task_text(lesson, "lesson_id") +
      "@" +
      version,
      record_version: version,
      record_digest: "synthetic-retest-" + version,
    },
    payload: {
      "candidate_schema": "outcome_lesson.v1",
      "outcome_lesson": lesson,
    },
  }
  {
    lesson: record,
    review: @json.from_json(history_test_review(record, "Accept")) catch {
      _ => panic()
    },
    selection_review: Json::null(),
  }
}

///|
fn retest_test_ready(
  exercise? : String = "The source says exports run nightly. When do they finish?",
) -> Model {
  let base = teaching_test_model()
  let browser = base.outcome_lessons.browser
  let data = browser.data.unwrap()
  let old = retest_test_version(
    data.lessons[0],
    "before",
    "Answer only the stated schedule.",
  )
  let base = {
    ..base,
    outcome_lessons: {
      ..base.outcome_lessons,
      browser: { ..browser, data: Some({ ..data, lessons: [old], }), },
    },
  }
  let ready = teaching_test_step(
    teaching_test_step(
      teaching_test_step(base, Add(browser.request, old.lesson.record)),
      Objective("Revisit a recorded task after a reviewed correction"),
    ),
    Exercise(0, exercise),
  )
  let observed = practice_test_step(
    practice_test_step(ready, Start),
    Edit(0, "before", "Exports finish exactly at 02:00 UTC."),
  )
  let observed = practice_test_step(
    observed,
    Learner("Original synthetic session"),
  )
  let current = retest_test_version(
    old, "corrected", "State the schedule and explicitly identify an unknown completion time.",
  )
  let refreshed = {
    ..observed,
    outcome_lessons: {
      ..observed.outcome_lessons,
      browser: {
        ..browser,
        request: browser.request + 1,
        data: Some({ ..data, lessons: [current], }),
      },
    },
  }
  let selected = teaching_test_step(
    teaching_test_step(refreshed, Remove(0)),
    Add(browser.request + 1, current.lesson.record),
  )
  practice_test_step(
    teaching_test_step(selected, Exercise(0, "Previously authored next task")),
    Search(exercise),
  )
}

///|
fn retest_test_preview(model : Model) -> Model {
  snapshot_test_step(
    model,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, model),
      "Preview this task with selected current guidance",
    ),
  )
}

///|
fn retest_test_apply_message(model : Model) -> Msg {
  evolution_test_click(
    lesson_practice_view(evolution_test_message, model),
    "Replace next task with previewed historical task",
  )
}

///|
test "retest rendered preview replaces only next task then starts a blank versioned round" {
  let exact = "  海😀 é\t\n<task>\r\n  "
  let ready = retest_test_ready(exercise=exact)
  let old = ready.outcome_lessons.teaching_brief.practice.session.unwrap()
  let brief = ready.outcome_lessons.teaching_brief.draft
  let prepared = retest_test_preview(ready)
  assert_eq(prepared.outcome_lessons.teaching_brief.draft, brief)
  assert_eq(prepared.outcome_lessons.teaching_brief.practice.session, Some(old))
  let html = browser_test_html(prepared)
  for
    text in [
      "Historical guidance, scope and reviews", "Selected current guidance, scope and reviews",
      "Previously authored next task", "unknown completion time", "unverified operator report",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  let copied = snapshot_test_step(prepared, retest_test_apply_message(prepared))
  assert_eq(
    copied.outcome_lessons.teaching_brief.draft.items[0].exercise,
    exact,
  )
  assert_eq(
    copied.outcome_lessons.teaching_brief.draft.items[0].snapshot,
    brief.items[0].snapshot,
  )
  assert_eq(copied.outcome_lessons.teaching_brief.practice.session, Some(old))
  assert_true(copied.outcome_lessons.teaching_brief.practice.retest is None)
  let next = practice_rounds_test_next(copied)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(session.previous_rounds, lesson_practice_rounds(old))
  assert_eq(session.teaching.items[0].exercise, exact)
  assert_true(
    session.teaching.items[0].snapshot.reference.record_id !=
    old.teaching.items[0].snapshot.reference.record_id,
  )
  assert_true(
    session.observations.all(o => {
      o.before == "" &&
      o.after == "" &&
      o.feedback == "" &&
      o.next_practice == ""
    }),
  )
  let recorded = practice_test_step(
    practice_test_step(next, Learner("New synthetic session")),
    Edit(
      0, "before", "The source states nightly exports but gives no completion time.",
    ),
  )
  let final_session = recorded.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(final_session.previous_rounds, session.previous_rounds)
  assert_eq(
    lesson_practice_matching_rounds(
      final_session,
      final_session.teaching.items[0],
    ).length(),
    2,
  )
  let html = browser_test_html(recorded)
  assert_true(html.contains("Different lesson capture"))
  assert_true(html.contains("Captured version: before"))
  assert_true(html.contains("Captured version: corrected"))
  assert_true(html.contains("New synthetic session"))
  assert_eq(
    recorded.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    ready.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
  assert_eq(recorded.outcome_lessons.fields, ready.outcome_lessons.fields)
}

///|
test "retest rejects changed family source or same version and preserves original exact reuse" {
  let ready = retest_test_ready()
  let state = ready.outcome_lessons.teaching_brief
  let old = state.practice.session.unwrap().teaching.items[0]
  assert_eq(
    lesson_practice_retest_target(state, ready.outcome_lessons.browser, old),
    Some(0),
  )
  assert_true(
    lesson_practice_reuse_target(state, ready.outcome_lessons.browser, old)
    is None,
  )
  for
    changed in [
      { ..old, snapshot: { ..old.snapshot, lesson_id: "unrelated-family", }, },
      {
        ..old,
        snapshot: {
          ..old.snapshot,
          outcome: { "record_id": "different-outcome" },
        },
      },
      {
        ..old,
        snapshot: {
          ..old.snapshot,
          assessment: { "record_id": "different-assessment" },
        },
      },
      {
        ..old,
        snapshot: {
          ..old.snapshot,
          reference: {
            ..old.snapshot.reference,
            record_id: "unrelated-record",
          },
        },
      },
      state.draft.items[0],
    ] {
    assert_true(
      lesson_practice_retest_target(
        state,
        ready.outcome_lessons.browser,
        changed,
      )
      is None,
    )
  }
  let unchanged = practice_test_recorded()
  let brief = unchanged.outcome_lessons.teaching_brief
  let item = brief.practice.session.unwrap().teaching.items[0]
  assert_eq(
    lesson_practice_reuse_target(brief, unchanged.outcome_lessons.browser, item),
    Some(0),
  )
  assert_true(
    lesson_practice_retest_target(
      brief,
      unchanged.outcome_lessons.browser,
      item,
    )
    is None,
  )
}

///|
test "retest requires a selected freshly matching current capture and readable host" {
  let ready = retest_test_ready()
  let state = ready.outcome_lessons.teaching_brief
  let browser = ready.outcome_lessons.browser
  let old = state.practice.session.unwrap().teaching.items[0]
  for
    changed in [
      { ..browser, pending: true, },
      { ..browser, error: Some("offline"), },
      { ..browser, data: None, },
      { ..browser, data: Some({ ..browser.data.unwrap(), lessons: [], }), },
    ] {
    assert_true(lesson_practice_retest_target(state, changed, old) is None)
    let prepared = lesson_practice_retest_prepare(
      state,
      changed,
      changed.request,
      0,
      0,
    )
    assert_eq(prepared.draft, state.draft)
    assert_true(prepared.practice.retest is None)
  }
  assert_true(
    lesson_practice_retest_target(
      { ..state, recheck_after: browser.request, },
      browser,
      old,
    )
    is None,
  )
  let removed = teaching_test_step(ready, Remove(0))
  assert_true(
    lesson_practice_retest_target(
      removed.outcome_lessons.teaching_brief,
      browser,
      old,
    )
    is None,
  )
  let pending = {
    ..ready,
    outcome_lessons: { ..ready.outcome_lessons, pending: true, },
  }
  let denied = practice_test_step(pending, PreviewRetest(browser.request, 0, 0))
  assert_true(denied.outcome_lessons.teaching_brief.practice.retest is None)
}

///|
test "retest stale rendered controls cannot replace a newer task or changed workbook" {
  let prepared = retest_test_preview(retest_test_ready())
  let click = retest_test_apply_message(prepared)
  let original = prepared.outcome_lessons.teaching_brief
  for
    changed in [
      teaching_test_step(prepared, Exercise(0, "Newer authored task")),
      practice_test_step(
        practice_test_step(prepared, Search("other")),
        Search(original.practice.search),
      ),
      practice_test_step(
        prepared,
        Edit(0, "before", "Changed historical observation"),
      ),
      practice_test_step(prepared, Discard),
      teaching_test_step(prepared, Remove(0)),
      {
        ..prepared,
        outcome_lessons: {
          ..prepared.outcome_lessons,
          browser: {
            ..prepared.outcome_lessons.browser,
            request: prepared.outcome_lessons.browser.request + 1,
          },
        },
      },
      {
        ..prepared,
        outcome_lessons: {
          ..prepared.outcome_lessons,
          browser: { ..prepared.outcome_lessons.browser, pending: true, },
        },
      },
      {
        ..prepared,
        outcome_lessons: { ..prepared.outcome_lessons, pending: true, },
      },
    ] {
    let result = snapshot_test_step(changed, click)
    assert_eq(
      result.outcome_lessons.teaching_brief.draft,
      changed.outcome_lessons.teaching_brief.draft,
    )
    assert_eq(
      result.outcome_lessons.teaching_brief.practice.session,
      changed.outcome_lessons.teaching_brief.practice.session,
    )
  }
  let first = snapshot_test_step(prepared, click)
  let repeated = snapshot_test_step(first, click).outcome_lessons.teaching_brief
  assert_eq(repeated.draft, first.outcome_lessons.teaching_brief.draft)
  assert_eq(
    repeated.practice.session,
    first.outcome_lessons.teaching_brief.practice.session,
  )
  assert_eq(repeated.revision, first.outcome_lessons.teaching_brief.revision)
}

///|
test "retest cancellation and cold resume preserve histories and require a fresh preview" {
  let prepared = retest_test_preview(retest_test_ready())
  let state = prepared.outcome_lessons.teaching_brief
  let cancelled = practice_test_step(prepared, CancelRetest)
  assert_eq(cancelled.outcome_lessons.teaching_brief.draft, state.draft)
  assert_eq(
    cancelled.outcome_lessons.teaching_brief.practice.session,
    state.practice.session,
  )
  assert_true(cancelled.outcome_lessons.teaching_brief.practice.retest is None)
  let applied = snapshot_test_step(
    prepared,
    retest_test_apply_message(prepared),
  )
  let next = practice_rounds_test_next(applied)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  let fresh = teaching_test_model()
  let resumed = practice_test_step(
    practice_test_step(
      practice_test_step(fresh, Intake(ToJson::to_json(session).stringify())),
      Preview,
    ),
    Restore,
  )
  assert_eq(
    resumed.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  assert_true(resumed.outcome_lessons.teaching_brief.practice.retest is None)
  assert_eq(
    lesson_practice_matching_rounds(session, session.teaching.items[0]).length(),
    2,
  )
  assert_eq(
    practice_test_step(resumed, ApplyRetest).outcome_lessons.teaching_brief.draft,
    resumed.outcome_lessons.teaching_brief.draft,
  )
}

///|
test "cross-version comparisons separate exact task and source family without asserting lineage" {
  let prepared = retest_test_preview(retest_test_ready())
  let next = practice_rounds_test_next(
    snapshot_test_step(prepared, retest_test_apply_message(prepared)),
  )
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  let item = session.teaching.items[0]
  assert_eq(lesson_practice_matching_rounds(session, item).length(), 2)
  for
    changed in [
      { ..item, exercise: item.exercise + " ", },
      {
        ..item,
        snapshot: {
          ..item.snapshot,
          outcome: { "record_id": "other-outcome" },
        },
      },
      {
        ..item,
        snapshot: {
          ..item.snapshot,
          assessment: { "record_id": "other-assessment" },
        },
      },
      {
        ..item,
        snapshot: {
          ..item.snapshot,
          reference: {
            ..item.snapshot.reference,
            record_id: "unrelated-record",
          },
        },
      },
    ] {
    assert_eq(lesson_practice_matching_rounds(session, changed).length(), 0)
  }
}

///|
test "retest displays changed scope and refuses a target whose current host capture changed" {
  let ready = retest_test_ready()
  let browser = ready.outcome_lessons.browser
  let data = browser.data.unwrap()
  let entry = data.lessons[0]
  let lesson = lesson_record_value(entry.lesson).unwrap()
  let altered = {
    ..entry,
    lesson: {
      ..entry.lesson,
      payload: {
        "candidate_schema": "outcome_lesson.v1",
        "outcome_lesson": browser_test_set(
          browser_test_set(lesson, "applicability", [
            { "key": "source_state", "value": "reconfirmed-source-only" },
          ]),
          "invalidation",
          [{ "key": "source_state", "value": "changed-since-practice" }],
        ),
      },
    },
  }
  let changed_host = {
    ..ready,
    outcome_lessons: {
      ..ready.outcome_lessons,
      browser: { ..browser, data: Some({ ..data, lessons: [altered], }), },
    },
  }
  let state = ready.outcome_lessons.teaching_brief
  assert_true(
    lesson_practice_retest_target(
      state,
      changed_host.outcome_lessons.browser,
      state.practice.session.unwrap().teaching.items[0],
    )
    is None,
  )
  let reselected = teaching_test_step(
    teaching_test_step(changed_host, Remove(0)),
    Add(browser.request, altered.lesson.record),
  )
  let preview = retest_test_preview(reselected)
  let html = browser_test_html(preview)
  assert_true(html.contains("reconfirmed-source-only"))
  assert_true(html.contains("changed-since-practice"))
  assert_true(html.contains("does not establish that the guidance applies"))
  let original = preview.outcome_lessons.teaching_brief.practice.session
  let applied = snapshot_test_step(preview, retest_test_apply_message(preview))
  assert_eq(applied.outcome_lessons.teaching_brief.practice.session, original)
  assert_eq(
    applied.outcome_lessons.teaching_brief.draft.items[0].snapshot.applicability,
    lesson_task_field(
      lesson_record_value(altered.lesson).unwrap(),
      "applicability",
    ),
  )
}
