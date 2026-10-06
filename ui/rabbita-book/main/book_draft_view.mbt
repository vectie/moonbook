///|
fn book_summary_editor(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let drafts = model.draft_recovery
  if model.bookkeeper_mode != "review" {
    return @html.nothing
  }
  @html.div(style=["display:grid", "gap:10px"], [
    @html.h3(style=["margin:0", "font-size:16px"], "Review summary"),
    @html.p(
      style=["margin:0", "font-size:13px", "color:#cbd5e1"],
      "Explain this decision in your own words. Save a local copy before reloading or leaving this page. Only this summary text is saved in this browser; evidence, permissions and technical JSON are not saved locally. Do not put credentials here.",
    ),
    @html.textarea(
      value=drafts.summary,
      attrs=@html.Attrs::build().aria_label("Review summary"),
      on_input=text => emit(DraftRecovery(EditSummary(text))),
      style=[
        "width:100%", "box-sizing:border-box", "min-height:130px", "padding:12px",
        "font:inherit", "line-height:1.5", "border-radius:12px", "border:1px solid #64748b",
        "color:#f8fafc", "background:#020617",
      ],
      ([] : Array[@rabbita.Html]),
    ),
    @html.div(style=["display:flex", "flex-wrap:wrap", "gap:8px"], [
      @html.button(
        class="moonbook-secondary-action",
        disabled=drafts.note_key is None || drafts.storage_pending,
        on_click=emit(DraftRecovery(SaveSummary)),
        "Save summary locally",
      ),
      @html.button(
        class="moonbook-secondary-action",
        disabled=drafts.saved is None || drafts.storage_pending,
        title="Replace the displayed summary with the saved local text; no review is submitted",
        on_click=emit(DraftRecovery(RestoreSummary)),
        "Restore saved summary",
      ),
      @html.button(
        class="moonbook-secondary-action",
        disabled=drafts.note_key is None || drafts.storage_pending,
        title="Remove the saved browser copy; the current text stays in this tab",
        on_click=emit(DraftRecovery(DiscardSummary)),
        "Discard saved summary",
      ),
    ]),
    if drafts.edited && drafts.saved != Some(drafts.summary) {
      @html.p(
        style=["margin:0", "font-size:13px", "color:#fde68a"],
        "This summary has changes that are not saved locally.",
      )
    } else {
      @html.nothing
    },
    match drafts.storage_notice {
      Some(notice) =>
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          style=["margin:0", "font-size:13px"],
          notice,
        )
      None => @html.nothing
    },
    if book_draft_is_stale(model) {
      @html.div([
        @html.p(
          "The record or reviewer evidence changed. Your text is retained; prepare again before saving this decision.",
        ),
        @html.button(
          class="moonbook-secondary-action",
          disabled=model.bookkeeper_busy,
          on_click=emit(PrepareBookkeeperReview(drafts.decision)),
          "Prepare with current evidence",
        ),
      ])
    } else {
      @html.nothing
    },
    if drafts.notes.filter(item => Some(item.key) != drafts.note_key).is_empty() {
      @html.nothing
    } else {
      @html.details([
        @html.summary("Other summary drafts retained in this tab"),
        @html.div(
          drafts.notes
          .filter(item => Some(item.key) != drafts.note_key)
          .map(item => {
            @html.div([
              @html.p(item.label),
              @html.pre(
                style=[
                  "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:220px",
                  "overflow:auto",
                ],
                item.text,
              ),
            ])
          }),
        ),
      ])
    },
  ])
}

///|
fn book_technical_recovery_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let drafts = model.draft_recovery
  if drafts.technical.is_empty() {
    return @html.nothing
  }
  @html.details([
    @html.summary("Technical edits retained in this tab"),
    @html.p(
      "These copies are kept in memory only. They are lost when this page closes or reloads. Restoring is available only for the same exact record, evidence, reviewer and operation.",
    ),
    if book_retained_text(drafts.technical, book_technical_context(model))
      is Some(_) &&
      !book_draft_is_stale(model) &&
      !book_draft_waiting_for_evidence(model) &&
      book_technical_restore_ready(model) {
      @html.button(
        disabled=model.bookkeeper_busy,
        on_click=emit(DraftRecovery(RestoreTechnical)),
        "Restore technical edits for this context",
      )
    } else {
      @html.nothing
    },
    @html.div(
      drafts.technical.map(item => {
        @html.details([
          @html.summary(item.label),
          @html.pre(
            style=[
              "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:260px",
              "overflow:auto",
            ],
            item.text,
          ),
        ])
      }),
    ),
  ])
}
