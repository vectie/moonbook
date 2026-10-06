///|
fn wiki_review_test_items(count : Int) -> Array[WikiReviewItem] {
  [
    for index in 0..<count => {
      {
        review_id: "review-\{index}",
        kind: "result-review",
        title: "Result \{index}",
        status: "pending",
      }
    }
  ]
}

///|
fn wiki_review_test_detail(
  review_id : String,
  status? : String = "pending",
) -> WikiReviewDetail {
  {
    review_id,
    kind: "result-review",
    title: "Exact result",
    status,
    review_digest: "digest-\{review_id}",
    review_text: "Complete review text for \{review_id}",
    result_text: "<script>danger()</script> complete source text",
    evidence_text: "Evidence first line\nEvidence final line",
    review_scope: "local-book-review",
    original_task_acceptance: "unevaluated",
    can_resolve: status == "pending",
    native_binding: None,
  }
}

///|
fn wiki_review_test_ready() -> WikiReviewState {
  let (queued, _) = wiki_review_reduce(
    wiki_review_initial_state(),
    QueueLoaded(1, Ok(wiki_review_test_items(7))),
  )
  let (selected, _) = wiki_review_reduce(queued, Select("review-0"))
  let (ready, _) = wiki_review_reduce(
    selected,
    DetailLoaded(
      selected.detail_request,
      "review-0",
      Ok(wiki_review_test_detail("review-0")),
    ),
  )
  ready
}

///|
fn wiki_review_test_choice(decision? : String = "approve") -> WikiReviewChoice {
  { review_id: "review-0", digest: "digest-review-0", decision, }
}

///|
fn wiki_review_test_wire_detail(status? : String = "pending") -> Json {
  {
    "review_id": "review-0",
    "kind": "result-review",
    "title": "Exact result",
    "status": status,
    "review_digest": "digest-review-0",
    "review_text": "Complete review text",
    "result_text": "Complete result text",
    "evidence_text": "Complete evidence text",
    "review_scope": "local-book-review",
    "original_task_acceptance": "unevaluated",
    "can_resolve": status == "pending",
    "native_binding": Json::null(),
  }
}

///|
#cfg(target="js")
test "wiki review queue preserves every exact ID and supports legacy detail" {
  let state = wiki_review_test_ready()
  assert_eq(state.items.length(), 7)
  assert_eq(state.items[6].review_id, "review-6")
  let detail = state.detail.unwrap()
  assert_eq(detail.review_id, "review-0")
  assert_true(detail.native_binding is None)
  assert_true(wiki_review_choice_is_current(state, wiki_review_test_choice()))
  assert_eq(detail.evidence_text, "Evidence first line\nEvidence final line")
}

///|
#cfg(target="js")
test "wiki review blank and duplicate queue IDs fail closed" {
  let items = wiki_review_test_items(2)
  items.push(items[0])
  let (duplicate, effects) = wiki_review_reduce(
    wiki_review_initial_state(),
    QueueLoaded(1, Ok(items)),
  )
  assert_false(duplicate.queue_loaded)
  assert_true(duplicate.queue_error is Some(_))
  assert_true(effects.is_empty())
  let (_, select_effects) = wiki_review_reduce(duplicate, Select("review-0"))
  assert_true(select_effects.is_empty())
  let blank : Array[WikiReviewItem] = [{ ..items[0], review_id: " ", }]
  assert_true(wiki_review_queue_issue(blank) is Some(_))
}

///|
#cfg(target="js")
test "wiki review requires explicit matching confirmation and dispatches only once" {
  let state = wiki_review_test_ready()
  let choice = wiki_review_test_choice()
  let (_, unconfirmed) = wiki_review_reduce(state, Confirm(choice))
  assert_true(unconfirmed.is_empty())
  let (prepared, prepare_effects) = wiki_review_reduce(state, Prepare(choice))
  assert_eq(prepared.confirmation, Some(choice))
  assert_true(prepare_effects.is_empty())
  let (saving, effects) = wiki_review_reduce(prepared, Confirm(choice))
  assert_true(effects is [Resolve(_, _)])
  assert_true(saving.pending is Some(_))
  let (_, duplicate) = wiki_review_reduce(saving, Confirm(choice))
  assert_true(duplicate.is_empty())
  let (_, reload) = wiki_review_reduce(saving, Reload)
  assert_true(reload.is_empty())
  let (_, select) = wiki_review_reduce(saving, Select("review-1"))
  assert_true(select.is_empty())
}

