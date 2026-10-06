///|
fn outcome_test_reference() -> Json {
  {
    "record_id": "completed-outcome",
    "record_version": "2",
    "record_digest": "sha256:" + "c".repeat(64),
  }
}

///|
fn outcome_test_submission() -> Json {
  {
    "contract_version": "moonbook.bookkeeper.product_outcome_submission.v1",
    "submission": outcome_test_reference(),
    "source_product": "fixture-product",
    "deliverable_title": "Outcome <&> 中文",
    "deliverable_summary": "Preserved source result",
    "outcome_summary": "Supplied observed outcome",
    "decision_evidence_id": "fixture-evidence",
    "evidence_refs": [
      {
        "reference_id": "fixture-evidence",
        "provenance_ref": "fixture://evidence",
      },
    ],
    "unknown_preserved_field": { "exact": [1, false, "unchanged"] },
  }
}

///|
fn outcome_test_replace(value : Json, key : String, replacement : Json) -> Json {
  guard value is Object(fields) else { return value }
  let fields = fields.copy()
  fields[key] = replacement
  Json::object(fields)
}

///|
fn outcome_test_readback(state : String) -> Json {
  let next = if state == "deliverable_review_required" ||
    state == "assessment_review_required" {
    ToJson::to_json(draft_test_record("second").record)
  } else {
    Json::null()
  }
  let base = outcome_test_replace(
    lesson_receiver_test_readback(),
    "sources",
    Json::array([]),
  )
  outcome_test_replace(base, "outcome_submissions", [
    {
      "submission": outcome_test_reference(),
      "deliverable": ToJson::to_json(draft_test_record("second").record),
      "title": "Outcome <&> 中文",
      "outcome_summary": "Supplied observed outcome",
      "state": state,
      "next_record": next,
    },
  ])
}

///|
fn outcome_test_model(state : String) -> Model {
  let prepared = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary("  My unsaved review <&> 中文\nKept exactly  ")),
  )
  let readback = outcome_test_readback(state)
  {
    ..prepared,
    bookkeeper_reads: {
      ..prepared.bookkeeper_reads,
      store_loading: false,
      authorities_loading: false,
    },
    outcome_lessons: {
      ..lesson_workspace_fixture(),
      handoff: Some(readback),
      outcome_review: {
        ..initial_outcome_review_workspace(),
        binding: Some(lesson_task_field(readback, "handoff")),
        preview: Some(outcome_test_submission()),
      },
    },
  }
}

///|
fn outcome_test_step(model : Model, message : OutcomeReviewMsg) -> Model {
  snapshot_test_step(model, OutcomeLesson(OutcomeReview(message)))
}

///|
fn outcome_test_drafts_kept(before : Model, after : Model) -> Unit raise {
  assert_eq(after.selected_bookkeeper_record, before.selected_bookkeeper_record)
  assert_eq(after.bookkeeper_draft, before.bookkeeper_draft)
  assert_eq(after.draft_recovery.summary, before.draft_recovery.summary)
  assert_eq(after.outcome_lessons.fields, before.outcome_lessons.fields)
  assert_eq(after.outcome_lessons.source, before.outcome_lessons.source)
  assert_eq(after.outcome_lessons.lesson_id, before.outcome_lessons.lesson_id)
  assert_eq(
    after.outcome_lessons.history.selected,
    before.outcome_lessons.history.selected,
  )
  assert_eq(
    after.outcome_lessons.saved_return.selected,
    before.outcome_lessons.saved_return.selected,
  )
}

