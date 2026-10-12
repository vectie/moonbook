///|
fn browser_test_set(value : Json, key : String, replacement : Json) -> Json {
  guard value is Object(fields) else { panic() }
  let fields = fields.copy()
  fields[key] = replacement
  Json::object(fields)
}

///|
fn browser_test_result(text? : String = "", empty? : Bool = false) -> Json {
  let record = history_test_record("2")
  let lesson = lesson_record_value(record).unwrap()
  let record = {
    ..record,
    stage: "DeliverableAcceptance",
    title: "Evidence comparison <&> 中文",
    payload: {
      "candidate_schema": "outcome_lesson.v1",
      "outcome_lesson": browser_test_set(lesson, "invalidation", [
        { "key": "evidence_state", "value": "superseded" },
      ]),
    },
  }
  {
    "contract_version": "moonbook.outcome-lesson-browser.v1",
    "query": lesson_browser_query(text),
    "lessons": if empty {
      []
    } else {
      [
        {
          "lesson": ToJson::to_json(record),
          "review": history_test_review(record, "Accept"),
          "selection_review": {
            "record_id": "selected-current",
            "record_version": "1",
            "record_digest": "selection-digest",
          },
        },
      ]
    },
    "exclusions": [
      {
        "lesson": ToJson::to_json(history_test_record("pending")),
        "lesson_id": "one-stable-id",
        "reason": "Not accepted by a named human",
      },
      {
        "lesson": ToJson::to_json(history_test_record("1")),
        "lesson_id": "one-stable-id",
        "reason": "Historical version; another reviewed version is current",
      },
      {
        "lesson": ToJson::to_json(history_test_record("rejected")),
        "lesson_id": "one-stable-id",
        "reason": "Rejected review",
      },
    ],
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
fn browser_test_model(text? : String = "", empty? : Bool = false) -> Model {
  let model = history_test_model()
  {
    ..model,
    outcome_lessons: {
      ..model.outcome_lessons,
      browser: {
        ..initial_lesson_browser_workspace(),
        text,
        data: Some(
          parse_lesson_browser_result(
            browser_test_result(text~, empty~),
            lesson_browser_query(text),
          ).unwrap(),
        ),
      },
    },
  }
}

///|
fn browser_test_html(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_message : Msg, old) { old },
      view=lesson_browser_view,
    ),
  )
}

///|
test "reviewed lesson browser is visible before a task and outside technical disclosure" {
  let model = draft_test_model()
  let html = @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_message : Msg, old) { old },
      view=bookkeeper_console,
    ),
  )
  let sections = html.split("id=\"reviewed-lesson-browser\"").to_array()
  assert_eq(sections.length(), 2)
  let before = sections[0]
  assert_eq(
    before.split("<details").count(),
    before.split("</details>").count(),
  )
  let browser = browser_test_html(model)
  for
    label in [
      "Reviewed lessons", "Browse reviewed lessons", "Search reviewed lessons", "No task ID or digest is needed",
      "Text search does not decide", "does not accept a lesson",
    ] {
    assert_true(browser.contains(label), msg=label)
  }
  assert_false(browser.contains("Next task ID"))
  assert_false(browser.contains("Use this guidance"))
  assert_false(browser.contains("Save lesson for review"))
  assert_false(browser.contains("Make and reuse a lesson"))
}

