///|
extern "js" fn outcome_native_fixture_read() -> @js.Promise =
  #| async () => {const path=globalThis.process?.env?.MOONBOOK_OUTCOME_UI_FIXTURE;if(!path)return '';const fs=await import('node:fs/promises');return await fs.readFile(path,'utf8');}

///|
extern "js" fn outcome_native_fixture_install(text : String, ui_state : String) =
  #| (text,uiState) => {
  #|   const wire=JSON.parse(text), state={oldFetch:globalThis.fetch,requests:[],continued:false};
  #|   globalThis.__bookOutcomeWire=state;
  #|   globalThis.fetch=async (url,options={})=>{
  #|     state.requests.push({url,method:options.method||'GET',body:options.body?JSON.parse(options.body):null});
  #|     let value;
  #|     if(url==='/api/bookkeeper/lessons/outcome-import')value=wire.imported;
  #|     else if(url==='/api/bookkeeper/lessons/outcome-continue'){state.continued=true;value=wire.continued;}
  #|     else if(url==='/api/bookkeeper/lessons/task-handoff')value=state.continued?wire.reviewed:wire.ready_to_continue;
  #|     else if(url==='/api/bookkeeper/state')value=wire.snapshot;
  #|     else if(url==='/api/bookkeeper/authorities')value={contract_version:'moonbook.bookkeeper.authority.v1',grants:[]};
  #|     else if(url==='./moonbook-ui-state.json')value=JSON.parse(uiState);
  #|     else throw Error('Unexpected request '+url);
  #|     return {ok:true,status:200,text:async()=>JSON.stringify(value)};
  #|   };
  #| }

///|
extern "js" fn outcome_native_fixture_restore() =
  #| () => {globalThis.fetch=globalThis.__bookOutcomeWire.oldFetch;delete globalThis.__bookOutcomeWire;}

///|
extern "js" fn outcome_native_fixture_tick() -> @js.Promise =
  #| () => new Promise(resolve=>setTimeout(resolve,0))

///|
extern "js" fn outcome_native_fixture_requests() -> String =
  #| () => {const requests=globalThis.__bookOutcomeWire.requests;return JSON.stringify({import_request:requests.find(r=>r.url==='/api/bookkeeper/lessons/outcome-import')?.body,continue_request:requests.find(r=>r.url==='/api/bookkeeper/lessons/outcome-continue')?.body,requests});}

///|
extern "js" fn outcome_native_fixture_write(text : String) -> @js.Promise =
  #| async text=>{const output=globalThis.process?.env?.MOONBOOK_OUTCOME_UI_REQUESTS;if(!output)return;const fs=await import('node:fs/promises');await fs.writeFile(output,text);}

