///|
fn lesson_evolution_text(value : String) -> @rabbita.Html {
  @html.pre(style=["white-space:pre-wrap", "overflow-wrap:anywhere"], value)
}

///|
fn lesson_evolution_scope_view(title : String, delta : Json) -> @rabbita.Html {
  @html.section([
    @html.h4(title),
    @html.div(
      ["removed", "added", "unchanged"].map(kind => {
        let items = lesson_evolution_array(lesson_task_field(delta, kind))
        @html.div([
          @html.strong(kind + " · " + items.length().to_string()),
          @html.ul(
            items.map(item => {
              @html.li(
                lesson_task_text(item, "key") +
                " = " +
                lesson_task_text(item, "value"),
              )
            }),
          ),
        ])
      }),
    ),
  ])
}

///|
fn lesson_evolution_version_view(
  label : String,
  snapshot : Json,
) -> @rabbita.Html {
  @html.article([
    @html.h4(
      label +
      " · " +
      lesson_task_text(snapshot, "title") +
      " · version " +
      lesson_task_text(
        lesson_task_field(snapshot, "reference"),
        "record_version",
      ),
    ),
    @html.p(
      "Review state: " +
      lesson_task_text(snapshot, "review_status") +
      (if lesson_task_field(snapshot, "current_at_load") == Json::boolean(true) {
        " · current at last history load"
      } else {
        " · not current at last history load"
      }),
    ),
    @html.strong("Exact guidance"),
    lesson_evolution_text(lesson_task_text(snapshot, "guidance")),
    @html.strong("Required conditions"),
    lesson_evolution_text(
      lesson_condition_edit_text(lesson_task_field(snapshot, "applicability")),
    ),
    @html.strong("Do not use when"),
    lesson_evolution_text(
      lesson_condition_edit_text(lesson_task_field(snapshot, "invalidation")),
    ),
    @html.p(
      "Author's reason for the revision · not an independent outcome finding",
    ),
    lesson_evolution_text(lesson_task_text(snapshot, "author_rationale")),
    @html.strong("Named review history"),
    @html.ul(
      lesson_evolution_array(lesson_task_field(snapshot, "reviews")).map(review => {
        @html.li([
          lesson_evolution_text(
            lesson_task_text(review, "reviewer") +
            " · " +
            lesson_task_text(review, "disposition") +
            " · " +
            (if lesson_task_field(review, "complete") == Json::boolean(true) {
              "completed"
            } else {
              "incomplete"
            }) +
            "\n" +
            lesson_task_text(review, "summary"),
          ),
          lesson_evolution_text(
            lesson_task_field(review, "receipt").stringify(indent=2),
          ),
        ])
      }),
    ),
    @html.strong("Original lesson, outcome and assessment references"),
    lesson_evolution_text(
      lesson_task_field(snapshot, "reference").stringify(indent=2) +
      "\n" +
      lesson_task_field(snapshot, "source_references").stringify(indent=2),
    ),
    @html.p(lesson_task_text(snapshot, "cases_notice")),
  ])
}

///|
fn lesson_evolution_case_view(label : String, value : Json) -> @rabbita.Html {
  if value is Null {
    return @html.p(
      label +
      ": no matching input in this version's saved report. This does not establish that the behavior was forgotten or removed.",
    )
  }
  @html.div([
    @html.h4(label + " · " + lesson_task_text(value, "name")),
    @html.strong("Recorded output under this version"),
    lesson_evolution_text(lesson_task_text(value, "output")),
    @html.strong("Required literal fragments"),
    lesson_evolution_text(
      lesson_task_field(value, "required").stringify(indent=2),
    ),
    @html.strong("Forbidden literal fragments"),
    lesson_evolution_text(
      lesson_task_field(value, "forbidden").stringify(indent=2),
    ),
  ])
}

