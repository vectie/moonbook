///|
priv struct TaskGuidanceWorkspace {
  handoff : Json?
  selection : Json?
  busy : Bool
  confirmed_origin : String
  confirmed_handoff : Json?
}

///|
priv enum TaskGuidanceMsg {
  Receive
  ConfirmDestination(Json, String)
  Received(Int, Result[String, String])
  Resolved(Int, Json, Result[Json, String])
  Use(BookkeeperRecordReference)
  Selected(Int, Json, Result[Json, String])
  Returned(Int, Bool)
  Cancel
}

///|
fn initial_task_guidance_workspace() -> TaskGuidanceWorkspace {
  {
    handoff: None,
    selection: None,
    busy: false,
    confirmed_origin: "",
    confirmed_handoff: None,
  }
}

///|
fn task_guidance_keys(value : Json, keys : Array[String]) -> Bool {
  match value {
    Object(fields) =>
      fields.length() == keys.length() &&
      fields.keys().all(key => keys.contains(key))
    _ => false
  }
}

///|
fn task_guidance_minimal_result(value : Json) -> Bool {
  if !task_guidance_keys(value, [
      "contract_version", "handoff", "query", "lesson", "review", "source", "selection_review",
      "currentness", "journal_sequence", "applicability_decision_required", "activation_authorized",
      "external_side_effects_applied",
    ]) {
    return false
  }
  let lesson = lesson_task_field(value, "lesson")
  let review = lesson_task_field(value, "review")
  let source = lesson_task_field(value, "source")
  if !task_guidance_keys(lesson, [
      "reference", "title", "guidance", "applicability", "invalidation",
    ]) ||
    !task_guidance_keys(review, ["receipt", "reviewer_id", "decided_at"]) ||
    !task_guidance_keys(source, ["outcome", "assessment", "assessment_review"]) {
    return false
  }
  let references = [
    lesson_task_field(lesson, "reference"),
    lesson_task_field(review, "receipt"),
    lesson_task_field(source, "outcome"),
    lesson_task_field(source, "assessment"),
    lesson_task_field(source, "assessment_review"),
  ]
  let selection = lesson_task_field(value, "selection_review")
  if selection != Json::null() {
    references.push(selection)
  }
  if references.any(reference => {
      !task_guidance_keys(reference, [
        "record_id", "record_version", "record_digest",
      ]) ||
      saved_lesson_reference(reference) is None
    }) {
    return false
  }
  for key in ["applicability", "invalidation"] {
    guard lesson_task_field(lesson, key) is Array(conditions) &&
      conditions.all(condition => {
        task_guidance_keys(condition, ["key", "value"])
      }) else {
      return false
    }
  }
  true
}

///|
fn task_guidance_query_matches(handoff : Json, query : Json) -> Bool {
  if lesson_task_text(query, "contract_version") !=
    "moonbook.outcome-lesson-query.v1" ||
    lesson_task_field(query, "target_task") !=
    lesson_task_field(handoff, "target_task") {
    return false
  }
  match
    (
      lesson_task_field(handoff, "conditions"),
      lesson_task_field(query, "conditions"),
    ) {
    (Array(required), Array(actual)) =>
      required.all(condition => actual.contains(condition))
    _ => false
  }
}

///|
fn task_guidance_received(
  state : OutcomeLessonWorkspace,
  handoff : Json,
) -> OutcomeLessonWorkspace {
  let fields = state.fields.copy()
  let target = lesson_task_field(handoff, "target_task")
  for
    (key, source) in [
      ("task-id", "record_id"),
      ("task-version", "record_version"),
      ("task-digest", "record_digest"),
    ] {
    fields[key] = lesson_task_text(target, source)
  }
  fields["query-customer"] = ""
  fields["query-decision"] = ""
  fields["query-extra"] = match lesson_task_field(handoff, "conditions") {
    Array(values) =>
      values
      .map(item => {
        lesson_task_text(item, "key") + "=" + lesson_task_text(item, "value")
      })
      .join("\n")
    _ => ""
  }
  {
    ..state,
    fields,
    pending: false,
    result: None,
    task_guidance: {
      ..initial_task_guidance_workspace(),
      handoff: Some(handoff),
    },
    notice: "Task context received. Add this task's customer and kind of decision, then find useful lessons below. Your authored lesson draft was kept.",
  }
}

