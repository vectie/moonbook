///|
fn lesson_practice_retest_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let workspace = model.outcome_lessons
  let state = workspace.teaching_brief
  guard state.practice.retest is Some(prepared) else { return @html.div("") }
  let send = action => {
    emit(OutcomeLesson(TeachingBrief(state.revision, Practice(action))))
  }
  let ready = !workspace.pending &&
    lesson_practice_retest_ready(state, workspace.browser, prepared)
  @html.section([
    @html.h4("Retest a recorded task with current reviewed guidance"),
    @html.p(
      "Source: round " +
      (prepared.round + 1).to_string() +
      " · practice " +
      (prepared.index + 1).to_string(),
    ),
    @html.p("Exact historical task to reuse"),
    @html.pre(style=["white-space:pre-wrap"], prepared.historical.exercise),
    @html.p("Selected next-task text that will be replaced"),
    @html.pre(style=["white-space:pre-wrap"], prepared.selected.exercise),
    @html.div([
      @html.section([
        @html.h4("Historical guidance, scope and reviews"),
        @html.pre(
          style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
          ToJson::to_json(prepared.historical.snapshot).stringify(indent=2),
        ),
      ]),
      @html.section([
        @html.h4("Selected current guidance, scope and reviews"),
        @html.pre(
          style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
          ToJson::to_json(prepared.selected.snapshot).stringify(indent=2),
        ),
      ]),
    ]),
    @html.p(
      "Inspect any changed applicability or invalidation conditions before proceeding. This prepares an exercise; it does not establish that the guidance applies, that these versions have a predecessor relationship, or that an agent improved. Current means matched at the latest successful host read. Imported history remains an unverified operator report.",
    ),
    if ready {
      @html.p(
        "Only the exact task text will replace the selected next task. Both recorded guidance captures and all observations stay unchanged. Use the ordinary next-round control afterward; fresh observations start blank.",
      )
    } else {
      @html.p(
        "This preview is no longer current or a request is pending. Recheck guidance and prepare a new preview before replacement.",
      )
    },
    @html.button(
      disabled=!ready,
      on_click=send(ApplyRetest),
      "Replace next task with previewed historical task",
    ),
    @html.button(on_click=send(CancelRetest), "Cancel retest preparation"),
  ])
}
