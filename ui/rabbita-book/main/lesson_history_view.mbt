///|
fn lesson_history_review_list(
  reviews : Array[BookkeeperRawReview],
) -> @rabbita.Html {
  if reviews.is_empty() {
    return @html.p("Pending review · no review receipt yet")
  }
  @html.ul(
    reviews.map(review => {
      @html.li(
        review.disposition +
        " · " +
        review.reviewer.reviewer_id +
        " · " +
        review.summary +
        (if review.review_complete {
          " · completed"
        } else {
          " · incomplete / deferred"
        }),
      )
    }),
  )
}

///|
fn lesson_history_original(
  label : String,
  record : BookkeeperRawRecord,
) -> @rabbita.Html {
  @html.section(style=["display:grid", "gap:8px", "overflow-wrap:anywhere"], [
    @html.h4(
      label +
      " · " +
      record.title +
      " · version " +
      record.record.record_version,
    ),
    outcome_lesson_review_detail(record),
    @html.details([
      @html.summary("Exact original artifact"),
      @html.pre(
        style=["white-space:pre-wrap"],
        outcome_lesson_reference_line("Lesson", ToJson::to_json(record.record)),
      ),
    ]),
  ])
}

///|
fn lesson_exact_record(model : Model, value : Json) -> BookkeeperRawRecord? {
  let reference : BookkeeperRecordReference = @json.from_json(value) catch {
    _ => return None
  }
  guard model.bookkeeper_store is Some(snapshot) else { return None }
  for record in snapshot.records {
    if record.record == reference {
      return Some(record)
    }
  }
  None
}

///|
fn lesson_change_predecessor(
  model : Model,
  change : Json,
) -> BookkeeperRawRecord? {
  let head = lesson_task_field(change, "expected_head")
  let reference = if head is Null {
    match lesson_task_field(change, "accepted_reviews") {
      [only] => only
      _ => return None
    }
  } else {
    head
  }
  guard model.bookkeeper_store is Some(snapshot) else { return None }
  for review in snapshot.reviews {
    if ToJson::to_json(review.receipt) == reference &&
      lesson_exact_record(model, ToJson::to_json(review.subject))
      is Some(record) {
      if lesson_record_value(record) is Some(_) {
        return Some(record)
      }
      if record.payload
        is {
          "candidate_schema": "outcome_lesson_selection.v1",
          "selection": selection,
          ..
        } {
        return lesson_exact_record(
          model,
          lesson_task_field(selection, "target"),
        )
      }
    }
  }
  None
}

///|
fn lesson_change_review_detail(
  model : Model,
  record : BookkeeperRawRecord,
) -> @rabbita.Html {
  let (change, target_key, title) = match record.payload {
    { "candidate_schema": "outcome_lesson.v2", "revision": value, .. } =>
      (value, "supersedes", "Review this lesson revision")
    {
      "candidate_schema": "outcome_lesson_selection.v1",
      "selection": value,
      ..
    } => (value, "target", "Review this current-version proposal")
    _ => return @html.nothing
  }
  let comparison : Array[@rabbita.Html] = []
  if lesson_exact_record(model, lesson_task_field(change, target_key))
    is Some(original) {
    comparison.push(
      lesson_history_original(
        if target_key == "supersedes" {
          "Accepted original being revised"
        } else {
          "Accepted target to make current"
        },
        original,
      ),
    )
  } else {
    comparison.push(
      @html.p(
        "The exact original lesson is not loaded. Reload Bookkeeper and inspect its guidance and scope before reviewing.",
      ),
    )
  }
  match lesson_change_predecessor(model, change) {
    Some(predecessor) =>
      comparison.push(
        lesson_history_original(
          "Current guidance at captured predecessor", predecessor,
        ),
      )
    None =>
      comparison.push(
        @html.p(
          "No single predecessor guidance can be shown here. Inspect the captured accepted versions and exact review references below before reviewing.",
        ),
      )
  }
  if model.bookkeeper_store is Some(snapshot) &&
    lesson_task_field(change, "accepted_reviews") is Array(references) {
    for reference in references {
      for review in snapshot.reviews {
        if ToJson::to_json(review.receipt) == reference &&
          lesson_exact_record(model, ToJson::to_json(review.subject))
          is Some(original) {
          comparison.push(
            lesson_history_original(
              "Captured accepted version · " + review.reviewer.reviewer_id,
              original,
            ),
          )
        }
      }
    }
  }
  @html.section(
    attrs=@html.Attrs::build().aria_label(title),
    style=["display:grid", "gap:10px"],
    [
      @html.h4(title),
      @html.p(
        style=["white-space:pre-wrap"],
        "Reason · " + lesson_task_text(change, "reason"),
      ),
      @html.p(
        "Compare the original guidance and full conditions before preparing acceptance or rejection. Saving this proposal did not change current guidance. Acceptance is checked against the captured review head and accepted versions; a stale proposal must be refreshed and reviewed again.",
      ),
      @html.div(comparison),
      @html.details([
        @html.summary("Captured predecessor and accepted reviews"),
        @html.pre(
          style=["white-space:pre-wrap"],
          if lesson_task_field(change, "expected_head") is Null {
            "No reviewed current-version choice existed. Legacy accepted lessons remain retrievable until a choice is reviewed."
          } else {
            outcome_lesson_reference_line(
              "Predecessor review",
              lesson_task_field(change, "expected_head"),
            )
          },
        ),
        @html.pre(
          style=["white-space:pre-wrap"],
          lesson_task_field(change, "accepted_reviews").stringify(indent=2),
        ),
      ]),
    ],
  )
}

