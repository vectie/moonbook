///|
extern "js" fn guided_book_before(
  html : String,
  left : String,
  right : String,
) -> Bool =
  #| (html, left, right) => html.indexOf(left) >= 0 && html.indexOf(right) > html.indexOf(left)

///|
extern "js" fn guided_book_primary_href(html : String) -> String =
  #| html => (html.match(/<a\b[^>]*>/g) || []).find(tag => /class="moonbook-primary-action"/.test(tag))?.match(/href="([^"]*)"/)?.[1] || ''

///|
fn guided_book_model(state : WikiReviewState) -> Model {
  {
    loading: false,
    state: demo_state(),
    error: None,
    refresh_count: 1,
    snapshot_request: 1,
    live_reload_endpoint: None,
    locale: English,
    bookkeeper_store: None,
    bookkeeper_authorities: None,
    bookkeeper_reads: {
      ..initial_bookkeeper_reads(),
      store_loading: false,
      authorities_loading: false,
    },
    selected_bookkeeper_record: None,
    selected_bookkeeper_authority: None,
    bookkeeper_mode: "ingress",
    bookkeeper_draft: "",
    bookkeeper_busy: false,
    bookkeeper_notice: None,
    draft_recovery: initial_book_draft_recovery(),
    wiki_review: state,
    outcome_lessons: initial_outcome_lesson_workspace(),
  }
}

///|
fn guided_book_hero(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(model~, update=fn(_msg : Msg, old) { old }, view=fn(
      _emit,
      model,
    ) {
      hero_section(model.state, model)
    }),
  )
}

///|
fn guided_book_panel(state : WikiReviewState) -> String {
  @rabbita.render_to_string(
    @rabbita.simple_cell(model=state, update=fn(_msg : Msg, old) { old }, view=fn(
      emit,
      model,
    ) {
      wiki_review_panel(emit, model)
    }),
  )
}

///|
test "local review next step matches pending queue and restored review" {
  let state = wiki_review_test_ready()
  let html = guided_book_hero(guided_book_model(state))
  assert_eq(guided_book_primary_href(html), "#reviews")
  assert_true(html.contains("Continue Book review"))
  assert_true(html.contains("Open Bookkeeper"))
  assert_true(html.contains("Task and goal acceptance remain separate"))
  let restored = wiki_review_initial_state(restore_id="resolved-exact-id")
  assert_true(wiki_review_is_next(restored, false))
  assert_false(wiki_review_is_next(wiki_review_initial_state(), false))
  let empty = { ..state, selected_id: None, items: [], detail: None, }
  assert_eq(
    guided_book_primary_href(guided_book_hero(guided_book_model(empty))),
    "#bookkeeper",
  )
}

///|
test "chosen Bookkeeper workflow keeps its primary navigation" {
  let model = guided_book_model(wiki_review_test_ready())
  let chosen = { ..model, bookkeeper_mode: "review", }
  let html = guided_book_hero(chosen)
  assert_eq(guided_book_primary_href(html), "#bookkeeper")
  assert_true(html.contains("Continue Bookkeeper review"))
  assert_true(html.contains("Review Book queue (7)"))
  assert_false(wiki_review_is_next(model.wiki_review, true))
  let busy = { ..model, bookkeeper_busy: true, }
  assert_eq(guided_book_primary_href(guided_book_hero(busy)), "#bookkeeper")
}

///|
test "selected Book review precedes queue without losing complete context" {
  let html = guided_book_panel(wiki_review_test_ready())
  assert_true(guided_book_before(html, "Exact review ID:", "Result 6"))
  assert_true(guided_book_before(html, "Evidence final line", "Inspect review"))
  assert_true(html.contains("All 7 queued reviews"))
  assert_true(html.contains("Content verification details"))
  assert_true(html.contains("Displayed-content digest:"))
  assert_true(
    html.contains("&lt;script&gt;danger()&lt;/script&gt; complete source text"),
  )
  assert_true(html.contains("Legacy/local review"))
  assert_true(html.contains("Approve in Book"))
  assert_false(html.contains("Confirm approve in Book"))
}

///|
test "Book confirmation and uncertain readback stay ahead of other queue items" {
  let state = wiki_review_test_ready()
  let (prepared, _) = wiki_review_reduce(
    state,
    Prepare(wiki_review_test_choice()),
  )
  assert_true(wiki_review_is_next(prepared, true))
  let confirmation = guided_book_panel(prepared)
  assert_true(
    guided_book_before(confirmation, "Confirm approve in Book", "Result 6"),
  )
  let (saving, _) = wiki_review_reduce(
    prepared,
    Confirm(wiki_review_test_choice()),
  )
  let (uncertain, effects) = wiki_review_reduce(
    saving,
    Resolved(saving.pending.unwrap().request, Err("Connection interrupted")),
  )
  assert_true(uncertain.readback is Some(_))
  assert_true(wiki_review_is_next(uncertain, true))
  assert_true(
    effects is [LoadQueue(_), LoadDetail(_, "review-0"), RefreshSnapshot],
  )
  let html = guided_book_panel(uncertain)
  assert_true(html.contains("Connection interrupted"))
  assert_true(guided_book_before(html, "Connection interrupted", "Result 6"))
  assert_true(
    html.contains("Original-task/goal acceptance remains unevaluated"),
  )
}

///|
test "explicit Bookkeeper anchor preserves the chosen workflow" {
  assert_true(
    bookkeeper_anchor_selected("https://example.invalid/book#bookkeeper"),
  )
  assert_true(
    bookkeeper_anchor_selected(
      "https://example.invalid/book?wiki_review=review-0#bookkeeper-lanes",
    ),
  )
  assert_false(
    bookkeeper_anchor_selected("https://example.invalid/book#reviews"),
  )
  assert_false(
    bookkeeper_anchor_selected(
      "https://example.invalid/book?return_to=%23bookkeeper",
    ),
  )
  assert_false(bookkeeper_anchor_selected(""))
}

///|
test "Book next-step wording matches saved and uncertain review states" {
  let ready = wiki_review_test_ready()
  let resolved = {
    ..ready,
    detail: Some(wiki_review_test_detail("review-0", status="approved")),
    items: [],
  }
  let saved = guided_book_hero(guided_book_model(resolved))
  assert_eq(guided_book_primary_href(saved), "#reviews")
  assert_true(saved.contains("Inspect the saved Book decision"))
  assert_true(saved.contains("cannot be resolved again"))
  assert_false(saved.contains("choose approve or reject"))
  let uncertain = { ..ready, readback: Some(wiki_review_test_choice()), }
  let checking = guided_book_hero(guided_book_model(uncertain))
  assert_true(checking.contains("Verify the Book decision"))
  assert_true(checking.contains("outcome is uncertain"))
  assert_false(checking.contains("choose approve or reject"))
  let failed = { ..ready, queue_error: Some("offline"), }
  assert_true(
    guided_book_hero(guided_book_model(failed)).contains(
      "Reload Book review information",
    ),
  )
}
