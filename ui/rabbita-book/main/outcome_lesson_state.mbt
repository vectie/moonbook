///|
priv struct OutcomeLessonWorkspace {
  fields : Map[String, String]
  source : Json?
  source_label : String
  lesson_id : String
  recorded_at : Int
  request : Int
  pending : Bool
  notice : String
  result : Json?
  handoff : Json?
  history : LessonHistoryWorkspace
  saved_return : SavedLessonReturn
  outcome_review : OutcomeReviewWorkspace
  task_guidance : TaskGuidanceWorkspace
}

///|
priv enum OutcomeLessonMsg {
  Edit(String, String)
  UseSelected
  Submit(String)
  Finished(Int, String, Result[Json, String])
  ImportTask
  ReceiveTask
  TaskImported(Int, Bool, Result[String, String])
  TaskResolved(Int, Bool, Result[Json, String])
  UseTask(Int)
  OpenHistory
  RefreshHistory
  ChooseHistoryVersion(BookkeeperRecordReference)
  StartHistoryChange(String)
  EditHistory(String, String)
  DiscardHistoryChange
  SubmitHistoryChange
  HistoryFinished(Int, String, Result[Json, String])
  ChooseSavedLesson(BookkeeperRecordReference)
  RefreshSavedLessons(String)
  SavedLessonsRead(Int, String, Result[Json, String])
  SavedLessonReturned(Int, Bool)
  OutcomeReview(OutcomeReviewMsg)
  TaskGuidance(TaskGuidanceMsg)
}

///|
fn initial_outcome_lesson_workspace() -> OutcomeLessonWorkspace {
  {
    fields: {
      "title": "",
      "guidance": "",
      "customer": "",
      "decision": "",
      "extra": "",
      "invalid": "",
      "version": "1",
      "task-id": "",
      "task-version": "1",
      "task-digest": "",
      "query-customer": "",
      "query-decision": "",
      "query-extra": "",
    },
    source: None,
    source_label: "No assessment selected for this draft",
    lesson_id: "",
    recorded_at: 0,
    request: 0,
    pending: false,
    notice: "",
    result: None,
    handoff: None,
    history: initial_lesson_history_workspace(),
    saved_return: initial_saved_lesson_return(),
    outcome_review: initial_outcome_review_workspace(),
    task_guidance: initial_task_guidance_workspace(),
  }
}

///|
fn lesson_field(state : OutcomeLessonWorkspace, key : String) -> String {
  state.fields.get(key).unwrap_or("")
}

///|
fn lesson_ui_conditions(
  customer : String,
  decision : String,
  extra : String,
) -> Result[Array[Json], String] {
  let result : Array[Json] = []
  let keys : Array[String] = []
  for (key, value) in [("customer_id", customer), ("decision_kind", decision)] {
    if !value.is_blank() {
      result.push({ "key": key, "value": value })
      keys.push(key)
    }
  }
  for raw in extra.split("\n") {
    let line = raw.trim().to_owned()
    if line.is_empty() {
      continue
    }
    let parts = line.split("=").to_array()
    if parts.length() < 2 {
      return Err("Additional conditions need one key=value per line.")
    }
    let key = parts[0].trim().to_owned()
    let value = parts[1:]
      .map(part => part.to_owned())
      .join("=")
      .trim()
      .to_owned()
    if key.is_blank() || value.is_blank() || keys.contains(key) {
      return Err(
        "Condition names must be unique, with a name and value on each line.",
      )
    }
    result.push({ "key": key, "value": value })
    keys.push(key)
  }
  Ok(result)
}

///|
fn lesson_selected_source(model : Model) -> Result[(Json, String), String] {
  if model.bookkeeper_reads.store_loading ||
    model.bookkeeper_reads.store_error is Some(_) {
    return Err(
      "Reload the current Bookkeeper records before selecting a lesson source.",
    )
  }
  guard model.selected_bookkeeper_record is Some(reference) &&
    selected_raw_record(model, reference) is Some(record) &&
    model.bookkeeper_store is Some(snapshot) else {
    return Err(
      "Select a reviewed Three-Gap assessment in the Bookkeeper lanes.",
    )
  }
  if !bookkeeper_enum_is(record.stage, "ThreeGapFinding") ||
    !snapshot.replay_issues.is_empty() {
    return Err("Select a reviewed Three-Gap assessment from a clean journal.")
  }
  guard record.subject is Some(outcome) else {
    return Err("The assessment has no exact outcome.")
  }
  let decisions = snapshot.reviews.filter(review => {
    review.subject == record.record &&
    review.review_complete &&
    (review.disposition == "Accept" || review.disposition == "Reject") &&
    bookkeeper_enum_is(review.reviewer_kind, "Human")
  })
  if decisions.length() != 1 || decisions[0].disposition != "Accept" {
    return Err(
      "The selected assessment needs one named-human acceptance before a lesson can be prepared.",
    )
  }
  Ok(
    (
      {
        "outcome": outcome.to_json(),
        "assessment": reference.to_json(),
        "assessment_review": decisions[0].receipt.to_json(),
      },
      record.title + " · " + reference.record_id,
    ),
  )
}

