///|
fn lesson_practice_progression_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
  session : LessonPracticeSession,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  @html.section(
    attrs=@html.Attrs::build().aria_label("Practice round progression"),
    [
      @html.h4("Practice round progression"),
      lesson_practice_comparison_view(session),
      lesson_practice_search_view(emit, model, session),
      @html.p(
        "Round order records your explicit next-round actions, not verified execution times or a learning score. Earlier rounds keep their exact tasks, guidance, observations and gaps. Imported history remains an operator report.",
      ),
      @html.div(
        lesson_practice_rounds(session).mapi((round_index, round) => {
          let sealed = round_index < session.previous_rounds.length()
          @html.article(style=["padding:12px", "border:1px solid #64748b"], [
            @html.h4(
              "Round " +
              (round_index + 1).to_string() +
              (if sealed {
                " · sealed historical capture"
              } else {
                " · current editable round"
              }),
            ),
            @html.p(round.teaching.objective),
            @html.p("Captured learner / session label: " + round.learner),
            @html.p(
              round.observations
              .filter(o => !o.before.is_blank())
              .length()
              .to_string() +
              " of " +
              round.teaching.items.length().to_string() +
              " first responses recorded; " +
              round.observations
              .filter(o => !o.after.is_blank())
              .length()
              .to_string() +
              " after-feedback responses recorded. Counts describe entries only.",
            ),
            if sealed {
              @html.details([
                @html.summary(
                  "Read round " +
                  (round_index + 1).to_string() +
                  " tasks, responses and feedback",
                ),
                @html.div(
                  round.teaching.items.mapi((index, item) => {
                    let observation = round.observations[index]
                    @html.article([
                      @html.h4(
                        "Practice " +
                        (index + 1).to_string() +
                        " · " +
                        item.snapshot.title,
                      ),
                      @html.p("Exact task"),
                      @html.pre(
                        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                        item.exercise,
                      ),
                      @html.div(
                        [
                          ("First response", observation.before),
                          ("Response after feedback", observation.after),
                          (
                            "Feedback / observed difference",
                            observation.feedback,
                          ),
                          (
                            "Next practice / proposed correction",
                            observation.next_practice,
                          ),
                        ].map(pair => {
                          let (label, value) = pair
                          @html.div([
                            @html.p(label),
                            @html.pre(
                              style=[
                                "white-space:pre-wrap", "overflow-wrap:anywhere",
                              ],
                              if value.is_blank() {
                                "Not recorded."
                              } else {
                                value
                              },
                            ),
                          ])
                        }),
                      ),
                      @html.details([
                        @html.summary(
                          "Inspect this round's fixed lesson snapshot",
                        ),
                        @html.pre(
                          style=[
                            "white-space:pre-wrap", "overflow-wrap:anywhere",
                          ],
                          ToJson::to_json(item).stringify(indent=2),
                        ),
                      ]),
                      @html.button(
                        disabled=state.pending,
                        on_click=emit(
                          OutcomeLesson(
                            PracticeCorrection(
                              state.teaching_brief.revision,
                              state.request,
                              lesson_practice_correction_owner(model),
                              ChooseRound(round_index, index),
                            ),
                          ),
                        ),
                        "Prepare round " +
                        (round_index + 1).to_string() +
                        " practice " +
                        (index + 1).to_string() +
                        " for correction",
                      ),
                    ])
                  }),
                ),
              ])
            } else {
              @html.p("Record and edit this round below.")
            },
          ])
        }),
      ),
    ],
  )
}
