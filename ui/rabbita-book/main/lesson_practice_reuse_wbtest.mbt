///|
fn practice_reuse_test_search(model : Model) -> Model {
  let session = model.outcome_lessons.teaching_brief.practice.session.unwrap()
  practice_test_step(
    model,
    Search(lesson_practice_rounds(session)[0].teaching.items[0].exercise),
  )
}

///|
fn practice_reuse_test_click(model : Model) -> Msg {
  evolution_test_click(
    lesson_practice_view(evolution_test_message, model),
    "Replace selected lesson's next task with this exact task",
  )
}

///|
test "reuse exact historical task through rendered replacement then blank next round and cold resume" {
  let exact = "  海😀 é\t\n<task>\r\n  "
  let prepared = teaching_test_step(teaching_test_ready(), Exercise(0, exact))
  let recorded = practice_test_step(
    practice_test_step(prepared, Start),
    Edit(0, "before", "Original observation"),
  )
  let second = practice_rounds_test_next(
    teaching_test_step(recorded, Exercise(0, "Replacement to overwrite")),
  )
  let second = practice_test_step(
    second,
    Edit(0, "before", "Second observation"),
  )
  let searched = practice_reuse_test_search(second)
  let before = searched.outcome_lessons.teaching_brief.practice.session.unwrap()
  let copied = snapshot_test_step(searched, practice_reuse_test_click(searched))
  assert_eq(
    copied.outcome_lessons.teaching_brief.draft.items[0].exercise,
    exact,
  )
  assert_eq(
    copied.outcome_lessons.teaching_brief.practice.session,
    Some(before),
  )
  assert_true(browser_test_html(copied).contains("No observations were copied"))
  let next = practice_rounds_test_next(copied)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(session.teaching.items[0].exercise, exact)
  assert_eq(session.previous_rounds, lesson_practice_rounds(before))
  assert_true(
    session.observations.all(o => {
      o.before == "" &&
      o.after == "" &&
      o.feedback == "" &&
      o.next_practice == ""
    }),
  )
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
  assert_eq(
    resumed.outcome_lessons.teaching_brief.draft,
    fresh.outcome_lessons.teaching_brief.draft,
  )
  assert_eq(
    practice_test_step(resumed, NextRound).outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
}

///|
test "reuse stale search reorder edit and browser callbacks cannot replace another task" {
  let searched = practice_reuse_test_search(practice_test_recorded())
  let click = practice_reuse_test_click(searched)
  for
    changed in [
      practice_test_step(searched, Search("different query")),
      practice_test_step(
        practice_test_step(searched, Search("different query")),
        Search(searched.outcome_lessons.teaching_brief.practice.search),
      ),
      teaching_test_step(searched, Move(0, 1)),
      teaching_test_step(searched, Exercise(0, "Newer edit")),
      {
        ..searched,
        outcome_lessons: {
          ..searched.outcome_lessons,
          browser: {
            ..searched.outcome_lessons.browser,
            request: searched.outcome_lessons.browser.request + 1,
          },
        },
      },
    ] {
    assert_eq(
      snapshot_test_step(changed, click).outcome_lessons.teaching_brief.draft,
      changed.outcome_lessons.teaching_brief.draft,
    )
    assert_eq(
      snapshot_test_step(changed, click).outcome_lessons.teaching_brief.practice.session,
      changed.outcome_lessons.teaching_brief.practice.session,
    )
  }
}

///|
test "reuse refuses missing incompatible and unavailable selected lessons" {
  let searched = practice_reuse_test_search(practice_test_recorded())
  let brief = searched.outcome_lessons.teaching_brief
  let items = brief.draft.items.copy()
  items[0] = {
    ..items[0],
    snapshot: { ..items[0].snapshot, title: "Changed capture", },
  }
  let incompatible = {
    ..searched,
    outcome_lessons: {
      ..searched.outcome_lessons,
      teaching_brief: { ..brief, draft: { ..brief.draft, items, }, },
    },
  }
  let missing = teaching_test_step(searched, Remove(0))
  let unavailable = {
    ..searched,
    outcome_lessons: {
      ..searched.outcome_lessons,
      browser: { ..searched.outcome_lessons.browser, data: None, },
    },
  }
  for blocked in [missing, incompatible, unavailable] {
    let result = practice_test_step(
      blocked,
      ReuseTask(blocked.outcome_lessons.browser.request, 0, 0),
    )
    assert_eq(
      result.outcome_lessons.teaching_brief.draft,
      blocked.outcome_lessons.teaching_brief.draft,
    )
    assert_eq(
      result.outcome_lessons.teaching_brief.practice.session,
      blocked.outcome_lessons.teaching_brief.practice.session,
    )
  }
}