///|
fn lesson_evolution_report_view(report : Json) -> @rabbita.Html {
  let before = lesson_task_field(report, "baseline")
  let after = lesson_task_field(report, "target")
  @html.section([
    @html.h3("What changed in " + lesson_task_text(report, "lesson_id") + "?"),
    @html.p(lesson_task_text(report, "relationship")),
    @html.p(lesson_task_text(report, "interpretation")),
    @html.div(
      style=[
        "display:grid", "grid-template-columns:repeat(auto-fit,minmax(260px,1fr))",
        "gap:16px",
      ],
      [
        lesson_evolution_version_view("Baseline", before),
        lesson_evolution_version_view("Target", after),
      ],
    ),
    @html.h3("Guidance changes · exact line comparison"),
    @html.p(
      "Added and removed text is a textual difference, not a quality score. Above 256 lines per version, complete before/after blocks are shown instead.",
    ),
    @html.div(
      lesson_evolution_array(lesson_task_field(report, "guidance_lines")).map(line => {
        @html.div([
          @html.strong(lesson_task_text(line, "kind")),
          lesson_evolution_text(lesson_task_text(line, "text")),
        ])
      }),
    ),
    lesson_evolution_scope_view(
      "Required applicability changes",
      lesson_task_field(report, "required_conditions"),
    ),
    lesson_evolution_scope_view(
      "Invalidation changes · when not to reuse",
      lesson_task_field(report, "invalidation_conditions"),
    ),
    @html.h3("Teaching experience across versions"),
    @html.p(
      "Cases are paired only by the exact complete input text. A renamed case stays paired; changed input stays separate. These recorded observations are unverified operator reports, including when their lesson was accepted. No fresh model execution or generalized improvement is inferred.",
    ),
    if lesson_evolution_array(lesson_task_field(report, "teaching_cases")).is_empty() {
      @html.p(
        "Neither version exposes readable supported teaching cases. Compare guidance, scope and original evidence above.",
      )
    } else {
      @html.div(
        lesson_evolution_array(lesson_task_field(report, "teaching_cases")).map(case => {
            @html.article([
              @html.h4(lesson_task_text(case, "kind")),
              @html.strong("Exact example input"),
              lesson_evolution_text(lesson_task_text(case, "input")),
              @html.div(
                style=[
                  "display:grid", "grid-template-columns:repeat(auto-fit,minmax(260px,1fr))",
                  "gap:16px",
                ],
                [
                  lesson_evolution_case_view(
                    "Baseline",
                    lesson_task_field(case, "before"),
                  ),
                  lesson_evolution_case_view(
                    "Target",
                    lesson_task_field(case, "after"),
                  ),
                ],
              ),
            ])
          },
        ),
      )
    },
  ])
}

///|
fn lesson_evolution_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let workspace = model.outcome_lessons
  let state = workspace.evolution
  guard workspace.history.data is Some(history) else { return @html.nothing }
  let send = action => {
    emit(OutcomeLesson(Evolution(workspace.request, state.revision, action)))
  }
  let unavailable = workspace.pending || !workspace.history.read_ready
  let report = lesson_evolution_selected(workspace)
  @html.section(
    attrs=@html.Attrs::build().aria_label("Lesson evolution explorer"),
    style=[
      "border:1px solid #64748b", "padding:14px", "display:grid", "gap:12px",
    ],
    [
      @html.h3("Explore how this lesson evolved"),
      @html.p(
        "Choose any two saved versions, including a rejected or pending alternative. Compare actual guidance, scope and recorded teaching experience before deciding what is useful. Baseline and target are your comparison direction, not an inferred chronology.",
      ),
      @html.div(
        history.versions.map(version => {
          let reference = version.lesson.record
          @html.article([
            @html.strong(
              version.lesson.title + " · version " + reference.record_version,
            ),
            @html.button(
              disabled=unavailable || state.baseline == Some(reference),
              on_click=send(Choose("baseline", reference)),
              "Use version " + reference.record_version + " as baseline",
            ),
            @html.button(
              disabled=unavailable || state.target == Some(reference),
              on_click=send(Choose("target", reference)),
              "Use version " + reference.record_version + " as target",
            ),
          ])
        }),
      ),
      @html.p(
        "Baseline: " +
        state.baseline.map(r => r.record_version).unwrap_or("not selected") +
        " · Target: " +
        state.target.map(r => r.record_version).unwrap_or("not selected"),
      ),
      @html.button(
        disabled=unavailable || state.baseline is None || state.target is None,
        on_click=send(Swap),
        "Swap comparison direction",
      ),
      match report {
        Ok(report) => lesson_evolution_report_view(report)
        Err(error) => @html.p(error)
      },
      @html.p(
        "Download a standalone printable comparison or its structured JSON. These files can contain private guidance and examples; share only with intended readers. Downloads are captured read-only outputs, not imports or review receipts.",
      ),
      @html.button(
        disabled=unavailable || report is Err(_) || state.downloading,
        on_click=send(Download(true)),
        "Download printable lesson evolution HTML",
      ),
      @html.button(
        disabled=unavailable || report is Err(_) || state.downloading,
        on_click=send(Download(false)),
        "Download lesson evolution JSON",
      ),
      @html.p(
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        state.notice,
      ),
    ],
  )
}
