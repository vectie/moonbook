///|
priv struct SavedLessonReturn {
  selected : BookkeeperRecordReference?
  observed_at : Int
  notice : String
}

///|
fn initial_saved_lesson_return() -> SavedLessonReturn {
  { selected: None, observed_at: 0, notice: "", }
}

///|
fn saved_lesson_receipts(readback : Json) -> Array[Json] {
  match lesson_task_field(readback, "saved_lessons") {
    Array(entries) => entries
    _ => []
  }
}

///|
fn saved_lesson_reference(value : Json) -> BookkeeperRecordReference? {
  let reference : BookkeeperRecordReference = @json.from_json(value) catch {
    _ => return None
  }
  if reference.record_id.is_blank() ||
    reference.record_version.is_blank() ||
    reference.record_digest.is_blank() {
    None
  } else {
    Some(reference)
  }
}

///|
fn saved_lesson_receipt_valid(receipt : Json, handoff : Json) -> Bool {
  guard receipt
    is {
      "contract_version": "moonbook.saved-lesson-receipt.v1",
      "source_product": "moonbook",
      "destination_product": "moonproj",
      "lesson_id": String(id),
      "title": String(title),
      "state": String(state),
      "currentness": String(currentness),
      "journal_sequence": Number(sequence),
      "activation_authorized": false,
      "external_side_effects_applied": false,
      "customer_acceptance": "not_asserted",
      "cash": "not_asserted",
      ..
    } &&
    !id.is_blank() &&
    !title.is_blank() &&
    sequence >= 0 &&
    sequence.trunc() == sequence else {
    return false
  }
  for
    key in [
      "task", "report", "submission", "outcome", "assessment", "assessment_review",
      "lesson",
    ] {
    if saved_lesson_reference(lesson_task_field(receipt, key)) is None {
      return false
    }
  }
  for key in ["task", "report"] {
    if lesson_task_field(receipt, key) != lesson_task_field(handoff, key) {
      return false
    }
  }
  for key in ["current", "selection_review"] {
    let reference = lesson_task_field(receipt, key)
    if !(reference is Null) && saved_lesson_reference(reference) is None {
      return false
    }
  }
  let review = lesson_task_field(receipt, "review")
  if state == "pending" {
    return review is Null && currentness == "not_retained"
  }
  guard review
    is {
      "receipt": reference,
      "disposition": String(disposition),
      "reviewer_id": String(reviewer),
      "decided_at": Number(at),
      ..
    } &&
    saved_lesson_reference(reference) is Some(_) &&
    !reviewer.is_blank() &&
    at >= 0 &&
    at.trunc() == at else {
    return false
  }
  if state == "rejected" {
    return disposition == "Reject" && currentness == "not_retained"
  }
  if state != "retained" || disposition != "Accept" {
    return false
  }
  let current = lesson_task_field(receipt, "current")
  match currentness {
    "current" => current == lesson_task_field(receipt, "lesson")
    "historical" =>
      !(current is Null) && current != lesson_task_field(receipt, "lesson")
    "legacy_unselected" =>
      current is Null && lesson_task_field(receipt, "selection_review") is Null
    _ => false
  }
}

///|
fn saved_lesson_selected(
  readback : Json,
  reference : BookkeeperRecordReference?,
) -> Json? {
  guard reference is Some(reference) else { return None }
  let matches = saved_lesson_receipts(readback).filter(receipt => {
    lesson_task_field(receipt, "lesson") == reference.to_json() &&
    saved_lesson_receipt_valid(receipt, lesson_task_field(readback, "handoff"))
  })
  if matches.length() == 1 {
    Some(matches[0])
  } else {
    None
  }
}

///|
fn saved_lesson_return_received(
  state : SavedLessonReturn,
  readback : Json,
  requested : String,
  observed_at : Int,
) -> SavedLessonReturn {
  let requested = @json.parse(requested) catch { _ => Json::null() }
  let chosen = saved_lesson_reference(requested)
  let selected = if saved_lesson_selected(readback, chosen) is Some(_) {
    chosen
  } else if saved_lesson_selected(readback, state.selected) is Some(_) {
    state.selected
  } else {
    None
  }
  {
    selected,
    observed_at,
    notice: if chosen is Some(_) && selected != chosen {
      "The exact requested lesson is not available for this task in this Book. Choose a saved lesson below; nothing was substituted."
    } else {
      "Fresh Book journal status loaded. Select the exact saved lesson before returning it."
    },
  }
}

