///|
fn live_test_store(sequence : Int) -> BookkeeperStoreSnapshot {
  {
    contract_version: "moonbook.bookkeeper.store.v1",
    last_sequence: sequence,
    records: [],
    reviews: [],
    envelopes: [],
    replay_issues: [],
  }
}

///|
fn live_test_registry(authority_ref : String) -> BookkeeperAuthorityRegistry {
  {
    contract_version: "moonbook.bookkeeper.store.v1",
    grants: [
      {
        contract_version: "moonbook.bookkeeper.store.v1",
        grant: {
          record_id: "grant",
          record_version: "v1",
          record_digest: "digest",
        },
        reviewer_id: "reviewer",
        reviewer_kind: "NamedHuman",
        authority_ref,
        evidence_refs: [],
        active: true,
        granted_at: 1,
      },
    ],
  }
}

///|
fn live_test_model() -> Model {
  {
    ..guided_book_model(wiki_review_test_ready()),
    live_reload_endpoint: Some("/events"),
    selected_bookkeeper_record: Some({
      record_id: "exact-record",
      record_version: "v7",
      record_digest: "exact-digest",
    }),
    selected_bookkeeper_authority: Some("chosen-authority"),
    bookkeeper_mode: "review",
    bookkeeper_draft: "{\n  \"unsent\": \"keep exact text <&> 中文\"\n}",
    bookkeeper_store: Some(live_test_store(7)),
    bookkeeper_authorities: Some(live_test_registry("chosen-authority")),
    bookkeeper_notice: Some(
      "Prepared exact named-human review; verify before saving.",
    ),
  }
}

///|
fn live_test_preserved(before : Model, after : Model) -> Unit raise {
  assert_eq(after.bookkeeper_draft, before.bookkeeper_draft)
  assert_eq(after.bookkeeper_mode, before.bookkeeper_mode)
  assert_eq(after.selected_bookkeeper_record, before.selected_bookkeeper_record)
  assert_eq(
    after.selected_bookkeeper_authority,
    before.selected_bookkeeper_authority,
  )
  assert_eq(after.bookkeeper_notice, before.bookkeeper_notice)
  assert_eq(after.bookkeeper_busy, before.bookkeeper_busy)
  assert_eq(after.wiki_review.selected_id, before.wiki_review.selected_id)
}

///|
test "live refresh preserves exact draft bindings mode and previous useful data" {
  let original = live_test_model()
  let refreshing = snapshot_test_step(original, LiveDataChanged("/events"))
  live_test_preserved(original, refreshing)
  assert_true(refreshing.loading)
  assert_eq(refreshing.bookkeeper_store.unwrap().last_sequence, 7)
  assert_eq(
    refreshing.wiki_review.detail.unwrap().review_digest,
    "digest-review-0",
  )
  assert_true(refreshing.wiki_review.detail_loading)
  let current = snapshot_test_step(
    refreshing,
    Loaded(
      refreshing.snapshot_request,
      Ok({ ..demo_state(), title: "Updated workspace", }),
    ),
  )
  let current = snapshot_test_step(
    current,
    LoadedBookkeeperStore(
      current.bookkeeper_reads.request,
      Ok(live_test_store(8)),
    ),
  )
  let current = snapshot_test_step(
    current,
    LoadedBookkeeperAuthorities(
      current.bookkeeper_reads.request,
      Ok(live_test_registry("different-authority")),
    ),
  )
  live_test_preserved(original, current)
  assert_eq(current.state.title, "Updated workspace")
  assert_eq(current.bookkeeper_store.unwrap().last_sequence, 8)
  assert_eq(
    current.bookkeeper_authorities.unwrap().grants[0].authority_ref,
    "different-authority",
  )
  assert_true(
    snapshot_test_html(current).contains("keep exact text &lt;&amp;&gt; 中文"),
  )
}

