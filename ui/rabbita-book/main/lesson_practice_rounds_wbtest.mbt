///|
fn practice_rounds_test_next(model : Model) -> Model {
  snapshot_test_step(
    model,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, model),
      "Seal this round and start the next",
    ),
  )
}

///|
fn practice_rounds_test_recorded() -> Model {
  let model = teaching_test_step(
    practice_test_recorded(),
    Exercise(
      0, "The service sheet says exports start between 02:00 and 03:00 UTC. Does that establish the finish time?",
    ),
  )
  let model = practice_rounds_test_next(model)
  let model = practice_test_step(
    model,
    Edit(
      0, "before", "Source: service sheet. The start window is 02:00–03:00 UTC; the finish time is not specified.",
    ),
  )
  let model = practice_test_step(
    model,
    Edit(
      0, "feedback", "This response separates the start window from the unknown finish. Test an ambiguous timezone next; this observation is not generalization evidence.",
    ),
  )
  let model = practice_test_step(
    model,
    Edit(
      0, "next_practice", "Use a source that omits its timezone. Keep the uncertainty visible.",
    ),
  )
  let model = teaching_test_step(
    model,
    Exercise(
      0, "The source says exports start at 02:00 but gives no timezone. Can a customer in Tokyo use that as local time?",
    ),
  )
  let model = practice_rounds_test_next(model)
  practice_test_step(
    model,
    Edit(
      0, "before", "Source: service sheet. 02:00 has no stated timezone; confirm it before scheduling in Tokyo.",
    ),
  )
}

