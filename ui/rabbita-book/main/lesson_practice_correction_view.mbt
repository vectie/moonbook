///|
fn lesson_practice_correction_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  let teaching = state.teaching_brief
  guard teaching.practice.session is Some(session) &&
    teaching.practice.correction is Some(draft) else {
    return @html.nothing
  }
  let item = lesson_practice_rounds(session)[draft.round].teaching.items[draft.index]
  let send = action => {
    emit(
      OutcomeLesson(
        PracticeCorrection(
          teaching.revision,
          state.request,
          lesson_practice_correction_owner(model),
          action,
        ),
      ),
    )
  }
  @html.section(
    attrs=@html.Attrs::build().aria_label("Practice observation to correction"),
    style=[
      "display:grid", "gap:10px", "padding:12px", "border:1px solid #64748b",
    ],
    [
      @html.h4(
        "Turn practice " +
        (draft.index + 1).to_string() +
        " into a correction case",
      ),
      @html.p(
        "Selected round " +
        (draft.round + 1).to_string() +
        " · exact historical task and first response",
      ),
      @html.p(
        "Open this captured lesson's history below and use the ordinary Revise this accepted version and Start contrasting-case rehearsal controls. Recheck reviewed lessons if needed. The captured lesson must still be the exact current version; your workbook and any existing authored rehearsal cases are kept.",
      ),
      @html.button(
        disabled=state.pending,
        on_click=send(OpenHistory),
        "Open this practice lesson's history",
      ),
      lesson_notebook_field("Practice case name", draft.name, value => {
        send(Edit("name", value))
      }),
      @html.p(
        "Choose the role of this observed case deliberately: " +
        (if draft.kind.is_empty() { "not chosen" } else { draft.kind }),
      ),
      @html.button(
        on_click=send(Edit("kind", "useful")),
        "Use as a known-useful case",
      ),
      @html.button(
        on_click=send(Edit("kind", "adverse")),
        "Use as an adverse case",
      ),
      lesson_notebook_field(
        "Practice case required literal fragments · one per line",
        draft.required,
        value => send(Edit("required", value)),
      ),
      lesson_notebook_field(
        "Practice case forbidden literal fragments · one per line",
        draft.forbidden,
        value => send(Edit("forbidden", value)),
      ),
      @html.p(
        "Inspect the exact case below before adding it. Add explicitly attributes the recorded first response to the captured original guidance for this operator-reported rehearsal. The after-feedback response and feedback remain readable source context; they are not a result of revised guidance. Supply that result separately in the ordinary rehearsal.",
      ),
      @html.pre(
        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
        lesson_practice_correction_case(session, draft).stringify(indent=2),
      ),
      @html.button(
        disabled=!lesson_practice_correction_ready(model, item),
        on_click=send(AddCase),
        "Add first response as original-guidance case",
      ),
      @html.p(
        if lesson_practice_correction_ready(model, item) {
          "Matching current revision rehearsal is open. Existing authored cases are preserved; this fills a pristine matching slot or appends within the existing six-case limit."
        } else {
          "Recheck captured guidance, open matching current lesson history, revise it and start its rehearsal before adding. A changed, stale or unavailable lesson leaves this preparation intact."
        },
      ),
      @html.button(on_click=send(Close), "Close practice case preparation"),
    ],
  )
}
