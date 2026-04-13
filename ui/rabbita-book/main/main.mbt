///|
using @html {
  a,
  article,
  aside,
  button,
  code,
  div,
  h1,
  h2,
  h3,
  header,
  input,
  li,
  main_,
  p,
  pre,
  section,
  small,
  span,
  ul,
}

///|
struct WorkspaceMetric {
  label : String
  value : String
  note : String
  tone : String
} derive(Show, FromJson)

///|
struct WorkflowItem {
  title : String
  detail : String
  status : String
} derive(Show, FromJson)

///|
struct PanelItem {
  title : String
  detail : String
  meta : String
} derive(Show, FromJson)

///|
struct StatusChip {
  label : String
  tone : String
} derive(Show, FromJson)

///|
struct ChapterLink {
  title : String
  href : String
  source_path : String
  number : String
} derive(Show, FromJson)

///|
struct UiState {
  title : String
  summary : String
  status_chips : Array[StatusChip]
  metrics : Array[WorkspaceMetric]
  workflow : Array[WorkflowItem]
  review_queue : Array[PanelItem]
  keeper_items : Array[PanelItem]
  page_families : Array[PanelItem]
  chapters : Array[ChapterLink]
  synthesis_preview : String
} derive(Show, FromJson)

///|
struct Model {
  loading : Bool
  state : UiState
  error : String?
}

///|
enum Msg {
  Loaded(Result[UiState, String])
}

///|
fn demo_state() -> UiState {
  {
    title: "MoonBook",
    summary: "A single Rabbita surface for reading chapters, inspecting workspace health, and steering Keeper-driven maintenance.",
    status_chips: [
      { label: "healthy", tone: "healthy" },
      { label: "pending review", tone: "review" },
      { label: "planning pressure", tone: "alert" },
    ],
    metrics: workspace_metrics(),
    workflow: workflow_items(),
    review_queue: review_queue_items(),
    keeper_items: keeper_items(),
    page_families: chapter_preview_items(),
    chapters: [
      { title: "Home", href: "index.html", source_path: "Home.md", number: "1" },
      {
        title: "Claims Register",
        href: "synthesis/claims.html",
        source_path: "synthesis/claims.md",
        number: "2",
      },
      {
        title: "Synthesis Map",
        href: "synthesis/map.html",
        source_path: "synthesis/map.md",
        number: "3",
      },
      {
        title: "Evidence",
        href: "synthesis/evidence.html",
        source_path: "synthesis/evidence.md",
        number: "4",
      },
    ],
    synthesis_preview: "## Coverage\n- Source pages: 12\n- Entity pages: 7\n- Concept pages: 5\n- Claim entries: 19\n- Evidence records: 18\n\n## Entity Hubs\n- wiki/entities/moonbook.md score=11\n- wiki/entities/moonclaw.md score=8\n\n## Open Loops\n- Pending reviews: 4\n- Low-confidence claims: 3\n- Keeper working memory is crowded: 8",
  }
}

///|
fn app_shell_style() -> Array[String] {
  [
    "min-height:100vh", "padding:32px", "box-sizing:border-box", "background:radial-gradient(circle at top left,#dbeafe 0,#f8fafc 36%,#f1f5f9 100%)",
    "color:#0f172a", "font-family:'Fira Sans','IBM Plex Sans','Avenir Next',sans-serif",
  ]
}

///|
fn page_grid_style() -> Array[String] {
  [
    "max-width:1480px", "margin:0 auto", "display:grid", "grid-template-columns:minmax(260px,320px) minmax(0,1fr)",
    "gap:24px", "align-items:start",
  ]
}

///|
fn panel_style() -> Array[String] {
  [
    "background:rgba(255,255,255,0.82)", "border:1px solid rgba(148,163,184,0.22)",
    "border-radius:26px", "box-shadow:0 26px 70px rgba(15,23,42,0.08)", "backdrop-filter:blur(18px)",
  ]
}

///|
fn muted_text_style() -> Array[String] {
  ["color:#475569", "line-height:1.65"]
}

