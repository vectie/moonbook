///|
priv struct BookRetainedText {
  key : String
  label : String
  text : String
}

///|
priv struct BookDraftRecovery {
  decision : String
  note_key : String?
  summary : String
  edited : Bool
  notes : Array[BookRetainedText]
  technical : Array[BookRetainedText]
  technical_edited : Bool
  bound_context : String?
  saved : String?
  storage_request : Int
  storage_pending : Bool
  storage_notice : String?
}

///|
priv enum BookDraftMsg {
  EditSummary(String)
  SaveSummary
  RestoreSummary
  DiscardSummary
  StorageFinished(Int, String, String, Result[String?, String])
  RestoreTechnical
}

///|
fn initial_book_draft_recovery() -> BookDraftRecovery {
  {
    decision: "Accept",
    note_key: None,
    summary: "",
    edited: false,
    notes: [],
    technical: [],
    technical_edited: false,
    bound_context: None,
    saved: None,
    storage_request: 0,
    storage_pending: false,
    storage_notice: None,
  }
}

///|
fn book_draft_default_summary(decision : String) -> String {
  if decision == "Reject" {
    "Named reviewer rejected the exact selected record and evidence."
  } else {
    "Named reviewer accepted the exact selected record and evidence."
  }
}

///|
/// This key is only a local text locator. It never restores a selection, grant,
/// evidence, decision, pending operation or executable payload.
fn book_note_key(model : Model) -> String? {
  guard model.bookkeeper_mode == "review" else { return None }
  guard model.selected_bookkeeper_record is Some(reference) else { return None }
  guard selected_raw_record(model, reference) is Some(record) &&
    record.record == reference else {
    return None
  }
  let workspace = model.state.bookkeeper.source_path
  guard !workspace.trim().is_empty() else { return None }
  Some(
    (
      {
        "workspace": workspace,
        "record": ToJson::to_json(reference),
        "decision": model.draft_recovery.decision,
      } : Json).stringify(),
  )
}

///|
/// Full evidence remains in memory only. A changed record, grant, authority or
/// evidence set creates another context and cannot silently reuse a payload.
/// Work-order modes also bind the existing builder's current prerequisite
/// result, including its accepted review receipt or unavailability.
fn book_technical_context(model : Model) -> String {
  let record = match model.selected_bookkeeper_record {
    Some(reference) => selected_raw_record(model, reference).to_json()
    None => Json::null()
  }
  (
    {
      "workspace": model.state.bookkeeper.source_path,
      "mode": model.bookkeeper_mode,
      "decision": model.draft_recovery.decision,
      "selection": model.selected_bookkeeper_record.to_json(),
      "record": record,
      "authority": selected_authority_grant(model).to_json(),
      "work_order_prerequisite": match model.bookkeeper_mode {
        "project-work-order" =>
          governed_work_order_draft(model, false).to_json()
        "egress-work-order" => governed_work_order_draft(model, true).to_json()
        _ => Json::null()
      },
    } : Json).stringify()
}

///|
/// Reuse the governed builder's existing prerequisite policy. An unavailable
/// template is never permission to restore a formerly executable payload,
/// including technical text originally edited while that prerequisite failed.
fn book_technical_restore_ready(model : Model) -> Bool {
  match model.bookkeeper_mode {
    "project-work-order" => governed_work_order_draft(model, false) is Ok(_)
    "egress-work-order" => governed_work_order_draft(model, true) is Ok(_)
    _ => true
  }
}

///|
fn book_draft_label(model : Model) -> String {
  let record = match model.selected_bookkeeper_record {
    Some(reference) =>
      reference.record_id +
      " · " +
      reference.record_version +
      " · " +
      reference.record_digest
    None => "No record selected"
  }
  model.bookkeeper_mode +
  " · " +
  model.draft_recovery.decision +
  " · " +
  record
}

///|
fn book_retained_text(items : Array[BookRetainedText], key : String) -> String? {
  for item in items {
    if item.key == key {
      return Some(item.text)
    }
  }
  None
}

///|
fn book_retain_text(
  items : Array[BookRetainedText],
  key : String,
  label : String,
  text : String,
) -> Array[BookRetainedText] {
  items.filter(item => item.key != key) + [{ key, label, text, }]
}

///|
fn book_stash_drafts(model : Model) -> Model {
  let drafts = model.draft_recovery
  let notes = match drafts.note_key {
    Some(key) if drafts.edited =>
      book_retain_text(
        drafts.notes,
        key,
        book_draft_label(model),
        drafts.summary,
      )
    _ => drafts.notes
  }
  let technical = match drafts.bound_context {
    Some(key) if drafts.technical_edited =>
      book_retain_text(
        drafts.technical,
        key,
        book_draft_label(model),
        model.bookkeeper_draft,
      )
    _ => drafts.technical
  }
  { ..model, draft_recovery: { ..drafts, notes, technical, }, }
}

