///|
fn history_test_record(version : String) -> BookkeeperRawRecord {
  let draft = lesson_ui_payload(lesson_workspace_fixture(), "prepare").unwrap()
  guard draft is Object(values) else { panic() }
  let fields = values.copy()
  fields["lesson_version"] = Json::string(version)
  fields["guidance"] = Json::string(
    "Original guidance " + version + " <&> 中文\nSecond line",
  )
  {
    ..draft_test_record("one-stable-id"),
    record: {
      record_id: "one-stable-id",
      record_version: version,
      record_digest: "exact-" + version,
    },
    title: "Lesson " + version,
    payload: {
      "candidate_schema": "outcome_lesson.v1",
      "outcome_lesson": Json::object(fields),
    },
  }
}

///|
fn history_test_review(
  record : BookkeeperRawRecord,
  disposition : String,
) -> Json {
  let grant = live_test_registry("reviewer").grants[0]
  let reference : Json = {
    "record_id": "review-" + record.record.record_version,
    "record_version": "1",
    "record_digest": "review-digest-" + record.record.record_version,
  }
  {
    "contract_version": "moonbook.bookkeeper.store.v1",
    "mutation": reference,
    "receipt": reference,
    "stage": record.stage,
    "subject": ToJson::to_json(record.record),
    "requested": disposition,
    "disposition": disposition,
    "reviewer_kind": "Human",
    "reviewer": {
      "grant": ToJson::to_json(grant.grant),
      "reviewer_id": "named-reviewer",
      "authority_ref": grant.authority_ref,
      "authorized": true,
      "evidence_refs": [],
    },
    "evidence_refs": [],
    "summary": "Reviewed " + disposition,
    "decided_at": 300,
    "issues": [],
    "review_complete": disposition != "Revise",
    "side_effects_applied": false,
  }
}

///|
fn history_test_value(multiple? : Bool = false) -> Json {
  let old = history_test_record("1")
  let current = history_test_record("2")
  let rejected = history_test_record("rejected")
  let pending = history_test_record("pending")
  let review1 = history_test_review(old, "Accept")
  let review2 = history_test_review(current, "Accept")
  {
    "contract_version": "moonbook.outcome-lesson-history.v1",
    "lesson_id": "one-stable-id",
    "current": if multiple {
      Json::null()
    } else {
      ToJson::to_json(current.record)
    },
    "head": if multiple {
      Json::null()
    } else {
      lesson_task_field(review2, "receipt")
    },
    "accepted_reviews": [
      lesson_task_field(review1, "receipt"),
      lesson_task_field(review2, "receipt"),
    ],
    "versions": [
      { "lesson": ToJson::to_json(old), "reviews": [review1], "current": false },
      {
        "lesson": ToJson::to_json(current),
        "reviews": [review2],
        "current": !multiple,
      },
      {
        "lesson": ToJson::to_json(rejected),
        "reviews": [history_test_review(rejected, "Reject")],
        "current": false,
      },
      {
        "lesson": ToJson::to_json(pending),
        "reviews": [history_test_review(pending, "Revise")],
        "current": false,
      },
    ],
    "selections": [],
  }
}

///|
fn history_test_model(multiple? : Bool = false) -> Model {
  let value = history_test_value(multiple~)
  let data = parse_lesson_history(value).unwrap()
  let base = draft_test_model()
  let reviews : Array[BookkeeperRawReview] = []
  for version in data.versions {
    for review in version.reviews {
      reviews.push(review)
    }
  }
  {
    ..base,
    selected_bookkeeper_record: Some(data.versions[0].lesson.record),
    bookkeeper_store: Some({
      ..live_test_store(1),
      records: data.versions.map(version => version.lesson),
      reviews,
    }),
    outcome_lessons: {
      ..lesson_workspace_fixture(),
      handoff: Some({ "task": "kept" }),
      history: {
        ..initial_lesson_history_workspace(),
        lesson_id: data.lesson_id,
        data: Some(data),
        selected: Some(data.versions[0].lesson.record),
      },
    },
  }
}