///|
fn tone_style(tone : String) -> Array[String] {
  match tone {
    "healthy" => ["background:#dcfce7", "color:#166534"]
    "review" => ["background:#fef3c7", "color:#92400e"]
    "alert" => ["background:#fee2e2", "color:#991b1b"]
    _ => ["background:#dbeafe", "color:#1d4ed8"]
  }
}

///|
fn status_chip(text : String, tone : String) -> @rabbita.Html {
  span(
    style=[
        "display:inline-flex", "align-items:center", "gap:8px", "padding:7px 12px",
        "border-radius:999px", "font-size:12px", "font-weight:700", "letter-spacing:.04em",
        "text-transform:uppercase",
      ] +
      tone_style(tone),
    text,
  )
}

///|
fn nav_link(
  label : String,
  href : String,
  current? : Bool = false,
) -> @rabbita.Html {
  let background = if current {
    "linear-gradient(135deg,#dbeafe,#eff6ff)"
  } else {
    "transparent"
  }
  let border = if current {
    "1px solid rgba(37,99,235,0.24)"
  } else {
    "1px solid transparent"
  }
  a(
    href~,
    style=[
      "display:flex",
      "justify-content:space-between",
      "align-items:center",
      "padding:12px 14px",
      "border-radius:16px",
      "text-decoration:none",
      "color:#0f172a",
      "background:\{background}",
      "border:\{border}",
      "transition:all .22s ease",
      "cursor:pointer",
    ],
    [
      span(style=["font-weight:600"], label),
      span(style=["color:#64748b", "font-size:12px"], "open"),
    ],
  )
}

///|
fn render_chapter_link(chapter : ChapterLink, index : Int) -> @rabbita.Html {
  let background = if index == 0 {
    "linear-gradient(180deg,rgba(37,99,235,.10),rgba(37,99,235,.04))"
  } else {
    "rgba(255,255,255,.55)"
  }
  li(style=["list-style:none"], [
    a(
      href=chapter.href,
      style=[
        "display:grid",
        "grid-template-columns:44px minmax(0,1fr)",
        "gap:12px",
        "align-items:start",
        "padding:13px 12px",
        "border-radius:18px",
        "text-decoration:none",
        "color:#0f172a",
        "background:\{background}",
        "border:1px solid rgba(148,163,184,0.18)",
        "cursor:pointer",
      ],
      [
        div(
          style=[
            "width:44px", "height:44px", "border-radius:14px", "display:flex", "align-items:center",
            "justify-content:center", "font-family:'Fira Code','SFMono-Regular',monospace",
            "font-weight:700", "font-size:13px", "background:#eff6ff", "color:#1d4ed8",
          ],
          chapter.number,
        ),
        div([
          span(
            style=[
              "display:block", "font-size:15px", "font-weight:700", "margin-bottom:4px",
            ],
            chapter.title,
          ),
          small(
            style=["display:block", "color:#64748b", "line-height:1.45"],
            chapter.source_path,
          ),
        ]),
      ],
    ),
  ])
}

///|
fn render_chapter_links(chapters : Array[ChapterLink]) -> Array[@rabbita.Html] {
  let items : Array[@rabbita.Html] = []
  for i = 0; i < chapters.length(); i = i + 1 {
    items.push(render_chapter_link(chapters[i], i))
  }
  items
}

///|
fn workspace_metrics() -> Array[WorkspaceMetric] {
  [
    {
      label: "Pending Review",
      value: "4",
      note: "Two query promotions and two result merges are waiting.",
      tone: "review",
    },
    {
      label: "Evidence Coverage",
      value: "18",
      note: "Persisted results now append support records into the wiki.",
      tone: "healthy",
    },
    {
      label: "Open Loops",
      value: "3",
      note: "Crowded working memory, low-confidence claims, and stale planning notes.",
      tone: "alert",
    },
    {
      label: "Entity Hubs",
      value: "7",
      note: "High-link pages surfaced through the synthesis map.",
      tone: "info",
    },
  ]
}

