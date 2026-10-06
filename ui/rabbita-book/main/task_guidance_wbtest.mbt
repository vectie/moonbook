///|
fn guidance_ui_handoff() -> Json {
  {
    "contract_version": "moonproj.book-guidance-query.v1",
    "source_product": "moonproj",
    "target_task": {
      "record_id": "next-task",
      "record_version": "3",
      "record_digest": "sha256:captured",
    },
    "task_snapshot": "captured minimal task",
    "conditions": [
      { "key": "project_id", "value": "project-a" },
      { "key": "suite_product_id", "value": "moonbook" },
    ],
    "authorizing": false,
  }
}

///|
fn guidance_ui_ready() -> OutcomeLessonWorkspace {
  let handoff = guidance_ui_handoff()
  let state = task_guidance_received(lesson_workspace_fixture(), handoff)
  let state = lesson_ui_edit(state, "query-customer", "customer-a")
  let state = lesson_ui_edit(state, "query-decision", "vendor-comparison")
  let query = lesson_ui_payload(state, "retrieve").unwrap()
  {
    ..state,
    result: Some({
      "contract_version": "moonbook.outcome-lesson-retrieval.v1",
      "query": query,
      "matches": [{ "lesson": draft_test_record("guidance").to_json() }],
      "exclusions": [],
      "activation_authorized": false,
      "external_side_effects_applied": false,
    }),
  }
}

///|
test "task guidance UI fills exact context preserves authored draft and never invents customer scope" {
  let original = lesson_workspace_fixture()
  let state = task_guidance_received(original, guidance_ui_handoff())
  assert_eq(lesson_field(state, "task-id"), "next-task")
  assert_eq(lesson_field(state, "task-version"), "3")
  assert_eq(lesson_field(state, "task-digest"), "sha256:captured")
  assert_eq(
    lesson_field(state, "query-extra"),
    "project_id=project-a\nsuite_product_id=moonbook",
  )
  assert_eq(lesson_field(state, "query-customer"), "")
  assert_eq(lesson_field(state, "query-decision"), "")
  assert_eq(lesson_field(state, "guidance"), lesson_field(original, "guidance"))
  assert_eq(state.source, original.source)
  assert_true(
    lesson_ui_payload(
      lesson_ui_edit(state, "query-extra", "project_id=other"),
      "retrieve",
    )
    is Err(_),
  )
  assert_true(
    lesson_ui_payload(lesson_ui_edit(state, "task-id", "other"), "retrieve")
    is Err(_),
  )
}

///|
test "task guidance private selection requires explicit destination bound to exact received task" {
  let ready = guidance_ui_ready()
  let reference = draft_test_record("guidance").record
  assert_true(task_guidance_selection_request(ready, reference) is Err(_))
  let confirmed = {
    ..ready,
    task_guidance: {
      ..ready.task_guidance,
      confirmed_handoff: ready.task_guidance.handoff,
      confirmed_origin: "https://proj.example",
    },
  }
  let request = task_guidance_selection_request(confirmed, reference).unwrap()
  assert_eq(lesson_task_field(request, "lesson"), reference.to_json())
  assert_eq(
    lesson_task_field(request, "query"),
    lesson_ui_payload(confirmed, "retrieve").unwrap(),
  )
  assert_true(
    task_guidance_selection_request(
      lesson_ui_edit(confirmed, "query-customer", "other"),
      reference,
    )
    is Err(_),
  )
  let reopened = task_guidance_received(confirmed, guidance_ui_handoff())
  assert_eq(reopened.task_guidance.confirmed_origin, "")
  assert_true(reopened.task_guidance.confirmed_handoff is None)
}

///|
test "task guidance cancellation ignores late results and cannot cancel unrelated lesson saving" {
  let ready = guidance_ui_ready()
  let saving = {
    ..draft_test_model(),
    outcome_lessons: { ..ready, request: 8, pending: true, },
  }
  let unchanged = snapshot_test_step(
    saving,
    OutcomeLesson(TaskGuidance(Cancel)),
  )
  assert_true(unchanged.outcome_lessons.pending)
  assert_eq(unchanged.outcome_lessons.request, 8)
  let waiting = {
    ..saving,
    outcome_lessons: {
      ..saving.outcome_lessons,
      task_guidance: { ..ready.task_guidance, busy: true, },
    },
  }
  let cancelled = snapshot_test_step(
    waiting,
    OutcomeLesson(TaskGuidance(Cancel)),
  )
  assert_false(cancelled.outcome_lessons.pending)
  assert_true(cancelled.outcome_lessons.task_guidance.handoff is None)
  let late = snapshot_test_step(
    cancelled,
    OutcomeLesson(TaskGuidance(Resolved(8, guidance_ui_handoff(), Ok({})))),
  )
  assert_true(late.outcome_lessons.task_guidance.handoff is None)
  let late = snapshot_test_step(
    late,
    OutcomeLesson(TaskGuidance(Selected(8, {}, Ok({})))),
  )
  let late = snapshot_test_step(
    late,
    OutcomeLesson(TaskGuidance(Returned(8, true))),
  )
  assert_true(late.outcome_lessons.task_guidance.selection is None)
  assert_false(late.outcome_lessons.notice.contains("Proj received"))
}