///|
fn task_guidance_selection_request(
  state : OutcomeLessonWorkspace,
  reference : BookkeeperRecordReference,
) -> Result[Json, String] {
  guard state.task_guidance.handoff is Some(handoff) &&
    state.result is Some(result) else {
    return Err("Receive a task and find matching lessons first.")
  }
  if state.task_guidance.confirmed_handoff != Some(handoff) ||
    state.task_guidance.confirmed_origin.is_empty() {
    return Err(
      "Confirm the exact Proj destination for this task before returning private guidance.",
    )
  }
  let query = match lesson_ui_payload(state, "retrieve") {
    Ok(query) => query
    Err(error) => return Err(error)
  }
  guard lesson_task_field(result, "query") == query &&
    lesson_task_field(result, "matches") is Array(matches) &&
    matches.any(item => {
      lesson_task_field(lesson_task_field(item, "lesson"), "record") ==
      reference.to_json()
    }) else {
    return Err(
      "Find lessons again for this exact task and conditions before choosing guidance.",
    )
  }
  Ok({ "handoff": handoff, "query": query, "lesson": reference.to_json() })
}

///|
fn task_guidance_decode(
  operation : String,
  payload : Json,
  response : BookkeeperBrowserResponse,
) -> Result[Json, String] {
  let value = @json.parse(response.body) catch {
    _ => return Err("The Book host did not return readable guidance")
  }
  guard response.ok &&
    value
    is {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "ok": true,
      "operation": String(actual),
      "result": result,
      ..
    } &&
    actual == operation else {
    let error = lesson_task_text(value, "error")
    return Err(
      if error.is_empty() {
        "The Book host did not confirm guidance"
      } else {
        error
      },
    )
  }
  if operation == "guidance-query" {
    if lesson_task_text(result, "contract_version") !=
      "moonbook.task-guidance-query-readback.v1" ||
      lesson_task_field(result, "handoff") != payload ||
      !task_guidance_query_matches(payload, lesson_task_field(result, "query")) {
      return Err("Book did not read back this exact target task")
    }
  } else if !task_guidance_minimal_result(result) ||
    lesson_task_text(result, "contract_version") !=
    "moonbook.task-guidance-selection.v1" ||
    lesson_task_field(result, "handoff") !=
    lesson_task_field(payload, "handoff") ||
    lesson_task_field(result, "query") != lesson_task_field(payload, "query") ||
    lesson_task_field(lesson_task_field(result, "lesson"), "reference") !=
    lesson_task_field(payload, "lesson") ||
    !["current", "legacy_unselected"].contains(
      lesson_task_text(result, "currentness"),
    ) ||
    lesson_task_field(result, "applicability_decision_required") !=
    true.to_json() {
    return Err("Book did not read back this exact current reviewed guidance")
  }
  if lesson_task_field(result, "activation_authorized") != false.to_json() ||
    lesson_task_field(result, "external_side_effects_applied") !=
    false.to_json() {
    return Err("Guidance must remain non-authorizing")
  }
  Ok(result)
}

///|
async fn post_task_guidance(
  operation : String,
  payload : Json,
) -> Result[Json, String] noraise {
  let response = await_bookkeeper_response(
    post_bookkeeper_json(
      "/api/bookkeeper/lessons/" + operation,
      payload.stringify(),
    ),
  )
  task_guidance_decode(operation, payload, response)
}

///|
fn task_guidance_export(
  value : Json,
  origin : String,
  observed_at : Int,
) -> Result[Json, String] {
  guard value is Object(fields) else {
    return Err("Guidance readback is unavailable")
  }
  let fields = fields.copy()
  fields["book_origin"] = origin.to_json()
  fields["observed_at"] = observed_at.to_json()
  let selection = Json::object(fields)
  if !task_guidance_export_fits(selection.stringify()) {
    return Err(
      "Selected guidance exceeds the export limit or its Book origin is unavailable. Nothing was truncated or returned.",
    )
  }
  Ok(selection)
}

