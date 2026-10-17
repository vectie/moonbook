///|
extern "js" fn browser_native_wire_read() -> @js.Promise =
  #| async () => { const path = globalThis.process?.env?.MOONBOOK_BROWSER_WIRE; if (!path) return ''; return await (await import('node:fs/promises')).readFile(path, 'utf8'); }

///|
test "browser native route wire crosses production transport decoder reducer and rendered workspace" {
  book_test_async(async fn() {
    let text : String = browser_native_wire_read().wait().cast()
    if text.is_empty() {
      return
    }
    let wire = @json.parse(text)
    let query = lesson_task_field(wire, "query")
    let response = lesson_task_field(wire, "response")
    let expected = lesson_task_field(response, "result")
    let fixture = history_transport_fixture(response.stringify())
    let result = post_outcome_lesson("browse", query, send=(url, body) => {
      history_transport_send(fixture, url, body)
    })
    assert_eq(result, Ok(expected))
    guard @json.parse(history_transport_calls(fixture))
      is [
        {
          "url": "/api/bookkeeper/lessons/browse",
          "method": "POST",
          "body": sent,
          ..
        },
      ] else {
      fail("Native browse wire used an unexpected route")
    }
    assert_eq(sent, query)
    assert_true(task_guidance_keys(sent, ["contract_version", "text"]))
    let before = {
      ..draft_test_model(),
      outcome_lessons: lesson_workspace_fixture(),
    }
    let edited = snapshot_test_step(
      before,
      OutcomeLesson(Browser(Edit(lesson_task_text(query, "text")))),
    )
    let loading = snapshot_test_step(edited, OutcomeLesson(Browser(Reload)))
    let ready = snapshot_test_step(
      loading,
      OutcomeLesson(
        Browser(
          Finished(loading.outcome_lessons.browser.request, query, result),
        ),
      ),
    )
    assert_false(ready.outcome_lessons.browser.pending)
    assert_true(ready.outcome_lessons.browser.error is None)
    guard ready.outcome_lessons.browser.data is Some(data) else {
      fail("Native browse result was not accepted")
    }
    assert_eq(data.query, query)
    assert_false(data.activation_authorized)
    assert_false(data.external_side_effects_applied)
    assert_false(
      data.lessons.is_empty(),
      msg="Native fixture must contain current reviewed guidance",
    )
    assert_false(
      data.exclusions.is_empty(),
      msg="Native fixture must exercise excluded lesson visibility",
    )
    let html = browser_test_html(ready)
    assert_true(html.contains("Reviewed by "))
    assert_true(html.contains("When this lesson applies"))
    assert_true(html.contains("Do not use when"))
    assert_true(
      html.contains(
        "Other saved lesson records (" +
        data.exclusions.length().to_string() +
        ")",
      ),
    )
    assert_false(html.contains("Use this guidance"))
    assert_eq(ready.outcome_lessons.fields, before.outcome_lessons.fields)
    assert_eq(ready.outcome_lessons.source, before.outcome_lessons.source)
    assert_eq(ready.outcome_lessons.handoff, before.outcome_lessons.handoff)
    assert_true(ready.outcome_lessons.task_guidance.handoff is None)
    assert_eq(ready.outcome_lessons.result, before.outcome_lessons.result)
    assert_eq(ready.outcome_lessons.request, before.outcome_lessons.request)
    assert_eq(ready.bookkeeper_draft, before.bookkeeper_draft)
    let record = data.lessons[0].lesson
    let loaded = {
      ..ready,
      bookkeeper_store: Some({
        ..live_test_store(1),
        records: [record],
        reviews: [data.lessons[0].review],
      }),
    }
    let original = snapshot_test_step(
      loaded,
      OutcomeLesson(Browser(OpenOriginal(record.record))),
    )
    assert_eq(original.selected_bookkeeper_record, Some(record.record))
    let history = snapshot_test_step(
      original,
      OutcomeLesson(Browser(OpenHistory(record.record))),
    )
    assert_true(history.outcome_lessons.pending)
    assert_eq(
      history.outcome_lessons.history.lesson_id,
      lesson_task_text(lesson_record_value(record).unwrap(), "lesson_id"),
    )
    assert_eq(history.outcome_lessons.fields, before.outcome_lessons.fields)
  })
}
