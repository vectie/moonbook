///|
fn evolution_test_model() -> Model {
  let ready = revision_rehearsal_test_step(
    retained_case_test_ready(),
    "edit",
    field="guidance",
    value="Preserve source attribution.\nState uncertainty when the source cannot support a claim.",
  )
  let staged = revision_rehearsal_test_step(
    revision_rehearsal_test_step(ready, "compare"),
    "stage",
  )
  let payload = lesson_history_payload(staged.outcome_lessons.history).unwrap()
  let lesson = browser_test_set(
    browser_test_set(lesson_task_field(payload, "lesson"), "applicability", [
      { "key": "customer_id", "value": "customer-a" },
      { "key": "decision_kind", "value": "evidence-backed-answer" },
      { "key": "source_state", "value": "retained" },
    ]),
    "invalidation",
    [{ "key": "source_state", "value": "superseded" }],
  )
  let revised = {
    ..history_test_record("3"),
    title: "Attribution with explicit uncertainty",
    payload: {
      "candidate_schema": "outcome_lesson.v2",
      "outcome_lesson": lesson,
      "revision": browser_test_set(payload, "lesson", lesson),
      "unrelated_private_field": "DO NOT EXPORT THIS PRIVATE FIELD",
    },
  }
  let history = staged.outcome_lessons.history.data.unwrap()
  let old = history.versions[1]
  let reviews : Array[BookkeeperRawReview] = [
    @json.from_json(history_test_review(revised, "Accept")) catch {
      _ => panic()
    },
  ]
  let data = {
    ..history,
    current: Some(revised.record),
    head: Some(reviews[0].receipt),
    versions: [
      { ..old, current: false, },
      { lesson: revised, reviews, current: true, },
      history.versions[2],
      history.versions[3],
    ],
  }
  {
    ..staged,
    outcome_lessons: {
      ..staged.outcome_lessons,
      history: {
        ..staged.outcome_lessons.history,
        data: Some(data),
        read_ready: true,
      },
    },
  }
}

///|
fn evolution_test_step(model : Model, action : LessonEvolutionMsg) -> Model {
  snapshot_test_step(
    model,
    OutcomeLesson(
      Evolution(
        model.outcome_lessons.request,
        model.outcome_lessons.evolution.revision,
        action,
      ),
    ),
  )
}

///|
fn evolution_test_selected() -> Model {
  let model = evolution_test_model()
  let data = model.outcome_lessons.history.data.unwrap()
  evolution_test_step(
    evolution_test_step(
      model,
      Choose("baseline", data.versions[0].lesson.record),
    ),
    Choose("target", data.versions[1].lesson.record),
  )
}

///|
extern "js" fn evolution_test_message(message : Msg) -> @rabbita.Cmd =
  #| message => ({message})

///|
/// Invokes the actual compiled Rabbita click handler; no browser is simulated.
extern "js" fn evolution_test_click(
  tree : @rabbita.Html,
  label : String,
) -> Msg =
  #| (tree,label) => {
  #|   const map=(m,k)=>m.entries.find(e=>e?.key===k)?.value;
  #|   const walk=n=>[n,...(Array.isArray(n?._2?._0)?n._2._0.flatMap(walk):[])];
  #|   const text=n=>n._1?((n._2?._0||[]).map(text).join('')):typeof n._0==='string'?n._0:'';
  #|   const node=walk(tree).find(n=>n._0==='button'&&text(n)===label);
  #|   if(!node)throw Error('Rendered button not found: '+label);
  #|   const previous=globalThis.MouseEvent; globalThis.MouseEvent=class MouseEvent{};
  #|   try { const messages=[]; map(node._1.handlers,'click')(new MouseEvent(),{self:null,method_table:{method_3:(_,cmd)=>messages.push(cmd.message)}});if(messages.length!==1)throw Error('Expected one routed message');return messages[0]; }
  #|   finally { if(previous===undefined)delete globalThis.MouseEvent;else globalThis.MouseEvent=previous; }
  #| }

