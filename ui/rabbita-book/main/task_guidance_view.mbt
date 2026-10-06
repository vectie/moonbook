///|
fn task_guidance_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  if task_guidance_incoming_origin().is_empty() &&
    state.task_guidance.handoff is None {
    return @html.nothing
  }
  @html.section(id="task-guidance-query", style=["display:grid", "gap:10px"], [
    @html.h4("Use reviewed guidance for your next task"),
    @html.p(
      "Receive the task opened from Proj. Its exact identity and known project context are filled in for you. Add only truthful customer and decision conditions below, then find useful lessons.",
    ),
    @html.button(
      disabled=state.pending || task_guidance_incoming_origin().is_empty(),
      on_click=emit(OutcomeLesson(TaskGuidance(Receive))),
      "Receive task for guidance",
    ),
    if state.task_guidance.handoff is Some(handoff) {
      @html.div([
        @html.p(
          "Task received · " +
          lesson_task_text(
            lesson_task_field(handoff, "target_task"),
            "record_id",
          ),
        ),
        @html.p(
          "Requested destination · " +
          task_guidance_incoming_origin() +
          ". Confirm only if this is the Proj page you intended to use; the incoming link alone does not authorize sharing.",
        ),
        @html.button(
          disabled=state.pending || task_guidance_incoming_origin().is_empty(),
          on_click=emit(
            OutcomeLesson(
              TaskGuidance(
                ConfirmDestination(handoff, task_guidance_incoming_origin()),
              ),
            ),
          ),
          if state.task_guidance.confirmed_handoff == Some(handoff) &&
            state.task_guidance.confirmed_origin ==
            task_guidance_incoming_origin() {
            "Destination confirmed for this task"
          } else {
            "Allow selected guidance to this destination for this task"
          },
        ),
        @html.p(
          "Choosing Use returns this lesson's guidance, conditions and review references to " +
          task_guidance_incoming_origin() +
          ". Original outcome and assessment bodies stay in Book. This does not start a task, accept anything, or grant authority.",
        ),
        @html.p(
          "suite_product_id identifies the task's Moon Suite application. It is separate from a customer's product_id and from the application that supplied the original outcome.",
        ),
      ])
    } else {
      @html.nothing
    },
    @html.button(
      disabled=state.pending && !state.task_guidance.busy,
      on_click=emit(OutcomeLesson(TaskGuidance(Cancel))),
      "Cancel guidance handoff",
    ),
  ])
}