///|
fn workflow_items() -> Array[WorkflowItem] {
  [
    {
      title: "Ingest",
      detail: "Sources update entity, concept, claim, relationship, and synthesis-map pages in one pass.",
      status: "active",
    },
    {
      title: "Query",
      detail: "Saved answers propagate signals into cited pages and queue promotion review when needed.",
      status: "active",
    },
    {
      title: "Review",
      detail: "Approved query insights now land in overview plus cited source/entity/concept pages.",
      status: "expanded",
    },
    {
      title: "Keeper",
      detail: "Memory, evidence, and insight surfaces stay bounded and visible to the operator.",
      status: "stable",
    },
  ]
}

///|
fn review_queue_items() -> Array[PanelItem] {
  [
    {
      title: "Result review | task-memory",
      detail: "Promote durable memory into `concepts/harness.md` and refresh support tracking.",
      meta: "merge policy: promote-durable",
    },
    {
      title: "Query review | retrieval synthesis",
      detail: "Apply approved insight into cited entity and concept pages, not only the overview.",
      meta: "merge policy: promote-query-insight",
    },
    {
      title: "Claim review | Architecture Notes",
      detail: "Resolve conflicting low-confidence statements and mark superseded claims explicitly.",
      meta: "merge policy: claim-resolution",
    },
  ]
}

///|
fn keeper_items() -> Array[PanelItem] {
  [
    {
      title: "Active Memory",
      detail: "Reusable domain rules and recent accepted findings.",
      meta: "10 entries",
    },
    {
      title: "Working Memory",
      detail: "Short-lived task pressure; prune when the count crosses the review threshold.",
      meta: "8 entries / crowded",
    },
    {
      title: "Keeper Insights",
      detail: "Derived cleanup guidance from review backlog, evidence coverage, and claim confidence.",
      meta: "3 actions pending",
    },
  ]
}

///|
fn chapter_preview_items() -> Array[PanelItem] {
  [
    {
      title: "Claims Register",
      detail: "Now stores claim ids, kinds, related pages, support, confidence, and supersession fields.",
      meta: "synthesis/claims.md",
    },
    {
      title: "Synthesis Map",
      detail: "Tracks coverage counts, hub pages, and open loops so planning pressure is visible.",
      meta: "synthesis/map.md",
    },
    {
      title: "Evidence",
      detail: "Structured support records for persisted results and review outcomes.",
      meta: "synthesis/evidence.md",
    },
  ]
}

///|
fn metric_card(metric : WorkspaceMetric) -> @rabbita.Html {
  article(
    style=panel_style() +
      ["padding:18px", "display:flex", "flex-direction:column", "gap:12px"],
    [
      div(
        style=[
          "display:flex", "justify-content:space-between", "align-items:center",
          "gap:12px",
        ],
        [
          small(
            style=[
              "font-size:12px", "font-weight:700", "letter-spacing:.05em", "text-transform:uppercase",
              "color:#64748b",
            ],
            metric.label,
          ),
          status_chip(metric.tone, metric.tone),
        ],
      ),
      div(
        style=[
          "font-family:'Fira Code','SFMono-Regular',monospace", "font-size:34px",
          "font-weight:700", "letter-spacing:-.03em",
        ],
        metric.value,
      ),
      p(style=muted_text_style() + ["margin:0", "font-size:14px"], metric.note),
    ],
  )
}

///|
fn workflow_card(item : WorkflowItem, index : Int) -> @rabbita.Html {
  let tone = if index == 2 {
    "review"
  } else if index == 3 {
    "healthy"
  } else {
    "info"
  }
  article(
    style=panel_style() +
      ["padding:18px", "display:flex", "flex-direction:column", "gap:14px"],
    [
      div(
        style=[
          "display:flex", "justify-content:space-between", "align-items:center",
          "gap:12px",
        ],
        [
          h3(style=["margin:0", "font-size:18px"], item.title),
          status_chip(item.status, tone),
        ],
      ),
      p(style=muted_text_style() + ["margin:0"], item.detail),
    ],
  )
}

