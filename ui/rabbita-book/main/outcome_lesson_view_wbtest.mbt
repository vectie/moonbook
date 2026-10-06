///|
test "outcome lesson UI exposes complete guidance scope and source before review" {
  let source = draft_test_record("lesson")
  let lesson : Json = {
    "guidance": "Exact guidance <&> 中文\nNext line",
    "applicability": [
      { "key": "customer_id", "value": "customer-a" },
      { "key": "decision_kind", "value": "vendor-comparison" },
    ],
    "invalidation": [{ "key": "evidence_state", "value": "superseded" }],
    "outcome": source.record.to_json(),
    "assessment": source.record.to_json(),
    "assessment_review": source.record.to_json(),
  }
  let record = {
    ..source,
    payload: {
      "candidate_schema": "outcome_lesson.v1",
      "outcome_lesson": lesson,
    },
  }
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model=record,
      update=fn(_message : Unit, old) { old },
      view=fn(_emit, model) { outcome_lesson_review_detail(model) },
    ),
  )
  for
    text in [
      "Reusable outcome lesson", "Exact guidance &lt;&amp;&gt; 中文", "customer_id = customer-a",
      "decision_kind = vendor-comparison", "evidence_state = superseded", "Original outcome and review references",
      "digest-v1", "Retrieve for the next task", "cmd/outcome_lessons",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_true(html.contains("does not activate a capability"))
}

///|
test "ordinary artifacts do not acquire a lesson claim and malformed scope stays visible" {
  assert_eq(outcome_lesson_condition_lines({}), [
    "Conditions are unavailable. Inspect the exact evidence before reviewing.",
  ])
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model=draft_test_record("ordinary"),
      update=fn(_message : Unit, old) { old },
      view=fn(_emit, model) { outcome_lesson_review_detail(model) },
    ),
  )
  assert_false(html.contains("Reusable outcome lesson"))
}
