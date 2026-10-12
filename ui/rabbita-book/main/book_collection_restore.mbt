///|
// Move the exact historical envelope back to active. A replacement exchanges
// slots, preserving both complete snapshots without growing the text budget.
fn book_collection_restore_history(
  state : BookCollectionState,
  revision : Int,
  index : Int,
) -> BookCollectionState {
  guard revision == state.revision &&
    index >= 0 &&
    index < state.history.length() else {
    return state
  }
  let selected = state.history[index]
  let existing = state.items.search_by(item => {
    item.page.citation == selected.page.citation
  })
  guard existing is Some(_) || state.items.length() < 12 else {
    return {
      ..state,
      notice: Some(
        "This historical citation is not active and all 12 selection slots are full. Remove a selection or save this collection first. Nothing changed.",
      ),
    }
  }
  let items = state.items.copy()
  let history = []
  for i, item in state.history {
    if i != index {
      history.push(item)
    }
  }
  match existing {
    Some(active) => {
      history.push(items[active])
      items[active] = selected
    }
    None => items.push(selected)
  }
  {
    ..state,
    items,
    history,
    revision: state.revision + 1,
    merge_plan: None,
    notice: Some(
      "Historical snapshot restored with its original title, complete inspection and researcher note. Any displaced active snapshot and note are retained at the end of history. This is a research selection change, not a live Book edit or fresh verification. Save JSON to keep it.",
    ),
  }
}
