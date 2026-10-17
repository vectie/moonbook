///|
fn comparison_test_record(version : String) -> BookkeeperRawRecord {
  let record = history_test_record(version)
  { ..record, stage: "DeliverableAcceptance", }
}

///|
fn comparison_test_model() -> Model {
  let state = guidance_ui_ready()
  let matches = ["1", "2"].map(version => {
    let record = comparison_test_record(version)
    {
      "lesson": ToJson::to_json(record),
      "review": history_test_review(record, "Accept"),
      "selection_review": Json::null(),
    }
  })
  {
    ..draft_test_model(),
    outcome_lessons: {
      ..state,
      result: Some({
        "contract_version": "moonbook.outcome-lesson-retrieval.v1",
        "query": lesson_ui_payload(state, "retrieve").unwrap(),
        "matches": matches.to_json(),
        "exclusions": [],
        "activation_authorized": false,
        "external_side_effects_applied": false,
      }),
    },
  }
}

///|
fn comparison_test_change(
  model : Model,
  kind : String,
  reference~ : Json = Json::null(),
  field~ : String = "",
  value~ : String = "",
) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      Comparison(
        lesson_comparison_action(
          model.outcome_lessons,
          kind,
          reference~,
          field~,
          value~,
        ),
      ),
    ),
  )
}

///|
fn comparison_test_ready() -> Model {
  let first = ToJson::to_json(comparison_test_record("1").record)
  let second = ToJson::to_json(comparison_test_record("2").record)
  let model = comparison_test_change(
    comparison_test_model(),
    "add",
    reference=first,
  )
  let model = comparison_test_change(model, "add", reference=second)
  let model = comparison_test_change(
    model,
    "edit",
    field="input",
    value="Same fresh task <&> 東京",
  )
  let model = comparison_test_change(
    model,
    "edit",
    field="checks",
    value="Source:\nCounterexample:",
  )
  let model = comparison_test_change(
    model,
    "edit",
    field="output",
    reference=first,
    value="Source: retained",
  )
  let model = comparison_test_change(
    model,
    "edit",
    field="output",
    reference=second,
    value="Source: retained. Counterexample: checked.",
  )
  comparison_test_change(model, "compare")
}

///|
test "comparison ordinary update connects exact reviewed task results to shared check differences" {
  let model = comparison_test_ready()
  assert_eq(model.outcome_lessons.notice, "")
  let preview = lesson_task_field(model.outcome_lessons.comparison, "preview")
  assert_eq(lesson_task_field(preview, "all_pass_count"), (1 : Json))
  assert_eq(lesson_task_field(preview, "rows"), [
    { "text": "Source:", "passed": [true, true] },
    { "text": "Counterexample:", "passed": [false, true] },
  ])
  let first = ToJson::to_json(comparison_test_record("1").record)
  let second = ToJson::to_json(comparison_test_record("2").record)
  let denied = lesson_comparison_transition(
    model.outcome_lessons,
    lesson_comparison_action(model.outcome_lessons, "use", reference=first),
  )
  assert_true(lesson_task_text(denied, "error").contains("does not pass"))
  let choice = lesson_comparison_transition(
    model.outcome_lessons,
    lesson_comparison_action(model.outcome_lessons, "use", reference=second),
  )
  assert_eq(lesson_task_field(choice, "selection"), second)
  assert_eq(
    model.outcome_lessons.source,
    comparison_test_model().outcome_lessons.source,
  )
  assert_eq(
    model.outcome_lessons.fields,
    comparison_test_model().outcome_lessons.fields,
  )
}

///|
test "comparison newer edits pending requests and clear never overwrite lesson draft or reuse old controls" {
  let model = comparison_test_ready()
  let old = lesson_comparison_action(model.outcome_lessons, "clear")
  let newer = comparison_test_change(
    model,
    "edit",
    field="input",
    value="A newer example",
  )
  let refused = snapshot_test_step(newer, OutcomeLesson(Comparison(old)))
  assert_eq(
    refused.outcome_lessons.comparison,
    newer.outcome_lessons.comparison,
  )
  let pending = {
    ..model,
    outcome_lessons: { ..model.outcome_lessons, pending: true, },
  }
  let refused = comparison_test_change(pending, "clear")
  assert_eq(
    refused.outcome_lessons.comparison,
    model.outcome_lessons.comparison,
  )
  let changed_task = snapshot_test_step(
    model,
    OutcomeLesson(Edit("query-customer", "another-customer")),
  )
  let inspection = lesson_comparison_transition(changed_task.outcome_lessons, {
    "kind": "inspect",
  })
  assert_eq(lesson_task_field(inspection, "preview_current"), false.to_json())
  let cleared = comparison_test_change(changed_task, "clear")
  assert_eq(lesson_task_field(cleared.outcome_lessons.comparison, "entries"), [])
  assert_eq(cleared.outcome_lessons.fields, changed_task.outcome_lessons.fields)
  assert_eq(cleared.outcome_lessons.source, model.outcome_lessons.source)
}

