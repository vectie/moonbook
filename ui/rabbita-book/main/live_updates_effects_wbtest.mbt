///|
struct LiveTestScheduler {
  hooks : @cmd.Hooks
}

///|
impl @cmd.Scheduler for LiveTestScheduler with fn run_effect(
  self,
  _kind,
  effect,
) {
  effect(self)
}

///|
impl @cmd.Scheduler for LiveTestScheduler with fn queue_message(
  _self,
  _id,
  send,
) {
  send()
}

///|
impl @cmd.Scheduler for LiveTestScheduler with fn drain_message(_self) {
  ()
}

///|
impl @cmd.Scheduler for LiveTestScheduler with fn hooks(self) {
  self.hooks
}

///|
extern "js" fn live_effect_fixture_install() -> Unit =
  #| () => {
  #|   const state = { oldFetch: globalThis.fetch, oldWindow: globalThis.window, hadWindow: Object.prototype.hasOwnProperty.call(globalThis, "window"), requests: [], sources: [], reloads: 0 };
  #|   globalThis.__bookLiveEffects = state;
  #|   globalThis.fetch = (url, options = {}) => new Promise((resolve, reject) => state.requests.push({ url, method: options.method || "GET", body: options.body, resolve, reject }));
  #|   class FakeEventSource {
  #|     constructor(endpoint) { this.endpoint = endpoint; this.listeners = {}; state.sources.push(this); }
  #|     addEventListener(name, fn) { this.listeners[name] = fn; }
  #|     close() {}
  #|   }
  #|   globalThis.window = { EventSource: FakeEventSource, location: { reload() { state.reloads++; } } };
  #| }

///|
extern "js" fn live_effect_fixture_restore() -> Unit =
  #| () => {
  #|   const state = globalThis.__bookLiveEffects;
  #|   globalThis.fetch = state.oldFetch;
  #|   if (state.hadWindow) globalThis.window = state.oldWindow; else delete globalThis.window;
  #|   delete globalThis.__bookLiveEffects;
  #| }

///|
extern "js" fn live_effect_fixture_event(token : String) -> Unit =
  #| token => globalThis.__bookLiveEffects.sources[0].listeners.reload({ data: token })

///|
extern "js" fn live_effect_fixture_requests() -> String =
  #| () => JSON.stringify({ reloads: globalThis.__bookLiveEffects.reloads, requests: globalThis.__bookLiveEffects.requests.map(({url, method, body}) => ({url, method, body: body || ""})) })

///|
extern "js" fn live_effect_fixture_settle(
  start : Int,
  end : Int,
  version : Int,
  failed : Bool,
) -> @js.Promise =
  #| (start, end, version, failed) => {
  #|   const state = globalThis.__bookLiveEffects;
  #|   for (const request of state.requests.slice(start, end)) {
  #|     if (failed) { request.reject(new Error("controlled offline")); continue; }
  #|     let body;
  #|     if (request.url === "./moonbook-ui-state.json") {
  #|       body = { title: "Snapshot " + version, summary: "Current snapshot", status_chips: [], metrics: [], workflow: [], review_queue: [], keeper_items: [], page_families: [], chapters: [], synthesis_preview: "Current synthesis", bookkeeper: { contract_version: "v1", projection_version: "v1", source_path: "fixture", loaded: true, deliverable_acceptance: [], outcome_binding: [], three_gap_findings: [], three_gap_review: [], capability_proposal: [], capability_review: [], mooncode_work_order: [], evaluation: [], adoption: [] } };
  #|     } else if (request.url === "/api/bookkeeper/state") {
  #|       body = { contract_version: "v1", last_sequence: version, records: [], reviews: [], envelopes: [], replay_issues: [] };
  #|     } else if (request.url === "/api/bookkeeper/authorities") {
  #|       body = { contract_version: "registry-" + version, grants: [] };
  #|     } else if (request.url === "/api/wiki/reviews") {
  #|       body = { schema: "moonbook.wiki-review-operator.v1", ok: true, original_task_acceptance: "unevaluated", items: [{ review_id: "review-0", kind: "result-review", title: "Queue " + version, status: "pending" }] };
  #|     } else if (request.url === "/api/wiki/reviews/inspect") {
  #|       body = { schema: "moonbook.wiki-review-operator.v1", ok: true, detail: { review_id: "review-0", kind: "result-review", title: "Detail " + version, status: "pending", review_digest: "digest-review-0", review_text: "Evidence " + version, result_text: "Source", evidence_text: "Evidence", review_scope: "local-book-review", original_task_acceptance: "unevaluated", can_resolve: true, native_binding: null } };
  #|     } else {
  #|       request.reject(new Error("Forbidden route in controlled fixture: " + request.url)); continue;
  #|     }
  #|     request.resolve({ ok: true, status: 200, text: () => Promise.resolve(JSON.stringify(body)) });
  #|   }
  #|   return new Promise(resolve => setTimeout(resolve, 0));
  #| }

