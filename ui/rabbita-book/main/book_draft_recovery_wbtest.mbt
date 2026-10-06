///|
fn draft_test_record(
  id : String,
  digest? : String = "digest-v1",
) -> BookkeeperRawRecord {
  {
    contract_version: "moonbook.bookkeeper.store.v1",
    record: { record_id: id, record_version: "v1", record_digest: digest, },
    stage: "MoonCodeResult",
    subject: None,
    links: [],
    title: id,
    summary: "Server content",
    owner_route: "mooncode",
    status: "returned",
    evidence_refs: [
      {
        reference_id: "evidence",
        reference_version: "v1",
        digest: "server-evidence",
        provenance_ref: "fixture://evidence",
      },
    ],
    issue_refs: [],
    requires_human_review: true,
    next_action: "review",
    source_product: "mooncode",
    recorded_at: 1,
    payload: { "secret_fixture": "not-for-local-storage" },
    side_effects_applied: false,
  }
}

///|
fn draft_test_item(id : String) -> BookkeeperItem {
  {
    stage: "MoonCodeResult",
    title: id,
    record_id: id,
    record_version: "v1",
    status: "returned",
    tone: "review",
    summary: "Server content",
    owner_route: "mooncode",
    evidence_count: 1,
    issue_count: 0,
    requires_human_review: true,
    next_action: "review",
  }
}

///|
fn draft_test_model() -> Model {
  let first = draft_test_record("first")
  {
    ..guided_book_model(wiki_review_initial_state()),
    bookkeeper_store: Some({
      ..live_test_store(1),
      records: [first, draft_test_record("second")],
    }),
    bookkeeper_authorities: Some(live_test_registry("reviewer")),
    selected_bookkeeper_record: Some(first.record),
    selected_bookkeeper_authority: Some("reviewer"),
  }
}

///|
fn draft_test_prepared() -> Model {
  let ready = snapshot_test_step(
    draft_test_model(),
    PrepareBookkeeperReview("Accept"),
  )
  {
    ..ready,
    draft_recovery: { ..ready.draft_recovery, storage_pending: false, },
  }
}

///|
fn draft_test_editor(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=book_summary_editor,
    ),
  )
}

///|
test "review summary stays exact through repeated record authority decision and mode clicks" {
  let note = "  My own reasons <&> 中文 😀\n\nSecond paragraph.  "
  let edited = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary(note)),
  )
  let raw = edited.bookkeeper_draft
  let mut next = edited
  for
    message in [
      SelectBookkeeperItem(draft_test_item("first")),
      SelectBookkeeperAuthority("reviewer"),
      PrepareBookkeeperReview("Accept"),
      SetBookkeeperMode("review"),
    ] {
    next = snapshot_test_step(next, message)
    assert_eq(next.draft_recovery.summary, note)
    assert_eq(next.bookkeeper_draft, raw)
  }
  assert_eq(book_json_summary(raw), Some(note))
  let html = draft_test_editor(next)
  assert_true(html.contains("Review summary"))
  assert_true(html.contains("Save summary locally"))
  assert_true(html.contains("Restore saved summary"))
  assert_true(html.contains("Discard saved summary"))
  assert_true(html.contains("not saved locally"))
  assert_true(html.contains("&lt;&amp;&gt;"))
}

///|
test "switching record decision and mode retains each summary without reusing authority" {
  let first = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary("First acceptance")),
  )
  let second = snapshot_test_step(
    first,
    SelectBookkeeperItem(draft_test_item("second")),
  )
  assert_eq(second.draft_recovery.summary, book_draft_default_summary("Accept"))
  let second = snapshot_test_step(
    second,
    DraftRecovery(EditSummary("Second acceptance")),
  )
  let reject = snapshot_test_step(second, PrepareBookkeeperReview("Reject"))
  assert_eq(reject.draft_recovery.summary, book_draft_default_summary("Reject"))
  let reject = snapshot_test_step(
    reject,
    DraftRecovery(EditSummary("Second rejection")),
  )
  let mode = snapshot_test_step(reject, SetBookkeeperMode("ingress"))
  let returned = snapshot_test_step(mode, SetBookkeeperMode("review"))
  assert_eq(returned.draft_recovery.decision, "Reject")
  assert_eq(returned.draft_recovery.summary, "Second rejection")
  let returned = snapshot_test_step(returned, PrepareBookkeeperReview("Accept"))
  assert_eq(returned.draft_recovery.summary, "Second acceptance")
  let returned = snapshot_test_step(
    returned,
    SelectBookkeeperItem(draft_test_item("first")),
  )
  assert_eq(returned.draft_recovery.summary, "First acceptance")
  assert_eq(
    book_json_summary(returned.bookkeeper_draft),
    Some("First acceptance"),
  )
  assert_true(draft_test_editor(returned).contains("Second rejection"))
}

