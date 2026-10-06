///|
fn saved_lesson_return_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  guard state.handoff is Some(readback) else { return @html.nothing }
  let saved = state.saved_return
  let receipts = saved_lesson_receipts(readback)
  @html.section(id="saved-lesson-return", style=["display:grid", "gap:10px"], [
    @html.h4("Saved lessons for this exact task"),
    @html.p(
      "Select a persisted lesson to return its review status to Proj. Saving for review is pending; only a named-human accepted lesson is retained. Guidance and scope stay in Book.",
    ),
    @html.button(
      disabled=state.pending || state.outcome_review.pending,
      on_click=emit(OutcomeLesson(RefreshSavedLessons("refresh"))),
      "Refresh saved lesson status",
    ),
    if receipts.is_empty() {
      @html.p(
        "No saved lesson matches this exact task/report and reviewed outcome. Save a lesson through the existing review workflow, then refresh here.",
      )
    } else {
      @html.div(
        receipts.map(receipt => {
          guard saved_lesson_receipt_valid(
              receipt,
              lesson_task_field(readback, "handoff"),
            ) &&
            saved_lesson_reference(lesson_task_field(receipt, "lesson"))
            is Some(reference) else {
            return @html.p(
              "A saved lesson receipt is incomplete. Refresh before returning any status.",
            )
          }
          @html.article(
            style=[
              "padding:10px", "border:1px solid #64748b", "border-radius:8px",
            ],
            [
              @html.strong(
                lesson_task_text(receipt, "title") +
                " · version " +
                reference.record_version,
              ),
              @html.p(
                "Review status · " +
                lesson_task_text(receipt, "state") +
                " · " +
                lesson_task_text(receipt, "currentness"),
              ),
              @html.p(
                "Reviewer · " +
                (match lesson_task_field(receipt, "review") {
                  Null => "No final named-human decision"
                  review => lesson_task_text(review, "reviewer_id")
                }),
              ),
              @html.button(
                disabled=state.pending,
                on_click=emit(OutcomeLesson(ChooseSavedLesson(reference))),
                if saved.selected == Some(reference) {
                  "Selected exact lesson"
                } else {
                  "Select this saved lesson"
                },
              ),
              match selected_raw_record(model, reference) {
                Some(record) =>
                  @html.button(
                    on_click=emit(
                      SelectBookkeeperItem(lesson_record_item(record)),
                    ),
                    "Inspect lesson and its review in Book",
                  )
                None => @html.nothing
              },
            ],
          )
        }),
      )
    },
    @html.p(
      "Book journal observed at Unix seconds · " +
      saved.observed_at.to_string() +
      ". Refresh rereads Book; exported receipts describe this observation and are not signatures.",
    ),
    @html.button(
      disabled=state.pending ||
        state.outcome_review.pending ||
        saved.selected is None ||
        lesson_incoming_origin().is_empty(),
      on_click=emit(OutcomeLesson(RefreshSavedLessons("return"))),
      "Return selected lesson status to Proj",
    ),
    @html.button(
      disabled=state.pending ||
        state.outcome_review.pending ||
        saved.selected is None,
      on_click=emit(OutcomeLesson(RefreshSavedLessons("export"))),
      "Download selected lesson receipt",
    ),
    @html.p(
      "If the Proj window closed or its connection expired, reconnect from the exact task in Proj or import the downloaded receipt. Nothing here accepts a task, customer outcome or payment.",
    ),
    @html.p(
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      saved.notice,
    ),
  ])
}
