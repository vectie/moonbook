///|
test "received task offers outcome import before a reviewed source exists" {
  let model = {
    ..draft_test_model(),
    outcome_lessons: {
      ..lesson_workspace_fixture(),
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
  assert_true(html.contains("Import outcome file"))
  assert_true(html.contains("Internal task acceptance"))
}

///|
test "outcome import transport accepts fresh task readback with exact binding" {
  let readback = outcome_test_readback("deliverable_review_required")
  let payload : Json = {
    "handoff": lesson_task_field(readback, "handoff"),
    "submission": outcome_test_submission(),
  }
  let response : BookkeeperBrowserResponse = {
    ok: true,
    status: 200,
    body: (
      {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "operation": "outcome-import",
        "ok": true,
        "result": readback,
      } : Json).stringify(),
    error: None,
  }
  assert_eq(
    decode_outcome_lesson_response("outcome-import", payload, response),
    Ok(readback),
  )
  assert_true(
    decode_outcome_lesson_response("outcome-continue", payload, response)
    is Err(_),
  )
  assert_true(
    decode_outcome_lesson_response(
      "outcome-import",
      outcome_test_replace(payload, "handoff", Json::null()),
      response,
    )
    is Err(_),
  )
  let wrong = outcome_test_replace(
    payload,
    "submission",
    outcome_test_replace(
      outcome_test_submission(),
      "submission",
      ToJson::to_json(draft_test_record("other").record),
    ),
  )
  assert_true(
    decode_outcome_lesson_response("outcome-import", wrong, response) is Err(_),
  )
  for
    result in [
      outcome_test_replace(readback, "activation_authorized", true),
      outcome_test_replace(readback, "external_side_effects_applied", true),
      outcome_test_replace(readback, "outcome_submissions", []),
    ] {
    let invalid = {
      ..response,
      body: (
        {
          "schema": "moonbook.outcome-lesson-operation.v1",
          "operation": "outcome-import",
          "ok": true,
          "result": result,
        } : Json).stringify(),
    }
    assert_true(
      decode_outcome_lesson_response("outcome-import", payload, invalid)
      is Err(_),
    )
  }
  assert_true(
    decode_outcome_lesson_response("outcome-import", payload, {
      ..response,
      ok: false,
      status: 409,
    })
    is Err(_),
  )
}
