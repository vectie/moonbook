///|
struct BookkeeperJourneyStep {
  position : Int
  title : String
  detail : String
  action : String
  blocked : Bool
} derive(Debug, Eq)

///|
fn bookkeeper_journey_step_for(
  records_available : Bool,
  record_selected : Bool,
  authority_selected : Bool,
  mode : String,
  busy : Bool,
  notice : String,
) -> BookkeeperJourneyStep {
  if busy {
    {
      position: 3,
      title: "Saving your governed decision",
      detail: "MoonBook is writing the receipt and refreshing the durable projection.",
      action: "wait",
      blocked: false,
    }
  } else if !records_available {
    {
      position: 1,
      title: "Load review work",
      detail: "No durable review record is available yet. Replay the journal to recover the latest safe state.",
      action: "replay",
      blocked: false,
    }
  } else if !record_selected {
    {
      position: 1,
      title: "Choose what you are reviewing",
      detail: "Select one exact record below. MoonBook will bind the review to its version, digest, and evidence.",
      action: "select",
      blocked: false,
    }
  } else if !authority_selected {
    {
      position: 2,
      title: "Reviewer permission is required",
      detail: "A named-human authority must be installed outside the browser before this decision can be accepted.",
      action: "install-authority",
      blocked: true,
    }
  } else if notice.contains("Mutation accepted") ||
    notice.contains("Replay complete") {
    {
      position: 4,
      title: "Verify the durable outcome",
      detail: "Replay once to confirm the journal and visible projection agree before continuing the loop.",
      action: "replay",
      blocked: false,
    }
  } else if mode != "review" {
    {
      position: 3,
      title: "Prepare the governed review",
      detail: "MoonBook can now generate a review draft bound to the selected record and reviewer.",
      action: "prepare-review",
      blocked: false,
    }
  } else {
    {
      position: 3,
      title: "Confirm and save this review",
      detail: "Check the decision summary. Technical JSON remains available below for evidence inspection.",
      action: "submit-review",
      blocked: false,
    }
  }
}

///|
fn bookkeeper_records_available(model : Model) -> Bool {
  match model.bookkeeper_store {
    Some(snapshot) => !snapshot.records.is_empty()
    None => false
  }
}

///|
fn bookkeeper_journey_step(model : Model) -> BookkeeperJourneyStep {
  bookkeeper_journey_step_for(
    bookkeeper_records_available(model),
    model.selected_bookkeeper_record is Some(_),
    selected_authority_grant(model) is Some(_),
    model.bookkeeper_mode,
    model.bookkeeper_busy,
    model.bookkeeper_notice.unwrap_or(""),
  )
}

///|
fn render_bookkeeper_progress(step : BookkeeperJourneyStep) -> @rabbita.Html {
  let labels = [
    (1, "record", "1 · Select"),
    (2, "authority", "2 · Authorize"),
    (3, "review", "3 · Review"),
    (4, "verify", "4 · Verify"),
  ]
  @html.div(
    class="moonbook-progress",
    attrs=@html.Attrs::build()
      .role("list")
      .aria_label("Bookkeeper review progress"),
    labels.map(fn(pair) {
      let index = pair.0
      let state = if index < step.position {
        "complete"
      } else if index == step.position && step.blocked {
        "blocked"
      } else if index == step.position {
        "current"
      } else {
        "next"
      }
      @html.div(
        class="moonbook-progress-step {state}",
        attrs=@html.Attrs::build()
          .role("listitem")
          .aria_current(
            if state == "current" || state == "blocked" {
              "step"
            } else {
              "false"
            },
          ),
        [ui_icon(pair.1, size=18), @html.span(pair.2)],
      )
    }),
  )
}

///|
fn render_bookkeeper_primary_action(
  emit : @rabbita.Emit[Msg],
  model : Model,
  step : BookkeeperJourneyStep,
) -> @rabbita.Html {
  match step.action {
    "replay" =>
      @html.button(
        class="moonbook-primary-action",
        title="Recover and verify from the durable journal",
        disabled=model.bookkeeper_busy,
        on_click=emit(ReplayBookkeeper),
        [ui_icon("verify"), @html.span("Replay and verify")],
      )
    "select" =>
      @html.a(
        class="moonbook-primary-action",
        title="Go to the available review records",
        href="#bookkeeper-lanes",
        [ui_icon("record"), @html.span("Choose a record")],
      )
    "prepare-review" =>
      @html.button(
        class="moonbook-primary-action",
        title="Prepare a review bound to this exact record",
        on_click=emit(SetBookkeeperMode("review")),
        [ui_icon("review"), @html.span("Prepare review")],
      )
    "submit-review" =>
      @html.button(
        class="moonbook-primary-action",
        title="Save the named-human review as durable evidence",
        disabled=model.bookkeeper_busy ||
          model.bookkeeper_draft.trim().is_blank(),
        on_click=emit(SubmitBookkeeperMutation),
        [ui_icon("review"), @html.span("Save governed review")],
      )
    "install-authority" =>
      @html.details(class="moonbook-technical-disclosure", [
        @html.summary(title="Show the safe authority recovery step", [
          ui_icon("authority"),
          @html.span("Show permission setup"),
        ]),
        @html.p(
          style=["margin:8px 0 4px", "color:#fde68a"],
          "Run this outside the browser, then reload this page:",
        ),
        @html.code(
          style=[
            "display:block", "padding:10px", "background:#020617", "border-radius:10px",
            "overflow-wrap:anywhere",
          ],
          "moonbook bookkeeper authority install <book-root> <reviewer-grant.json>",
        ),
      ])
    _ =>
      @html.span(
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        "Working…",
      )
  }
}