///|
test "repeated live refresh accepts newest data and ignores late duplicate reads" {
  let original = live_test_model()
  let first = snapshot_test_step(original, LiveDataChanged("/events"))
  let second = snapshot_test_step(first, LiveDataChanged("/events"))
  assert_eq(second.snapshot_request, first.snapshot_request + 1)
  assert_eq(second.bookkeeper_reads.request, first.bookkeeper_reads.request + 1)
  let old = snapshot_test_step(
    second,
    Loaded(first.snapshot_request, Ok({ ..demo_state(), title: "Obsolete", })),
  )
  let old = snapshot_test_step(
    old,
    LoadedBookkeeperStore(
      first.bookkeeper_reads.request,
      Ok(live_test_store(99)),
    ),
  )
  let old = snapshot_test_step(
    old,
    LoadedBookkeeperAuthorities(
      first.bookkeeper_reads.request,
      Err(SnapshotTestError("old failure")),
    ),
  )
  assert_true(old.loading)
  assert_eq(old.state.title, original.state.title)
  assert_eq(old.bookkeeper_store.unwrap().last_sequence, 7)
  assert_eq(old.bookkeeper_reads.authorities_error, None)
  let current = snapshot_test_step(
    old,
    LoadedBookkeeperStore(
      second.bookkeeper_reads.request,
      Ok(live_test_store(8)),
    ),
  )
  let duplicate = snapshot_test_step(
    current,
    LoadedBookkeeperStore(
      second.bookkeeper_reads.request,
      Ok(live_test_store(2)),
    ),
  )
  assert_eq(duplicate.bookkeeper_store.unwrap().last_sequence, 8)
  let latest = snapshot_test_step(
    duplicate,
    LoadedBookkeeperAuthorities(
      second.bookkeeper_reads.request,
      Ok(live_test_registry("fresh")),
    ),
  )
  let duplicate = snapshot_test_step(
    latest,
    LoadedBookkeeperAuthorities(
      second.bookkeeper_reads.request,
      Err(SnapshotTestError("duplicate")),
    ),
  )
  assert_eq(duplicate.bookkeeper_reads.authorities_error, None)
  assert_eq(
    duplicate.bookkeeper_authorities.unwrap().grants[0].authority_ref,
    "fresh",
  )
  live_test_preserved(original, duplicate)
}

///|
test "failed live read retains draft data and action notice with safe manual retry" {
  let original = live_test_model()
  let refreshing = snapshot_test_step(original, LiveDataChanged("/events"))
  let failed = snapshot_test_failure(refreshing)
  let failed = snapshot_test_step(
    failed,
    LoadedBookkeeperStore(
      refreshing.bookkeeper_reads.request,
      Err(SnapshotTestError("store <offline>")),
    ),
  )
  let failed = snapshot_test_step(
    failed,
    LoadedBookkeeperAuthorities(
      refreshing.bookkeeper_reads.request,
      Err(SnapshotTestError("authorities offline")),
    ),
  )
  live_test_preserved(original, failed)
  assert_eq(failed.bookkeeper_store.unwrap().last_sequence, 7)
  assert_true(snapshot_status(failed) is Stale)
  let html = snapshot_test_html(failed)
  assert_true(html.contains("store &lt;offline&gt;"))
  assert_true(html.contains("Your draft is retained."))
  let retry = snapshot_test_step(failed, RetrySnapshot)
  let duplicate = snapshot_test_step(retry, RetrySnapshot)
  assert_eq(duplicate.bookkeeper_reads.request, retry.bookkeeper_reads.request)
  let ready = snapshot_test_step(
    duplicate,
    Loaded(retry.snapshot_request, Ok(demo_state())),
  )
  let ready = snapshot_test_step(
    ready,
    LoadedBookkeeperStore(
      retry.bookkeeper_reads.request,
      Ok(live_test_store(9)),
    ),
  )
  let ready = snapshot_test_step(
    ready,
    LoadedBookkeeperAuthorities(
      retry.bookkeeper_reads.request,
      Ok(live_test_registry("fresh")),
    ),
  )
  assert_eq(ready.bookkeeper_reads.store_error, None)
  assert_eq(ready.bookkeeper_reads.authorities_error, None)
  assert_true(snapshot_status(ready) is Current)
  live_test_preserved(original, ready)
}

///|
test "live refresh does not resubmit pending mutation or lose its delayed completion" {
  let original = live_test_model()
  let saving = snapshot_test_step(original, SubmitBookkeeperMutation)
  let refreshed = snapshot_test_step(saving, LiveDataChanged("/events"))
  live_test_preserved(saving, refreshed)
  let duplicate = snapshot_test_step(refreshed, SubmitBookkeeperMutation)
  live_test_preserved(refreshed, duplicate)
  let replay = snapshot_test_step(duplicate, ReplayBookkeeper)
  live_test_preserved(duplicate, replay)
  let edited = snapshot_test_step(
    replay,
    SetBookkeeperDraft("{\"newer\": true}"),
  )
  let finished = snapshot_test_step(
    edited,
    BookkeeperMutationFinished(
      Ok({
        accepted: true,
        idempotent: false,
        event: None,
        review: None,
        issues: [],
        ui_state_path: "moonbook-ui-state.json",
      }),
    ),
  )
  assert_false(finished.bookkeeper_busy)
  assert_eq(finished.bookkeeper_draft, "{\"newer\": true}")
  assert_true(finished.bookkeeper_notice.unwrap().contains("Mutation accepted"))
  let old = snapshot_test_step(
    finished,
    LoadedBookkeeperStore(
      refreshed.bookkeeper_reads.request,
      Ok(live_test_store(1)),
    ),
  )
  assert_eq(old.bookkeeper_store.unwrap().last_sequence, 7)
  assert_true(old.bookkeeper_reads.store_loading)
}

