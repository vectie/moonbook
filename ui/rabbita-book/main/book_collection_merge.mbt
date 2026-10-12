///|
struct BookCollectionMergePlan {
  revision : Int
  request : Int
  choices : Map[String, Bool]
} derive(Debug, Eq)

///|
fn book_collection_merge_choices(
  state : BookCollectionState,
) -> Map[String, Bool] {
  match state.merge_plan {
    Some(plan) if plan.revision == state.revision &&
      plan.request == state.import_request => plan.choices
    _ => {}
  }
}

///|
fn book_collection_merge_choice(
  state : BookCollectionState,
  revision : Int,
  request : Int,
  citation : String,
  imported : Bool,
) -> BookCollectionState {
  guard revision == state.revision && request == state.import_request else {
    return state
  }
  guard book_collection_decode_archive(state.import_text) is Ok(archive) else {
    return state
  }
  guard archive.items.any(item => item.page.citation == citation) &&
    state.items.any(item => item.page.citation == citation) else {
    return state
  }
  let choices = book_collection_merge_choices(state).copy()
  choices[citation] = imported
  { ..state, merge_plan: Some({ revision, request, choices, }), notice: None, }
}

///|
fn book_collection_merge_result(
  state : BookCollectionState,
  archive : BookCollectionArchive,
) -> Result[BookCollectionState, String] {
  let choices = book_collection_merge_choices(state)
  let items = state.items.copy()
  let history = state.history + archive.history
  for incoming in archive.items {
    match
      items.search_by(item => item.page.citation == incoming.page.citation) {
      None => items.push(incoming)
      Some(index) => {
        let current = items[index]
        if current != incoming {
          guard choices.get(incoming.page.citation) is Some(use_imported) else {
            return Err(
              "Choose the active snapshot for every citation collision before combining. Current collection kept.",
            )
          }
          if use_imported {
            history.push(current)
            items[index] = incoming
          } else {
            history.push(incoming)
          }
        }
      }
    }
  }
  let combined = {
    ..state,
    items,
    history,
    revision: state.revision + 1,
    import_request: state.import_request + 1,
    import_text: "",
    merge_plan: None,
    notice: Some(
      "Collections combined. Current title and synthesis kept; new citations appended. Both histories and unchosen collision snapshots, including notes, are retained in JSON. No Book data or review state changed.",
    ),
  }
  match book_collection_decode_archive(book_collection_archive(combined)) {
    Ok(_) => Ok(combined)
    Err(message) =>
      Err(
        "Combination exceeds collection limits or contains invalid data. " +
        message,
      )
  }
}

///|
fn book_collection_merge_apply(
  state : BookCollectionState,
  revision : Int,
  request : Int,
) -> BookCollectionState {
  guard revision == state.revision && request == state.import_request else {
    return state
  }
  match book_collection_decode_archive(state.import_text) {
    Err(message) => { ..state, notice: Some(message), }
    Ok(archive) =>
      match book_collection_merge_result(state, archive) {
        Ok(combined) => combined
        Err(message) => { ..state, notice: Some(message), }
      }
  }
}

///|
fn book_collection_merge_panel(
  send : @rabbita.Emit[BookCollectionMsg],
  state : BookCollectionState,
  archive : BookCollectionArchive,
) -> @rabbita.Html {
  let choices = book_collection_merge_choices(state)
  let collisions = archive.items.filter(incoming => {
    state.items.any(current => {
      current.page.citation == incoming.page.citation && current != incoming
    })
  })
  @html.details([
    @html.summary("Combine with current collection"),
    @html.p(
      "Confirm these saved sessions belong to the same Book: citations are Book-relative and cannot authenticate Book identity. The same citation in different Books does not prove the same source; combining cannot infer their identity. Current title and synthesis stay unchanged. New citations append in incoming order; existing selection positions stay unchanged. Each collision needs your choice; the other snapshot and its note are retained in JSON history.",
    ),
    wiki_review_text("Incoming title (not automatically copied)", archive.title),
    wiki_review_text(
      "Incoming synthesis (copy into your synthesis editor if useful)",
      archive.purpose,
    ),
    @html.p(
      "Both historical sequences are retained, current then incoming, followed by displaced collision items. No global chronology is inferred. Combining the same file again may repeat historical entries. Save current JSON before combining if you need an independent checkpoint.",
    ),
    @html.div(
      collisions.map(incoming => {
        let current = state.items[state.items
          .search_by(item => item.page.citation == incoming.page.citation)
          .unwrap()]
        @html.article([
          @html.h4(incoming.page.citation),
          wiki_review_text(
            "Current complete snapshot and note",
            current.to_json().stringify(indent=2),
          ),
          wiki_review_text(
            "Incoming complete snapshot and note",
            incoming.to_json().stringify(indent=2),
          ),
          @html.p(
            match choices.get(incoming.page.citation) {
              Some(true) =>
                "Active choice: incoming; current retained in history."
              Some(false) =>
                "Active choice: current; incoming retained in history."
              None => "Choose which snapshot and note remain active."
            },
          ),
          @html.button(
            on_click=send(
              MergeChoice(
                state.revision,
                state.import_request,
                incoming.page.citation,
                false,
              ),
            ),
            "Keep current active",
          ),
          @html.button(
            on_click=send(
              MergeChoice(
                state.revision,
                state.import_request,
                incoming.page.citation,
                true,
              ),
            ),
            "Use incoming active",
          ),
        ])
      }),
    ),
    match book_collection_merge_result(state, archive) {
      Ok(combined) =>
        @html.p(
          "Ready: " +
          combined.items.length().to_string() +
          " active selections and " +
          combined.history.length().to_string() +
          " historical snapshots. Exact identical selections are included once.",
        )
      Err(message) => @html.p(message)
    },
    @html.button(
      on_click=send(ApplyMerge(state.revision, state.import_request)),
      "Combine collections and retain snapshots",
    ),
    @html.button(on_click=send(CancelMerge), "Cancel combination choices"),
  ])
}
