///|
suberror SnapshotTestError {
  SnapshotTestError(String)
}

///|
impl Show for SnapshotTestError with fn output(self, logger) {
  match self {
    SnapshotTestError(message) => logger.write_string(message)
  }
}

///|
extern "js" fn snapshot_test_button_tag(html : String) -> String =
  #| html => (html.match(/<button\b[^>]*>/g) || []).find(tag => /id="snapshot-retry"/.test(tag)) || ''

///|
fn snapshot_test_initial() -> Model {
  {
    ..guided_book_model(wiki_review_initial_state()),
    loading: true,
    state: empty_snapshot_state(),
    refresh_count: 0,
  }
}

///|
fn snapshot_test_step(model : Model, message : Msg) -> Model {
  let (emit, _) = @rabbita.cell_with_emit(model~, update~, view=render_page)
  let (_, next) = update(emit, message, model)
  next
}

///|
fn snapshot_test_html(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=render_page,
    ),
  )
}

///|
fn snapshot_test_failure(model : Model) -> Model {
  snapshot_test_step(
    model,
    Loaded(
      model.snapshot_request,
      Err(SnapshotTestError("Snapshot read offline <unsafe>")),
    ),
  )
}

///|
test "snapshot initial failure stays unavailable without illustrative data" {
  let initial = snapshot_test_initial()
  assert_true(snapshot_status(initial) is Loading)
  assert_true(initial.state.metrics.is_empty())
  assert_true(initial.state.status_chips.is_empty())
  assert_true(initial.state.chapters.is_empty())
  let failed = snapshot_test_failure(initial)
  assert_true(snapshot_status(failed) is Unavailable)
  assert_eq(failed.refresh_count, 0)
  let html = snapshot_test_html(failed)
  assert_true(html.contains("Workspace snapshot unavailable."))
  assert_true(html.contains("Workspace data has not loaded."))
  assert_true(html.contains("Retry snapshot"))
  assert_false(snapshot_test_button_tag(html).contains("disabled"))
  assert_true(html.contains("Snapshot read offline &lt;unsafe&gt;"))
  assert_true(html.contains("role=\"alert\""))
  assert_false(html.contains("Live workspace snapshot loaded"))
  assert_false(html.contains("Latest snapshot loaded"))
  assert_false(html.contains("Snapshot Ready"))
  assert_false(html.contains("Planning Pressure"))
}

///|
test "snapshot retry retains data and error until a successful current read" {
  let initial = snapshot_test_initial()
  let state = { ..demo_state(), title: "Previously read Book", }
  let ready = snapshot_test_step(initial, Loaded(1, Ok(state)))
  assert_true(snapshot_status(ready) is Current)
  let refreshing = snapshot_test_step(ready, RetrySnapshot)
  let failed = snapshot_test_failure(refreshing)
  assert_true(snapshot_status(failed) is Stale)
  assert_eq(failed.state.title, "Previously read Book")
  assert_eq(failed.state.metrics.length(), state.metrics.length())
  assert_eq(failed.refresh_count, 1)
  let failed_html = snapshot_test_html(failed)
  assert_true(failed_html.contains("Workspace snapshot may be out of date."))
  assert_false(failed_html.contains("Workspace snapshot loaded."))
  let retrying = snapshot_test_step(failed, RetrySnapshot)
  assert_true(snapshot_status(retrying) is Loading)
  assert_eq(retrying.state.title, "Previously read Book")
  assert_eq(retrying.error, failed.error)
  let pending_html = snapshot_test_html(retrying)
  assert_true(pending_html.contains("Showing the last successful read"))
  assert_true(pending_html.contains("Snapshot read offline &lt;unsafe&gt;"))
  let current = snapshot_test_step(
    retrying,
    Loaded(
      retrying.snapshot_request,
      Ok({ ..state, title: "Newly read Book", }),
    ),
  )
  assert_true(snapshot_status(current) is Current)
  assert_eq(current.error, None)
  assert_eq(current.state.title, "Newly read Book")
  assert_eq(current.refresh_count, 2)
  let html = snapshot_test_html(current)
  assert_true(html.contains("Workspace snapshot loaded."))
  assert_true(html.contains("Refresh snapshot"))
  assert_false(html.contains("Snapshot read offline"))
}

