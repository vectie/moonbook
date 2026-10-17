///|
fn lesson_rehearsal_result_view(result : Json) -> @rabbita.Html {
  guard result
    is {
      "checks": Array(checks),
      "baseline_passed": Number(before),
      "corrected_passed": Number(after),
      "total": Number(total),
      "improved": improved,
      "model_executed": false,
      "activation_authorized": false,
      ..
    } &&
    (improved is True || improved is False) else {
    return @html.p("The rehearsal result could not be read.")
  }
  let improved = improved == true.to_json()
  @html.div([
    @html.p(
      "Supplied baseline: " +
      before.to_string() +
      "/" +
      total.to_string() +
      " checks. Supplied correction: " +
      after.to_string() +
      "/" +
      total.to_string() +
      " checks.",
    ),
    @html.ul(
      checks.map(check => {
        match check {
          {
            "text": String(text),
            "baseline_passed": before,
            "corrected_passed": after,
            ..
          } if (before is True || before is False) &&
            (after is True || after is False) =>
            @html.li(
              text +
              " · baseline " +
              (if before == true.to_json() { "pass" } else { "fail" }) +
              " · correction " +
              (if after == true.to_json() { "pass" } else { "fail" }),
            )
          _ => @html.li("Unreadable check; repeat the rehearsal.")
        }
      }),
    ),
    @html.p(
      if improved {
        "All corrected-output checks pass, with at least one baseline failure. This is ready for your review of the example and guidance."
      } else {
        "No qualifying improvement: every corrected-output check must pass, with at least one baseline failure. Your draft is unchanged."
      },
    ),
    @html.p(
      "Literal matching checks only the supplied text. It does not establish factual correctness, successful model execution, or improvement on another example.",
    ),
  ])
}

///|
fn lesson_rehearsal_view(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
) -> @rabbita.Html {
  @html.details([
    @html.summary("Teach once · rehearse this correction"),
    @html.p(
      "Keep one completed example fixed. Paste its input and original output, then supply the output you expect after following your proposed guidance. No model or tool runs here. These exact texts and checks will be retained with the lesson for named-human review.",
    ),
    lesson_text_field(
      emit,
      state,
      "rehearsal-input",
      "Same example: task or input",
      tall=true,
    ),
    lesson_text_field(
      emit,
      state,
      "rehearsal-baseline",
      "Original output for this example",
      tall=true,
    ),
    lesson_text_field(
      emit,
      state,
      "rehearsal-corrected",
      "Corrected output for the same example",
      tall=true,
    ),
    lesson_text_field(
      emit,
      state,
      "rehearsal-checks",
      "Required literal text, one check per line",
      tall=true,
    ),
    @html.p(
      "Checks are case-sensitive text fragments, with surrounding line whitespace removed. Use 1–20 distinct checks. Every corrected-output check must pass and the original output must fail at least one.",
    ),
    @html.button(
      disabled=state.pending,
      on_click=emit(OutcomeLesson(TryRehearsal)),
      "Try correction on the same example",
    ),
    @html.button(
      disabled=state.pending || !lesson_rehearsal_has_inputs(state),
      on_click=emit(OutcomeLesson(ClearRehearsal)),
      "Clear rehearsal and keep lesson draft",
    ),
    match state.rehearsal_result {
      Some(result) =>
        if lesson_rehearsal_request(state) is Ok(current) &&
          state.rehearsal_request == Some(current) {
          lesson_rehearsal_result_view(result)
        } else {
          @html.p(
            "The draft or its source changed. Repeat the same-example rehearsal before saving.",
          )
        }
      None => @html.nothing
    },
    @html.button(
      class="moonbook-primary-action",
      disabled=state.pending || lesson_rehearsal_save_payload(state) is Err(_),
      on_click=emit(OutcomeLesson(Submit("prepare-rehearsal"))),
      "Save rehearsal-backed lesson for review",
    ),
    @html.p(
      "After acceptance, use Find useful lessons for the next task below. When opened from Proj, choose this exact guidance version for its named task, return to Proj and Start. Proj captures that version in the run request. Version history can prepare a reviewed rollback; it never rewrites an existing run.",
    ),
  ])
}

///|
fn lesson_rehearsal_review_view(record : BookkeeperRawRecord) -> @rabbita.Html {
  guard record.payload
    is {
      "candidate_schema": "outcome_lesson.rehearsed.v1",
      "rehearsal": {
        "example_input": String(input),
        "baseline_output": String(baseline),
        "corrected_output": String(corrected),
        ..
      },
      "rehearsal_result": result,
      ..
    } else {
    return @html.nothing
  }
  @html.details([
    @html.summary("Review the same-example rehearsal · supplied outputs"),
    @html.strong("Fixed example input"),
    @html.pre(style=["white-space:pre-wrap", "overflow-wrap:anywhere"], input),
    @html.strong("Original supplied output"),
    @html.pre(
      style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
      baseline,
    ),
    @html.strong("Corrected supplied output"),
    @html.pre(
      style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
      corrected,
    ),
    lesson_rehearsal_result_view(result),
    @html.p(
      "Acceptance makes this digest-bound lesson version available as scoped guidance. Repeated-finding capability promotion and its separate adoption review are unchanged.",
    ),
  ])
}
