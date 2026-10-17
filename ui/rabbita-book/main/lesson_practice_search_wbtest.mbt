///|
test "search finds historical observations and keeps exact round selection" {
  let model = practice_test_recorded()
  let next = practice_rounds_test_next(model)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  let historic = session.previous_rounds[0]
  let query = historic.observations[0].before
  assert_true(!query.is_blank())
  assert_true(lesson_practice_search(session, query).contains((0, 0)))
  assert_true(lesson_practice_search(session, "").is_empty())
  assert_true(
    lesson_practice_search(session, "no-such-practice-738").is_empty(),
  )
  let state = next.outcome_lessons.teaching_brief
  let searched = lesson_practice_reduce(
    state,
    next.outcome_lessons.browser,
    Search(query),
  )
  assert_eq(searched.practice.session, state.practice.session)
  assert_eq(searched.revision, state.revision + 1)
  let searched_model = {
    ..next,
    outcome_lessons: { ..next.outcome_lessons, teaching_brief: searched, },
  }
  let html = browser_test_html(searched_model)
  assert_true(html.contains("Find a recorded practice experience"))
  assert_true(html.contains("Prepare this experience for correction"))
  let selected = practice_correction_test_step(
    searched_model,
    ChooseRound(0, 0),
  )
  assert_eq(
    selected.outcome_lessons.teaching_brief.practice.correction.unwrap().round,
    0,
  )
}

///|
test "search covers feedback learner tasks and current response" {
  let session = practice_test_recorded().outcome_lessons.teaching_brief.practice.session.unwrap()
  let observations = session.observations.copy()
  observations[0] = {
    ..observations[0],
    feedback: "specific feedback 738",
    next_practice: "next task 738",
  }
  let changed = { ..session, learner: "agent 738", observations, }
  for
    query in [
      "specific feedback 738",
      "next task 738",
      "agent 738",
      changed.teaching.items[0].exercise,
    ] {
    assert_true(lesson_practice_search(changed, query).contains((0, 0)))
  }
  assert_true(
    lesson_practice_search(changed, "SPECIFIC FEEDBACK 738").is_empty(),
  )
}
