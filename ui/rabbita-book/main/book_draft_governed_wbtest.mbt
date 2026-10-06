///|
fn governed_test_model(stage : String) -> Model {
  let record = { ..draft_test_record("first"), stage: Json::string(stage), }
  let grant = live_test_registry("reviewer").grants[0]
  let review : BookkeeperRawReview = {
    contract_version: "moonbook.bookkeeper.store.v1",
    mutation: {
      record_id: "review-mutation",
      record_version: "v1",
      record_digest: "mutation-digest",
    },
    receipt: {
      record_id: "required-review",
      record_version: "v1",
      record_digest: "required-review-digest",
    },
    stage: record.stage,
    subject: record.record,
    requested: "Accept",
    disposition: "Accept",
    reviewer_kind: "Human",
    reviewer: {
      grant: grant.grant,
      reviewer_id: grant.reviewer_id,
      authority_ref: grant.authority_ref,
      authorized: true,
      evidence_refs: [],
    },
    evidence_refs: record.evidence_refs,
    summary: "Accepted",
    decided_at: 1,
    issues: [],
    review_complete: true,
    side_effects_applied: false,
  }
  {
    ..draft_test_model(),
    bookkeeper_store: Some({
      ..live_test_store(1),
      records: [record],
      reviews: [review],
    }),
  }
}

///|
fn governed_test_edited(mode : String, stage : String) -> Model {
  let reviewed = snapshot_test_step(
    governed_test_model(stage),
    PrepareBookkeeperReview("Accept"),
  )
  let reviewed = snapshot_test_step(
    reviewed,
    DraftRecovery(EditSummary("My separate review explanation")),
  )
  let prepared = snapshot_test_step(reviewed, SetBookkeeperMode(mode))
  snapshot_test_step(
    prepared,
    SetBookkeeperDraft(prepared.bookkeeper_draft + "\n  "),
  )
}

///|
fn governed_test_view(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(
      model~,
      update=fn(_msg : Msg, old) { old },
      view=book_technical_recovery_view,
    ),
  )
}

///|
fn governed_test_removed(mode : String, stage : String) -> Unit raise {
  let edited = governed_test_edited(mode, stage)
  assert_true(edited.bookkeeper_draft.contains("required-review-digest"))
  let elsewhere = snapshot_test_step(edited, SetBookkeeperMode("ingress"))
  let missing = {
    ..elsewhere,
    bookkeeper_store: Some({
      ..elsewhere.bookkeeper_store.unwrap(),
      reviews: [],
    }),
  }
  let reentered = snapshot_test_step(missing, SetBookkeeperMode(mode))
  assert_eq(reentered.bookkeeper_draft, bookkeeper_mode_template(mode))
  assert_false(book_technical_restore_ready(reentered))
  let restored = snapshot_test_step(reentered, DraftRecovery(RestoreTechnical))
  assert_eq(restored.bookkeeper_draft, bookkeeper_mode_template(mode))
  assert_false(
    snapshot_test_step(restored, SubmitBookkeeperMutation).bookkeeper_busy,
  )
  assert_false(
    governed_test_view(restored).contains(
      "Restore technical edits for this context",
    ),
  )
  assert_eq(
    book_retained_text(
      restored.draft_recovery.technical,
      book_technical_context(edited),
    ),
    Some(edited.bookkeeper_draft),
  )
  assert_true(
    restored.draft_recovery.notes.any(item => {
      item.text == "My separate review explanation"
    }),
  )
}

///|
test "removed proposal acceptance cannot restore or submit its old work order payload" {
  governed_test_removed("project-work-order", "CapabilityProposal")
}

///|
test "removed work order acceptance cannot restore or submit its old egress payload" {
  governed_test_removed("egress-work-order", "MoonCodeWorkOrder")
}

///|
test "rejected incomplete and replaced prerequisite receipts do not restore obsolete payloads" {
  for
    (mode, stage) in [
      ("project-work-order", "CapabilityProposal"),
      ("egress-work-order", "MoonCodeWorkOrder"),
    ] {
    let edited = governed_test_edited(mode, stage)
    let old_review = edited.bookkeeper_store.unwrap().reviews[0]
    let elsewhere = snapshot_test_step(edited, SetBookkeeperMode("ingress"))
    let replacement = {
      ..old_review,
      receipt: {
        ..old_review.receipt,
        record_digest: "replacement-review-digest",
      },
    }
    for
      changed_review in [
        { ..old_review, disposition: "Reject", },
        { ..old_review, review_complete: false, },
        { ..old_review, issues: ["no longer accepted"], },
        replacement,
      ] {
      let changed = {
        ..elsewhere,
        bookkeeper_store: Some({
          ..elsewhere.bookkeeper_store.unwrap(),
          reviews: [changed_review],
        }),
      }
      let reentered = snapshot_test_step(changed, SetBookkeeperMode(mode))
      assert_true(
        book_technical_context(reentered) != book_technical_context(edited),
      )
      let fresh = reentered.bookkeeper_draft
      let restored = snapshot_test_step(
        reentered,
        DraftRecovery(RestoreTechnical),
      )
      assert_eq(restored.bookkeeper_draft, fresh)
      assert_false(restored.bookkeeper_draft.contains("required-review-digest"))
      if changed_review.receipt.record_digest == "replacement-review-digest" {
        assert_true(
          restored.bookkeeper_draft.contains("replacement-review-digest"),
        )
        assert_true(book_technical_restore_ready(restored))
      } else {
        assert_eq(restored.bookkeeper_draft, bookkeeper_mode_template(mode))
        assert_false(
          snapshot_test_step(restored, SubmitBookkeeperMutation).bookkeeper_busy,
        )
      }
    }
  }
}

