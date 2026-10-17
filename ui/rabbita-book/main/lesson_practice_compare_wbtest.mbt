///|
test "practice comparison pairs exact task and preserves changed guidance" {
  let model = practice_test_recorded()
  let first = model.outcome_lessons.teaching_brief.practice.session.unwrap()
  let next = practice_rounds_test_next(model)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  let item = session.teaching.items[0]
  let matches = lesson_practice_matching_rounds(session, item)
  assert_eq(matches.length(), 2)
  let (number, _, observed, _) = matches[0]
  assert_eq(number, 1)
  assert_eq(observed, first.observations[0])
  let modified = {
    ..item,
    snapshot: { ..item.snapshot, guidance: "Revised guidance", },
  }
  let changed = {
    ..session,
    teaching: {
      ..session.teaching,
      items: session.teaching.items.mapi((index, existing) => {
        if index == 0 {
          modified
        } else {
          existing
        }
      }),
    },
  }
  assert_eq(lesson_practice_matching_rounds(changed, modified).length(), 2)
  let text = @rabbita.render_to_string(
    @rabbita.simple_cell(model=changed, update=fn(_msg : Int, old) { old }, view=fn(
      _,
      session,
    ) {
      lesson_practice_comparison_view(session)
    }),
  )
  assert_true(text.contains("Different lesson capture"))
  assert_true(text.contains("Revised guidance"))
  assert_true(text.contains("Not recorded."))
  assert_true(
    browser_test_html(next).contains(
      "Compare the same practice task across rounds",
    ),
  )
  assert_eq(
    lesson_practice_decode(ToJson::to_json(changed).stringify()).unwrap(),
    changed,
  )
  println("PRACTICE_COMPARISON_SAMPLE=" + ToJson::to_json(changed).stringify())
}

///|
test "practice comparison separates task and record identity" {
  let session = practice_rounds_test_recorded().outcome_lessons.teaching_brief.practice.session.unwrap()
  let item = session.teaching.items[0]
  assert_eq(lesson_practice_matching_rounds(session, item).length(), 1)
  assert_eq(
    lesson_practice_matching_rounds(session, {
      ..item,
      exercise: item.exercise + " ",
    }).length(),
    0,
  )
  let different = {
    ..item,
    snapshot: {
      ..item.snapshot,
      reference: { ..item.snapshot.reference, record_id: "another-record", },
    },
  }
  assert_eq(lesson_practice_matching_rounds(session, different).length(), 0)
}
