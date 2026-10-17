///|
fn lesson_repair_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  @html.details([
    @html.summary("Learn from a later-task failure · narrow lesson scope"),
    @html.p(
      "Choose the current human-reviewed lesson above. Describe a later task where it applied but failed, then choose the distinguishing condition to exclude. This is your unverified report, not an automatic finding. Drafts stay in this tab.",
    ),
    @html.button(
      disabled=state.pending ||
        state.repair != Json::null() ||
        lesson_task_field(lesson_repair_context(state), "eligible") !=
        Json::boolean(true),
      on_click=emit(OutcomeLesson(Repair("begin", "", ""))),
      "Start failure case for current lesson",
    ),
    if state.repair == Json::null() {
      @html.nothing
    } else {
      @html.div(style=["display:grid", "gap:10px"], [
        @html.div([
          @html.label([
            @html.span("Later task ID"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label("Later task ID"),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "task-id",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "task-id", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Exact later task version"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label("Exact later task version"),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "task-version",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "task-version", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Exact later task digest"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label("Exact later task digest"),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "task-digest",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "task-digest", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Evidence reference to the observed failure"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label(
                "Evidence reference to the observed failure",
              ),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "evidence",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "evidence", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("What happened despite following the lesson?"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label(
                "What happened despite following the lesson?",
              ),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "observation",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "observation", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Actual later-task conditions · one key=value per line"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label(
                "Actual later-task conditions · one key=value per line",
              ),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "conditions",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "conditions", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Distinguishing failure condition name"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label(
                "Distinguishing failure condition name",
              ),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "exclude-key",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "exclude-key", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Distinguishing failure condition value"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label(
                "Distinguishing failure condition value",
              ),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "exclude-value",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "exclude-value", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
          @html.label([
            @html.span("Unused lesson version for narrowed scope"),
            @html.textarea(
              attrs=@html.Attrs::build().aria_label(
                "Unused lesson version for narrowed scope",
              ),
              value=lesson_task_text(
                lesson_task_field(state.repair, "fields"),
                "version",
              ),
              disabled=state.pending,
              on_input=value => {
                emit(OutcomeLesson(Repair("edit", "version", value)))
              },
              ([] : Array[@rabbita.Html]),
            ),
          ]),
        ]),
        @html.button(
          disabled=state.pending,
          on_click=emit(OutcomeLesson(Repair("preview", "", ""))),
          "Preview narrower scope",
        ),
        if lesson_task_field(state.repair, "preview") == Json::null() {
          @html.nothing
        } else {
          @html.div([
            @html.p("Proposed complete do-not-use conditions:"),
            @html.pre(
              lesson_task_text(
                lesson_task_field(state.repair, "preview"),
                "invalidation",
              ),
            ),
            @html.p(
              "All original required conditions and guidance are preserved. This excludes the reported case; it does not prove the remaining scope works.",
            ),
            @html.button(
              disabled=state.pending,
              on_click=emit(OutcomeLesson(Repair("stage", "", ""))),
              "Stage narrowed revision for review",
            ),
          ])
        },
        @html.button(
          disabled=state.pending,
          on_click=emit(OutcomeLesson(Repair("discard", "", ""))),
          "Discard unsaved failure case",
        ),
      ])
    },
    @html.p(
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      state.notice,
    ),
  ])
}
