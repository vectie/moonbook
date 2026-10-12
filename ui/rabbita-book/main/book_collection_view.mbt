///|
fn book_collection_panel(
  emit : @rabbita.Emit[Msg],
  state : BookCollectionState,
) -> @rabbita.Html {
  let send = emit.map(message => BookSearch(Collection(message)))
  @html.section(
    id="book-collection",
    attrs=@html.Attrs::build().aria_label("Research collection"),
    style=[
      "display:grid", "gap:12px", "padding:20px", "border:1px solid #cbd5e1", "border-radius:14px",
      "min-width:0",
    ],
    [
      @html.h3(
        "Research collection (" + state.items.length().to_string() + "/12)",
      ),
      @html.p(
        "Collect inspected pages across searches, compare snapshots and add notes. Download collection JSON to resume later, or a Markdown or offline HTML brief to read and share. This tab is not automatically saved.",
      ),
      @html.label(for_="book-collection-title", "Brief title"),
      @html.input(
        id="book-collection-title",
        value=state.title,
        on_input=text => send(Title(text)),
        style=["padding:10px", "font:inherit"],
      ),
      @html.label(
        for_="book-collection-purpose",
        "Research question and your synthesis",
      ),
      @html.textarea(
        id="book-collection-purpose",
        value=state.purpose,
        on_input=text => send(Purpose(text)),
        style=["min-height:100px", "padding:10px", "font:inherit"],
        "",
      ),
      @html.small(
        "Title: 160 code units. Synthesis and each note: 4,000. Up to 12 current and 48 historical snapshots, sharing a 1,048,576 code-unit text limit. Notes are yours; collecting does not review or accept a source.",
      ),
      book_collection_find_panel(send, state),
      if state.items.is_empty() {
        @html.p(
          "Inspect a search result above, then choose Collect inspected page.",
        )
      } else {
        @html.div("")
      },
      @html.div(
        style=["display:grid", "gap:12px"],
        state.items.mapi((index, item) => {
          let note_id = "book-collection-note-" + index.to_string()
          @html.article(
            style=[
              "display:grid", "gap:8px", "padding:16px", "border:1px solid #cbd5e1",
              "border-radius:10px", "overflow-wrap:anywhere",
            ],
            [
              @html.h4((index + 1).to_string() + ". " + item.title),
              @html.p(item.page.citation),
              @html.p("Found with: " + item.page.question),
              @html.details([
                @html.summary("Read collected snapshot"),
                @html.p(
                  "This snapshot is kept as collected. Later searches or file edits do not replace it.",
                ),
                wiki_review_text(
                  "Complete maintained-page snapshot",
                  item.page.content,
                ),
                match item.page.retained_source {
                  Some(source) =>
                    @html.p(
                      "Host-reported page SHA-256: " +
                      source.page_digest +
                      ". Retained reference: " +
                      source.reference,
                    )
                  None =>
                    @html.p(
                      "The host did not supply an inspection digest or retained binding for this page.",
                    )
                },
              ]),
              @html.label(
                for_=note_id,
                "Your note for selection " + (index + 1).to_string(),
              ),
              @html.textarea(
                id=note_id,
                value=item.note,
                on_input=text => send(Note(item.page.citation, text)),
                style=["min-height:90px", "padding:10px", "font:inherit"],
                "",
              ),
              @html.div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
                @html.button(
                  disabled=index == 0,
                  on_click=send(Move(item.page.citation, -1)),
                  "Move earlier",
                ),
                @html.button(
                  disabled=index == state.items.length() - 1,
                  on_click=send(Move(item.page.citation, 1)),
                  "Move later",
                ),
                @html.button(
                  on_click=send(Remove(item.page.citation)),
                  "Remove selection",
                ),
              ]),
            ],
          )
        }),
      ),
      @html.div(style=["display:flex", "gap:10px", "flex-wrap:wrap"], [
        @html.button(
          on_click=send(DownloadArchive),
          "Save resumable collection (.json)",
        ),
        @html.button(
          disabled=state.items.is_empty(),
          on_click=send(CopyBrief),
          "Copy research brief",
        ),
        @html.button(
          disabled=state.items.is_empty(),
          on_click=send(DownloadBrief),
          "Download research brief (.md)",
        ),
        @html.button(
          disabled=state.items.is_empty(),
          on_click=send(DownloadHtml),
          "Download offline brief (.html)",
        ),
      ]),
      @html.details([
        @html.summary(
          "Retained snapshot history (" +
          state.history.length().to_string() +
          "/48)",
        ),
        @html.p(
          "History is retention order, not a timeline. Compare a historical snapshot with the active selection below, then restore its exact title, inspection and note. The restored entry moves out of history; any displaced active selection moves to the end. Other entries keep their order. Missing active citations append, up to 12. Save JSON before leaving this tab.",
        ),
        @html.div(
          state.history.mapi((index, item) => {
            @html.details([
              @html.summary((index + 1).to_string() + ". " + item.page.citation),
              wiki_review_text("Historical title", item.title),
              wiki_review_text(
                "Historical inspection metadata and complete text",
                item.page.to_json().stringify(indent=2),
              ),
              wiki_review_text("Historical researcher note", item.note),
              match
                state.items.search_by(active => {
                  active.page.citation == item.page.citation
                }) {
                Some(active) =>
                  @html.details([
                    @html.summary(
                      "Compare active snapshot that will move to history",
                    ),
                    wiki_review_text("Active title", state.items[active].title),
                    wiki_review_text(
                      "Active inspection metadata and complete text",
                      state.items[active].page.to_json().stringify(indent=2),
                    ),
                    wiki_review_text(
                      "Active researcher note",
                      state.items[active].note,
                    ),
                  ])
                None =>
                  @html.p(
                    if state.items.length() >= 12 {
                      "This citation is not active and all 12 selection slots are full. Remove a selection to enable restoration. Save JSON first if you need its current snapshot and note."
                    } else {
                      "This citation is not active. Restoring appends it to the collection; existing selections keep their positions."
                    },
                  )
              },
              @html.button(
                disabled=state.items.length() >= 12 &&
                  !state.items.any(active => {
                    active.page.citation == item.page.citation
                  }),
                on_click=send(RestoreHistory(state.revision, index)),
                "Restore historical snapshot " +
                (index + 1).to_string() +
                " as active",
              ),
            ])
          }),
        ),
      ]),
      @html.details([
        @html.summary("Resume or combine a saved collection"),
        @html.p(
          "Open or paste a MoonBook collection JSON file. Resuming replaces the current selection, notes and synthesis; save them first. No Book files change. Imported snapshots and digest labels are supplied data and are not verified against this Book.",
        ),
        @html.button(on_click=send(OpenArchive), "Open collection JSON"),
        @html.label(for_="collection-archive-input", "Collection JSON"),
        @html.textarea(
          id="collection-archive-input",
          value=state.import_text,
          on_input=text => send(ArchiveDraft(text)),
          style=["width:100%", "min-height:120px"],
          "",
        ),
        match book_collection_decode_archive(state.import_text) {
          Ok(archive) =>
            @html.div([
              @html.p(
                "Ready to resume: " +
                archive.title +
                " (" +
                archive.items.length().to_string() +
                " selections)",
              ),
              @html.p(archive.items.map(item => item.page.citation).join("; ")),
              book_collection_merge_panel(send, state, archive),
              @html.button(
                on_click=send(ResumeArchive),
                "Replace collection and resume",
              ),
            ])
          Err(message) =>
            if state.import_text.is_empty() {
              @html.p("Choose a file or paste JSON to preview it.")
            } else {
              @html.p(message)
            }
        },
      ]),
      @html.details([
        @html.summary("Preview exact resumable JSON"),
        wiki_review_text(
          "Portable collection JSON",
          book_collection_archive(state),
        ),
      ]),
      @html.p(
        "Markdown and offline HTML briefs contain all current selections and notes, regardless of the finder. HTML includes complete snapshots, internal navigation and print styling. Neither reading format resumes a collection. Collection JSON also contains outgoing history and historical notes, even after an active selection is removed. Check its scope before sharing it. Original retained files are not embedded. Imported snapshots and digest labels are supplied data, not fresh Book verification. No Book files, review state or journals are changed.",
      ),
      match state.notice {
        Some(notice) => wiki_review_notice(notice)
        None => @html.div("")
      },
      if state.items.is_empty() {
        @html.div("")
      } else {
        @html.details([
          @html.summary("Preview exact research brief"),
          wiki_review_text("Exported Markdown", book_collection_brief(state)),
        ])
      },
    ],
  )
}