///|
fn history_test_change(model : Model, operation : String) -> Model {
  let model = if operation == "revise" &&
    model.outcome_lessons.history.data is Some(data) &&
    data.current is Some(current) {
    snapshot_test_step(model, OutcomeLesson(ChooseHistoryVersion(current)))
  } else {
    model
  }
  let started = snapshot_test_step(
    model,
    OutcomeLesson(StartHistoryChange(operation)),
  )
  let reason = snapshot_test_step(
    started,
    OutcomeLesson(EditHistory("reason", "Reason <&> 中文")),
  )
  if operation == "revise" {
    let version = snapshot_test_step(
      reason,
      OutcomeLesson(EditHistory("version", "3")),
    )
    snapshot_test_step(
      version,
      OutcomeLesson(
        EditHistory(
          "guidance", "  Revised exact guidance <&> 中文\nNext line  ",
        ),
      ),
    )
  } else {
    reason
  }
}

///|
test "history revision keeps original evidence full scope manual and Proj drafts" {
  let initial = history_test_model()
  let changed = history_test_change(initial, "revise")
  let payload = lesson_history_payload(changed.outcome_lessons.history).unwrap()
  let original = lesson_record_value(history_test_record("2")).unwrap()
  let draft = lesson_task_field(payload, "lesson")
  for
    key in [
      "lesson_id", "outcome", "assessment", "assessment_review", "applicability",
      "invalidation",
    ] {
    assert_eq(
      lesson_task_field(draft, key),
      lesson_task_field(original, key),
      msg=key,
    )
  }
  assert_eq(lesson_task_text(draft, "lesson_version"), "3")
  assert_eq(
    lesson_task_text(draft, "guidance"),
    "  Revised exact guidance <&> 中文\nNext line  ",
  )
  assert_eq(
    lesson_task_field(payload, "supersedes"),
    ToJson::to_json(history_test_record("2").record),
  )
  assert_eq(changed.outcome_lessons.fields, initial.outcome_lessons.fields)
  assert_eq(changed.outcome_lessons.source, initial.outcome_lessons.source)
  assert_eq(changed.outcome_lessons.handoff, initial.outcome_lessons.handoff)
  let again = snapshot_test_step(
    changed,
    OutcomeLesson(StartHistoryChange("revise")),
  )
  assert_eq(
    lesson_history_payload(again.outcome_lessons.history).unwrap(),
    payload,
  )
  let selected = snapshot_test_step(
    changed,
    OutcomeLesson(ChooseHistoryVersion(history_test_record("1").record)),
  )
  assert_eq(
    lesson_history_payload(selected.outcome_lessons.history).unwrap(),
    payload,
  )
  let existing = snapshot_test_step(
    changed,
    OutcomeLesson(EditHistory("version", "2")),
  )
  assert_true(
    lesson_history_payload(existing.outcome_lessons.history) is Err(_),
  )
}

///|
test "history save duplicate clicks transport failures and late wrong-operation replies preserve ownership" {
  let changed = history_test_change(history_test_model(), "revise")
  let payload = lesson_history_payload(changed.outcome_lessons.history).unwrap()
  let saving = snapshot_test_step(changed, OutcomeLesson(SubmitHistoryChange))
  assert_true(saving.outcome_lessons.pending)
  let duplicate = snapshot_test_step(saving, OutcomeLesson(SubmitHistoryChange))
  assert_eq(duplicate.outcome_lessons.request, saving.outcome_lessons.request)
  let edited = snapshot_test_step(
    saving,
    OutcomeLesson(EditHistory("guidance", "lost")),
  )
  assert_eq(
    lesson_history_payload(edited.outcome_lessons.history).unwrap(),
    payload,
  )
  let wrong = lesson_history_finished(
    saving.outcome_lessons,
    saving.outcome_lessons.request,
    "history",
    Ok(history_test_value()),
  )
  assert_true(wrong.pending)
  let failed = lesson_history_finished(
    saving.outcome_lessons,
    saving.outcome_lessons.request,
    "revise",
    Err("timeout"),
  )
  assert_false(failed.pending)
  assert_eq(lesson_history_payload(failed.history).unwrap(), payload)
  let newer = snapshot_test_step(
    { ..changed, outcome_lessons: failed, },
    OutcomeLesson(EditHistory("reason", "New explanation")),
  )
  let late = lesson_history_finished(
    newer.outcome_lessons,
    saving.outcome_lessons.request,
    "revise",
    Ok({ "accepted": true }),
  )
  assert_true(late.history.result is None)
  assert_eq(
    lesson_change_field(late.history.change.unwrap(), "reason"),
    "New explanation",
  )
}

