///|
fn practice_test_step(model : Model, action : LessonPracticeMsg) -> Model {
  teaching_test_step(model, Practice(action))
}

///|
fn practice_test_recorded() -> Model {
  let model = practice_test_step(teaching_test_ready(), Start)
  let model = practice_test_step(
    model,
    Learner("Synthetic learner · session one"),
  )
  let model = practice_test_step(
    model,
    Edit(0, "before", "Exports finish at 02:00 UTC."),
  )
  let model = practice_test_step(
    model,
    Edit(
      0, "after", "Source: service sheet. Exports run nightly; the exact completion time is not stated.",
    ),
  )
  let model = practice_test_step(
    model,
    Edit(
      0, "feedback", "The first response invented an exact time. The second states the evidence limit; its correctness still needs review.",
    ),
  )
  let model = practice_test_step(
    model,
    Edit(
      0, "next_practice", "Try a new source that gives a time window, and preserve the distinction between start and finish.",
    ),
  )
  practice_test_step(
    model,
    Edit(
      1, "before", "Measure support demand and staffing before deciding whether to expand to twelve teams.",
    ),
  )
}

///|
test "practice workbook captures a complete fresh exercise sequence and preserves accepted work" {
  let original = teaching_test_ready()
  let recorded = practice_test_recorded()
  let session = recorded.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(session.teaching, original.outcome_lessons.teaching_brief.draft)
  assert_eq(session.observations.length(), 2)
  assert_eq(session.observations[1].after, "")
  assert_eq(
    recorded.outcome_lessons.teaching_brief.draft,
    original.outcome_lessons.teaching_brief.draft,
  )
  assert_eq(recorded.outcome_lessons.fields, original.outcome_lessons.fields)
  assert_eq(
    recorded.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    original.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
}

///|
test "practice workbook requires all exercises fresh guidance and explicit disposal before a new session" {
  let no_task = teaching_test_step(teaching_test_ready(), Exercise(0, " "))
  assert_true(
    practice_test_step(no_task, Start).outcome_lessons.teaching_brief.practice.session
    is None,
  )
  let ready = teaching_test_ready()
  let offline = {
    ..ready,
    outcome_lessons: {
      ..ready.outcome_lessons,
      browser: { ..ready.outcome_lessons.browser, pending: true, },
    },
  }
  assert_true(
    practice_test_step(offline, Start).outcome_lessons.teaching_brief.practice.session
    is None,
  )
  let recorded = practice_test_recorded()
  assert_eq(
    practice_test_step(recorded, Start).outcome_lessons.teaching_brief.practice.session,
    recorded.outcome_lessons.teaching_brief.practice.session,
  )
  let discarded = practice_test_step(recorded, Discard)
  assert_true(discarded.outcome_lessons.teaching_brief.practice.session is None)
  assert_true(
    practice_test_step(discarded, Start).outcome_lessons.teaching_brief.practice.session
    is Some(_),
  )
}

///|
test "practice workbook observations never move when teaching tasks reorder change or disappear" {
  let model = practice_test_recorded()
  let captured = model.outcome_lessons.teaching_brief.practice.session
  let model = teaching_test_step(
    model,
    Exercise(0, "An entirely different task"),
  )
  let model = teaching_test_step(model, Move(0, 1))
  let model = teaching_test_step(model, Remove(1))
  assert_eq(model.outcome_lessons.teaching_brief.practice.session, captured)
  let removed_host = {
    ..model,
    outcome_lessons: {
      ..model.outcome_lessons,
      browser: { ..model.outcome_lessons.browser, data: None, },
    },
  }
  let html = browser_test_html(removed_host)
  assert_true(html.contains("Historical capture is not matched"))
  assert_true(
    lesson_practice_markdown(captured.unwrap()).contains(
      "Exports finish at 02:00 UTC.",
    ),
  )
}

///|
test "practice workbook exact JSON resumes observations without importing accepted knowledge or changing brief" {
  let old = practice_test_step(
    practice_test_recorded(),
    Edit(1, "feedback", "  海风😀\r\n``` quoted  "),
  )
  let session = old.outcome_lessons.teaching_brief.practice.session.unwrap()
  let text = ToJson::to_json(session).stringify(indent=2)
  assert_eq(lesson_practice_decode(text).unwrap(), session)
  let fresh = teaching_test_model()
  let resumed = practice_test_step(
    practice_test_step(practice_test_step(fresh, Intake(text)), Preview),
    Restore,
  )
  assert_eq(
    resumed.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  assert_eq(
    resumed.outcome_lessons.teaching_brief.draft,
    fresh.outcome_lessons.teaching_brief.draft,
  )
  assert_eq(
    resumed.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    fresh.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
}

///|
test "practice workbook rejects unsupported fields mismatched rows bad Unicode and bounded text without loss" {
  let session = practice_test_recorded().outcome_lessons.teaching_brief.practice.session.unwrap()
  let json = ToJson::to_json(session)
  for
    text in [
      "{",
      "{}",
      "a".repeat(1048577),
      browser_test_set(json, "schema", "future").stringify(),
      browser_test_set(json, "model_executed", true).stringify(),
      browser_test_set(json, "learner", Json::string("x".repeat(257))).stringify(),
      ToJson::to_json({ ..session, observations: [], }).stringify(),
      ToJson::to_json({
        ..session,
        teaching: { ..session.teaching, items: [], },
      }).stringify(),
      ToJson::to_json({
        ..session,
        observations: [
          { ..session.observations[0], after: "x".repeat(16385), },
          session.observations[1],
        ],
      }).stringify(),
      json
      .stringify()
      .replace_all(old="Synthetic learner · session one", new="\\ud800"),
    ] {
    assert_true(lesson_practice_decode(text) is Err(_))
  }
  let model = practice_test_recorded()
  let rejected = practice_test_step(model, Edit(0, "before", "x".repeat(16385)))
  assert_eq(
    rejected.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
}

///|
test "practice workbook invalid intake clears preview and stale controls cannot overwrite new observations" {
  let model = practice_test_recorded()
  let text = ToJson::to_json(
    model.outcome_lessons.teaching_brief.practice.session.unwrap(),
  ).stringify()
  let preview = practice_test_step(
    practice_test_step(model, Intake(text)),
    Preview,
  )
  let old_revision = preview.outcome_lessons.teaching_brief.revision
  let changed = practice_test_step(
    preview,
    Edit(0, "feedback", "New observation"),
  )
  assert_true(changed.outcome_lessons.teaching_brief.practice.preview is None)
  for
    action in [
      LessonPracticeMsg::Restore,
      Discard,
      Edit(0, "feedback", "stale"),
      Export(true),
    ] {
    let stale = snapshot_test_step(
      changed,
      OutcomeLesson(TeachingBrief(old_revision, Practice(action))),
    )
    assert_eq(
      stale.outcome_lessons.teaching_brief.practice.session,
      changed.outcome_lessons.teaching_brief.practice.session,
    )
    assert_eq(
      stale.outcome_lessons.teaching_brief.notice,
      changed.outcome_lessons.teaching_brief.notice,
    )
  }
  let oversized = practice_test_step(preview, Intake("海".repeat(400000)))
  assert_true(oversized.outcome_lessons.teaching_brief.practice.preview is None)
  assert_eq(oversized.outcome_lessons.teaching_brief.practice.intake, text)
}

///|
test "practice workbook literal report retains adversarial text and does not claim current source freshness" {
  let literal = " <script>unsafe()</script>\r\n```````\n=1+2 海😀 "
  let model = practice_test_step(
    practice_test_recorded(),
    Edit(0, "after", literal),
  )
  let session = model.outcome_lessons.teaching_brief.practice.session.unwrap()
  let markdown = lesson_practice_markdown(session)
  assert_true(markdown.contains(literal))
  assert_true(markdown.contains("````````text"))
  assert_false(
    markdown.contains("Captures matched loaded reviewed lessons at export"),
  )
  assert_true(markdown.contains("Not recorded."))
  let html = browser_test_html(model)
  assert_false(html.contains("<script>unsafe()"))
  assert_true(html.contains("&lt;script&gt;"))
}

///|
test "practice workbook real rendered controls start resume and request exact reports" {
  let model = teaching_test_ready()
  let started = snapshot_test_step(
    model,
    evolution_test_click(
      lesson_teaching_brief_view(evolution_test_message, model),
      "Start practice from this teaching brief",
    ),
  )
  assert_true(
    started.outcome_lessons.teaching_brief.practice.session is Some(_),
  )
  assert_true(
    evolution_test_click(
      lesson_teaching_brief_view(evolution_test_message, started),
      "Download practice report Markdown",
    )
    is OutcomeLesson(TeachingBrief(_, Practice(Export(true)))),
  )
  let session = practice_test_recorded().outcome_lessons.teaching_brief.practice.session.unwrap()
  let intake = practice_test_step(
    started,
    Intake(ToJson::to_json(session).stringify()),
  )
  let preview = snapshot_test_step(
    intake,
    evolution_test_click(
      lesson_teaching_brief_view(evolution_test_message, intake),
      "Preview practice workbook",
    ),
  )
  let restored = snapshot_test_step(
    preview,
    evolution_test_click(
      lesson_teaching_brief_view(evolution_test_message, preview),
      "Replace local practice with this preview",
    ),
  )
  assert_eq(
    restored.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
}

///|
test "practice workbook production downloads retain actual Blob bytes and release resources" {
  @js.async_test(async fn() {
    for markdown in [false, true] {
      let cell = Ref(practice_test_recorded())
      let state = cell.val.outcome_lessons.teaching_brief
      let session = state.practice.session.unwrap()
      let expected = if markdown {
        lesson_practice_markdown(session)
      } else {
        ToJson::to_json(session).stringify(indent=2) + "\n"
      }
      let scheduler : LiveTestScheduler = {
        hooks: { url_request: None, url_changed: None, },
      }
      fn dispatch(message : Msg) -> @rabbita.Cmd {
        cell.val = snapshot_test_step(cell.val, message)
        @rabbita.none
      }
      let capture = html_brief_capture_start(false)
      let (command, next) = outcome_lesson_update(
        dispatch,
        cell.val,
        TeachingBrief(state.revision, Practice(Export(markdown))),
      )
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      ignore(html_brief_tick().wait())
      let receipt : String = html_brief_capture_finish(capture, expected)
        .wait()
        .cast()
      guard @json.parse(receipt)
        is {
          "filename": String(filename),
          "bytesExact": true,
          "clicked": true,
          "removed": true,
          "revoked": true,
          ..
        } else {
        fail("Practice output mismatch")
      }
      assert_eq(
        filename,
        if markdown {
          "moonbook-agent-practice-workbook.md"
        } else {
          "moonbook-agent-practice-workbook.json"
        },
      )
      assert_eq(
        cell.val.outcome_lessons.teaching_brief.practice.session,
        Some(session),
      )
      assert_true(
        cell.val.outcome_lessons.teaching_brief.notice.contains(
          "download requested",
        ),
      )
    }
  })
}

///|
test "practice workbook production journey emits a reusable synthetic two-lesson report" {
  let model = practice_test_recorded()
  let session = model.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(
    lesson_practice_decode(ToJson::to_json(session).stringify()).unwrap(),
    session,
  )
  let markdown = lesson_practice_markdown(session)
  assert_true(markdown.contains("Next practice / proposed correction"))
  println(
    "PRACTICE_WORKBOOK_SAMPLE=" +
    ({ "json": ToJson::to_json(session), "markdown": markdown } : Json).stringify(),
  )
}

///|
test "practice workbook download failure preserves observations and cleans created resources" {
  @js.async_test(async fn() {
    let cell = Ref(practice_test_recorded())
    let state = cell.val.outcome_lessons.teaching_brief
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      cell.val = snapshot_test_step(cell.val, message)
      @rabbita.none
    }
    let capture = html_brief_capture_start(true)
    let (command, next) = outcome_lesson_update(
      dispatch,
      cell.val,
      TeachingBrief(state.revision, Practice(Export(true))),
    )
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    ignore(html_brief_tick().wait())
    let receipt : String = html_brief_capture_finish(
        capture,
        lesson_practice_markdown(state.practice.session.unwrap()),
      )
      .wait()
      .cast()
    assert_true(
      @json.parse(receipt)
      is { "clicked": false, "removed": true, "revoked": true, .. },
    )
    assert_true(
      cell.val.outcome_lessons.teaching_brief.notice.contains("Download failed"),
    )
    assert_eq(
      cell.val.outcome_lessons.teaching_brief.practice.session,
      state.practice.session,
    )
  })
}