///|
fn bookkeeper_operator_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let step = bookkeeper_journey_step(model)
  let project_readiness = governed_work_order_draft(model, false)
  let egress_readiness = governed_work_order_draft(model, true)
  let authority_buttons = match model.bookkeeper_authorities {
    Some(registry) =>
      registry.grants
      .filter(grant => grant.active)
      .map(fn(grant) {
        let selected = model.selected_bookkeeper_authority ==
          Some(grant.authority_ref)
        @html.button(
          class="moonbook-secondary-action",
          title="Use {grant.reviewer_id} for this review",
          style=if selected {
            ["border:2px solid #60a5fa", "background:rgba(37,99,235,.18)"]
          } else {
            []
          },
          attrs=@html.Attrs::build().aria_pressed(
            if selected {
              "true"
            } else {
              "false"
            },
          ),
          on_click=emit(SelectBookkeeperAuthority(grant.authority_ref)),
          [ui_icon("authority", size=18), @html.span(grant.reviewer_id)],
        )
      })
    None => []
  }
  @html.article(
    style=[
      "padding:20px", "border-radius:22px", "background:#0f172a", "color:#f8fafc",
      "display:grid", "gap:16px",
    ],
    [
      @html.div([
        @html.p(
          style=[
            "margin:0 0 5px", "color:#93c5fd", "font-size:12px", "font-weight:800",
            "letter-spacing:.06em", "text-transform:uppercase",
          ],
          "Your next step",
        ),
        @html.h3(style=["margin:0 0 6px", "font-size:22px"], step.title),
        @html.p(
          style=["margin:0", "color:#cbd5e1", "line-height:1.55"],
          step.detail,
        ),
      ]),
      render_bookkeeper_progress(step),
      @html.div(
        style=[
          "display:flex", "align-items:center", "gap:12px", "flex-wrap:wrap",
        ],
        [
          render_bookkeeper_primary_action(emit, model, step),
          if step.action == "replay" {
            @html.nothing
          } else {
            @html.button(
              class="moonbook-secondary-action",
              title="Reload Bookkeeper state from durable evidence",
              disabled=model.bookkeeper_busy,
              on_click=emit(ReplayBookkeeper),
              [ui_icon("verify", size=18), @html.span("Replay state")],
            )
          },
        ],
      ),
      if authority_buttons.is_empty() {
        @html.p(
          id="bookkeeper-authority-help",
          style=["margin:0", "color:#fde68a", "font-size:13px"],
          "No active named reviewer is installed. The browser cannot grant its own authority.",
        )
      } else {
        @html.div(
          style=["display:flex", "gap:8px", "flex-wrap:wrap"],
          authority_buttons,
        )
      },
      @html.details(class="moonbook-technical-disclosure", [
        @html.summary(
          title="Inspect advanced operations and exact evidence JSON",
          [ui_icon("settings"), @html.span("Evidence and advanced operations")],
        ),
        @html.div(style=["display:grid", "gap:12px", "padding-top:12px"], [
          @html.div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
            @html.button(on_click=emit(SetBookkeeperMode("ingress")), "Ingress"),
            @html.button(on_click=emit(SetBookkeeperMode("record")), "Record"),
            @html.button(on_click=emit(SetBookkeeperMode("review")), "Review"),
            @html.button(on_click=emit(SetBookkeeperMode("egress")), "Egress"),
            @html.button(
              disabled=project_readiness is Err(_),
              on_click=emit(SetBookkeeperMode("project-work-order")),
              "Project work order",
            ),
            @html.button(
              disabled=egress_readiness is Err(_),
              on_click=emit(SetBookkeeperMode("egress-work-order")),
              "Authorize egress",
            ),
          ]),
          @html.small(
            style=["color:#fbbf24"],
            match project_readiness {
              Ok(_) =>
                "Work-order projection is ready; a second human review is still required."
              Err(reason) => "Work-order blocker: " + reason
            },
          ),
          @html.small(
            style=["color:#fbbf24"],
            match egress_readiness {
              Ok(_) => "Reviewed egress is ready for MoonFlow delivery."
              Err(reason) => "Egress blocker: " + reason
            },
          ),
          @html.small(
            style=[
              "color:#93c5fd", "font-family:'Fira Code','SFMono-Regular',monospace",
            ],
            "operation · {model.bookkeeper_mode}",
          ),
          @html.textarea(
            value=model.bookkeeper_draft,
            title="Exact governed mutation JSON",
            attrs=@html.Attrs::build().aria_label(
              "Exact governed mutation JSON",
            ),
            on_input=value => emit(SetBookkeeperDraft(value)),
            disabled=model.bookkeeper_busy,
            style=[
              "width:100%", "min-height:240px", "box-sizing:border-box", "padding:14px",
              "border-radius:14px", "border:1px solid #475569", "background:#020617",
              "color:#e2e8f0", "font-family:'Fira Code','SFMono-Regular',monospace",
              "font-size:12px", "line-height:1.55", "resize:vertical",
            ],
            ([] : Array[@rabbita.Html]),
          ),
        ]),
      ]),
      match model.bookkeeper_notice {
        Some(notice) =>
          @html.pre(
            style=["margin:0", "white-space:pre-wrap", "color:#bfdbfe"],
            attrs=@html.Attrs::build().role("status").aria_live("polite"),
            notice,
          )
        None => @html.nothing
      },
    ],
  )
}