///|
test "evolution actual rendered choice swap and download callbacks route through the existing controller" {
  let initial = evolution_test_model()
  let old_view = lesson_evolution_view(evolution_test_message, initial)
  let baseline = snapshot_test_step(
    initial,
    evolution_test_click(old_view, "Use version 2 as baseline"),
  )
  let selected = snapshot_test_step(
    baseline,
    evolution_test_click(
      lesson_evolution_view(evolution_test_message, baseline),
      "Use version 3 as target",
    ),
  )
  let report = lesson_evolution_selected(selected.outcome_lessons).unwrap()
  let ignored = snapshot_test_step(
    selected,
    evolution_test_click(old_view, "Use version rejected as target"),
  )
  assert_eq(lesson_evolution_selected(ignored.outcome_lessons).unwrap(), report)
  let swapped = snapshot_test_step(
    selected,
    evolution_test_click(
      lesson_evolution_view(evolution_test_message, selected),
      "Swap comparison direction",
    ),
  )
  assert_eq(
    swapped.outcome_lessons.evolution.baseline,
    selected.outcome_lessons.evolution.target,
  )
  let download = evolution_test_click(
    lesson_evolution_view(evolution_test_message, swapped),
    "Download printable lesson evolution HTML",
  )
  assert_true(download is OutcomeLesson(Evolution(_, _, Download(true))))
  let pending = snapshot_test_step(swapped, download)
  assert_true(pending.outcome_lessons.evolution.downloading)
  let duplicate = snapshot_test_step(pending, download)
  assert_true(duplicate.outcome_lessons.evolution.downloading)
  assert_eq(
    duplicate.outcome_lessons.evolution.revision,
    pending.outcome_lessons.evolution.revision,
  )
}

///|
test "evolution output rejects oversize exact guidance without truncation" {
  let selected = evolution_test_selected()
  let history = selected.outcome_lessons.history.data.unwrap()
  let old = history.versions[0]
  let record = old.lesson
  let lesson = browser_test_set(
    lesson_record_value(record).unwrap(),
    "guidance",
    Json::string("x".repeat(1048577)),
  )
  let changed = {
    ..record,
    payload: browser_test_set(record.payload, "outcome_lesson", lesson),
  }
  let data = {
    ..history,
    versions: [{ ..old, lesson: changed, }, history.versions[1]],
  }
  assert_true(
    lesson_evolution_report(
      data,
      record.record,
      history.versions[1].lesson.record,
    )
    is Err(error) &&
    error.contains("nothing was truncated"),
  )
  assert_eq(
    lesson_task_text(lesson_record_value(changed).unwrap(), "guidance").length(),
    1048577,
  )
}

///|
test "evolution line alignment preserves exact repeated lines Unicode and CRLF" {
  for
    (before, after) in [
      ("same\nsame\n東京\r\n", "same\nnew\nsame\n東京\r\n"),
      ("", "new"),
      ("drop\n", ""),
      ("same", "same"),
    ] {
    let lines = lesson_evolution_lines(before, after)
    if before == after {
      assert_eq(lines, [{ kind: "unchanged", text: before, }])
    } else {
      assert_eq(
        lines.filter(l => l.kind != "added").map(l => l.text).join("\n"),
        before,
      )
      assert_eq(
        lines.filter(l => l.kind != "removed").map(l => l.text).join("\n"),
        after,
      )
    }
  }
  let large = "exact\n".repeat(257)
  let lines = lesson_evolution_lines(large, "changed")
  assert_eq(lines, [
    { kind: "removed block", text: large, },
    { kind: "added block", text: "changed", },
  ])
}

