///|
priv struct OutcomeReviewWorkspace {
  request : Int
  pending : Bool
  refresh_queued : Bool
  operation : String
  binding : Json?
  preview : Json?
  notice : String
}

///|
priv enum OutcomeReviewMsg {
  PickOutcome
  OutcomePicked(Int, Json, Result[String, String])
  SaveOutcome
  ContinueOutcome(Json)
  RefreshOutcomes
  OutcomeRead(Int, String, Json, Result[Json, String])
  OpenOutcomeReview(Json)
}

///|
fn initial_outcome_review_workspace() -> OutcomeReviewWorkspace {
  {
    request: 0,
    pending: false,
    refresh_queued: false,
    operation: "",
    binding: None,
    preview: None,
    notice: "",
  }
}

///|
fn outcome_review_items(readback : Json) -> Array[Json] {
  match lesson_task_field(readback, "outcome_submissions") {
    Array(items) => items
    _ => []
  }
}

///|
fn outcome_review_binding(model : Model) -> Json? {
  model.outcome_lessons.handoff.map(readback => {
    lesson_task_field(readback, "handoff")
  })
}

///|
fn outcome_review_preview(text : String) -> Result[Json, String] {
  let payload = @json.parse(text) catch {
    _ =>
      return Err(
        "The outcome file is not readable JSON. Choose the completed ProductOutcomeSubmission exported by the producing product.",
      )
  }
  guard payload
    is {
      "contract_version": "moonbook.bookkeeper.product_outcome_submission.v1",
      "deliverable_title": String(_),
      "deliverable_summary": String(_),
      "outcome_summary": String(_),
      "evidence_refs": Array(_),
      ..
    } &&
    saved_lesson_reference(lesson_task_field(payload, "submission")) is Some(_) else {
    return Err(
      "Choose a completed ProductOutcomeSubmission, including its outcome summary and evidence. The Book host validates the complete record before saving.",
    )
  }
  Ok(payload)
}