///|
fn render_workflow_cards(items : Array[WorkflowItem]) -> Array[@rabbita.Html] {
  let cards : Array[@rabbita.Html] = []
  for i = 0; i < items.length(); i = i + 1 {
    cards.push(workflow_card(items[i], i))
  }
  cards
}

///|
fn panel_list(
  title : String,
  subtitle : String,
  items : Array[PanelItem],
) -> @rabbita.Html {
  section(
    style=panel_style() +
      ["padding:22px", "display:flex", "flex-direction:column", "gap:18px"],
    [
      div([
        h2(style=["margin:0 0 6px 0", "font-size:22px"], title),
        p(style=muted_text_style() + ["margin:0"], subtitle),
      ]),
      div(
        style=["display:grid", "gap:12px"],
        items.map(fn(item) {
          article(
            style=[
              "padding:16px", "border-radius:18px", "background:rgba(248,250,252,.88)",
              "border:1px solid rgba(148,163,184,.18)",
            ],
            [
              div(
                style=[
                  "display:flex", "justify-content:space-between", "align-items:flex-start",
                  "gap:12px",
                ],
                [
                  h3(style=["margin:0", "font-size:16px"], item.title),
                  span(
                    style=[
                      "padding:5px 9px", "border-radius:999px", "background:#e2e8f0",
                      "color:#334155", "font-size:11px", "font-weight:700", "text-transform:uppercase",
                    ],
                    item.meta,
                  ),
                ],
              ),
              p(style=muted_text_style() + ["margin:10px 0 0 0"], item.detail),
            ],
          )
        }),
      ),
    ],
  )
}

///|
fn render_sidebar(state : UiState, model : Model) -> @rabbita.Html {
  let sidebar_note = match model.error {
    Some(error) =>
      "Using fallback snapshot because `moonbook-ui-state.json` could not be loaded: \{error}"
    None =>
      "The UI is now bound to `moonbook-ui-state.json` when the generated snapshot is present."
  }
  aside(
    style=panel_style() +
      [
        "padding:22px", "position:sticky", "top:24px", "display:flex", "flex-direction:column",
        "gap:24px",
      ],
    [
      div([
        span(
          style=[
            "display:inline-flex", "padding:7px 12px", "border-radius:999px", "background:#dbeafe",
            "color:#1d4ed8", "font-size:12px", "font-weight:700", "letter-spacing:.05em",
            "text-transform:uppercase",
          ],
          "MoonBook UI",
        ),
        h1(
          style=[
            "margin:16px 0 10px 0", "font-size:34px", "line-height:1.05", "letter-spacing:-.04em",
          ],
          state.title,
        ),
        p(style=muted_text_style() + ["margin:0"], state.summary),
      ]),
      div(style=["display:grid", "gap:8px"], [
        nav_link("Workspace Overview", "#overview", current=true),
        nav_link("Review Queue", "#reviews"),
        nav_link("Synthesis Map", "#map"),
        nav_link("Keeper State", "#keeper"),
      ]),
      div([
        h3(style=["margin:0 0 12px 0", "font-size:16px"], "Reading Surface"),
        ul(
          style=["display:grid", "gap:10px", "padding:0", "margin:0"],
          render_chapter_links(state.chapters),
        ),
      ]),
      article(
        style=[
          "padding:18px", "border-radius:20px", "background:linear-gradient(180deg,#0f172a,#1e293b)",
          "color:#e2e8f0", "display:flex", "flex-direction:column", "gap:12px",
        ],
        [
          small(
            style=[
              "font-size:12px", "text-transform:uppercase", "letter-spacing:.05em",
              "color:#93c5fd",
            ],
            "Next Step",
          ),
          h3(
            style=["margin:0", "font-size:18px"],
            if model.loading {
              "Loading workspace snapshot."
            } else {
              "Live workspace snapshot loaded."
            },
          ),
          p(
            style=["margin:0", "line-height:1.6", "color:#cbd5e1"],
            sidebar_note,
          ),
        ],
      ),
    ],
  )
}