///|
extern "js" fn guidance_test_browser(
  text : String,
  mode : Int,
) -> LessonReceiverBrowser =
  #| (text,mode) => {
  #|   const listeners=new Set(),timers=new Map();let serial=0;
  #|   const browser={location:{origin:'https://book.example',search:'?proj_guidance_source=https%3A%2F%2Fproj.example&proj_guidance_nonce=guidance-nonce'},test:{text,mode,sent:[],listeners,timers},setTimeout:fn=>{timers.set(++serial,fn);return serial;},clearTimeout:id=>timers.delete(id),addEventListener:(kind,fn)=>{if(kind==='message')listeners.add(fn);},removeEventListener:(kind,fn)=>listeners.delete(fn)};
  #|   const dispatch=e=>[...listeners].forEach(fn=>fn(e));browser.test.dispatch=dispatch;
  #|   browser.opener={closed:false,postMessage:(data,origin)=>{browser.test.sent.push({data,origin});if(data.kind==='moonbook.guidance-ready.v1'){
  #|     const payload=browser.test.text,base={source:browser.opener,origin:'https://proj.example',data:{kind:'moonproj.guidance-query.v1',nonce:'guidance-nonce',payload}};
  #|     dispatch({...base,source:{}});dispatch({...base,origin:'https://other.example'});dispatch({...base,data:{...base.data,nonce:'wrong'}});if(browser.test.mode!==1)dispatch(base);
  #|   }else if(data.kind==='moonbook.guidance-selection.v1'&&browser.test.mode!==2){dispatch({source:browser.opener,origin:'https://proj.example',data:{kind:'moonproj.guidance-received.v1',nonce:'guidance-nonce',payload:data.payload+'wrong'}});dispatch({source:browser.opener,origin:'https://proj.example',data:{kind:'moonproj.guidance-received.v1',nonce:'guidance-nonce',payload:data.payload}});}}};return browser;
  #| }

///|
extern "js" fn guidance_test_browser_change(
  browser : LessonReceiverBrowser,
  mode : String,
) =
  #| (b,mode)=>{if(mode==='url')b.location.search='?proj_guidance_source=https%3A%2F%2Fother.example&proj_guidance_nonce=guidance-nonce';else if(mode==='opener')b.opener={closed:false,postMessage(){throw Error('wrong opener')}};else if(mode==='timeout')for(const fn of [...b.test.timers.values()])fn();}

///|
extern "js" fn guidance_test_browser_counts(
  browser : LessonReceiverBrowser,
) -> String =
  #| b=>JSON.stringify({sent:b.test.sent.length,listeners:b.test.listeners.size,timers:b.test.timers.size})

///|
extern "js" fn guidance_test_browser_ack(
  browser : LessonReceiverBrowser,
  text : String,
) =
  #| (b,text)=>b.test.dispatch({source:b.__moonbookGuidanceSession?.opener,origin:'https://proj.example',data:{kind:'moonproj.guidance-received.v1',nonce:'guidance-nonce',payload:text}})