///|
fn outcome_review_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : OutcomeReviewMsg,
) -> (@rabbita.Cmd, Model) {
  let lessons = model.outcome_lessons
  let state = lessons.outcome_review
  let current = outcome_review_binding(model)
  let (command, next) = match message {
    RefreshOutcomes if state.pending => {
      guard current is Some(binding) && state.binding == Some(binding) else {
        return (@rabbita.none, model)
      }
      // A completed human review may arrive before this operation's older
      // readback. Coalesce one reread; never discard that completion signal.
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            outcome_review: { ..state, refresh_queued: true, },
          },
        },
      )
    }
    PickOutcome => {
      guard !state.pending &&
        !lessons.pending &&
        !model.bookkeeper_busy &&
        current is Some(binding) else {
        return (@rabbita.none, model)
      }
      let request = state.request + 1
      (
        @rabbita.perform(
          result => {
            emit(
              OutcomeLesson(
                OutcomeReview(OutcomePicked(request, binding, result)),
              ),
            )
          },
          async fn() noraise {
            let text : String = lesson_pick_task_file().wait().cast() catch {
                error => return Err("Could not read the outcome file: \{error}")
              }
            if text.is_empty() {
              Err(
                "No outcome file was read. Choose a JSON file up to 2 MiB to try again.",
              )
            } else {
              Ok(text)
            }
          },
        ),
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            outcome_review: {
              ..state,
              request,
              pending: true,
              operation: "pick",
              binding: Some(binding),
              preview: None,
              notice: "Choose an already-complete outcome JSON. Nothing is saved until you inspect it and choose Save outcome.",
            },
          },
        },
      )
    }
    OutcomePicked(request, binding, result) => {
      guard state.pending &&
        state.operation == "pick" &&
        state.request == request &&
        current == Some(binding) &&
        state.binding == Some(binding) else {
        return (@rabbita.none, model)
      }
      let preview = match result {
        Ok(text) => outcome_review_preview(text)
        Err(error) => Err(error)
      }
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            outcome_review: {
              ..state,
              pending: false,
              preview: match preview {
                Ok(value) => Some(value)
                Err(_) => None
              },
              notice: match preview {
                Ok(_) =>
                  "Preview only. Inspect the supplied summary and evidence, then explicitly save. The Book host checks the full submission and exact task/report binding."
                Err(error) => error
              },
            },
          },
        },
      )
    }
    SaveOutcome | ContinueOutcome(_) | RefreshOutcomes => {
      guard !state.pending &&
        !lessons.pending &&
        !model.bookkeeper_busy &&
        current is Some(binding) else {
        return (@rabbita.none, model)
      }
      let (operation, payload) : (String, Json) = match message {
        SaveOutcome => {
          guard state.binding == Some(binding) &&
            state.preview is Some(submission) else {
            return (@rabbita.none, model)
          }
          ("outcome-import", { "handoff": binding, "submission": submission })
        }
        ContinueOutcome(reference) => {
          guard lessons.handoff is Some(readback) &&
            outcome_review_items(readback).any(item => {
              lesson_task_field(item, "submission") == reference &&
              lesson_task_text(item, "state") == "continue_required"
            }) else {
            return (@rabbita.none, model)
          }
          ("outcome-continue", { "handoff": binding, "submission": reference })
        }
        _ => ("task-handoff", binding)
      }
      let request = state.request + 1
      (
        @rabbita.perform(
          result => {
            emit(
              OutcomeLesson(
                OutcomeReview(OutcomeRead(request, operation, payload, result)),
              ),
            )
          },
          async fn() noraise { post_outcome_lesson(operation, payload) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..lessons,
            outcome_review: {
              ..state,
              request,
              pending: true,
              operation,
              refresh_queued: if operation == "task-handoff" {
                false
              } else {
                state.refresh_queued
              },
              binding: Some(binding),
              notice: match operation {
                "outcome-import" =>
                  "Saving the supplied outcome and reading the exact pending record…"
                "outcome-continue" =>
                  "Continuing from the immutable saved submission and checking the next required step…"
                _ => "Refreshing outcome review status from the Book journal…"
              },
            },
          },
        },
      )
    }
    OutcomeRead(request, operation, payload, result) => {
      let binding = if operation == "task-handoff" {
        payload
      } else {
        lesson_task_field(payload, "handoff")
      }
      guard state.pending &&
        state.request == request &&
        state.operation == operation &&
        current == Some(binding) &&
        state.binding == Some(binding) else {
        return (@rabbita.none, model)
      }
      let checked = match result {
        Ok(readback) if lesson_task_field(readback, "handoff") == binding =>
          Ok(readback)
        Ok(_) =>
          Err(
            "The response did not match this exact task/report. Refresh before continuing.",
          )
        Err(error) => Err(error)
      }
      let next = {
        ..model,
        outcome_lessons: {
          ..lessons,
          handoff: match checked {
            Ok(readback) => Some(readback)
            Err(_) => lessons.handoff
          },
          saved_return: match checked {
            Ok(readback) =>
              saved_lesson_return_received(
                lessons.saved_return,
                readback,
                "",
                bookkeeper_unix_seconds(),
              )
            Err(_) => lessons.saved_return
          },
          outcome_review: {
            ..state,
            pending: false,
            preview: if operation == "outcome-import" && checked is Ok(_) {
              None
            } else {
              state.preview
            },
            notice: match checked {
              Ok(_) =>
                "Current outcome status read back. Use the next step shown below; review and lesson drafts were kept."
              Err(error) =>
                "Outcome operation could not be confirmed: " +
                error +
                ". Your preview and drafts were kept. Refresh status or retry the same action; a failed response does not prove nothing was saved."
            },
          },
        },
      }
      if checked is Ok(_) {
        let (read, next) = start_bookkeeper_read(emit, next)
        (
          @rabbita.batch([
            read,
            if operation == "task-handoff" {
              @rabbita.none
            } else {
              emit(RefreshSnapshot)
            },
          ]),
          next,
        )
      } else {
        (@rabbita.none, next)
      }
    }
    OpenOutcomeReview(reference) => outcome_review_open(emit, model, reference)
  }
  let (refresh, next) = outcome_review_drain_refresh(emit, next)
  (@rabbita.batch([command, refresh]), next)
}

///|
fn outcome_review_drain_refresh(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let lessons = model.outcome_lessons
  let state = lessons.outcome_review
  guard state.refresh_queued &&
    !state.pending &&
    !lessons.pending &&
    !model.bookkeeper_busy &&
    outcome_review_binding(model) == state.binding else {
    return (@rabbita.none, model)
  }
  outcome_review_update(
    emit,
    {
      ..model,
      outcome_lessons: {
        ..lessons,
        outcome_review: { ..state, refresh_queued: false, },
      },
    },
    RefreshOutcomes,
  )
}
