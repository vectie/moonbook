///|
fn lesson_comparison_textarea(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
  field : String,
  value : String,
  label : String,
  reference? : Json = Json::null(),
  stale? : Bool = false,
) -> @rabbita.Html {
  @html.label(style=["display:grid", "gap:5px"], [
    @html.span(label),
    @html.textarea(
      value~,
      attrs=@html.Attrs::build().aria_label(label),
      disabled=state.pending || stale,
      on_input=value => {
        emit(
          OutcomeLesson(
            Comparison(
              lesson_comparison_action(
                state,
                "edit",
                field~,
                value~,
                reference~,
              ),
            ),
          ),
        )
      },
      style=[
        "width:100%", "box-sizing:border-box", "min-height:100px", "font:inherit",
      ],
      ([] : Array[@rabbita.Html]),
    ),
  ])
}

///|
fn lesson_comparison_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  let inspection = lesson_comparison_transition(state, { "kind": "inspect" })
  let current = lesson_task_field(inspection, "current") == true.to_json()
  let preview_current = lesson_task_field(inspection, "preview_current") ==
    true.to_json()
  let entries = match lesson_task_field(state.comparison, "entries") {
    Array(values) => values
    _ => []
  }
  if entries.is_empty() {
    return @html.p(
      "Compare reviewed approaches: find useful lessons for a task, then add two to four candidates using Add to approach comparison.",
    )
  }
  let preview = lesson_task_field(state.comparison, "preview")
  let rows = match lesson_task_field(preview, "rows") {
    Array(values) => values
    _ => []
  }
  let scores = match lesson_task_field(preview, "scores") {
    Array(values) => values
    _ => []
  }
  let columns = entries.mapi((index, entry) => {
    let lesson = lesson_task_field(entry, "lesson")
    let reference = lesson_task_field(lesson, "reference")
    let score = scores.get(index).unwrap_or(Json::null())
    let all_pass = preview_current &&
      lesson_task_field(score, "reference") == reference &&
      lesson_task_field(score, "passed") == lesson_task_field(score, "total")
    @html.article(
      style=[
        "display:grid", "gap:8px", "padding:14px", "border:1px solid #64748b", "border-radius:12px",
        "min-width:0",
      ],
      [
        @html.h4(lesson_task_text(lesson, "title")),
        @html.p(
          "Reviewed by " +
          lesson_task_text(lesson, "reviewer") +
          " · version " +
          lesson_task_text(reference, "record_version"),
        ),
        @html.p(
          style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
          lesson_task_text(lesson, "guidance"),
        ),
        @html.details([
          @html.summary("Scope and exact evidence for this approach"),
          @html.ul(
            outcome_lesson_condition_lines(
              lesson_task_field(lesson, "applicability"),
            ).map(line => @html.li(line)),
          ),
          @html.strong("Do not use when"),
          @html.ul(
            outcome_lesson_condition_lines(
              lesson_task_field(lesson, "invalidation"),
            ).map(line => @html.li(line)),
          ),
          @html.pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            [
              outcome_lesson_reference_line("Lesson", reference),
              outcome_lesson_reference_line(
                "Named review",
                lesson_task_field(lesson, "review"),
              ),
              outcome_lesson_reference_line(
                "Original outcome",
                lesson_task_field(
                  lesson_task_field(lesson, "source"),
                  "outcome",
                ),
              ),
            ].join("\n\n"),
          ),
        ]),
        lesson_comparison_textarea(
          emit,
          state,
          "output",
          lesson_task_text(entry, "output"),
          "Supplied output using " + lesson_task_text(lesson, "title"),
          reference~,
          stale=!current,
        ),
        if preview_current {
          @html.div([
            @html.strong(
              lesson_task_field(score, "passed").stringify() +
              "/" +
              lesson_task_field(score, "total").stringify() +
              " literal checks passed",
            ),
            @html.ul(
              rows.map(row => {
                let passed = match lesson_task_field(row, "passed") {
                  Array(values) => values.get(index) == Some(true.to_json())
                  _ => false
                }
                @html.li(
                  (if passed { "Pass · " } else { "Fail · " }) +
                  lesson_task_text(row, "text"),
                )
              }),
            ),
          ])
        } else {
          @html.nothing
        },
        @html.button(
          disabled=state.pending,
          on_click=emit(
            OutcomeLesson(
              Comparison(lesson_comparison_action(state, "remove", reference~)),
            ),
          ),
          "Remove this approach",
        ),
        if state.task_guidance.handoff is Some(_) {
          @html.button(
            class="moonbook-primary-action",
            disabled=state.pending ||
              !all_pass ||
              task_guidance_incoming_origin().is_empty() ||
              state.task_guidance.confirmed_handoff !=
              state.task_guidance.handoff ||
              state.task_guidance.confirmed_origin !=
              task_guidance_incoming_origin(),
            on_click=emit(
              OutcomeLesson(
                Comparison(lesson_comparison_action(state, "use", reference~)),
              ),
            ),
            "Use this compared guidance for " + lesson_field(state, "task-id"),
          )
        } else {
          @html.p(
            "Open guidance from Proj to return one compared version to its exact task.",
          )
        },
      ],
    )
  })
  @html.section(
    id="lesson-approach-comparison",
    style=["display:grid", "gap:12px"],
    [
      @html.h4("Compare reviewed approaches for this task"),
      @html.p(
        "Shortlist two to four reviewed lessons. Supply the output obtained or written using each approach for the same fixed task/example. No model runs here. The comparison tests literal text only; it cannot prove which guidance caused an output or will generalize.",
      ),
      @html.p(
        "Bound task · " +
        lesson_task_field(
          lesson_task_field(state.comparison, "query"),
          "target_task",
        ).stringify(),
      ),
      if !current {
        @html.p(
          attrs=@html.Attrs::build().role("alert"),
          "This comparison is stale or unavailable. Find lessons for the exact task again. If the task or reviewed versions changed, clear and rebuild the shortlist. Your supplied outputs are kept here until you clear it.",
        )
      } else {
        @html.nothing
      },
      lesson_comparison_textarea(
        emit,
        state,
        "input",
        lesson_task_text(state.comparison, "input"),
        "Same fresh task or example for every approach",
        stale=!current,
      ),
      lesson_comparison_textarea(
        emit,
        state,
        "checks",
        lesson_task_text(state.comparison, "checks"),
        "Shared required literal text, one check per line",
        stale=!current,
      ),
      @html.p(
        "Use 1–20 distinct case-sensitive checks, at most 512 characters each. Surrounding line whitespace is removed. Each input/output is limited to 16384 characters; no text is silently truncated.",
      ),
      @html.div(
        style=[
          "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,280px),1fr))",
          "gap:12px",
        ],
        columns,
      ),
      @html.button(
        disabled=state.pending || !current || entries.length() < 2,
        on_click=emit(
          OutcomeLesson(Comparison(lesson_comparison_action(state, "compare"))),
        ),
        "Compare these supplied outputs",
      ),
      if preview_current {
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          "Approaches passing every check: " +
          lesson_task_field(preview, "all_pass_count").stringify() +
          ". No winner was selected. Review the differences and explicitly choose one passing approach; ties remain your decision.",
        )
      } else {
        @html.p(
          "Compare again after any change to the shortlist, task, example, outputs or checks.",
        )
      },
      @html.button(
        disabled=state.pending,
        on_click=emit(
          OutcomeLesson(Comparison(lesson_comparison_action(state, "clear"))),
        ),
        "Clear comparison and keep lesson draft",
      ),
      @html.p(
        "This comparison stays in this tab and is lost on reload. Choosing guidance uses the existing host recheck and confirmed Proj destination. Outputs and check results stay in Book's tab; no review, accepted memory, capability activation or execution is created by this comparison.",
      ),
    ],
  )
}
