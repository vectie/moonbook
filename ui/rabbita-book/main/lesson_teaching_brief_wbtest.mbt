///|
fn teaching_test_step(model : Model, action : LessonTeachingBriefMsg) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      TeachingBrief(model.outcome_lessons.teaching_brief.revision, action),
    ),
  )
}

///|
fn teaching_test_model() -> Model {
  let base = notebook_test_model()
  let browser = base.outcome_lessons.browser
  let versions = evolution_test_model().outcome_lessons.history.data.unwrap().versions
  let current = versions[1]
  let marker = "Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n"
  let revision = lesson_task_field(current.lesson.payload, "revision")
  let reason = lesson_task_text(revision, "reason")
  let report = @json.parse(reason[marker.length():].to_owned()) catch {
    _ => panic()
  }
  let cases = lesson_evolution_array(lesson_task_field(report, "cases"))
  let useful = browser_test_set(
    browser_test_set(
      browser_test_set(
        browser_test_set(
          cases[0],
          "name",
          "Answer the schedule stated in a retained source",
        ),
        "input",
        "The retained service sheet says exports run nightly. When do exports run?",
      ),
      "original_output",
      "Source: service sheet. The known export schedule is nightly.",
    ),
    "revised_output",
    "Source: service sheet. The known export schedule is nightly.",
  )
  let adverse = browser_test_set(
    browser_test_set(
      browser_test_set(
        browser_test_set(cases[1], "name", "Avoid inventing an exact time"),
        "input",
        "The same service sheet gives no exact time. Can we promise exports finish at 02:00 UTC?",
      ),
      "original_output",
      "Exports finish at exactly 02:00 UTC.",
    ),
    "revised_output",
    "Source: service sheet. uncertainty: no exact completion time is stated.",
  )
  let payload = browser_test_set(
    current.lesson.payload,
    "revision",
    browser_test_set(
      revision,
      "reason",
      Json::string(
        marker +
        browser_test_set(report, "cases", Json::array([useful, adverse])).stringify(),
      ),
    ),
  )
  let first : LessonBrowserEntry = {
    lesson: { ..current.lesson, payload, },
    review: current.reviews[0],
    selection_review: Json::null(),
  }
  let data = {
    ..browser.data.unwrap(),
    lessons: [first, browser.data.unwrap().lessons[1]],
  }
  {
    ..base,
    outcome_lessons: {
      ..base.outcome_lessons,
      browser: { ..browser, data: Some(data), },
    },
  }
}

///|
fn teaching_test_ready() -> Model {
  let model = teaching_test_model()
  let browser = model.outcome_lessons.browser
  let model = teaching_test_step(
    model,
    Add(browser.request, browser.data.unwrap().lessons[0].lesson.record),
  )
  let model = teaching_test_step(
    model,
    Add(browser.request, browser.data.unwrap().lessons[1].lesson.record),
  )
  let model = teaching_test_step(
    model,
    Objective(
      "Answer evidence-backed customer questions, then propose a pilot size within the recorded scope.",
    ),
  )
  let model = teaching_test_step(
    model,
    Exercise(
      0, "A source says exports run nightly but gives no exact time. Draft a sourced answer that states the missing time explicitly.",
    ),
  )
  teaching_test_step(
    model,
    Exercise(
      1, "The next customer asks to expand the pilot to twelve teams. Current support capacity has not been measured. Draft a scoped recommendation and name the missing observation.",
    ),
  )
}

