///|
priv struct LessonPracticeCorrection {
  index : Int
  round : Int
  kind : String
  name : String
  required : String
  forbidden : String
}

///|
priv enum LessonPracticeCorrectionMsg {
  Choose(Int)
  ChooseRound(Int, Int)
  Edit(String, String)
  OpenHistory
  AddCase
  Close
}

///|
fn lesson_practice_correction_source(
  session : LessonPracticeSession,
  index : Int,
  round? : Int = session.previous_rounds.length(),
) -> Json {
  let capture = lesson_practice_rounds(session)[round]
  let item = capture.teaching.items[index]
  let observation = capture.observations[index]
  {
    "schema": "moonbook.practice-correction-source.v1",
    "learner": capture.learner,
    "objective": capture.teaching.objective,
    "round_number": round + 1,
    "observation_index": index,
    "lesson": ToJson::to_json(item.snapshot),
    "exercise": item.exercise,
    "first_response": observation.before,
    "after_feedback_response": observation.after,
    "feedback": observation.feedback,
    "next_practice": observation.next_practice,
    "operator_reported": true,
    "model_executed": false,
  }
}

///|
fn lesson_practice_correction_case(
  session : LessonPracticeSession,
  draft : LessonPracticeCorrection,
) -> Json {
  let capture = lesson_practice_rounds(session)[draft.round]
  let item = capture.teaching.items[draft.index]
  let observation = capture.observations[draft.index]
  {
    "kind": draft.kind,
    "name": draft.name,
    "input": item.exercise,
    "original": observation.before,
    "revised": "",
    "required": draft.required,
    "forbidden": draft.forbidden,
    "practice_from": lesson_practice_correction_source(
      session,
      draft.index,
      round=draft.round,
    ),
  }
}

///|
fn lesson_practice_correction_ready(
  model : Model,
  item : LessonTeachingItem,
) -> Bool {
  let state = model.outcome_lessons
  guard !state.pending &&
    state.history.read_ready &&
    lesson_teaching_matches(item, state.browser) &&
    state.history.data is Some(history) &&
    history.lesson_id == item.snapshot.lesson_id &&
    history.current == Some(item.snapshot.reference) &&
    state.history.change is Some(change) &&
    change.original.record == item.snapshot.reference else {
    return false
  }
  let inspected = lesson_revision_rehearsal_transition(
    state.history,
    state.pending,
    { "kind": "inspect" },
    request_id=state.request,
  )
  lesson_task_field(inspected, "current") == true.to_json() &&
  history.versions.any(version => {
    version.lesson.record == item.snapshot.reference &&
    lesson_history_accepted(version) &&
    version.reviews.any(review => {
      review.receipt == item.snapshot.accepted_review &&
      lesson_notebook_capture({
        lesson: version.lesson,
        review,
        selection_review: item.snapshot.selection_review,
      }) ==
      item.snapshot
    })
  })
}

///|
fn lesson_practice_correction_notice(model : Model, notice : String) -> Model {
  {
    ..model,
    outcome_lessons: {
      ..model.outcome_lessons,
      teaching_brief: { ..model.outcome_lessons.teaching_brief, notice, },
    },
  }
}

///|
fn lesson_practice_correction_owner(model : Model) -> Json {
  {
    "history": lesson_correction_draft_owner(model),
    "read_ready": model.outcome_lessons.history.read_ready,
    "browser_request": model.outcome_lessons.browser.request,
    "browser_pending": model.outcome_lessons.browser.pending,
  }
}