///|
test "reviewed lesson browser shows exact guidance conditions named review and excluded originals" {
  let html = browser_test_html(browser_test_model())
  for
    label in [
      "Evidence comparison &lt;&amp;&gt; 中文", "Original guidance 2 &lt;&amp;&gt; 中文",
      "Reviewed by named-reviewer", "customer_id = customer-a", "decision_kind = vendor-comparison",
      "evidence_state = superseded", "When this lesson applies", "Do not use when",
      "Accepted review", "review-digest-2", "Current-version review", "selection-digest",
      "Inspect original lesson", "Open lesson history", "Other saved lesson records (3)",
      "Not accepted by a named human", "Historical version", "Rejected review", "Reload reviewed lessons",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  assert_false(html.contains("Use this guidance"))
  assert_false(html.contains("Save revision"))
  assert_false(html.contains("Prepare acceptance"))
  assert_false(html.contains("must never leave Book"))
  assert_false(html.contains("Reload Bookkeeper records"))
}

///|
test "browser empty excluded loading error and retry states stay truthful" {
  let empty = browser_test_model(text="Missing", empty=true)
  let html = browser_test_html(empty)
  assert_true(html.contains("No current reviewed lessons match this search"))
  assert_true(html.contains("Other saved lesson records match this search"))
  assert_true(html.contains("Other saved lesson records (3)"))
  let all_empty = browser_test_set(
    browser_test_result(empty=true),
    "exclusions",
    [],
  )
  let initial = {
    ..empty,
    outcome_lessons: {
      ..empty.outcome_lessons,
      browser: {
        ..initial_lesson_browser_workspace(),
        data: Some(
          parse_lesson_browser_result(all_empty, lesson_browser_query("")).unwrap(),
        ),
      },
    },
  }
  assert_true(
    browser_test_html(initial).contains("No current reviewed lessons to browse"),
  )
  let loading = snapshot_test_step(empty, OutcomeLesson(Browser(Reload)))
  assert_true(loading.outcome_lessons.browser.pending)
  assert_true(loading.outcome_lessons.browser.data is None)
  assert_true(
    browser_test_html(loading).contains("Loading reviewed lessons…"),
  )
  assert_false(
    browser_test_html(loading).contains("No current reviewed lessons"),
  )
  let duplicate = snapshot_test_step(loading, OutcomeLesson(Browser(Reload)))
  assert_eq(
    duplicate.outcome_lessons.browser.request,
    loading.outcome_lessons.browser.request,
  )
  let failed = snapshot_test_step(
    loading,
    OutcomeLesson(
      Browser(
        Finished(
          loading.outcome_lessons.browser.request,
          lesson_browser_query("Missing"),
          Err("offline <&>"),
        ),
      ),
    ),
  )
  assert_false(failed.outcome_lessons.browser.pending)
  assert_eq(failed.outcome_lessons.browser.text, "Missing")
  let html = browser_test_html(failed)
  assert_true(html.contains("role=\"alert\""))
  assert_true(html.contains("offline &lt;&amp;&gt;"))
  assert_false(html.contains("No current reviewed lessons"))
  let retried = snapshot_test_step(failed, OutcomeLesson(Browser(Reload)))
  assert_true(retried.outcome_lessons.browser.pending)
  assert_true(retried.outcome_lessons.browser.error is None)
  assert_eq(retried.outcome_lessons.browser.text, "Missing")
}

///|
test "browser late requests cannot replace a new search and preserves task handoff and authored draft" {
  let lesson_state = { ..guidance_ui_ready(), pending: true, request: 83, }
  let model = { ..browser_test_model(), outcome_lessons: lesson_state, }
  let first = snapshot_test_step(model, OutcomeLesson(Browser(Reload)))
  let first_request = first.outcome_lessons.browser.request
  let edited = snapshot_test_step(
    first,
    OutcomeLesson(Browser(Edit("  CUSTOMER-a 中文  "))),
  )
  assert_false(edited.outcome_lessons.browser.pending)
  assert_true(edited.outcome_lessons.browser.data is None)
  let second = snapshot_test_step(edited, OutcomeLesson(Browser(Reload)))
  let late = snapshot_test_step(
    second,
    OutcomeLesson(
      Browser(
        Finished(
          first_request,
          lesson_browser_query(""),
          Ok(browser_test_result()),
        ),
      ),
    ),
  )
  assert_true(late.outcome_lessons.browser.pending)
  assert_true(late.outcome_lessons.browser.data is None)
  let wrong_query = snapshot_test_step(
    late,
    OutcomeLesson(
      Browser(
        Finished(
          second.outcome_lessons.browser.request,
          lesson_browser_query("other"),
          Ok(browser_test_result(text="other")),
        ),
      ),
    ),
  )
  assert_true(wrong_query.outcome_lessons.browser.pending)
  let ready = snapshot_test_step(
    wrong_query,
    OutcomeLesson(
      Browser(
        Finished(
          second.outcome_lessons.browser.request,
          lesson_browser_query("  CUSTOMER-a 中文  "),
          Ok(browser_test_result(text="  CUSTOMER-a 中文  ")),
        ),
      ),
    ),
  )
  assert_true(ready.outcome_lessons.browser.data is Some(_))
  assert_false(ready.outcome_lessons.browser.pending)
  assert_eq(ready.outcome_lessons.fields, model.outcome_lessons.fields)
  assert_eq(ready.outcome_lessons.source, model.outcome_lessons.source)
  assert_eq(ready.outcome_lessons.handoff, model.outcome_lessons.handoff)
  assert_eq(
    ready.outcome_lessons.task_guidance.handoff,
    model.outcome_lessons.task_guidance.handoff,
  )
  assert_eq(
    ready.outcome_lessons.task_guidance.confirmed_origin,
    model.outcome_lessons.task_guidance.confirmed_origin,
  )
  assert_eq(ready.outcome_lessons.result, model.outcome_lessons.result)
  assert_eq(ready.outcome_lessons.request, 83)
  assert_true(ready.outcome_lessons.pending)
  assert_eq(ready.bookkeeper_draft, model.bookkeeper_draft)
  assert_eq(ready.selected_bookkeeper_record, model.selected_bookkeeper_record)
}

///|
test "browser original and history navigation require exact loaded records and preserve local drafts" {
  let model = browser_test_model()
  let reference = history_test_record("2").record
  let selected = snapshot_test_step(
    model,
    OutcomeLesson(Browser(OpenOriginal(reference))),
  )
  assert_eq(selected.selected_bookkeeper_record, Some(reference))
  assert_eq(selected.bookkeeper_draft, model.bookkeeper_draft)
  assert_eq(selected.outcome_lessons.fields, model.outcome_lessons.fields)
  let history = snapshot_test_step(
    selected,
    OutcomeLesson(Browser(OpenHistory(reference))),
  )
  assert_true(history.outcome_lessons.pending)
  assert_eq(history.outcome_lessons.history.lesson_id, "one-stable-id")
  assert_eq(history.outcome_lessons.history.selected, Some(reference))
  assert_eq(history.outcome_lessons.fields, model.outcome_lessons.fields)
  assert_eq(history.outcome_lessons.handoff, model.outcome_lessons.handoff)
  for
    missing in [
      { ..model, bookkeeper_store: None, },
      {
        ..model,
        bookkeeper_store: Some({
          ..model.bookkeeper_store.unwrap(),
          records: [
            {
              ..history_test_record("2"),
              record: { ..reference, record_digest: "different", },
            },
          ],
        }),
      },
      {
        ..model,
        bookkeeper_reads: { ..model.bookkeeper_reads, store_loading: true, },
      },
      {
        ..model,
        bookkeeper_store: Some({
          ..model.bookkeeper_store.unwrap(),
          replay_issues: ["unclean"],
        }),
      },
    ] {
    assert_true(
      browser_test_html(missing).contains("Reload Bookkeeper records"),
    )
    for
      action in [
        LessonBrowserMsg::OpenOriginal(reference),
        LessonBrowserMsg::OpenHistory(reference),
      ] {
      let denied = snapshot_test_step(missing, OutcomeLesson(Browser(action)))
      assert_eq(
        denied.selected_bookkeeper_record,
        missing.selected_bookkeeper_record,
      )
      assert_false(denied.outcome_lessons.pending)
      assert_true(
        denied.outcome_lessons.browser.notice.contains(
          "Reload Bookkeeper records",
        ),
      )
    }
  }
}

///|
test "browser response binds exact read-only query and validates accepted named review" {
  let query = lesson_browser_query("A <&> 中文")
  let result = browser_test_result(text="A <&> 中文")
  let response : BookkeeperBrowserResponse = {
    ok: true,
    status: 200,
    error: None,
    body: (
      {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "ok": true,
        "operation": "browse",
        "result": result,
      } : Json).stringify(),
  }
  assert_eq(
    decode_outcome_lesson_response("browse", query, response),
    Ok(result),
  )
  assert_true(
    decode_outcome_lesson_response("retrieve", query, response) is Err(_),
  )
  assert_true(
    decode_outcome_lesson_response(
      "browse",
      lesson_browser_query("other"),
      response,
    )
    is Err(_),
  )
  assert_true(
    decode_outcome_lesson_response("browse", query, {
      ..response,
      ok: false,
      status: 500,
    })
    is Err(_),
  )
  for
    (key, value) in [
      ("contract_version", "other".to_json()),
      ("activation_authorized", true.to_json()),
      ("external_side_effects_applied", true.to_json()),
      ("lessons", ([{}] : Json)),
      ("exclusions", ([{}] : Json)),
    ] {
    assert_true(
      parse_lesson_browser_result(browser_test_set(result, key, value), query)
      is Err(_),
      msg=key,
    )
  }
  let bad_query = browser_test_set(query, "target_task", {
    "record_id": "hidden-task",
  })
  assert_true(
    parse_lesson_browser_result(
      browser_test_set(result, "query", bad_query),
      bad_query,
    )
    is Err(_),
  )
  guard lesson_task_field(result, "lessons") is [entry] else { fail("fixture") }
  let record = lesson_task_field(entry, "lesson")
  let payload = lesson_task_field(record, "payload")
  let lesson = lesson_task_field(payload, "outcome_lesson")
  for
    bad_record in [
      browser_test_set(record, "stage", "MoonCodeResult"),
      browser_test_set(
        record,
        "payload",
        browser_test_set(
          payload,
          "outcome_lesson",
          browser_test_set(lesson, "applicability", []),
        ),
      ),
      browser_test_set(
        record,
        "payload",
        browser_test_set(
          payload,
          "outcome_lesson",
          browser_test_set(lesson, "applicability", [
            { "key": "scope", "value": "" },
          ]),
        ),
      ),
    ] {
    let bad = browser_test_set(entry, "lesson", bad_record)
    assert_true(
      parse_lesson_browser_result(
        browser_test_set(result, "lessons", [bad]),
        query,
      )
      is Err(_),
    )
  }
  let review = lesson_task_field(entry, "review")
  for
    (key, value) in [
      ("disposition", "Reject".to_json()),
      ("review_complete", false.to_json()),
      ("reviewer_kind", "Agent".to_json()),
      ("stage", "MoonCodeResult".to_json()),
      ("subject", ToJson::to_json(history_test_record("1").record)),
      ("side_effects_applied", true.to_json()),
      ("issues", ["incomplete"].to_json()),
    ] {
    let bad = browser_test_set(
      entry,
      "review",
      browser_test_set(review, key, value),
    )
    assert_true(
      parse_lesson_browser_result(
        browser_test_set(result, "lessons", [bad]),
        query,
      )
      is Err(_),
      msg=key,
    )
  }
  let reviewer = lesson_task_field(review, "reviewer")
  for
    (key, value) in [
      ("reviewer_id", "".to_json()),
      ("authorized", false.to_json()),
    ] {
    let bad_review = browser_test_set(
      review,
      "reviewer",
      browser_test_set(reviewer, key, value),
    )
    let bad = browser_test_set(entry, "review", bad_review)
    assert_true(
      parse_lesson_browser_result(
        browser_test_set(result, "lessons", [bad]),
        query,
      )
      is Err(_),
    )
  }
}

///|
test "browser transport uses only read-only browse endpoint without task metadata" {
  @js.async_test(async fn() {
    let query = lesson_browser_query("  Customer-A 中文  ")
    let result = browser_test_result(text="  Customer-A 中文  ")
    let response : Json = {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "operation": "browse",
      "ok": true,
      "result": result,
    }
    let fixture = history_transport_fixture(response.stringify())
    assert_eq(
      post_outcome_lesson("browse", query, send=(url, body) => {
        history_transport_send(fixture, url, body)
      }),
      Ok(result),
    )
    guard @json.parse(history_transport_calls(fixture))
      is [
        {
          "url": "/api/bookkeeper/lessons/browse",
          "method": "POST",
          "body": body,
          ..
        },
      ] else {
      fail("Browser called an unexpected endpoint")
    }
    assert_eq(body, query)
    assert_true(task_guidance_keys(body, ["contract_version", "text"]))
    assert_eq(lesson_task_text(body, "text"), "  Customer-A 中文  ")
  })
}
