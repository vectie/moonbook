///|
priv struct LessonPracticeObservation {
  before : String
  after : String
  feedback : String
  next_practice : String
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonPracticeSession {
  schema : String
  learner : String
  teaching : LessonTeachingBrief
  observations : Array[LessonPracticeObservation]
  previous_rounds : Array[LessonPracticeRound]
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonPracticeWorkspace {
  search : String
  session : LessonPracticeSession?
  intake : String
  preview : LessonPracticeSession?
  correction : LessonPracticeCorrection?
  retest : LessonPracticeRetest?
}

///|
priv enum LessonPracticeMsg {
  Search(String)
  ReuseTask(Int, Int, Int)
  PreviewRetest(Int, Int, Int)
  ApplyRetest
  CancelRetest
  Start
  NextRound
  Learner(String)
  Edit(Int, String, String)
  Intake(String)
  Preview
  PreviewCsv
  Restore
  Discard
  Export(Bool)
}

///|
fn initial_lesson_practice() -> LessonPracticeWorkspace {
  {
    search: "",
    session: None,
    intake: "",
    preview: None,
    correction: None,
    retest: None,
  }
}

///|
fn lesson_practice_decode(
  text : String,
) -> Result[LessonPracticeSession, String] {
  guard text.length() <= 1048576 && lesson_notebook_fits(text) else {
    return Err(
      "Use at most 1 MiB UTF-8 for a practice workbook. Nothing was truncated.",
    )
  }
  guard lesson_teaching_well_formed(text) else {
    return Err(
      "Paste complete practice-workbook JSON with well-formed Unicode.",
    )
  }
  let json = @json.parse(text) catch {
    _ => return Err("Invalid practice-workbook JSON.")
  }
  let normalized = if lesson_task_text(json, "schema") ==
    "moonbook.agent-practice-workbook.v1" {
    guard json is Object(fields) && !fields.contains("previous_rounds") else {
      return Err("A v1 workbook cannot contain subsequent rounds.")
    }
    let fields = fields.copy()
    fields["schema"] = "moonbook.agent-practice-workbook.v2"
    fields["previous_rounds"] = [].to_json()
    Json::object(fields)
  } else {
    json
  }
  let session : LessonPracticeSession = @json.from_json(normalized) catch {
    _ => return Err("The practice workbook has missing or unreadable fields.")
  }
  guard session.schema == "moonbook.agent-practice-workbook.v2" &&
    ToJson::to_json(session) == normalized &&
    session.learner.length() <= 256 &&
    session.previous_rounds.length() < 12 &&
    lesson_notebook_fits(ToJson::to_json(session).stringify(indent=2) + "\n") else {
    return Err(
      "Unsupported workbook fields/schema or size. Keep the learner label within 256 characters, at most 12 rounds and the complete workbook within 1 MiB.",
    )
  }
  for round in lesson_practice_rounds(session) {
    if lesson_practice_round_validate(round) is Err(error) {
      return Err(error)
    }
  }
  Ok(session)
}

///|
fn lesson_practice_reduce(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
  action : LessonPracticeMsg,
) -> LessonTeachingBriefWorkspace {
  let work = state.practice
  let changed = match action {
    Search(query) =>
      return {
        ..state,
        revision: state.revision + 1,
        practice: { ..work, search: query, },
      }
    ReuseTask(request, round, index) =>
      return lesson_practice_reuse_task(state, browser, request, round, index)
    PreviewRetest(request, round, index) =>
      return lesson_practice_retest_prepare(
        state, browser, request, round, index,
      )
    ApplyRetest => return lesson_practice_retest_apply(state, browser)
    CancelRetest =>
      return {
        ..state,
        revision: state.revision + 1,
        practice: { ..work, retest: None, },
        notice: "Retest preparation closed. Next tasks and recorded practice are unchanged.",
      }
    Start => {
      guard work.session is None &&
        lesson_teaching_ready(state, browser) &&
        state.draft.items.all(item => !item.exercise.is_blank()) else {
        return {
          ..state,
          notice: "Start practice after rechecking every lesson and writing every fresh task. Save and discard the open session before starting another.",
        }
      }
      Some({
        schema: "moonbook.agent-practice-workbook.v2",
        learner: "",
        teaching: state.draft,
        observations: state.draft.items.map(_ => {
          before: "",
          after: "",
          feedback: "",
          next_practice: "",
        }),
        previous_rounds: [],
      })
    }
    NextRound => {
      guard work.session is Some(session) &&
        lesson_practice_next_ready(state, browser) else {
        return {
          ..state,
          notice: "Recheck the next teaching brief and write every task before starting another round. Keep at least one first response in this round; the workbook supports 12 rounds. Existing observations are kept.",
        }
      }
      Some({
        ..session,
        previous_rounds: lesson_practice_rounds(session),
        teaching: state.draft,
        observations: state.draft.items.map(_ => {
          before: "",
          after: "",
          feedback: "",
          next_practice: "",
        }),
      })
    }
    Learner(value) => {
      guard work.session is Some(session) else { return state }
      Some({ ..session, learner: value, })
    }
    Edit(index, key, value) => {
      guard work.session is Some(session) &&
        index >= 0 &&
        index < session.observations.length() else {
        return state
      }
      let observations = session.observations.copy()
      let old = observations[index]
      observations[index] = match key {
        "before" => { ..old, before: value, }
        "after" => { ..old, after: value, }
        "feedback" => { ..old, feedback: value, }
        "next_practice" => { ..old, next_practice: value, }
        _ => return state
      }
      Some({ ..session, observations, })
    }
    Intake(text) => {
      let fits = text.length() <= 1048576 && lesson_notebook_fits(text)
      return {
        ..state,
        revision: state.revision + 1,
        practice: {
          ..work,
          intake: if fits {
            text
          } else {
            work.intake
          },
          preview: None,
        },
        notice: if fits {
          ""
        } else {
          "Use at most 1 MiB UTF-8. Existing workbook and intake are kept; preview cleared."
        },
      }
    }
    PreviewCsv => {
      guard work.session is Some(session) else { return state }
      return match lesson_practice_csv_preview(session, work.intake) {
        Ok(preview) =>
          {
            ..state,
            revision: state.revision + 1,
            practice: { ..work, preview: Some(preview), },
            notice: "CSV preview fills blank observations only. Inspect the workbook, then apply with Replace local practice. No responses are verified by import.",
          }
        Err(error) =>
          {
            ..state,
            revision: state.revision + 1,
            practice: { ..work, preview: None, },
            notice: error,
          }
      }
    }
    Preview =>
      return match lesson_practice_decode(work.intake) {
        Ok(preview) =>
          {
            ..state,
            revision: state.revision + 1,
            practice: { ..work, preview: Some(preview), },
            notice: "Inspect the full replacement. Imported responses and source labels are unverified operator reports.",
          }
        Err(error) =>
          {
            ..state,
            revision: state.revision + 1,
            practice: { ..work, preview: None, },
            notice: error,
          }
      }
    Restore => {
      guard work.preview is Some(session) else { return state }
      Some(session)
    }
    Discard => None
    Export(_) => return state
  }
  if changed is Some(session) &&
    lesson_practice_decode(ToJson::to_json(session).stringify()) is Err(error) {
    return {
      ..state,
      revision: state.revision + 1,
      practice: { ..work, preview: None, },
      notice: error,
    }
  }
  {
    ..state,
    revision: state.revision + 1,
    practice: {
      ..work,
      session: changed,
      preview: None,
      correction: None,
      retest: None,
    },
    notice: "Practice workbook edited locally. Save its JSON before reload; observations are not accepted learning or execution receipts.",
  }
}

///|
fn lesson_practice_markdown(session : LessonPracticeSession) -> String {
  let parts = [
    "# MoonBook agent practice workbook\n",
    "Operator-entered observations of separately conducted practice. Blank responses mean unrecorded, not failure or success. No model was run, score computed, factual review completed or lesson accepted by this workbook. The teaching snapshot is historical and imported labels are unverified. Recheck current lessons in Book before applying guidance.\n",
    "## Current learner / session label · operator supplied\n" +
    lesson_teaching_block(session.learner),
  ]
  for round_index, round in lesson_practice_rounds(session) {
    parts.push(
      "## Round " +
      (round_index + 1).to_string() +
      (if round_index < session.previous_rounds.length() {
        " · sealed historical capture\n"
      } else {
        " · current editable round\n"
      }),
    )
    parts.push(
      "### Captured learning objective\n" +
      lesson_teaching_block(round.teaching.objective),
    )
    parts.push(
      "### Captured learner / session label\n" +
      lesson_teaching_block(round.learner),
    )
    for index, item in round.teaching.items {
      let observation = round.observations[index]
      parts.push("### Practice " + (index + 1).to_string() + "\n")
      parts.push("#### Exact task\n" + lesson_teaching_block(item.exercise))
      parts.push(
        "#### Captured lesson, scope, reviews and historical examples\n" +
        lesson_teaching_block(ToJson::to_json(item).stringify(indent=2)),
      )
      for
        (label, value) in [
          ("First response · operator entered", observation.before),
          ("Response after feedback · operator entered", observation.after),
          (
            "Feedback / observed difference · operator entered",
            observation.feedback,
          ),
          (
            "Next practice / proposed correction · not accepted",
            observation.next_practice,
          ),
        ] {
        parts.push(
          "#### " +
          label +
          "\n" +
          (if value.is_empty() {
            "Not recorded.\n"
          } else {
            lesson_teaching_block(value)
          }),
        )
      }
    }
  }
  parts.push(
    "## Return useful observations to review\nOpen the exact lesson's version history in Book, inspect its current scope, and use the existing revision/rehearsal and named-human review path for any proposed change. A response difference alone does not establish improvement or generalization. Keep this workbook JSON for editing; downloads may contain private inputs and responses.\n",
  )
  parts.join("\n")
}

///|
extern "js" fn lesson_practice_download(
  text : String,
  markdown : Bool,
) -> @js.Promise =
  #| async (text,markdown)=>{const blob=new Blob([text],{type:markdown?'text/markdown;charset=utf-8':'application/json;charset=utf-8'});const url=URL.createObjectURL(blob);let link;try{link=document.createElement('a');link.href=url;link.download=markdown?'moonbook-agent-practice-workbook.md':'moonbook-agent-practice-workbook.json';document.body.appendChild(link);link.click();}finally{try{link?.remove();}finally{setTimeout(()=>URL.revokeObjectURL(url),1000);}}return 'Practice workbook download requested. Check browser downloads; observations remain operator reports.';}

///|
fn lesson_practice_export(
  emit : @rabbita.Emit[Msg],
  model : Model,
  revision : Int,
  markdown : Bool,
) -> (@rabbita.Cmd, Model) {
  let workspace = model.outcome_lessons
  let state = workspace.teaching_brief
  guard state.practice.session is Some(session) else {
    return (@rabbita.none, model)
  }
  let text = if markdown {
    lesson_practice_markdown(session)
  } else {
    ToJson::to_json(session).stringify(indent=2) + "\n"
  }
  guard lesson_notebook_fits(text) else {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..workspace,
          teaching_brief: {
            ..state,
            notice: "The report exceeds 1 MiB. Save JSON or shorten observation text; nothing was truncated.",
          },
        },
      },
    )
  }
  (
    @rabbita.perform(
      result => emit(OutcomeLesson(TeachingBrief(revision, Downloaded(result)))),
      async fn() noraise {
        let result : String = lesson_practice_download(text, markdown)
          .wait()
          .cast() catch {
            error => return Err("\{error}")
          }
        Ok(result)
      },
    ),
    model,
  )
}
