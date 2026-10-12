///|
priv struct LessonBrowserEntry {
  lesson : BookkeeperRawRecord
  review : BookkeeperRawReview
  selection_review : Json
} derive(FromJson)

///|
priv struct LessonBrowserExclusion {
  lesson : BookkeeperRawRecord
  lesson_id : String
  reason : String
} derive(FromJson)

///|
priv struct LessonBrowserResult {
  contract_version : String
  query : Json
  lessons : Array[LessonBrowserEntry]
  exclusions : Array[LessonBrowserExclusion]
  activation_authorized : Bool
  external_side_effects_applied : Bool
} derive(FromJson)

///|
priv struct LessonBrowserWorkspace {
  text : String
  request : Int
  pending : Bool
  data : LessonBrowserResult?
  error : String?
  notice : String
}

///|
priv enum LessonBrowserMsg {
  Edit(String)
  Reload
  Finished(Int, Json, Result[Json, String])
  OpenOriginal(BookkeeperRecordReference)
  OpenHistory(BookkeeperRecordReference)
  ReloadRecords
}

///|
fn initial_lesson_browser_workspace() -> LessonBrowserWorkspace {
  { text: "", request: 0, pending: false, data: None, error: None, notice: "", }
}

///|
fn lesson_browser_query(text : String) -> Json {
  {
    "contract_version": "moonbook.outcome-lesson-browse-query.v1",
    "text": text,
  }
}

///|
fn lesson_browser_record_readable(record : BookkeeperRawRecord) -> Bool {
  guard lesson_record_value(record) is Some(lesson) &&
    lesson
    is {
      "lesson_id": String(id),
      "guidance": String(guidance),
      "applicability": Array(applicability),
      "invalidation": Array(invalidation),
      ..
    } else {
    return false
  }
  !id.is_blank() &&
  !record.title.is_blank() &&
  !guidance.is_blank() &&
  !record.record.record_id.is_blank() &&
  !record.record.record_version.is_blank() &&
  !record.record.record_digest.is_blank() &&
  (applicability + invalidation).all(condition => {
    condition is { "key": String(key), "value": String(value), .. } &&
    !key.is_blank() &&
    !value.is_blank()
  })
}

///|
fn parse_lesson_browser_result(
  value : Json,
  query : Json,
) -> Result[LessonBrowserResult, String] {
  let data : LessonBrowserResult = @json.from_json(value) catch {
    _ => return Err("The Book host did not return readable reviewed lessons.")
  }
  if data.contract_version != "moonbook.outcome-lesson-browser.v1" ||
    data.query != query ||
    query != lesson_browser_query(lesson_task_text(query, "text")) ||
    data.activation_authorized ||
    data.external_side_effects_applied {
    return Err(
      "The lesson browser response does not match this exact read-only search.",
    )
  }
  for entry in data.lessons {
    let review = entry.review
    if !lesson_browser_record_readable(entry.lesson) ||
      !bookkeeper_enum_is(entry.lesson.stage, "DeliverableAcceptance") ||
      !bookkeeper_enum_is(review.stage, "DeliverableAcceptance") ||
      review.subject != entry.lesson.record ||
      review.disposition != "Accept" ||
      !review.review_complete ||
      !bookkeeper_enum_is(review.reviewer_kind, "Human") ||
      !review.reviewer.authorized ||
      review.reviewer.reviewer_id.is_blank() ||
      !review.issues.is_empty() ||
      review.side_effects_applied ||
      lesson_nullable_reference(ToJson::to_json(review.receipt)) is Err(_) ||
      lesson_nullable_reference(entry.selection_review) is Err(_) {
      return Err(
        "A reviewed lesson or its named-human review is incomplete. Reload lessons.",
      )
    }
    guard lesson_task_field(
        lesson_record_value(entry.lesson).unwrap(),
        "applicability",
      )
      is Array(conditions) &&
      !conditions.is_empty() else {
      return Err(
        "A reviewed lesson has no applicability conditions. Reload lessons.",
      )
    }
  }
  for entry in data.exclusions {
    if !lesson_browser_record_readable(entry.lesson) ||
      entry.reason.is_blank() ||
      entry.lesson_id.is_blank() ||
      lesson_task_text(lesson_record_value(entry.lesson).unwrap(), "lesson_id") !=
      entry.lesson_id {
      return Err("An excluded lesson could not be read. Reload lessons.")
    }
  }
  Ok(data)
}