///|
test "teaching brief builds and edits an ordered sequence without changing accepted work" {
  let base = teaching_test_model()
  let ready = teaching_test_ready()
  let state = ready.outcome_lessons.teaching_brief
  assert_eq(state.draft.items.length(), 2)
  assert_true(lesson_teaching_ready(state, ready.outcome_lessons.browser))
  assert_eq(state.draft.items[0].examples.length(), 2)
  assert_true(state.draft.items[1].examples.is_empty())
  let moved = teaching_test_step(ready, Move(1, -1))
  assert_eq(
    moved.outcome_lessons.teaching_brief.draft.items[0],
    state.draft.items[1],
  )
  assert_eq(
    moved.outcome_lessons.teaching_brief.draft.items[1].exercise,
    state.draft.items[0].exercise,
  )
  let duplicate = teaching_test_step(
    moved,
    Add(0, state.draft.items[0].snapshot.reference),
  )
  assert_eq(
    duplicate.outcome_lessons.teaching_brief.draft,
    moved.outcome_lessons.teaching_brief.draft,
  )
  let removed = teaching_test_step(duplicate, Remove(0))
  assert_eq(removed.outcome_lessons.teaching_brief.draft.items.length(), 1)
  assert_eq(
    ready.outcome_lessons.notebook.draft,
    base.outcome_lessons.notebook.draft,
  )
  assert_eq(ready.outcome_lessons.fields, base.outcome_lessons.fields)
  assert_eq(
    ready.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    base.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
}

///|
test "teaching brief captures attributed cases and excludes private raw payload fields" {
  let ready = teaching_test_ready()
  let draft = ready.outcome_lessons.teaching_brief.draft
  let example = draft.items[0].examples[0]
  assert_eq(
    example.expected_output,
    "Source: service sheet. The known export schedule is nightly.",
  )
  assert_eq(example.source_kind, "contrasting_revision")
  assert_false(example.source_case_id.is_empty())
  let text = ToJson::to_json(draft).stringify()
  assert_false(text.contains("DO NOT EXPORT THIS PRIVATE FIELD"))
  assert_false(text.contains("MUST NEVER EXPORT RAW PAYLOAD"))
  assert_false(text.contains("authority_ref"))
  let markdown = lesson_teaching_markdown(draft)
  assert_true(markdown.contains("source_case_id"))
  assert_true(
    markdown.contains(draft.items[0].snapshot.reference.record_digest),
  )
  assert_true(markdown.contains("not a fresh model run"))
}

///|
test "teaching brief resumes exact authored text only after a fresh matching host load" {
  let ready = teaching_test_step(
    teaching_test_ready(),
    Objective("  海风😀\r\nLearn safely  "),
  )
  let draft = ready.outcome_lessons.teaching_brief.draft
  let text = ToJson::to_json(draft).stringify(indent=2)
  assert_eq(lesson_teaching_decode(text).unwrap(), draft)
  let resumed = teaching_test_step(
    teaching_test_step(
      teaching_test_step(teaching_test_model(), Intake(text)),
      Preview,
    ),
    Restore,
  )
  let state = resumed.outcome_lessons.teaching_brief
  let browser = resumed.outcome_lessons.browser
  assert_eq(state.draft, draft)
  assert_false(lesson_teaching_ready(state, browser))
  assert_true(
    lesson_teaching_ready(state, { ..browser, request: browser.request + 1, }),
  )
  let rechecking = teaching_test_step(resumed, Recheck)
  assert_true(rechecking.outcome_lessons.browser.pending)
  assert_eq(rechecking.outcome_lessons.browser.text, "")
  assert_eq(rechecking.outcome_lessons.teaching_brief.draft, draft)
}

///|
test "teaching brief does not substitute superseded guidance changed examples or reviews" {
  let model = teaching_test_ready()
  let state = model.outcome_lessons.teaching_brief
  let browser = model.outcome_lessons.browser
  let data = browser.data.unwrap()
  for
    changed in [
      { ..browser, pending: true, },
      { ..browser, error: Some("offline"), },
      { ..browser, data: None, },
      { ..browser, data: Some({ ..data, lessons: [data.lessons[1]], }), },
      {
        ..browser,
        data: Some({
          ..data,
          lessons: [
            {
              ..data.lessons[0],
              review: { ..data.lessons[0].review, summary: "changed review", },
            },
            data.lessons[1],
          ],
        }),
      },
    ] {
    assert_false(lesson_teaching_ready(state, changed))
    let blocked = lesson_teaching_brief_update(
        evolution_test_message,
        {
          ..model,
          outcome_lessons: { ..model.outcome_lessons, browser: changed, },
        },
        state.revision,
        Download(true, changed.request),
      ).1
    assert_eq(blocked.outcome_lessons.teaching_brief.draft, state.draft)
    assert_true(
      blocked.outcome_lessons.teaching_brief.notice.contains("export needs"),
    )
  }
  let item = state.draft.items[0]
  let examples = item.examples.copy()
  examples[0] = { ..examples[0], expected_output: "invented", }
  assert_false(lesson_teaching_matches({ ..item, examples, }, browser))
}

///|
test "teaching brief stale callbacks cannot change new drafts or export stale search results" {
  let model = teaching_test_ready()
  let before = model.outcome_lessons.teaching_brief
  let next = teaching_test_step(model, Objective("New objective"))
  for
    action in [
      LessonTeachingBriefMsg::Remove(0),
      LessonTeachingBriefMsg::Move(0, 1),
      LessonTeachingBriefMsg::Restore,
      LessonTeachingBriefMsg::Download(true, 0),
      LessonTeachingBriefMsg::Downloaded(Ok("old download")),
    ] {
    let result = snapshot_test_step(
      next,
      OutcomeLesson(TeachingBrief(before.revision, action)),
    )
    assert_eq(
      result.outcome_lessons.teaching_brief.draft,
      next.outcome_lessons.teaching_brief.draft,
    )
    assert_eq(
      result.outcome_lessons.teaching_brief.notice,
      next.outcome_lessons.teaching_brief.notice,
    )
  }
  let edited = snapshot_test_step(
    model,
    OutcomeLesson(Browser(Edit("different search"))),
  )
  let stale = teaching_test_step(
    edited,
    Add(0, before.draft.items[0].snapshot.reference),
  )
  assert_eq(stale.outcome_lessons.teaching_brief.draft, before.draft)
  let download = teaching_test_step(edited, Download(true, 0))
  assert_true(
    download.outcome_lessons.teaching_brief.notice.contains("export needs"),
  )
}

///|
test "teaching brief import rejects unsupported fields broken references duplicates and limits" {
  let draft = teaching_test_ready().outcome_lessons.teaching_brief.draft
  let json = ToJson::to_json(draft)
  for
    text in [
      "{",
      "{}",
      "a".repeat(1048577),
      browser_test_set(json, "schema", "future").stringify(),
      browser_test_set(json, "authority", true).stringify(),
      ToJson::to_json({ ..draft, objective: "x".repeat(16385), }).stringify(),
      ToJson::to_json({ ..draft, items: draft.items + draft.items, }).stringify(),
      ToJson::to_json({
        ..draft,
        items: [
          {
            ..draft.items[0],
            snapshot: {
              ..draft.items[0].snapshot,
              reference: {
                record_id: "",
                record_version: "1",
                record_digest: "x",
              },
            },
          },
        ],
      }).stringify(),
      ToJson::to_json({
        ..draft,
        items: [
          {
            ..draft.items[0],
            examples: [
              { ..draft.items[0].examples[0], source_kind: "fabricated", },
            ],
          },
        ],
      }).stringify(),
    ] {
    assert_true(lesson_teaching_decode(text) is Err(_))
  }
}

///|
test "teaching brief invalid intake clears preview and prevents detached replacement" {
  let model = teaching_test_ready()
  let text = ToJson::to_json(model.outcome_lessons.teaching_brief.draft).stringify()
  let previewed = teaching_test_step(
    teaching_test_step(model, Intake(text)),
    Preview,
  )
  assert_true(previewed.outcome_lessons.teaching_brief.preview is Some(_))
  let before = previewed.outcome_lessons.teaching_brief
  let invalid = teaching_test_step(previewed, Intake("海".repeat(400000)))
  assert_true(invalid.outcome_lessons.teaching_brief.preview is None)
  assert_eq(invalid.outcome_lessons.teaching_brief.intake, text)
  let stale = snapshot_test_step(
    invalid,
    OutcomeLesson(TeachingBrief(before.revision, Restore)),
  )
  assert_eq(stale.outcome_lessons.teaching_brief.draft, before.draft)
  let oversized = teaching_test_step(previewed, Objective("x".repeat(16385)))
  assert_true(oversized.outcome_lessons.teaching_brief.preview is None)
  assert_eq(oversized.outcome_lessons.teaching_brief.draft, before.draft)
}

///|
test "teaching brief literal Markdown fences preserve authored markup and exact case text" {
  let raw = "  <script>unsafe()</script>\r\n```\n```````\n海风😀  "
  let block = lesson_teaching_block(raw)
  assert_true(block.has_prefix("````````text\n"))
  assert_true(block.contains(raw))
  assert_true(block.has_suffix("\n````````\n"))
  let ready = teaching_test_step(teaching_test_ready(), Exercise(1, raw))
  let html = browser_test_html(ready)
  assert_false(html.contains("<script>unsafe()"))
  assert_true(html.contains("&lt;script&gt;"))
}

///|
test "teaching brief actual rendered buttons add reorder save and restore through controller" {
  let initial = teaching_test_model()
  let entry = initial.outcome_lessons.browser.data.unwrap().lessons[0]
  let added = snapshot_test_step(
    initial,
    evolution_test_click(
      lesson_browser_card(evolution_test_message, initial, entry),
      "Add lesson to agent teaching brief",
    ),
  )
  assert_eq(added.outcome_lessons.teaching_brief.draft.items.length(), 1)
  let ready = teaching_test_ready()
  let view = lesson_teaching_brief_view(evolution_test_message, ready)
  let moved = snapshot_test_step(
    ready,
    evolution_test_click(view, "Move teaching lesson down"),
  )
  assert_eq(
    moved.outcome_lessons.teaching_brief.draft.items[0],
    ready.outcome_lessons.teaching_brief.draft.items[1],
  )
  let save = evolution_test_click(
    lesson_teaching_brief_view(evolution_test_message, moved),
    "Save editable teaching-brief JSON",
  )
  assert_true(save is OutcomeLesson(TeachingBrief(_, Download(false, _))))
  let intake = teaching_test_step(
    moved,
    Intake(
      ToJson::to_json(ready.outcome_lessons.teaching_brief.draft).stringify(),
    ),
  )
  let preview = snapshot_test_step(
    intake,
    evolution_test_click(
      lesson_teaching_brief_view(evolution_test_message, intake),
      "Preview saved teaching brief",
    ),
  )
  let restored = snapshot_test_step(
    preview,
    evolution_test_click(
      lesson_teaching_brief_view(evolution_test_message, preview),
      "Replace open teaching brief with this preview",
    ),
  )
  assert_eq(
    restored.outcome_lessons.teaching_brief.draft,
    ready.outcome_lessons.teaching_brief.draft,
  )
}

///|
test "teaching brief routed downloads preserve production Blob bytes and clean resources" {
  book_test_async(async fn() {
    for markdown in [false, true] {
      let cell = Ref(teaching_test_ready())
      let state = cell.val.outcome_lessons.teaching_brief
      let expected = if markdown {
        lesson_teaching_markdown(state.draft)
      } else {
        ToJson::to_json(state.draft).stringify(indent=2) + "\n"
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
        TeachingBrief(
          state.revision,
          Download(markdown, cell.val.outcome_lessons.browser.request),
        ),
      )
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      ignore(html_brief_tick().wait())
      let receipt : String = html_brief_capture_finish(capture, expected)
        .wait()
        .cast()
      guard @json.parse(receipt)
        is {
          "text": String(text),
          "filename": String(filename),
          "bytesExact": true,
          "clicked": true,
          "removed": true,
          "revoked": true,
          ..
        } else {
        fail("Teaching brief output or cleanup mismatch")
      }
      assert_eq(text, expected)
      assert_eq(
        filename,
        if markdown {
          "moonbook-agent-teaching-brief.md"
        } else {
          "moonbook-agent-teaching-brief.json"
        },
      )
      assert_true(
        cell.val.outcome_lessons.teaching_brief.notice.contains(
          "download requested",
        ),
      )
      assert_eq(cell.val.outcome_lessons.teaching_brief.draft, state.draft)
    }
  })
}

///|
test "teaching brief practical synthetic workflow emits portable teaching material" {
  let ready = teaching_test_ready()
  let draft = ready.outcome_lessons.teaching_brief.draft
  assert_true(
    lesson_teaching_ready(
      ready.outcome_lessons.teaching_brief,
      ready.outcome_lessons.browser,
    ),
  )
  let markdown = lesson_teaching_markdown(draft)
  assert_true(markdown.contains("State uncertainty"))
  assert_true(markdown.contains("capacity-pilot-outcome"))
  assert_true(
    markdown.contains("uncertainty: no exact completion time is stated"),
  )
  println(
    "TEACHING_BRIEF_SAMPLE=" +
    ({ "json": ToJson::to_json(draft), "markdown": markdown } : Json).stringify(),
  )
}

///|
test "teaching brief reports failed downloads without losing authored work" {
  book_test_async(async fn() {
    let cell = Ref(teaching_test_ready())
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
      TeachingBrief(
        state.revision,
        Download(true, cell.val.outcome_lessons.browser.request),
      ),
    )
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    ignore(html_brief_tick().wait())
    let receipt : String = html_brief_capture_finish(
        capture,
        lesson_teaching_markdown(state.draft),
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
    assert_eq(cell.val.outcome_lessons.teaching_brief.draft, state.draft)
  })
}

///|
test "teaching brief enforces twelve lesson envelope and rejects lossy Unicode" {
  let model = teaching_test_ready()
  let draft = model.outcome_lessons.teaching_brief.draft
  let item = draft.items[1]
  let items = Array::makei(13, index => {
    ..item,
    snapshot: {
      ..item.snapshot,
      lesson_id: "lesson-" + index.to_string(),
      reference: {
        ..item.snapshot.reference,
        record_id: "lesson-" + index.to_string(),
      },
    },
  })
  assert_true(
    lesson_teaching_decode(
      ToJson::to_json({ ..draft, items: items[:12].to_array(), }).stringify(),
    )
    is Ok(_),
  )
  assert_true(
    lesson_teaching_decode(ToJson::to_json({ ..draft, items, }).stringify())
    is Err(_),
  )
  assert_false(lesson_teaching_well_formed("{\"objective\":\"\\ud800\"}"))
  assert_true(
    lesson_teaching_well_formed("{\"objective\":\"海风😀\\r\\n\"}"),
  )
}

///|
test "teaching brief remains readable when unsupported case reports cannot be reused" {
  let model = teaching_test_model()
  let browser = model.outcome_lessons.browser
  let entry = browser.data.unwrap().lessons[0]
  let unsupported = {
    ..entry,
    lesson: {
      ..entry.lesson,
      payload: browser_test_set(entry.lesson.payload, "revision", Json::null()),
    },
  }
  let captured = lesson_teaching_capture(unsupported)
  assert_true(captured.examples.is_empty())
  assert_true(captured.example_notice.contains("no supported retained"))
  assert_eq(captured.snapshot.guidance, lesson_notebook_capture(entry).guidance)
}

///|
test "teaching brief exports supported dense backtick guidance without overflowing call arguments" {
  let draft = teaching_test_ready().outcome_lessons.teaching_brief.draft
  let first = draft.items[0]
  let guidance = "`x".repeat(180000)
  let dense = {
    ..draft,
    items: [{ ..first, snapshot: { ..first.snapshot, guidance, }, }],
  }
  assert_true(
    lesson_teaching_decode(ToJson::to_json(dense).stringify()) is Ok(_),
  )
  let output = lesson_teaching_markdown(dense)
  assert_true(output.contains(guidance))
  assert_true(lesson_notebook_fits(output))
  assert_eq(lesson_teaching_block(guidance), "```text\n" + guidance + "\n```\n")
  let mixed = guidance + "````````" + guidance
  assert_true(lesson_teaching_block(mixed).has_prefix("``````````text\n"))
  assert_true(lesson_teaching_block("`").has_prefix("```text\n"))
}