///|
test "evolution joins real stored rehearsal shapes exact scope and retained input" {
  let model = evolution_test_selected()
  let report = lesson_evolution_selected(model.outcome_lessons).unwrap()
  assert_eq(
    lesson_task_text(report, "schema"),
    "moonbook.lesson-evolution-comparison.v1",
  )
  assert_true(
    lesson_task_text(report, "relationship").contains("explicit predecessor"),
  )
  let scope = lesson_task_field(report, "required_conditions")
  assert_eq(
    lesson_evolution_array(lesson_task_field(scope, "removed")).length(),
    1,
  )
  assert_eq(
    lesson_evolution_array(lesson_task_field(scope, "added")).length(),
    2,
  )
  assert_eq(
    lesson_evolution_array(lesson_task_field(scope, "unchanged")).length(),
    1,
  )
  let cases = lesson_evolution_array(
    lesson_task_field(report, "teaching_cases"),
  )
  assert_eq(cases.length(), 2)
  assert_eq(lesson_task_text(cases[0], "kind"), "changed observation or checks")
  assert_eq(
    lesson_task_text(lesson_task_field(cases[0], "before"), "output"),
    "  Source: known 東京\n exact  ",
  )
  assert_eq(
    lesson_task_text(lesson_task_field(cases[0], "after"), "output"),
    "Source: known new output",
  )
  assert_eq(lesson_task_text(cases[1], "kind"), "only in target")
  assert_eq(
    lesson_task_text(lesson_task_field(report, "target"), "review_status"),
    "accepted",
  )
  assert_false(report.stringify().contains("DO NOT EXPORT THIS PRIVATE FIELD"))
  assert_false(report.stringify().contains("authority_ref"))
  assert_eq(lesson_task_field(report, "model_executed"), false.to_json())
}

///|
test "evolution selection and swap leave accepted stores revision drafts and notebook untouched" {
  let before = evolution_test_model()
  let data = before.outcome_lessons.history.data.unwrap()
  let selected = evolution_test_step(
    evolution_test_step(
      before,
      Choose("baseline", data.versions[0].lesson.record),
    ),
    Choose("target", data.versions[1].lesson.record),
  )
  let swapped = evolution_test_step(selected, Swap)
  assert_eq(
    swapped.outcome_lessons.evolution.baseline,
    selected.outcome_lessons.evolution.target,
  )
  assert_eq(
    swapped.outcome_lessons.evolution.target,
    selected.outcome_lessons.evolution.baseline,
  )
  assert_eq(swapped.outcome_lessons.history.data.unwrap().current, data.current)
  assert_eq(
    lesson_history_payload(swapped.outcome_lessons.history),
    lesson_history_payload(before.outcome_lessons.history),
  )
  assert_eq(
    swapped.outcome_lessons.notebook.draft,
    before.outcome_lessons.notebook.draft,
  )
  assert_eq(swapped.outcome_lessons.fields, before.outcome_lessons.fields)
  assert_eq(
    swapped.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
    before.bookkeeper_store.unwrap().records.map(r => ToJson::to_json(r)),
  )
  let report = lesson_evolution_selected(swapped.outcome_lessons).unwrap()
  assert_true(
    lesson_task_text(report, "relationship").contains("Reader-selected"),
  )
}

///|
test "evolution compares rejected and pending alternatives without promoting them" {
  let model = evolution_test_selected()
  let data = model.outcome_lessons.history.data.unwrap()
  for
    (index, expected) in [(2, "rejected"), (3, "pending or incomplete review")] {
    let chosen = evolution_test_step(
      model,
      Choose("target", data.versions[index].lesson.record),
    )
    let report = lesson_evolution_selected(chosen.outcome_lessons).unwrap()
    let target = lesson_task_field(report, "target")
    assert_eq(lesson_task_text(target, "review_status"), expected)
    assert_eq(lesson_task_field(target, "current_at_load"), false.to_json())
    assert_eq(
      chosen.outcome_lessons.history.data.unwrap().current,
      data.current,
    )
  }
}