///|
fn lesson_ui_payload(
  state : OutcomeLessonWorkspace,
  operation : String,
) -> Result[Json, String] {
  let query = operation == "retrieve"
  let conditions = match
    lesson_ui_conditions(
      lesson_field(state, if query { "query-customer" } else { "customer" }),
      lesson_field(state, if query { "query-decision" } else { "decision" }),
      lesson_field(state, if query { "query-extra" } else { "extra" }),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if query {
    let id = lesson_field(state, "task-id")
    let version = lesson_field(state, "task-version")
    let digest = lesson_field(state, "task-digest")
    if id.is_blank() || version.is_blank() || digest.is_blank() {
      return Err("Enter the later task's ID, version and exact digest.")
    }
    let payload : Json = {
      "contract_version": "moonbook.outcome-lesson-query.v1",
      "target_task": {
        "record_id": id,
        "record_version": version,
        "record_digest": digest,
      },
      "conditions": conditions.to_json(),
    }
    if state.task_guidance.handoff is Some(handoff) &&
      !task_guidance_query_matches(handoff, payload) {
      return Err(
        "Keep this task's captured identity, project and suite-product conditions. Cancel its handoff to query another task.",
      )
    }
    return Ok(payload)
  }
  guard state.source
    is Some(
      {
        "outcome": outcome,
        "assessment": assessment,
        "assessment_review": review,
        ..
      }
    ) else {
    return Err(
      "Use a selected reviewed assessment as the lesson's source first.",
    )
  }
  if lesson_field(state, "title").is_blank() ||
    lesson_field(state, "guidance").is_blank() ||
    conditions.is_empty() ||
    lesson_field(state, "version").is_blank() {
    return Err(
      "Add a title, lesson guidance, version and at least one condition for when to use it.",
    )
  }
  let invalid = match
    lesson_ui_conditions("", "", lesson_field(state, "invalid")) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    "contract_version": "moonbook.outcome-lesson.v1",
    "lesson_id": state.lesson_id,
    "lesson_version": lesson_field(state, "version"),
    "title": lesson_field(state, "title"),
    "guidance": lesson_field(state, "guidance"),
    "outcome": outcome,
    "assessment": assessment,
    "assessment_review": review,
    "applicability": conditions.to_json(),
    "invalidation": invalid.to_json(),
    "recorded_at": state.recorded_at,
  })
}

///|
fn lesson_ui_edit(
  state : OutcomeLessonWorkspace,
  key : String,
  value : String,
) -> OutcomeLessonWorkspace {
  if state.pending {
    return state
  }
  let fields = state.fields.copy()
  fields[key] = value
  { ..state, fields, result: None, notice: "", request: state.request + 1, }
}

///|
fn lesson_ui_finished(
  state : OutcomeLessonWorkspace,
  request : Int,
  operation : String,
  result : Result[Json, String],
) -> OutcomeLessonWorkspace {
  if !state.pending || request != state.request {
    return state
  }
  match result {
    Err(error) =>
      {
        ..state,
        pending: false,
        notice: "Request did not finish: " +
        error +
        ". Your draft is still here; retrying unchanged content uses the same lesson identity.",
      }
    Ok(value) =>
      {
        ..state,
        pending: false,
        result: Some(value),
        notice: if operation == "prepare" {
          "Lesson saved for review. Select it in the Bookkeeper lane, inspect the conditions, then prepare acceptance or rejection."
        } else {
          "These results belong to the task and conditions shown below. Check their applicability before reuse."
        },
      }
  }
}

///|
fn decode_outcome_lesson_response(
  operation : String,
  payload : Json,
  response : BookkeeperBrowserResponse,
) -> Result[Json, String] {
  let value = @json.parse(response.body) catch {
    _ =>
      return Err(
        response.error.unwrap_or(
          "The Book host did not return a readable lesson response",
        ),
      )
  }
  match value {
    {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "ok": true,
      "operation": String(actual),
      "result": result,
      ..
    } if response.ok && actual == operation => {
      if operation == "prepare" ||
        operation == "revise" ||
        operation == "select" {
        guard result
          is {
            "accepted": true,
            "event": {
              "record_id": String(id),
              "record_version": String(version),
              "record_digest": String(digest),
              ..
            },
            ..
          } &&
          !id.is_blank() &&
          !version.is_blank() &&
          !digest.is_blank() else {
          return Err("The Book host did not confirm a saved lesson reference")
        }
      } else if operation == "history" {
        let history = match parse_lesson_history(result) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        if history.contract_version != "moonbook.outcome-lesson-history.v1" ||
          lesson_task_text(payload, "lesson_id") != history.lesson_id {
          return Err("The lesson history does not match the selected lesson")
        }
      } else if operation == "task-handoff" ||
        operation == "outcome-import" ||
        operation == "outcome-continue" {
        guard result
          is {
            "contract_version": "moonbook.task-lesson-readback.v1",
            "handoff": actual,
            "sources": Array(_),
            "pending": Array(_),
            "state": String(_),
            "activation_authorized": false,
            "external_side_effects_applied": false,
            ..
          } &&
          actual ==
          (if operation == "task-handoff" {
            payload
          } else {
            lesson_task_field(payload, "handoff")
          }) else {
          return Err(
            "Book did not read back this exact task and report binding",
          )
        }
        if operation != "task-handoff" {
          let submission = lesson_task_field(payload, "submission")
          let reference = if operation == "outcome-import" {
            lesson_task_field(submission, "submission")
          } else {
            submission
          }
          if saved_lesson_reference(reference) is None ||
            !outcome_review_items(result).any(item => {
              lesson_task_field(item, "submission") == reference
            }) {
            return Err("Book did not read back this exact outcome submission")
          }
        }
      } else {
        guard result
          is {
            "contract_version": "moonbook.outcome-lesson-retrieval.v1",
            "query": query,
            "matches": Array(_),
            "exclusions": Array(_),
            "activation_authorized": false,
            "external_side_effects_applied": false,
            ..
          } &&
          query == payload else {
          return Err(
            "The lesson response does not match this exact task and conditions",
          )
        }
      }
      Ok(result)
    }
    { "error": String(error), .. } => Err(error)
    _ => Err("The Book host returned an unsupported lesson response")
  }
}

