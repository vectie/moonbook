///|
fn lesson_correction_draft_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
  current : Bool,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  guard state.history.change is Some(change) && change.operation == "revise" else {
    return @html.nothing
  }
  let recovery = change.correction_recovery
  let saved = lesson_task_field(recovery, "draft")
  let has_saved = lesson_task_field(recovery, "raw") != Json::null()
  let problem = lesson_task_text(recovery, "problem")
  @html.section(
    attrs=@html.Attrs::build().aria_label("Save and resume correction draft"),
    style=["display:grid", "gap:8px"],
    [
      @html.h4("Keep this correction for later"),
      @html.p(
        "Save your revision fields, supplied cases and pasted CSV on this browser. This shared-device copy may contain private examples. It is not a reviewed lesson or a backup; clearing browser data removes it. Resume explicitly from a fresh revision of the same current lesson.",
      ),
      @html.button(
        disabled=state.pending,
        on_click=emit(
          OutcomeLesson(
            CorrectionDraft(lesson_correction_draft_action(model, "read")),
          ),
        ),
        "Check saved correction",
      ),
      if recovery != Json::null() {
        @html.p(lesson_task_text(recovery, "notice"))
      } else {
        @html.nothing
      },
      if !problem.is_blank() {
        @html.p(problem)
      } else {
        @html.nothing
      },
      if saved != Json::null() {
        let cases = match
          lesson_task_field(lesson_task_field(saved, "rehearsal"), "cases") {
          Array(items) => items.length()
          _ => 0
        }
        @html.div([
          @html.p(
            "Saved title: " +
            lesson_task_text(lesson_task_field(saved, "fields"), "title") +
            " · " +
            cases.to_string() +
            " supplied cases. Resuming restores editable text only; comparison and staging must be repeated.",
          ),
          @html.details([
            @html.summary(
              "Inspect saved correction text · available even when history changed",
            ),
            @html.p(
              "You can copy this authored text to prepare a separate correction if its accepted source has changed. It remains an unreviewed browser draft.",
            ),
            @html.pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              (
                {
                  "revision_fields": lesson_task_field(saved, "fields"),
                  "supplied_rehearsal": lesson_task_field(saved, "rehearsal"),
                } : Json).stringify(indent=2),
            ),
          ]),
          @html.button(
            disabled=state.pending || !lesson_correction_draft_pristine(change),
            on_click=emit(
              OutcomeLesson(
                CorrectionDraft(lesson_correction_draft_action(model, "resume")),
              ),
            ),
            "Resume saved correction into this fresh revision",
          ),
        ])
      } else {
        @html.nothing
      },
      @html.button(
        disabled=state.pending || !current,
        on_click=emit(
          OutcomeLesson(
            CorrectionDraft(lesson_correction_draft_action(model, "save")),
          ),
        ),
        if has_saved {
          "Replace checked browser copy with this correction"
        } else {
          "Save correction on this browser"
        },
      ),
      if has_saved {
        @html.button(
          disabled=state.pending,
          on_click=emit(
            OutcomeLesson(
              CorrectionDraft(lesson_correction_draft_action(model, "forget")),
            ),
          ),
          "Remove checked browser copy · keep open work",
        )
      } else {
        @html.nothing
      },
    ],
  )
}
