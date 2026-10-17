///|
priv struct LessonTeachingExample {
  name : String
  input : String
  expected_output : String
  required : Array[String]
  forbidden : Array[String]
  source_case_id : String
  source_kind : String
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonTeachingItem {
  snapshot : LessonNotebookSnapshot
  examples : Array[LessonTeachingExample]
  example_notice : String
  exercise : String
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonTeachingBrief {
  schema : String
  objective : String
  items : Array[LessonTeachingItem]
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonTeachingBriefWorkspace {
  revision : Int
  draft : LessonTeachingBrief
  intake : String
  preview : LessonTeachingBrief?
  recheck_after : Int
  notice : String
  practice : LessonPracticeWorkspace
}

///|
priv enum LessonTeachingBriefMsg {
  Add(Int, BookkeeperRecordReference)
  Objective(String)
  Exercise(Int, String)
  Move(Int, Int)
  Remove(Int)
  Intake(String)
  Preview
  Restore
  Recheck
  Download(Bool, Int)
  Downloaded(Result[String, String])
  Practice(LessonPracticeMsg)
}

///|
fn initial_lesson_teaching_brief() -> LessonTeachingBriefWorkspace {
  {
    revision: 0,
    draft: {
      schema: "moonbook.agent-teaching-brief.v1",
      objective: "",
      items: [],
    },
    intake: "",
    preview: None,
    recheck_after: -1,
    notice: "",
    practice: initial_lesson_practice(),
  }
}

///|
fn lesson_teaching_capture(entry : LessonBrowserEntry) -> LessonTeachingItem {
  let snapshot = lesson_notebook_capture(entry)
  let retained = lesson_retained_cases({
    "eligible": true,
    "original_guidance": snapshot.guidance,
    "binding": {
      "record": ToJson::to_json(entry.lesson),
      "original": ToJson::to_json(entry.lesson.record),
      "reviews": [[{ "receipt": ToJson::to_json(entry.review.receipt) }]],
    },
  })
  let examples = match lesson_task_field(retained, "items") {
    Array(items) =>
      items.map(item => {
        let fragments = key => {
          let value = lesson_task_text(item, key)
          if value.is_empty() {
            []
          } else {
            value.split("\n").map(s => s.to_owned()).collect()
          }
        }
        {
          name: lesson_task_text(item, "name"),
          input: lesson_task_text(item, "input"),
          expected_output: lesson_task_text(item, "original"),
          required: fragments("required"),
          forbidden: fragments("forbidden"),
          source_case_id: lesson_task_text(
            lesson_task_field(item, "retained_from"),
            "source_case_id",
          ),
          source_kind: lesson_task_text(
            lesson_task_field(item, "retained_from"),
            "source_kind",
          ),
        }
      })
    _ => []
  }
  {
    snapshot,
    examples,
    example_notice: (if examples.is_empty() {
      lesson_task_text(retained, "notice")
    } else {
      "Retained expected outputs are earlier operator reports, not fresh execution or proof of generalization."
    }) +
    (if lesson_task_field(retained, "unavailable") is Array(items) &&
      !items.is_empty() {
      " Some retained cases exceed the supported exact-text limits; inspect the original lesson for those cases."
    } else {
      ""
    }),
    exercise: "",
  }
}

///|
extern "js" fn lesson_teaching_well_formed(text : String) -> Bool =
  #| text => { const walk=v=>typeof v==='string'?new TextDecoder().decode(new TextEncoder().encode(v))===v:Array.isArray(v)?v.every(walk):v&&typeof v==='object'?Object.values(v).every(walk):true;try{return walk(JSON.parse(text))}catch{return false} }

///|
fn lesson_teaching_decode(text : String) -> Result[LessonTeachingBrief, String] {
  guard text.length() <= 1048576 && lesson_notebook_fits(text) else {
    return Err(
      "Use at most 1 MiB UTF-8; the open teaching brief is kept without truncation.",
    )
  }
  let json = @json.parse(text) catch {
    _ => return Err("Paste a complete teaching-brief JSON file.")
  }
  guard lesson_teaching_well_formed(text) else {
    return Err(
      "Teaching text contains an unmatched Unicode surrogate. Nothing was replaced or normalized.",
    )
  }
  let draft : LessonTeachingBrief = @json.from_json(json) catch {
    _ => return Err("The teaching brief has missing or unreadable fields.")
  }
  guard draft.schema == "moonbook.agent-teaching-brief.v1" &&
    ToJson::to_json(draft) == json &&
    draft.items.length() <= 12 &&
    draft.objective.length() <= 16384 &&
    lesson_notebook_fits(ToJson::to_json(draft).stringify(indent=2) + "\n") else {
    return Err(
      "Unsupported fields/schema or size. Use up to 12 lessons and a 16384-character objective.",
    )
  }
  // Share the existing curated snapshot contract, never import a raw record.
  let notebook : LessonNotebookDraft = {
    schema: "moonbook.decision-notebook.v1",
    question: "",
    decision: "",
    uncertainty: "",
    items: draft.items.map(item => {
      snapshot: item.snapshot,
      stance: "context",
      note: "",
    }),
  }
  if lesson_notebook_decode(ToJson::to_json(notebook).stringify()) is Err(error) {
    return Err(error)
  }
  let ids : Array[String] = []
  for item in draft.items {
    guard !ids.contains(item.snapshot.lesson_id) &&
      item.exercise.length() <= 16384 &&
      item.example_notice.length() <= 4096 &&
      item.examples.length() <= 6 else {
      return Err(
        "Select each lesson once; keep exercises within 16384 characters and at most six retained examples per lesson.",
      )
    }
    ids.push(item.snapshot.lesson_id)
    let case_ids : Array[String] = []
    for example in item.examples {
      let fragments = example.required + example.forbidden
      guard !case_ids.contains(example.source_case_id) &&
        !example.source_case_id.is_blank() &&
        example.source_case_id.length() <= 256 &&
        ["single_example", "contrasting_revision"].contains(example.source_kind) &&
        !example.name.is_blank() &&
        example.name.length() <= 256 &&
        [example.input, example.expected_output].all(s => {
          !s.is_blank() && s.length() <= 8192
        }) &&
        !fragments.is_empty() &&
        fragments.length() <= 20 &&
        fragments.all(s => !s.is_blank() && s.length() <= 256) else {
        return Err(
          "A retained example is incomplete, duplicated, incompatible or too large.",
        )
      }
      case_ids.push(example.source_case_id)
    }
  }
  Ok(draft)
}

///|
fn lesson_teaching_matches(
  item : LessonTeachingItem,
  browser : LessonBrowserWorkspace,
) -> Bool {
  guard !browser.pending && browser.error is None && browser.data is Some(data) else {
    return false
  }
  data.lessons.any(entry => {
    let capture = lesson_teaching_capture(entry)
    capture.snapshot == item.snapshot &&
    capture.examples == item.examples &&
    capture.example_notice == item.example_notice
  })
}

///|
fn lesson_teaching_ready(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
) -> Bool {
  !state.draft.objective.is_blank() &&
  !state.draft.items.is_empty() &&
  browser.request > state.recheck_after &&
  state.draft.items.all(item => lesson_teaching_matches(item, browser))
}

///|
fn lesson_teaching_reduce(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
  revision : Int,
  action : LessonTeachingBriefMsg,
) -> LessonTeachingBriefWorkspace {
  guard revision == state.revision else { return state }
  let draft = state.draft
  let changed = match action {
    Add(request, reference) => {
      guard request == browser.request &&
        !browser.pending &&
        browser.error is None &&
        browser.data is Some(data) &&
        data.lessons.search_by(e => e.lesson.record == reference) is Some(index) else {
        return state
      }
      let capture = lesson_teaching_capture(data.lessons[index])
      if draft.items.any(i => i.snapshot.lesson_id == capture.snapshot.lesson_id) {
        return state
      }
      { ..draft, items: draft.items + [capture], }
    }
    Objective(value) => { ..draft, objective: value, }
    Exercise(index, value) => {
      guard index >= 0 && index < draft.items.length() else { return state }
      let items = draft.items.copy()
      items[index] = { ..items[index], exercise: value, }
      { ..draft, items, }
    }
    Move(index, delta) => {
      let target = index + delta
      guard (delta == 1 || delta == -1) &&
        index >= 0 &&
        target >= 0 &&
        index < draft.items.length() &&
        target < draft.items.length() else {
        return state
      }
      let items = draft.items.copy()
      let item = items[index]
      items[index] = items[target]
      items[target] = item
      { ..draft, items, }
    }
    Remove(index) => {
      guard index >= 0 && index < draft.items.length() else { return state }
      { ..draft, items: [ for i, item in draft.items if i != index => item ], }
    }
    Intake(text) =>
      return {
        ..state,
        revision: revision + 1,
        preview: None,
        intake: if text.length() <= 1048576 && lesson_notebook_fits(text) {
          text
        } else {
          state.intake
        },
        notice: if text.length() <= 1048576 && lesson_notebook_fits(text) {
          ""
        } else {
          "Paste at most 1 MiB UTF-8. Existing intake is kept; preview was cleared."
        },
      }
    Preview =>
      return match lesson_teaching_decode(state.intake) {
        Ok(preview) =>
          {
            ..state,
            revision: revision + 1,
            preview: Some(preview),
            notice: "Inspect the exact replacement. Imported labels and examples need a fresh host recheck.",
          }
        Err(error) =>
          { ..state, revision: revision + 1, preview: None, notice: error, }
      }
    Restore => {
      guard state.preview is Some(preview) else { return state }
      return {
        ..state,
        revision: revision + 1,
        draft: preview,
        preview: None,
        recheck_after: browser.request,
        notice: "Draft resumed. Reload all reviewed lessons before exporting the agent briefing. Old or changed captures will not be substituted.",
      }
    }
    Downloaded(result) =>
      return {
        ..state,
        notice: match result {
          Ok(text) => text
          Err(error) => "Download failed: " + error + ". Your brief is kept."
        },
      }
    Recheck | Download(_, _) => return state
    Practice(action) => return lesson_practice_reduce(state, browser, action)
  }
  match lesson_teaching_decode(ToJson::to_json(changed).stringify()) {
    Ok(_) =>
      {
        ..state,
        revision: revision + 1,
        draft: changed,
        preview: None,
        notice: "Teaching brief edited locally. Save JSON before closing this tab.",
      }
    Err(error) =>
      { ..state, revision: revision + 1, preview: None, notice: error, }
  }
}

///|
fn lesson_teaching_brief_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  revision : Int,
  action : LessonTeachingBriefMsg,
) -> (@rabbita.Cmd, Model) {
  let workspace = model.outcome_lessons
  let state = workspace.teaching_brief
  guard revision == state.revision else { return (@rabbita.none, model) }
  if workspace.pending &&
    (
      action is Practice(PreviewRetest(_, _, _)) ||
      action is Practice(ApplyRetest)
    ) {
    return (@rabbita.none, model)
  }
  if action is Practice(Export(markdown)) {
    return lesson_practice_export(emit, model, revision, markdown)
  }
  if action is Recheck {
    guard !workspace.browser.pending else { return (@rabbita.none, model) }
    let next = {
      ..model,
      outcome_lessons: {
        ..workspace,
        browser: {
          ..workspace.browser,
          text: "",
          request: workspace.browser.request + 1,
          pending: false,
          data: None,
          error: None,
        },
      },
    }
    return lesson_browser_update(emit, next, Reload)
  }
  if action is Download(markdown, request) {
    let text = if markdown {
      lesson_teaching_markdown(state.draft)
    } else {
      ToJson::to_json(state.draft).stringify(indent=2) + "\n"
    }
    guard request == workspace.browser.request &&
      (!markdown || lesson_teaching_ready(state, workspace.browser)) &&
      lesson_notebook_fits(text) else {
      return (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..workspace,
            teaching_brief: {
              ..state,
              notice: "Briefing export needs an objective, selected lessons and exact fresh captures, within 1 MiB. Reload all lessons; inspect and explicitly remove/re-add changed selections. JSON can still save your work.",
            },
          },
        },
      )
    }
    return (
      @rabbita.perform(
        result => {
          emit(OutcomeLesson(TeachingBrief(revision, Downloaded(result))))
        },
        async fn() noraise {
          let result : String = lesson_teaching_download(text, markdown)
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
  (
    @rabbita.none,
    {
      ..model,
      outcome_lessons: {
        ..workspace,
        teaching_brief: lesson_teaching_reduce(
          state,
          workspace.browser,
          revision,
          action,
        ),
      },
    },
  )
}
