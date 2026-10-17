///|
fn notebook_test_step(model : Model, action : LessonNotebookMsg) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(Notebook(model.outcome_lessons.notebook.revision, action)),
  )
}

///|
fn notebook_test_model() -> Model {
  let model = browser_test_model()
  let data = model.outcome_lessons.browser.data.unwrap()
  let original = data.lessons[0]
  let first : LessonBrowserEntry = {
    ..original,
    lesson: {
      ..original.lesson,
      title: "Earlier pilot: expand in measured stages",
      payload: {
        "candidate_schema": "outcome_lesson.v1",
        "outcome_lesson": browser_test_set(
          lesson_record_value(original.lesson).unwrap(),
          "guidance",
          "Expand in measured stages when customer readiness and support capacity are both demonstrated.",
        ),
      },
    },
  }
  let lesson = browser_test_set(
    browser_test_set(lesson_record_value(first.lesson).unwrap(), "outcome", {
      "record_id": "capacity-pilot-outcome",
      "record_version": "1",
      "record_digest": "capacity-outcome-digest",
    }),
    "assessment",
    {
      "record_id": "capacity-pilot-assessment",
      "record_version": "1",
      "record_digest": "capacity-assessment-digest",
    },
  )
  let second_record = {
    ..first.lesson,
    record: {
      record_id: "capacity-pilot",
      record_version: "3",
      record_digest: "capacity-exact-3",
    },
    title: "Capacity pilot: narrower scope",
    payload: {
      "candidate_schema": "outcome_lesson.v1",
      "outcome_lesson": browser_test_set(
        browser_test_set(
          browser_test_set(lesson, "lesson_id", "capacity-pilot"),
          "guidance",
          "Keep the next pilot to eight teams until support is measured.",
        ),
        "applicability",
        [{ "key": "decision_kind", "value": "pilot-capacity" }],
      ),
      "private_operator_token": "MUST NEVER EXPORT RAW PAYLOAD",
    },
  }
  let second : LessonBrowserEntry = {
    lesson: second_record,
    review: @json.from_json(history_test_review(second_record, "Accept")) catch {
      _ => panic()
    },
    selection_review: Json::null(),
  }
  let model = {
    ..model,
    outcome_lessons: {
      ..model.outcome_lessons,
      browser: {
        ..model.outcome_lessons.browser,
        data: Some({ ..data, lessons: [first, second], }),
      },
    },
  }
  let model = notebook_test_step(
    model,
    Add(model.outcome_lessons.browser.request, first.lesson.record),
  )
  let model = notebook_test_step(
    model,
    Add(model.outcome_lessons.browser.request, second.lesson.record),
  )
  let model = notebook_test_step(
    model,
    Edit("question", "Should the next pilot expand from eight to twelve teams?"),
  )
  let model = notebook_test_step(
    model,
    Edit(
      "decision", "Keep eight for now. Reconcile the earlier comparison lesson with the later capacity outcome.",
    ),
  )
  let model = notebook_test_step(
    model,
    Edit(
      "uncertainty", "The studies have different scopes. Ask the owner for current support data before deciding.",
    ),
  )
  let model = notebook_test_step(
    model,
    EditItem(
      0, "note", "Earlier comparison practice is useful, but does not establish capacity.",
    ),
  )
  let model = notebook_test_step(model, EditItem(1, "stance", "tension"))
  notebook_test_step(
    model,
    EditItem(
      1, "note", "This pilot experience limits the expansion suggested by the earlier context. Keep both visible.",
    ),
  )
}

