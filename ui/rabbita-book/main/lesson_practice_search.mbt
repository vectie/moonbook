///|
fn lesson_practice_search(
  session : LessonPracticeSession,
  query : String,
) -> Array[(Int, Int)] {
  let found = []
  if query.is_blank() {
    return found
  }
  for round_index, round in lesson_practice_rounds(session) {
    for index, item in round.teaching.items {
      let observation = round.observations[index]
      if [
          round.learner,
          item.snapshot.title,
          item.exercise,
          observation.before,
          observation.after,
          observation.feedback,
          observation.next_practice,
        ].any(text => text.contains(query)) {
        found.push((round_index, index))
      }
    }
  }
  found
}

///|
fn lesson_practice_search_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
  session : LessonPracticeSession,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  let brief = state.teaching_brief
  let query = brief.practice.search
  let rounds = lesson_practice_rounds(session)
  let matches = lesson_practice_search(session, query)
  @html.details([
    @html.summary("Find a recorded practice experience"),
    lesson_notebook_field("Literal search across every round", query, value => {
      emit(
        OutcomeLesson(TeachingBrief(brief.revision, Practice(Search(value)))),
      )
    }),
    @html.p(
      "Case-sensitive search of learner labels, lesson titles, tasks, responses, feedback and next practice. Matches are recorded text, not evidence of learning.",
    ),
    @html.p(
      if query.is_blank() {
        "Enter text to search the workbook."
      } else {
        matches.length().to_string() + " matching practice entries"
      },
    ),
    @html.div(
      matches.map(pair => {
        let (round_index, index) = pair
        let round = rounds[round_index]
        let item = round.teaching.items[index]
        let observation = round.observations[index]
        @html.article([
          @html.h4(
            "Round " +
            (round_index + 1).to_string() +
            " · practice " +
            (index + 1).to_string() +
            " · " +
            item.snapshot.title,
          ),
          @html.p("Learner / session: " + round.learner),
          @html.div(
            [
              ("Task", item.exercise),
              ("First response", observation.before),
              ("After feedback", observation.after),
              ("Feedback", observation.feedback),
              ("Next practice", observation.next_practice),
            ].map(pair => {
              let (label, value) = pair
              @html.div([
                @html.p(label),
                @html.pre(style=["white-space:pre-wrap"], value),
              ])
            }),
          ),
          @html.button(
            disabled=state.pending ||
              lesson_practice_reuse_target(brief, state.browser, item) is None,
            on_click=emit(
              OutcomeLesson(
                TeachingBrief(
                  brief.revision,
                  Practice(ReuseTask(state.browser.request, round_index, index)),
                ),
              ),
            ),
            "Replace selected lesson's next task with this exact task",
          ),
          @html.p(
            "Copies only task text into the compatible selected teaching lesson. Inspect or edit it before starting the next round. Existing next-task text is replaced; recorded observations stay unchanged.",
          ),
          @html.button(
            disabled=state.pending ||
              lesson_practice_retest_target(brief, state.browser, item) is None,
            on_click=emit(
              OutcomeLesson(
                TeachingBrief(
                  brief.revision,
                  Practice(
                    PreviewRetest(state.browser.request, round_index, index),
                  ),
                ),
              ),
            ),
            "Preview this task with selected current guidance",
          ),
          @html.p(
            "After a reviewed version change, explicitly select and recheck that lesson in the teaching brief. Preview both versions and their scope before replacing its next task. The source lesson family, outcome and assessment must match; old responses never become new observations.",
          ),
          @html.button(
            disabled=state.pending,
            on_click=emit(
              OutcomeLesson(
                PracticeCorrection(
                  brief.revision,
                  state.request,
                  lesson_practice_correction_owner(model),
                  ChooseRound(round_index, index),
                ),
              ),
            ),
            "Prepare this experience for correction",
          ),
        ])
      }),
    ),
    lesson_practice_retest_view(emit, model),
  ])
}
