///|
fn lesson_receiver_test_readback() -> Json {
  let reference : Json = {
    "record_id": "task-fixture",
    "record_version": "3",
    "record_digest": "sha256:" + "a".repeat(64),
  }
  let source : Json = {
    "outcome": reference,
    "assessment": reference,
    "assessment_review": reference,
    "title": "Reviewed source <&>",
    "outcome_summary": "Synthetic local outcome",
    "assessment_summary": "Named assessment",
    "reviewer": { "reviewer_id": "fixture-reviewer" },
  }
  {
    "contract_version": "moonbook.task-lesson-readback.v1",
    "handoff": {
      "task": reference,
      "report": {
        "record_id": "report-fixture",
        "record_version": "1",
        "record_digest": "sha256:" + "b".repeat(64),
      },
    },
    "task_context": {
      "task_id": "task-fixture",
      "project_id": "project-fixture",
      "title": "Synthetic task",
      "source_context": { "reference": "fixture://source" },
      "acceptance_receipt": {
        "actor_id": "fixture-reviewer",
        "event_id": "fixture-accept-event",
      },
    },
    "report_context": { "summary": "Exact report summary" },
    "sources": [source],
    "pending": [],
    "state": "reviewed_source_available",
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
test "task handoff hydrates typed retrieval without retyping and keeps existing draft" {
  let original = {
    ..lesson_workspace_fixture(),
    handoff: Some(lesson_receiver_test_readback()),
  }
  let state = lesson_use_received_task(original, -1)
  assert_eq(lesson_field(state, "task-id"), "task-fixture")
  assert_eq(lesson_field(state, "task-version"), "3")
  assert_eq(lesson_field(state, "task-digest"), "sha256:" + "a".repeat(64))
  assert_eq(lesson_field(state, "guidance"), lesson_field(original, "guidance"))
  assert_eq(state.source, original.source)
  let payload = lesson_ui_payload(state, "retrieve").unwrap()
  assert_true(
    payload
    is {
      "target_task": { "record_id": "task-fixture", "record_version": "3", .. },
      "conditions": [{ "key": "project_id", "value": "project-fixture" }],
      ..
    },
  )
}

///|
test "explicit new lesson adopts reviewed source and repeated click preserves authored draft" {
  let initial = {
    ..initial_outcome_lesson_workspace(),
    handoff: Some(lesson_receiver_test_readback()),
  }
  let first = lesson_use_received_task(initial, 0)
  assert_true(first.source is Some(_))
  assert_false(first.lesson_id.is_empty())
  let authored = lesson_ui_edit(first, "guidance", "My exact new guidance")
  let repeated = lesson_use_received_task(authored, 0)
  assert_eq(repeated.lesson_id, authored.lesson_id)
  assert_eq(lesson_field(repeated, "guidance"), "My exact new guidance")
  assert_eq(
    lesson_use_received_task({ ..authored, pending: true, }, 0).lesson_id,
    authored.lesson_id,
  )
  assert_eq(lesson_use_received_task(authored, 99).request, authored.request)
}

///|
test "task handoff HTTP decoder refuses mismatched receipt and sender receives no journal details" {
  let readback = lesson_receiver_test_readback()
  let payload = lesson_task_field(readback, "handoff")
  let response : BookkeeperBrowserResponse = {
    ok: true,
    status: 200,
    body: (
      {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "operation": "task-handoff",
        "ok": true,
        "result": readback,
      } : Json).stringify(),
    error: None,
  }
  assert_eq(
    decode_outcome_lesson_response("task-handoff", payload, response),
    Ok(readback),
  )
  assert_true(
    decode_outcome_lesson_response("task-handoff", Json::null(), response)
    is Err(_),
  )
  let sender = lesson_task_sender_receipt(readback)
  assert_eq(lesson_task_field(sender, "handoff"), payload)
  for key in ["sources", "pending", "task_context", "report_context"] {
    assert_true(lesson_task_field(sender, key) is Null)
  }
}

///|
test "task handoff is visible as real GUI with exact binding source and explicit action" {
  let model = {
    ..draft_test_model(),
    outcome_lessons: {
      ..initial_outcome_lesson_workspace(),
      handoff: Some(lesson_receiver_test_readback()),
    },
  }
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=outcome_lesson_workspace_view,
    ),
  )
  for
    label in [
      "Receive task from Proj", "Import Proj task handoff file", "task-fixture @ 3",
      "report-fixture @ 1", "Reviewed source &lt;&amp;&gt;", "Start lesson from this assessment",
      "replace unsaved lesson draft", "Exact report summary",
    ] {
    assert_true(html.contains(label), msg=label)
  }
}

