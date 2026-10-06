///|
fn saved_return_test_entry(state? : String = "retained") -> Json {
  let handoff = lesson_task_field(lesson_receiver_test_readback(), "handoff")
  let reference = draft_test_record("saved").record.to_json()
  {
    "contract_version": "moonbook.saved-lesson-receipt.v1",
    "source_product": "moonbook",
    "destination_product": "moonproj",
    "task": lesson_task_field(handoff, "task"),
    "report": lesson_task_field(handoff, "report"),
    "submission": reference,
    "outcome": reference,
    "assessment": reference,
    "assessment_review": reference,
    "lesson": reference,
    "lesson_id": "saved",
    "title": "Saved <&> lesson",
    "state": state,
    "review": if state == "pending" {
      Json::null()
    } else {
      {
        "receipt": reference,
        "disposition": if state == "retained" {
          "Accept"
        } else {
          "Reject"
        },
        "reviewer_id": "named-reviewer",
        "decided_at": 20,
      }
    },
    "current": if state == "retained" {
      reference
    } else {
      Json::null()
    },
    "selection_review": Json::null(),
    "currentness": if state == "retained" {
      "current"
    } else {
      "not_retained"
    },
    "journal_sequence": 10,
    "activation_authorized": false,
    "external_side_effects_applied": false,
    "customer_acceptance": "not_asserted",
    "cash": "not_asserted",
  }
}

///|
fn saved_return_test_readback(
  entry? : Json = saved_return_test_entry(),
) -> Json {
  guard lesson_receiver_test_readback() is Object(fields) else {
    abort("fixture")
  }
  fields["saved_lessons"] = [entry]
  Json::object(fields)
}

///|
fn saved_return_test_change(
  value : Json,
  key : String,
  replacement : Json,
) -> Json {
  guard value is Object(fields) else { abort("fixture") }
  let fields = fields.copy()
  fields[key] = replacement
  Json::object(fields)
}

///|
test "saved lesson receipt requires exact task report and truthful state review currentness" {
  let handoff = lesson_task_field(lesson_receiver_test_readback(), "handoff")
  for state in ["pending", "retained", "rejected"] {
    assert_true(
      saved_lesson_receipt_valid(saved_return_test_entry(state~), handoff),
    )
  }
  let retained = saved_return_test_entry()
  for
    (key, wrong) in [
      ("state", "pending".to_json()),
      ("review", Json::null()),
      ("current", Json::null()),
      ("task", draft_test_record("other").record.to_json()),
      ("report", Json::null()),
      ("activation_authorized", true.to_json()),
      ("cash", "received".to_json()),
    ] {
    assert_false(
      saved_lesson_receipt_valid(
        saved_return_test_change(retained, key, wrong),
        handoff,
      ),
    )
  }
  let legacy = saved_return_test_change(
    saved_return_test_change(retained, "current", Json::null()),
    "currentness",
    "legacy_unselected".to_json(),
  )
  assert_true(saved_lesson_receipt_valid(legacy, handoff))
}

///|
test "saved lesson selection is explicit reopened exactly and never substitutes another version" {
  let readback = saved_return_test_readback()
  let initial = saved_lesson_return_received(
    initial_saved_lesson_return(),
    readback,
    "",
    50,
  )
  assert_true(initial.selected is None)
  let reference = lesson_task_field(saved_return_test_entry(), "lesson")
  let reopened = saved_lesson_return_received(
    initial,
    readback,
    reference.stringify(),
    60,
  )
  assert_eq(reopened.selected, saved_lesson_reference(reference))
  let missing = saved_lesson_return_received(
    initial,
    readback,
    draft_test_record("other").record.to_json().stringify(),
    70,
  )
  assert_true(missing.selected is None)
  assert_true(missing.notice.contains("nothing was substituted"))
  let duplicate = saved_return_test_change(
    readback,
    "saved_lessons",
    [saved_return_test_entry(), saved_return_test_entry()].to_json(),
  )
  assert_true(saved_lesson_selected(duplicate, reopened.selected) is None)
  assert_true(
    lesson_task_field(lesson_task_sender_receipt(readback), "saved_lessons")
    is Null,
  )
}

///|
test "fresh saved receipt refresh preserves authoring and history drafts and ignores stale results" {
  let readback = saved_return_test_readback()
  let state = {
    ..lesson_workspace_fixture(),
    handoff: Some(readback),
    saved_return: saved_lesson_return_received(
      initial_saved_lesson_return(),
      readback,
      "",
      10,
    ),
  }
  let model = { ..draft_test_model(), outcome_lessons: state, }
  let reference = saved_lesson_reference(
    lesson_task_field(saved_return_test_entry(), "lesson"),
  ).unwrap()
  let (_, selected) = saved_lesson_return_update(
    _ => @rabbita.none,
    model,
    ChooseSavedLesson(reference),
  )
  let (_, pending) = saved_lesson_return_update(
    _ => @rabbita.none,
    selected,
    RefreshSavedLessons("refresh"),
  )
  assert_true(pending.outcome_lessons.pending)
  let request = pending.outcome_lessons.request
  let (_, stale) = saved_lesson_return_update(
    _ => @rabbita.none,
    pending,
    SavedLessonsRead(request - 1, "refresh", Ok(readback)),
  )
  assert_true(stale.outcome_lessons.pending)
  let (_, fresh) = saved_lesson_return_update(
    _ => @rabbita.none,
    pending,
    SavedLessonsRead(request, "refresh", Ok(readback)),
  )
  assert_false(fresh.outcome_lessons.pending)
  assert_eq(fresh.outcome_lessons.fields, state.fields)
  assert_eq(fresh.outcome_lessons.source, state.source)
  assert_eq(fresh.outcome_lessons.saved_return.selected, Some(reference))
  let (_, failed) = saved_lesson_return_update(
    _ => @rabbita.none,
    pending,
    SavedLessonsRead(request, "return", Err("offline")),
  )
  assert_false(failed.outcome_lessons.pending)
  assert_true(
    failed.outcome_lessons.saved_return.notice.contains("Nothing was returned"),
  )
  assert_eq(failed.outcome_lessons.fields, state.fields)
}

