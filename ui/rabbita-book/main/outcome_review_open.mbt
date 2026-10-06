///|
fn outcome_review_record(
  model : Model,
  reference : Json,
) -> BookkeeperRawRecord? {
  guard !model.bookkeeper_busy &&
    !model.bookkeeper_reads.store_loading &&
    model.bookkeeper_reads.store_error is None &&
    model.bookkeeper_store is Some(snapshot) &&
    snapshot.replay_issues.is_empty() &&
    model.outcome_lessons.handoff is Some(readback) &&
    outcome_review_items(readback).any(item => {
      let state = lesson_task_text(item, "state")
      (
        state == "deliverable_review_required" ||
        state == "assessment_review_required"
      ) &&
      lesson_task_field(item, "next_record") == reference
    }) else {
    return None
  }
  let matches = snapshot.records.filter(record => {
    record.record.record_id == lesson_task_text(reference, "record_id") &&
    record.record.record_version ==
    lesson_task_text(reference, "record_version")
  })
  if matches.length() == 1 && ToJson::to_json(matches[0].record) == reference {
    Some(matches[0])
  } else {
    None
  }
}

///|
fn outcome_review_open(
  emit : @rabbita.Emit[Msg],
  model : Model,
  reference : Json,
) -> (@rabbita.Cmd, Model) {
  guard !model.outcome_lessons.outcome_review.pending &&
    !model.outcome_lessons.pending &&
    outcome_review_record(model, reference) is Some(record) else {
    return (@rabbita.none, model)
  }
  // The existing selection handler stashes each unsaved review draft by its
  // exact context. Never assign the selected record or authoring draft here.
  let (command, next) = update(
    emit,
    SelectBookkeeperItem(lesson_record_item(record)),
    model,
  )
  (
    @rabbita.batch([
      command,
      @cmd.custom_cmd(_ => outcome_review_scroll(), kind=@cmd.after_render),
    ]),
    next,
  )
}

///|
extern "js" fn outcome_review_scroll() =
  #| () => { const node=globalThis.document?.getElementById('bookkeeper-review-controls'); node?.scrollIntoView?.({block:'center'}); }
