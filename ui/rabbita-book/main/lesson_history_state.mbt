///|
priv struct LessonHistoryVersion {
  lesson : BookkeeperRawRecord
  reviews : Array[BookkeeperRawReview]
  current : Bool
} derive(FromJson)

///|
priv struct LessonHistorySelection {
  record : BookkeeperRawRecord
  reviews : Array[BookkeeperRawReview]
} derive(FromJson)

///|
priv struct LessonHistory {
  contract_version : String
  lesson_id : String
  current : BookkeeperRecordReference?
  head : BookkeeperRecordReference?
  accepted_reviews : Array[BookkeeperRecordReference]
  versions : Array[LessonHistoryVersion]
  selections : Array[LessonHistorySelection]
}

///|
priv struct LessonHistoryWire {
  contract_version : String
  lesson_id : String
  current : Json
  head : Json
  accepted_reviews : Array[BookkeeperRecordReference]
  versions : Array[LessonHistoryVersion]
  selections : Array[LessonHistorySelection]
} derive(FromJson)

///|
fn lesson_nullable_reference(
  value : Json,
) -> Result[BookkeeperRecordReference?, String] {
  if value is Null {
    return Ok(None)
  }
  let reference : BookkeeperRecordReference = @json.from_json(value) catch {
    _ => return Err("An exact lesson or review reference could not be read.")
  }
  if reference.record_id.is_blank() ||
    reference.record_version.is_blank() ||
    reference.record_digest.is_blank() {
    return Err("An exact lesson or review reference is incomplete.")
  }
  Ok(Some(reference))
}

///|
fn lesson_nullable_reference_json(
  reference : BookkeeperRecordReference?,
) -> Json {
  match reference {
    Some(value) => ToJson::to_json(value)
    None => Json::null()
  }
}

///|
fn parse_lesson_history(value : Json) -> Result[LessonHistory, String] {
  let wire : LessonHistoryWire = @json.from_json(value) catch {
    _ => return Err("The Book host did not return readable lesson history.")
  }
  let current = match lesson_nullable_reference(wire.current) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let head = match lesson_nullable_reference(wire.head) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    contract_version: wire.contract_version,
    lesson_id: wire.lesson_id,
    current,
    head,
    accepted_reviews: wire.accepted_reviews,
    versions: wire.versions,
    selections: wire.selections,
  })
}

///|
priv struct LessonHistoryChange {
  operation : String
  original : BookkeeperRawRecord
  predecessor : BookkeeperRawRecord?
  fields : Map[String, String]
  expected_head : BookkeeperRecordReference?
  accepted_reviews : Array[BookkeeperRecordReference]
  selection_id : String
  recorded_at : Int
}

///|
priv struct LessonHistoryWorkspace {
  lesson_id : String
  data : LessonHistory?
  selected : BookkeeperRecordReference?
  change : LessonHistoryChange?
  pending_operation : String
  result : Json?
  notice : String
}

///|
fn initial_lesson_history_workspace() -> LessonHistoryWorkspace {
  {
    lesson_id: "",
    data: None,
    selected: None,
    change: None,
    pending_operation: "",
    result: None,
    notice: "",
  }
}

///|
fn lesson_record_value(record : BookkeeperRawRecord) -> Json? {
  match record.payload {
    { "candidate_schema": String(schema), "outcome_lesson": value, .. } if schema ==
      "outcome_lesson.v1" ||
      schema == "outcome_lesson.v2" => Some(value)
    _ => None
  }
}

///|
fn lesson_history_source(model : Model) -> Result[BookkeeperRawRecord, String] {
  if model.bookkeeper_reads.store_loading ||
    model.bookkeeper_reads.store_error is Some(_) {
    return Err(
      "Reload the current Bookkeeper records before opening lesson history.",
    )
  }
  guard model.bookkeeper_store is Some(snapshot) &&
    snapshot.replay_issues.is_empty() &&
    model.selected_bookkeeper_record is Some(reference) else {
    return Err(
      "Select an outcome lesson in the Bookkeeper lanes, then open its history.",
    )
  }
  for record in snapshot.records {
    if record.record == reference && lesson_record_value(record) is Some(_) {
      return Ok(record)
    }
  }
  Err(
    "Select an outcome lesson in the Bookkeeper lanes, then open its history.",
  )
}