///|
test "live read keeps prepared review only for exact unchanged content" {
  let choice = wiki_review_test_choice()
  let (prepared, _) = wiki_review_reduce(
    wiki_review_test_ready(),
    Prepare(choice),
  )
  let (refreshing, effects) = wiki_review_reduce(prepared, LiveRefresh)
  assert_true(effects is [LoadQueue(_), LoadDetail(_, "review-0")])
  assert_eq(refreshing.confirmation, Some(choice))
  assert_true(refreshing.detail is Some(_))
  assert_false(wiki_review_choice_is_current(refreshing, choice))
  let (_, blocked) = wiki_review_reduce(refreshing, Confirm(choice))
  assert_true(blocked.is_empty())
  // Deliberately complete detail first: confirmation survives response ordering.
  let (detailed, _) = wiki_review_reduce(
    refreshing,
    DetailLoaded(
      refreshing.detail_request,
      "review-0",
      Ok(wiki_review_test_detail("review-0")),
    ),
  )
  assert_eq(detailed.confirmation, Some(choice))
  let (ready, _) = wiki_review_reduce(
    detailed,
    QueueLoaded(refreshing.queue_request, Ok(wiki_review_test_items(7))),
  )
  assert_true(wiki_review_choice_is_current(ready, choice))
  assert_eq(ready.confirmation, Some(choice))
  let (changed, _) = wiki_review_reduce(ready, LiveRefresh)
  let (changed, _) = wiki_review_reduce(
    changed,
    DetailLoaded(
      changed.detail_request,
      "review-0",
      Ok({ ..wiki_review_test_detail("review-0"), review_digest: "new-digest", }),
    ),
  )
  assert_eq(changed.confirmation, None)
  assert_false(wiki_review_choice_is_current(changed, choice))
}

///|
test "pending wiki decision owns completion while live reads preserve readback context" {
  let choice = wiki_review_test_choice()
  let (prepared, _) = wiki_review_reduce(
    wiki_review_test_ready(),
    Prepare(choice),
  )
  let (saving, _) = wiki_review_reduce(prepared, Confirm(choice))
  let request = saving.pending.unwrap().request
  let (untouched, effects) = wiki_review_reduce(saving, LiveRefresh)
  assert_true(effects.is_empty())
  assert_eq(untouched.pending.unwrap().request, request)
  assert_eq(untouched.pending.unwrap().choice, choice)
  let (readback, effects) = wiki_review_reduce(
    untouched,
    Resolved(request, Err("uncertain response")),
  )
  assert_true(
    effects is [LoadQueue(_), LoadDetail(_, "review-0"), RefreshSnapshot],
  )
  let (refreshed, effects) = wiki_review_reduce(readback, LiveRefresh)
  assert_true(effects is [LoadQueue(_), LoadDetail(_, "review-0")])
  assert_eq(refreshed.readback, Some(choice))
  assert_eq(refreshed.notice, readback.notice)
  let (obsolete, _) = wiki_review_reduce(
    refreshed,
    DetailLoaded(
      readback.detail_request,
      "review-0",
      Ok(wiki_review_test_detail("review-0", status="rejected")),
    ),
  )
  assert_eq(obsolete.readback, Some(choice))
  let (verified, _) = wiki_review_reduce(
    obsolete,
    DetailLoaded(
      refreshed.detail_request,
      "review-0",
      Ok(wiki_review_test_detail("review-0", status="approved")),
    ),
  )
  assert_eq(verified.readback, None)
  assert_true(verified.readback_notice.unwrap().contains("Readback verified"))
}

