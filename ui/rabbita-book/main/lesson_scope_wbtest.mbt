///|
fn scope_test_model() -> Model {
  let model = browser_test_model()
  let fields = model.outcome_lessons.fields.copy()
  fields["task-id"] = "later-task"
  fields["task-version"] = "1"
  fields["task-digest"] = "later-digest"
  fields["query-customer"] = ""
  fields["query-decision"] = ""
  fields["query-extra"] = ""
  { ..model, outcome_lessons: { ..model.outcome_lessons, fields, }, }
}

///|
fn scope_test_action(
  model : Model,
  action : String,
  condition? : Json = Json::null(),
) -> Msg {
  OutcomeLesson(
    ScopeInterview(
      action,
      model.outcome_lessons.scope_interview,
      lesson_scope_binding(model.outcome_lessons),
      condition,
    ),
  )
}

///|
test "scope interview discovers required and invalidation questions without inferring answers" {
  let model = scope_test_model()
  let state = model.outcome_lessons
  let questions = lesson_scope_questions(state)
  assert_true(questions.length() >= 2)
  assert_true(
    questions.contains({ "key": "evidence_state", "value": "superseded" }),
  )
  assert_eq(lesson_scope_answers(state).length(), 0)
  assert_eq(lesson_scope_conditions(state).unwrap().length(), 0)
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_ : Msg, old) { old },
      view=lesson_scope_view,
    ),
  )
  assert_true(html.contains("Unknown: answer"))
  assert_true(html.contains("not evidence about your task"))
  assert_true(html.contains("Evidence comparison &lt;&amp;&gt; 中文"))
}

///|
test "staging answers narrows questions and keeps task and lesson drafts untouched until apply" {
  let model = scope_test_model()
  let question = lesson_scope_questions(model.outcome_lessons)[0]
  let answered = snapshot_test_step(
    model,
    scope_test_action(model, "answer", condition=question),
  )
  assert_eq(answered.outcome_lessons.fields, model.outcome_lessons.fields)
  assert_eq(answered.outcome_lessons.result, model.outcome_lessons.result)
  assert_eq(lesson_scope_answers(answered.outcome_lessons), [question])
  assert_true(
    !lesson_scope_questions(answered.outcome_lessons).contains(question),
  )
  let duplicate = snapshot_test_step(
    answered,
    scope_test_action(model, "answer", condition=question),
  )
  assert_eq(
    duplicate.outcome_lessons.scope_interview,
    answered.outcome_lessons.scope_interview,
  )
  let removed = snapshot_test_step(
    answered,
    scope_test_action(answered, "remove", condition=question),
  )
  assert_eq(lesson_scope_answers(removed.outcome_lessons), [])
  let canceled = snapshot_test_step(
    answered,
    scope_test_action(answered, "reset"),
  )
  assert_eq(canceled.outcome_lessons.scope_interview, initial_lesson_scope())
  assert_eq(canceled.outcome_lessons.fields, model.outcome_lessons.fields)
}

///|
test "scope contradictions invalidations and unresolved safety conditions stay distinct" {
  let lesson : Json = {
    "applicability": [{ "key": "customer_id", "value": "a" }],
    "invalidation": [{ "key": "evidence_state", "value": "superseded" }],
  }
  assert_true(lesson_scope_status(lesson, []).has_prefix("Unknown:"))
  assert_true(
    lesson_scope_status(lesson, [{ "key": "customer_id", "value": "b" }]).contains(
      "conflicts",
    ),
  )
  assert_true(
    lesson_scope_status(lesson, [
      { "key": "evidence_state", "value": "superseded" },
    ]).contains("do-not-use condition is present"),
  )
  assert_true(
    lesson_scope_status(lesson, [{ "key": "customer_id", "value": "a" }]).contains(
      "still need checking",
    ),
  )
  assert_true(
    lesson_scope_status(lesson, [
      { "key": "customer_id", "value": "a" },
      { "key": "evidence_state", "value": "current" },
    ]).has_prefix("Scope matches"),
  )
}

///|
test "task edit lesson revision and reload invalidate staged answers while reset remains available" {
  let model = scope_test_model()
  let question = lesson_scope_questions(model.outcome_lessons)[0]
  let answered = snapshot_test_step(
    model,
    scope_test_action(model, "answer", condition=question),
  )
  let edited = snapshot_test_step(
    answered,
    OutcomeLesson(Edit("task-digest", "new-digest")),
  )
  let blocked = snapshot_test_step(edited, scope_test_action(edited, "apply"))
  assert_true(!blocked.outcome_lessons.pending)
  assert_true(blocked.outcome_lessons.notice.contains("changed"))
  assert_eq(lesson_scope_answers(blocked.outcome_lessons), [question])
  let data = answered.outcome_lessons.browser.data.unwrap()
  let first = data.lessons[0]
  let revised = {
    ..first,
    selection_review: {
      "record_id": "new",
      "record_version": "2",
      "record_digest": "changed",
    },
  }
  let changed = {
    ..answered,
    outcome_lessons: {
      ..answered.outcome_lessons,
      browser: {
        ..answered.outcome_lessons.browser,
        data: Some({ ..data, lessons: [revised], }),
      },
    },
  }
  let blocked = snapshot_test_step(changed, scope_test_action(changed, "apply"))
  assert_true(blocked.outcome_lessons.notice.contains("changed"))
  let reset = snapshot_test_step(blocked, scope_test_action(blocked, "reset"))
  assert_eq(reset.outcome_lessons.scope_interview, initial_lesson_scope())
}