///|
fn lesson_history_record(
  history : LessonHistory,
  reference : BookkeeperRecordReference?,
) -> BookkeeperRawRecord? {
  guard reference is Some(reference) else { return None }
  for version in history.versions {
    if version.lesson.record == reference {
      return Some(version.lesson)
    }
  }
  None
}

///|
fn lesson_history_accepted(version : LessonHistoryVersion) -> Bool {
  let decisions = version.reviews.filter(review => {
    review.subject == version.lesson.record &&
    review.review_complete &&
    bookkeeper_enum_is(review.reviewer_kind, "Human") &&
    (review.disposition == "Accept" || review.disposition == "Reject")
  })
  decisions.length() == 1 &&
  decisions[0].disposition == "Accept" &&
  decisions[0].reviewer.authorized &&
  !decisions[0].reviewer.reviewer_id.is_blank() &&
  decisions[0].issues.is_empty() &&
  !decisions[0].side_effects_applied
}

///|
fn lesson_history_selected_accepted(
  state : LessonHistoryWorkspace,
) -> BookkeeperRawRecord? {
  guard state.data is Some(history) && state.selected is Some(reference) else {
    return None
  }
  for version in history.versions {
    if version.lesson.record == reference && lesson_history_accepted(version) {
      return Some(version.lesson)
    }
  }
  None
}

///|
fn lesson_history_can_revise(state : LessonHistoryWorkspace) -> Bool {
  guard state.data is Some(history) &&
    lesson_history_selected_accepted(state) is Some(original) else {
    return false
  }
  history.current is None || history.current == Some(original.record)
}

///|
fn lesson_condition_edit_text(value : Json) -> String {
  match value {
    Array(values) =>
      values
      .map(condition => {
        lesson_task_text(condition, "key") +
        "=" +
        lesson_task_text(condition, "value")
      })
      .join("\n")
    _ => ""
  }
}

///|
fn lesson_history_begin(
  state : LessonHistoryWorkspace,
  operation : String,
  nonce : String,
  recorded_at : Int,
) -> LessonHistoryWorkspace {
  if state.change is Some(_) {
    return state
  }
  guard (operation == "revise" || operation == "select") &&
    state.data is Some(history) &&
    lesson_history_selected_accepted(state) is Some(original) &&
    lesson_record_value(original) is Some(lesson) else {
    return {
      ..state,
      notice: "Select a named-human accepted version before proposing a change.",
    }
  }
  if operation == "select" && history.current == Some(original.record) {
    return { ..state, notice: "This version is already the current guidance.", }
  }
  if operation == "revise" && !lesson_history_can_revise(state) {
    return {
      ..state,
      notice: "This accepted version is not current. Choose or restore it as current through named-human review first, or select the current version to revise.",
    }
  }
  {
    ..state,
    change: Some({
      operation,
      original,
      predecessor: lesson_history_record(history, history.current),
      fields: {
        "title": lesson_task_text(lesson, "title"),
        "guidance": lesson_task_text(lesson, "guidance"),
        "version": "",
        "applicability": lesson_condition_edit_text(
          lesson_task_field(lesson, "applicability"),
        ),
        "invalidation": lesson_condition_edit_text(
          lesson_task_field(lesson, "invalidation"),
        ),
        "reason": "",
      },
      expected_head: history.head,
      accepted_reviews: history.accepted_reviews.copy(),
      selection_id: "lesson-selection-" + nonce,
      recorded_at,
    }),
    result: None,
    notice: "Change started from this exact accepted version. The original and current guidance remain below. Saving creates a candidate for the existing named-human review.",
  }
}

///|
fn lesson_change_field(change : LessonHistoryChange, key : String) -> String {
  change.fields.get(key).unwrap_or("")
}