///|
test "live prerequisite removal or replacement invalidates an already open governed payload" {
  for
    (mode, stage) in [
      ("project-work-order", "CapabilityProposal"),
      ("egress-work-order", "MoonCodeWorkOrder"),
    ] {
    let edited = governed_test_edited(mode, stage)
    let store = edited.bookkeeper_store.unwrap()
    let review = store.reviews[0]
    let variants : Array[Array[BookkeeperRawReview]] = [
      [],
      [{ ..review, receipt: { ..review.receipt, record_digest: "changed", }, }],
    ]
    for reviews in variants {
      let changed = { ..edited, bookkeeper_store: Some({ ..store, reviews, }), }
      assert_true(book_draft_is_stale(changed))
      let blocked = snapshot_test_step(changed, SubmitBookkeeperMutation)
      assert_false(blocked.bookkeeper_busy)
      assert_eq(blocked.bookkeeper_draft, edited.bookkeeper_draft)
      assert_eq(
        blocked.draft_recovery.notes.length(),
        edited.draft_recovery.notes.length(),
      )
      assert_true(
        blocked.draft_recovery.notes.any(item => {
          item.text == "My separate review explanation"
        }),
      )
    }
  }
}

///|
test "a technical draft authored with missing prerequisites cannot restore authority later" {
  for
    (mode, stage) in [
      ("project-work-order", "CapabilityProposal"),
      ("egress-work-order", "MoonCodeWorkOrder"),
    ] {
    let valid = governed_test_edited(mode, stage)
    let initial = governed_test_model(stage)
    let missing = {
      ..initial,
      bookkeeper_store: Some({
        ..initial.bookkeeper_store.unwrap(),
        reviews: [],
      }),
    }
    let neutral = snapshot_test_step(missing, SetBookkeeperMode(mode))
    let manually_typed = snapshot_test_step(
      neutral,
      SetBookkeeperDraft(valid.bookkeeper_draft),
    )
    let elsewhere = snapshot_test_step(
      manually_typed,
      SetBookkeeperMode("ingress"),
    )
    let reentered = snapshot_test_step(elsewhere, SetBookkeeperMode(mode))
    // The unavailable context is identical. Readiness is independently checked
    // so an old manual copy cannot turn that unavailable template executable.
    assert_eq(
      book_technical_context(reentered),
      book_technical_context(manually_typed),
    )
    assert_true(
      book_retained_text(
        reentered.draft_recovery.technical,
        book_technical_context(reentered),
      )
      is Some(_),
    )
    assert_false(book_technical_restore_ready(reentered))
    let restored = snapshot_test_step(
      reentered,
      DraftRecovery(RestoreTechnical),
    )
    assert_eq(restored.bookkeeper_draft, bookkeeper_mode_template(mode))
    assert_false(
      governed_test_view(restored).contains(
        "Restore technical edits for this context",
      ),
    )
  }
}

///|
test "unchanged accepted prerequisites still allow exact technical recovery after unrelated updates" {
  for
    (mode, stage) in [
      ("project-work-order", "CapabilityProposal"),
      ("egress-work-order", "MoonCodeWorkOrder"),
    ] {
    let edited = governed_test_edited(mode, stage)
    let elsewhere = snapshot_test_step(edited, SetBookkeeperMode("ingress"))
    let store = elsewhere.bookkeeper_store.unwrap()
    let unrelated = {
      ..store.reviews[0],
      subject: {
        record_id: "unrelated",
        record_version: "v1",
        record_digest: "unrelated",
      },
    }
    let updated = {
      ..elsewhere,
      bookkeeper_store: Some({
        ..store,
        last_sequence: 99,
        reviews: [unrelated] + store.reviews,
      }),
    }
    let reentered = snapshot_test_step(updated, SetBookkeeperMode(mode))
    assert_eq(book_technical_context(reentered), book_technical_context(edited))
    assert_true(book_technical_restore_ready(reentered))
    assert_true(
      governed_test_view(reentered).contains(
        "Restore technical edits for this context",
      ),
    )
    let restored = snapshot_test_step(
      reentered,
      DraftRecovery(RestoreTechnical),
    )
    assert_eq(restored.bookkeeper_draft, edited.bookkeeper_draft)
  }
}