///|
test "outcome file stays a preview until explicit save and retry preserves exact payload and drafts" {
  let original = outcome_test_model("deliverable_review_required")
  let picking = outcome_test_step(original, PickOutcome)
  assert_true(picking.outcome_lessons.outcome_review.pending)
  assert_eq(picking.outcome_lessons.outcome_review.operation, "pick")
  assert_true(picking.outcome_lessons.outcome_review.preview is None)
  let duplicate = outcome_test_step(picking, PickOutcome)
  assert_eq(
    duplicate.outcome_lessons.outcome_review.request,
    picking.outcome_lessons.outcome_review.request,
  )
  let binding = outcome_review_binding(original).unwrap()
  let preview = outcome_test_step(
    picking,
    OutcomePicked(
      picking.outcome_lessons.outcome_review.request,
      binding,
      Ok(outcome_test_submission().stringify()),
    ),
  )
  assert_false(preview.outcome_lessons.outcome_review.pending)
  assert_eq(
    preview.outcome_lessons.outcome_review.preview,
    Some(outcome_test_submission()),
  )
  outcome_test_drafts_kept(original, preview)
  let saving = outcome_test_step(preview, SaveOutcome)
  assert_eq(saving.outcome_lessons.outcome_review.operation, "outcome-import")
  let repeated = outcome_test_step(saving, SaveOutcome)
  assert_eq(
    repeated.outcome_lessons.outcome_review.request,
    saving.outcome_lessons.outcome_review.request,
  )
  let payload : Json = {
    "handoff": binding,
    "submission": outcome_test_submission(),
  }
  let failed = outcome_test_step(
    saving,
    OutcomeRead(
      saving.outcome_lessons.outcome_review.request,
      "outcome-import",
      payload,
      Err("network interrupted"),
    ),
  )
  assert_eq(
    failed.outcome_lessons.outcome_review.preview,
    preview.outcome_lessons.outcome_review.preview,
  )
  assert_true(
    failed.outcome_lessons.outcome_review.notice.contains(
      "does not prove nothing was saved",
    ),
  )
  outcome_test_drafts_kept(original, failed)
  let retry = outcome_test_step(failed, SaveOutcome)
  assert_true(
    retry.outcome_lessons.outcome_review.request >
    saving.outcome_lessons.outcome_review.request,
  )
  let saved = outcome_test_step(
    retry,
    OutcomeRead(
      retry.outcome_lessons.outcome_review.request,
      "outcome-import",
      payload,
      Ok(outcome_test_readback("deliverable_review_required")),
    ),
  )
  assert_false(saved.outcome_lessons.outcome_review.pending)
  assert_true(saved.outcome_lessons.outcome_review.preview is None)
  outcome_test_drafts_kept(original, saved)
}

///|
test "malformed cancelled and unsupported outcome previews never save or erase lesson and review drafts" {
  let original = outcome_test_model("deliverable_review_required")
  for result in [Ok("not JSON"), Ok("{}"), Err("No file chosen")] {
    let picking = outcome_test_step(original, PickOutcome)
    let failed = outcome_test_step(
      picking,
      OutcomePicked(
        picking.outcome_lessons.outcome_review.request,
        outcome_review_binding(original).unwrap(),
        result,
      ),
    )
    assert_false(failed.outcome_lessons.outcome_review.pending)
    assert_true(failed.outcome_lessons.outcome_review.preview is None)
    let blocked = outcome_test_step(failed, SaveOutcome)
    assert_false(blocked.outcome_lessons.outcome_review.pending)
    outcome_test_drafts_kept(original, blocked)
  }
}

///|
test "continuation requires explicit current continue state and stops at refreshed assessment review" {
  for
    state in [
      "deliverable_review_required", "deliverable_rejected", "assessment_review_required",
      "assessment_rejected", "reviewed_source_available",
    ] {
    let model = outcome_test_model(state)
    assert_false(
      outcome_test_step(model, ContinueOutcome(outcome_test_reference())).outcome_lessons.outcome_review.pending,
    )
  }
  let original = outcome_test_model("continue_required")
  let started = outcome_test_step(
    original,
    ContinueOutcome(outcome_test_reference()),
  )
  assert_true(started.outcome_lessons.outcome_review.pending)
  assert_eq(
    started.outcome_lessons.outcome_review.operation,
    "outcome-continue",
  )
  assert_eq(
    outcome_test_step(started, ContinueOutcome(outcome_test_reference())).outcome_lessons.outcome_review.request,
    started.outcome_lessons.outcome_review.request,
  )
  let payload : Json = {
    "handoff": outcome_review_binding(original).unwrap(),
    "submission": outcome_test_reference(),
  }
  let finished = outcome_test_step(
    started,
    OutcomeRead(
      started.outcome_lessons.outcome_review.request,
      "outcome-continue",
      payload,
      Ok(outcome_test_readback("assessment_review_required")),
    ),
  )
  assert_false(finished.outcome_lessons.outcome_review.pending)
  assert_eq(
    lesson_task_text(
      outcome_review_items(finished.outcome_lessons.handoff.unwrap())[0],
      "state",
    ),
    "assessment_review_required",
  )
  outcome_test_drafts_kept(original, finished)
  assert_false(
    outcome_test_step(finished, ContinueOutcome(outcome_test_reference())).outcome_lessons.outcome_review.pending,
  )
}

