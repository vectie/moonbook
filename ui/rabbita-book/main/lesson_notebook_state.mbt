///|
/// Deliberately curated reader snapshot. Raw records, grants, task handoffs and
/// hidden payload fields never enter the planning notebook or its export.
priv struct LessonNotebookSnapshot {
  reference : BookkeeperRecordReference
  lesson_id : String
  title : String
  guidance : String
  applicability : Json
  invalidation : Json
  outcome : Json
  assessment : Json
  accepted_review : BookkeeperRecordReference
  reviewer : String
  review_summary : String
  selection_review : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonNotebookItem {
  snapshot : LessonNotebookSnapshot
  stance : String
  note : String
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct LessonNotebookDraft {
  schema : String
  question : String
  decision : String
  uncertainty : String
  items : Array[LessonNotebookItem]
} derive(Debug, Eq, ToJson, FromJson)

///|
extend LessonNotebookDraft with ToJson::{to_json}

///|
priv struct LessonNotebookWorkspace {
  revision : Int
  draft : LessonNotebookDraft
  intake : String
  preview : LessonNotebookDraft?
  notice : String
}

///|
priv enum LessonNotebookMsg {
  Add(Int, BookkeeperRecordReference)
  Edit(String, String)
  EditItem(Int, String, String)
  Move(Int, Int)
  Remove(Int)
  Intake(String)
  Preview
  Restore
  Download(Bool)
  Downloaded(Result[String, String])
  Recheck
}

///|
fn initial_lesson_notebook() -> LessonNotebookWorkspace {
  {
    revision: 0,
    draft: {
      schema: "moonbook.decision-notebook.v1",
      question: "",
      decision: "",
      uncertainty: "",
      items: [],
    },
    intake: "",
    preview: None,
    notice: "",
  }
}

///|
fn lesson_notebook_capture(
  entry : LessonBrowserEntry,
) -> LessonNotebookSnapshot {
  let lesson = lesson_record_value(entry.lesson).unwrap()
  {
    reference: entry.lesson.record,
    lesson_id: lesson_task_text(lesson, "lesson_id"),
    title: entry.lesson.title,
    guidance: lesson_task_text(lesson, "guidance"),
    applicability: lesson_task_field(lesson, "applicability"),
    invalidation: lesson_task_field(lesson, "invalidation"),
    outcome: lesson_task_field(lesson, "outcome"),
    assessment: lesson_task_field(lesson, "assessment"),
    accepted_review: entry.review.receipt,
    reviewer: entry.review.reviewer.reviewer_id,
    review_summary: entry.review.summary,
    selection_review: entry.selection_review,
  }
}

///|
extern "js" fn lesson_notebook_fits(text : String) -> Bool =
  #| text => new TextEncoder().encode(text).length <= 1048576

///|
fn lesson_notebook_reference(value : Json, nullable : Bool) -> Bool {
  match lesson_nullable_reference(value) {
    Ok(Some(reference)) => ToJson::to_json(reference) == value
    Ok(None) => nullable
    Err(_) => false
  }
}

///|
fn lesson_notebook_decode(text : String) -> Result[LessonNotebookDraft, String] {
  guard text.length() <= 1048576 && lesson_notebook_fits(text) else {
    return Err(
      "Notebook exceeds 1 MiB UTF-8; nothing was truncated or replaced.",
    )
  }
  let value = @json.parse(text) catch {
    _ => return Err("Paste a complete decision-notebook JSON file.")
  }
  let draft : LessonNotebookDraft = @json.from_json(value) catch {
    _ =>
      return Err(
        "Notebook fields or captured lesson references are incomplete.",
      )
  }
  guard draft.schema == "moonbook.decision-notebook.v1" &&
    draft.to_json() == value else {
    return Err(
      "Unsupported notebook schema or unexpected fields. The open notebook is kept.",
    )
  }
  guard lesson_notebook_fits(draft.to_json().stringify(indent=2) + "\n") else {
    return Err(
      "The downloadable notebook exceeds 1 MiB UTF-8; open work is kept.",
    )
  }
  guard draft.items.length() <= 12 &&
    [draft.question, draft.decision, draft.uncertainty].all(s => {
      s.length() <= 16384
    }) else {
    return Err("Use up to 12 lessons and 16384 characters per authored field.")
  }
  let references : Array[BookkeeperRecordReference] = []
  for item in draft.items {
    let s = item.snapshot
    guard ["consider", "tension", "context"].contains(item.stance) &&
      item.note.length() <= 16384 &&
      [s.lesson_id, s.title, s.guidance, s.reviewer].all(v => !v.is_blank()) &&
      !references.contains(s.reference) else {
      return Err(
        "A lesson is duplicated, incomplete, or has an unsupported stance or oversized note.",
      )
    }
    references.push(s.reference)
    for
      reference in [
        ToJson::to_json(s.reference),
        ToJson::to_json(s.accepted_review),
        s.outcome,
        s.assessment,
      ] {
      guard lesson_notebook_reference(reference, false) else {
        return Err(
          "A captured lesson, review, outcome or assessment reference is incomplete.",
        )
      }
    }
    guard lesson_notebook_reference(s.selection_review, true) else {
      return Err("The captured current-version review is incomplete.")
    }
    for
      (kind, conditions) in [
        ("applicability", s.applicability),
        ("invalidation", s.invalidation),
      ] {
      guard conditions is Array(values) &&
        (kind != "applicability" || !values.is_empty()) else {
        return Err("Captured lesson scope is missing.")
      }
      for condition in values {
        guard condition is { "key": String(key), "value": String(value), .. } &&
          !key.is_blank() &&
          !value.is_blank() &&
          condition == ({ "key": key, "value": value } : Json) else {
          return Err("Captured scope contains an incomplete condition.")
        }
      }
    }
  }
  Ok(draft)
}

///|
fn lesson_notebook_status(
  snapshot : LessonNotebookSnapshot,
  browser : LessonBrowserWorkspace,
) -> String {
  guard !browser.pending && browser.error is None && browser.data is Some(data) else {
    return "Unverified capture: reload reviewed lessons to recheck."
  }
  for entry in data.lessons {
    let current = lesson_notebook_capture(entry)
    if current == snapshot {
      return "Exact capture matches the loaded reviewed lesson; current at last load only."
    }
    if current.reference == snapshot.reference ||
      current.lesson_id == snapshot.lesson_id {
      return "Changed since capture: inspect the current lesson. Your old experience and notes are kept."
    }
  }
  if data.exclusions.any(e => e.lesson.record == snapshot.reference) {
    return "This capture is no longer in current reviewed guidance. Inspect its lesson history."
  }
  "Unverified capture: absent from this search. Reload all reviewed lessons to recheck."
}

///|
fn lesson_notebook_reduce(
  state : LessonNotebookWorkspace,
  browser : LessonBrowserWorkspace,
  revision : Int,
  action : LessonNotebookMsg,
) -> LessonNotebookWorkspace {
  guard revision == state.revision else { return state }
  let draft = state.draft
  let changed = match action {
    Add(request, reference) => {
      guard request == browser.request &&
        !browser.pending &&
        browser.error is None &&
        browser.data is Some(data) else {
        return state
      }
      guard data.lessons.search_by(e => e.lesson.record == reference)
        is Some(index) else {
        return state
      }
      if draft.items.any(i => i.snapshot.reference == reference) {
        return state
      }
      {
        ..draft,
        items: draft.items +
        [
          {
            snapshot: lesson_notebook_capture(data.lessons[index]),
            stance: "consider",
            note: "",
          },
        ],
      }
    }
    Edit(field, value) =>
      match field {
        "question" => { ..draft, question: value, }
        "decision" => { ..draft, decision: value, }
        "uncertainty" => { ..draft, uncertainty: value, }
        _ => return state
      }
    EditItem(index, field, value) => {
      guard index >= 0 && index < draft.items.length() else { return state }
      let items = draft.items.copy()
      items[index] = match field {
        "stance" => { ..items[index], stance: value, }
        "note" => { ..items[index], note: value, }
        _ => return state
      }
      { ..draft, items, }
    }
    Move(index, delta) => {
      let target = index + delta
      guard (delta == -1 || delta == 1) &&
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
    Intake(text) => {
      guard text.length() <= 1048576 && lesson_notebook_fits(text) else {
        return {
          ..state,
          preview: None,
          notice: "Paste at most 1 MiB UTF-8. Existing intake and notebook are kept.",
        }
      }
      return {
        ..state,
        revision: revision + 1,
        intake: text,
        preview: None,
        notice: "",
      }
    }
    Preview =>
      return match lesson_notebook_decode(state.intake) {
        Ok(preview) =>
          {
            ..state,
            revision: revision + 1,
            preview: Some(preview),
            notice: "Preview ready. Imported captures are claims in a file, not fresh host review. Replace explicitly to resume.",
          }
        Err(error) => { ..state, preview: None, notice: error, }
      }
    Restore => {
      guard state.preview is Some(preview) else { return state }
      return {
        ..state,
        revision: revision + 1,
        draft: preview,
        preview: None,
        notice: "Notebook restored as authored planning text. Reload reviewed lessons to compare every capture before reuse.",
      }
    }
    Downloaded(result) =>
      return {
        ..state,
        notice: match result {
          Ok(text) => text
          Err(error) => "Download failed: " + error + ". Your notebook is kept."
        },
      }
    Download(_) | Recheck => return state
  }
  match lesson_notebook_decode(changed.to_json().stringify()) {
    Ok(_) =>
      {
        ..state,
        revision: revision + 1,
        draft: changed,
        preview: None,
        notice: "Notebook edited locally. Download JSON to keep it across reloads.",
      }
    Err(error) => { ..state, notice: error, }
  }
}

///|
fn lesson_notebook_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  revision : Int,
  action : LessonNotebookMsg,
) -> (@rabbita.Cmd, Model) {
  let workspace = model.outcome_lessons
  let state = workspace.notebook
  guard revision == state.revision else { return (@rabbita.none, model) }
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
  if action is Download(html) {
    guard !html ||
      (!state.draft.items.is_empty() && !state.draft.question.is_blank()) else {
      return (
        @rabbita.none,
        {
          ..model,
          outcome_lessons: {
            ..workspace,
            notebook: {
              ..state,
              notice: "Add at least one experience and a decision question before exporting HTML.",
            },
          },
        },
      )
    }
    let text = if html {
      lesson_notebook_html(state.draft)
    } else {
      state.draft.to_json().stringify(indent=2) + "\n"
    }
    return (
      @rabbita.perform(
        result => emit(OutcomeLesson(Notebook(revision, Downloaded(result)))),
        async fn() noraise {
          let result : String = lesson_notebook_download(text, html)
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
        notebook: lesson_notebook_reduce(
          state,
          workspace.browser,
          revision,
          action,
        ),
      },
    },
  )
}