///|
test "task guidance production bridge binds source nonce destination and cancels cleanly" {
  @js.async_test(async fn() {
    let handoff = guidance_ui_handoff()
    let browser = guidance_test_browser(handoff.stringify(), 0)
    let received : String = task_guidance_receive_on(browser).wait().cast()
    assert_eq(received, handoff.stringify())
    let selection = (
      { "handoff": handoff, "book_origin": "https://book.example" } : Json).stringify()
    let denied : Bool = task_guidance_send_on(browser, selection, "")
      .wait()
      .cast()
    assert_false(denied)
    assert_eq(@json.parse(guidance_test_browser_counts(browser)), {
      "sent": 1,
      "listeners": 0,
      "timers": 0,
    })
    let acknowledged : Bool = task_guidance_send_on(
        browser, selection, "https://proj.example",
      )
      .wait()
      .cast()
    assert_true(acknowledged)
    assert_eq(@json.parse(guidance_test_browser_counts(browser)), {
      "sent": 2,
      "listeners": 0,
      "timers": 0,
    })
    guidance_test_browser_change(browser, "url")
    let denied : Bool = task_guidance_send_on(
        browser, selection, "https://proj.example",
      )
      .wait()
      .cast()
    assert_false(denied)
    assert_eq(@json.parse(guidance_test_browser_counts(browser)), {
      "sent": 2,
      "listeners": 0,
      "timers": 0,
    })
    let cancelled = guidance_test_browser(handoff.stringify(), 1)
    let pending = task_guidance_receive_on(cancelled)
    task_guidance_cancel_on(cancelled)
    let result : String = pending.wait().cast()
    assert_eq(result, "")
    assert_eq(@json.parse(guidance_test_browser_counts(cancelled)), {
      "sent": 1,
      "listeners": 0,
      "timers": 0,
    })
    let waiting = guidance_test_browser(handoff.stringify(), 2)
    ignore(task_guidance_receive_on(waiting).wait())
    let pending = task_guidance_send_on(
      waiting, selection, "https://proj.example",
    )
    task_guidance_cancel_on(waiting)
    let result : Bool = pending.wait().cast()
    assert_false(result)
    assert_eq(@json.parse(guidance_test_browser_counts(waiting)), {
      "sent": 2,
      "listeners": 0,
      "timers": 0,
    })
    let changed = guidance_test_browser(handoff.stringify(), 2)
    ignore(task_guidance_receive_on(changed).wait())
    let pending = task_guidance_send_on(
      changed, selection, "https://proj.example",
    )
    guidance_test_browser_change(changed, "url")
    guidance_test_browser_ack(changed, selection)
    let result : Bool = pending.wait().cast()
    assert_false(result)
    assert_eq(@json.parse(guidance_test_browser_counts(changed)), {
      "sent": 2,
      "listeners": 0,
      "timers": 0,
    })
    let timed_out = guidance_test_browser(handoff.stringify(), 1)
    let pending = task_guidance_receive_on(timed_out)
    guidance_test_browser_change(timed_out, "timeout")
    let result : String = pending.wait().cast()
    assert_eq(result, "")
    assert_eq(@json.parse(guidance_test_browser_counts(timed_out)), {
      "sent": 1,
      "listeners": 0,
      "timers": 0,
    })
  })
}

///|
extern "js" fn guidance_wire_read() -> @js.Promise =
  #| async()=>{const path=globalThis.process?.env?.MOONBOOK_GUIDANCE_WIRE;if(!path)return '';return await (await import('node:fs/promises')).readFile(path,'utf8');}

///|
extern "js" fn guidance_wire_install(
  text : String,
  browser : LessonReceiverBrowser,
) =
  #| (text,browser)=>{
  #|   const wire=JSON.parse(text),keys=['location','opener','addEventListener','removeEventListener','__moonbookGuidanceSession','__moonbookGuidanceCancel'],descriptors=Object.fromEntries(keys.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
  #|   const state={wire,browser,keys,descriptors,oldFetch:globalThis.fetch,requests:[]};globalThis.__bookGuidanceWire=state;
  #|   for(const key of ['location','opener','addEventListener','removeEventListener'])Object.defineProperty(globalThis,key,{value:browser[key],writable:true,configurable:true});
  #|   globalThis.fetch=async(url,options={})=>{const response=url==='/api/bookkeeper/lessons/guidance-query'?wire.query_response:url==='/api/bookkeeper/lessons/retrieve'?wire.retrieval_response:url==='/api/bookkeeper/lessons/guidance-select'?wire.selection_response:null;if(!response)throw Error('Unexpected request '+url);state.requests.push({url,body:JSON.parse(options.body),response});return {ok:true,status:200,text:async()=>JSON.stringify(response)};};
  #| }

///|
extern "js" fn guidance_wire_restore() =
  #| ()=>{const s=globalThis.__bookGuidanceWire;globalThis.__moonbookGuidanceCancel?.();for(const key of s.keys){if(s.descriptors[key])Object.defineProperty(globalThis,key,s.descriptors[key]);else delete globalThis[key];}globalThis.fetch=s.oldFetch;delete globalThis.__bookGuidanceWire;}

///|
extern "js" fn guidance_wire_sent() -> String =
  #| ()=>JSON.stringify(globalThis.__bookGuidanceWire.browser.test.sent.filter(item=>item.data.kind==='moonbook.guidance-selection.v1').map(item=>JSON.parse(item.data.payload)))

///|
extern "js" fn guidance_wire_write(selection : String) -> @js.Promise =
  #| async selection=>{const fs=await import('node:fs/promises'),s=globalThis.__bookGuidanceWire,env=globalThis.process.env;if(env.MOONBOOK_GUIDANCE_SELECTION)await fs.writeFile(env.MOONBOOK_GUIDANCE_SELECTION,selection);if(env.MOONBOOK_GUIDANCE_UI_REQUESTS)await fs.writeFile(env.MOONBOOK_GUIDANCE_UI_REQUESTS,JSON.stringify({journal_root:s.wire.journal_root,requests:s.requests},null,2));}