///|
async fn post_outcome_lesson(
  operation : String,
  payload : Json,
  send? : (String, String) -> @js.Promise = post_bookkeeper_json,
) -> Result[Json, String] noraise {
  let response = await_bookkeeper_response(
    send("/api/bookkeeper/lessons/" + operation, payload.stringify()),
  )
  decode_outcome_lesson_response(operation, payload, response)
}

///|
fn outcome_lesson_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : OutcomeLessonMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  let (command, next) = match message {
    TaskGuidance(action) => task_guidance_update(emit, model, action)
    RefreshSavedLessons(_) if state.outcome_review.pending =>
      (@rabbita.none, model)
    OutcomeReview(message) => outcome_review_update(emit, model, message)
    ChooseSavedLesson(_)
    | RefreshSavedLessons(_)
    | SavedLessonsRead(_, _, _)
    | SavedLessonReturned(_, _) =>
      saved_lesson_return_update(emit, model, message)
    OpenHistory
    | RefreshHistory
    | ChooseHistoryVersion(_)
    | StartHistoryChange(_)
    | EditHistory(_, _)
    | DiscardHistoryChange
    | SubmitHistoryChange
    | HistoryFinished(_, _, _) => lesson_history_update(emit, model, message)
    ImportTask
    | ReceiveTask
    | TaskImported(_, _, _)
    | TaskResolved(_, _, _)
    | UseTask(_) => lesson_task_handoff_update(emit, model, message)
    Edit(key, value) =>
      (
        @rabbita.none,
        { ..model, outcome_lessons: lesson_ui_edit(state, key, value), },
      )
    UseSelected => {
      if state.pending {
        return (@rabbita.none, model)
      }
      match lesson_selected_source(model) {
        Err(error) =>
          (
            @rabbita.none,
            { ..model, outcome_lessons: { ..state, notice: error, }, },
          )
        Ok((source, label)) => {
          if state.source == Some(source) && !state.lesson_id.is_blank() {
            return (@rabbita.none, model)
          }
          (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..state,
                source: Some(source),
                source_label: label,
                lesson_id: "lesson-" + bookkeeper_nonce(),
                recorded_at: bookkeeper_unix_seconds(),
                result: None,
                request: state.request + 1,
                notice: "Source selected for a new lesson. Your written guidance and conditions were kept.",
              },
            },
          )
        }
      }
    }
    Submit(operation) => {
      if state.pending {
        return (@rabbita.none, model)
      }
      match lesson_ui_payload(state, operation) {
        Err(error) =>
          (
            @rabbita.none,
            { ..model, outcome_lessons: { ..state, notice: error, }, },
          )
        Ok(payload) => {
          let request = state.request + 1
          (
            @rabbita.perform(
              result => {
                emit(OutcomeLesson(Finished(request, operation, result)))
              },
              async fn() noraise { post_outcome_lesson(operation, payload) },
            ),
            {
              ..model,
              outcome_lessons: {
                ..state,
                request,
                pending: true,
                result: None,
                notice: if operation == "prepare" {
                  "Saving the lesson candidate…"
                } else {
                  "Finding useful lessons…"
                },
              },
            },
          )
        }
      }
    }
    Finished(request, operation, result) => {
      let next = {
        ..model,
        outcome_lessons: lesson_ui_finished(state, request, operation, result),
      }
      if state.pending &&
        state.request == request &&
        operation == "prepare" &&
        result is Ok(_) {
        let (cmd, refreshed) = start_bookkeeper_read(emit, next)
        (@rabbita.batch([cmd, emit(RefreshSnapshot)]), refreshed)
      } else {
        (@rabbita.none, next)
      }
    }
  }
  let (refresh, next) = outcome_review_drain_refresh(emit, next)
  (@rabbita.batch([command, refresh]), next)
}