///|
test "applying answers starts existing exact retrieval and never selects or authorizes guidance" {
  let model = scope_test_model()
  let question = lesson_scope_questions(model.outcome_lessons)[0]
  let answered = snapshot_test_step(
    model,
    scope_test_action(model, "answer", condition=question),
  )
  let applied = snapshot_test_step(
    answered,
    scope_test_action(answered, "apply"),
  )
  assert_true(applied.outcome_lessons.pending)
  let payload = lesson_ui_payload(applied.outcome_lessons, "retrieve").unwrap()
  assert_true(
    lesson_task_field(payload, "conditions") is Array(values) &&
    values.contains(question),
  )
  assert_eq(
    lesson_task_text(lesson_task_field(payload, "target_task"), "record_digest"),
    "later-digest",
  )
  assert_eq(applied.outcome_lessons.scope_interview, initial_lesson_scope())
  assert_eq(applied.outcome_lessons.task_guidance.selection, None)
  assert_eq(
    applied.outcome_lessons.fields.get("guidance"),
    model.outcome_lessons.fields.get("guidance"),
  )
  let repeated = snapshot_test_step(
    applied,
    scope_test_action(answered, "apply"),
  )
  assert_eq(repeated.outcome_lessons.request, applied.outcome_lessons.request)
}

///|
test "unknown choices malformed conditions and pending actions cannot mutate query" {
  let model = scope_test_model()
  let forged = snapshot_test_step(
    model,
    scope_test_action(model, "answer", condition={
      "key": "invented",
      "value": "true",
    }),
  )
  assert_eq(forged.outcome_lessons.scope_interview, initial_lesson_scope())
  let bad = snapshot_test_step(
    model,
    OutcomeLesson(Edit("query-extra", "broken")),
  )
  assert_eq(lesson_scope_questions(bad.outcome_lessons), [])
  let pending = {
    ..model,
    outcome_lessons: { ..model.outcome_lessons, pending: true, },
  }
  let question = lesson_scope_questions(model.outcome_lessons)[0]
  let blocked = snapshot_test_step(
    pending,
    scope_test_action(pending, "answer", condition=question),
  )
  assert_eq(blocked.outcome_lessons.scope_interview, initial_lesson_scope())
}

///|
test "ambiguous observed values remain choices and the user's answer excludes conflicting lessons" {
  let model = scope_test_model()
  let data = model.outcome_lessons.browser.data.unwrap()
  let first = data.lessons[0]
  let lesson = lesson_record_value(first.lesson).unwrap()
  let other = {
    ..first,
    lesson: {
      ..first.lesson,
      payload: {
        "candidate_schema": "outcome_lesson.v1",
        "outcome_lesson": browser_test_set(lesson, "applicability", [
          { "key": "customer_id", "value": "different-customer" },
        ]),
      },
    },
  }
  let model = {
    ..model,
    outcome_lessons: {
      ..model.outcome_lessons,
      browser: {
        ..model.outcome_lessons.browser,
        data: Some({ ..data, lessons: [first, other], }),
      },
    },
  }
  let question : Json = { "key": "customer_id", "value": "different-customer" }
  let questions = lesson_scope_questions(model.outcome_lessons)
  assert_true(questions.contains(question))
  assert_true(
    questions.filter(c => lesson_task_text(c, "key") == "customer_id").length() ==
    2,
  )
  let answered = snapshot_test_step(
    model,
    scope_test_action(model, "answer", condition=question),
  )
  let conditions = lesson_scope_conditions(answered.outcome_lessons).unwrap()
  assert_true(lesson_scope_status(lesson, conditions).contains("conflicts"))
  assert_true(
    !lesson_scope_status(lesson_record_value(other.lesson).unwrap(), conditions).contains(
      "conflicts",
    ),
  )
}

///|
test "changed lesson bytes or browser reload blocks old answers and query application preserves rehearsal" {
  let model = scope_test_model()
  let model = {
    ..model,
    outcome_lessons: {
      ..model.outcome_lessons,
      rehearsal_request: Some({ "sample": "keep" }),
      rehearsal_result: Some({ "preview": "keep" }),
    },
  }
  let question = lesson_scope_questions(model.outcome_lessons)[0]
  let answered = snapshot_test_step(
    model,
    scope_test_action(model, "answer", condition=question),
  )
  let data = answered.outcome_lessons.browser.data.unwrap()
  let first = data.lessons[0]
  let revised = {
    ..first,
    lesson: {
      ..first.lesson,
      record: {
        ..first.lesson.record,
        record_version: "3",
        record_digest: "new-bytes",
      },
    },
  }
  let revised_model = {
    ..answered,
    outcome_lessons: {
      ..answered.outcome_lessons,
      browser: {
        ..answered.outcome_lessons.browser,
        data: Some({ ..data, lessons: [revised], }),
      },
    },
  }
  let blocked = snapshot_test_step(
    revised_model,
    scope_test_action(revised_model, "apply"),
  )
  assert_true(blocked.outcome_lessons.notice.contains("changed"))
  let reloaded = {
    ..answered,
    outcome_lessons: {
      ..answered.outcome_lessons,
      browser: {
        ..answered.outcome_lessons.browser,
        request: answered.outcome_lessons.browser.request + 1,
      },
    },
  }
  let blocked = snapshot_test_step(
    reloaded,
    scope_test_action(reloaded, "apply"),
  )
  assert_true(blocked.outcome_lessons.notice.contains("changed"))
  let applied = snapshot_test_step(
    answered,
    scope_test_action(answered, "apply"),
  )
  assert_eq(
    applied.outcome_lessons.rehearsal_request,
    model.outcome_lessons.rehearsal_request,
  )
  assert_eq(
    applied.outcome_lessons.rehearsal_result,
    model.outcome_lessons.rehearsal_result,
  )
}