///|
test "evolution rejects duplicate missing cross family and identical selections" {
  let model = evolution_test_selected()
  let history = model.outcome_lessons.history.data.unwrap()
  let old = history.versions[0].lesson.record
  let current = history.versions[1].lesson.record
  assert_true(lesson_evolution_report(history, old, old) is Err(_))
  assert_true(
    lesson_evolution_report(
      history,
      { ..old, record_digest: "not-this-exact-record", },
      current,
    )
    is Err(_),
  )
  assert_true(
    lesson_evolution_report(
      { ..history, versions: history.versions + [history.versions[0]], },
      old,
      current,
    )
    is Err(_),
  )
  assert_true(
    lesson_evolution_report(
      { ..history, lesson_id: "another-family", },
      old,
      current,
    )
    is Err(_),
  )
}

///|
test "evolution old rendered actions cannot replace a newer pair or use a failed refresh" {
  let model = evolution_test_selected()
  let state = model.outcome_lessons
  let changed = evolution_test_step(model, Swap)
  let stale = snapshot_test_step(
    changed,
    OutcomeLesson(Evolution(state.request, state.evolution.revision, Swap)),
  )
  assert_eq(
    stale.outcome_lessons.evolution.baseline,
    changed.outcome_lessons.evolution.baseline,
  )
  let loading = snapshot_test_step(changed, OutcomeLesson(RefreshHistory))
  assert_false(loading.outcome_lessons.history.read_ready)
  assert_true(lesson_evolution_selected(loading.outcome_lessons) is Err(_))
  let failed = snapshot_test_step(
    loading,
    OutcomeLesson(
      HistoryFinished(
        loading.outcome_lessons.request,
        "history",
        Err("offline"),
      ),
    ),
  )
  assert_true(lesson_evolution_selected(failed.outcome_lessons) is Err(_))
  let old_click = snapshot_test_step(
    failed,
    OutcomeLesson(
      Evolution(state.request, state.evolution.revision, Download(true)),
    ),
  )
  assert_false(old_click.outcome_lessons.evolution.downloading)
  assert_eq(
    old_click.outcome_lessons.history.data.unwrap().current,
    state.history.data.unwrap().current,
  )
}

///|
test "evolution exact input matching distinguishes whitespace and preserves renamed checks" {
  let before : Json = [
    {
      "name": "Old",
      "input": "Exact input",
      "output": "Old output",
      "required": ["Old"],
      "forbidden": [],
    },
  ]
  let after : Json = [
    {
      "name": "Renamed",
      "input": "Exact input",
      "output": "New output",
      "required": ["New"],
      "forbidden": [],
    },
    {
      "name": "Distinct",
      "input": "Exact input ",
      "output": "Another",
      "required": [],
      "forbidden": [],
    },
  ]
  let rows = lesson_evolution_case_delta(before, after)
  assert_eq(rows.length(), 2)
  assert_eq(lesson_task_text(rows[0], "kind"), "changed observation or checks")
  assert_eq(lesson_task_text(rows[1], "kind"), "only in target")
}

///|
test "evolution malformed retained report stays visible without inventing a case" {
  let model = evolution_test_selected()
  let data = model.outcome_lessons.history.data.unwrap()
  let original = data.versions[1]
  let record = original.lesson
  let revision = lesson_task_field(record.payload, "revision")
  let broken = {
    ..record,
    payload: browser_test_set(
      record.payload,
      "revision",
      browser_test_set(
        revision, "reason", "Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n{",
      ),
    ),
  }
  let capture = lesson_evolution_capture(
    { ..original, lesson: broken, },
    data.current,
  ).unwrap()
  assert_eq(lesson_task_field(capture, "cases"), ([] : Array[Json]).to_json())
  assert_true(
    lesson_task_text(capture, "cases_notice").contains("cannot be read"),
  )
  assert_eq(
    lesson_task_text(capture, "guidance"),
    lesson_task_text(lesson_record_value(record).unwrap(), "guidance"),
  )
}

