///|
extern "js" fn install_lesson_transport_fixture(response : String) -> Unit =
  #| response => {
  #|   globalThis.__lessonCalls = [];
  #|   globalThis.__lessonResponse = response;
  #| }

///|
extern "js" fn restore_lesson_transport_fixture() -> Unit =
  #| () => { delete globalThis.__lessonResponse; delete globalThis.__lessonCalls; }

///|
extern "js" fn lesson_fixture_send(url : String, body : String) -> @js.Promise =
  #| async (url, body) => {
  #|   globalThis.__lessonCalls.push({url, method: "POST", body: JSON.parse(body)});
  #|   return JSON.stringify({ok: true, status: 200, body: globalThis.__lessonResponse});
  #| }

///|
extern "js" fn lesson_transport_calls() -> String =
  #| () => JSON.stringify(globalThis.__lessonCalls)

///|
test "lesson GUI calls the exact existing host route with unchanged task context" {
  @js.async_test(async fn() {
    let query : Json = {
      "contract_version": "moonbook.outcome-lesson-query.v1",
      "target_task": {
        "record_id": "task-2",
        "record_version": "1",
        "record_digest": "sha256:" + "d".repeat(64),
      },
      "conditions": [{ "key": "customer_id", "value": "customer-a" }],
    }
    let result : Json = {
      "contract_version": "moonbook.outcome-lesson-retrieval.v1",
      "query": query,
      "matches": [],
      "exclusions": [],
      "activation_authorized": false,
      "external_side_effects_applied": false,
    }
    let response : Json = {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "operation": "retrieve",
      "ok": true,
      "result": result,
    }
    install_lesson_transport_fixture(response.stringify())
    defer restore_lesson_transport_fixture()
    assert_eq(
      post_outcome_lesson("retrieve", query, send=lesson_fixture_send),
      Ok(result),
    )
    guard @json.parse(lesson_transport_calls())
      is [
        {
          "url": "/api/bookkeeper/lessons/retrieve",
          "method": "POST",
          "body": body,
          ..
        },
      ] else {
      fail("GUI used an unexpected lesson route")
    }
    assert_eq(body, query)
  })
}