///|
fn lesson_history_edit_field(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
  change : LessonHistoryChange,
  key : String,
  label : String,
) -> @rabbita.Html {
  @html.label(style=["display:grid", "gap:5px"], [
    @html.span(label),
    @html.textarea(
      value=lesson_change_field(change, key),
      attrs=@html.Attrs::build().aria_label(label),
      disabled=state.pending,
      on_input=value => emit(OutcomeLesson(EditHistory(key, value))),
      style=[
        "width:100%",
        "box-sizing:border-box",
        "padding:9px",
        "color:#f8fafc",
        "background:#020617",
        "border:1px solid #64748b",
        "border-radius:8px",
        "font:inherit",
        if key == "version" || key == "title" {
          "min-height:44px"
        } else {
          "min-height:100px"
        },
      ],
      ([] : Array[@rabbita.Html]),
    ),
  ])
}

///|
fn lesson_history_change_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  guard state.history.change is Some(change) else { return @html.nothing }
  let revision = change.operation == "revise"
  let stale = match state.history.data {
    Some(data) =>
      data.head != change.expected_head ||
      data.accepted_reviews != change.accepted_reviews
    None => false
  }
  @html.section(
    style=[
      "display:grid", "gap:12px", "border:1px solid #64748b", "padding:14px",
    ],
    [
      @html.h4(
        if revision {
          "Revise the selected accepted lesson"
        } else {
          "Propose the selected accepted version as current"
        },
      ),
      @html.p(
        "This separate change draft stays in this tab. Your manual lesson draft and Proj context are kept. The captured original is fixed even if you inspect another version.",
      ),
      if stale {
        @html.p(
          "History has changed since this draft began. Its captured comparison is kept, but this proposal is stale. Copy your edits, close this draft and start a new change from refreshed history before saving.",
        )
      } else {
        @html.nothing
      },
      lesson_history_original(
        if revision {
          "Original comparison"
        } else {
          "Selected restore target"
        },
        change.original,
      ),
      match change.predecessor {
        Some(original) =>
          lesson_history_original(
            "Current guidance when this change began", original,
          )
        None =>
          @html.p(
            "No single current version was selected when this change began. Every legacy accepted version remains retrievable until a choice receives named-human acceptance.",
          )
      },
      if revision {
        @html.div(style=["display:grid", "gap:12px"], [
          lesson_history_edit_field(
            emit, state, change, "title", "Revised lesson title",
          ),
          lesson_history_edit_field(
            emit, state, change, "guidance", "Revised guidance",
          ),
          lesson_history_edit_field(
            emit, state, change, "version", "New lesson version",
          ),
          lesson_history_edit_field(
            emit, state, change, "applicability", "Revised required conditions · one key=value per line",
          ),
          lesson_history_edit_field(
            emit, state, change, "invalidation", "Revised invalidation conditions · one key=value per line",
          ),
        ])
      } else {
        @html.p(
          "The selected accepted version's guidance, scope and original evidence are preserved exactly. This saves a separate selection proposal.",
        )
      },
      lesson_history_edit_field(
        emit, state, change, "reason", "Why should this change be accepted?",
      ),
      @html.button(
        class="moonbook-primary-action",
        disabled=state.pending || stale,
        on_click=emit(OutcomeLesson(SubmitHistoryChange)),
        if revision {
          "Save revision for review"
        } else {
          "Save current-version proposal for review"
        },
      ),
      @html.button(
        disabled=state.pending,
        on_click=emit(OutcomeLesson(DiscardHistoryChange)),
        "Close this change draft · discard unsaved edits only",
      ),
    ],
  )
}