///|
test "evolution printable output and mounted history include learning content as inert Unicode" {
  let model = evolution_test_selected()
  let report = lesson_evolution_selected(model.outcome_lessons).unwrap()
  let poisoned = browser_test_set(
    report, "lesson_id", "<script>unsafe()</script> 海风😀",
  )
  let html = lesson_evolution_html(poisoned)
  assert_true(html.contains("&lt;script&gt;unsafe()&lt;/script&gt; 海风😀"))
  assert_false(html.contains("<script"))
  assert_true(html.contains("default-src 'none'"))
  for
    text in [
      "Required applicability changes", "Teaching experience across versions", "Source: known new output",
      "Source: uncertainty", "named-reviewer", "Do not use when", "superseded",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  let mounted = history_test_html(model)
  for
    text in [
      "Lesson evolution explorer", "Use version 2 as baseline", "Use version 3 as target",
      "Swap comparison direction", "Download printable lesson evolution HTML", "Download lesson evolution JSON",
    ] {
    assert_true(mounted.contains(text), msg=text)
  }
}

///|
test "evolution actual routed download effects preserve exact output and clean browser resources" {
  book_test_async(async fn() {
    for html in [false, true] {
      let cell = Ref(evolution_test_selected())
      let state = cell.val.outcome_lessons
      let report = lesson_evolution_selected(state).unwrap()
      let expected = if html {
        lesson_evolution_html(report)
      } else {
        report.stringify(indent=2) + "\n"
      }
      let scheduler : LiveTestScheduler = {
        hooks: { url_request: None, url_changed: None, },
      }
      fn dispatch(message : Msg) -> @rabbita.Cmd {
        cell.val = snapshot_test_step(cell.val, message)
        @rabbita.none
      }
      let capture = html_brief_capture_start(false)
      let (command, pending) = outcome_lesson_update(
        dispatch,
        cell.val,
        Evolution(state.request, state.evolution.revision, Download(html)),
      )
      cell.val = pending
      assert_true(cell.val.outcome_lessons.evolution.downloading)
      @cmd.Scheduler::add(scheduler, command)
      ignore(html_brief_tick().wait())
      let receipt : String = html_brief_capture_finish(capture, expected)
        .wait()
        .cast()
      guard @json.parse(receipt)
        is {
          "text": String(downloaded),
          "filename": String(filename),
          "bytesExact": true,
          "clicked": true,
          "removed": true,
          "revoked": true,
          ..
        } else {
        fail("Evolution download bytes or cleanup mismatch")
      }
      assert_eq(downloaded, expected)
      assert_eq(
        filename,
        if html {
          "moonbook-lesson-evolution.html"
        } else {
          "moonbook-lesson-evolution.json"
        },
      )
      assert_false(cell.val.outcome_lessons.evolution.downloading)
      assert_true(
        cell.val.outcome_lessons.evolution.notice.contains("download requested"),
      )
      assert_eq(
        lesson_evolution_selected(cell.val.outcome_lessons).unwrap(),
        report,
      )
    }
  })
}

///|
test "evolution download failure preserves pair and late completion cannot mask a new pair" {
  book_test_async(async fn() {
    let cell = Ref(evolution_test_selected())
    let state = cell.val.outcome_lessons
    let report = lesson_evolution_selected(state).unwrap()
    let scheduler : LiveTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      cell.val = snapshot_test_step(cell.val, message)
      @rabbita.none
    }
    let capture = html_brief_capture_start(true)
    let (command, pending) = outcome_lesson_update(
      dispatch,
      cell.val,
      Evolution(state.request, state.evolution.revision, Download(true)),
    )
    cell.val = pending
    @cmd.Scheduler::add(scheduler, command)
    ignore(html_brief_tick().wait())
    let receipt : String = html_brief_capture_finish(
        capture,
        lesson_evolution_html(report),
      )
      .wait()
      .cast()
    assert_true(
      @json.parse(receipt)
      is { "clicked": false, "removed": true, "revoked": true, .. },
    )
    assert_true(
      cell.val.outcome_lessons.evolution.notice.contains("Download failed"),
    )
    assert_eq(
      lesson_evolution_selected(cell.val.outcome_lessons).unwrap(),
      report,
    )
    let changed = evolution_test_step(cell.val, Swap)
    let late = snapshot_test_step(
      changed,
      OutcomeLesson(
        Evolution(
          state.request,
          state.evolution.revision,
          Downloaded(Ok("old success")),
        ),
      ),
    )
    assert_eq(
      late.outcome_lessons.evolution.notice,
      changed.outcome_lessons.evolution.notice,
    )
  })
}

