///|
fn product_ui_package() -> Json {
  {
    "contract_version": "moonbook.product-outcome-package.v1",
    "package_digest": "sha256:" + "d".repeat(64),
    "payload_json": (
      {
        "submission": outcome_test_submission(),
        "artifacts": [
          {
            "reference": { "reference_id": "original-result" },
            "text": "<script>keep escaped</script> 中文",
          },
        ],
      } : Json).stringify(),
  }
}

///|
fn product_ui_receipt(state : String) -> Json {
  let progress = outcome_review_items(outcome_test_readback(state))[0]
  {
    "contract_version": "moonbook.product-outcome-readback.v1",
    "package_digest": lesson_task_field(product_ui_package(), "package_digest"),
    "package": product_ui_package(),
    "progress": progress,
    "reviews": [],
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
fn product_ui_step(model : Model, action : ProductOutcomeMsg) -> Model {
  snapshot_test_step(model, OutcomeLesson(ProductOutcome(action)))
}

///|
extern "js" fn product_test_picker_failure(restore : Bool) =
  #| restore => {if(restore){globalThis.document=globalThis.__productPickerDocument;delete globalThis.__productPickerDocument;return}globalThis.__productPickerDocument=globalThis.document;globalThis.document={createElement:()=>({files:[{size:10,text:async()=>{throw Error('fixture file became unreadable')}}],click(){queueMicrotask(()=>this.onchange())}})}}

///|
test "product file read rejection settles the picker and allows retry" {
  @js.async_test(async fn() {
    product_test_picker_failure(false)
    let result : Result[String, Error] = Ok(
      product_outcome_pick_file().wait().cast(),
    ) catch {
      error => Err(error)
    }
    product_test_picker_failure(true)
    assert_true(result is Err(_))
    let original = draft_test_model()
    let pending = product_ui_step(original, Pick)
    let failed = product_ui_step(
      pending,
      Picked(
        pending.outcome_lessons.products.request,
        Err("fixture file became unreadable"),
      ),
    )
    assert_false(failed.outcome_lessons.products.pending)
    assert_true(product_ui_step(failed, Pick).outcome_lessons.products.pending)
  })
}

///|
test "product import works without accepted company task and preserves drafts on duplicate failure and stale response" {
  let original = {
    ..outcome_test_model("deliverable_review_required"),
    outcome_lessons: { ..lesson_workspace_fixture(), handoff: None, },
  }
  let picking = product_ui_step(original, Pick)
  assert_true(picking.outcome_lessons.products.pending)
  assert_eq(
    product_ui_step(picking, Pick).outcome_lessons.products.request,
    picking.outcome_lessons.products.request,
  )
  let preview = product_ui_step(
    picking,
    Picked(
      picking.outcome_lessons.products.request,
      Ok(product_ui_package().stringify()),
    ),
  )
  assert_eq(
    preview.outcome_lessons.products.preview,
    Some(product_ui_package()),
  )
  assert_true(preview.outcome_lessons.handoff is None)
  outcome_test_drafts_kept(original, preview)
  let saving = product_ui_step(
    preview,
    Run("product-import", product_ui_package()),
  )
  assert_true(saving.outcome_lessons.products.pending)
  assert_eq(
    product_ui_step(saving, Run("product-import", product_ui_package())).outcome_lessons.products.request,
    saving.outcome_lessons.products.request,
  )
  let late = product_ui_step(
    saving,
    Read(
      saving.outcome_lessons.products.request - 1,
      "product-import",
      product_ui_package(),
      Ok(product_ui_receipt("deliverable_review_required")),
    ),
  )
  assert_true(late.outcome_lessons.products.pending)
  let failed = product_ui_step(
    saving,
    Read(
      saving.outcome_lessons.products.request,
      "product-import",
      product_ui_package(),
      Err("fixture network interruption"),
    ),
  )
  assert_eq(
    failed.outcome_lessons.products.preview,
    preview.outcome_lessons.products.preview,
  )
  outcome_test_drafts_kept(original, failed)
  let retry = product_ui_step(
    failed,
    Run("product-import", product_ui_package()),
  )
  let saved = product_ui_step(
    retry,
    Read(
      retry.outcome_lessons.products.request,
      "product-import",
      product_ui_package(),
      Ok(product_ui_receipt("deliverable_review_required")),
    ),
  )
  assert_true(saved.outcome_lessons.products.preview is None)
  assert_true(saved.outcome_lessons.products.selected is Some(_))
  outcome_test_drafts_kept(original, saved)
}

///|
test "product readback binds exact submission and rejects mismatched or activating responses" {
  let request : Json = { "submission": outcome_test_reference() }
  assert_true(
    product_outcome_response(
      "product-read",
      request,
      product_ui_receipt("deliverable_rejected"),
    )
    is Ok(_),
  )
  assert_true(
    product_outcome_response(
      "product-read",
      { "submission": {} },
      product_ui_receipt("deliverable_rejected"),
    )
    is Err(_),
  )
  assert_true(
    product_outcome_response(
      "product-read",
      request,
      outcome_test_replace(
        product_ui_receipt("deliverable_rejected"),
        "activation_authorized",
        true,
      ),
    )
    is Err(_),
  )
  assert_true(
    product_outcome_response(
      "product-import",
      {},
      product_ui_receipt("deliverable_review_required"),
    )
    is Err(_),
  )
}

///|
test "product panel exposes retained source and next existing review action with escaped content" {
  let base = draft_test_model()
  let model = {
    ..base,
    outcome_lessons: {
      ..base.outcome_lessons,
      products: {
        ..initial_product_outcome_workspace(),
        selected: Some(product_ui_receipt("deliverable_rejected")),
      },
    },
  }
  let html = book_test_render_component(
    @rabbita.simple_cell(
      model~,
      update=fn(_message : Msg, old) { old },
      view=product_outcome_view,
    ),
  )
  for
    expected in [
      "Product outcomes", "Import product outcome", "Download disposition receipt",
      "Download unchanged source package", "Deliverable rejected", "Original source",
      "&lt;script&gt;",
    ] {
    assert_true(html.contains(expected), msg=expected)
  }
  assert_false(html.contains("<script>keep escaped"))
  assert_false(html.contains("accepted company task"))
}

///|
test "product revision and escalation controls prepare existing governed decisions and preserve each reason" {
  let base = outcome_test_model("deliverable_review_required")
  let original = {
    ..base,
    outcome_lessons: {
      ..base.outcome_lessons,
      products: {
        ..initial_product_outcome_workspace(),
        selected: Some(product_ui_receipt("deliverable_review_required")),
      },
    },
  }
  let opened = product_ui_step(
    original,
    Review(draft_test_record("second").record.to_json()),
  )
  assert_true(product_outcome_can_defer(opened))
  let revision = snapshot_test_step(opened, PrepareBookkeeperReview("Revise"))
  let request = @json.parse(revision.bookkeeper_draft)
  assert_eq(lesson_task_text(request, "requested"), "Revise")
  assert_eq(
    lesson_task_field(request, "subject"),
    draft_test_record("second").record.to_json(),
  )
  assert_true(
    revision.draft_recovery.summary.contains("acceptance is deferred"),
  )
  let edited = snapshot_test_step(
    revision,
    DraftRecovery(
      EditSummary(
        "Please clarify the retained terrain assumptions before acceptance",
      ),
    ),
  )
  let escalated = snapshot_test_step(
    edited,
    PrepareBookkeeperReview("Escalate"),
  )
  assert_eq(
    lesson_task_text(@json.parse(escalated.bookkeeper_draft), "requested"),
    "Escalate",
  )
  let restored = snapshot_test_step(
    escalated,
    PrepareBookkeeperReview("Revise"),
  )
  assert_eq(restored.draft_recovery.summary, edited.draft_recovery.summary)
  let html = book_test_render_component(
    @rabbita.simple_cell(
      model=opened,
      update=fn(_message : Msg, old) { old },
      view=product_outcome_view,
    ),
  )
  assert_true(html.contains("Prepare revision request"))
  assert_true(html.contains("Prepare escalation"))
  let unrelated = draft_test_model()
  assert_true(review_draft_for_selection(unrelated, "Revise") is None)
  let no_reviewer = { ..opened, selected_bookkeeper_authority: None, }
  assert_true(review_draft_for_selection(no_reviewer, "Revise") is None)
  let mismatched = {
    ..opened,
    selected_bookkeeper_record: Some(draft_test_record("first").record),
  }
  assert_false(product_outcome_can_defer(mismatched))
  let store = opened.bookkeeper_store.unwrap()
  let completed = governed_test_model("DeliverableAcceptance").bookkeeper_store.unwrap().reviews[0]
  let stale = {
    ..opened,
    bookkeeper_store: Some({
      ..store,
      reviews: [{ ..completed, subject: draft_test_record("second").record, }],
    }),
  }
  assert_false(product_outcome_can_defer(stale))
  assert_true(review_draft_for_selection(stale, "Escalate") is None)
}