///|
fn lesson_history_payload(
  state : LessonHistoryWorkspace,
) -> Result[Json, String] {
  guard state.change is Some(change) &&
    lesson_record_value(change.original) is Some(lesson) else {
    return Err("Start a revision or a current-version proposal first.")
  }
  if state.data is Some(data) &&
    (
      data.head != change.expected_head ||
      data.accepted_reviews != change.accepted_reviews
    ) {
    return Err(
      "History changed after this draft began. Your edits were kept; start a new proposal from the refreshed history before saving.",
    )
  }
  let reason = lesson_change_field(change, "reason")
  if reason.is_blank() {
    return Err("Explain why this change should be reviewed.")
  }
  let lesson_id = lesson_task_text(lesson, "lesson_id")
  if change.operation == "select" {
    return Ok({
      "contract_version": "moonbook.outcome-lesson-selection.v1",
      "selection_id": change.selection_id,
      "lesson_id": lesson_id,
      "target": ToJson::to_json(change.original.record),
      "expected_head": lesson_nullable_reference_json(change.expected_head),
      "accepted_reviews": change.accepted_reviews.to_json(),
      "reason": reason,
      "recorded_at": change.recorded_at,
    })
  }
  let version = lesson_change_field(change, "version")
  if version.is_blank() ||
    lesson_change_field(change, "title").is_blank() ||
    lesson_change_field(change, "guidance").is_blank() {
    return Err("Add a new version, title and revised guidance before saving.")
  }
  if state.data is Some(history) &&
    history.versions.any(item => item.lesson.record.record_version == version) {
    return Err(
      "That version already exists. Use a new version; original artifacts stay unchanged.",
    )
  }
  guard lesson is Object(original_fields) else {
    return Err("The original lesson is unreadable.")
  }
  let fields = original_fields.copy()
  for key in ["applicability", "invalidation"] {
    let text = lesson_change_field(change, key)
    let value = if text ==
      lesson_condition_edit_text(lesson_task_field(lesson, key)) {
      lesson_task_field(lesson, key)
    } else {
      match lesson_ui_conditions("", "", text) {
        Ok(conditions) => conditions.to_json()
        Err(error) => return Err(error)
      }
    }
    if key == "applicability" && value is [] {
      return Err(
        "Keep at least one condition for when the revised lesson applies.",
      )
    }
    fields[key] = value
  }
  fields["title"] = Json::string(lesson_change_field(change, "title"))
  fields["guidance"] = Json::string(lesson_change_field(change, "guidance"))
  fields["lesson_version"] = Json::string(version)
  fields["recorded_at"] = change.recorded_at.to_json()
  Ok({
    "contract_version": "moonbook.outcome-lesson-revision.v1",
    "lesson": Json::object(fields),
    "supersedes": ToJson::to_json(change.original.record),
    "expected_head": lesson_nullable_reference_json(change.expected_head),
    "accepted_reviews": change.accepted_reviews.to_json(),
    "reason": reason,
  })
}

///|
fn lesson_history_finished(
  state : OutcomeLessonWorkspace,
  request : Int,
  operation : String,
  result : Result[Json, String],
) -> OutcomeLessonWorkspace {
  if !state.pending ||
    state.request != request ||
    state.history.pending_operation != operation {
    return state
  }
  let history = { ..state.history, pending_operation: "", }
  match result {
    Err(error) =>
      {
        ..state,
        pending: false,
        history: {
          ..history,
          notice: "Request did not finish: " +
          error +
          ". Your change and captured comparison were kept. Refresh history to inspect any newer accepted choice; unchanged retries keep the same identity.",
        },
      }
    Ok(value) if operation == "history" => {
      let data = match parse_lesson_history(value) {
        Ok(data) => data
        Err(_) =>
          return {
            ..state,
            pending: false,
            history: {
              ..history,
              notice: "History could not be read. Your draft was kept.",
            },
          }
      }
      if data.lesson_id != history.lesson_id {
        return {
          ..state,
          pending: false,
          history: {
            ..history,
            notice: "History belongs to another lesson. Your draft was kept.",
          },
        }
      }
      let selected = if lesson_history_record(data, history.selected) is Some(_) {
        history.selected
      } else {
        match data.current {
          Some(reference) => Some(reference)
          None => data.versions.get(0).map(version => version.lesson.record)
        }
      }
      {
        ..state,
        pending: false,
        history: {
          ..history,
          data: Some(data),
          selected,
          notice: "History loaded. Inspect every saved version and its reviews; a new proposal only changes current guidance after named-human acceptance.",
        },
      }
    }
    Ok(value) =>
      {
        ..state,
        pending: false,
        history: {
          ..history,
          result: Some(value),
          notice: "Change saved for review. Open the saved proposal and use the existing named-human review controls. Current guidance has not changed.",
        },
      }
  }
}

