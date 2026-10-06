///|
fn wiki_review_notice(text : String, error? : Bool = false) -> @rabbita.Html {
  @html.p(
    attrs=@html.Attrs::build()
      .role(if error { "alert" } else { "status" })
      .aria_live("polite"),
    style=[
      "margin:0",
      "padding:12px",
      "border-radius:12px",
      "overflow-wrap:anywhere",
      if error {
        "background:#fee2e2"
      } else {
        "background:#eff6ff"
      },
      if error {
        "color:#991b1b"
      } else {
        "color:#1e3a8a"
      },
      "line-height:1.6",
    ],
    text,
  )
}

///|
fn wiki_review_text(label : String, text : String) -> @rabbita.Html {
  @html.section(style=["display:grid", "gap:8px", "min-width:0"], [
    @html.h3(style=["margin:0", "font-size:17px"], label),
    @html.pre(
      style=[
        "margin:0", "padding:14px", "background:#f1f5f9", "border:1px solid #cbd5e1",
        "border-radius:12px", "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:32rem",
        "overflow:auto", "font-size:13px", "line-height:1.65",
      ],
      if text.is_empty() {
        "No text attached to this review."
      } else {
        text
      },
    ),
  ])
}

///|
fn wiki_review_detail_view(
  emit : @rabbita.Emit[WikiReviewMsg],
  state : WikiReviewState,
  detail : WikiReviewDetail,
) -> @rabbita.Html {
  let approve : WikiReviewChoice = {
    review_id: detail.review_id,
    digest: detail.review_digest,
    decision: "approve",
  }
  let reject = { ..approve, decision: "reject", }
  let actions_disabled = !wiki_review_choice_is_current(state, approve)
  let actions : Array[@rabbita.Html] = if detail.can_resolve {
    [
      @html.button(
        class="moonbook-primary-action",
        title="Prepare approval of this exact local Book review",
        disabled=actions_disabled,
        on_click=emit(Prepare(approve)),
        "Approve in Book…",
      ),
      @html.button(
        class="moonbook-secondary-action",
        title="Prepare rejection of this exact local Book review",
        disabled=actions_disabled,
        on_click=emit(Prepare(reject)),
        "Reject in Book…",
      ),
    ]
  } else {
    [
      wiki_review_notice(
        "This review cannot be resolved again. Current local status: \{detail.status}.",
      ),
    ]
  }
  @html.article(
    style=[
      "display:grid", "gap:18px", "padding:18px", "border:2px solid #93c5fd", "border-radius:18px",
      "min-width:0",
    ],
    [
      @html.div([
        @html.h3(
          style=["margin:0 0 8px", "overflow-wrap:anywhere"],
          detail.title,
        ),
        @html.p(style=["margin:0", "overflow-wrap:anywhere"], [
          @html.strong("Exact review ID: "),
          @html.code(detail.review_id),
        ]),
        @html.p(
          style=["margin:8px 0 0", "overflow-wrap:anywhere"],
          "Kind: \{detail.kind} · Status: \{detail.status}",
        ),
        @html.details([
          @html.summary("Content verification details"),
          @html.p(
            style=["margin:8px 0 0", "overflow-wrap:anywhere", "font-size:12px"],
            "Displayed-content digest: \{detail.review_digest}",
          ),
        ]),
      ]),
      wiki_review_notice(
        "Local Book review only. Approval or rejection updates this Book. Original-task/goal acceptance remains unevaluated.",
      ),
      wiki_review_text("Complete review text", detail.review_text),
      wiki_review_text("Result / source text", detail.result_text),
      wiki_review_text("Evidence text", detail.evidence_text),
      match detail.native_binding {
        Some(binding) =>
          @html.details([
            @html.summary("Review provenance"),
            wiki_review_text(
              "Native record binding (informative)",
              binding.stringify(indent=2),
            ),
          ])
        None =>
          wiki_review_notice(
            "Legacy/local review: no native record binding is attached. This does not establish original-task acceptance.",
          )
      },
      @html.div(style=["display:flex", "gap:10px", "flex-wrap:wrap"], actions),
      match state.confirmation {
        Some(choice) =>
          @html.section(
            attrs=@html.Attrs::build().aria_label(
              "Confirm exact local Book decision",
            ),
            style=[
              "display:grid", "gap:12px", "padding:14px", "background:#fef3c7", "border:1px solid #d97706",
              "border-radius:12px",
            ],
            [
              @html.p(
                style=["margin:0", "overflow-wrap:anywhere"],
                "Confirm \{choice.decision} for exact review ID \{choice.review_id}? This saves a local Book decision for the displayed content digest. Original-task/goal acceptance remains unevaluated.",
              ),
              @html.div(style=["display:flex", "gap:10px", "flex-wrap:wrap"], [
                @html.button(
                  class="moonbook-primary-action",
                  disabled=!wiki_review_choice_is_current(state, choice),
                  on_click=emit(Confirm(choice)),
                  "Confirm \{choice.decision} in Book",
                ),
                @html.button(
                  class="moonbook-secondary-action",
                  on_click=emit(Cancel),
                  "Cancel",
                ),
              ]),
            ],
          )
        None => @html.div("")
      },
    ],
  )
}

