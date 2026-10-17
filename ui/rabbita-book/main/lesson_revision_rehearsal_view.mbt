///|
fn lesson_revision_rehearsal_field(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
  field : String,
  value : String,
  label : String,
  case_id? : String = "",
  stale? : Bool = false,
  retained? : Bool = false,
) -> @rabbita.Html {
  @html.label(style=["display:grid", "gap:5px"], [
    @html.span(label),
    @html.textarea(
      value~,
      attrs=@html.Attrs::build().aria_label(label),
      disabled=state.pending || stale || retained,
      on_input=value => {
        emit(
          OutcomeLesson(
            RevisionRehearsal(
              lesson_revision_rehearsal_action(
                state.history,
                "edit",
                field~,
                value~,
                case_id~,
              ),
            ),
          ),
        )
      },
      style=[
        "width:100%", "box-sizing:border-box", "min-height:70px", "font:inherit",
      ],
      ([] : Array[@rabbita.Html]),
    ),
  ])
}

///|
fn lesson_revision_rehearsal_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  guard state.history.change is Some(change) else { return @html.nothing }
  let draft = change.revision_rehearsal
  let inspection = lesson_revision_rehearsal_transition(
    state.history,
    state.pending,
    { "kind": "inspect" },
    request_id=state.request,
  )
  let current = lesson_task_field(inspection, "current") == true.to_json()
  let preview_current = lesson_task_field(inspection, "preview_current") ==
    true.to_json()
  let staged = lesson_task_field(draft, "staged") == true.to_json()
  let cases = match lesson_task_field(draft, "cases") {
    Array(values) => values
    _ => []
  }
  let results = match
    lesson_task_field(lesson_task_field(draft, "preview"), "cases") {
    Array(values) => values
    _ => []
  }
  @html.section(
    attrs=@html.Attrs::build().aria_label(
      "Rehearse revision on contrasting cases",
    ),
    style=[
      "display:grid", "gap:12px", "padding:12px", "border:1px solid #64748b",
    ],
    [
      @html.h4("Rehearse revision on contrasting cases"),
      @html.p(
        "Supply 2–6 distinct examples, including a known-useful case and an adverse case. Paste original and revised outputs, then define required or forbidden literal fragments. These are your reports; no model runs and passing samples do not prove generalization. Save a browser copy explicitly to continue after reload.",
      ),
      lesson_correction_draft_view(emit, model, current),
      lesson_retained_cases_view(emit, state, inspection),
      if draft == Json::null() {
        @html.button(
          disabled=state.pending ||
            lesson_task_field(inspection, "eligible") != true.to_json(),
          on_click=emit(
            OutcomeLesson(
              RevisionRehearsal(
                lesson_revision_rehearsal_action(state.history, "begin"),
              ),
            ),
          ),
          "Start contrasting-case rehearsal",
        )
      } else {
        @html.div(style=["display:grid", "gap:12px"], [
          if !current {
            @html.p(
              "Accepted history, guidance, scope or rationale changed. Your cases are retained. Discard this rehearsal and restart from refreshed history; stale cases cannot be staged or saved.",
            )
          } else {
            @html.nothing
          },
          if staged {
            @html.p(
              "Staged in the ordinary revision editor. Save for named-human review below. Editing the rehearsal requires comparing and staging again.",
            )
          } else {
            @html.nothing
          },
          lesson_case_csv_view(emit, state, inspection),
          lesson_revision_rehearsal_field(
            emit,
            state,
            "guidance",
            lesson_task_text(draft, "guidance"),
            "Guidance to rehearse · exact text staged",
            stale=!current,
          ),
          lesson_revision_rehearsal_field(
            emit,
            state,
            "rationale",
            lesson_task_text(draft, "rationale"),
            "Your reason for the correction · operator reported",
            stale=!current,
          ),
          @html.div(
            cases.map(c => {
              let id = lesson_task_text(c, "id")
              @html.article(
                style=[
                  "display:grid", "gap:8px", "border:1px solid #475569", "padding:12px",
                ],
                [
                  @html.h4(
                    if lesson_task_text(c, "kind") == "useful" {
                      "Known-useful case · preserve behavior"
                    } else {
                      "Adverse case · repair failure"
                    },
                  ),
                  if lesson_task_field(c, "retained_from") != Json::null() {
                    @html.p(
                      "Remembered baseline · input, old output and checks are read-only. Fresh revised output is required. Source: " +
                      lesson_task_field(
                        lesson_task_field(c, "retained_from"),
                        "lesson",
                      ).stringify(),
                    )
                  } else {
                    @html.nothing
                  },
                  if lesson_task_field(c, "practice_from") != Json::null() {
                    @html.details([
                      @html.summary(
                        "Inspect observed practice source · unverified operator report",
                      ),
                      @html.p(
                        "The fixed task and first response are preserved. The after-feedback response is reference context only; supply an output explicitly attributed to the revised guidance in the blank revised field. Feedback is not proof of learning or factual accuracy.",
                      ),
                      @html.pre(
                        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                        lesson_task_field(c, "practice_from").stringify(
                          indent=2,
                        ),
                      ),
                    ])
                  } else {
                    @html.nothing
                  },
                  @html.div(
                    [
                      ("name", "Case name"),
                      ("input", "Example input"),
                      ("original", "Supplied output using original guidance"),
                      ("revised", "Supplied output using revised guidance"),
                      ("required", "Required fragments · one per line"),
                      ("forbidden", "Forbidden fragments · one per line"),
                    ].map(pair => {
                      let (key, label) = pair
                      lesson_revision_rehearsal_field(
                        emit,
                        state,
                        key,
                        lesson_task_text(c, key),
                        label + " · " + id,
                        case_id=id,
                        stale=!current,
                        retained=(
                            key != "revised" &&
                            lesson_task_field(c, "retained_from") !=
                            Json::null()
                          ) ||
                          (
                            (key == "input" || key == "original") &&
                            lesson_task_field(c, "practice_from") !=
                            Json::null()
                          ),
                      )
                    }),
                  ),
                  @html.button(
                    disabled=state.pending || !current || cases.length() <= 2,
                    on_click=emit(
                      OutcomeLesson(
                        RevisionRehearsal(
                          lesson_revision_rehearsal_action(
                            state.history,
                            "remove",
                            case_id=id,
                          ),
                        ),
                      ),
                    ),
                    "Remove case",
                  ),
                ],
              )
            }),
          ),
          @html.div(
            ["useful", "adverse"].map(kind => {
              @html.button(
                disabled=state.pending || !current || cases.length() >= 6,
                on_click=emit(
                  OutcomeLesson(
                    RevisionRehearsal(
                      lesson_revision_rehearsal_action(
                        state.history,
                        "add",
                        case_kind=kind,
                      ),
                    ),
                  ),
                ),
                "Add " + kind + " case",
              )
            }),
          ),
          @html.button(
            disabled=state.pending || !current,
            on_click=emit(
              OutcomeLesson(
                RevisionRehearsal(
                  lesson_revision_rehearsal_action(state.history, "compare"),
                ),
              ),
            ),
            "Compare supplied outputs and literal checks",
          ),
          if preview_current {
            @html.div([
              @html.p(
                "Per-case differences · literal matches only. A useful baseline must pass; every revised check must pass; at least one adverse baseline check must be repaired before staging.",
              ),
              @html.div(
                results.map(result => {
                  let checks = match lesson_task_field(result, "checks") {
                    Array(values) => values
                    _ => []
                  }
                  @html.article([
                    @html.h4(lesson_task_text(result, "name")),
                    @html.p(
                      "Original " +
                      lesson_task_field(result, "original_passed").stringify() +
                      "/" +
                      lesson_task_field(result, "total").stringify() +
                      " · revised " +
                      lesson_task_field(result, "revised_passed").stringify() +
                      "/" +
                      lesson_task_field(result, "total").stringify(),
                    ),
                    @html.ul(
                      checks.map(check => {
                        @html.li(
                          lesson_task_text(check, "kind") +
                          " · “" +
                          lesson_task_text(check, "text") +
                          "” · original " +
                          (if lesson_task_field(check, "original_passed") ==
                            true.to_json() {
                            "pass"
                          } else {
                            "fail"
                          }) +
                          " → revised " +
                          (if lesson_task_field(check, "revised_passed") ==
                            true.to_json() {
                            "pass"
                          } else {
                            "fail"
                          }),
                        )
                      }),
                    ),
                  ])
                }),
              ),
              @html.button(
                disabled=state.pending ||
                  lesson_task_field(
                    lesson_task_field(draft, "preview"),
                    "ready",
                  ) !=
                  true.to_json(),
                on_click=emit(
                  OutcomeLesson(
                    RevisionRehearsal(
                      lesson_revision_rehearsal_action(state.history, "stage"),
                    ),
                  ),
                ),
                "Stage exact guidance and operator-reported rationale",
              ),
            ])
          } else {
            @html.nothing
          },
          @html.button(
            disabled=state.pending,
            on_click=emit(
              OutcomeLesson(
                RevisionRehearsal(
                  lesson_revision_rehearsal_action(state.history, "discard"),
                ),
              ),
            ),
            "Discard local rehearsal · keep revision fields",
          ),
        ])
      },
    ],
  )
}