///|
fn lesson_browser_finished(
  state : LessonBrowserWorkspace,
  request : Int,
  query : Json,
  result : Result[Json, String],
) -> LessonBrowserWorkspace {
  if !state.pending ||
    state.request != request ||
    query != lesson_browser_query(state.text) {
    return state
  }
  let parsed = match result {
    Ok(value) => parse_lesson_browser_result(value, query)
    Err(error) => Err(error)
  }
  match parsed {
    Ok(data) =>
      { ..state, pending: false, data: Some(data), error: None, notice: "", }
    Err(error) =>
      { ..state, pending: false, data: None, error: Some(error), notice: "", }
  }
}

///|
fn lesson_browser_navigation_record(
  model : Model,
  reference : BookkeeperRecordReference,
) -> BookkeeperRawRecord? {
  if model.bookkeeper_reads.store_loading ||
    model.bookkeeper_reads.store_error is Some(_) {
    return None
  }
  guard model.bookkeeper_store is Some(store) && store.replay_issues.is_empty() else {
    return None
  }
  lesson_exact_record(model, ToJson::to_json(reference))
}

///|
fn lesson_browser_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  action : LessonBrowserMsg,
) -> (@rabbita.Cmd, Model) {
  let lessons = model.outcome_lessons
  let state = lessons.browser
  match action {
    Edit(text) =>
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            browser: {
              text,
              request: state.request + 1,
              pending: false,
              data: None,
              error: None,
              notice: "Search text changed. Choose Search reviewed lessons to load these results.",
            },
          },
        },
      )
    Reload => {
      if state.pending {
        return (@rabbita.none, model)
      }
      let request = state.request + 1
      let query = lesson_browser_query(state.text)
      (
        @rabbita.perform(
          result => {
            emit(OutcomeLesson(Browser(Finished(request, query, result))))
          },
          async fn() noraise { post_outcome_lesson("browse", query) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            browser: {
              ..state,
              request,
              pending: true,
              data: None,
              error: None,
              notice: "",
            },
          },
        },
      )
    }
    Finished(request, query, result) =>
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            browser: lesson_browser_finished(state, request, query, result),
          },
        },
      )
    ReloadRecords => {
      let (command, next) = start_bookkeeper_read(emit, model)
      (
        command,
        {
          ..next,
          outcome_lessons: {
            ..next.outcome_lessons,
            browser: {
              ..state,
              notice: "Reloading Bookkeeper records. When the exact record is available, open its original or history below.",
            },
          },
        },
      )
    }
    OpenOriginal(reference) | OpenHistory(reference) => {
      guard lesson_browser_navigation_record(model, reference) is Some(_) else {
        return (
          @rabbita.none,
          {
            ..model,
            outcome_lessons: {
              ..lessons,
              browser: {
                ..state,
                notice: "Reload Bookkeeper records before opening this exact lesson. Its record is missing or the loaded store is unavailable.",
              },
            },
          },
        )
      }
      let next = {
        ..model,
        selected_bookkeeper_record: Some(reference),
        outcome_lessons: {
          ..lessons,
          browser: {
            ..state,
            notice: if action is OpenHistory(_) {
              "Opening the existing lesson history below. Your lesson draft and task context are kept."
            } else {
              "Original lesson selected below. Your lesson draft and task context are kept."
            },
          },
        },
      }
      if action is OpenHistory(_) {
        if lessons.pending {
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..lessons,
                browser: {
                  ..state,
                  notice: "Wait for the current lesson request to finish before opening history. You can continue browsing.",
                },
              },
            },
          )
        }
        lesson_history_update(emit, next, OpenHistory)
      } else {
        (@rabbita.none, next)
      }
    }
  }
}