///|
fn lesson_history_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : OutcomeLessonMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  let history = state.history
  match message {
    HistoryFinished(request, operation, result) => {
      let next = {
        ..model,
        outcome_lessons: lesson_history_finished(
          state, request, operation, result,
        ),
      }
      if state.pending &&
        state.request == request &&
        history.pending_operation == operation &&
        operation != "history" &&
        result is Ok(_) {
        let (cmd, refreshed) = start_bookkeeper_read(emit, next)
        return (@rabbita.batch([cmd, emit(RefreshSnapshot)]), refreshed)
      }
      (@rabbita.none, next)
    }
    _ if state.pending => (@rabbita.none, model)
    OpenHistory | RefreshHistory => {
      let (lesson_id, selected) = if message is OpenHistory {
        match lesson_history_source(model) {
          Err(error) =>
            return (
              @rabbita.none,
              {
                ..model,
                outcome_lessons: {
                  ..state,
                  history: { ..history, notice: error, },
                },
              },
            )
          Ok(record) =>
            (
              lesson_task_text(
                lesson_record_value(record).unwrap(),
                "lesson_id",
              ),
              Some(record.record),
            )
        }
      } else {
        (history.lesson_id, history.selected)
      }
      if lesson_id.is_blank() {
        return (@rabbita.none, model)
      }
      if history.change is Some(_) && lesson_id != history.lesson_id {
        return (
          @rabbita.none,
          {
            ..model,
            outcome_lessons: {
              ..state,
              history: {
                ..history,
                notice: "Your change draft belongs to the open lesson. Close this change draft before opening another lesson history; closing only discards unsaved local edits.",
              },
            },
          },
        )
      }
      let request = state.request + 1
      let payload : Json = { "lesson_id": lesson_id }
      (
        @rabbita.perform(
          result => {
            emit(OutcomeLesson(HistoryFinished(request, "history", result)))
          },
          async fn() noraise { post_outcome_lesson("history", payload) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request,
            pending: true,
            history: {
              ..history,
              lesson_id,
              selected,
              pending_operation: "history",
              data: if lesson_id == history.lesson_id {
                history.data
              } else {
                None
              },
              notice: "Loading the selected lesson's original versions and reviews…",
            },
          },
        },
      )
    }
    ChooseHistoryVersion(reference) => {
      guard history.data is Some(data) &&
        lesson_history_record(data, Some(reference)) is Some(_) else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            request: state.request + 1,
            history: { ..history, selected: Some(reference), },
          },
        },
      )
    }
    StartHistoryChange(operation) =>
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            request: state.request + 1,
            history: lesson_history_begin(
              history,
              operation,
              bookkeeper_nonce(),
              bookkeeper_unix_seconds(),
            ),
          },
        },
      )
    EditHistory(key, value) => {
      guard history.change is Some(change) else {
        return (@rabbita.none, model)
      }
      let fields = change.fields.copy()
      fields[key] = value
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            request: state.request + 1,
            history: {
              ..history,
              change: Some({ ..change, fields, }),
              result: None,
              notice: "",
            },
          },
        },
      )
    }
    DiscardHistoryChange =>
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            request: state.request + 1,
            history: {
              ..history,
              change: None,
              result: None,
              notice: "Unsaved history change discarded. Original lessons and manual lesson draft remain unchanged.",
            },
          },
        },
      )
    SubmitHistoryChange => {
      let payload = match lesson_history_payload(history) {
        Err(error) =>
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..state,
                history: { ..history, notice: error, },
              },
            },
          )
        Ok(value) => value
      }
      let operation = history.change.unwrap().operation
      let request = state.request + 1
      (
        @rabbita.perform(
          result => {
            emit(OutcomeLesson(HistoryFinished(request, operation, result)))
          },
          async fn() noraise { post_outcome_lesson(operation, payload) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request,
            pending: true,
            history: {
              ..history,
              pending_operation: operation,
              result: None,
              notice: "Saving the change for named-human review…",
            },
          },
        },
      )
    }
    _ => (@rabbita.none, model)
  }
}
