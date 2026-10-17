///|
/// A local interview draft; observed lesson conditions are suggestions, never
/// assertions about the task until the operator explicitly answers and applies.
fn initial_lesson_scope() -> Json {
  { "binding": Json::null(), "answers": [] }
}

///|
fn lesson_scope_binding(state : OutcomeLessonWorkspace) -> Json {
  let records = match state.browser.data {
    Some(data) =>
      data.lessons.map(entry => {
        "lesson": ToJson::to_json(entry.lesson),
        "review": ToJson::to_json(entry.review.receipt),
        "selection_review": entry.selection_review,
      })
    None => []
  }
  {
    "fields": state.fields.to_json(),
    "request": state.request,
    "browser_request": state.browser.request,
    "records": records,
    "handoff": state.task_guidance.handoff.to_json(),
  }
}

///|
fn lesson_scope_answers(state : OutcomeLessonWorkspace) -> Array[Json] {
  match lesson_task_field(state.scope_interview, "answers") {
    Array(values) => values
    _ => []
  }
}

///|
fn lesson_scope_conditions(
  state : OutcomeLessonWorkspace,
) -> Result[Array[Json], String] {
  let base = match
    lesson_ui_conditions(
      lesson_field(state, "query-customer"),
      lesson_field(state, "query-decision"),
      lesson_field(state, "query-extra"),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(base + lesson_scope_answers(state))
}

///|
fn lesson_scope_status(lesson : Json, conditions : Array[Json]) -> String {
  let actual : Map[String, String] = {}
  for c in conditions {
    actual[lesson_task_text(c, "key")] = lesson_task_text(c, "value")
  }
  if lesson_task_field(lesson, "invalidation") is Array(invalid) &&
    invalid.any(c => {
      actual.get(lesson_task_text(c, "key")) ==
      Some(lesson_task_text(c, "value"))
    }) {
    return "Excluded: a do-not-use condition is present"
  }
  guard lesson_task_field(lesson, "applicability") is Array(required) else {
    return "Unavailable: unreadable scope"
  }
  if required.any(c => {
      let key = lesson_task_text(c, "key")
      actual.contains(key) &&
      actual.get(key) != Some(lesson_task_text(c, "value"))
    }) {
    return "Excluded: a required condition conflicts with this task"
  }
  if required.any(c => !actual.contains(lesson_task_text(c, "key"))) {
    return "Unknown: answer the missing scope questions"
  }
  if lesson_task_field(lesson, "invalidation") is Array(invalid) &&
    invalid.any(c => !actual.contains(lesson_task_text(c, "key"))) {
    return "Required scope matches; do-not-use conditions still need checking"
  }
  "Scope matches your answers; retrieve to recheck current review"
}

///|
fn lesson_scope_questions(state : OutcomeLessonWorkspace) -> Array[Json] {
  guard !state.browser.pending &&
    state.browser.error is None &&
    state.browser.data is Some(data) else {
    return []
  }
  let conditions = match lesson_scope_conditions(state) {
    Ok(value) => value
    Err(_) => return []
  }
  let questions : Array[Json] = []
  for entry in data.lessons {
    guard lesson_record_value(entry.lesson) is Some(lesson) else { continue }
    if lesson_scope_status(lesson, conditions).has_prefix("Excluded:") {
      continue
    }
    for kind in ["applicability", "invalidation"] {
      if lesson_task_field(lesson, kind) is Array(values) {
        for c in values {
          let key = lesson_task_text(c, "key")
          let value = lesson_task_text(c, "value")
          // The existing key=value wire cannot represent line breaks in values.
          if key.contains("=") ||
            key.contains("\n") ||
            key.contains("\r") ||
            value.contains("\n") ||
            value.contains("\r") ||
            key != key.trim().to_owned() ||
            value != value.trim().to_owned() {
            continue
          }
          if !conditions.any(other => lesson_task_text(other, "key") == key) &&
            !questions.contains(c) {
            questions.push(c)
          }
        }
      }
    }
  }
  questions
}

///|
fn lesson_scope_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  action : String,
  expected : Json,
  binding : Json,
  condition : Json,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  if state.pending || state.browser.pending || expected != state.scope_interview {
    return (@rabbita.none, model)
  }
  if action == "reset" {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          scope_interview: initial_lesson_scope(),
          notice: "Scope answers discarded. Existing task conditions and authored lesson are kept.",
        },
      },
    )
  }
  let old_binding = lesson_task_field(state.scope_interview, "binding")
  if binding != lesson_scope_binding(state) ||
    (old_binding != Json::null() && old_binding != binding) {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          notice: "Task or reviewed lessons changed. Discard the scope answers and answer again.",
        },
      },
    )
  }
  let answers = lesson_scope_answers(state)
  if action == "answer" {
    if !lesson_scope_questions(state).contains(condition) {
      return (@rabbita.none, model)
    }
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          scope_interview: {
            "binding": binding,
            "answers": (answers + [condition]).to_json(),
          },
          notice: "Answer staged. Apply answers and find lessons when the conditions are true for this task.",
        },
      },
    )
  }
  if action == "remove" {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          scope_interview: {
            "binding": binding,
            "answers": answers.filter(c => c != condition).to_json(),
          },
        },
      },
    )
  }
  if action != "apply" || answers.is_empty() {
    return (@rabbita.none, model)
  }
  // Reuse exact query validation before modifying the operator's query.
  if lesson_ui_payload(state, "retrieve") is Err(error) {
    return (
      @rabbita.none,
      { ..model, outcome_lessons: { ..state, notice: error, }, },
    )
  }
  let extra = lesson_field(state, "query-extra")
  let lines = answers
    .map(c => lesson_task_text(c, "key") + "=" + lesson_task_text(c, "value"))
    .join("\n")
  let fields = state.fields.copy()
  fields["query-extra"] = if extra.is_empty() {
    lines
  } else {
    extra + "\n" + lines
  }
  let next = {
    ..model,
    outcome_lessons: {
      ..state,
      fields,
      result: None,
      request: state.request + 1,
      scope_interview: initial_lesson_scope(),
    },
  }
  outcome_lesson_update(emit, next, Submit("retrieve"))
}
