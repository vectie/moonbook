///|
// Resolve only the current completed inspection, with exact search binding.
fn book_collection_refresh_candidate(
  state : BookSearchState,
) -> BookCollectionItem? {
  guard !state.pending &&
    !state.page_pending &&
    state.result is Some(result) &&
    state.page is Some(page) &&
    page.ok &&
    page.schema == "moonbook.search.v1" &&
    state.draft == result.question &&
    page.question == result.question &&
    state.selected == Some(page.citation) &&
    page.page == result.paging.map(p => p.page) &&
    result.excerpts.search_by(item => item.citation == page.citation)
    is Some(index) &&
    state.collection.items.any(item => item.page.citation == page.citation) else {
    return None
  }
  Some({ title: result.excerpts[index].title, page, note: "", })
}

///|
fn book_collection_snapshot_unchanged(
  old : BookCollectionItem,
  fresh : BookCollectionItem,
) -> Bool {
  old.title == fresh.title &&
  old.page.content == fresh.page.content &&
  old.page.retained_source == fresh.page.retained_source
}

///|
fn book_collection_refresh(
  state : BookSearchState,
  request : Int,
  revision : Int,
  candidate : BookCollectionItem,
) -> BookCollectionState {
  let collection = state.collection
  guard request == state.page_request &&
    revision == collection.revision &&
    book_collection_refresh_candidate(state) == Some(candidate) &&
    collection.items.search_by(item => {
      item.page.citation == candidate.page.citation
    })
    is Some(index) else {
    return collection
  }
  let outgoing = collection.items[index]
  if book_collection_snapshot_unchanged(outgoing, candidate) {
    return {
      ..collection,
      notice: Some(
        "Inspection unchanged: text, title and supplied source binding match. No snapshot or history was changed.",
      ),
    }
  }
  if collection.history.length() >= 48 {
    return {
      ..collection,
      notice: Some(
        "History holds up to 48 outgoing snapshots. Refresh refused without discarding history. Save this collection before starting another.",
      ),
    }
  }
  // Both the outgoing version and the replacement must fit; never evict history.
  let size = (collection.items + collection.history).fold(
    init=candidate.page.content.length(),
    (size, item) => size + item.page.content.length(),
  )
  if size > 1048576 {
    return {
      ..collection,
      notice: Some(
        "Refresh exceeds the 1,048,576 code-unit limit including history. Current snapshot, notes and history kept without truncation.",
      ),
    }
  }
  let items = collection.items.copy()
  items[index] = { ..candidate, note: outgoing.note, }
  let refreshed = {
    ..collection,
    items,
    history: collection.history + [outgoing],
    revision: collection.revision + 1,
    notice: Some(
      "Collected snapshot refreshed explicitly. Note and position kept; outgoing snapshot and its note retained in collection JSON history. This is not factual acceptance.",
    ),
  }
  match book_collection_decode_archive(book_collection_archive(refreshed)) {
    Ok(_) => refreshed
    Err(message) =>
      { ..collection, notice: Some("Refresh refused: " + message), }
  }
}

///|
fn book_collection_comparison(
  emit : @rabbita.Emit[Msg],
  state : BookSearchState,
) -> @rabbita.Html {
  guard book_collection_refresh_candidate(state) is Some(candidate) else {
    return @html.div("")
  }
  let index = state.collection.items
    .search_by(item => item.page.citation == candidate.page.citation)
    .unwrap()
  let old = state.collection.items[index]
  let unchanged = book_collection_snapshot_unchanged(old, candidate)
  @html.details([
    @html.summary("Compare with collected snapshot"),
    @html.p("Same Book-relative citation: " + candidate.page.citation),
    @html.p(
      "Check that this is the same Book, especially after resuming a supplied archive. No cross-Book identity or factual verification is implied.",
    ),
    @html.p(
      if unchanged {
        "Unchanged: text, title and supplied source binding match. Search question and result position alone do not create a new snapshot."
      } else {
        "Snapshot changed. Compare the complete old and fresh inspections before replacing."
      },
    ),
    wiki_review_text("Collected title", old.title),
    wiki_review_text(
      "Fresh title from search (may predate inspection)",
      candidate.title,
    ),
    wiki_review_text("Collected text", old.page.content),
    wiki_review_text("Fresh inspected text", candidate.page.content),
    wiki_review_text(
      "Collected supplied source binding",
      old.page.retained_source.to_json().stringify(),
    ),
    wiki_review_text(
      "Fresh supplied source binding",
      candidate.page.retained_source.to_json().stringify(),
    ),
    wiki_review_text("Your note (kept on refresh)", old.note),
    @html.p(
      "Refresh preserves your note and selection order. The outgoing complete snapshot and note are retained in the resumable JSON archive. Nothing is saved automatically; refresh does not accept a claim.",
    ),
    @html.button(
      disabled=unchanged,
      on_click=emit(
        BookSearch(
          RefreshCollected(
            state.page_request,
            state.collection.revision,
            candidate,
          ),
        ),
      ),
      "Refresh snapshot and retain history",
    ),
  ])
}
