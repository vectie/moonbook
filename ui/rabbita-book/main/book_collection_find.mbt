///|
struct BookCollectionFindHit {
  historical : Bool
  index : Int
  item : BookCollectionItem
  excerpts : Array[(String, String)]
} derive(Debug, Eq)

///|
// Escape every regex operator: the user's query is always a literal phrase.
// Match offsets refer to original text, so case folding cannot shift excerpts.
extern "js" fn book_collection_find_excerpt(
  text : String,
  query : String,
) -> String =
  #| (text, query) => {
  #|   query = query.trim();
  #|   if (!query || query.length > 200) return "";
  #|   const pattern = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  #|   const match = new RegExp(pattern, "iu").exec(text);
  #|   if (!match) return "";
  #|   const before = Array.from(text.slice(0, match.index));
  #|   const after = Array.from(text.slice(match.index + match[0].length));
  #|   return (before.length > 70 ? "…" : "") + before.slice(-70).join("") + match[0] + after.slice(0, 70).join("") + (after.length > 70 ? "…" : "");
  #| }

///|
fn book_collection_find(
  state : BookCollectionState,
) -> Array[BookCollectionFindHit] {
  let hits = []
  if state.find_text.trim().is_empty() || state.find_text.length() > 200 {
    return hits
  }
  for historical in [false, true] {
    if (historical && state.find_scope == "active") ||
      (!historical && state.find_scope == "history") {
      continue
    }
    let items = if historical { state.history } else { state.items }
    for index, item in items {
      let fields = [
        ("Title", item.title),
        ("Book-relative citation", item.page.citation),
        ("Original search question", item.page.question),
        ("Researcher note", item.note),
        ("Snapshot text", item.page.content),
      ]
      if item.page.retained_source is Some(source) {
        fields.push(("Retained source reference", source.reference))
        fields.push(("Supplied page digest", source.page_digest))
      }
      let excerpts = []
      for (label, text) in fields {
        let excerpt = book_collection_find_excerpt(text, state.find_text)
        if !excerpt.is_empty() {
          excerpts.push((label, excerpt))
        }
      }
      if !excerpts.is_empty() {
        hits.push({ historical, index, item, excerpts, })
      }
    }
  }
  hits
}

///|
fn book_collection_find_panel(
  send : @rabbita.Emit[BookCollectionMsg],
  state : BookCollectionState,
) -> @rabbita.Html {
  let hits = book_collection_find(state)
  @html.section(
    attrs=@html.Attrs::build().aria_label("Find in collection snapshots"),
    style=[
      "display:grid", "gap:10px", "padding:12px", "border:1px solid #cbd5e1",
    ],
    [
      @html.h4("Find in collection snapshots"),
      @html.label(
        for_="collection-find",
        "Literal phrase in snapshots, notes or source references",
      ),
      @html.input(id="collection-find", value=state.find_text, on_input=text => {
        send(FindText(text))
      }),
      @html.div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
        @html.button(
          disabled=state.find_scope == "all",
          on_click=send(FindScope("all")),
          "Active and history",
        ),
        @html.button(
          disabled=state.find_scope == "active",
          on_click=send(FindScope("active")),
          "Active only",
        ),
        @html.button(
          disabled=state.find_scope == "history",
          on_click=send(FindScope("history")),
          "History only",
        ),
        @html.button(on_click=send(FindText("")), "Clear phrase"),
      ]),
      @html.p(
        "Case-insensitive literal matching; no regex or fuzzy search. Leading/trailing whitespace is ignored. First match in each field has up to 70 characters of context on each side. This searches retained snapshots, not the live Book or original raw files. Search does not limit any download.",
      ),
      if state.find_text.trim().is_empty() {
        @html.p(
          "Enter a phrase to find an earlier claim or your research note.",
        )
      } else {
        @html.div([
          @html.p(
            hits.length().to_string() +
            " matching snapshots; scope: " +
            state.find_scope +
            ". Positions are original collection positions, not result ranks.",
          ),
          if hits.is_empty() {
            @html.p(
              "No matching snapshots in this scope. Try another phrase or include history.",
            )
          } else {
            @html.div("")
          },
          @html.div(
            hits.map(hit => {
              let location = (if hit.historical {
                  "Historical snapshot "
                } else {
                  "Active selection "
                }) +
                (hit.index + 1).to_string()
              @html.article(
                style=[
                  "padding:12px", "border:1px solid #cbd5e1", "overflow-wrap:anywhere",
                ],
                [
                  @html.h4(location + ": " + hit.item.title),
                  @html.p(hit.item.page.citation),
                  @html.div(
                    hit.excerpts.map(pair => {
                      wiki_review_text(
                        pair.0 + " — first matching excerpt",
                        pair.1,
                      )
                    }),
                  ),
                  @html.details([
                    @html.summary("Read complete matching snapshot and note"),
                    wiki_review_text(
                      "Complete inspection envelope",
                      hit.item.page.to_json().stringify(indent=2),
                    ),
                    wiki_review_text("Researcher note", hit.item.note),
                  ]),
                  if hit.historical {
                    @html.div([
                      @html.p(
                        "Restoring moves this exact title, inspection and note to active. A displaced active snapshot and its note move to history. This changes your collection; save JSON to retain it.",
                      ),
                      match
                        state.items.search_by(item => {
                          item.page.citation == hit.item.page.citation
                        }) {
                        Some(index) =>
                          @html.details([
                            @html.summary(
                              "Compare active snapshot that will move to history",
                            ),
                            wiki_review_text(
                              "Active title",
                              state.items[index].title,
                            ),
                            wiki_review_text(
                              "Active inspection",
                              state.items[index].page
                              .to_json()
                              .stringify(indent=2),
                            ),
                            wiki_review_text(
                              "Active note",
                              state.items[index].note,
                            ),
                          ])
                        None =>
                          @html.p(
                            if state.items.length() >= 12 {
                              "All 12 active slots are full. Save your collection and remove a selection before restoring this missing citation."
                            } else {
                              "This citation is not active; restoring appends it."
                            },
                          )
                      },
                      @html.button(
                        disabled=state.items.length() >= 12 &&
                          !state.items.any(item => {
                            item.page.citation == hit.item.page.citation
                          }),
                        on_click=send(RestoreHistory(state.revision, hit.index)),
                        "Restore matching historical snapshot " +
                        (hit.index + 1).to_string(),
                      ),
                    ])
                  } else {
                    @html.p(
                      "This snapshot is already active. Its note and ordering controls are below.",
                    )
                  },
                ],
              )
            }),
          ),
        ])
      },
    ],
  )
}