///|
test "snapshot first-load retry succeeds and duplicate clicks stay pending once" {
  let failed = snapshot_test_failure(snapshot_test_initial())
  let retrying = snapshot_test_step(failed, RetrySnapshot)
  assert_eq(retrying.snapshot_request, failed.snapshot_request + 1)
  let duplicate = snapshot_test_step(retrying, RetrySnapshot)
  assert_eq(duplicate.snapshot_request, retrying.snapshot_request)
  assert_eq(duplicate.refresh_count, 0)
  assert_true(duplicate.loading)
  let html = snapshot_test_html(duplicate)
  assert_true(snapshot_test_button_tag(html).contains("disabled"))
  assert_true(html.contains("Refreshing workspace snapshot."))
  assert_false(html.contains("Workspace snapshot loaded."))
  let current = snapshot_test_step(
    duplicate,
    Loaded(duplicate.snapshot_request, Ok(demo_state())),
  )
  assert_true(snapshot_status(current) is Current)
  assert_eq(current.refresh_count, 1)
  assert_eq(current.error, None)
}

///|
test "snapshot newer read ignores late success and error callbacks" {
  let first = snapshot_test_initial()
  let newer = snapshot_test_step(first, RefreshSnapshot)
  assert_eq(newer.snapshot_request, first.snapshot_request + 1)
  let old_success = snapshot_test_step(
    newer,
    Loaded(first.snapshot_request, Ok(demo_state())),
  )
  assert_true(old_success.loading)
  assert_eq(old_success.refresh_count, 0)
  assert_true(old_success.state.metrics.is_empty())
  let old_failure = snapshot_test_step(
    old_success,
    Loaded(first.snapshot_request, Err(SnapshotTestError("late failure"))),
  )
  assert_true(old_failure.loading)
  assert_eq(old_failure.error, None)
  let current = snapshot_test_step(
    old_failure,
    Loaded(newer.snapshot_request, Ok(demo_state())),
  )
  let duplicate = snapshot_test_step(
    current,
    Loaded(newer.snapshot_request, Err(SnapshotTestError("duplicate failure"))),
  )
  assert_true(snapshot_status(duplicate) is Current)
  assert_eq(duplicate.refresh_count, 1)
  assert_eq(duplicate.error, None)
}

///|
test "snapshot locale switch preserves the retained data while retry is pending" {
  let ready = snapshot_test_step(
    snapshot_test_initial(),
    Loaded(1, Ok({ ..demo_state(), title: "Exact previous data", })),
  )
  let pending = snapshot_test_step(ready, RetrySnapshot)
  let switched = snapshot_test_step(
    pending,
    SetInterfaceLocale(SimplifiedChinese),
  )
  assert_eq(switched.state.title, "Exact previous data")
  assert_eq(switched.snapshot_request, pending.snapshot_request)
  assert_true(snapshot_status(switched) is Loading)
  assert_true(
    snapshot_test_html(switched).contains("正在刷新工作区快照"),
  )
}

///|
test "snapshot static mode allows manual reread and keeps diagnostics collapsed" {
  let ready = snapshot_test_step(
    snapshot_test_initial(),
    Loaded(1, Ok(demo_state())),
  )
  let static_mode = snapshot_test_step(
    ready,
    LoadedConfig(Ok({ live_reload_endpoint: None, })),
  )
  let html = snapshot_test_html(static_mode)
  assert_true(html.contains("Static snapshot mode: automatic updates are off."))
  assert_false(snapshot_test_button_tag(html).contains("disabled"))
  assert_false(html.contains("Live workspace snapshot loaded"))
  assert_true(html.contains("<details><summary>Snapshot diagnostics</summary>"))
  assert_true(html.contains("Successful snapshot reads: 1"))
  let refreshed = snapshot_test_step(static_mode, RetrySnapshot)
  assert_true(refreshed.loading)
  assert_eq(refreshed.snapshot_request, static_mode.snapshot_request + 1)
  let live = snapshot_test_step(
    ready,
    LoadedConfig(Ok({ live_reload_endpoint: Some("/events"), })),
  )
  let live_html = snapshot_test_html(live)
  assert_true(live_html.contains("Automatic updates are configured."))
  assert_true(live_html.contains("SSE via /events"))
  assert_false(live_html.contains("subscribed"))
}
