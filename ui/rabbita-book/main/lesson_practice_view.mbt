///|
fn lesson_practice_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons.teaching_brief
  let browser = model.outcome_lessons.browser
  let work = state.practice
  let send = action => {
    emit(OutcomeLesson(TeachingBrief(state.revision, Practice(action))))
  }
  @html.section(
    attrs=@html.Attrs::build().aria_label("Agent practice workbook"),
    style=[
      "display:grid", "gap:12px", "padding:12px", "border:1px solid #475569",
    ],
    [
      @html.h3("Agent practice workbook · observe a learning session"),
      @html.p(
        "Start from the rechecked teaching brief above, with a fresh task for every lesson. The workbook fixes that exact task/lesson sequence so later brief edits cannot move your observations to different exercises. Conduct practice separately, then paste the responses and describe what changed. No model runs, automatic grades or accepted lessons are created.",
      ),
      if work.session is None {
        @html.button(
          disabled=!lesson_teaching_ready(state, browser) ||
            !state.draft.items.all(item => !item.exercise.is_blank()),
          on_click=send(Start),
          "Start practice from this teaching brief",
        )
      } else {
        @html.nothing
      },
      match work.session {
        None =>
          @html.p(
            "No local practice session. Start one above or resume its JSON below.",
          )
        Some(session) =>
          @html.div([
            lesson_practice_progression_view(emit, model, session),
            @html.h4(
              "Current round " +
              (session.previous_rounds.length() + 1).to_string() +
              " · editable observations",
            ),
            lesson_notebook_field(
              "Learner / session label · operator supplied",
              session.learner,
              value => send(Learner(value)),
            ),
            @html.p("Captured objective: " + session.teaching.objective),
            @html.details([
              @html.summary("Import recorded practice responses from CSV"),
              @html.p(
                "Copy this current-round template into a spreadsheet. Keep its first six identity columns unchanged. Fill response columns, paste CSV into the intake below, then Preview CSV and explicitly replace with the preview. Blank cells leave existing observations alone; conflicting responses are refused. No model is run or learning accepted.",
              ),
              @html.pre(
                style=["white-space:pre-wrap"],
                lesson_practice_csv_bridge(
                  ToJson::to_json(session).stringify(),
                  "",
                  true,
                ),
              ),
              lesson_notebook_field("Practice responses CSV", work.intake, value => {
                send(Intake(value))
              }),
              @html.button(
                on_click=send(PreviewCsv),
                "Preview recorded responses CSV",
              ),
            ]),
            @html.div(
              session.teaching.items.mapi((index, item) => {
                let observation = session.observations[index]
                @html.article(
                  style=["display:grid", "gap:8px", "padding:12px"],
                  [
                    @html.h4(
                      "Practice " +
                      (index + 1).to_string() +
                      " · " +
                      item.snapshot.title,
                    ),
                    @html.p(
                      if lesson_teaching_matches(item, browser) {
                        "Historical capture matches the currently loaded lesson; this does not verify the responses."
                      } else {
                        "Historical capture is not matched to a currently loaded lesson. Responses stay attached to the captured task; recheck guidance before reuse."
                      },
                    ),
                    @html.pre(style=["white-space:pre-wrap"], item.exercise),
                    @html.details([
                      @html.summary(
                        "Inspect fixed lesson and exercise snapshot",
                      ),
                      @html.pre(
                        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                        ToJson::to_json(item).stringify(indent=2),
                      ),
                    ]),
                    lesson_notebook_field(
                      "First response · practice " + (index + 1).to_string(),
                      observation.before,
                      value => send(Edit(index, "before", value)),
                    ),
                    lesson_notebook_field(
                      "Response after feedback · practice " +
                      (index + 1).to_string(),
                      observation.after,
                      value => send(Edit(index, "after", value)),
                    ),
                    lesson_notebook_field(
                      "Feedback / observed difference · practice " +
                      (index + 1).to_string(),
                      observation.feedback,
                      value => send(Edit(index, "feedback", value)),
                    ),
                    lesson_notebook_field(
                      "Next practice / proposed correction · practice " +
                      (index + 1).to_string(),
                      observation.next_practice,
                      value => send(Edit(index, "next_practice", value)),
                    ),
                    @html.button(
                      disabled=model.outcome_lessons.pending,
                      on_click=emit(
                        OutcomeLesson(
                          PracticeCorrection(
                            state.revision,
                            model.outcome_lessons.request,
                            lesson_practice_correction_owner(model),
                            Choose(index),
                          ),
                        ),
                      ),
                      "Prepare practice " +
                      (index + 1).to_string() +
                      " for correction",
                    ),
                  ],
                )
              }),
            ),
            lesson_practice_correction_view(emit, model),
            @html.section([
              @html.h4("Practice again without losing this experience"),
              @html.p(
                "Write the next tasks in the teaching brief above and recheck its lessons. You may retry the same task or capture a new task or lesson version. Starting seals this round as read-only in Book and captures the current brief into a new blank round. Missing observations remain unrecorded; no improvement is inferred.",
              ),
              @html.p("Next round objective: " + state.draft.objective),
              @html.details([
                @html.summary("Inspect next round's exact teaching brief"),
                @html.pre(
                  style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                  ToJson::to_json(state.draft).stringify(indent=2),
                ),
              ]),
              @html.button(
                disabled=!lesson_practice_next_ready(state, browser),
                on_click=send(NextRound),
                "Seal this round and start the next",
              ),
              @html.p(
                if session.previous_rounds.length() >= 11 {
                  "This workbook has reached 12 rounds. Save it, then start a separate workbook."
                } else {
                  "Requires at least one recorded first response, a task for every next lesson and a successful current-lesson recheck. Save JSON before leaving."
                },
              ),
            ]),
            @html.button(
              on_click=send(Export(false)),
              "Save editable practice-workbook JSON",
            ),
            @html.button(
              on_click=send(Export(true)),
              "Download practice report Markdown",
            ),
            @html.p(
              "Save the workbook before discarding or reloading. This separate file includes fixed guidance, tasks and your responses; review private information before sharing. The ordinary teaching-brief JSON does not include this workbook.",
            ),
            @html.button(
              on_click=send(Discard),
              "Discard local practice workbook",
            ),
          ])
      },
      @html.details([
        @html.summary(
          "Inspect and apply a CSV preview, or resume saved workbook JSON",
        ),
        @html.p(
          "Paste and preview its complete JSON, then explicitly replace the open practice session. Save your open workbook first. Import keeps historical captures; it neither verifies a run nor changes the teaching brief above.",
        ),
        lesson_notebook_field("Saved practice-workbook JSON", work.intake, value => {
          send(Intake(value))
        }),
        @html.button(on_click=send(Preview), "Preview practice workbook"),
        match work.preview {
          None => @html.nothing
          Some(preview) =>
            @html.div([
              @html.pre(
                style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                ToJson::to_json(preview).stringify(indent=2),
              ),
              @html.button(
                on_click=send(Restore),
                "Replace local practice with this preview",
              ),
            ])
        },
      ]),
    ],
  )
}