///|
test "decision notebook composes distinct experiences without task or accepted knowledge mutations" {
  let original = browser_test_model()
  let model = notebook_test_model()
  let n = model.outcome_lessons.notebook
  assert_eq(n.draft.items.length(), 2)
  assert_eq(n.draft.items[1].stance, "tension")
  assert_true(n.draft.question.contains("eight to twelve"))
  assert_eq(model.outcome_lessons.fields, original.outcome_lessons.fields)
  assert_eq(model.outcome_lessons.handoff, original.outcome_lessons.handoff)
  assert_eq(model.bookkeeper_draft, original.bookkeeper_draft)
  assert_eq(
    model.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    original.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
  assert_eq(
    model.bookkeeper_store.unwrap().reviews.map(r => r.receipt),
    original.bookkeeper_store.unwrap().reviews.map(r => r.receipt),
  )
  assert_false(model.outcome_lessons.pending)
  assert_false(n.draft.to_json().stringify().contains("MUST NEVER EXPORT"))
  assert_true(lesson_notebook_decode(n.draft.to_json().stringify()) is Ok(_))
}

///|
test "decision notebook repeated selection and stale source callbacks do not duplicate or add lessons" {
  let model = notebook_test_model()
  let n = model.outcome_lessons.notebook
  let reference = n.draft.items[0].snapshot.reference
  let repeat = notebook_test_step(
    model,
    Add(model.outcome_lessons.browser.request, reference),
  )
  assert_eq(repeat.outcome_lessons.notebook.draft, n.draft)
  let cleared = notebook_test_step(
    notebook_test_step(model, Remove(1)),
    Remove(0),
  )
  let late = snapshot_test_step(
    cleared,
    OutcomeLesson(
      Notebook(
        n.revision,
        Add(model.outcome_lessons.browser.request, reference),
      ),
    ),
  )
  assert_true(late.outcome_lessons.notebook.draft.items.is_empty())
  let old_request = model.outcome_lessons.browser.request
  let changed = snapshot_test_step(
    cleared,
    OutcomeLesson(Browser(Edit("different"))),
  )
  assert_true(
    notebook_test_step(changed, Add(old_request, reference)).outcome_lessons.notebook.draft.items.is_empty(),
  )
}

///|
test "decision notebook reordering preserves application notes and detached index edits cannot change another experience" {
  let model = notebook_test_model()
  let before = model.outcome_lessons.notebook
  let moved = notebook_test_step(model, Move(1, -1))
  assert_eq(
    moved.outcome_lessons.notebook.draft.items[0],
    before.draft.items[1],
  )
  let late = snapshot_test_step(
    moved,
    OutcomeLesson(Notebook(before.revision, EditItem(0, "note", "WRONG ROW"))),
  )
  assert_eq(
    late.outcome_lessons.notebook.draft,
    moved.outcome_lessons.notebook.draft,
  )
  let removed = notebook_test_step(late, Remove(0))
  assert_eq(removed.outcome_lessons.notebook.draft.items, [
    before.draft.items[0],
  ])
  let invalid_move = notebook_test_step(removed, Move(0, -1))
  assert_eq(
    invalid_move.outcome_lessons.notebook.draft,
    removed.outcome_lessons.notebook.draft,
  )
}

///|
test "decision notebook survives interruption through exact preview and explicit JSON restore" {
  let model = notebook_test_model()
  let draft = model.outcome_lessons.notebook.draft
  let cold = draft_test_model()
  let pasted = notebook_test_step(
    cold,
    Intake(draft.to_json().stringify(indent=2)),
  )
  assert_true(pasted.outcome_lessons.notebook.draft.items.is_empty())
  let preview = notebook_test_step(pasted, Preview)
  assert_eq(preview.outcome_lessons.notebook.preview, Some(draft))
  assert_true(preview.outcome_lessons.notebook.draft.items.is_empty())
  let resumed = notebook_test_step(preview, Restore)
  assert_eq(resumed.outcome_lessons.notebook.draft, draft)
  assert_true(
    lesson_notebook_status(
      draft.items[0].snapshot,
      resumed.outcome_lessons.browser,
    ).has_prefix("Unverified capture"),
  )
  let stale_restore = snapshot_test_step(
    resumed,
    OutcomeLesson(Notebook(preview.outcome_lessons.notebook.revision, Restore)),
  )
  assert_eq(stale_restore.outcome_lessons.notebook.draft, draft)
  let edited = notebook_test_step(
    preview,
    Edit("decision", "Keep my newer work"),
  )
  assert_true(edited.outcome_lessons.notebook.preview is None)
  assert_eq(
    notebook_test_step(edited, Restore).outcome_lessons.notebook.draft.decision,
    "Keep my newer work",
  )
}

///|
test "decision notebook rejects malformed future extra duplicate and oversized archives without replacement" {
  let model = notebook_test_model()
  let draft = model.outcome_lessons.notebook.draft
  let value = draft.to_json()
  for
    bad in [
      "{",
      "{}",
      browser_test_set(value, "schema", "moonbook.decision-notebook.v99").stringify(),
      browser_test_set(value, "activation_authorized", true).stringify(),
      { ..draft, items: draft.items + [draft.items[0]], }.to_json().stringify(),
      { ..draft, question: "x".repeat(16385), }.to_json().stringify(),
      { ..draft, items: [{ ..draft.items[0], stance: "accepted", }], }
      .to_json()
      .stringify(),
      {
        ..draft,
        items: [
          {
            ..draft.items[0],
            snapshot: { ..draft.items[0].snapshot, outcome: Json::null(), },
          },
        ],
      }
      .to_json()
      .stringify(),
    ] {
    assert_true(lesson_notebook_decode(bad) is Err(_))
    let next = notebook_test_step(
      notebook_test_step(model, Intake(bad)),
      Preview,
    )
    assert_eq(next.outcome_lessons.notebook.draft, draft)
    assert_true(next.outcome_lessons.notebook.preview is None)
  }
  assert_false(lesson_notebook_fits("🌙".repeat(262145)))
}

///|
test "decision notebook distinguishes fresh exact changed excluded missing and loading sources without rewriting captures" {
  let model = notebook_test_model()
  let n = model.outcome_lessons.notebook
  let browser = model.outcome_lessons.browser
  let snapshot = n.draft.items[0].snapshot
  assert_true(
    lesson_notebook_status(snapshot, browser).has_prefix(
      "Exact capture matches",
    ),
  )
  assert_true(
    lesson_notebook_status(snapshot, { ..browser, pending: true, }).has_prefix(
      "Unverified capture",
    ),
  )
  let data = browser.data.unwrap()
  let old = {
    ..snapshot,
    reference: { ..snapshot.reference, record_version: "0", },
  }
  assert_true(
    lesson_notebook_status(old, browser).has_prefix("Changed since capture"),
  )
  let no_match = { ..browser, data: Some({ ..data, lessons: [], }), }
  assert_true(
    lesson_notebook_status(snapshot, no_match).has_prefix("Unverified capture"),
  )
  let excluded = {
    ..browser,
    data: Some({
      ..data,
      lessons: [],
      exclusions: [
        {
          lesson: data.lessons[0].lesson,
          lesson_id: snapshot.lesson_id,
          reason: "new review rejected",
        },
      ],
    }),
  }
  assert_true(lesson_notebook_status(snapshot, excluded).contains("no longer"))
  let rechecked = notebook_test_step(model, Recheck)
  assert_true(rechecked.outcome_lessons.browser.pending)
  assert_eq(rechecked.outcome_lessons.browser.text, "")
  assert_eq(rechecked.outcome_lessons.notebook.draft, n.draft)
  assert_eq(
    notebook_test_step(rechecked, Recheck).outcome_lessons.browser.request,
    rechecked.outcome_lessons.browser.request,
  )
}

///|
test "decision notebook mounted UI exposes editing export restoration and scope independently of task workflow" {
  let html = browser_test_html(notebook_test_model())
  for
    label in [
      "Add experience to decision notebook", "Decision question · authored", "Application note · experience 2",
      "Mark as tension", "Move experience up", "Remove experience from notebook",
      "Download editable notebook JSON", "Download offline decision notebook HTML",
      "Resume a downloaded notebook", "Do not use when", "Outcome and assessment",
      "Exact capture matches",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  assert_false(html.contains("MUST NEVER EXPORT"))
}

///|
test "decision notebook offline output preserves contradictory notes exact scope provenance and inert Unicode text" {
  let draft = notebook_test_model().outcome_lessons.notebook.draft
  let draft = {
    ..draft,
    question: "  <script>alert('x')</script> 海风😀\r\n",
    items: [
      { ..draft.items[0], note: "<img src=x onerror=x()>\n<&>", },
      draft.items[1],
    ],
  }
  let html = lesson_notebook_html(draft)
  assert_true(
    html.contains(
      "&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt; 海风😀&#13;\n",
    ),
  )
  assert_true(html.contains("&lt;img src=x onerror=x()&gt;"))
  assert_false(html.contains("<script"))
  assert_false(html.contains("<img"))
  assert_true(html.contains("default-src 'none'"))
  assert_true(html.contains("no consensus is inferred"))
  assert_true(html.contains("tension"))
  assert_true(html.contains("capacity-exact-3"))
  assert_true(html.contains("Do not use when"))
  assert_true(
    html.contains("Captured review labels are not independent verification"),
  )
  assert_eq(lesson_notebook_decode(draft.to_json().stringify()).unwrap(), draft)
  assert_eq(lesson_notebook_html(draft), html)
}

///|
test "decision notebook exports a concrete two-experience planning sample" {
  let draft = notebook_test_model().outcome_lessons.notebook.draft
  println(
    "NOTEBOOK_SAMPLE=" +
    ({ "json": draft.to_json(), "html": lesson_notebook_html(draft) } : Json).stringify(),
  )
  assert_eq(draft.items.length(), 2)
}

///|
test "decision notebook enforces selection and restorable export bounds without silent truncation" {
  let draft = notebook_test_model().outcome_lessons.notebook.draft
  let items = Array::makei(12, index => {
    let item = draft.items[0]
    {
      ..item,
      snapshot: {
        ..item.snapshot,
        reference: {
          ..item.snapshot.reference,
          record_id: "lesson-" + index.to_string(),
        },
      },
    }
  })
  assert_true(
    lesson_notebook_decode({ ..draft, items, }.to_json().stringify()) is Ok(_),
  )
  assert_true(
    lesson_notebook_decode(
      {
        ..draft,
        items: items +
        [
          {
            ..items[0],
            snapshot: {
              ..items[0].snapshot,
              reference: {
                ..items[0].snapshot.reference,
                record_id: "thirteenth",
              },
            },
          },
        ],
      }
      .to_json()
      .stringify(),
    )
    is Err(_),
  )
  assert_false(
    lesson_notebook_reference(
      browser_test_set(
        draft.items[0].snapshot.outcome,
        "unexpected_private_field",
        "x",
      ),
      false,
    ),
  )
  let conditions = Array::makei(18000, index => {
    ({ "key": "scope-" + index.to_string(), "value": "x" } : Json)
  })
  let wide = {
    ..draft,
    items: [
      {
        ..draft.items[0],
        snapshot: {
          ..draft.items[0].snapshot,
          applicability: conditions.to_json(),
        },
      },
    ],
  }
  let compact = wide.to_json().stringify()
  assert_true(lesson_notebook_fits(compact))
  assert_false(lesson_notebook_fits(wide.to_json().stringify(indent=2)))
  assert_true(lesson_notebook_decode(compact) is Err(_))
}

///|
test "decision notebook production effects download exact HTML and JSON bytes with cleanup" {
  @js.async_test(async fn() {
    for html in [false, true] {
      let cell = Ref(notebook_test_model())
      let before = cell.val.outcome_lessons.notebook
      let expected = if html {
        lesson_notebook_html(before.draft)
      } else {
        before.draft.to_json().stringify(indent=2) + "\n"
      }
      let scheduler : LiveTestScheduler = {
        hooks: { url_request: None, url_changed: None, },
      }
      fn dispatch(message : Msg) -> @rabbita.Cmd {
        cell.val = snapshot_test_step(cell.val, message)
        @rabbita.none
      }
      let capture = html_brief_capture_start(false)
      let (command, _) = lesson_notebook_update(
        dispatch,
        cell.val,
        before.revision,
        Download(html),
      )
      @cmd.Scheduler::add(scheduler, command)
      ignore(html_brief_tick().wait())
      let receipt : String = html_brief_capture_finish(capture, expected)
        .wait()
        .cast()
      guard @json.parse(receipt)
        is {
          "text": String(downloaded),
          "mime": String(mime),
          "filename": String(filename),
          "bytesExact": true,
          "clicked": true,
          "removed": true,
          "revoked": true,
          ..
        } else {
        fail("Notebook Blob or cleanup mismatch")
      }
      assert_eq(downloaded, expected)
      assert_eq(
        filename,
        if html {
          "moonbook-decision-notebook.html"
        } else {
          "moonbook-decision-notebook.json"
        },
      )
      assert_eq(
        mime,
        if html {
          "text/html;charset=utf-8"
        } else {
          "application/json;charset=utf-8"
        },
      )
      assert_eq(cell.val.outcome_lessons.notebook.draft, before.draft)
      assert_true(
        cell.val.outcome_lessons.notebook.notice.contains("download requested"),
      )
      if !html {
        assert_eq(lesson_notebook_decode(downloaded).unwrap(), before.draft)
      }
    }
  })
}

///|
test "decision notebook failed download keeps work and late completion cannot mask new edits" {
  @js.async_test(async fn() {
    let cell = Ref(notebook_test_model())
    let before = cell.val.outcome_lessons.notebook
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      cell.val = snapshot_test_step(cell.val, message)
      @rabbita.none
    }
    let capture = html_brief_capture_start(true)
    let (command, _) = lesson_notebook_update(
      dispatch,
      cell.val,
      before.revision,
      Download(true),
    )
    @cmd.Scheduler::add(scheduler, command)
    ignore(html_brief_tick().wait())
    let receipt : String = html_brief_capture_finish(
        capture,
        lesson_notebook_html(before.draft),
      )
      .wait()
      .cast()
    guard @json.parse(receipt)
      is { "clicked": false, "removed": true, "revoked": true, .. } else {
      fail("Failed download cleanup mismatch")
    }
    assert_true(
      cell.val.outcome_lessons.notebook.notice.contains("Download failed"),
    )
    assert_eq(cell.val.outcome_lessons.notebook.draft, before.draft)
    let edited = notebook_test_step(
      cell.val,
      Edit("decision", "Keep the newer decision"),
    )
    let late = snapshot_test_step(
      edited,
      OutcomeLesson(Notebook(before.revision, Downloaded(Ok("old success")))),
    )
    assert_eq(
      late.outcome_lessons.notebook.notice,
      edited.outcome_lessons.notebook.notice,
    )
    assert_eq(
      late.outcome_lessons.notebook.draft,
      edited.outcome_lessons.notebook.draft,
    )
  })
}