///|
test "partial advanced JSON remains exact but is never silently restored into an executable draft" {
  let partial = "{\n  \"summary\": \"unfinished <&> 中文"
  let edited = snapshot_test_step(
    draft_test_prepared(),
    SetBookkeeperDraft(partial),
  )
  let repeated = snapshot_test_step(
    edited,
    SelectBookkeeperItem(draft_test_item("first")),
  )
  assert_eq(repeated.bookkeeper_draft, partial)
  let second = snapshot_test_step(
    repeated,
    SelectBookkeeperItem(draft_test_item("second")),
  )
  let back = snapshot_test_step(
    second,
    SelectBookkeeperItem(draft_test_item("first")),
  )
  assert_true(back.bookkeeper_draft != partial)
  assert_eq(
    book_retained_text(
      back.draft_recovery.technical,
      book_technical_context(back),
    ),
    Some(partial),
  )
  let restored = snapshot_test_step(back, DraftRecovery(RestoreTechnical))
  assert_eq(restored.bookkeeper_draft, partial)
  let failed = snapshot_test_step(restored, SubmitBookkeeperMutation)
  assert_false(failed.bookkeeper_busy)
  assert_true(failed.bookkeeper_notice.unwrap().contains("not valid JSON"))
}

///|
test "new evidence invalidates executable draft and cannot restore an old technical context" {
  let edited = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary("Retain my reasoning")),
  )
  let edited = snapshot_test_step(
    edited,
    SetBookkeeperDraft(edited.bookkeeper_draft + "\n "),
  )
  let changed = draft_test_record("first", digest="new-digest")
  let next = {
    ..edited,
    bookkeeper_store: Some({ ..live_test_store(2), records: [changed], }),
  }
  assert_true(book_draft_is_stale(next))
  let blocked = snapshot_test_step(next, SubmitBookkeeperMutation)
  assert_false(blocked.bookkeeper_busy)
  assert_true(blocked.bookkeeper_notice.unwrap().contains("evidence changed"))
  assert_eq(blocked.draft_recovery.summary, "Retain my reasoning")
  let selected = snapshot_test_step(
    blocked,
    SelectBookkeeperItem(draft_test_item("first")),
  )
  assert_true(
    selected.draft_recovery.note_key != edited.draft_recovery.note_key,
  )
  assert_eq(
    book_retained_text(
      selected.draft_recovery.technical,
      book_technical_context(selected),
    ),
    None,
  )
  assert_true(draft_test_editor(selected).contains("Retain my reasoning"))
  assert_true(
    @json.parse(selected.bookkeeper_draft)
    is { "subject": { "record_digest": "new-digest", .. }, .. },
  )
}

///|
test "storage callbacks are bound to exact review generation and cannot replace later text" {
  let ready = draft_test_prepared()
  let saving = snapshot_test_step(
    snapshot_test_step(ready, DraftRecovery(EditSummary("Earlier text"))),
    DraftRecovery(SaveSummary),
  )
  let request = saving.draft_recovery.storage_request
  let key = saving.draft_recovery.note_key.unwrap()
  let newer = snapshot_test_step(
    saving,
    DraftRecovery(EditSummary("Newer text")),
  )
  let finished = snapshot_test_step(
    newer,
    DraftRecovery(
      StorageFinished(request, key, "save", Ok(Some("Earlier text"))),
    ),
  )
  assert_eq(finished.draft_recovery.summary, "Newer text")
  assert_eq(finished.draft_recovery.saved, Some("Earlier text"))
  assert_true(
    finished.draft_recovery.storage_notice.unwrap().contains("newer text"),
  )
  let switched = snapshot_test_step(
    finished,
    SelectBookkeeperItem(draft_test_item("second")),
  )
  let stale = snapshot_test_step(
    switched,
    DraftRecovery(
      StorageFinished(request, key, "save", Ok(Some("Earlier text"))),
    ),
  )
  assert_eq(stale.draft_recovery.summary, switched.draft_recovery.summary)
  assert_eq(stale.draft_recovery.saved, None)
}

///|
test "failed local storage remains visible and preserves long text and prior saved copy" {
  let note = "Unsaved <&>\n中文"
  let edited = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary(note)),
  )
  let saving = snapshot_test_step(edited, DraftRecovery(SaveSummary))
  let failed = snapshot_test_step(
    saving,
    DraftRecovery(
      StorageFinished(
        saving.draft_recovery.storage_request,
        saving.draft_recovery.note_key.unwrap(),
        "save",
        Err("quota"),
      ),
    ),
  )
  assert_eq(failed.draft_recovery.summary, note)
  assert_false(failed.draft_recovery.storage_pending)
  assert_eq(failed.draft_recovery.saved, None)
  let html = draft_test_editor(failed)
  assert_true(html.contains("Copy it before leaving"))
  assert_true(html.contains("quota"))
}

