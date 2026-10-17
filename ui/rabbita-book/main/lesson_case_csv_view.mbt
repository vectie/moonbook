///|
fn lesson_case_csv_view(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
  inspection : Json,
) -> @rabbita.Html {
  guard state.history.change is Some(change) else { return @html.nothing }
  let intake = lesson_task_field(change.revision_rehearsal, "intake")
  let preview = lesson_task_field(intake, "preview")
  let current = lesson_task_field(inspection, "current") == true.to_json()
  let preview_current = lesson_task_field(inspection, "csv_preview_current") ==
    true.to_json()
  let input_error = lesson_task_text(intake, "input_error")
  let errors = match lesson_task_field(preview, "errors") {
    Array(values) => values
    _ => []
  }
  let rows = match lesson_task_field(preview, "rows") {
    Array(values) => values
    _ => []
  }
  let plan = match lesson_task_field(preview, "plan") {
    Array(values) => values
    _ => []
  }
  let act = (kind : String, value : String) => {
    OutcomeLesson(
      RevisionRehearsal(
        lesson_revision_rehearsal_action(
          state.history,
          kind,
          value~,
          request_id=state.request,
        ),
      ),
    )
  }
  @html.section(
    attrs=@html.Attrs::build().aria_label("Import a CSV teaching-case set"),
    style=[
      "display:grid", "gap:8px", "padding:12px", "border:1px solid #64748b",
    ],
    [
      @html.h4("Import a CSV teaching-case set"),
      @html.p(
        "Paste 1–6 observed cases, at most 128 KiB UTF-8. Exact header: kind,name,input,original,revised,required,forbidden. Kind is useful or adverse; revised may be empty until you supply a fresh output. Quote fields containing commas, quotes or line breaks; double embedded quotes. No rows or fields are silently truncated.",
      ),
      @html.p(
        "Preview never changes your cases. Explicit import fills only completely empty same-kind manual slots, then appends. Authored and remembered cases stay unchanged. Checks are 1–20 nonblank literal fragments, one per line, without surrounding whitespace. Cases are operator reports; import provides no review, model run or authority.",
      ),
      @html.label([
        @html.span("CSV case set · exact pasted text"),
        @html.textarea(
          value=lesson_task_text(intake, "text"),
          attrs=@html.Attrs::build().aria_label(
            "CSV case set · exact pasted text",
          ),
          disabled=state.pending || !current,
          on_input=value => emit(act("csv_edit", value)),
          style=[
            "width:100%", "min-height:140px", "box-sizing:border-box", "font:inherit",
          ],
          ([] : Array[@rabbita.Html]),
        ),
      ]),
      if input_error != "" {
        @html.p(input_error)
      } else {
        @html.nothing
      },
      @html.div([
        @html.button(
          disabled=state.pending || !current || input_error != "",
          on_click=emit(act("csv_preview", "")),
          "Preview exact CSV cases",
        ),
        @html.button(
          disabled=state.pending || !current,
          on_click=emit(act("csv_clear", "")),
          "Clear CSV intake · keep rehearsal cases",
        ),
      ]),
      if preview != Json::null() {
        @html.div([
          @html.p(
            if preview_current {
              "Exact parsed preview. JSON strings below expose every field, quote and line ending. Nothing has been imported yet."
            } else {
              "This CSV preview is stale or a request is pending. Cases are kept; preview again before import."
            },
          ),
          @html.ul(
            errors.map(error => {
              @html.li(
                "Record " +
                lesson_task_field(error, "record").stringify() +
                " · " +
                lesson_task_text(error, "field") +
                ": " +
                lesson_task_text(error, "message"),
              )
            }),
          ),
          @html.div(
            rows.map(row => {
              @html.article([
                @html.h4(
                  "CSV record " + lesson_task_field(row, "record").stringify(),
                ),
                @html.pre(
                  style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                  (if lesson_task_field(row, "value") != Json::null() {
                    lesson_task_field(row, "value")
                  } else {
                    lesson_task_field(row, "fields")
                  }).stringify(indent=2),
                ),
              ])
            }),
          ),
          @html.ul(
            plan.map(item => {
              @html.li(
                "Record " +
                lesson_task_field(item, "record").stringify() +
                " → " +
                lesson_task_text(item, "id") +
                " · " +
                (if lesson_task_text(item, "operation") == "fill_empty" {
                  "fill completely empty same-kind slot"
                } else {
                  "append a new case"
                }),
              )
            }),
          ),
          @html.button(
            disabled=state.pending ||
              !current ||
              !preview_current ||
              lesson_task_field(preview, "ready") != true.to_json(),
            on_click=emit(act("csv_import", "")),
            "Import exact previewed cases",
          ),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}
