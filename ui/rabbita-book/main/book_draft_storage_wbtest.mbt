///|
extern "js" fn draft_storage_fixture_install() =
  #| () => {
  #|   const state = { descriptor: Object.getOwnPropertyDescriptor(globalThis, "localStorage"), data: new Map(), blocked: false, writes: 0 };
  #|   globalThis.__bookDraftStorage = state;
  #|   Object.defineProperty(globalThis, "localStorage", { configurable: true, value: {
  #|     getItem(key) { if (state.blocked) throw new Error("blocked"); return state.data.get(key) ?? null; },
  #|     setItem(key, value) { if (state.blocked) throw new Error("quota"); state.writes++; state.data.set(key, value); },
  #|     removeItem(key) { if (state.blocked) throw new Error("blocked"); state.data.delete(key); }
  #|   } });
  #| }

///|
extern "js" fn draft_storage_fixture_restore() =
  #| () => {
  #|   const state = globalThis.__bookDraftStorage;
  #|   if (state.descriptor) Object.defineProperty(globalThis, "localStorage", state.descriptor); else delete globalThis.localStorage;
  #|   delete globalThis.__bookDraftStorage;
  #| }

///|
extern "js" fn draft_storage_fixture_contents() -> String =
  #| () => JSON.stringify(Array.from(globalThis.__bookDraftStorage.data.values()))

///|
extern "js" fn draft_storage_fixture_block(block : Bool) =
  #| block => { globalThis.__bookDraftStorage.blocked = block; }

///|
extern "js" fn draft_storage_fixture_corrupt(key : String, text : String) =
  #| (key, text) => globalThis.__bookDraftStorage.data.set("moonbook.review-summary.v1:" + encodeURIComponent(key), text)

///|
test "actual browser storage commands save only text and restore explicitly after a cold start" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let scheduler : LiveTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref(draft_test_model())
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(dispatch(PrepareBookkeeperReview("Accept")))
  assert_false(cell.val.draft_recovery.storage_pending)
  assert_eq(cell.val.draft_recovery.saved, None)
  let exact = "  Long-form summary <&> 中文 😀\n\nPreserve spacing.  "
  ignore(dispatch(DraftRecovery(EditSummary(exact))))
  ignore(dispatch(DraftRecovery(SaveSummary)))
  assert_eq(cell.val.draft_recovery.saved, Some(exact))
  let stored = @json.parse(draft_storage_fixture_contents())
  guard stored is [String(raw)] else { fail("Expected one summary copy") }
  guard @json.parse(raw) is Object(fields) else {
    fail("Expected summary object")
  }
  assert_eq(fields.length(), 2)
  assert_true(
    fields is { "version": 1, "summary": String(value), .. } && value == exact,
  )
  assert_false(raw.contains("server-evidence"))
  assert_false(raw.contains("authority"))
  assert_false(raw.contains("secret_fixture"))
  // Recreate the model exactly as a page reload does. No selection, authority,
  // payload or summary is restored from local storage by initialization.
  cell.val = draft_test_model()
  assert_eq(cell.val.draft_recovery.summary, "")
  ignore(dispatch(PrepareBookkeeperReview("Accept")))
  assert_eq(cell.val.draft_recovery.saved, Some(exact))
  assert_eq(
    cell.val.draft_recovery.summary,
    book_draft_default_summary("Accept"),
  )
  let fresh_payload = cell.val.bookkeeper_draft
  ignore(dispatch(DraftRecovery(RestoreSummary)))
  assert_eq(cell.val.draft_recovery.summary, exact)
  assert_eq(book_json_summary(cell.val.bookkeeper_draft), Some(exact))
  guard @json.parse(fresh_payload) is Object(before) &&
    @json.parse(cell.val.bookkeeper_draft) is Object(after) else {
    fail("Review objects expected")
  }
  for key, value in before {
    if key != "summary" {
      assert_eq(after.get(key), Some(value))
    }
  }
  assert_false(cell.val.bookkeeper_busy)
  ignore(dispatch(DraftRecovery(DiscardSummary)))
  assert_eq(draft_storage_fixture_contents(), "[]")
  assert_eq(cell.val.draft_recovery.saved, None)
  assert_eq(cell.val.draft_recovery.summary, exact)
  cell.val = draft_test_model()
  ignore(dispatch(PrepareBookkeeperReview("Accept")))
  assert_eq(cell.val.draft_recovery.saved, None)
  draft_storage_fixture_block(true)
  ignore(
    dispatch(DraftRecovery(EditSummary("Still present on storage failure"))),
  )
  ignore(dispatch(DraftRecovery(SaveSummary)))
  assert_eq(cell.val.draft_recovery.summary, "Still present on storage failure")
  assert_eq(cell.val.draft_recovery.saved, None)
  assert_true(
    cell.val.draft_recovery.storage_notice.unwrap().contains("blocked"),
  )
}

///|
test "actual storage failures malformed entries and unsupported versions fail without losing text" {
  draft_storage_fixture_install()
  defer draft_storage_fixture_restore()
  let key = book_note_key(draft_test_prepared()).unwrap()
  draft_storage_fixture_block(true)
  for action in ["read", "save", "discard"] {
    assert_true(
      book_summary_storage_result(book_summary_storage(action, key, "keep"))
      is Err(_),
    )
  }
  draft_storage_fixture_block(false)
  for
    value in [
      "{broken", "{\"version\":2,\"summary\":\"old\"}", "{\"version\":1,\"summary\":false}",
    ] {
    draft_storage_fixture_corrupt(key, value)
    assert_true(
      book_summary_storage_result(book_summary_storage("read", key, ""))
      is Err(_),
    )
  }
  assert_true(
    book_summary_storage_result(book_summary_storage("discard", key, ""))
    is Ok(None),
  )
  assert_eq(draft_storage_fixture_contents(), "[]")
  assert_true(book_summary_storage_result("invalid envelope") is Err(_))
}

///|
extern "js" fn draft_language_fixture_run(change : () -> Unit) -> String =
  #| change => {
  #|   const originals = ["window", "document", "navigator", "localStorage"].map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]);
  #|   let reloads = 0;
  #|   const document = { cookie: "", documentElement: { lang: "en-US", dir: "ltr" } };
  #|   try {
  #|     Object.defineProperty(globalThis, "window", { configurable: true, value: { location: { reload() { reloads++; } } } });
  #|     Object.defineProperty(globalThis, "document", { configurable: true, value: document });
  #|     Object.defineProperty(globalThis, "navigator", { configurable: true, value: { languages: ["zh-CN"] } });
  #|     Object.defineProperty(globalThis, "localStorage", { configurable: true, value: { setItem() { throw new Error("blocked"); } } });
  #|     change();
  #|     return JSON.stringify({ reloads, lang: document.documentElement.lang, cookie: document.cookie });
  #|   } finally {
  #|     for (const [key, descriptor] of originals) {
  #|       if (descriptor) Object.defineProperty(globalThis, key, descriptor); else delete globalThis[key];
  #|     }
  #|   }
  #| }

///|
test "actual system language effect never reloads even when storage is blocked" {
  let wire = @json.parse(
    draft_language_fixture_run(() => {
      let scheduler : LiveTestScheduler = {
        hooks: { url_request: None, url_changed: None, },
      }
      @cmd.Scheduler::add(scheduler, use_system_interface_locale_cmd())
    }),
  )
  assert_true(
    wire is { "reloads": 0, "lang": "zh-Hans", "cookie": String(cookie), .. } &&
    cookie.contains("=system;"),
  )
}
