///|
fn lesson_browser_links(
  emit : @rabbita.Emit[Msg],
  model : Model,
  record : BookkeeperRawRecord,
) -> @rabbita.Html {
  let available = lesson_browser_navigation_record(model, record.record)
    is Some(_)
  @html.div(style=["display:grid", "gap:8px"], [
    @html.div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
      @html.button(
        disabled=!available,
        on_click=emit(OutcomeLesson(Browser(OpenOriginal(record.record)))),
        "Inspect original lesson",
      ),
      @html.button(
        disabled=!available || model.outcome_lessons.pending,
        on_click=emit(OutcomeLesson(Browser(OpenHistory(record.record)))),
        "Open lesson history",
      ),
    ]),
    if !available {
      @html.div([
        @html.p(
          "Reload Bookkeeper records to open this exact original or its history. The browser result alone does not load the review workspace.",
        ),
        @html.button(
          disabled=model.bookkeeper_reads.store_loading,
          on_click=emit(OutcomeLesson(Browser(ReloadRecords))),
          if model.bookkeeper_reads.store_loading {
            "Reloading Bookkeeper records…"
          } else {
            "Reload Bookkeeper records"
          },
        ),
        match model.bookkeeper_reads.store_error {
          Some(error) =>
            @html.p(attrs=@html.Attrs::build().role("alert"), error)
          None => @html.nothing
        },
      ])
    } else {
      @html.nothing
    },
  ])
}

///|
fn lesson_browser_card(
  emit : @rabbita.Emit[Msg],
  model : Model,
  entry : LessonBrowserEntry,
) -> @rabbita.Html {
  let lesson = lesson_record_value(entry.lesson).unwrap()
  let applicability = outcome_lesson_condition_lines(
    lesson_task_field(lesson, "applicability"),
  )
  let invalidation = outcome_lesson_condition_lines(
    lesson_task_field(lesson, "invalidation"),
  )
  @html.article(
    class="moonbook-reviewed-lesson-card",
    style=[
      "display:grid", "gap:8px", "padding:16px", "border:1px solid #475569", "border-radius:14px",
      "overflow-wrap:anywhere",
    ],
    [
      @html.h4(style=["margin:0"], entry.lesson.title),
      @html.p(
        "Reviewed by " +
        entry.review.reviewer.reviewer_id +
        " · version " +
        entry.lesson.record.record_version,
      ),
      @html.p(
        style=["white-space:pre-wrap"],
        lesson_task_text(lesson, "guidance"),
      ),
      @html.strong("When this lesson applies"),
      if applicability.is_empty() {
        @html.p(
          "No applicability conditions recorded. Check the original before reuse.",
        )
      } else {
        @html.ul(applicability.map(line => @html.li(line)))
      },
      @html.strong("Do not use when"),
      if invalidation.is_empty() {
        @html.p("No additional invalidation condition was supplied.")
      } else {
        @html.ul(invalidation.map(line => @html.li(line)))
      },
      @html.details([
        @html.summary("Named review and exact references"),
        @html.p(entry.review.summary),
        @html.pre(
          style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
          [
            outcome_lesson_reference_line(
              "Lesson",
              ToJson::to_json(entry.lesson.record),
            ),
            outcome_lesson_reference_line(
              "Accepted review",
              ToJson::to_json(entry.review.receipt),
            ),
            outcome_lesson_reference_line(
              "Outcome",
              lesson_task_field(lesson, "outcome"),
            ),
            outcome_lesson_reference_line(
              "Assessment",
              lesson_task_field(lesson, "assessment"),
            ),
          ].join("\n\n"),
        ),
        if entry.selection_review is Null {
          @html.nothing
        } else {
          @html.pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            outcome_lesson_reference_line(
              "Current-version review",
              entry.selection_review,
            ),
          )
        },
      ]),
      lesson_browser_links(emit, model, entry.lesson),
      @html.button(
        disabled=model.outcome_lessons.teaching_brief.draft.items.any(item => {
          item.snapshot.lesson_id == lesson_task_text(lesson, "lesson_id")
        }),
        on_click=emit(
          OutcomeLesson(
            TeachingBrief(
              model.outcome_lessons.teaching_brief.revision,
              Add(model.outcome_lessons.browser.request, entry.lesson.record),
            ),
          ),
        ),
        "Add lesson to agent teaching brief",
      ),
      @html.button(
        disabled=model.outcome_lessons.notebook.draft.items.any(item => {
          item.snapshot.reference == entry.lesson.record
        }),
        on_click=emit(
          OutcomeLesson(
            Notebook(
              model.outcome_lessons.notebook.revision,
              Add(model.outcome_lessons.browser.request, entry.lesson.record),
            ),
          ),
        ),
        "Add experience to decision notebook",
      ),
    ],
  )
}