///|
fn hero_section(state : UiState, model : Model) -> @rabbita.Html {
  let search_value = if state.chapters.is_empty() {
    "synthesis map"
  } else {
    state.chapters[0].title.to_lower()
  }
  header(
    id="overview",
    style=panel_style() +
      [
        "padding:28px", "display:flex", "flex-direction:column", "gap:22px", "overflow:hidden",
        "position:relative",
      ],
    [
      div(
        style=[
          "position:absolute", "inset:auto -120px -140px auto", "width:320px", "height:320px",
          "border-radius:999px", "background:radial-gradient(circle,rgba(37,99,235,.18),rgba(37,99,235,0))",
          "pointer-events:none",
        ],
        "",
      ),
      div(
        style=[
          "display:flex", "justify-content:space-between", "align-items:flex-start",
          "gap:20px", "flex-wrap:wrap",
        ],
        [
          div(style=["max-width:760px"], [
            span(
              style=[
                "display:inline-flex", "padding:7px 12px", "border-radius:999px",
                "background:#eff6ff", "color:#1d4ed8", "font-size:12px", "font-weight:700",
                "text-transform:uppercase", "letter-spacing:.05em",
              ],
              "Swiss docs console",
            ),
            h1(
              style=[
                "margin:16px 0 14px 0", "font-size:50px", "line-height:.98", "letter-spacing:-.06em",
                "max-width:14ch",
              ],
              state.title,
            ),
            p(
              style=muted_text_style() +
                ["margin:0", "max-width:64ch", "font-size:17px"],
              state.summary,
            ),
          ]),
          div(
            style=["display:grid", "gap:10px", "min-width:230px"],
            state.status_chips.map(fn(chip) {
              status_chip(chip.label, chip.tone)
            }),
          ),
        ],
      ),
      div(
        style=[
          "display:grid", "grid-template-columns:minmax(0,1fr) auto", "gap:12px",
          "align-items:center",
        ],
        [
          input(
            placeholder="Search claims, chapters, concepts, or keeper notes",
            value=search_value,
            read_only=true,
            style=[
              "width:100%", "padding:15px 18px", "border-radius:18px", "border:1px solid rgba(148,163,184,.24)",
              "background:rgba(255,255,255,.88)", "font-size:15px", "color:#0f172a",
              "box-sizing:border-box",
            ],
            "",
          ),
          button(
            style=[
              "padding:15px 18px", "border:none", "border-radius:18px", "background:#2563eb",
              "color:#fff", "font-weight:700", "cursor:pointer", "box-shadow:0 16px 35px rgba(37,99,235,.22)",
              "transition:transform .2s ease, box-shadow .2s ease",
            ],
            if model.loading {
              "Loading"
            } else {
              "Open Search"
            },
          ),
        ],
      ),
    ],
  )
}