///|
test "saved lesson return UI exposes honest statuses and explicit actions without guidance export" {
  let readback = saved_return_test_readback()
  let model = {
    ..draft_test_model(),
    outcome_lessons: { ..lesson_workspace_fixture(), handoff: Some(readback), },
  }
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_ : Msg, old) { old },
      view=saved_lesson_return_view,
    ),
  )
  for
    label in [
      "Saved &lt;&amp;&gt; lesson", "retained", "named-reviewer", "Refresh saved lesson status",
      "Return selected lesson status to Proj", "Download selected lesson receipt",
      "Guidance and scope stay in Book", "not signatures",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  assert_false(html.contains(lesson_field(model.outcome_lessons, "guidance")))
}

///|
extern "js" fn saved_return_test_ack(
  browser : LessonReceiverBrowser,
  origin : String,
  correct : Bool,
  nonce : String,
  text : String,
) =
  #| (b,origin,correct,nonce,text)=>b.listener?.({origin,source:correct?b.opener:{},data:{kind:'moonproj.saved-lesson-received.v1',nonce,payload:text}})

///|
extern "js" fn saved_return_test_expire(browser : LessonReceiverBrowser) =
  #| b=>b.timer?.()

///|
extern "js" fn saved_return_test_closed(browser : LessonReceiverBrowser) =
  #| b=>b.opener.closed=true

///|
test "Book return waits for exact opener origin nonce and payload acknowledgment and recovers timeout" {
  @js.async_test(async fn() {
    let browser = lesson_receiver_test_browser()
    let promise = lesson_send_saved_receipt_on(browser, "exact-receipt")
    for
      (origin, correct, nonce, text) in [
        ("https://other.example", true, "test-nonce", "exact-receipt"),
        ("https://proj.example", false, "test-nonce", "exact-receipt"),
        ("https://proj.example", true, "old", "exact-receipt"),
        ("https://proj.example", true, "test-nonce", "other"),
      ] {
      saved_return_test_ack(browser, origin, correct, nonce, text)
      assert_true(lesson_receiver_test_listening(browser))
    }
    saved_return_test_ack(
      browser, "https://proj.example", true, "test-nonce", "exact-receipt",
    )
    let returned : Bool = promise.wait().cast()
    assert_true(returned)
    assert_false(lesson_receiver_test_listening(browser))
    let timeout = lesson_send_saved_receipt_on(browser, "timed-out")
    saved_return_test_expire(browser)
    let returned : Bool = timeout.wait().cast()
    assert_false(returned)
    assert_false(lesson_receiver_test_listening(browser))
    saved_return_test_closed(browser)
    let returned : Bool = lesson_send_saved_receipt_on(browser, "closed")
      .wait()
      .cast()
    assert_false(returned)
    assert_false(lesson_receiver_test_listening(browser))
  })
}

///|
extern "js" fn saved_return_native_fixture() -> @js.Promise =
  #| async()=>{const path=globalThis.process?.env?.MOONPROJ_LESSON_FIXTURE_OUTPUT;if(!path)return '';const fs=await import('node:fs/promises');return await fs.readFile(path+'.saved-retained.json','utf8');}

///|
extern "js" fn saved_return_write_fixture(text : String) -> @js.Promise =
  #| async text=>{const fs=await import('node:fs/promises');await fs.writeFile(process.env.MOONPROJ_LESSON_FIXTURE_OUTPUT+'.saved-return-ui.json',text);}

///|
test "actual native journal receipt enters Book UI decoder and explicit selected return wrapper" {
  @js.async_test(async fn() {
    let wire : String = saved_return_native_fixture().wait().cast()
    if wire.is_empty() {
      return
    }
    let response = @json.parse(wire)
    let result = lesson_task_field(response, "result")
    let handoff = lesson_task_field(result, "handoff")
    let decoded = decode_outcome_lesson_response("task-handoff", handoff, {
      ok: true,
      status: 200,
      body: wire,
      error: None,
    }).unwrap()
    let entry = saved_lesson_receipts(decoded)[0]
    assert_true(saved_lesson_receipt_valid(entry, handoff))
    let selected = saved_lesson_return_received(
      initial_saved_lesson_return(),
      decoded,
      lesson_task_field(entry, "lesson").stringify(),
      500,
    )
    let receipt = saved_lesson_selected(decoded, selected.selected).unwrap()
    let wrapper = saved_lesson_return_wrapper(
      receipt,
      "https://book.example",
      selected.observed_at,
    )
    assert_false(wrapper.stringify().contains("PRIVATE GUIDANCE"))
    assert_false(wrapper.stringify().contains("PRIVATE SCOPE"))
    assert_eq(lesson_task_text(receipt, "state"), "retained")
    ignore(saved_return_write_fixture(wrapper.stringify(indent=2)).wait())
  })
}
