///|
fn lesson_teaching_brief_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons.teaching_brief
  let browser = model.outcome_lessons.browser
  let send = action => {
    emit(OutcomeLesson(TeachingBrief(state.revision, action)))
  }
  @html.section(
    id="agent-teaching-brief",
    attrs=@html.Attrs::build().aria_label("Agent teaching brief"),
    style=[
      "display:grid", "gap:12px", "border:1px solid #64748b", "padding:16px",
    ],
    [
      @html.h3("Agent teaching brief · build a learning sequence"),
      @html.p(
        "Select up to 12 reviewed lessons above. Put them in a useful teaching order, write a learning objective and optional fresh practice tasks, then download an agent-readable Markdown brief with exact scope, source references and retained examples. Selection and exercises are your authored choices; no model or learner is executed.",
      ),
      @html.p(
        "This draft lives in this tab. Save JSON to resume after reload. Markdown export needs all captures to match loaded current lessons. Files can contain private guidance and examples; share deliberately.",
      ),
      lesson_notebook_field(
        "Learning objective · authored",
        state.draft.objective,
        value => send(Objective(value)),
      ),
      @html.p(state.draft.items.length().to_string() + " lessons selected"),
      if state.draft.items.is_empty() {
        @html.p(
          "Browse reviewed lessons above and choose Add lesson to agent teaching brief.",
        )
      } else {
        @html.nothing
      },
      @html.div(
        state.draft.items.mapi((index, item) => {
          @html.article(
            style=[
              "display:grid", "gap:8px", "padding:12px", "border:1px solid #475569",
            ],
            [
              @html.h4((index + 1).to_string() + ". " + item.snapshot.title),
              @html.p(
                if browser.request <= state.recheck_after {
                  "Resumed capture: reload all reviewed lessons before reuse."
                } else if lesson_teaching_matches(item, browser) {
                  "Exact guidance, review and examples match the loaded current lesson."
                } else {
                  lesson_notebook_status(item.snapshot, browser) +
                  " Teaching examples also require an exact match. Remove and re-add deliberately if changed."
                },
              ),
              @html.p(style=["white-space:pre-wrap"], item.snapshot.guidance),
              @html.details([
                @html.summary(
                  "Inspect captured scope, reviews and source-linked examples",
                ),
                @html.pre(
                  style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                  ToJson::to_json(item.snapshot).stringify(indent=2),
                ),
                @html.p(item.example_notice),
                @html.pre(
                  style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                  ToJson::to_json(item.examples).stringify(indent=2),
                ),
              ]),
              lesson_notebook_field(
                "Fresh practice task · lesson " + (index + 1).to_string(),
                item.exercise,
                value => send(Exercise(index, value)),
              ),
              @html.div([
                @html.button(
                  disabled=index == 0,
                  on_click=send(Move(index, -1)),
                  "Move teaching lesson up",
                ),
                @html.button(
                  disabled=index + 1 == state.draft.items.length(),
                  on_click=send(Move(index, 1)),
                  "Move teaching lesson down",
                ),
                @html.button(
                  on_click=send(Remove(index)),
                  "Remove from teaching brief",
                ),
              ]),
            ],
          )
        }),
      ),
      @html.div([
        @html.button(
          disabled=browser.pending,
          on_click=send(Recheck),
          "Recheck all teaching lessons",
        ),
        @html.button(
          on_click=send(Download(false, browser.request)),
          "Save editable teaching-brief JSON",
        ),
        @html.button(
          disabled=!lesson_teaching_ready(state, browser),
          on_click=send(Download(true, browser.request)),
          "Download agent teaching brief Markdown",
        ),
      ]),
      @html.details([
        @html.summary("Resume a saved teaching brief"),
        @html.p(
          "Paste the complete JSON and inspect the replacement before confirming. Replacing discards this tab's open brief; save it first if needed. Imported captures cannot enable Markdown export until checked against a fresh host response.",
        ),
        lesson_notebook_field("Saved teaching-brief JSON", state.intake, value => {
          send(Intake(value))
        }),
        @html.button(on_click=send(Preview), "Preview saved teaching brief"),
        match state.preview {
          Some(preview) =>
            @html.div([
              @html.h4("Exact replacement preview"),
              @html.pre(
                style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                ToJson::to_json(preview).stringify(indent=2),
              ),
              @html.button(
                on_click=send(Restore),
                "Replace open teaching brief with this preview",
              ),
            ])
          None => @html.nothing
        },
      ]),
      lesson_practice_view(emit, model),
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
