///|
struct BookCollectionItem {
  title : String
  page : BookSearchPage
  note : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct BookCollectionState {
  find_text : String
  find_scope : String
  merge_plan : BookCollectionMergePlan?
  import_text : String
  import_request : Int
  title : String
  purpose : String
  items : Array[BookCollectionItem]
  history : Array[BookCollectionItem]
  revision : Int
  notice : String?
} derive(Debug)

///|
enum BookCollectionMsg {
  FindText(String)
  FindScope(String)
  RestoreHistory(Int, Int)
  MergeChoice(Int, Int, String, Bool)
  ApplyMerge(Int, Int)
  CancelMerge
  ArchiveDraft(String)
  OpenArchive
  ArchiveRead(Int, Result[String, String])
  ResumeArchive
  DownloadArchive
  Title(String)
  Purpose(String)
  Note(String, String)
  Move(String, Int)
  Remove(String)
  CopyBrief
  DownloadBrief
  DownloadHtml
  ExportedBrief(Int, Result[String, String])
} derive(Debug)

///|
fn book_collection_initial() -> BookCollectionState {
  {
    find_text: "",
    find_scope: "all",
    merge_plan: None,
    import_text: "",
    import_request: 0,
    title: "Research brief",
    purpose: "",
    items: [],
    history: [],
    revision: 0,
    notice: None,
  }
}

///|
fn book_collection_collect(state : BookSearchState) -> BookCollectionState {
  let collection = state.collection
  guard !state.pending &&
    !state.page_pending &&
    state.result is Some(result) &&
    state.page is Some(page) &&
    state.draft == result.question &&
    page.question == result.question &&
    state.selected == Some(page.citation) &&
    page.page == result.paging.map(p => p.page) &&
    result.excerpts.search_by(item => item.citation == page.citation)
    is Some(excerpt_index) else {
    return collection
  }
  if collection.items.any(item => item.page.citation == page.citation) {
    return {
      ..collection,
      notice: Some(
        "Already collected. Your earlier snapshot and notes were kept. Compare with the collected snapshot to refresh explicitly while preserving notes and history.",
      ),
    }
  }
  if collection.items.length() >= 12 {
    return {
      ..collection,
      notice: Some(
        "This collection holds up to 12 pages. Remove a selection or export this brief before starting another.",
      ),
    }
  }
  let size = (collection.items + collection.history).fold(
    init=page.content.length(),
    (size, item) => size + item.page.content.length(),
  )
  if size > 1048576 {
    return {
      ..collection,
      notice: Some(
        "The complete snapshots exceed the 1,048,576 UTF-16 code-unit collection limit. Nothing was truncated or added.",
      ),
    }
  }
  {
    ..collection,
    items: collection.items +
    [{ title: result.excerpts[excerpt_index].title, page, note: "", }],
    revision: collection.revision + 1,
    notice: Some(
      "Page snapshot collected. Keep searching to compare another source; download the brief before leaving this tab.",
    ),
  }
}

///|
fn book_collection_reduce(
  state : BookCollectionState,
  msg : BookCollectionMsg,
) -> (BookCollectionState, Array[BookSearchEffect]) {
  match msg {
    FindText(text) =>
      if text.length() <= 200 {
        ({ ..state, find_text: text, }, [])
      } else {
        (
          {
            ..state,
            notice: Some("Find a phrase of at most 200 UTF-16 code units."),
          },
          [],
        )
      }
    FindScope(scope) =>
      if scope == "all" || scope == "active" || scope == "history" {
        ({ ..state, find_scope: scope, }, [])
      } else {
        (state, [])
      }
    RestoreHistory(revision, index) =>
      (book_collection_restore_history(state, revision, index), [])
    MergeChoice(revision, request, citation, imported) =>
      (
        book_collection_merge_choice(
          state, revision, request, citation, imported,
        ),
        [],
      )
    ApplyMerge(revision, request) =>
      (book_collection_merge_apply(state, revision, request), [])
    CancelMerge =>
      (
        {
          ..state,
          merge_plan: None,
          import_request: state.import_request + 1,
          notice: Some("Combination cancelled. Current collection kept."),
        },
        [],
      )
    ArchiveDraft(text) => {
      if text.length() > 8_388_608 {
        return (
          {
            ..state,
            notice: Some("Archive exceeds the 8 Mi code-unit import limit."),
            import_request: state.import_request + 1,
          },
          [],
        )
      }
      (
        {
          ..state,
          import_text: text,
          import_request: state.import_request + 1,
          notice: None,
        },
        [],
      )
    }
    OpenArchive => {
      let request = state.import_request + 1
      (
        {
          ..state,
          import_request: request,
          notice: Some(
            "Choose a collection JSON file; review it before replacing this collection.",
          ),
        },
        [ReadArchive(request)],
      )
    }
    ArchiveRead(request, result) => {
      guard request == state.import_request else { return (state, []) }
      match result {
        Ok(text) =>
          if text.is_empty() {
            (state, [])
          } else {
            book_collection_reduce(state, ArchiveDraft(text))
          }
        Err(message) => ({ ..state, notice: Some(message), }, [])
      }
    }
    ResumeArchive =>
      match book_collection_decode_archive(state.import_text) {
        Ok(archive) =>
          (
            {
              ..state,
              title: archive.title,
              purpose: archive.purpose,
              items: archive.items,
              history: archive.history,
              revision: state.revision + 1,
              import_request: state.import_request + 1,
              import_text: "",
              notice: Some(
                "Collection resumed from a portable file. Imported snapshots and digest labels are supplied data, not newly verified Book inspections. Reinspect the same Book to check freshness.",
              ),
            },
            [],
          )
        Err(message) => ({ ..state, notice: Some(message), }, [])
      }
    DownloadArchive =>
      (state, [ExportArchive(state.revision, book_collection_archive(state))])
    Title(title) => {
      if title.length() > 160 {
        return (
          {
            ..state,
            notice: Some("Use a title of at most 160 UTF-16 code units."),
          },
          [],
        )
      }
      ({ ..state, title, revision: state.revision + 1, notice: None, }, [])
    }
    Purpose(purpose) => {
      if purpose.length() > 4000 {
        return (
          {
            ..state,
            notice: Some(
              "Keep the research question and synthesis within 4,000 UTF-16 code units.",
            ),
          },
          [],
        )
      }
      ({ ..state, purpose, revision: state.revision + 1, notice: None, }, [])
    }
    Note(citation, note) => {
      if note.length() > 4000 {
        return (
          {
            ..state,
            notice: Some(
              "Keep each selection note within 4,000 UTF-16 code units.",
            ),
          },
          [],
        )
      }
      if !state.items.any(item => item.page.citation == citation) {
        return (state, [])
      }
      (
        {
          ..state,
          items: state.items.map(item => {
            if item.page.citation == citation {
              { ..item, note, }
            } else {
              item
            }
          }),
          revision: state.revision + 1,
          notice: None,
        },
        [],
      )
    }
    Remove(citation) => {
      if !state.items.any(item => item.page.citation == citation) {
        return (state, [])
      }
      (
        {
          ..state,
          items: state.items.filter(item => item.page.citation != citation),
          revision: state.revision + 1,
          notice: Some(
            "Selection and its note removed from the active collection. Retained snapshot history is unchanged.",
          ),
        },
        [],
      )
    }
    Move(citation, direction) => {
      guard direction == -1 || direction == 1 else { return (state, []) }
      guard state.items.search_by(item => item.page.citation == citation)
        is Some(index) else {
        return (state, [])
      }
      let next = index + direction
      guard next >= 0 && next < state.items.length() else { return (state, []) }
      let items = state.items.copy()
      let prior = items[index]
      items[index] = items[next]
      items[next] = prior
      ({ ..state, items, revision: state.revision + 1, notice: None, }, [])
    }
    DownloadHtml => {
      guard !state.items.is_empty() else { return (state, []) }
      (
        state,
        [ExportCollectionHtml(state.revision, book_collection_html(state))],
      )
    }
    CopyBrief | DownloadBrief => {
      guard !state.items.is_empty() else { return (state, []) }
      (
        state,
        [
          ExportCollection(
            state.revision,
            book_collection_brief(state),
            msg is DownloadBrief,
          ),
        ],
      )
    }
    ExportedBrief(revision, result) => {
      guard revision == state.revision else { return (state, []) }
      (
        {
          ..state,
          notice: Some(
            match result {
              Ok(message) => message
              Err(message) => message
            },
          ),
        },
        [],
      )
    }
  }
}

///|
// Keep every source/note inert even when it contains Markdown fences or HTML.
fn book_collection_block(text : String) -> String {
  let mut longest = 2
  let mut run = 0
  for character in text.iter() {
    if character == '~' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
  }
  let fence = "~".repeat(longest + 1)
  fence + "text\n" + text + "\n" + fence + "\n"
}

///|
fn book_collection_brief(state : BookCollectionState) -> String {
  let parts = [
    "# MoonBook research collection\n",
    "Selected maintained-page snapshots and researcher notes. This is a personal research brief, not factual review or accepted knowledge.\n",
    "Portable collections may contain imported snapshots and digest labels. These are supplied data, not newly verified Book inspections.\n",
    "Book-relative citations apply only to the Book where this collection was assembled. Snapshots are from separate inspections, not an atomic Book revision. Reinspect the live Book to check for changes.\n",
    "## Title\n" + book_collection_block(state.title),
    "## Research question and synthesis (researcher-authored)\n" +
    book_collection_block(state.purpose),
    "Selections: " + state.items.length().to_string() + "\n",
    "Historical snapshots retained in the resumable JSON archive: " +
    state.history.length().to_string() +
    ". This reading brief contains current selections only.\n",
  ]
  for index, item in state.items {
    parts.push("## Selection " + (index + 1).to_string() + "\n")
    parts.push(
      "Title from search (may predate inspection):\n" +
      book_collection_block(item.title),
    )
    parts.push(
      "Book-relative citation:\n" + book_collection_block(item.page.citation),
    )
    parts.push(
      "Found with question:\n" + book_collection_block(item.page.question),
    )
    if item.page.page is Some(page) {
      parts.push("Search results page: " + (page + 1).to_string() + "\n")
    }
    match item.page.retained_source {
      Some(source) => {
        parts.push(
          "Host-reported maintained-page SHA-256 at inspection:\n" +
          book_collection_block(source.page_digest),
        )
        parts.push(
          "Retained source reference (original bytes are not included in this brief):\n" +
          book_collection_block(source.reference),
        )
      }
      None =>
        parts.push(
          "Inspection digest and retained source binding: not supplied by the host for this page.\n",
        )
    }
    parts.push("### Researcher note\n" + book_collection_block(item.note))
    parts.push(
      "### Complete maintained-page snapshot\n" +
      book_collection_block(item.page.content),
    )
  }
  parts.join("\n")
}