///|
fn lesson_practice_correction_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  revision : Int,
  request : Int,
  owner : Json,
  action : LessonPracticeCorrectionMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  let teaching = state.teaching_brief
  let work = teaching.practice
  guard revision == teaching.revision &&
    request == state.request &&
    owner == lesson_practice_correction_owner(model) &&
    !state.pending &&
    work.session is Some(session) else {
    return (@rabbita.none, model)
  }
  let draft = match action {
    Choose(index) => {
      guard index >= 0 && index < session.teaching.items.length() else {
        return (@rabbita.none, model)
      }
      Some({
        index,
        round: session.previous_rounds.length(),
        kind: "",
        name: "",
        required: "",
        forbidden: "",
      })
    }
    ChooseRound(round, index) => {
      let rounds = lesson_practice_rounds(session)
      guard round >= 0 &&
        round < rounds.length() &&
        index >= 0 &&
        index < rounds[round].teaching.items.length() else {
        return (@rabbita.none, model)
      }
      Some({ index, round, kind: "", name: "", required: "", forbidden: "", })
    }
    Close => None
    Edit(key, value) => {
      guard work.correction is Some(draft) else {
        return (@rabbita.none, model)
      }
      let limit = if key == "name" { 256 } else { 5140 }
      guard value.length() <= limit &&
        lesson_teaching_well_formed(Json::string(value).stringify()) else {
        return (
          @rabbita.none,
          lesson_practice_correction_notice(
            model, "The case field is too large or has invalid Unicode. Existing text was kept; nothing was truncated.",
          ),
        )
      }
      Some(
        match key {
          "kind" if value == "useful" || value == "adverse" =>
            { ..draft, kind: value, }
          "name" => { ..draft, name: value, }
          "required" => { ..draft, required: value, }
          "forbidden" => { ..draft, forbidden: value, }
          _ => return (@rabbita.none, model)
        },
      )
    }
    OpenHistory => {
      guard work.correction is Some(draft) else {
        return (@rabbita.none, model)
      }
      let item = lesson_practice_rounds(session)[draft.round].teaching.items[draft.index]
      if state.history.change is Some(_) &&
        state.history.lesson_id != item.snapshot.lesson_id {
        return (
          @rabbita.none,
          lesson_practice_correction_notice(
            model, "An unsaved correction for another lesson is open. Finish or close that existing change before opening this practice lesson. The workbook is kept.",
          ),
        )
      }
      let next = {
        ..model,
        outcome_lessons: {
          ..state,
          history: {
            ..state.history,
            lesson_id: item.snapshot.lesson_id,
            selected: Some(item.snapshot.reference),
          },
        },
      }
      return lesson_history_update(emit, next, RefreshHistory)
    }
    AddCase => {
      guard work.correction is Some(draft) else {
        return (@rabbita.none, model)
      }
      let item = lesson_practice_rounds(session)[draft.round].teaching.items[draft.index]
      guard lesson_practice_correction_ready(model, item) else {
        return (
          @rabbita.none,
          lesson_practice_correction_notice(
            model, "Recheck the captured lesson, open its exact current history, and use its existing Revise and Start contrasting-case rehearsal controls first. Changed or unavailable guidance cannot receive this observation automatically.",
          ),
        )
      }
      let action = lesson_revision_rehearsal_action(
        state.history,
        "practice_import",
      )
      let fields = match action {
        Object(fields) => fields.copy()
        _ => panic()
      }
      fields["practice_case"] = lesson_practice_correction_case(session, draft)
      let (cmd, next) = lesson_revision_rehearsal_update(
        model,
        Json::object(fields),
      )
      if next.outcome_lessons.history.notice ==
        "Added observed practice as an operator-reported case. Supply a fresh revised-guidance output, compare and stage through the existing named-review lane." {
        return (
          cmd,
          {
            ..next,
            outcome_lessons: {
              ..next.outcome_lessons,
              teaching_brief: {
                ..teaching,
                revision: teaching.revision + 1,
                practice: { ..work, correction: None, },
                notice: next.outcome_lessons.history.notice,
              },
            },
          },
        )
      }
      return (
        cmd,
        lesson_practice_correction_notice(
          next,
          next.outcome_lessons.history.notice,
        ),
      )
    }
  }
  (
    @rabbita.none,
    {
      ..model,
      outcome_lessons: {
        ..state,
        teaching_brief: {
          ..teaching,
          revision: teaching.revision + 1,
          practice: { ..work, correction: draft, },
          notice: "Prepare an observed case locally. The first response is attributed only by your explicit Add action; the after-feedback response remains source context and the revised-guidance output starts blank.",
        },
      },
    },
  )
}
