///|
fn outcome_review_status(state : String) -> String {
  match state {
    "deliverable_review_required" =>
      "2 · Review the supplied deliverable with a named human"
    "deliverable_rejected" =>
      "Deliverable rejected. This submission cannot continue."
    "continue_required" => "3 · Continue the saved outcome review"
    "assessment_review_required" =>
      "4 · Review the assessment with a named human"
    "assessment_rejected" =>
      "Assessment rejected. This outcome is not an accepted lesson source."
    "reviewed_source_available" =>
      "5 · Reviewed source available. Start a lesson below when ready."
    _ => "Refresh status to inspect this submission's next step."
  }
}

///|
fn outcome_review_reference(label : String, reference : Json) -> @rabbita.Html {
  @html.p(
    label +
    " · " +
    lesson_task_text(reference, "record_id") +
    " @ " +
    lesson_task_text(reference, "record_version"),
  )
}

///|
fn outcome_review_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
  readback : Json,
) -> @rabbita.Html {
  let state = model.outcome_lessons.outcome_review
  let busy = state.pending ||
    model.outcome_lessons.pending ||
    model.bookkeeper_busy
  @html.section(
    id="task-outcome-review",
    style=[
      "display:grid", "gap:10px", "padding:14px", "border:1px solid #475569", "border-radius:12px",
    ],
    [
      @html.h4("Outcome review for this task"),
      @html.p(
        "Internal task acceptance confirms the captured work report. Import an already-complete outcome file from the producing product, then inspect its external outcome evidence before saving.",
      ),
      @html.p(
        "1 · Import and inspect → 2 · Deliverable review → 3 · Continue outcome review → 4 · Assessment review → 5 · Start lesson",
      ),
      @html.button(
        disabled=busy,
        on_click=emit(OutcomeLesson(OutcomeReview(PickOutcome))),
        "Import outcome file",
      ),
      @html.button(
        disabled=busy,
        on_click=emit(OutcomeLesson(OutcomeReview(RefreshOutcomes))),
        "Refresh outcome review status",
      ),
      if state.notice.is_empty() {
        @html.nothing
      } else {
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          state.notice,
        )
      },
      match state.preview {
        Some(preview) if state.binding == outcome_review_binding(model) =>
          @html.article(style=["display:grid", "gap:8px"], [
            @html.strong(
              "Preview · " + lesson_task_text(preview, "deliverable_title"),
            ),
            @html.p(
              "Deliverable · " +
              lesson_task_text(preview, "deliverable_summary"),
            ),
            @html.p(
              "Supplied outcome · " +
              lesson_task_text(preview, "outcome_summary"),
            ),
            outcome_review_reference(
              "Submission",
              lesson_task_field(preview, "submission"),
            ),
            @html.p(
              "Source product · " + lesson_task_text(preview, "source_product"),
            ),
            @html.p(
              "Decision evidence · " +
              lesson_task_text(preview, "decision_evidence_id"),
            ),
            @html.details([
              @html.summary("Inspect supplied evidence references"),
              @html.pre(
                style=["white-space:pre-wrap"],
                lesson_task_field(preview, "evidence_refs").stringify(indent=2),
              ),
            ]),
            @html.details([
              @html.summary("Inspect complete imported JSON"),
              @html.pre(
                style=["white-space:pre-wrap"],
                preview.stringify(indent=2),
              ),
            ]),
            @html.p(
              "Save records the supplied deliverable and result for review. Importing the same unchanged file keeps one saved submission and its existing reviews. It does not accept the outcome or start a lesson.",
            ),
            @html.button(
              disabled=busy,
              on_click=emit(OutcomeLesson(OutcomeReview(SaveOutcome))),
              "Save outcome for review",
            ),
          ])
        _ => @html.nothing
      },
      @html.div(
        outcome_review_items(readback).map(item => {
          let status = lesson_task_text(item, "state")
          let next = lesson_task_field(item, "next_record")
          let needs_review = status == "deliverable_review_required" ||
            status == "assessment_review_required"
          @html.article(style=["display:grid", "gap:6px", "padding-top:12px"], [
            @html.strong(lesson_task_text(item, "title")),
            @html.p(
              "Supplied outcome · " + lesson_task_text(item, "outcome_summary"),
            ),
            outcome_review_reference(
              "Saved submission",
              lesson_task_field(item, "submission"),
            ),
            @html.p(outcome_review_status(status)),
            if next is Null {
              @html.nothing
            } else {
              outcome_review_reference("Exact pending record", next)
            },
            @html.details([
              @html.summary("Exact saved record references"),
              @html.pre(
                style=["white-space:pre-wrap"],
                item.stringify(indent=2),
              ),
            ]),
            if needs_review {
              @html.div([
                @html.button(
                  disabled=busy || outcome_review_record(model, next) is None,
                  on_click=emit(
                    OutcomeLesson(OutcomeReview(OpenOutcomeReview(next))),
                  ),
                  "Open named-human review for this exact record",
                ),
                @html.p(
                  "Opening selects this record in the existing review controls. Previous review drafts remain available when you return to their records. Inspect the named reviewer, evidence and decision before saving.",
                ),
                if outcome_review_record(model, next) is None {
                  @html.p(
                    "The exact record is still loading or unavailable. Refresh status before opening review.",
                  )
                } else {
                  @html.nothing
                },
              ])
            } else if status == "continue_required" {
              @html.div([
                @html.p(
                  "Continue uses the immutable saved submission. It can recover an interrupted intake and stops at the next existing human review gate.",
                ),
                @html.button(
                  disabled=busy,
                  on_click=emit(
                    OutcomeLesson(
                      OutcomeReview(
                        ContinueOutcome(lesson_task_field(item, "submission")),
                      ),
                    ),
                  ),
                  "Continue outcome review",
                ),
              ])
            } else {
              @html.nothing
            },
          ])
        }),
      ),
    ],
  )
}
