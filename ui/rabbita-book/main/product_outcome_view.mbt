///|
fn product_outcome_sources(source_pack : Json) -> @rabbita.Html {
  let inner = match product_outcome_payload(source_pack) {
    Ok(value) => value
    Err(error) => return @html.p(error)
  }
  let submission = lesson_task_field(inner, "submission")
  @html.div([
    @html.strong(lesson_task_text(submission, "deliverable_title")),
    @html.p(lesson_task_text(submission, "deliverable_summary")),
    @html.p(
      "Operator-authored interpretation · " +
      lesson_task_text(submission, "outcome_summary"),
    ),
    @html.details([
      @html.summary("Read supplied gap statements"),
      @html.pre(
        style=["white-space:pre-wrap"],
        ["information_gap", "recognition_gap", "decisiveness_gap"]
        .map(key => {
          key + ": " + lesson_task_field(submission, key).stringify(indent=2)
        })
        .join("\n"),
      ),
    ]),
    @html.div(
      match lesson_task_field(inner, "artifacts") {
        Array(artifacts) =>
          artifacts.map(artifact => {
            @html.details([
              @html.summary(
                "Original source · " +
                lesson_task_text(
                  lesson_task_field(artifact, "reference"),
                  "reference_id",
                ),
              ),
              @html.pre(
                style=[
                  "white-space:pre-wrap", "max-height:260px", "overflow:auto",
                ],
                lesson_task_text(artifact, "text"),
              ),
            ])
          })
        _ => []
      },
    ),
  ])
}

///|
fn product_outcome_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons.products
  let busy = state.pending ||
    model.bookkeeper_busy ||
    model.outcome_lessons.pending
  fn action(
    label : String,
    operation : String,
    payload : Json,
  ) -> @rabbita.Html {
    @html.button(
      disabled=busy,
      on_click=emit(OutcomeLesson(ProductOutcome(Run(operation, payload)))),
      label,
    )
  }
  @html.section(
    id="product-outcome-intake",
    style=[
      "display:grid", "gap:10px", "padding:14px", "border:1px solid #475569", "border-radius:12px",
    ],
    [
      @html.h4("Product outcomes"),
      @html.p(
        "Import completed product work with its original source files. Read the supplied interpretation, then use Book’s existing named-human review. A product review is evidence; Book makes its own decision.",
      ),
      @html.p(
        "1 · Import and inspect → 2 · Save for review → 3 · Open the next review → 4 · Refresh and return the receipt",
      ),
      @html.button(
        disabled=busy,
        on_click=emit(OutcomeLesson(ProductOutcome(Pick))),
        "Import product outcome",
      ),
      action("Reopen saved outcomes", "product-list", {}),
      if state.notice.is_empty() {
        @html.nothing
      } else {
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          state.notice,
        )
      },
      match state.preview {
        None => @html.nothing
        Some(source_pack) =>
          @html.article([
            @html.h4("Inspect before saving"),
            product_outcome_sources(source_pack),
            @html.p(
              "Saving retains the exact submitted files for review. It does not accept the outcome, create a task, or activate a capability.",
            ),
            action(
              "Save outcome for Book review", "product-import", source_pack,
            ),
          ])
      },
      @html.div(
        state.items.map(item => {
          @html.article([
            @html.strong(lesson_task_text(item, "title")),
            @html.p(outcome_review_status(lesson_task_text(item, "state"))),
            action("Open saved outcome and original sources", "product-read", {
              "submission": lesson_task_field(item, "submission"),
            }),
          ])
        }),
      ),
      match state.selected {
        None => @html.nothing
        Some(receipt) => {
          let progress = lesson_task_field(receipt, "progress")
          let reference = lesson_task_field(progress, "submission")
          let next = lesson_task_field(progress, "next_record")
          let status = lesson_task_text(progress, "state")
          @html.article(style=["display:grid", "gap:10px"], [
            @html.h4("Selected saved outcome"),
            product_outcome_sources(lesson_task_field(receipt, "package")),
            @html.p(outcome_review_status(status)),
            @html.p(
              "Rejected, revision-requested and escalated material stays available. A revision request or escalation leaves the existing review open; no acceptance is inferred.",
            ),
            @html.h4("Book decisions and reasons"),
            @html.ul(
              match lesson_task_field(receipt, "reviews") {
                Array(reviews) if !reviews.is_empty() =>
                  reviews.map(review => {
                    let disposition = match
                      lesson_task_text(review, "disposition") {
                      "Accept" => "Accepted"
                      "Reject" => "Declined"
                      "Revise" => "Revision requested; review remains open"
                      "Escalate" => "Escalated; review remains open"
                      _ => "Review incomplete"
                    }
                    let stage = if lesson_task_text(review, "stage") ==
                      "ThreeGapFinding" {
                      "Assessment"
                    } else {
                      "Deliverable"
                    }
                    @html.li(
                      stage +
                      " · " +
                      disposition +
                      " · " +
                      lesson_task_text(
                        lesson_task_field(review, "reviewer"),
                        "reviewer_id",
                      ) +
                      ": " +
                      lesson_task_text(review, "summary"),
                    )
                  })
                _ => [@html.li("No Book decision recorded in this readback")]
              },
            ),
            if status == "deliverable_review_required" ||
              status == "assessment_review_required" {
              @html.button(
                disabled=busy ||
                  product_outcome_review_record(model, next) is None,
                on_click=emit(OutcomeLesson(ProductOutcome(Review(next)))),
                "Open this exact record in Book review",
              )
            } else if status == "continue_required" {
              action(
                "Continue to the existing assessment review",
                "product-continue",
                { "submission": reference },
              )
            } else {
              @html.nothing
            },
            action("Refresh this outcome after review", "product-read", {
              "submission": reference,
            }),
            if product_outcome_can_defer(model) &&
              selected_authority_grant(model) is Some(_) {
              @html.div([
                @html.button(
                  disabled=busy,
                  on_click=emit(PrepareBookkeeperReview("Revise")),
                  "Prepare revision request",
                ),
                @html.button(
                  disabled=busy,
                  on_click=emit(PrepareBookkeeperReview("Escalate")),
                  "Prepare escalation",
                ),
                @html.p(
                  "These defer acceptance using Book’s existing decisions. Review the named reviewer and reason below, then choose Save governed review.",
                ),
              ])
            } else {
              @html.nothing
            },
            action(
              "Download disposition receipt for source product",
              "product-read",
              { "submission": reference, "download": "receipt" },
            ),
            action("Download unchanged source package", "product-read", {
              "submission": reference,
              "download": "package",
            }),
            @html.p(
              "The exported receipt is a historical local observation. Import it in the source product to reopen the original result. Refresh Book for current review state.",
            ),
          ])
        }
      },
    ],
  )
}