///|
test "comparison ordinary rendered workspace exposes shortlist matrix scope escaping and explicit choice" {
  let model = comparison_test_ready()
  let html = book_test_render_component(
    @rabbita.simple_cell(
      model~,
      update=fn(_message : Msg, old) { old },
      view=outcome_lesson_workspace_view,
    ),
  )
  for
    text in [
      "Add to approach comparison", "Compare reviewed approaches for this task",
      "Same fresh task or example", "Shared required literal text", "Original guidance 1 &lt;&amp;&gt; 中文",
      "named-reviewer", "1/2 literal checks passed", "2/2 literal checks passed",
      "Fail · Counterexample:", "Pass · Counterexample:", "Use this compared guidance for next-task",
      "No winner was selected", "Clear comparison and keep lesson draft", "No model runs here",
      "Scope and exact evidence",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("Original guidance 1 <&>"))
}

///|
fn comparison_test_wire(model : Model, rejected~ : Bool = false) -> Json {
  let state = model.outcome_lessons
  let record = comparison_test_record("2")
  let lesson = lesson_record_value(record).unwrap()
  let review = history_test_review(record, "Accept")
  let handoff = guidance_ui_handoff()
  let query = lesson_ui_payload(state, "retrieve").unwrap()
  let selection : Json = {
    "contract_version": "moonbook.task-guidance-selection.v1",
    "handoff": handoff,
    "query": query,
    "lesson": {
      "reference": ToJson::to_json(record.record),
      "title": record.title,
      "guidance": lesson_task_field(lesson, "guidance"),
      "applicability": lesson_task_field(lesson, "applicability"),
      "invalidation": lesson_task_field(lesson, "invalidation"),
    },
    "review": {
      "receipt": lesson_task_field(review, "receipt"),
      "reviewer_id": "named-reviewer",
      "decided_at": 300,
    },
    "source": {
      "outcome": lesson_task_field(lesson, "outcome"),
      "assessment": lesson_task_field(lesson, "assessment"),
      "assessment_review": lesson_task_field(lesson, "assessment_review"),
    },
    "selection_review": Json::null(),
    "currentness": "legacy_unselected",
    "journal_sequence": 100,
    "applicability_decision_required": true,
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
  {
    "query_response": {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "ok": true,
      "operation": "guidance-query",
      "result": {
        "contract_version": "moonbook.task-guidance-query-readback.v1",
        "handoff": handoff,
        "query": query,
        "activation_authorized": false,
        "external_side_effects_applied": false,
      },
    },
    "selection_response": if rejected {
      {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "ok": false,
        "operation": "guidance-select",
        "error": "The selected lesson was superseded; retrieve again.",
      }
    } else {
      {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "ok": true,
        "operation": "guidance-select",
        "result": selection,
      }
    },
  }
}

///|
async fn comparison_test_return(rejected : Bool) -> Unit {
  let model = comparison_test_ready()
  let handoff = guidance_ui_handoff()
  let browser = guidance_test_browser(handoff.stringify(), 0)
  guidance_wire_install(
    comparison_test_wire(model, rejected~).stringify(),
    browser,
  )
  defer guidance_wire_restore()
  let received : String = task_guidance_receive_on(lesson_receiver_browser())
    .wait()
    .cast()
  assert_eq(received, handoff.stringify())
  let cell = Ref(model)
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
  let reference = ToJson::to_json(comparison_test_record("2").record)
  let choose = OutcomeLesson(
    Comparison(
      lesson_comparison_action(model.outcome_lessons, "use", reference~),
    ),
  )
  ignore(dispatch(choose))
  assert_eq(guidance_wire_sent(), "[]")
  assert_false(cell.val.outcome_lessons.pending)
  ignore(
    dispatch(
      OutcomeLesson(
        TaskGuidance(ConfirmDestination(handoff, "https://proj.example")),
      ),
    ),
  )
  ignore(dispatch(choose))
  ignore(dispatch(choose))
  ignore(outcome_native_fixture_tick().wait())
  assert_false(cell.val.outcome_lessons.pending)
  assert_eq(
    cell.val.outcome_lessons.comparison,
    model.outcome_lessons.comparison,
  )
  if rejected {
    assert_eq(guidance_wire_sent(), "[]")
    assert_true(cell.val.outcome_lessons.notice.contains("superseded"))
  } else {
    assert_true(
      cell.val.outcome_lessons.notice.contains("Proj received"),
      msg=cell.val.outcome_lessons.notice,
    )
    let sent = @json.parse(guidance_wire_sent())
    guard sent is Array(values) && values.length() == 1 else {
      fail("Expected one explicit compared-guidance return")
    }
    assert_eq(
      lesson_task_field(lesson_task_field(values[0], "lesson"), "reference"),
      reference,
    )
    assert_false(values[0].stringify().contains("Counterexample: checked."))
    assert_false(values[0].stringify().contains("all_pass_count"))
    assert_eq(
      lesson_task_field(values[0], "activation_authorized"),
      false.to_json(),
    )
  }
}

///|
test "compared choice reuses confirmed exact Proj wire and host rejection preserves work" {
  // Run both browser-global fixtures serially; Rabbita async_test starts work
  // without blocking other test declarations in this process.
  @js.async_test(async fn() {
    comparison_test_return(false)
    comparison_test_return(true)
  })
}