///|
test "mutation completion preserves newer summary and its local saved state" {
  let earlier = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary("Submitted")),
  )
  let saving = snapshot_test_step(earlier, SubmitBookkeeperMutation)
  assert_true(saving.bookkeeper_busy)
  let newer = snapshot_test_step(
    saving,
    DraftRecovery(EditSummary("Newer reasoning")),
  )
  let finished = snapshot_test_step(
    newer,
    BookkeeperMutationFinished(
      Ok({
        accepted: true,
        idempotent: false,
        event: None,
        review: None,
        issues: [],
        ui_state_path: "fixture",
      }),
    ),
  )
  assert_eq(finished.draft_recovery.summary, "Newer reasoning")
  assert_eq(
    book_json_summary(finished.bookkeeper_draft),
    Some("Newer reasoning"),
  )
  assert_false(finished.bookkeeper_busy)
}

///|
test "system language selection no longer discards in-memory review text" {
  let earlier = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary("Keep through language change")),
  )
  let changed = snapshot_test_step(earlier, UseSystemInterfaceLocale)
  assert_eq(changed.draft_recovery.summary, earlier.draft_recovery.summary)
  assert_eq(changed.bookkeeper_draft, earlier.bookkeeper_draft)
  assert_eq(
    changed.selected_bookkeeper_record,
    earlier.selected_bookkeeper_record,
  )
}

///|
test "fresh reads and active grant remain required before restored review text can submit" {
  let original = snapshot_test_step(
    draft_test_prepared(),
    DraftRecovery(EditSummary("Keep independent of permission")),
  )
  let loading = {
    ..original,
    bookkeeper_reads: { ..original.bookkeeper_reads, store_loading: true, },
  }
  let blocked = snapshot_test_step(loading, SubmitBookkeeperMutation)
  assert_false(blocked.bookkeeper_busy)
  assert_eq(blocked.draft_recovery.summary, original.draft_recovery.summary)
  let failed = {
    ..original,
    bookkeeper_reads: {
      ..original.bookkeeper_reads,
      authorities_error: Some("offline"),
    },
  }
  assert_false(
    snapshot_test_step(failed, SubmitBookkeeperMutation).bookkeeper_busy,
  )
  let revoked = {
    ..original,
    bookkeeper_authorities: Some({ contract_version: "v1", grants: [], }),
  }
  assert_true(book_draft_is_stale(revoked))
  assert_false(
    snapshot_test_step(revoked, SubmitBookkeeperMutation).bookkeeper_busy,
  )
  let refreshed = {
    ..original,
    bookkeeper_store: Some({
      ..live_test_store(2),
      records: [draft_test_record("first", digest="updated")],
    }),
  }
  let prepared = snapshot_test_step(
    refreshed,
    PrepareBookkeeperReview("Accept"),
  )
  assert_eq(
    prepared.selected_bookkeeper_record.unwrap().record_digest,
    "updated",
  )
  assert_true(prepared.draft_recovery.note_key is Some(_))
  assert_false(book_draft_is_stale(prepared))
  assert_true(
    draft_test_editor(prepared).contains("Keep independent of permission"),
  )
}

///|
test "saved-summary lookup separates workspace record digest and decision without storing grants" {
  let ready = draft_test_prepared()
  let key = book_note_key(ready).unwrap()
  let workspace = {
    ..ready,
    state: {
      ..ready.state,
      bookkeeper: {
        ..ready.state.bookkeeper,
        source_path: "/different/book/.moonbook/bookkeeper/ui-state.json",
      },
    },
  }
  assert_true(book_note_key(workspace) != Some(key))
  let rejected = snapshot_test_step(ready, PrepareBookkeeperReview("Reject"))
  assert_true(book_note_key(rejected) != Some(key))
  assert_false(key.contains("reviewer"))
  assert_false(key.contains("server-evidence"))
  assert_false(key.contains("secret_fixture"))
}

///|
test "advanced ingress and unavailable reviewer changes retain copies without rebinding an old payload" {
  let model = snapshot_test_step(
    draft_test_model(),
    SetBookkeeperDraft("{\"important\":\"manual payload\"}"),
  )
  let key = book_technical_context(model)
  let changed = snapshot_test_step(
    model,
    SelectBookkeeperItem(draft_test_item("second")),
  )
  assert_eq(changed.bookkeeper_draft, bookkeeper_mode_template("ingress"))
  assert_eq(
    book_retained_text(changed.draft_recovery.technical, key),
    Some(model.bookkeeper_draft),
  )
  let review = snapshot_test_step(
    draft_test_prepared(),
    SetBookkeeperDraft("{\"important\":\"old exact review\"}"),
  )
  let unavailable = snapshot_test_step(
    review,
    SelectBookkeeperAuthority("missing-authority"),
  )
  assert_eq(unavailable.bookkeeper_draft, bookkeeper_mode_template("review"))
  assert_eq(
    book_retained_text(
      unavailable.draft_recovery.technical,
      book_technical_context(review),
    ),
    Some(review.bookkeeper_draft),
  )
  assert_false(
    snapshot_test_step(unavailable, SubmitBookkeeperMutation).bookkeeper_busy,
  )
}