///|
fn task_guidance_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  action : TaskGuidanceMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  match action {
    ConfirmDestination(handoff, origin) => {
      if state.pending ||
        state.task_guidance.handoff != Some(handoff) ||
        origin.is_empty() ||
        origin != task_guidance_incoming_origin() {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            task_guidance: {
              ..state.task_guidance,
              confirmed_handoff: Some(handoff),
              confirmed_origin: origin,
            },
            notice: "Destination confirmed for this exact task. Choose one reviewed lesson to return its guidance and review references.",
          },
        },
      )
    }
    Receive => {
      if state.pending || task_guidance_incoming_origin().is_empty() {
        return (@rabbita.none, model)
      }
      let request = state.request + 1
      (
        @rabbita.perform(
          result => emit(OutcomeLesson(TaskGuidance(Received(request, result)))),
          async fn() noraise {
            let text : String = task_guidance_receive_on(
                lesson_receiver_browser(),
              )
              .wait()
              .cast() catch {
                error => return Err("\{error}")
              }
            if text.is_empty() {
              Err(
                "No task received. Return to Proj and reopen guidance; ordinary Start is still available.",
              )
            } else {
              Ok(text)
            }
          },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request,
            pending: true,
            result: None,
            task_guidance: { ..initial_task_guidance_workspace(), busy: true, },
            notice: "Receiving the task selected in Proj…",
          },
        },
      )
    }
    Received(request, result) => {
      if !state.pending || state.request != request {
        return (@rabbita.none, model)
      }
      let handoff = match result {
        Ok(text) =>
          @json.parse(text) catch {
            _ =>
              return (
                @rabbita.none,
                {
                  ..model,
                  outcome_lessons: {
                    ..state,
                    pending: false,
                    task_guidance: { ..state.task_guidance, busy: false, },
                    notice: "Task query is not readable JSON. Nothing was shared.",
                  },
                },
              )
          }
        Err(error) =>
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..state,
                pending: false,
                task_guidance: { ..state.task_guidance, busy: false, },
                notice: error,
              },
            },
          )
      }
      (
        @rabbita.perform(
          result => {
            emit(
              OutcomeLesson(TaskGuidance(Resolved(request, handoff, result))),
            )
          },
          async fn() noraise { post_task_guidance("guidance-query", handoff) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            notice: "Checking the exact target task and its known scope…",
          },
        },
      )
    }
    Resolved(request, handoff, result) => {
      if !state.pending || state.request != request {
        return (@rabbita.none, model)
      }
      let next = match result {
        Ok(_) => task_guidance_received(state, handoff)
        Err(error) =>
          {
            ..state,
            pending: false,
            task_guidance: { ..state.task_guidance, busy: false, },
            notice: "Task guidance query was not accepted: " + error,
          }
      }
      (@rabbita.none, { ..model, outcome_lessons: next, })
    }
    Use(reference) => {
      if state.pending || task_guidance_incoming_origin().is_empty() {
        return (@rabbita.none, model)
      }
      if state.task_guidance.confirmed_origin != task_guidance_incoming_origin() {
        return (
          @rabbita.none,
          {
            ..model,
            outcome_lessons: {
              ..state,
              notice: "The requested destination changed. Receive and confirm the task again before sharing.",
            },
          },
        )
      }
      let payload = match task_guidance_selection_request(state, reference) {
        Ok(value) => value
        Err(error) =>
          return (
            @rabbita.none,
            { ..model, outcome_lessons: { ..state, notice: error, }, },
          )
      }
      let request = state.request + 1
      (
        @rabbita.perform(
          result => {
            emit(
              OutcomeLesson(TaskGuidance(Selected(request, payload, result))),
            )
          },
          async fn() noraise { post_task_guidance("guidance-select", payload) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request,
            pending: true,
            task_guidance: {
              ..state.task_guidance,
              selection: None,
              busy: true,
            },
            notice: "Rechecking this exact lesson and scope before returning only its guidance and review references…",
          },
        },
      )
    }
    Selected(request, payload, result) => {
      if !state.pending ||
        state.request != request ||
        state.task_guidance.handoff !=
        Some(lesson_task_field(payload, "handoff")) {
        return (@rabbita.none, model)
      }
      let selection = match result {
        Ok(value) =>
          task_guidance_export(
            value,
            lesson_return_book_origin(),
            bookkeeper_unix_seconds(),
          )
        Err(error) => Err(error)
      }
      let selection = match selection {
        Ok(value) => value
        Err(error) =>
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..state,
                pending: false,
                task_guidance: { ..state.task_guidance, busy: false, },
                notice: error,
              },
            },
          )
      }
      (
        @rabbita.perform(
          confirmed => {
            emit(OutcomeLesson(TaskGuidance(Returned(request, confirmed))))
          },
          async fn() noraise {
            let confirmed : Bool = task_guidance_send_on(
                lesson_receiver_browser(),
                selection.stringify(),
                state.task_guidance.confirmed_origin,
              )
              .wait()
              .cast() catch {
                _ => false
              }
            confirmed
          },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            task_guidance: {
              ..state.task_guidance,
              selection: Some(selection),
            },
            notice: "Returning the selected guidance to this Proj task…",
          },
        },
      )
    }
    Returned(request, confirmed) => {
      if !state.pending || state.request != request {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            pending: false,
            task_guidance: { ..state.task_guidance, busy: false, },
            notice: if confirmed {
              "Proj received this guidance for the selected task. It has not started execution; Proj captures the advice only when you choose Start."
            } else {
              "Proj did not acknowledge the guidance. Nothing is confirmed attached. Reopen from Proj or select the lesson again to retry."
            },
          },
        },
      )
    }
    Cancel => {
      if state.pending && !state.task_guidance.busy {
        return (@rabbita.none, model)
      }
      (
        @cmd.custom_cmd(_ => task_guidance_cancel_on(lesson_receiver_browser())),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request: state.request + 1,
            pending: false,
            result: None,
            task_guidance: initial_task_guidance_workspace(),
            notice: "Guidance handoff stopped. If you already chose Use, check Proj before starting. Your lesson draft is kept.",
          },
        },
      )
    }
  }
}
