///|
fn outcome_lesson_condition_lines(value : Json) -> Array[String] {
  match value {
    Array(conditions) =>
      conditions.map(condition => {
        match condition {
          { "key": String(key), "value": String(value), .. } =>
            key + " = " + value
          _ =>
            "Condition could not be read. Inspect the exact evidence before reviewing."
        }
      })
    _ =>
      [
        "Conditions are unavailable. Inspect the exact evidence before reviewing.",
      ]
  }
}

///|
fn outcome_lesson_reference_line(label : String, value : Json) -> String {
  match value {
    {
      "record_id": String(id),
      "record_version": String(version),
      "record_digest": String(digest),
      ..
    } => label + ": " + id + " @ " + version + "\n" + digest
    _ => label + ": exact reference is unavailable"
  }
}

///|
fn outcome_lesson_review_detail(record : BookkeeperRawRecord) -> @rabbita.Html {
  guard lesson_record_value(record) is Some(lesson) else {
    return @html.nothing
  }
  guard lesson
    is {
      "guidance": String(guidance),
      "applicability": applicability,
      "invalidation": invalidation,
      "outcome": outcome,
      "assessment": assessment,
      "assessment_review": review,
      ..
    } else {
    return @html.p(
      "This lesson is incomplete. Inspect its exact evidence before reviewing.",
    )
  }
  let invalidation_lines = outcome_lesson_condition_lines(invalidation)
  @html.section(
    attrs=@html.Attrs::build().aria_label("Outcome lesson review"),
    style=[
      "padding:16px", "border:1px solid #475569", "border-radius:14px", "display:grid",
      "gap:10px",
    ],
    [
      @html.h4(style=["margin:0"], "Reusable outcome lesson"),
      @html.p(style=["white-space:pre-wrap", "margin:0"], guidance),
      @html.strong("All of these conditions must match the later task"),
      @html.ul(
        outcome_lesson_condition_lines(applicability).map(line => @html.li(line)),
      ),
      @html.strong("Do not reuse when any of these conditions matches"),
      if invalidation_lines.is_empty() {
        @html.p("No additional invalidation condition was supplied.")
      } else {
        @html.ul(invalidation_lines.map(line => @html.li(line)))
      },
      @html.p(
        "Review the guidance together with these conditions. Acceptance makes this exact lesson available for scoped retrieval; it does not activate a capability or accept another task.",
      ),
      @html.details([
        @html.summary("Original outcome and review references"),
        @html.pre(
          style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
          [
            outcome_lesson_reference_line("Outcome", outcome),
            outcome_lesson_reference_line("Assessment", assessment),
            outcome_lesson_reference_line("Assessment review", review),
          ].join("\n\n"),
        ),
      ]),
      @html.details([
        @html.summary("Retrieve for the next task"),
        @html.p(
          "Provide the later task's exact reference and named conditions in a query file. Retrieval returns only human-accepted lessons whose full applicability matches, with the original outcome and review evidence.",
        ),
        @html.code(
          "moon run cmd/outcome_lessons -- retrieve <book-root> <query.json>",
        ),
      ]),
    ],
  )
}

///|
fn selected_outcome_lesson_detail(model : Model) -> @rabbita.Html {
  guard model.selected_bookkeeper_record is Some(reference) else {
    return @html.nothing
  }
  match selected_raw_record(model, reference) {
    Some(record) =>
      @html.div([
        lesson_change_review_detail(model, record),
        outcome_lesson_review_detail(record),
      ])
    None => @html.nothing
  }
}