///|
test "history restore saves separate stable selection proposal and rejects unaccepted target" {
  let old = history_test_model()
  assert_false(lesson_history_can_revise(old.outcome_lessons.history))
  let refused = snapshot_test_step(
    old,
    OutcomeLesson(StartHistoryChange("revise")),
  )
  assert_true(refused.outcome_lessons.history.change is None)
  assert_true(refused.outcome_lessons.history.notice.contains("not current"))
  assert_true(
    history_test_html(old).contains("choose or restore it as current"),
  )
  let legacy = history_test_model(multiple=true)
  assert_true(lesson_history_can_revise(legacy.outcome_lessons.history))
  assert_true(
    snapshot_test_step(legacy, OutcomeLesson(StartHistoryChange("revise"))).outcome_lessons.history.change
    is Some(_),
  )
  let changed = history_test_change(history_test_model(), "select")
  let payload = lesson_history_payload(changed.outcome_lessons.history).unwrap()
  assert_eq(
    lesson_task_text(payload, "contract_version"),
    "moonbook.outcome-lesson-selection.v1",
  )
  assert_eq(
    lesson_task_field(payload, "target"),
    ToJson::to_json(history_test_record("1").record),
  )
  assert_eq(
    lesson_task_field(payload, "expected_head"),
    lesson_task_field(history_test_value(), "head"),
  )
  assert_eq(
    lesson_task_field(payload, "accepted_reviews"),
    lesson_task_field(history_test_value(), "accepted_reviews"),
  )
  assert_true(lesson_task_field(payload, "lesson") is Null)
  assert_false(lesson_task_text(payload, "selection_id").is_blank())
  assert_eq(
    lesson_history_payload(changed.outcome_lessons.history).unwrap(),
    payload,
  )
  for version in ["rejected", "pending"] {
    let selected = snapshot_test_step(
      history_test_model(),
      OutcomeLesson(ChooseHistoryVersion(history_test_record(version).record)),
    )
    let started = snapshot_test_step(
      selected,
      OutcomeLesson(StartHistoryChange("select")),
    )
    assert_true(started.outcome_lessons.history.change is None)
  }
  let current = snapshot_test_step(
    history_test_model(),
    OutcomeLesson(ChooseHistoryVersion(history_test_record("2").record)),
  )
  assert_true(
    snapshot_test_step(current, OutcomeLesson(StartHistoryChange("select"))).outcome_lessons.history.change
    is None,
  )
}

///|
test "refreshed history never rebases a captured draft silently and legacy ambiguity stays explicit" {
  let changed = history_test_change(history_test_model(multiple=true), "select")
  let payload = lesson_history_payload(changed.outcome_lessons.history).unwrap()
  assert_true(lesson_task_field(payload, "expected_head") is Null)
  let loading = snapshot_test_step(changed, OutcomeLesson(RefreshHistory))
  let fresh = lesson_history_finished(
    loading.outcome_lessons,
    loading.outcome_lessons.request,
    "history",
    Ok(history_test_value()),
  )
  assert_eq(fresh.history.change.unwrap().expected_head, None)
  assert_eq(
    lesson_change_field(fresh.history.change.unwrap(), "reason"),
    "Reason <&> 中文",
  )
  assert_true(lesson_history_payload(fresh.history) is Err(_))
  let refused = snapshot_test_step(
    { ..changed, outcome_lessons: fresh, },
    OutcomeLesson(SubmitHistoryChange),
  )
  assert_false(refused.outcome_lessons.pending)
  let closed = snapshot_test_step(changed, OutcomeLesson(DiscardHistoryChange))
  assert_true(closed.outcome_lessons.history.change is None)
  assert_eq(closed.outcome_lessons.fields, changed.outcome_lessons.fields)
}

///|
fn history_test_html(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=lesson_history_workspace_view,
    ),
  )
}