///|
fn lesson_browser_results(
  emit : @rabbita.Emit[Msg],
  model : Model,
  data : LessonBrowserResult,
) -> @rabbita.Html {
  @html.div(style=["display:grid", "gap:12px"], [
    @html.p(
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      data.lessons.length().to_string() +
      " reviewed lessons · current at last load",
    ),
    if data.lessons.is_empty() {
      @html.div([
        @html.h4(
          if lesson_task_text(data.query, "text").is_empty() {
            "No current reviewed lessons to browse"
          } else {
            "No current reviewed lessons match this search"
          },
        ),
        @html.p(
          if data.exclusions.is_empty() {
            "Try another search or clear the text and reload. This search does not check a task's scope or applicability."
          } else {
            "Other saved lesson records match this search. Expand the list below to inspect why they are not shown as current reviewed guidance."
          },
        ),
      ])
    } else {
      @html.div(
        style=["display:grid", "gap:12px"],
        data.lessons.map(entry => lesson_browser_card(emit, model, entry)),
      )
    },
    @html.details([
      @html.summary(
        "Other saved lesson records (" +
        data.exclusions.length().to_string() +
        ")",
      ),
      @html.p(
        "Unreviewed, rejected, historical or ambiguous-current records are not current reviewed guidance. You can still inspect their original records and review history.",
      ),
      @html.div(
        style=["display:grid", "gap:12px"],
        data.exclusions.map(entry => {
          @html.article(style=["padding:12px", "border:1px solid #475569"], [
            @html.h4(
              entry.lesson.title +
              " · version " +
              entry.lesson.record.record_version,
            ),
            @html.p(entry.reason),
            lesson_browser_links(emit, model, entry.lesson),
          ])
        }),
      ),
    ]),
  ])
}

///|
fn lesson_browser_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons.browser
  @html.section(
    id="reviewed-lesson-browser",
    attrs=@html.Attrs::build().aria_label("Reviewed lesson browser"),
    style=[
      "display:grid", "gap:12px", "padding:18px", "border:1px solid #64748b", "border-radius:16px",
    ],
    [
      @html.h3(style=["margin:0"], "Reviewed lessons"),
      @html.p(
        "Browse saved guidance before creating a task. Search titles, guidance, condition names and values, or reviewer names. No task ID or digest is needed.",
      ),
      @html.p(
        "Text search does not decide whether a lesson applies to a future task. Check all applicability and invalidation conditions yourself. Browsing does not accept a lesson, change the current version, attach guidance or start work.",
      ),
      @html.label(style=["display:grid", "gap:5px"], [
        @html.span("Search reviewed lessons"),
        @html.input(
          input_type=Search,
          value=state.text,
          attrs=@html.Attrs::build().aria_label("Search reviewed lessons"),
          on_input=text => emit(OutcomeLesson(Browser(Edit(text)))),
          style=[
            "padding:10px", "font:inherit", "border-radius:8px", "color:#f8fafc",
            "background:#020617", "border:1px solid #64748b",
          ],
        ),
      ]),
      @html.div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
        @html.button(
          class="moonbook-primary-action",
          disabled=state.pending,
          on_click=emit(OutcomeLesson(Browser(Reload))),
          if state.pending {
            "Loading reviewed lessons…"
          } else if state.data is Some(_) {
            "Reload reviewed lessons"
          } else if state.text.is_empty() {
            "Browse reviewed lessons"
          } else {
            "Search reviewed lessons"
          },
        ),
      ]),
      if state.pending {
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          "Loading this exact search…",
        )
      } else {
        @html.nothing
      },
      match state.error {
        Some(error) =>
          @html.div(attrs=@html.Attrs::build().role("alert"), [
            @html.p("Reviewed lessons could not be loaded: " + error),
            @html.p(
              "Your search text, lesson draft and task handoff are kept. Reload to retry.",
            ),
          ])
        None => @html.nothing
      },
      if state.notice.is_empty() {
        @html.nothing
      } else {
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          state.notice,
        )
      },
      match state.data {
        Some(data) => lesson_browser_results(emit, model, data)
        None => @html.nothing
      },
      lesson_notebook_view(emit, model),
      lesson_teaching_brief_view(emit, model),
    ],
  )
}