///|
test "evolution exports concrete saved example progression for standalone reading" {
  let original = evolution_test_selected().outcome_lessons.history.data.unwrap()
  let old = original.versions[0].lesson
  let old_lesson = browser_test_set(
    browser_test_set(
      lesson_record_value(old).unwrap(),
      "lesson_id",
      "synthetic-source-attribution",
    ),
    "guidance",
    "Cite the retained source.\nKeep the quoted claim intact.",
  )
  let old_case = browser_test_set(
    browser_test_set(
      browser_test_set(
        lesson_task_field(old.payload, "rehearsal"),
        "lesson",
        old_lesson,
      ),
      "example_input",
      "The retained service sheet says exports run nightly. When do exports run?",
    ),
    "corrected_output",
    "Source: service sheet. Exports run nightly.",
  )
  let old_case = browser_test_set(old_case, "required_text", [
    "Source:", "nightly",
  ])
  let old_record = {
    ..old,
    title: "Cite the source's stated facts",
    payload: {
      "candidate_schema": "outcome_lesson.rehearsed.v1",
      "outcome_lesson": old_lesson,
      "rehearsal": old_case,
    },
  }
  let target = original.versions[1].lesson
  let target_lesson = browser_test_set(
    lesson_record_value(target).unwrap(),
    "lesson_id",
    "synthetic-source-attribution",
  )
  let revision = lesson_task_field(target.payload, "revision")
  let marker = "Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n"
  let reason = lesson_task_text(revision, "reason")
  let parsed = @json.parse(reason[marker.length():].to_owned())
  let cases = lesson_evolution_array(lesson_task_field(parsed, "cases"))
  let first = browser_test_set(
    browser_test_set(
      browser_test_set(cases[0], "name", "Keep the useful direct answer"),
      "input",
      "The retained service sheet says exports run nightly. When do exports run?",
    ),
    "revised_output",
    "Source: service sheet. Exports run nightly; the sheet does not specify an exact hour.",
  )
  let first = browser_test_set(first, "checks", [
    { "kind": "required", "text": "Source:" },
    { "kind": "required", "text": "nightly" },
  ])
  let second = browser_test_set(
    browser_test_set(
      browser_test_set(cases[1], "name", "Missing precise schedule"),
      "input",
      "The retained service sheet says exports run nightly. Can we promise 02:00 UTC?",
    ),
    "revised_output",
    "Source: service sheet. Uncertainty: an exact hour is not stated. Confirm the schedule before promising 02:00 UTC.",
  )
  let second = browser_test_set(second, "checks", [
    { "kind": "required", "text": "Uncertainty:" },
    { "kind": "forbidden", "text": "guaranteed" },
  ])
  let rationale = "A cited source can still be stretched beyond what it says. Keep useful direct answers while explicitly flagging missing detail before a customer promise."
  let parsed = browser_test_set(
    browser_test_set(parsed, "cases", [first, second]),
    "operator_rationale",
    Json::string(rationale),
  )
  let revised = browser_test_set(
    browser_test_set(revision, "lesson", target_lesson),
    "reason",
    Json::string(marker + parsed.stringify(indent=2)),
  )
  let target_record = {
    ..target,
    payload: {
      "candidate_schema": "outcome_lesson.v2",
      "outcome_lesson": target_lesson,
      "revision": revised,
    },
  }
  let history = {
    ..original,
    lesson_id: "synthetic-source-attribution",
    versions: [
      { ..original.versions[0], lesson: old_record, },
      { ..original.versions[1], lesson: target_record, },
    ],
  }
  let report = lesson_evolution_report(
    history,
    old_record.record,
    target_record.record,
  ).unwrap()
  println(
    "EVOLUTION_SAMPLE=" +
    ({ "json": report, "html": lesson_evolution_html(report) } : Json).stringify(),
  )
}