///|
test "late outcome replies cannot replace a newly received task or its drafts" {
  let original = outcome_test_model("continue_required")
  let started = outcome_test_step(original, SaveOutcome)
  let switched = snapshot_test_step(started, OutcomeLesson(ImportTask))
  assert_true(switched.outcome_lessons.handoff is None)
  assert_false(switched.outcome_lessons.outcome_review.pending)
  let payload : Json = {
    "handoff": outcome_review_binding(original).unwrap(),
    "submission": outcome_test_submission(),
  }
  let stale = outcome_test_step(
    switched,
    OutcomeRead(
      started.outcome_lessons.outcome_review.request,
      "outcome-import",
      payload,
      Ok(outcome_test_readback("assessment_review_required")),
    ),
  )
  assert_true(stale.outcome_lessons.handoff is None)
  assert_eq(
    stale.outcome_lessons.outcome_review.request,
    switched.outcome_lessons.outcome_review.request,
  )
  outcome_test_drafts_kept(original, stale)
  let picking = outcome_test_step(original, PickOutcome)
  let switched = snapshot_test_step(picking, OutcomeLesson(ImportTask))
  let stale = outcome_test_step(
    switched,
    OutcomePicked(
      picking.outcome_lessons.outcome_review.request,
      outcome_review_binding(original).unwrap(),
      Ok(outcome_test_submission().stringify()),
    ),
  )
  assert_true(stale.outcome_lessons.outcome_review.preview is None)
  outcome_test_drafts_kept(original, stale)
}

///|
test "opening exact pending review uses existing draft recovery and no automatic decision" {
  let original = outcome_test_model("deliverable_review_required")
  let reference = ToJson::to_json(draft_test_record("second").record)
  let opened = outcome_test_step(original, OpenOutcomeReview(reference))
  assert_eq(
    opened.selected_bookkeeper_record,
    Some(draft_test_record("second").record),
  )
  assert_false(opened.bookkeeper_busy)
  assert_eq(opened.outcome_lessons.fields, original.outcome_lessons.fields)
  assert_eq(opened.outcome_lessons.source, original.outcome_lessons.source)
  let returned = snapshot_test_step(
    opened,
    SelectBookkeeperItem(draft_test_item("first")),
  )
  assert_eq(returned.draft_recovery.summary, original.draft_recovery.summary)
  assert_eq(
    book_json_summary(returned.bookkeeper_draft),
    book_json_summary(original.bookkeeper_draft),
  )
  let incorrect = outcome_test_replace(
    reference, "record_digest", "different-digest",
  )
  let ignored = outcome_test_step(original, OpenOutcomeReview(incorrect))
  outcome_test_drafts_kept(original, ignored)
  let blocked = outcome_test_step(
    { ..original, bookkeeper_busy: true, },
    OpenOutcomeReview(reference),
  )
  outcome_test_drafts_kept(original, blocked)
  let snapshot = original.bookkeeper_store.unwrap()
  let conflicting = {
    ..original,
    bookkeeper_store: Some({
      ..snapshot,
      records: snapshot.records +
      [draft_test_record("second", digest="other-digest")],
    }),
  }
  assert_true(outcome_review_record(conflicting, reference) is None)
  let ignored = outcome_test_step(conflicting, OpenOutcomeReview(reference))
  outcome_test_drafts_kept(original, ignored)
}