///|
#cfg(target="js")
test "wiki review rejects stale rendered ID digest and decision" {
  let state = wiki_review_test_ready()
  let choice = wiki_review_test_choice()
  for
    invalid in [
      { ..choice, review_id: "review-1", },
      { ..choice, digest: "old-digest", },
      { ..choice, decision: "accept-goal", },
    ] {
    let (next, effects) = wiki_review_reduce(state, Prepare(invalid))
    assert_true(next.confirmation is None)
    assert_true(effects.is_empty())
  }
  let (prepared, _) = wiki_review_reduce(state, Prepare(choice))
  let (selected, _) = wiki_review_reduce(prepared, Select("review-1"))
  let (_, stale) = wiki_review_reduce(selected, Confirm(choice))
  assert_true(stale.is_empty())
  assert_true(selected.confirmation is None)
}

///|
#cfg(target="js")
test "wiki review ignores late loads after selection or reload" {
  let ready = wiki_review_test_ready()
  let (first, _) = wiki_review_reduce(ready, Select("review-1"))
  let (second, _) = wiki_review_reduce(first, Select("review-2"))
  let (late, effects) = wiki_review_reduce(
    second,
    DetailLoaded(
      first.detail_request,
      "review-1",
      Ok(wiki_review_test_detail("review-1")),
    ),
  )
  assert_eq(late.selected_id, Some("review-2"))
  assert_true(late.detail is None)
  assert_true(late.detail_loading)
  assert_true(effects.is_empty())
  let (reload, _) = wiki_review_reduce(second, Reload)
  let (old_queue, _) = wiki_review_reduce(
    reload,
    QueueLoaded(1, Ok(wiki_review_test_items(1))),
  )
  assert_true(old_queue.queue_loading)
  assert_eq(old_queue.items.length(), 7)
  let (old_detail, _) = wiki_review_reduce(
    reload,
    DetailLoaded(
      second.detail_request,
      "review-2",
      Ok(wiki_review_test_detail("review-2")),
    ),
  )
  assert_true(old_detail.detail_loading)
  assert_true(old_detail.detail is None)
}

///|
#cfg(target="js")
test "wiki review failed loads disable decisions and reload keeps exact selection" {
  let ready = wiki_review_test_ready()
  let (reloading, effects) = wiki_review_reduce(ready, Reload)
  assert_true(effects is [LoadQueue(_), LoadDetail(_, "review-0")])
  assert_false(
    wiki_review_choice_is_current(reloading, wiki_review_test_choice()),
  )
  let (failed, _) = wiki_review_reduce(
    reloading,
    DetailLoaded(reloading.detail_request, "review-0", Err("offline")),
  )
  assert_eq(failed.detail_error, Some("offline"))
  assert_true(failed.detail is None)
  let (retry, retry_effects) = wiki_review_reduce(failed, Reload)
  assert_eq(retry.selected_id, Some("review-0"))
  assert_true(retry_effects is [LoadQueue(_), LoadDetail(_, "review-0")])
}

///|
#cfg(target="js")
test "wiki review successful and uncertain decisions both perform readback without automatic retry" {
  for decision in ["approve", "reject"] {
    let choice = wiki_review_test_choice(decision~)
    let (prepared, _) = wiki_review_reduce(
      wiki_review_test_ready(),
      Prepare(choice),
    )
    let (saving, _) = wiki_review_reduce(prepared, Confirm(choice))
    let pending = saving.pending.unwrap()
    let (checking, effects) = wiki_review_reduce(
      saving,
      Resolved(pending.request, Err("response lost")),
    )
    assert_true(
      effects is [LoadQueue(_), LoadDetail(_, "review-0"), RefreshSnapshot],
    )
    assert_true(checking.pending is None)
    assert_true(checking.confirmation is None)
    let status = if decision == "approve" { "approved" } else { "rejected" }
    let (verified, _) = wiki_review_reduce(
      checking,
      DetailLoaded(
        checking.detail_request,
        "review-0",
        Ok(wiki_review_test_detail("review-0", status~)),
      ),
    )
    assert_true(verified.readback_notice.unwrap().contains("Readback verified"))
    assert_false(verified.detail.unwrap().can_resolve)
    let (_, retry) = wiki_review_reduce(verified, Confirm(choice))
    assert_true(retry.is_empty())
    let (_, late_duplicate) = wiki_review_reduce(
      verified,
      Resolved(pending.request, Err("late")),
    )
    assert_true(late_duplicate.is_empty())
    let (reloaded, reload_effects) = wiki_review_reduce(verified, Reload)
    assert_eq(reloaded.selected_id, Some("review-0"))
    assert_true(reload_effects is [LoadQueue(_), LoadDetail(_, "review-0")])
  }
}

