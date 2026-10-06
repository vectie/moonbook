///|
fn lesson_text_field(
  emit : @rabbita.Emit[Msg],
  state : OutcomeLessonWorkspace,
  key : String,
  label : String,
  tall? : Bool = false,
) -> @rabbita.Html {
  @html.label(style=["display:grid", "gap:5px"], [
    @html.span(label),
    @html.textarea(
      value=lesson_field(state, key),
      attrs=@html.Attrs::build().aria_label(label),
      on_input=value => emit(OutcomeLesson(Edit(key, value))),
      disabled=state.pending ||
        (
          state.task_guidance.handoff is Some(_) &&
          ["task-id", "task-version", "task-digest"].contains(key)
        ),
      style=[
        "width:100%",
        "box-sizing:border-box",
        "padding:9px",
        "color:#f8fafc",
        "background:#020617",
        "border:1px solid #64748b",
        "border-radius:8px",
        "font:inherit",
        if tall {
          "min-height:100px"
        } else {
          "height:44px"
        },
      ],
      ([] : Array[@rabbita.Html]),
    ),
  ])
}

///|
fn lesson_record_item(record : BookkeeperRawRecord) -> BookkeeperItem {
  {
    stage: "deliverable_acceptance",
    title: record.title,
    record_id: record.record.record_id,
    record_version: record.record.record_version,
    status: record.status,
    tone: "review",
    summary: record.summary,
    owner_route: record.owner_route,
    evidence_count: record.evidence_refs.length(),
    issue_count: record.issue_refs.length(),
    requires_human_review: record.requires_human_review,
    next_action: record.next_action,
  }
}

///|
fn lesson_workspace_results(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  guard model.outcome_lessons.result is Some(result) else {
    return @html.nothing
  }
  match result {
    { "accepted": true, "event": event, .. } => {
      let reference : BookkeeperRecordReference = @json.from_json(event) catch {
        _ =>
          return @html.p(
            "The saved lesson reference could not be read. Reload Bookkeeper state.",
          )
      }
      let link = match selected_raw_record(model, reference) {
        Some(record) =>
          @html.button(
            class="moonbook-primary-action",
            on_click=emit(SelectBookkeeperItem(lesson_record_item(record))),
            "Open saved lesson for review",
          )
        None =>
          @html.p("Refreshing the saved lesson in the Bookkeeper lanes…")
      }
      @html.div([
        @html.p(
          "Saved lesson: " +
          reference.record_id +
          " · " +
          reference.record_version,
        ),
        link,
      ])
    }
    {
      "contract_version": "moonbook.outcome-lesson-retrieval.v1",
      "matches": Array(matches),
      "exclusions": Array(exclusions),
      ..
    } => {
      let cards = matches.map(item => {
        guard item
          is {
            "lesson": value,
            "review": {
              "reviewer": { "reviewer_id": String(reviewer), .. },
              ..
            },
            ..
          } else {
          return @html.p(
            "A lesson result is incomplete. Find lessons again before reuse.",
          )
        }
        let record : BookkeeperRawRecord = @json.from_json(value) catch {
          _ => return @html.p("A lesson could not be read. Find lessons again.")
        }
        @html.article(style=["display:grid", "gap:8px"], [
          @html.h4(record.title),
          @html.p("Reviewed by " + reviewer),
          outcome_lesson_review_detail(record),
          @html.button(
            on_click=emit(SelectBookkeeperItem(lesson_record_item(record))),
            "Inspect original lesson",
          ),
          if model.outcome_lessons.task_guidance.handoff is Some(_) {
            @html.button(
              class="moonbook-primary-action",
              disabled=model.outcome_lessons.pending ||
                task_guidance_incoming_origin().is_empty() ||
                model.outcome_lessons.task_guidance.confirmed_handoff !=
                model.outcome_lessons.task_guidance.handoff ||
                model.outcome_lessons.task_guidance.confirmed_origin !=
                task_guidance_incoming_origin(),
              on_click=emit(OutcomeLesson(TaskGuidance(Use(record.record)))),
              "Use this guidance for " +
              lesson_field(model.outcome_lessons, "task-id") +
              " at " +
              task_guidance_incoming_origin(),
            )
          } else {
            @html.nothing
          },
        ])
      })
      @html.div(style=["display:grid", "gap:14px"], [
        @html.h4(
          if matches.is_empty() {
            "No matching reviewed lessons"
          } else {
            "Useful lessons for this task"
          },
        ),
        @html.p(
          if matches.is_empty() {
            "No human-accepted lesson meets all of these conditions. Try another truthful task context; original lessons remain unchanged."
          } else {
            "These lessons match the named conditions. Check the original evidence and decide whether each applies to this task."
          },
        ),
        @html.div(cards),
        @html.details([
          @html.summary(
            "Why other lessons were excluded (" +
            exclusions.length().to_string() +
            ")",
          ),
          @html.ul(
            exclusions.map(item => {
              match item {
                {
                  "lesson": { "record_id": String(id), .. },
                  "reason": String(reason),
                  ..
                } => @html.li(id + ": " + reason)
                _ => @html.li("A lesson did not meet the requested conditions.")
              }
            }),
          ),
        ]),
      ])
    }
    _ =>
      @html.p(
        "Unsupported lesson result. Retry after reloading Bookkeeper state.",
      )
  }
}

