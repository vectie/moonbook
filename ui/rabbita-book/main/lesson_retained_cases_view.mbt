///|
fn lesson_retained_cases_view(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
  inspection : Json,
) -> @rabbita.Html {
  let catalog = lesson_task_field(inspection, "retained")
  let entries = match lesson_task_field(catalog, "items") {
    Array(values) => values
    _ => []
  }
  let unavailable = match lesson_task_field(catalog, "unavailable") {
    Array(values) => values
    _ => []
  }
  let eligible = lesson_task_field(inspection, "eligible") == true.to_json()
  @html.section([
    @html.h4("Reuse this lesson's retained teaching examples"),
    @html.p(
      "Choose remembered examples to preserve while correcting this lesson. Their input, earlier successful output, literal checks and source attribution stay unchanged. Only the new revised output is editable. Add a new adverse case; nothing runs automatically.",
    ),
    @html.p(lesson_task_text(catalog, "notice")),
    @html.div(
      entries.map(entry => {
        @html.article([
          @html.strong(lesson_task_text(entry, "name")),
          @html.details([
            @html.summary("Inspect remembered input, output and checks"),
            @html.p("Input · " + lesson_task_text(entry, "input")),
            @html.pre(
              style=["white-space:pre-wrap"],
              "Remembered successful output · " +
              lesson_task_text(entry, "original"),
            ),
            @html.pre(
              style=["white-space:pre-wrap"],
              "Required fragments · " +
              lesson_task_text(entry, "required") +
              "\nForbidden fragments · " +
              lesson_task_text(entry, "forbidden"),
            ),
            @html.p(
              "Retained in accepted lesson · " +
              lesson_task_field(
                lesson_task_field(entry, "retained_from"),
                "lesson",
              ).stringify(),
            ),
          ]),
          @html.button(
            disabled=state.pending || !eligible,
            on_click=emit(
              OutcomeLesson(
                RevisionRehearsal(
                  lesson_revision_rehearsal_action(
                    state.history,
                    "reuse",
                    case_id=lesson_task_text(entry, "id"),
                  ),
                ),
              ),
            ),
            "Reuse retained example · " + lesson_task_text(entry, "name"),
          ),
        ])
      }),
    ),
    @html.ul(
      unavailable.map(entry => {
        @html.li(
          lesson_task_text(entry, "name") +
          ": " +
          lesson_task_text(entry, "reason"),
        )
      }),
    ),
  ])
}