///|
test "practice rounds real next control seals prior experience and edits only the new captured round" {
  let before = practice_test_recorded()
  let first = before.outcome_lessons.teaching_brief.practice.session.unwrap()
  let prepared = teaching_test_step(
    before,
    Exercise(0, "A different exact exercise"),
  )
  let stale_edit = OutcomeLesson(
    TeachingBrief(
      prepared.outcome_lessons.teaching_brief.revision,
      Practice(Edit(0, "before", "stale overwrite")),
    ),
  )
  let next = practice_rounds_test_next(prepared)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(session.previous_rounds, [
    {
      learner: first.learner,
      teaching: first.teaching,
      observations: first.observations,
    },
  ])
  assert_eq(session.teaching.items[0].exercise, "A different exact exercise")
  assert_true(
    session.observations.all(o => {
      o.before == "" &&
      o.after == "" &&
      o.feedback == "" &&
      o.next_practice == ""
    }),
  )
  assert_eq(
    snapshot_test_step(next, stale_edit).outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  let edited = practice_test_step(
    practice_test_step(next, Learner("Later learner label")),
    Edit(0, "before", "New experience"),
  )
  let reordered = teaching_test_step(
    teaching_test_step(edited, Move(0, 1)),
    Remove(1),
  )
  let latest = reordered.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(latest.previous_rounds, session.previous_rounds)
  assert_eq(latest.teaching, session.teaching)
  assert_eq(latest.observations[0].before, "New experience")
  assert_eq(
    next.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    before.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
  assert_eq(next.outcome_lessons.fields, before.outcome_lessons.fields)
}

///|
test "practice next round requires recorded experience current next lessons and explicit nonblank tasks" {
  let empty = practice_test_step(teaching_test_ready(), Start)
  assert_eq(
    practice_test_step(empty, NextRound).outcome_lessons.teaching_brief.practice.session,
    empty.outcome_lessons.teaching_brief.practice.session,
  )
  let recorded = practice_test_recorded()
  let blank = teaching_test_step(recorded, Exercise(0, " "))
  let unavailable = {
    ..recorded,
    outcome_lessons: {
      ..recorded.outcome_lessons,
      browser: { ..recorded.outcome_lessons.browser, data: None, },
    },
  }
  for blocked in [blank, unavailable] {
    assert_eq(
      practice_test_step(blocked, NextRound).outcome_lessons.teaching_brief.practice.session,
      blocked.outcome_lessons.teaching_brief.practice.session,
    )
  }
  let retry = practice_test_step(recorded, NextRound)
  assert_eq(
    retry.outcome_lessons.teaching_brief.practice.session.unwrap().teaching,
    recorded.outcome_lessons.teaching_brief.practice.session.unwrap().teaching,
  )
  let mut capped = recorded
  for _ in 0..<11 {
    capped = practice_test_step(capped, NextRound)
    capped = practice_test_step(
      capped,
      Edit(0, "before", "Recorded separately"),
    )
  }
  assert_eq(
    capped.outcome_lessons.teaching_brief.practice.session.unwrap().previous_rounds.length(),
    11,
  )
  assert_eq(
    practice_test_step(capped, NextRound).outcome_lessons.teaching_brief.practice.session,
    capped.outcome_lessons.teaching_brief.practice.session,
  )
  assert_true(browser_test_html(capped).contains("reached 12 rounds"))
}

///|
test "practice rounds migrate exact v1 workbooks and resume v2 progression without accepting knowledge" {
  let old = practice_test_recorded().outcome_lessons.teaching_brief.practice.session.unwrap()
  guard ToJson::to_json(old) is Object(fields) else {
    fail("Expected workbook object")
  }
  let fields = fields.copy()
  fields.remove("previous_rounds")
  fields["schema"] = "moonbook.agent-practice-workbook.v1"
  assert_eq(
    lesson_practice_decode(Json::object(fields).stringify()).unwrap(),
    old,
  )
  fields["previous_rounds"] = [].to_json()
  assert_true(
    lesson_practice_decode(Json::object(fields).stringify()) is Err(_),
  )
  let recorded = practice_rounds_test_recorded()
  let session = recorded.outcome_lessons.teaching_brief.practice.session.unwrap()
  let fresh = teaching_test_model()
  let intake = practice_test_step(
    fresh,
    Intake(ToJson::to_json(session).stringify(indent=2)),
  )
  let preview = snapshot_test_step(
    intake,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, intake),
      "Preview practice workbook",
    ),
  )
  let restored = snapshot_test_step(
    preview,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, preview),
      "Replace local practice with this preview",
    ),
  )
  assert_eq(
    restored.outcome_lessons.teaching_brief.practice.session,
    Some(session),
  )
  assert_eq(
    restored.outcome_lessons.teaching_brief.draft,
    fresh.outcome_lessons.teaching_brief.draft,
  )
  assert_eq(
    restored.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    fresh.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
  let malformed = {
    ..session,
    previous_rounds: [{ ..session.previous_rounds[0], observations: [], }],
  }
  assert_true(
    lesson_practice_decode(ToJson::to_json(malformed).stringify()) is Err(_),
  )
  let future = browser_test_set(ToJson::to_json(session), "unverified_score", 1)
  assert_true(lesson_practice_decode(future.stringify()) is Err(_))
}

///|
test "practice progression renders exact earlier responses gaps and escaped content with round-specific correction controls" {
  let recorded = practice_test_step(
    practice_test_recorded(),
    Edit(0, "feedback", "<script>unsafe()</script> 海😀\n````"),
  )
  let next = practice_rounds_test_next(recorded)
  let html = browser_test_html(next)
  assert_true(html.contains("Round 1 · sealed historical capture"))
  assert_true(html.contains("Current round 2 · editable observations"))
  assert_true(
    html.contains(
      "2 of 2 first responses recorded; 1 after-feedback responses recorded",
    ),
  )
  assert_true(html.contains("Not recorded."))
  assert_true(html.contains("&lt;script&gt;unsafe()&lt;/script&gt;"))
  assert_false(html.contains("<script>unsafe()"))
  let selected = snapshot_test_step(
    next,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, next),
      "Prepare round 1 practice 1 for correction",
    ),
  )
  assert_eq(
    selected.outcome_lessons.teaching_brief.practice.correction.unwrap().round,
    0,
  )
  assert_true(browser_test_html(selected).contains("Selected round 1"))
  let markdown = lesson_practice_markdown(
    next.outcome_lessons.teaching_brief.practice.session.unwrap(),
  )
  assert_true(markdown.contains("## Round 1 · sealed historical capture"))
  assert_true(markdown.contains("## Round 2 · current editable round"))
  assert_true(markdown.contains("<script>unsafe()</script> 海😀"))
}