///|
extern "js" fn lesson_receiver_test_browser() -> LessonReceiverBrowser =
  #| () => {const b={location:{search:'?proj_lesson_source=https%3A%2F%2Fproj.example&proj_lesson_nonce=test-nonce'},calls:[],listener:null,timer:null};b.opener={postMessage:(value,origin)=>b.calls.push({value,origin})};b.addEventListener=(_,fn)=>b.listener=fn;b.removeEventListener=()=>b.listener=null;b.setTimeout=fn=>{b.timer=fn;return 1;};b.clearTimeout=()=>b.timer=null;return b;}

///|
extern "js" fn lesson_receiver_test_send(
  browser : LessonReceiverBrowser,
  origin : String,
  correct_window : Bool,
  nonce : String,
  payload : String,
) =
  #| (b,origin,correct,nonce,payload)=>b.listener?.({origin,source:correct?b.opener:{},data:{kind:'moonproj.lesson-handoff.v1',nonce,payload}})

///|
extern "js" fn lesson_receiver_test_listening(
  browser : LessonReceiverBrowser,
) -> Bool =
  #| b => !!b.listener

///|
test "direct receiver checks actual opener exact origin and nonce before reading payload" {
  @js.async_test(async fn() {
    let browser = lesson_receiver_test_browser()
    let promise = lesson_receive_task_on(browser)
    for
      (origin, correct, nonce) in [
        ("https://evil.example", true, "test-nonce"),
        ("https://proj.example", false, "test-nonce"),
        ("https://proj.example", true, "wrong"),
      ] {
      lesson_receiver_test_send(browser, origin, correct, nonce, "wrong")
      assert_true(lesson_receiver_test_listening(browser))
    }
    lesson_receiver_test_send(
      browser, "https://proj.example", true, "test-nonce", "exact-payload",
    )
    let result : String = promise.wait().cast()
    assert_eq(result, "exact-payload")
    assert_false(lesson_receiver_test_listening(browser))
  })
}

///|
test "task handoff ignores stale receiver completion without replacing current draft" {
  let state = { ..lesson_workspace_fixture(), pending: true, request: 9, }
  let model = { ..draft_test_model(), outcome_lessons: state, }
  let emit : @rabbita.Emit[Msg] = _ => @rabbita.none
  let (_, unchanged) = lesson_task_handoff_update(
    emit,
    model,
    TaskResolved(8, false, Ok(lesson_receiver_test_readback())),
  )
  assert_true(unchanged.outcome_lessons.handoff is None)
  assert_eq(unchanged.outcome_lessons.lesson_id, state.lesson_id)
  assert_eq(
    lesson_field(unchanged.outcome_lessons, "guidance"),
    lesson_field(state, "guidance"),
  )
}

///|
extern "js" fn task_handoff_http_fixture(
  url : String,
  body : String,
) -> @js.Promise =
  #| async (url,body) => JSON.stringify({ok:url==='/api/bookkeeper/lessons/task-handoff',status:200,body:JSON.stringify({schema:'moonbook.outcome-lesson-operation.v1',ok:true,operation:'task-handoff',result:{contract_version:'moonbook.task-lesson-readback.v1',handoff:JSON.parse(body),sources:[],pending:[],state:'reviewed_source_missing',activation_authorized:false,external_side_effects_applied:false}})})

///|
test "task handoff UI posts exact serialized binding to its configured host route" {
  @js.async_test(async fn() {
    let payload = lesson_task_field(lesson_receiver_test_readback(), "handoff")
    let result = post_outcome_lesson(
      "task-handoff",
      payload,
      send=task_handoff_http_fixture,
    )
    guard result is Ok(readback) else {
      fail("fixture rejected exact transport")
    }
    assert_eq(lesson_task_field(readback, "handoff"), payload)
    assert_eq(lesson_task_text(readback, "state"), "reviewed_source_missing")
  })
}