///|
fn book_json_summary(text : String) -> String? {
  try @json.parse(text) catch {
    _ => None
  } noraise {
    { "summary": String(summary), .. } => Some(summary)
    _ => None
  }
}

///|
fn book_replace_summary(text : String, summary : String) -> String {
  try @json.parse(text) catch {
    _ => text
  } noraise {
    Object(fields) => {
      // Parsing creates a fresh map; no model-owned JSON is mutated.
      fields["summary"] = Json::string(summary)
      Json::object(fields).stringify(indent=2)
    }
    _ => text
  }
}

///|
fn book_draft_is_stale(model : Model) -> Bool {
  match model.draft_recovery.bound_context {
    Some(context) => context != book_technical_context(model)
    None => false
  }
}

///|
fn book_draft_waiting_for_evidence(model : Model) -> Bool {
  model.draft_recovery.bound_context is Some(_) &&
  (
    model.bookkeeper_reads.store_loading ||
    model.bookkeeper_reads.authorities_loading ||
    model.bookkeeper_reads.store_error is Some(_) ||
    model.bookkeeper_reads.authorities_error is Some(_)
  )
}

///|
fn book_summary_edit(model : Model, text : String) -> Model {
  let drafts = model.draft_recovery
  let next = {
    ..model,
    draft_recovery: { ..drafts, summary: text, edited: true, },
    bookkeeper_draft: if model.bookkeeper_mode == "review" &&
      !book_draft_is_stale(model) {
      book_replace_summary(model.bookkeeper_draft, text)
    } else {
      model.bookkeeper_draft
    },
  }
  book_stash_drafts(next)
}

///|
fn book_activate_draft(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let drafts = model.draft_recovery
  let key = book_note_key(model)
  let retained = match key {
    Some(value) => book_retained_text(drafts.notes, value)
    None => None
  }
  let summary = retained.unwrap_or(book_draft_default_summary(drafts.decision))
  // A context change always starts from current source data or a neutral
  // template. Retained technical edits require the explicit restore action.
  let generated = match model.bookkeeper_mode {
    "review" =>
      review_draft_for_selection(model, drafts.decision).unwrap_or(
        bookkeeper_mode_template("review"),
      )
    "project-work-order" =>
      governed_work_order_draft(model, false).unwrap_or(
        bookkeeper_mode_template("project-work-order"),
      )
    "egress-work-order" =>
      governed_work_order_draft(model, true).unwrap_or(
        bookkeeper_mode_template("egress-work-order"),
      )
    mode => bookkeeper_mode_template(mode)
  }
  let request = drafts.storage_request + 1
  let next = {
    ..model,
    bookkeeper_draft: if model.bookkeeper_mode == "review" {
      book_replace_summary(generated, summary)
    } else {
      generated
    },
    draft_recovery: {
      ..drafts,
      note_key: key,
      summary,
      edited: retained is Some(_),
      technical_edited: false,
      bound_context: Some(book_technical_context(model)),
      saved: None,
      storage_request: request,
      storage_pending: key is Some(_),
      storage_notice: None,
    },
  }
  match key {
    Some(value) =>
      (book_summary_storage_cmd(emit, request, "read", value, ""), next)
    None => (@rabbita.none, next)
  }
}