///|
test "real native accepted revision rollback history decodes and serializes exact revision and selection requests" {
  let value = @json.parse(history_native_fixture_text())
  let wire : Json = {
    "schema": "moonbook.outcome-lesson-operation.v1",
    "ok": true,
    "operation": "history",
    "result": value,
  }
  let response : BookkeeperBrowserResponse = {
    ok: true,
    status: 200,
    body: wire.stringify(),
    error: None,
  }
  assert_eq(
    decode_outcome_lesson_response(
      "history",
      { "lesson_id": "research-brief-lesson" },
      response,
    ),
    Ok(value),
  )
  let data = parse_lesson_history(value).unwrap()
  assert_eq(data.versions.length(), 2)
  assert_eq(data.selections.length(), 1)
  assert_eq(data.current, Some(data.versions[0].lesson.record))
  assert_eq(data.head.unwrap().record_id, "version-review-rollback-one")
  assert_true(lesson_history_accepted(data.versions[0]))
  assert_true(lesson_history_accepted(data.versions[1]))
  let base = history_test_model()
  let records = data.versions.map(version => version.lesson) +
    data.selections.map(selection => selection.record)
  let reviews : Array[BookkeeperRawReview] = []
  for version in data.versions {
    for review in version.reviews {
      reviews.push(review)
    }
  }
  for selection in data.selections {
    for review in selection.reviews {
      reviews.push(review)
    }
  }
  let model = {
    ..base,
    bookkeeper_store: Some({
      ..base.bookkeeper_store.unwrap(),
      records,
      reviews,
    }),
    outcome_lessons: {
      ..base.outcome_lessons,
      history: {
        ..initial_lesson_history_workspace(),
        lesson_id: data.lesson_id,
        data: Some(data),
        selected: Some(data.versions[1].lesson.record),
      },
    },
  }
  for operation in ["revise", "select"] {
    let changed = history_test_change(model, operation)
    let payload = lesson_history_payload(changed.outcome_lessons.history).unwrap()
    let roundtrip = @json.parse(payload.stringify())
    assert_eq(
      lesson_task_field(roundtrip, "expected_head"),
      lesson_task_field(value, "head"),
    )
    assert_true(lesson_task_field(roundtrip, "expected_head") is Object(_))
    assert_eq(
      lesson_task_field(roundtrip, "accepted_reviews"),
      lesson_task_field(value, "accepted_reviews"),
    )
    if operation == "revise" {
      assert_eq(
        lesson_task_field(roundtrip, "supersedes"),
        ToJson::to_json(data.versions[0].lesson.record),
      )
      let original = lesson_record_value(data.versions[0].lesson).unwrap()
      let revised = lesson_task_field(roundtrip, "lesson")
      for
        key in [
          "lesson_id", "outcome", "assessment", "assessment_review", "applicability",
          "invalidation",
        ] {
        assert_eq(
          lesson_task_field(revised, key),
          lesson_task_field(original, key),
          msg=key,
        )
      }
    } else {
      assert_eq(
        lesson_task_field(roundtrip, "target"),
        ToJson::to_json(data.versions[1].lesson.record),
      )
      assert_eq(lesson_task_text(roundtrip, "lesson_id"), data.lesson_id)
    }
    let html = history_test_html(changed)
    assert_true(html.contains("closure-reviewer-version-original"))
    assert_true(html.contains("evidence_state = superseded"))
    assert_true(
      html.contains("Current-version proposals and review history (1)"),
    )
  }
}