///|
test "actual SSE commands refresh only read endpoints and preserve pending work through late callbacks" {
  @js.async_test(async fn() {
    live_effect_fixture_install()
    defer live_effect_fixture_restore()
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    let original = live_test_model()
    let cell = Ref(original)
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      let (command, next) = update(dispatch, message, cell.val)
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      @rabbita.none
    }
    ignore(
      dispatch(LoadedConfig(Ok({ live_reload_endpoint: Some("/events"), }))),
    )
    live_effect_fixture_event("first")
    live_effect_fixture_event("second")
    ignore(live_effect_fixture_settle(5, 10, 20, false).wait())
    assert_eq(cell.val.state.title, "Snapshot 20")
    assert_eq(cell.val.bookkeeper_store.unwrap().last_sequence, 20)
    assert_eq(
      cell.val.bookkeeper_authorities.unwrap().contract_version,
      "registry-20",
    )
    assert_eq(cell.val.wiki_review.items[0].title, "Queue 20")
    assert_eq(cell.val.wiki_review.detail.unwrap().review_text, "Evidence 20")
    ignore(live_effect_fixture_settle(0, 5, 10, false).wait())
    assert_eq(cell.val.state.title, "Snapshot 20")
    assert_eq(cell.val.bookkeeper_store.unwrap().last_sequence, 20)
    assert_eq(
      cell.val.bookkeeper_authorities.unwrap().contract_version,
      "registry-20",
    )
    assert_eq(cell.val.wiki_review.items[0].title, "Queue 20")
    assert_eq(cell.val.wiki_review.detail.unwrap().review_text, "Evidence 20")
    live_test_preserved(original, cell.val)
    let choice = wiki_review_test_choice()
    let (prepared, _) = wiki_review_reduce(
      cell.val.wiki_review,
      Prepare(choice),
    )
    let (pending, _) = wiki_review_reduce(prepared, Confirm(choice))
    // The original requests already exist elsewhere; this harness only runs the
    // unrelated live data read while both mutation owners remain pending.
    cell.val = {
      ..cell.val,
      wiki_review: pending,
      bookkeeper_busy: true,
      bookkeeper_notice: Some("Original mutation pending"),
    }
    let before = cell.val
    live_effect_fixture_event("third")
    live_effect_fixture_event("third")
    ignore(live_effect_fixture_settle(10, 13, 30, true).wait())
    live_test_preserved(before, cell.val)
    assert_eq(
      cell.val.wiki_review.pending.unwrap().request,
      pending.pending.unwrap().request,
    )
    assert_eq(cell.val.wiki_review.pending.unwrap().choice, choice)
    assert_eq(cell.val.state.title, "Snapshot 20")
    assert_eq(cell.val.bookkeeper_store.unwrap().last_sequence, 20)
    assert_true(cell.val.error is Some(_))
    assert_true(cell.val.bookkeeper_reads.store_error is Some(_))
    assert_true(cell.val.bookkeeper_reads.authorities_error is Some(_))
    let wire = @json.parse(live_effect_fixture_requests())
    guard wire is { "reloads": 0, "requests": Array(requests), .. } else {
      fail("Missing controlled effect log")
    }
    assert_eq(requests.length(), 13)
    assert_eq(
      requests
      .filter(request => {
        request
        is {
          "url": "/api/wiki/reviews/inspect",
          "method": "POST",
          "body": "{\"review_id\":\"review-0\"}",
          ..
        }
      })
      .length(),
      2,
    )
    for request in requests {
      assert_true(
        request
        is {
          "method": "GET",
          "url": "./moonbook-ui-state.json"
          | "/api/bookkeeper/state"
          | "/api/bookkeeper/authorities"
          | "/api/wiki/reviews",
          ..
        } ||
        request is { "method": "POST", "url": "/api/wiki/reviews/inspect", .. },
      )
    }
    println(
      "Controlled SSE and deferred HTTP effects completed: 13 read requests, 0 reloads or writes",
    )
  })
}