///|
fn render_page(model : Model) -> @rabbita.Html {
  let state = model.state
  let operator_note = match model.error {
    Some(error) => "Last load error: \{error}"
    None => "Workspace snapshot currently available."
  }
  div(style=app_shell_style(), [
    div(style=page_grid_style(), [
      render_sidebar(state, model),
      main_(style=["display:grid", "gap:24px"], [
        hero_section(state, model),
        section(
          style=[
            "display:grid", "grid-template-columns:repeat(4,minmax(0,1fr))", "gap:14px",
          ],
          state.metrics.map(metric_card),
        ),
        section(
          style=[
            "display:grid", "grid-template-columns:minmax(0,1.45fr) minmax(0,.95fr)",
            "gap:24px", "align-items:start",
          ],
          [
            section(style=["display:grid", "gap:14px"], [
              div([
                h2(
                  style=["margin:0 0 8px 0", "font-size:28px"],
                  "Workflow Surface",
                ),
                p(
                  style=muted_text_style() + ["margin:0"],
                  "The UI mirrors the current MoonBook loop using generated workspace state instead of hardcoded demo counters.",
                ),
              ]),
              div(
                style=[
                  "display:grid", "grid-template-columns:repeat(2,minmax(0,1fr))",
                  "gap:14px",
                ],
                render_workflow_cards(state.workflow),
              ),
              panel_list(
                "Review Queue",
                "High-value merges and promotions should be legible before they become durable wiki edits.",
                state.review_queue,
              ),
            ]),
            section(style=["display:grid", "gap:14px"], [
              panel_list(
                "Keeper State",
                "Bounded memory needs its own operator panel instead of disappearing into file names.",
                state.keeper_items,
              ),
              panel_list(
                "Page Families",
                "The reading UI should make the maintained surfaces feel like a product map, not just markdown files.",
                state.page_families,
              ),
            ]),
          ],
        ),
        section(
          id="map",
          style=panel_style() +
            [
              "padding:24px", "display:grid", "grid-template-columns:minmax(0,1fr) minmax(320px,.9fr)",
              "gap:22px",
            ],
          [
            div([
              h2(
                style=["margin:0 0 8px 0", "font-size:28px"],
                "Synthesis Map Preview",
              ),
              p(
                style=muted_text_style() + ["margin:0 0 18px 0"],
                "A dedicated surface for coverage, hubs, and open loops makes local planning tangible. This is the part the old Rabbita shell was missing.",
              ),
              pre(
                style=[
                  "margin:0", "padding:18px", "border-radius:20px", "background:#0f172a",
                  "color:#dbeafe", "overflow:auto", "font-family:'Fira Code','SFMono-Regular',monospace",
                  "font-size:13px", "line-height:1.7",
                ],
                [code(state.synthesis_preview)],
              ),
            ]),
            article(
              id="keeper",
              style=[
                "padding:20px", "border-radius:22px", "background:linear-gradient(180deg,#eff6ff,#ffffff)",
                "border:1px solid rgba(37,99,235,.15)", "display:flex", "flex-direction:column",
                "gap:14px",
              ],
              [
                small(
                  style=[
                    "font-size:12px", "font-weight:700", "letter-spacing:.05em",
                    "text-transform:uppercase", "color:#1d4ed8",
                  ],
                  "Operator Notes",
                ),
                h3(
                  style=["margin:0", "font-size:22px"],
                  "What the UI now covers",
                ),
                ul(
                  style=[
                    "margin:0", "padding-left:18px", "display:grid", "gap:10px",
                    "color:#334155", "line-height:1.6",
                  ],
                  [
                    li("Reader navigation for the maintained page families."),
                    li(
                      "Dashboard view for review backlog, evidence, and open loops.",
                    ),
                    li(
                      "A synthesis map panel that reflects the generated planning layer.",
                    ),
                    li(
                      if model.loading {
                        "Loading snapshot from `moonbook-ui-state.json`."
                      } else {
                        "Snapshot loaded from `moonbook-ui-state.json`."
                      },
                    ),
                    li(operator_note),
                  ],
                ),
                button(
                  style=[
                    "margin-top:auto", "padding:13px 16px", "border:none", "border-radius:16px",
                    "background:#0f172a", "color:#fff", "font-weight:700", "cursor:pointer",
                  ],
                  "Snapshot Ready",
                ),
              ],
            ),
          ],
        ),
      ]),
    ]),
  ])
}

///|
#cfg(target="js")
test {
  ignore(render_page)
  ignore(metric_card)
  ignore(panel_list)
  ignore(fetch_ui_state_cmd)
}

///|
fn fetch_ui_state_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "./moonbook-ui-state.json",
    expect=@http.Json(fn(result) { dispatch(Loaded(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid ui snapshot")
      }
    }),
  )
}

///|
fn update(msg : Msg, model : Model) -> Model {
  match msg {
    Loaded(Ok(state)) => { loading: false, state, error: None }
    Loaded(Err(error)) => { ..model, loading: false, error: Some(error) }
  }
}

///|
fn main {
  let (dispatch, cell) = @rabbita.simple_cell_with_dispatch(
    model={ loading: true, state: demo_state(), error: None },
    update~,
    view=(_, model) => render_page(model),
  )
  let app = @rabbita.new(cell)
  app.with_init(fetch_ui_state_cmd(dispatch))
  app.mount("app")
}