///|
test "static config and old endpoint events cannot disturb draft or start reads" {
  let original = live_test_model()
  let static_mode = snapshot_test_step(
    original,
    LoadedConfig(Ok({ live_reload_endpoint: None, })),
  )
  let ignored = snapshot_test_step(static_mode, LiveDataChanged("/events"))
  assert_eq(ignored.snapshot_request, original.snapshot_request)
  assert_eq(ignored.bookkeeper_reads.request, original.bookkeeper_reads.request)
  live_test_preserved(original, ignored)
  let manual = snapshot_test_step(ignored, RetrySnapshot)
  assert_eq(manual.snapshot_request, original.snapshot_request + 1)
  live_test_preserved(original, manual)
  let replaced = snapshot_test_step(
    original,
    LoadedConfig(Ok({ live_reload_endpoint: Some("/replacement"), })),
  )
  let ignored = snapshot_test_step(replaced, LiveDataChanged("/events"))
  assert_eq(ignored.snapshot_request, original.snapshot_request)
}

///|
test "live review errors retain inspected evidence without enabling a stale decision" {
  let ready = wiki_review_test_ready()
  let (refreshing, _) = wiki_review_reduce(ready, LiveRefresh)
  let (failed, _) = wiki_review_reduce(
    refreshing,
    DetailLoaded(refreshing.detail_request, "review-0", Err("detail offline")),
  )
  assert_eq(
    failed.detail.unwrap().review_text,
    ready.detail.unwrap().review_text,
  )
  assert_false(wiki_review_choice_is_current(failed, wiki_review_test_choice()))
  let (failed, _) = wiki_review_reduce(
    failed,
    QueueLoaded(refreshing.queue_request, Err("queue offline")),
  )
  assert_eq(failed.items.length(), ready.items.length())
  assert_eq(failed.selected_id, ready.selected_id)
  assert_false(wiki_review_choice_is_current(failed, wiki_review_test_choice()))
  assert_true(
    guided_book_panel(failed).contains("Queue unavailable: queue offline"),
  )
  let (retry, _) = wiki_review_reduce(failed, LiveRefresh)
  let (old, effects) = wiki_review_reduce(
    retry,
    QueueLoaded(refreshing.queue_request, Ok([])),
  )
  assert_true(effects.is_empty())
  assert_eq(old.items.length(), ready.items.length())
  assert_true(old.queue_loading)
}

///|
extern "js" fn live_test_event_source(
  install : (String, () -> Unit) -> Unit,
  notify : () -> Unit,
) -> String =
  #| (install, notify) => {
  #|   const hadWindow = Object.prototype.hasOwnProperty.call(globalThis, "window");
  #|   const previous = globalThis.window;
  #|   const sources = [];
  #|   let reloads = 0, oldCallback = 0, currentCallback = 0;
  #|   class FakeEventSource {
  #|     constructor(endpoint) { this.endpoint = endpoint; this.listeners = {}; this.closed = 0; sources.push(this); }
  #|     addEventListener(name, fn) { (this.listeners[name] ||= []).push(fn); }
  #|     close() { this.closed++; }
  #|     emit(name, data) { for (const fn of this.listeners[name] || []) fn({ data }); }
  #|   }
  #|   globalThis.window = { EventSource: FakeEventSource, location: { reload() { reloads++; } } };
  #|   try {
  #|     install("/events", () => { oldCallback++; });
  #|     install("/events", () => { currentCallback++; notify(); });
  #|     const source = sources[0];
  #|     source.emit("ready", "a");
  #|     source.emit("reload", "a");
  #|     source.emit("reload", "b");
  #|     source.onerror();
  #|     source.emit("ready", "c");
  #|     source.emit("ready", "c");
  #|     install("/replacement", () => { currentCallback++; notify(); });
  #|     source.emit("reload", "late-from-closed");
  #|     sources[1].emit("reload", "d");
  #|     install("", () => { oldCallback++; });
  #|     sources[1].emit("reload", "late-after-static");
  #|     return [sources.length, source.listeners.reload.length, source.listeners.ready.length, source.closed, sources[1].closed, oldCallback, currentCallback, reloads, window.__moonbookLiveReload === null].join(",");
  #|   } finally {
  #|     if (hadWindow) globalThis.window = previous; else delete globalThis.window;
  #|   }
  #| }

///|
test "controlled EventSource reuses replaces reconnects and never reloads page" {
  let original = live_test_model()
  let state = Ref(original)
  let result = live_test_event_source(install_live_reload, () => {
    state.val = snapshot_test_step(state.val, LiveDataChanged("/events"))
  })
  assert_eq(result, "2,1,1,1,1,0,4,0,true")
  assert_eq(state.val.snapshot_request, original.snapshot_request + 4)
  live_test_preserved(original, state.val)
}
