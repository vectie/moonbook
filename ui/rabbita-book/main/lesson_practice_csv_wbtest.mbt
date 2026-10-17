///|
test "CSV observations preview then explicit replacement enters ordinary practice correction" {
  let model = practice_test_step(teaching_test_ready(), Start)
  let session = model.outcome_lessons.teaching_brief.practice.session.unwrap()
  let csv = lesson_practice_csv_bridge(
    ToJson::to_json(session).stringify(),
    "",
    true,
  )
  let csv = csv.replace(
    old="\"\",\"\",\"\",\"\"",
    new="\"Observed first response\",\"Feedback response\",\"Check source\",\"Try another task\"",
  )
  let preview = practice_test_step(
    practice_test_step(model, Intake(csv)),
    PreviewCsv,
  )
  assert_eq(
    preview.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  let imported = preview.outcome_lessons.teaching_brief.practice.preview.unwrap()
  assert_eq(imported.teaching, session.teaching)
  assert_eq(imported.previous_rounds, session.previous_rounds)
  assert_eq(imported.observations[0].before, "Observed first response")
  let restored = practice_test_step(preview, Restore)
  assert_eq(
    restored.outcome_lessons.teaching_brief.practice.session,
    Some(imported),
  )
  assert_eq(restored.outcome_lessons.fields, model.outcome_lessons.fields)
  assert_true(restored.outcome_lessons.teaching_brief.practice.preview is None)
  let decoded = lesson_practice_decode(ToJson::to_json(imported).stringify()).unwrap()
  assert_eq(decoded, imported)
  println("PRACTICE_CSV_SAMPLE=" + ToJson::to_json(imported).stringify())
  let clicked = evolution_test_click(
    lesson_practice_view(evolution_test_message, restored),
    "Preview recorded responses CSV",
  )
  let _ = snapshot_test_step(restored, clicked)
}

///|
test "CSV conflicts and stale task identity do not change observations" {
  let model = practice_test_recorded()
  let session = model.outcome_lessons.teaching_brief.practice.session.unwrap()
  let csv = lesson_practice_csv_bridge(
    ToJson::to_json(session).stringify(),
    "",
    true,
  )
  let conflicting = csv.replace(
    old="\"\",\"\",\"\",\"\"",
    new="\"Different response\",\"\",\"\",\"\"",
  )
  assert_true(lesson_practice_csv_preview(session, conflicting) is Err(_))
  assert_eq(lesson_practice_csv_preview(session, csv).unwrap(), session)
  let changed = { ..session, previous_rounds: lesson_practice_rounds(session), }
  assert_true(lesson_practice_csv_preview(changed, csv) is Err(_))
  let model = practice_test_step(
    practice_test_step(model, Intake(conflicting)),
    PreviewCsv,
  )
  assert_eq(
    model.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  assert_true(model.outcome_lessons.teaching_brief.practice.preview is None)
}