///|
#cfg(target="js")
test "wiki review readback failure retains uncertainty and cannot resolve stale detail" {
  let choice = wiki_review_test_choice()
  let (prepared, _) = wiki_review_reduce(
    wiki_review_test_ready(),
    Prepare(choice),
  )
  let (saving, _) = wiki_review_reduce(prepared, Confirm(choice))
  let response : WikiReviewResolution = {
    saved: true,
    detail: Some(wiki_review_test_detail("review-0", status="approved")),
    message: "Saved; checking.",
  }
  let (checking, _) = wiki_review_reduce(
    saving,
    Resolved(saving.pending.unwrap().request, Ok(response)),
  )
  let (failed, _) = wiki_review_reduce(
    checking,
    DetailLoaded(checking.detail_request, "review-0", Err("readback failed")),
  )
  assert_true(failed.detail is None)
  assert_true(failed.readback_notice.unwrap().contains("does not prove"))
  assert_false(wiki_review_choice_is_current(failed, choice))
  let (reloading, _) = wiki_review_reduce(failed, Reload)
  assert_eq(reloading.readback, Some(choice))
}

///|
#cfg(target="js")
test "wiki review wire rejects cross-scope or mismatched detail" {
  let wire : Json = {
    "schema": "moonbook.wiki-review-operator.v1",
    "ok": true,
    "detail": wiki_review_test_wire_detail(),
  }
  assert_true(wiki_review_decode_detail(wire.stringify(), "review-0") is Ok(_))
  assert_true(wiki_review_decode_detail(wire.stringify(), "other-id") is Err(_))
  let detail = wiki_review_test_detail("review-0")
  assert_true(
    wiki_review_detail_issue(
      { ..detail, original_task_acceptance: "accepted", },
      "review-0",
    )
    is Some(_),
  )
  assert_true(
    wiki_review_detail_issue(
      { ..detail, review_scope: "goal-acceptance", },
      "review-0",
    )
    is Some(_),
  )
  assert_true(
    wiki_review_detail_issue({ ..detail, review_digest: "", }, "review-0")
    is Some(_),
  )
  assert_true(
    wiki_review_detail_issue({ ..detail, status: "approved", }, "review-0")
    is Some(_),
  )
  let invalid : Json = {
    "schema": "old",
    "ok": true,
    "detail": wiki_review_test_wire_detail(),
  }
  assert_true(
    wiki_review_decode_detail(invalid.stringify(), "review-0") is Err(_),
  )
}

///|
#cfg(target="js")
test "wiki review transport sends only exact local scope and retains conflict details" {
  let choice = wiki_review_test_choice(decision="reject")
  json_inspect(wiki_review_resolve_body(choice), content={
    "review_id": "review-0",
    "decision": "reject",
    "expected_digest": "digest-review-0",
    "scope": "local-book-review",
  })
  let conflict : Json = {
    "schema": "moonbook.wiki-review-operator.v1",
    "ok": false,
    "error": "already-resolved",
    "detail": wiki_review_test_wire_detail(status="approved"),
  }
  let response = wiki_review_decode_resolution(
    conflict.stringify(),
    409,
    choice,
  ).unwrap()
  assert_false(response.saved)
  assert_eq(response.detail.unwrap().status, "approved")
  assert_true(response.message.contains("already-resolved"))
  let saved : Json = {
    "schema": "moonbook.wiki-review-operator.v1",
    "ok": true,
    "detail": wiki_review_test_wire_detail(status="rejected"),
    "promoted_pages": ["reviews/approved.md"],
  }
  let success = wiki_review_decode_resolution(saved.stringify(), 200, choice).unwrap()
  assert_true(success.saved)
  assert_true(success.message.contains("reviews/approved.md"))
  assert_true(
    wiki_review_decode_resolution(
      saved.stringify(),
      200,
      wiki_review_test_choice(),
    )
    is Err(_),
  )
}

///|
#cfg(target="js")
test "wiki review queue decoding supports all items and refuses unsupported acceptance" {
  let items : Array[Json] = [
    for item in wiki_review_test_items(7) => {
      {
        "review_id": item.review_id,
        "kind": item.kind,
        "title": item.title,
        "status": item.status,
      }
    }
  ]
  let wire : Json = {
    "schema": "moonbook.wiki-review-operator.v1",
    "ok": true,
    "items": items,
    "original_task_acceptance": "unevaluated",
  }
  assert_eq(wiki_review_decode_queue(wire.stringify()).unwrap().length(), 7)
  let invalid : Json = {
    "schema": "moonbook.wiki-review-operator.v1",
    "ok": true,
    "items": items,
    "original_task_acceptance": "accepted",
  }
  assert_true(wiki_review_decode_queue(invalid.stringify()) is Err(_))
  assert_true(wiki_review_decode_queue("not JSON") is Err(_))
}