///|
test "history ordinary view shows current guidance every review original comparison and distinct review actions" {
  let model = history_test_change(history_test_model(), "revise")
  let html = history_test_html(model)
  for
    label in [
      "Open selected lesson history", "Current guidance", "Saved versions and human reviews",
      "Accept · named-reviewer", "Reject · named-reviewer", "Revise · named-reviewer",
      "Original comparison", "Original guidance 2 &lt;&amp;&gt; 中文", "customer_id = customer-a",
      "decision_kind = vendor-comparison", "Revised exact guidance &lt;&amp;&gt; 中文",
      "New lesson version", "Save revision for review", "Choose or restore this accepted version as current",
      "Why should this change be accepted?",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  let legacy = history_test_html(
    history_test_change(history_test_model(multiple=true), "select"),
  )
  assert_true(legacy.contains("No single current version"))
  assert_true(legacy.contains("Save current-version proposal for review"))
  assert_true(legacy.contains("Selected restore target"))
}

///|
test "existing named-human review detail shows revision and selection original scopes reasons and predecessor" {
  for operation in ["revise", "select"] {
    let model = history_test_change(history_test_model(), operation)
    let payload = lesson_history_payload(model.outcome_lessons.history).unwrap()
    let proposal = {
      ..draft_test_record("proposal"),
      payload: if operation == "revise" {
        {
          "candidate_schema": "outcome_lesson.v2",
          "revision": payload,
          "outcome_lesson": lesson_task_field(payload, "lesson"),
        }
      } else {
        {
          "candidate_schema": "outcome_lesson_selection.v1",
          "selection": payload,
        }
      },
    }
    let model = {
      ..model,
      selected_bookkeeper_record: Some(proposal.record),
      bookkeeper_store: Some({
        ..model.bookkeeper_store.unwrap(),
        records: model.bookkeeper_store.unwrap().records + [proposal],
      }),
    }
    let html = @rabbita.render_to_string(
      @rabbita.simple_cell(model~, update=fn(_msg : Msg, old) { old }, view=fn(
        _emit,
        model,
      ) {
        selected_outcome_lesson_detail(model)
      }),
    )
    for
      label in [
        "Reason · Reason &lt;&amp;&gt; 中文", "Original guidance 1 &lt;&amp;&gt; 中文",
        "Original guidance 2 &lt;&amp;&gt; 中文", "customer_id = customer-a", "decision_kind = vendor-comparison",
        "Captured predecessor and accepted reviews", "review-digest-2",
      ] {
      assert_true(html.contains(label), msg=operation + " " + label)
    }
    if operation == "revise" {
      assert_true(html.contains("Revised exact guidance &lt;&amp;&gt; 中文"))
    }
  }
}

///|
test "history decode binds lesson identity and requires typed original records and mutation confirmation" {
  let value = history_test_value()
  let wire : Json = {
    "schema": "moonbook.outcome-lesson-operation.v1",
    "ok": true,
    "operation": "history",
    "result": value,
  }
  let response : BookkeeperBrowserResponse = {
    ok: true,
    status: 200,
    body: wire.stringify(),
    error: None,
  }
  assert_eq(
    decode_outcome_lesson_response(
      "history",
      { "lesson_id": "one-stable-id" },
      response,
    ),
    Ok(value),
  )
  assert_true(
    decode_outcome_lesson_response(
      "history",
      { "lesson_id": "another" },
      response,
    )
    is Err(_),
  )
  assert_true(lesson_nullable_reference([]) is Err(_))
  assert_true(
    lesson_nullable_reference({
      "record_id": "",
      "record_version": "1",
      "record_digest": "digest",
    })
    is Err(_),
  )
  for operation in ["revise", "select"] {
    let invalid : Json = {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "ok": true,
      "operation": operation,
      "result": { "accepted": false },
    }
    assert_true(
      decode_outcome_lesson_response(operation, {}, {
        ..response,
        body: invalid.stringify(),
      })
      is Err(_),
    )
  }
}

///|
test "ordinary selected lesson history read and saved proposal return through existing named-human review controls" {
  let model = history_test_model()
  let loading = snapshot_test_step(model, OutcomeLesson(OpenHistory))
  assert_true(loading.outcome_lessons.pending)
  assert_eq(loading.outcome_lessons.history.lesson_id, "one-stable-id")
  assert_eq(loading.outcome_lessons.fields, model.outcome_lessons.fields)
  assert_eq(loading.outcome_lessons.handoff, model.outcome_lessons.handoff)
  let again = snapshot_test_step(loading, OutcomeLesson(OpenHistory))
  assert_eq(again.outcome_lessons.request, loading.outcome_lessons.request)
  let loaded = snapshot_test_step(
    loading,
    OutcomeLesson(
      HistoryFinished(
        loading.outcome_lessons.request,
        "history",
        Ok(history_test_value()),
      ),
    ),
  )
  assert_false(loaded.outcome_lessons.pending)
  for operation in ["revise", "select"] {
    let changed = history_test_change(loaded, operation)
    let payload = lesson_history_payload(changed.outcome_lessons.history).unwrap()
    let saved = {
      ..draft_test_record("proposal-" + operation),
      stage: Json::string("DeliverableAcceptance"),
      payload: if operation == "revise" {
        {
          "candidate_schema": "outcome_lesson.v2",
          "revision": payload,
          "outcome_lesson": lesson_task_field(payload, "lesson"),
        }
      } else {
        {
          "candidate_schema": "outcome_lesson_selection.v1",
          "selection": payload,
        }
      },
    }
    let saving = snapshot_test_step(changed, OutcomeLesson(SubmitHistoryChange))
    let state = lesson_history_finished(
      saving.outcome_lessons,
      saving.outcome_lessons.request,
      operation,
      Ok({ "accepted": true, "event": ToJson::to_json(saved.record) }),
    )
    let available = {
      ..changed,
      outcome_lessons: state,
      bookkeeper_store: Some({
        ..loaded.bookkeeper_store.unwrap(),
        records: loaded.bookkeeper_store.unwrap().records + [saved],
      }),
    }
    assert_true(
      history_test_html(available).contains(
        "Open saved change for named-human review",
      ),
    )
    assert_eq(
      available.outcome_lessons.history.data.unwrap().current,
      loaded.outcome_lessons.history.data.unwrap().current,
    )
    let selected = snapshot_test_step(
      available,
      SelectBookkeeperItem(lesson_record_item(saved)),
    )
    for decision in ["Accept", "Reject"] {
      let prepared = snapshot_test_step(
        selected,
        PrepareBookkeeperReview(decision),
      )
      let review = @json.parse(prepared.bookkeeper_draft)
      assert_eq(lesson_task_text(review, "requested"), decision)
      assert_eq(
        lesson_task_field(review, "subject"),
        ToJson::to_json(saved.record),
      )
      assert_eq(
        lesson_task_field(review, "reviewer_kind"),
        selected.bookkeeper_authorities.unwrap().grants[0].reviewer_kind,
      )
      assert_false(prepared.bookkeeper_busy)
      assert_eq(prepared.outcome_lessons.fields, model.outcome_lessons.fields)
    }
  }
}

///|
#external
type LessonHistoryTransportFixture

///|
extern "js" fn history_transport_fixture(
  response : String,
) -> LessonHistoryTransportFixture =
  #| response => ({ response, calls: [] })

///|
extern "js" fn history_transport_send(
  fixture : LessonHistoryTransportFixture,
  url : String,
  body : String,
) -> @js.Promise =
  #| async (fixture, url, body) => { fixture.calls.push({ url, method: "POST", body: JSON.parse(body) }); return JSON.stringify({ ok: true, status: 200, body: fixture.response }); }

///|
extern "js" fn history_transport_calls(
  fixture : LessonHistoryTransportFixture,
) -> String =
  #| fixture => JSON.stringify(fixture.calls)

///|
test "history controlled transport calls only history revise and select with exact captured bodies" {
  @js.async_test(async fn() {
    for operation in ["history", "revise", "select"] {
      let payload : Json = if operation == "history" {
        { "lesson_id": "one-stable-id" }
      } else {
        lesson_history_payload(
          history_test_change(history_test_model(), operation).outcome_lessons.history,
        ).unwrap()
      }
      let result = if operation == "history" {
        history_test_value()
      } else {
        {
          "accepted": true,
          "event": ToJson::to_json(draft_test_record("saved-proposal").record),
        }
      }
      let response : Json = {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "operation": operation,
        "ok": true,
        "result": result,
      }
      let fixture = history_transport_fixture(response.stringify())
      assert_eq(
        post_outcome_lesson(operation, payload, send=(url, body) => {
          history_transport_send(fixture, url, body)
        }),
        Ok(result),
      )
      guard @json.parse(history_transport_calls(fixture))
        is [{ "url": String(url), "method": "POST", "body": body, .. }] else {
        fail("Unexpected lesson transport")
      }
      assert_eq(url, "/api/bookkeeper/lessons/" + operation)
      assert_eq(body, payload)
    }
  })
}