///|
test "practice sealed round transfers its own first response and task through existing correction path" {
  let ready = practice_correction_test_ready()
  let next = practice_rounds_test_next(
    teaching_test_step(ready, Exercise(0, "New task for round two")),
  )
  let next = practice_test_step(
    next,
    Edit(0, "before", "New response for round two"),
  )
  let mut chosen = snapshot_test_step(
    next,
    evolution_test_click(
      lesson_practice_view(evolution_test_message, next),
      "Prepare round 1 practice 1 for correction",
    ),
  )
  for
    (key, value) in [
      ("kind", "adverse"),
      ("name", "First-round invented hour"),
      ("required", "Source:"),
    ] {
    chosen = practice_correction_test_step(chosen, Edit(key, value))
  }
  let imported = snapshot_test_step(
    chosen,
    evolution_test_click(
      lesson_practice_correction_view(evolution_test_message, chosen),
      "Add first response as original-guidance case",
    ),
  )
  let item = practice_correction_test_cases(imported)[1]
  assert_eq(lesson_task_text(item, "original"), "Exports finish at 02:00 UTC.")
  assert_eq(lesson_task_text(item, "revised"), "")
  let source = lesson_task_field(item, "practice_from")
  assert_eq(lesson_task_field(source, "round_number"), Json::number(1))
  assert_eq(lesson_task_field(source, "model_executed"), false.to_json())
  assert_false(lesson_task_text(item, "input") == "New task for round two")
  let active = practice_correction_test_step(imported, Choose(0))
  assert_eq(
    active.outcome_lessons.teaching_brief.practice.correction.unwrap().round,
    1,
  )
  assert_eq(
    lesson_task_text(
      lesson_practice_correction_case(
        active.outcome_lessons.teaching_brief.practice.session.unwrap(),
        active.outcome_lessons.teaching_brief.practice.correction.unwrap(),
      ),
      "original",
    ),
    "New response for round two",
  )
  assert_eq(
    imported.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    ready.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
  let unavailable = {
    ..chosen,
    outcome_lessons: {
      ..chosen.outcome_lessons,
      history: { ..chosen.outcome_lessons.history, read_ready: false, },
    },
  }
  assert_eq(
    practice_correction_test_cases(
      practice_correction_test_step(unavailable, AddCase),
    ),
    practice_correction_test_cases(chosen),
  )
}

///|
test "practice next-round action invalidates prior correction and replacement controls" {
  let old = practice_correction_test_ready()
  let pending = practice_test_step(
    practice_test_step(
      old,
      Intake(
        ToJson::to_json(
          old.outcome_lessons.teaching_brief.practice.session.unwrap(),
        ).stringify(),
      ),
    ),
    Preview,
  )
  let stale = OutcomeLesson(
    TeachingBrief(
      pending.outcome_lessons.teaching_brief.revision,
      Practice(Restore),
    ),
  )
  let stale_case = OutcomeLesson(
    PracticeCorrection(
      pending.outcome_lessons.teaching_brief.revision,
      pending.outcome_lessons.request,
      lesson_practice_correction_owner(pending),
      AddCase,
    ),
  )
  let next = practice_rounds_test_next(pending)
  assert_true(next.outcome_lessons.teaching_brief.practice.preview is None)
  assert_true(next.outcome_lessons.teaching_brief.practice.correction is None)
  assert_eq(
    snapshot_test_step(next, stale).outcome_lessons.teaching_brief.practice.session,
    next.outcome_lessons.teaching_brief.practice.session,
  )
  assert_eq(
    practice_correction_test_cases(snapshot_test_step(next, stale_case)),
    practice_correction_test_cases(next),
  )
}

///|
test "practice a recaptured lesson version applies only to the next round and cannot relabel an old correction" {
  let original = practice_correction_test_ready()
  let old = original.outcome_lessons.teaching_brief.practice.session.unwrap()
  let version = evolution_test_model().outcome_lessons.history.data.unwrap().versions[0]
  let browser = original.outcome_lessons.browser
  let data = browser.data.unwrap()
  let changed = {
    ..original,
    outcome_lessons: {
      ..original.outcome_lessons,
      browser: {
        ..browser,
        request: browser.request + 1,
        data: Some({
          ..data,
          lessons: [
            {
              lesson: version.lesson,
              review: version.reviews[0],
              selection_review: Json::null(),
            },
            data.lessons[1],
          ],
        }),
      },
    },
  }
  assert_eq(
    practice_test_step(changed, NextRound).outcome_lessons.teaching_brief.practice.session,
    Some(old),
  )
  let recaptured = teaching_test_step(
    teaching_test_step(changed, Remove(0)),
    Add(changed.outcome_lessons.browser.request, version.lesson.record),
  )
  let recaptured = teaching_test_step(
    recaptured,
    Exercise(1, "Practice with the explicitly reselected guidance version"),
  )
  let next = practice_rounds_test_next(recaptured)
  let session = next.outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(session.previous_rounds[0].teaching, old.teaching)
  assert_eq(session.teaching.items[1].snapshot.reference, version.lesson.record)
  assert_false(
    session.teaching.items[1].snapshot.reference ==
    old.teaching.items[0].snapshot.reference,
  )
  let chosen = practice_correction_test_step(next, ChooseRound(0, 0))
  assert_eq(
    lesson_task_field(
      lesson_practice_correction_case(
        session,
        chosen.outcome_lessons.teaching_brief.practice.correction.unwrap(),
      ),
      "practice_from",
    ),
    lesson_practice_correction_source(old, 0),
  )
  let blocked = practice_correction_test_step(chosen, AddCase)
  assert_eq(
    practice_correction_test_cases(blocked),
    practice_correction_test_cases(chosen),
  )
  assert_true(blocked.outcome_lessons.teaching_brief.notice.contains("Recheck"))
}

///|
test "practice multiple rounds production JSON and Markdown downloads retain all exact experience" {
  book_test_async(async fn() {
    for markdown in [false, true] {
      let cell = Ref(practice_rounds_test_recorded())
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
      assert_true(
        @json.parse(receipt)
        is {
          "bytesExact": true,
          "clicked": true,
          "removed": true,
          "revoked": true,
          ..
        },
      )
      assert_eq(
        cell.val.outcome_lessons.teaching_brief.practice.session,
        Some(session),
      )
    }
  })
}

///|
test "practice three-round synthetic journey emits reusable progression sample" {
  let session = practice_rounds_test_recorded().outcome_lessons.teaching_brief.practice.session.unwrap()
  assert_eq(session.previous_rounds.length(), 2)
  assert_eq(
    lesson_practice_decode(ToJson::to_json(session).stringify()).unwrap(),
    session,
  )
  let markdown = lesson_practice_markdown(session)
  assert_true(markdown.contains("Exports finish at 02:00 UTC."))
  assert_true(markdown.contains("02:00–03:00 UTC"))
  assert_true(markdown.contains("confirm it before scheduling in Tokyo"))
  println(
    "PRACTICE_ROUNDS_SAMPLE=" +
    ({ "json": ToJson::to_json(session), "markdown": markdown } : Json).stringify(),
  )
}