///|
fn update(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    // Same-context clicks are harmless, even for partially written JSON.
    SelectBookkeeperItem(item) if model.selected_bookkeeper_record
      is Some(reference) &&
      item.record_id == reference.record_id &&
      item.record_version == reference.record_version &&
      !book_draft_is_stale(model) => (@rabbita.none, model)
    SelectBookkeeperAuthority(authority) if model.selected_bookkeeper_authority ==
      Some(authority) &&
      !book_draft_is_stale(model) => (@rabbita.none, model)
    SetBookkeeperMode(mode) if model.bookkeeper_mode == mode &&
      !book_draft_is_stale(model) => (@rabbita.none, model)
    PrepareBookkeeperReview(decision) if model.bookkeeper_mode == "review" &&
      model.draft_recovery.decision == decision &&
      !book_draft_is_stale(model) => (@rabbita.none, model)
    SelectBookkeeperItem(_)
    | SelectBookkeeperAuthority(_)
    | SetBookkeeperMode(_)
    | PrepareBookkeeperReview(_) => {
      let saved = book_stash_drafts(model)
      let saved = match msg {
        PrepareBookkeeperReview(decision) => {
          let selected = match saved.selected_bookkeeper_record {
            Some(reference) =>
              match selected_raw_record(saved, reference) {
                Some(record) => Some(record.record)
                None => saved.selected_bookkeeper_record
              }
            None => None
          }
          {
            ..saved,
            selected_bookkeeper_record: selected,
            draft_recovery: { ..saved.draft_recovery, decision, },
          }
        }
        _ => saved
      }
      let (command, next) = update_core(emit, msg, saved)
      let (recovery, next) = book_activate_draft(emit, next)
      (@rabbita.batch([command, recovery]), next)
    }
    SetBookkeeperDraft(text) => {
      let drafts = model.draft_recovery
      let summary = if model.bookkeeper_mode == "review" {
        book_json_summary(text).unwrap_or(drafts.summary)
      } else {
        drafts.summary
      }
      let next = {
        ..model,
        bookkeeper_draft: text,
        draft_recovery: {
          ..drafts,
          summary,
          edited: drafts.edited || summary != drafts.summary,
          technical_edited: true,
          bound_context: Some(
            drafts.bound_context.unwrap_or(book_technical_context(model)),
          ),
        },
      }
      (@rabbita.none, book_stash_drafts(next))
    }
    SubmitBookkeeperMutation if !model.bookkeeper_busy &&
      book_draft_is_stale(model) =>
      (
        @rabbita.none,
        {
          ..model,
          bookkeeper_notice: Some(
            "The record or reviewer evidence changed. Prepare a fresh review before saving. Your text is retained in this tab.",
          ),
        },
      )
    SubmitBookkeeperMutation if !model.bookkeeper_busy &&
      book_draft_waiting_for_evidence(model) =>
      (
        @rabbita.none,
        {
          ..model,
          bookkeeper_notice: Some(
            "Current record and reviewer evidence is still loading or unavailable. Refresh the snapshot before saving; your text is retained.",
          ),
        },
      )
    _ => update_core(emit, msg, model)
  }
}

///|
fn book_draft_reduce(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : BookDraftMsg,
) -> (@rabbita.Cmd, Model) {
  let drafts = model.draft_recovery
  match message {
    EditSummary(text) => (@rabbita.none, book_summary_edit(model, text))
    RestoreSummary =>
      match drafts.saved {
        Some(text) => {
          let restored = book_summary_edit(model, text)
          (
            @rabbita.none,
            {
              ..restored,
              draft_recovery: {
                ..restored.draft_recovery,
                storage_notice: Some(
                  "Local summary restored. Check the current record and evidence before saving the review.",
                ),
              },
            },
          )
        }
        None => (@rabbita.none, model)
      }
    SaveSummary | DiscardSummary => {
      guard drafts.note_key is Some(key) else {
        return (
          @rabbita.none,
          {
            ..model,
            draft_recovery: {
              ..drafts,
              storage_notice: Some(
                "Select an exact record and prepare a review before saving a local summary.",
              ),
            },
          },
        )
      }
      let operation = if message is SaveSummary { "save" } else { "discard" }
      let request = drafts.storage_request + 1
      (
        book_summary_storage_cmd(emit, request, operation, key, drafts.summary),
        {
          ..model,
          draft_recovery: {
            ..drafts,
            storage_request: request,
            storage_pending: true,
            storage_notice: Some(
              if operation == "save" {
                "Saving summary in this browser…"
              } else {
                "Discarding saved summary…"
              },
            ),
          },
        },
      )
    }
    StorageFinished(request, key, operation, result) => {
      guard request == drafts.storage_request &&
        drafts.storage_pending &&
        drafts.note_key == Some(key) else {
        return (@rabbita.none, model)
      }
      let (saved, notice) = match result {
        Ok(text) =>
          (
            text,
            Some(
              match operation {
                "save" =>
                  if text == Some(drafts.summary) {
                    "Summary saved in this browser only. The review has not been submitted."
                  } else {
                    "An earlier summary was saved locally. Your newer text is still here; save it when ready."
                  }
                "discard" =>
                  "Saved local summary discarded. Text in this tab is unchanged."
                _ =>
                  if text is Some(_) {
                    "A saved local summary is available. Restore it to use the text."
                  } else {
                    "No saved local summary for this exact review."
                  }
              },
            ),
          )
        Err(error) =>
          (
            drafts.saved,
            Some(
              "Local draft storage unavailable: " +
              error +
              " Your text remains in this tab. Copy it before leaving.",
            ),
          )
      }
      (
        @rabbita.none,
        {
          ..model,
          draft_recovery: {
            ..drafts,
            saved,
            storage_notice: notice,
            storage_pending: false,
          },
        },
      )
    }
    RestoreTechnical => {
      guard !model.bookkeeper_busy &&
        !book_draft_is_stale(model) &&
        !book_draft_waiting_for_evidence(model) &&
        book_technical_restore_ready(model) else {
        return (@rabbita.none, model)
      }
      match
        book_retained_text(drafts.technical, book_technical_context(model)) {
        Some(text) => update(emit, SetBookkeeperDraft(text), model)
        None => (@rabbita.none, model)
      }
    }
  }
}