///|
fn lesson_history_saved_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  guard model.outcome_lessons.history.result
    is Some({ "accepted": true, "event": event, .. }) else {
    return @html.nothing
  }
  match lesson_exact_record(model, event) {
    Some(record) =>
      @html.button(
        class="moonbook-primary-action",
        on_click=emit(SelectBookkeeperItem(lesson_record_item(record))),
        "Open saved change for named-human review",
      )
    None =>
      @html.p(
        "Change saved. Reload Bookkeeper state to open its exact proposal for review.",
      )
  }
}

///|
fn lesson_history_workspace_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  let history = state.history
  @html.section(
    attrs=@html.Attrs::build().aria_label("Lesson version history"),
    style=["display:grid", "gap:12px"],
    [
      @html.h4("Lesson version history"),
      @html.p(
        "Select a saved outcome lesson in the lanes, then inspect current guidance, earlier versions and review decisions. A revision or restore proposal uses the same named-human review controls.",
      ),
      @html.button(
        disabled=state.pending || lesson_history_source(model) is Err(_),
        on_click=emit(OutcomeLesson(OpenHistory)),
        "Open selected lesson history",
      ),
      @html.p(
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        history.notice,
      ),
      match history.data {
        None => @html.nothing
        Some(data) =>
          @html.div(style=["display:grid", "gap:12px"], [
            @html.h4("History · " + data.lesson_id),
            @html.button(
              disabled=state.pending,
              on_click=emit(OutcomeLesson(RefreshHistory)),
              "Refresh this lesson history · keep change draft",
            ),
            match lesson_history_record(data, data.current) {
              Some(record) =>
                lesson_history_original("Current guidance", record)
              None =>
                @html.p(
                  "No single current version. Legacy accepted versions remain available for retrieval until a current-version proposal is accepted; pending and rejected versions do not become guidance.",
                )
            },
            @html.h4("Saved versions and human reviews"),
            @html.div(
              data.versions.map(version => {
                @html.article(
                  style=["padding:10px", "border:1px solid #475569"],
                  [
                    @html.strong(
                      version.lesson.title +
                      " · version " +
                      version.lesson.record.record_version +
                      (if version.current { " · current" } else { "" }),
                    ),
                    lesson_history_review_list(version.reviews),
                    @html.button(
                      disabled=state.pending,
                      on_click=emit(
                        OutcomeLesson(
                          ChooseHistoryVersion(version.lesson.record),
                        ),
                      ),
                      "Inspect version " + version.lesson.record.record_version,
                    ),
                  ],
                )
              }),
            ),
            match lesson_history_record(data, history.selected) {
              Some(record) =>
                lesson_history_original("Selected version", record)
              None => @html.nothing
            },
            @html.button(
              disabled=state.pending ||
                history.change is Some(_) ||
                !lesson_history_can_revise(history),
              on_click=emit(OutcomeLesson(StartHistoryChange("revise"))),
              "Revise this accepted version",
            ),
            if lesson_history_selected_accepted(history) is Some(_) &&
              !lesson_history_can_revise(history) {
              @html.p(
                "To revise this older accepted version, choose or restore it as current and complete named-human review first. You can also select the current version and revise it directly.",
              )
            } else {
              @html.nothing
            },
            @html.button(
              disabled=state.pending ||
                history.change is Some(_) ||
                lesson_history_selected_accepted(history) is None ||
                history.selected == data.current,
              on_click=emit(OutcomeLesson(StartHistoryChange("select"))),
              "Choose or restore this accepted version as current",
            ),
            @html.details([
              @html.summary(
                "Current-version proposals and review history (" +
                data.selections.length().to_string() +
                ")",
              ),
              @html.div(
                data.selections.map(selection => {
                  @html.article([
                    @html.h4(selection.record.title),
                    lesson_change_review_detail(model, selection.record),
                    lesson_history_review_list(selection.reviews),
                    @html.button(
                      on_click=emit(
                        SelectBookkeeperItem(
                          lesson_record_item(selection.record),
                        ),
                      ),
                      "Open version proposal for review",
                    ),
                  ])
                }),
              ),
            ]),
          ])
      },
      lesson_history_change_view(emit, model),
      lesson_history_saved_view(emit, model),
    ],
  )
}
