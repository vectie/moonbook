///|
fn lesson_scope_view(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let state = model.outcome_lessons
  let binding = lesson_scope_binding(state)
  let answers = lesson_scope_answers(state)
  let stale = lesson_task_field(state.scope_interview, "binding") !=
    Json::null() &&
    lesson_task_field(state.scope_interview, "binding") != binding
  let send = fn(action, condition) {
    emit(
      OutcomeLesson(
        ScopeInterview(action, state.scope_interview, binding, condition),
      ),
    )
  }
  let busy = state.pending || state.browser.pending
  @html.section(
    id="lesson-scope-interview",
    style=[
      "display:grid", "gap:10px", "padding:14px", "border:1px solid #64748b",
    ],
    [
      @html.h4("Which past lessons fit this task?"),
      @html.p(
        "Browse reviewed lessons above, then answer only what you know is true for the next task. These values come from past lessons, not evidence about your task. Unanswered questions stay unknown. Other values can be entered in the task conditions below.",
      ),
      if state.browser.data is None {
        @html.p(
          "Load reviewed lessons above to discover their scope questions. No answers are inferred from a title or topic.",
        )
      } else if stale {
        @html.p(
          attrs=@html.Attrs::build().role("alert"),
          "Task or reviewed lessons changed. Discard the staged answers and start again.",
        )
      } else {
        @html.div(
          lesson_scope_questions(state).map(c => {
            let text = lesson_task_text(c, "key") +
              "=" +
              lesson_task_text(c, "value")
            @html.button(
              disabled=busy,
              on_click=send("answer", c),
              "This task has " + text,
            )
          }),
        )
      },
      @html.p("Staged answers (not yet applied to retrieval)"),
      @html.div(
        answers.map(c => {
          @html.div([
            @html.span(
              lesson_task_text(c, "key") + "=" + lesson_task_text(c, "value"),
            ),
            @html.button(
              disabled=busy || stale,
              on_click=send("remove", c),
              "Remove this answer",
            ),
          ])
        }),
      ),
      @html.button(
        disabled=busy || stale || answers.is_empty(),
        on_click=send("apply", Json::null()),
        "Apply my answers and find lessons",
      ),
      @html.button(
        disabled=busy,
        on_click=send("reset", Json::null()),
        "Discard scope answers",
      ),
      if stale {
        @html.nothing
      } else {
        match (state.browser.data, lesson_scope_conditions(state)) {
          (Some(data), Ok(conditions)) =>
            @html.div(
              data.lessons.map(entry => {
                let lesson = lesson_record_value(entry.lesson).unwrap()
                @html.article([
                  @html.strong(entry.lesson.title),
                  @html.p(lesson_scope_status(lesson, conditions)),
                  @html.p(
                    "Required: " +
                    outcome_lesson_condition_lines(
                      lesson_task_field(lesson, "applicability"),
                    ).join("; "),
                  ),
                  @html.p(
                    "Do not use when: " +
                    outcome_lesson_condition_lines(
                      lesson_task_field(lesson, "invalidation"),
                    ).join("; "),
                  ),
                ])
              }),
            )
          (_, Err(error)) => @html.p(error)
          _ => @html.nothing
        }
      },
      @html.p(
        "A scope match does not establish applicability or attach guidance. The Book host rechecks current reviewed versions on retrieval; the existing explicit lesson selection and destination confirmation are still required.",
      ),
    ],
  )
}
