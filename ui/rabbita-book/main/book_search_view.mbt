///|
fn book_search_panel(
  emit : @rabbita.Emit[Msg],
  state : BookSearchState,
) -> @rabbita.Html {
  let send = emit.map(message => BookSearch(message))
  @html.section(
    id="book-search",
    attrs=@html.Attrs::build().aria_label("Search this Book"),
    style=panel_style() +
      ["padding:24px", "display:grid", "gap:16px", "min-width:0"],
    [
      @html.h2(style=["margin:0", "font-size:28px"], "Search this Book"),
      @html.p(
        style=muted_text_style() + ["margin:0"],
        "Browse ranked excerpts from this Book's maintained pages, three per page within the first 30 matches. This is deterministic lexical search, not a generated answer or factual verification. Reviewed lessons have their own browser below.",
      ),
      @html.label(for_="book-search-question", "Your question"),
      @html.textarea(
        id="book-search-question",
        value=state.draft,
        attrs=@html.Attrs::build().aria_describedby("book-search-help"),
        style=[
          "width:100%", "box-sizing:border-box", "min-height:80px", "padding:12px",
          "font:inherit",
        ],
        on_input=text => send(Edit(text)),
        "",
      ),
      @html.small(
        id="book-search-help",
        "Use words from the pages; at least one term needs two characters. Maximum 1024 UTF-16 code units. Search does not save or change this Book.",
      ),
      @html.button(
        class="moonbook-primary-action",
        disabled=state.draft.trim().is_empty() || state.draft.length() > 1024,
        on_click=send(Search),
        if state.pending {
          "Search again"
        } else {
          "Search maintained pages"
        },
      ),
      if state.pending {
        wiki_review_notice(
          "Searching this Book… Previous results remain below until a new search succeeds.",
        )
      } else {
        @html.div("")
      },
      match state.error {
        Some(error) =>
          wiki_review_notice(
            error + " Previous successful results are preserved below.",
            error=true,
          )
        None => @html.div("")
      },
      match state.result {
        None => @html.p("Ask a question to find cited context in this Book.")
        Some(result) =>
          @html.div(style=["display:grid", "gap:14px"], [
            @html.h3(
              style=["margin:0", "overflow-wrap:anywhere"],
              "Results for: " + result.question,
            ),
            match result.paging {
              Some(paging) =>
                @html.div(style=["display:grid", "gap:8px"], [
                  @html.p(
                    "Results page " +
                    (paging.page + 1).to_string() +
                    ". Matched pages: " +
                    paging.matched_count.to_string() +
                    "; accessible window: " +
                    paging.window_count.to_string() +
                    "/30.",
                  ),
                  @html.p(
                    "Every search, page change and inspection scans current pages again. Rankings can change; this is not a saved snapshot.",
                  ),
                  if paging.truncated {
                    wiki_review_notice(
                      "Results truncated to the first 30 matches. Narrow your question to reach other pages.",
                    )
                  } else {
                    @html.div("")
                  },
                  @html.div(style=["display:flex", "gap:10px"], [
                    @html.button(
                      disabled=state.pending ||
                        state.draft != result.question ||
                        paging.page == 0,
                      on_click=send(Navigate(paging.page - 1)),
                      "Previous results",
                    ),
                    @html.button(
                      disabled=state.pending ||
                        state.draft != result.question ||
                        !paging.has_next,
                      on_click=send(Navigate(paging.page + 1)),
                      "Next results",
                    ),
                  ]),
                ])
              None => @html.div("")
            },
            if result.question != state.draft {
              wiki_review_notice(
                "These results belong to the displayed question above. Search again to use your edited question.",
              )
            } else {
              @html.div("")
            },
            if result.excerpts.is_empty() {
              wiki_review_notice(
                if result.paging is Some(paging) && paging.matched_count > 0 {
                  "No excerpts on this page in the current scan; other pages still match. Use Previous results or search again."
                } else {
                  "No matching maintained pages found. Try different words or inspect the Book's chapters."
                },
              )
            } else {
              @html.div("")
            },
            @html.div(
              style=["display:grid", "gap:14px"],
              result.excerpts.mapi((index, item) => {
                @html.article(
                  style=[
                    "padding:16px", "border:1px solid #cbd5e1", "border-radius:14px",
                    "display:grid", "gap:10px", "overflow-wrap:anywhere",
                  ],
                  [
                    @html.h3(
                      style=["margin:0"],
                      "[" +
                      (result.paging.map(p => p.page * 3).unwrap_or(0) +
                      index +
                      1).to_string() +
                      "] " +
                      item.title,
                    ),
                    @html.p(
                      style=[
                        "margin:0", "white-space:pre-wrap", "line-height:1.65",
                      ],
                      item.excerpt,
                    ),
                    @html.button(
                      class="moonbook-secondary-action",
                      disabled=state.pending || state.draft != result.question,
                      on_click=send(Inspect(item.citation)),
                      "Inspect maintained page",
                    ),
                    @html.details([
                      @html.summary("Citation and page metadata"),
                      @html.p(item.citation),
                      @html.p("Lexical score: " + item.score.to_string()),
                      @html.p(
                        "Page metadata status (unverified): " +
                        item.metadata_status,
                      ),
                      @html.p(
                        "Imported or maintained status labels are not factual review or original-task acceptance.",
                      ),
                    ]),
                  ],
                )
              }),
            ),
            @html.div(style=["display:flex", "gap:10px", "flex-wrap:wrap"], [
              @html.button(
                class="moonbook-secondary-action",
                on_click=send(Copy),
                "Copy context brief",
              ),
              @html.button(
                class="moonbook-secondary-action",
                on_click=send(Download),
                "Download context brief",
              ),
            ]),
            @html.details([
              @html.summary("Readable context brief"),
              wiki_review_text("Exact exported text", result.brief),
            ]),
          ])
      },
      match state.notice {
        Some(notice) => wiki_review_notice(notice)
        None => @html.div("")
      },
      if state.page_pending {
        wiki_review_notice("Reading the selected maintained page…")
      } else {
        @html.div("")
      },
      match state.page_error {
        Some(error) => wiki_review_notice(error, error=true)
        None => @html.div("")
      },
      match state.page {
        Some(page) =>
          @html.section(style=["display:grid", "gap:8px"], [
            @html.h3("Inspected maintained page"),
            @html.p(
              "Read from the current Book when Inspect was clicked. This may be newer than the search excerpt.",
            ),
            @html.details([
              @html.summary("Inspected citation"),
              @html.p(page.citation),
            ]),
            wiki_review_text("Complete page text", page.content),
            @html.button(
              disabled=state.pending ||
                state.page_pending ||
                state.draft != page.question,
              on_click=send(CollectPage),
              "Collect inspected page",
            ),
            book_collection_comparison(emit, state),
            match page.retained_source {
              Some(descriptor) =>
                @html.div(style=["display:grid", "gap:8px"], [
                  @html.p("Retained reference: " + descriptor.reference),
                  @html.button(
                    class="moonbook-secondary-action",
                    disabled=state.pending ||
                      state.page_pending ||
                      state.draft != page.question,
                    on_click=send(ReadRetained),
                    "Read retained source",
                  ),
                  @html.small(
                    "Reads the complete current retained file, up to 2 MiB. Remote captures may themselves be excerpts. These are retained bytes at inspection, not proof of original ingest bytes or factual review.",
                  ),
                ])
              None =>
                wiki_review_notice(
                  "Retained source unavailable. No unique, readable generated raw-source binding was found within this Book. The maintained page remains readable above.",
                )
            },
            if state.source_pending {
              wiki_review_notice(
                "Reading and checking retained source bytes…",
              )
            } else {
              @html.div("")
            },
            match state.source_error {
              Some(error) => wiki_review_notice(error, error=true)
              None => @html.div("")
            },
            match state.source {
              Some(source) =>
                @html.section(
                  style=["display:grid", "gap:8px", "min-width:0"],
                  [
                    @html.h3("Retained bytes at inspection"),
                    @html.p("Reference: " + source.reference),
                    @html.p("Bytes: " + source.size.to_string()),
                    @html.p(
                      style=["overflow-wrap:anywhere"],
                      "SHA-256: " + source.digest,
                    ),
                    @html.p(
                      "This download uses these exact inspected bytes, even if the file later changes. Re-read to inspect current bytes.",
                    ),
                    match source.text {
                      Some(text) =>
                        wiki_review_text("Complete retained UTF-8 text", text)
                      None =>
                        wiki_review_notice(
                          "Binary or non-UTF-8 retained source. No active preview is rendered; the bounded exact bytes are available to download.",
                        )
                    },
                    @html.button(
                      class="moonbook-secondary-action",
                      on_click=send(DownloadRetained),
                      "Download inspected retained bytes",
                    ),
                  ],
                )
              None => @html.div("")
            },
          ])
        None => @html.div("")
      },
      book_collection_panel(emit, state.collection),
    ],
  )
}