///|
test "outcome refresh rejects mismatched binding and stale completions while retaining imported preview" {
  let original = outcome_test_model("continue_required")
  let loading = outcome_test_step(original, RefreshOutcomes)
  let binding = outcome_review_binding(original).unwrap()
  let wrong = outcome_test_replace(
    outcome_test_readback("assessment_review_required"),
    "handoff",
    { "wrong": "task" },
  )
  let stale = outcome_test_step(
    loading,
    OutcomeRead(
      loading.outcome_lessons.outcome_review.request - 1,
      "task-handoff",
      binding,
      Ok(wrong),
    ),
  )
  assert_true(stale.outcome_lessons.outcome_review.pending)
  let rejected = outcome_test_step(
    loading,
    OutcomeRead(
      loading.outcome_lessons.outcome_review.request,
      "task-handoff",
      binding,
      Ok(wrong),
    ),
  )
  assert_false(rejected.outcome_lessons.outcome_review.pending)
  assert_eq(rejected.outcome_lessons.handoff, original.outcome_lessons.handoff)
  assert_eq(
    rejected.outcome_lessons.outcome_review.preview,
    original.outcome_lessons.outcome_review.preview,
  )
  outcome_test_drafts_kept(original, rejected)
  let retry = outcome_test_step(rejected, RefreshOutcomes)
  assert_true(retry.outcome_lessons.outcome_review.pending)
}

///|
test "opening outcome review preserves manually edited technical draft for explicit restore" {
  let original = outcome_test_model("deliverable_review_required")
  let original = snapshot_test_step(
    original,
    SetBookkeeperDraft(original.bookkeeper_draft + "\n  "),
  )
  let opened = outcome_test_step(
    original,
    OpenOutcomeReview(ToJson::to_json(draft_test_record("second").record)),
  )
  let returned = snapshot_test_step(
    opened,
    SelectBookkeeperItem(draft_test_item("first")),
  )
  let restored = snapshot_test_step(returned, DraftRecovery(RestoreTechnical))
  assert_eq(restored.bookkeeper_draft, original.bookkeeper_draft)
  assert_eq(restored.outcome_lessons.fields, original.outcome_lessons.fields)
}

///|
test "outcome and saved lesson readbacks cannot overlap and refresh preserves exact receipt selection" {
  let initial = outcome_test_model("continue_required")
  let receipt = saved_return_test_entry()
  let readback = outcome_test_replace(
    initial.outcome_lessons.handoff.unwrap(),
    "saved_lessons",
    [receipt],
  )
  let original = {
    ..initial,
    outcome_lessons: {
      ..initial.outcome_lessons,
      handoff: Some(readback),
      saved_return: {
        ..initial_saved_lesson_return(),
        selected: saved_lesson_reference(lesson_task_field(receipt, "lesson")),
        observed_at: 1,
      },
    },
  }
  let refreshing = outcome_test_step(original, RefreshOutcomes)
  for action in ["refresh", "return", "export"] {
    let blocked = snapshot_test_step(
      refreshing,
      OutcomeLesson(RefreshSavedLessons(action)),
    )
    assert_false(blocked.outcome_lessons.pending)
    assert_eq(blocked.outcome_lessons.request, original.outcome_lessons.request)
  }
  let finished = outcome_test_step(
    refreshing,
    OutcomeRead(
      refreshing.outcome_lessons.outcome_review.request,
      "task-handoff",
      outcome_review_binding(original).unwrap(),
      Ok(readback),
    ),
  )
  assert_eq(
    finished.outcome_lessons.saved_return.selected,
    original.outcome_lessons.saved_return.selected,
  )
  assert_true(finished.outcome_lessons.saved_return.observed_at > 1)
  outcome_test_drafts_kept(original, finished)
  let saved_loading = snapshot_test_step(
    original,
    OutcomeLesson(RefreshSavedLessons("refresh")),
  )
  assert_true(saved_loading.outcome_lessons.pending)
  assert_false(
    outcome_test_step(saved_loading, SaveOutcome).outcome_lessons.outcome_review.pending,
  )
  assert_false(
    outcome_test_step(saved_loading, ContinueOutcome(outcome_test_reference())).outcome_lessons.outcome_review.pending,
  )
}

