///|
fn lesson_correction_draft_fields(change : LessonHistoryChange) -> Json {
  let fields : Map[String, Json] = Map([])
  for
    key in [
      "title", "version", "guidance", "reason", "applicability", "invalidation",
    ] {
    fields[key] = lesson_change_field(change, key).to_json()
  }
  Json::object(fields)
}

///|
fn lesson_correction_draft_pristine(change : LessonHistoryChange) -> Bool {
  guard change.revision_rehearsal == Json::null() &&
    lesson_record_value(change.original) is Some(original) else {
    return false
  }
  lesson_change_field(change, "version") == "" &&
  lesson_change_field(change, "reason") == "" &&
  lesson_change_field(change, "title") == lesson_task_text(original, "title") &&
  lesson_change_field(change, "guidance") ==
  lesson_task_text(original, "guidance") &&
  lesson_change_field(change, "applicability") ==
  lesson_condition_edit_text(lesson_task_field(original, "applicability")) &&
  lesson_change_field(change, "invalidation") ==
  lesson_condition_edit_text(lesson_task_field(original, "invalidation"))
}

///|
fn lesson_correction_draft_owner(model : Model) -> Json {
  guard model.outcome_lessons.history.change is Some(change) else {
    return Json::null()
  }
  {
    "workspace": model.state.bookkeeper.source_path,
    "lesson_id": model.outcome_lessons.history.lesson_id,
    "request": model.outcome_lessons.request,
    "context": lesson_revision_rehearsal_context(model.outcome_lessons.history),
    "revision": lesson_task_field(change.revision_rehearsal, "revision"),
    "fields": lesson_correction_draft_fields(change),
    "recovery": change.correction_recovery,
  }
}

///|
fn lesson_correction_draft_action(model : Model, operation : String) -> Json {
  { "operation": operation, "owner": lesson_correction_draft_owner(model) }
}

///|
fn lesson_correction_draft_update(
  model : Model,
  action : Json,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  guard state.history.change is Some(change) else {
    return (@rabbita.none, model)
  }
  if state.pending ||
    lesson_task_field(action, "owner") != lesson_correction_draft_owner(model) {
    return (@rabbita.none, model)
  }
  let operation = lesson_task_text(action, "operation")
  if (operation == "save" || operation == "resume") &&
    (
      model.loading ||
      model.error is Some(_) ||
      model.bookkeeper_reads.store_loading ||
      model.bookkeeper_reads.store_error is Some(_)
    ) {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          history: {
            ..state.history,
            notice: "Reload the Book and current Bookkeeper records before saving or resuming this correction.",
          },
        },
      },
    )
  }
  let context = lesson_revision_rehearsal_context(state.history)
  let inspection = lesson_revision_rehearsal_transition(
    state.history,
    false,
    { "kind": "inspect" },
    request_id=state.request,
  )
  let request : Json = {
    "operation": operation,
    "workspace": model.state.bookkeeper.source_path,
    "lesson_id": state.history.lesson_id,
    "context": context,
    "retained": lesson_retained_cases(context),
    "current": lesson_task_field(inspection, "current"),
    "pristine": lesson_correction_draft_pristine(change),
    "fields": lesson_correction_draft_fields(change),
    "rehearsal": change.revision_rehearsal,
    "recovery": change.correction_recovery,
  }
  let result = @json.parse(
    lesson_correction_draft_storage_json(request.stringify()),
  ) catch {
    _ =>
      (
        {
          "error": "Browser correction storage returned an unreadable response. Your draft is kept.",
        } : Json)
  }
  if result is { "error": String(error), .. } {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          history: { ..state.history, notice: error, },
        },
      },
    )
  }
  let fields = change.fields.copy()
  let restored = lesson_task_field(result, "fields")
  if restored != Json::null() {
    for
      key in [
        "title", "version", "guidance", "reason", "applicability", "invalidation",
      ] {
      fields[key] = lesson_task_text(restored, key)
    }
  }
  let recovery = lesson_task_field(result, "recovery")
  (
    @rabbita.none,
    {
      ..model,
      outcome_lessons: {
        ..state,
        request: state.request + 1,
        history: {
          ..state.history,
          change: Some({
            ..change,
            fields,
            correction_recovery: recovery,
            revision_rehearsal: if restored != Json::null() {
              lesson_task_field(result, "rehearsal")
            } else {
              change.revision_rehearsal
            },
          }),
          result: if restored != Json::null() {
            None
          } else {
            state.history.result
          },
          notice: lesson_task_text(recovery, "notice"),
        },
      },
    },
  )
}