///|
#cfg(target="js")
test "wiki review SSR exposes full queue exact evidence local scope and safe text" {
  let state = wiki_review_test_ready()
  let cell = @rabbita.simple_cell(
    model=state,
    update=fn(_msg : Msg, old) { old },
    view=fn(emit, state) { wiki_review_panel(emit, state) },
  )
  let rendered = @rabbita.render_to_string(cell)
  assert_true(rendered.contains("id=\"reviews\""))
  assert_true(rendered.contains("All 7 queued reviews"))
  assert_true(rendered.contains("review-6"))
  assert_true(rendered.contains("Exact review ID:"))
  assert_true(rendered.contains("Evidence final line"))
  assert_true(
    rendered.contains(
      "&lt;script&gt;danger()&lt;/script&gt; complete source text",
    ),
  )
  assert_false(rendered.contains("<script>danger()"))
  assert_true(
    rendered.contains("Original-task/goal acceptance remains unevaluated"),
  )
  assert_true(rendered.contains("Legacy/local review"))
  assert_true(rendered.contains("Approve in Book"))
  assert_true(rendered.contains("Reject in Book"))
  assert_false(rendered.contains("Confirm approve in Book"))
  let (prepared, _) = wiki_review_reduce(
    state,
    Prepare(wiki_review_test_choice()),
  )
  let confirmation = @rabbita.render_to_string(
    @rabbita.simple_cell(model=prepared, update=fn(_msg : Msg, old) { old }, view=fn(
      emit,
      model,
    ) {
      wiki_review_panel(emit, model)
    }),
  )
  assert_true(confirmation.contains("Confirm approve in Book"))
  assert_true(confirmation.contains("exact review ID review-0"))
}

///|
#cfg(target="js")
test "wiki review browser reload restores only exact ID and inspects resolved records" {
  let initial = wiki_review_initial_state(restore_id="already-reviewed")
  assert_eq(initial.selected_id, Some("already-reviewed"))
  assert_true(initial.detail is None)
  assert_true(initial.confirmation is None)
  assert_true(initial.pending is None)
  let (restoring, effects) = wiki_review_reduce(initial, QueueLoaded(1, Ok([])))
  assert_true(effects is [LoadDetail(_, "already-reviewed")])
  assert_true(restoring.items.is_empty())
  assert_true(restoring.detail_loading)
  let (restored, after_inspect) = wiki_review_reduce(
    restoring,
    DetailLoaded(
      restoring.detail_request,
      "already-reviewed",
      Ok(wiki_review_test_detail("already-reviewed", status="approved")),
    ),
  )
  assert_eq(restored.detail.unwrap().status, "approved")
  assert_true(restored.confirmation is None)
  assert_true(restored.pending is None)
  assert_true(after_inspect.is_empty())
  let (_, explicit_selection) = wiki_review_reduce(
    wiki_review_test_ready(),
    Select("review-1"),
  )
  assert_true(
    explicit_selection
    is [RememberSelection("review-1"), LoadDetail(_, "review-1")],
  )
}

///|
#cfg(target="js")
test "wiki review URL hint roundtrips exact IDs without decisions or digests" {
  let exact_id = "review /?&=# plus+ unicode月"
  let url = wiki_review_url_with_hint(
    "https://example.invalid/book?chapter=3#overview", exact_id,
  )
  assert_eq(wiki_review_url_hint(url), exact_id)
  assert_true(url.contains("chapter=3"))
  assert_true(url.has_suffix("#reviews"))
  assert_true(url.contains("wiki_review="))
  assert_false(url.contains("expected_digest"))
  assert_false(url.contains("decision="))
  let replacement = wiki_review_url_with_hint(url, "next-review")
  assert_eq(wiki_review_url_hint(replacement), "next-review")
  assert_eq(wiki_review_url_hint("invalid URL"), "")
  assert_true(wiki_review_restore_id("  ") is None)
  let with_untrusted_action = "https://example.invalid/book?wiki_review=review-0&decision=approve&expected_digest=old"
  let initial = wiki_review_initial_state(
    restore_id=wiki_review_url_hint(with_untrusted_action),
  )
  assert_eq(initial.selected_id, Some("review-0"))
  assert_true(initial.confirmation is None)
  assert_true(initial.detail is None)
  assert_true(initial.pending is None)
}

///|
#cfg(target="js")
test "wiki review failed initial queue can reload and restore authoritative detail" {
  let initial = wiki_review_initial_state(restore_id="resolved-id")
  let (failed, first_effects) = wiki_review_reduce(
    initial,
    QueueLoaded(1, Err("offline")),
  )
  assert_true(first_effects.is_empty())
  let (retry, retry_effects) = wiki_review_reduce(failed, Reload)
  assert_true(retry_effects is [LoadQueue(_)])
  let (restoring, effects) = wiki_review_reduce(
    retry,
    QueueLoaded(retry.queue_request, Ok([])),
  )
  assert_true(effects is [LoadDetail(_, "resolved-id")])
  assert_true(restoring.confirmation is None)
  assert_true(restoring.pending is None)
}