///|
fn wiki_review_panel(
  emit : @rabbita.Emit[Msg],
  state : WikiReviewState,
  title? : String = "Local Book review queue",
  subtitle? : String = "Inspect an exact queued review, read its source and evidence, then explicitly approve or reject it in this Book.",
) -> @rabbita.Html {
  let review_emit = emit.map(message => WikiReview(message))
  let busy = state.pending is Some(_)
  let cards = state.items.map(item => {
    @html.article(
      style=[
        "display:grid", "gap:10px", "padding:14px", "border:1px solid #cbd5e1", "border-radius:14px",
        "overflow-wrap:anywhere",
      ],
      [
        @html.h3(style=["margin:0", "font-size:17px"], item.title),
        @html.p(style=["margin:0"], [
          @html.strong("Review ID: "),
          @html.code(item.review_id),
        ]),
        @html.p(
          style=["margin:0", "color:#475569"],
          "\{item.kind} · \{item.status}",
        ),
        @html.button(
          class="moonbook-secondary-action",
          title="Inspect exact review \{item.review_id}",
          disabled=busy || state.queue_loading || !state.queue_loaded,
          on_click=review_emit(Select(item.review_id)),
          if state.selected_id == Some(item.review_id) {
            "Inspect again"
          } else {
            "Inspect review"
          },
        ),
      ],
    )
  })
  @html.section(
    id="reviews",
    attrs=@html.Attrs::build().aria_label("Local Book review queue"),
    style=panel_style() +
      ["padding:22px", "display:grid", "gap:16px", "min-width:0"],
    [
      @html.div(
        style=[
          "display:flex", "justify-content:space-between", "gap:12px", "flex-wrap:wrap",
        ],
        [
          @html.div([
            @html.h2(style=["margin:0 0 6px", "font-size:24px"], title),
            @html.p(style=muted_text_style() + ["margin:0"], subtitle),
          ]),
          @html.button(
            class="moonbook-secondary-action",
            disabled=busy,
            on_click=review_emit(Reload),
            "Reload queue and detail",
          ),
        ],
      ),
      wiki_review_notice(
        "These decisions are scoped to local Book review. Original-task/goal acceptance remains unevaluated. Bookkeeper has its own separate review workflow.",
      ),
      match state.notice {
        Some(notice) => wiki_review_notice(notice)
        None => @html.div("")
      },
      match state.readback_notice {
        Some(notice) => wiki_review_notice(notice)
        None => @html.div("")
      },
      match state.queue_error {
        Some(error) =>
          wiki_review_notice(
            "Queue unavailable: \{error} Reload to recover; no decision is enabled from stale queue data.",
            error=true,
          )
        None => @html.div("")
      },
      if state.queue_loading {
        wiki_review_notice("Loading the complete review queue…")
      } else if state.queue_loaded && state.items.is_empty() {
        wiki_review_notice(
          "No pending local Book reviews. This is not a claim that any original task or goal has been accepted.",
        )
      } else if state.queue_loaded {
        @html.p(
          style=["margin:0", "font-weight:700"],
          "All \{state.items.length()} queued reviews",
        )
      } else {
        @html.div("")
      },
      if state.detail_loading {
        wiki_review_notice(
          "Reading exact review \{state.selected_id.unwrap_or("")} and its complete source/evidence text…",
        )
      } else {
        @html.div("")
      },
      match state.detail_error {
        Some(error) =>
          wiki_review_notice(
            "Review detail unavailable: \{error} Use Reload queue and detail to retry safely.",
            error=true,
          )
        None => @html.div("")
      },
      match state.detail {
        Some(detail) => wiki_review_detail_view(review_emit, state, detail)
        None => @html.div("")
      },
      @html.h3(style=["margin:0", "font-size:17px"], "Review queue"),
      @html.div(style=["display:grid", "gap:12px"], cards),
    ],
  )
}