///|
fn saved_lesson_return_wrapper(
  receipt : Json,
  origin : String,
  observed_at : Int,
) -> Json {
  {
    "contract_version": "moonbook.saved-lesson-return.v1",
    "book_origin": origin,
    "observed_at": observed_at,
    "receipt": receipt,
  }
}

///|
fn saved_lesson_return_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : OutcomeLessonMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  let saved = state.saved_return
  match message {
    ChooseSavedLesson(reference) => {
      guard !state.pending &&
        state.handoff is Some(readback) &&
        saved_lesson_selected(readback, Some(reference)) is Some(_) else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..state,
            request: state.request + 1,
            saved_return: {
              ..saved,
              selected: Some(reference),
              notice: "Selected this exact saved lesson. Return and download reread its journal status first.",
            },
          },
        },
      )
    }
    RefreshSavedLessons(action) => {
      guard !state.pending &&
        ["refresh", "return", "export"].contains(action) &&
        state.handoff is Some(readback) else {
        return (@rabbita.none, model)
      }
      if action != "refresh" &&
        saved_lesson_selected(readback, saved.selected) is None {
        return (@rabbita.none, model)
      }
      let request = state.request + 1
      let payload = lesson_task_field(readback, "handoff")
      (
        @rabbita.perform(
          result => {
            emit(OutcomeLesson(SavedLessonsRead(request, action, result)))
          },
          async fn() noraise { post_outcome_lesson("task-handoff", payload) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request,
            pending: true,
            saved_return: {
              ..saved,
              notice: "Rereading the exact task/report and saved lesson from the Book journal…",
            },
          },
        },
      )
    }
    SavedLessonsRead(request, action, result) => {
      guard state.pending &&
        state.request == request &&
        state.handoff is Some(previous) else {
        return (@rabbita.none, model)
      }
      let readback = match result {
        Ok(readback) if lesson_task_field(readback, "handoff") ==
          lesson_task_field(previous, "handoff") => readback
        _ =>
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..state,
                pending: false,
                saved_return: {
                  ..saved,
                  notice: "Fresh Book status could not be confirmed. Nothing was returned or exported; your draft and last observation were kept.",
                },
              },
            },
          )
      }
      let refreshed = saved_lesson_return_received(
        saved,
        readback,
        "",
        bookkeeper_unix_seconds(),
      )
      let next = {
        ..model,
        outcome_lessons: {
          ..state,
          pending: false,
          handoff: Some(readback),
          saved_return: refreshed,
        },
      }
      if action == "refresh" {
        return (@rabbita.none, next)
      }
      guard saved_lesson_selected(readback, saved.selected) is Some(receipt) else {
        return (
          @rabbita.none,
          {
            ..next,
            outcome_lessons: {
              ..next.outcome_lessons,
              saved_return: {
                ..refreshed,
                notice: "The selected exact lesson is unavailable in the fresh readback. Select again; nothing was returned.",
              },
            },
          },
        )
      }
      let wrapper = saved_lesson_return_wrapper(
        receipt,
        lesson_return_book_origin(),
        refreshed.observed_at,
      )
      if action == "export" {
        return (
          @cmd.custom_cmd(_ => {
            lesson_download_saved_receipt(wrapper.stringify(indent=2))
          }),
          {
            ..next,
            outcome_lessons: {
              ..next.outcome_lessons,
              saved_return: {
                ..refreshed,
                notice: "Receipt download prepared from this fresh readback. Importing it in Proj reports an observed Book status, not live company acceptance.",
              },
            },
          },
        )
      }
      (
        @rabbita.perform(
          result => emit(OutcomeLesson(SavedLessonReturned(request, result))),
          async fn() noraise {
            let returned : Bool = lesson_send_saved_receipt_on(
                lesson_receiver_browser(),
                wrapper.stringify(),
              )
              .wait()
              .cast() catch {
                _ => false
              }
            returned
          },
        ),
        {
          ..next,
          outcome_lessons: {
            ..next.outcome_lessons,
            pending: true,
            saved_return: {
              ..refreshed,
              notice: "Waiting for Proj to acknowledge this exact saved-lesson receipt…",
            },
          },
        },
      )
    }
    SavedLessonReturned(request, returned) => {
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
            saved_return: {
              ..saved,
              notice: if returned {
                "Proj acknowledged this exact saved-lesson status. Its task, customer acceptance and cash were not changed."
              } else {
                "Proj did not acknowledge the return. Reopen/reconnect from the task in Proj, or download this lesson receipt and import it there. The saved lesson is still in Book."
              },
            },
          },
        },
      )
    }
    _ => (@rabbita.none, model)
  }
}