///|
test "human review completed during outcome operation queues one fresh read after older response" {
  let original = outcome_test_model("continue_required")
  let started = outcome_test_step(
    original,
    ContinueOutcome(outcome_test_reference()),
  )
  let request = started.outcome_lessons.outcome_review.request
  let queued = outcome_test_step(
    outcome_test_step(started, RefreshOutcomes),
    RefreshOutcomes,
  )
  assert_true(queued.outcome_lessons.outcome_review.refresh_queued)
  assert_eq(queued.outcome_lessons.outcome_review.request, request)
  let binding = outcome_review_binding(original).unwrap()
  let payload : Json = {
    "handoff": binding,
    "submission": outcome_test_reference(),
  }
  let after_old = outcome_test_step(
    queued,
    OutcomeRead(
      request,
      "outcome-continue",
      payload,
      Ok(outcome_test_readback("assessment_review_required")),
    ),
  )
  assert_true(after_old.outcome_lessons.outcome_review.pending)
  assert_false(after_old.outcome_lessons.outcome_review.refresh_queued)
  assert_eq(after_old.outcome_lessons.outcome_review.operation, "task-handoff")
  assert_eq(after_old.outcome_lessons.outcome_review.request, request + 1)
  outcome_test_drafts_kept(original, after_old)
  assert_eq(
    after_old.outcome_lessons.outcome_review.preview,
    original.outcome_lessons.outcome_review.preview,
  )
  let refreshed = outcome_test_step(
    after_old,
    OutcomeRead(
      request + 1,
      "task-handoff",
      binding,
      Ok(outcome_test_readback("reviewed_source_available")),
    ),
  )
  assert_false(refreshed.outcome_lessons.outcome_review.pending)
  assert_false(refreshed.outcome_lessons.outcome_review.refresh_queued)
  assert_eq(
    lesson_task_text(
      outcome_review_items(refreshed.outcome_lessons.handoff.unwrap())[0],
      "state",
    ),
    "reviewed_source_available",
  )
  outcome_test_drafts_kept(original, refreshed)
  let switched = snapshot_test_step(queued, OutcomeLesson(ImportTask))
  assert_false(switched.outcome_lessons.outcome_review.refresh_queued)
  let ignored = outcome_test_step(
    switched,
    OutcomeRead(
      request,
      "outcome-continue",
      payload,
      Ok(outcome_test_readback("assessment_review_required")),
    ),
  )
  assert_false(ignored.outcome_lessons.outcome_review.pending)
  assert_true(ignored.outcome_lessons.handoff is None)
  // An unrelated lesson operation can finish later without losing the queued
  // outcome reread or replacing the authored lesson draft.
  let other_pending = {
    ..queued,
    outcome_lessons: { ..queued.outcome_lessons, pending: true, request: 88, },
  }
  let waiting = outcome_test_step(
    other_pending,
    OutcomeRead(
      request,
      "outcome-continue",
      payload,
      Ok(outcome_test_readback("assessment_review_required")),
    ),
  )
  assert_true(waiting.outcome_lessons.outcome_review.refresh_queued)
  assert_false(waiting.outcome_lessons.outcome_review.pending)
  let drained = snapshot_test_step(
    waiting,
    OutcomeLesson(
      Finished(88, "retrieve", Err("controlled lookup interruption")),
    ),
  )
  assert_true(drained.outcome_lessons.outcome_review.pending)
  assert_false(drained.outcome_lessons.outcome_review.refresh_queued)
  assert_eq(drained.outcome_lessons.outcome_review.operation, "task-handoff")
  outcome_test_drafts_kept(original, drained)
}

///|
test "outcome workflow SSR is ordered escaped collapsed and honest for rejection states" {
  for
    state in [
      "deliverable_review_required", "continue_required", "assessment_review_required",
      "deliverable_rejected", "assessment_rejected", "reviewed_source_available",
    ] {
    let model = outcome_test_model(state)
    let html = @rabbita.render_to_string(
      @rabbita.simple_cell(
        model~,
        update=fn(_ : Msg, old) { old },
        view=outcome_lesson_workspace_view,
      ),
    )
    for
      label in [
        "Outcome &lt;&amp;&gt; 中文", "Supplied observed outcome", "Save outcome for review",
        "Inspect supplied evidence references", "Inspect complete imported JSON",
        "Exact saved record references", "Internal task acceptance",
      ] {
      assert_true(html.contains(label), msg=label)
    }
    assert_false(html.contains("<details open"))
    assert_false(html.contains("<details open=\"true\""))
    if state == "deliverable_rejected" || state == "assessment_rejected" {
      assert_true(html.contains("rejected"))
      assert_false(html.contains(">Continue outcome review</button>"))
      assert_false(
        html.contains(">Open named-human review for this exact record</button>"),
      )
    }
    if state == "deliverable_review_required" ||
      state == "assessment_review_required" {
      assert_true(html.contains("Exact pending record · second @ v1"))
      assert_true(
        html.contains("Open named-human review for this exact record"),
      )
    }
  }
}