///|
test "task guidance actual UI receives Proj bytes queries selects and returns only explicit advice" {
  @js.async_test(async fn() {
    let text : String = guidance_wire_read().wait().cast()
    if text.is_empty() {
      return
    }
    let fixture = @json.parse(text)
    let handoff = lesson_task_field(fixture, "handoff")
    let native_response = lesson_task_field(fixture, "selection_response")
    let native_result = lesson_task_field(native_response, "result")
    guard native_result is Object(fields) else {
      fail("Missing native selection")
    }
    let extended = fields.copy()
    extended["private_memory"] = "must never leave Book".to_json()
    let unsafe_response : Json = {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "ok": true,
      "operation": "guidance-select",
      "result": Json::object(extended),
    }
    assert_true(
      task_guidance_decode(
        "guidance-select",
        lesson_task_field(fixture, "selection_request"),
        {
          ok: true,
          status: 200,
          body: unsafe_response.stringify(),
          error: None,
        },
      )
      is Err(_),
    )
    let browser = guidance_test_browser(handoff.stringify(), 0)
    guidance_wire_install(text, browser)
    defer guidance_wire_restore()
    let original = lesson_workspace_fixture()
    let cell = Ref({ ..draft_test_model(), outcome_lessons: original, })
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      let (command, next) = update(
        message => @cmd.custom_cmd(_ => ignore(dispatch(message))),
        message,
        cell.val,
      )
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      @rabbita.none
    }
    ignore(dispatch(OutcomeLesson(TaskGuidance(Receive))))
    ignore(outcome_native_fixture_tick().wait())
    assert_eq(cell.val.outcome_lessons.task_guidance.handoff, Some(handoff))
    assert_eq(cell.val.outcome_lessons.task_guidance.confirmed_origin, "")
    assert_eq(
      lesson_field(cell.val.outcome_lessons, "guidance"),
      lesson_field(original, "guidance"),
    )
    ignore(dispatch(OutcomeLesson(Edit("query-customer", "customer-a"))))
    ignore(dispatch(OutcomeLesson(Edit("query-decision", "vendor-comparison"))))
    ignore(dispatch(OutcomeLesson(Submit("retrieve"))))
    ignore(outcome_native_fixture_tick().wait())
    assert_eq(
      lesson_ui_payload(cell.val.outcome_lessons, "retrieve").unwrap(),
      lesson_task_field(fixture, "query"),
    )
    let reference : BookkeeperRecordReference = @json.from_json(
      lesson_task_field(fixture, "reference"),
    )
    ignore(dispatch(OutcomeLesson(TaskGuidance(Use(reference)))))
    assert_eq(guidance_wire_sent(), "[]")
    assert_false(cell.val.outcome_lessons.pending)
    ignore(
      dispatch(
        OutcomeLesson(
          TaskGuidance(ConfirmDestination(handoff, "https://other.example")),
        ),
      ),
    )
    assert_eq(cell.val.outcome_lessons.task_guidance.confirmed_origin, "")
    ignore(
      dispatch(
        OutcomeLesson(
          TaskGuidance(ConfirmDestination(handoff, "https://proj.example")),
        ),
      ),
    )
    ignore(dispatch(OutcomeLesson(TaskGuidance(Use(reference)))))
    ignore(dispatch(OutcomeLesson(TaskGuidance(Use(reference)))))
    ignore(outcome_native_fixture_tick().wait())
    assert_false(cell.val.outcome_lessons.pending)
    assert_true(
      cell.val.outcome_lessons.notice.contains("Proj received"),
      msg=cell.val.outcome_lessons.notice,
    )
    let sent = @json.parse(guidance_wire_sent())
    guard sent is Array(values) && values.length() == 1 else {
      fail("Expected exactly one explicit guidance return")
    }
    let selection = values[0]
    assert_eq(lesson_task_field(selection, "handoff"), handoff)
    assert_eq(
      lesson_task_field(selection, "query"),
      lesson_task_field(fixture, "query"),
    )
    assert_eq(
      lesson_task_field(lesson_task_field(selection, "lesson"), "reference"),
      reference.to_json(),
    )
    assert_eq(
      lesson_task_field(lesson_task_field(selection, "lesson"), "guidance"),
      lesson_task_field(lesson_task_field(native_result, "lesson"), "guidance"),
    )
    assert_false(selection.stringify().contains("outcome_summary"))
    assert_false(selection.stringify().contains("evidence_refs"))
    ignore(guidance_wire_write(selection.stringify(indent=2)).wait())
  })
}