///|
fn outcome_lesson_workspace_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  @html.details(
    class="moonbook-technical-disclosure",
    open=!lesson_incoming_origin().is_empty() ||
      !task_guidance_incoming_origin().is_empty(),
    [
      @html.summary("Make and reuse a lesson"),
      @html.div(style=["display:grid", "gap:14px", "padding-top:14px"], [
        task_guidance_view(emit, model),
        lesson_task_handoff_view(emit, model),
        saved_lesson_return_view(emit, model),
        @html.h4("1 · Write a lesson from a reviewed outcome"),
        @html.p(
          "Select an accepted Three-Gap assessment in the lanes, then use it as this lesson's source. Selecting another record leaves your text and source unchanged. Drafts stay in this tab until you leave or reload.",
        ),
        @html.button(
          disabled=state.pending || lesson_selected_source(model) is Err(_),
          on_click=emit(OutcomeLesson(UseSelected)),
          "Use selected assessment",
        ),
        @html.p(state.source_label),
        lesson_text_field(emit, state, "title", "Lesson title"),
        lesson_text_field(
          emit,
          state,
          "guidance",
          "What should we do next time?",
          tall=true,
        ),
        @html.strong("When to use this lesson"),
        lesson_text_field(
          emit, state, "customer", "Customer or audience identifier (optional)",
        ),
        lesson_text_field(
          emit, state, "decision", "Kind of decision (optional)",
        ),
        @html.details([
          @html.summary("Additional conditions and version"),
          @html.p(
            "Use one key=value per line for other precise context. All required conditions must match. Any invalidation match prevents reuse.",
          ),
          lesson_text_field(
            emit,
            state,
            "extra",
            "Additional required conditions",
            tall=true,
          ),
          lesson_text_field(
            emit,
            state,
            "invalid",
            "Do not use when",
            tall=true,
          ),
          lesson_text_field(emit, state, "version", "Lesson version"),
        ]),
        @html.button(
          class="moonbook-primary-action",
          disabled=state.pending,
          on_click=emit(OutcomeLesson(Submit("prepare"))),
          "Save lesson for review",
        ),
        @html.p(
          "2 · Open the saved lesson and use the existing named-human review controls above. Saving a lesson does not accept it. To revise an accepted lesson, open its version history and prepare a reviewed change.",
        ),
        @html.h4("3 · Find useful lessons for the next task"),
        lesson_text_field(emit, state, "task-id", "Next task ID"),
        @html.details([
          @html.summary("Exact task version and digest"),
          @html.p(
            "Copy these from the later task's source receipt. They identify the query context; they do not establish that task's acceptance.",
          ),
          lesson_text_field(emit, state, "task-version", "Next task version"),
          lesson_text_field(emit, state, "task-digest", "Next task digest"),
        ]),
        lesson_text_field(
          emit, state, "query-customer", "Next task customer or audience identifier",
        ),
        lesson_text_field(
          emit, state, "query-decision", "Next task kind of decision",
        ),
        @html.details([
          @html.summary("Other next-task conditions"),
          lesson_text_field(
            emit,
            state,
            "query-extra",
            "Other next-task conditions, one key=value per line",
            tall=true,
          ),
        ]),
        @html.button(
          class="moonbook-primary-action",
          disabled=state.pending,
          on_click=emit(OutcomeLesson(Submit("retrieve"))),
          "Find useful lessons",
        ),
        @html.p(
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          state.notice,
        ),
        lesson_workspace_results(emit, model),
      ]),
    ],
  )
}
