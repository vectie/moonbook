///|
fn lesson_notebook_field(
  label : String,
  value : String,
  change : (String) -> @rabbita.Cmd,
) -> @rabbita.Html {
  @html.label(style=["display:grid", "gap:4px"], [
    @html.span(label),
    @html.textarea(
      value~,
      attrs=@html.Attrs::build().aria_label(label),
      on_input=change,
      style=[
        "width:100%", "min-height:90px", "font:inherit", "box-sizing:border-box",
      ],
      ([] : Array[@rabbita.Html]),
    ),
  ])
}

///|
fn lesson_notebook_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons.notebook
  let send = action => emit(OutcomeLesson(Notebook(state.revision, action)))
  @html.section(
    id="lesson-decision-notebook",
    attrs=@html.Attrs::build().aria_label("Decision notebook"),
    style=[
      "display:grid", "gap:12px", "border:1px solid #64748b", "padding:16px",
    ],
    [
      @html.h3("Decision notebook · learn across experiences"),
      @html.p(
        "Add up to 12 reviewed lessons from any search, then explain how each experience applies to your decision. Keep supporting and conflicting guidance side by side. Nothing infers consensus or changes accepted knowledge.",
      ),
      @html.p(
        "This notebook lives in the current tab. Download JSON to resume after reload; HTML is an offline reading/printing output. Files can contain private experience and notes, so share them only with intended readers.",
      ),
      lesson_notebook_field(
        "Decision question · authored",
        state.draft.question,
        value => send(Edit("question", value)),
      ),
      lesson_notebook_field(
        "Proposed decision and reasoning · authored",
        state.draft.decision,
        value => send(Edit("decision", value)),
      ),
      lesson_notebook_field(
        "Uncertainty, contradiction and next check · authored",
        state.draft.uncertainty,
        value => send(Edit("uncertainty", value)),
      ),
      @html.p(state.draft.items.length().to_string() + " experiences selected"),
      if state.draft.items.is_empty() {
        @html.p(
          "Browse reviewed lessons above and choose Add experience to decision notebook.",
        )
      } else {
        @html.nothing
      },
      @html.div(
        state.draft.items.mapi((index, item) => {
          let s = item.snapshot
          @html.article(
            style=[
              "display:grid", "gap:8px", "padding:12px", "border:1px solid #475569",
            ],
            [
              @html.h4((index + 1).to_string() + ". " + s.title),
              @html.p(lesson_notebook_status(s, model.outcome_lessons.browser)),
              @html.p(style=["white-space:pre-wrap"], s.guidance),
              @html.p(
                "Captured reviewer: " +
                s.reviewer +
                " · version " +
                s.reference.record_version,
              ),
              @html.details([
                @html.summary("Captured scope and outcome"),
                @html.strong("Required scope"),
                @html.pre(s.applicability.stringify(indent=2)),
                @html.strong("Do not use when"),
                @html.pre(s.invalidation.stringify(indent=2)),
                @html.strong("Outcome and assessment"),
                @html.pre(
                  s.outcome.stringify(indent=2) +
                  "\n" +
                  s.assessment.stringify(indent=2),
                ),
                @html.strong("Exact captured lesson and review"),
                @html.pre(
                  ToJson::to_json(s.reference).stringify(indent=2) +
                  "\n" +
                  ToJson::to_json(s.accepted_review).stringify(indent=2),
                ),
              ]),
              @html.p("Your role for this experience: " + item.stance),
              @html.div(
                ["consider", "tension", "context"].map(role => {
                  @html.button(
                    disabled=item.stance == role,
                    on_click=send(EditItem(index, "stance", role)),
                    "Mark as " + role,
                  )
                }),
              ),
              lesson_notebook_field(
                "Application note · experience " + (index + 1).to_string(),
                item.note,
                value => send(EditItem(index, "note", value)),
              ),
              @html.div([
                @html.button(
                  disabled=index == 0,
                  on_click=send(Move(index, -1)),
                  "Move experience up",
                ),
                @html.button(
                  disabled=index + 1 == state.draft.items.length(),
                  on_click=send(Move(index, 1)),
                  "Move experience down",
                ),
                @html.button(
                  on_click=send(Remove(index)),
                  "Remove experience from notebook",
                ),
              ]),
            ],
          )
        }),
      ),
      @html.div([
        @html.button(
          disabled=model.outcome_lessons.browser.pending,
          on_click=send(Recheck),
          "Reload all reviewed lessons to recheck captures",
        ),
        @html.button(
          on_click=send(Download(false)),
          "Download editable notebook JSON",
        ),
        @html.button(
          disabled=state.draft.items.is_empty() ||
            state.draft.question.is_blank(),
          on_click=send(Download(true)),
          "Download offline decision notebook HTML",
        ),
      ]),
      @html.details([
        @html.summary("Resume a downloaded notebook"),
        @html.p(
          "Open your downloaded JSON as text and paste it here. Preview first; replacing discards this tab's open notebook, so download it first if needed. Imported review labels remain unverified until compared with fresh host results.",
        ),
        lesson_notebook_field("Saved decision-notebook JSON", state.intake, value => {
          send(Intake(value))
        }),
        @html.button(on_click=send(Preview), "Preview saved notebook"),
        match state.preview {
          Some(preview) =>
            @html.div([
              @html.h4(
                "Replacement preview · " +
                preview.items.length().to_string() +
                " experiences",
              ),
              @html.pre(
                style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                preview.to_json().stringify(indent=2),
              ),
              @html.button(
                on_click=send(Restore),
                "Replace open notebook with this preview",
              ),
            ])
          None => @html.nothing
        },
      ]),
      if state.notice.is_empty() {
        @html.nothing
      } else {
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          state.notice,
        )
      },
    ],
  )
}