///|
test "serialized native outcome fixture drives actual UI commands and accepted review refresh" {
  @js.async_test(async fn() {
    let wire : String = outcome_native_fixture_read().wait().cast()
    if wire.is_empty() {
      return
    }
    let fixture = @json.parse(wire)
    let handoff = lesson_task_field(fixture, "handoff")
    let submission = lesson_task_field(fixture, "submission")
    let original = {
      ..outcome_test_model("deliverable_review_required"),
      outcome_lessons: {
        ..lesson_workspace_fixture(),
        handoff: Some(lesson_task_field(fixture, "initial")),
        outcome_review: {
          ..initial_outcome_review_workspace(),
          binding: Some(handoff),
          preview: Some(outcome_review_preview(submission.stringify()).unwrap()),
        },
      },
    }
    // Only the in-process transport is exercised; no socket or provider is used.
    let minimal_ui : Json = {
      "title": "Native wire fixture",
      "summary": "",
      "status_chips": [],
      "metrics": [],
      "workflow": [],
      "review_queue": [],
      "keeper_items": [],
      "page_families": [],
      "chapters": [],
      "synthesis_preview": "",
      "bookkeeper": {
        "contract_version": "v1",
        "projection_version": "v1",
        "source_path": "fixture",
        "loaded": true,
        "deliverable_acceptance": [],
        "outcome_binding": [],
        "three_gap_findings": [],
        "three_gap_review": [],
        "capability_proposal": [],
        "capability_review": [],
        "mooncode_work_order": [],
        "evaluation": [],
        "adoption": [],
      },
    }
    outcome_native_fixture_install(wire, minimal_ui.stringify())
    defer outcome_native_fixture_restore()
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    let cell = Ref(original)
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
    ignore(dispatch(OutcomeLesson(OutcomeReview(SaveOutcome))))
    ignore(dispatch(OutcomeLesson(OutcomeReview(SaveOutcome))))
    ignore(outcome_native_fixture_tick().wait())
    assert_false(cell.val.outcome_lessons.outcome_review.pending)
    let imported = cell.val.outcome_lessons.handoff.unwrap()
    assert_eq(
      lesson_task_text(outcome_review_items(imported)[0], "state"),
      "deliverable_review_required",
    )
    assert_true(
      saved_lesson_reference(
        lesson_task_field(outcome_review_items(imported)[0], "next_record"),
      )
      is Some(_),
    )
    outcome_test_drafts_kept(original, cell.val)
    // This is the existing review completion notification. The outcome panel
    // only rereads; it never sends or invents the named-human review.
    let accepted : BookkeeperMutationResult = {
      accepted: true,
      idempotent: false,
      event: None,
      review: None,
      issues: [],
      ui_state_path: "fixture",
    }
    ignore(dispatch(BookkeeperMutationFinished(Ok(accepted))))
    ignore(outcome_native_fixture_tick().wait())
    assert_eq(
      lesson_task_text(
        outcome_review_items(cell.val.outcome_lessons.handoff.unwrap())[0],
        "state",
      ),
      "continue_required",
    )
    let reference = lesson_task_field(submission, "submission")
    ignore(dispatch(OutcomeLesson(OutcomeReview(ContinueOutcome(reference)))))
    ignore(dispatch(OutcomeLesson(OutcomeReview(ContinueOutcome(reference)))))
    ignore(outcome_native_fixture_tick().wait())
    assert_eq(
      lesson_task_text(
        outcome_review_items(cell.val.outcome_lessons.handoff.unwrap())[0],
        "state",
      ),
      "assessment_review_required",
    )
    outcome_test_drafts_kept(original, cell.val)
    ignore(dispatch(BookkeeperMutationFinished(Ok(accepted))))
    ignore(outcome_native_fixture_tick().wait())
    let reviewed = cell.val.outcome_lessons.handoff.unwrap()
    assert_eq(
      lesson_task_text(outcome_review_items(reviewed)[0], "state"),
      "reviewed_source_available",
    )
    assert_true(
      lesson_task_field(outcome_review_items(reviewed)[0], "next_record")
      is Null,
    )
    outcome_test_drafts_kept(original, cell.val)
    let html = @rabbita.render_to_string(
      @rabbita.simple_cell(
        model=cell.val,
        update=fn(_ : Msg, old) { old },
        view=outcome_lesson_workspace_view,
      ),
    )
    assert_true(html.contains("Start lesson from this assessment"))
    assert_true(html.contains("Internal task acceptance"))
    let captured = @json.parse(outcome_native_fixture_requests())
    assert_eq(
      lesson_task_field(captured, "import_request"),
      lesson_task_field(fixture, "import_request"),
    )
    assert_eq(
      lesson_task_field(captured, "continue_request"),
      lesson_task_field(fixture, "continue_request"),
    )
    guard lesson_task_field(captured, "requests") is Array(requests) else {
      fail("Expected captured commands")
    }
    assert_eq(
      requests
      .filter(request => {
        lesson_task_text(request, "url") ==
        "/api/bookkeeper/lessons/outcome-import"
      })
      .length(),
      1,
    )
    assert_eq(
      requests
      .filter(request => {
        lesson_task_text(request, "url") ==
        "/api/bookkeeper/lessons/outcome-continue"
      })
      .length(),
      1,
    )
    assert_false(
      requests.any(request => {
        lesson_task_text(request, "url") == "/api/bookkeeper/review"
      }),
    )
    let output : Json = {
      "import_request": lesson_task_field(captured, "import_request"),
      "continue_request": lesson_task_field(captured, "continue_request"),
    }
    ignore(outcome_native_fixture_write(output.stringify(indent=2)).wait())
  })
}
