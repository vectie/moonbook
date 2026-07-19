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
  textarea,
  ul,
}

///|
struct WorkspaceMetric {
  label : String
  value : String
  note : String
  tone : String
} derive(Debug, FromJson)

///|
struct WorkflowItem {
  title : String
  detail : String
  status : String
} derive(Debug, FromJson)

///|
struct PanelItem {
  title : String
  detail : String
  meta : String
} derive(Debug, FromJson)

///|
struct StatusChip {
  label : String
  tone : String
} derive(Debug, FromJson)

///|
struct ChapterLink {
  title : String
  href : String
  source_path : String
  number : String
} derive(Debug, FromJson)

///|
struct BookkeeperItem {
  stage : String
  title : String
  record_id : String
  record_version : String
  status : String
  tone : String
  summary : String
  owner_route : String
  evidence_count : Int
  issue_count : Int
  requires_human_review : Bool
  next_action : String
} derive(Debug, FromJson)

///|
struct BookkeeperRecordReference {
  record_id : String
  record_version : String
  record_digest : String
} derive(Debug, ToJson, FromJson)

///|
struct BookkeeperEvidenceReference {
  reference_id : String
  reference_version : String
  digest : String
  provenance_ref : String
} derive(Debug, ToJson, FromJson)

///|
struct BookkeeperRawRecord {
  contract_version : String
  record : BookkeeperRecordReference
  stage : Json
  subject : BookkeeperRecordReference?
  links : Array[BookkeeperRecordReference]
  title : String
  summary : String
  owner_route : String
  status : String
  evidence_refs : Array[BookkeeperEvidenceReference]
  issue_refs : Array[String]
  requires_human_review : Bool
  next_action : String
  source_product : String
  recorded_at : Int
  payload : Json
  side_effects_applied : Bool
} derive(Debug, ToJson, FromJson)

///|
struct BookkeeperStoreSnapshot {
  contract_version : String
  last_sequence : Int
  records : Array[BookkeeperRawRecord]
  reviews : Array[Json]
  envelopes : Array[Json]
  replay_issues : Array[String]
} derive(Debug, FromJson)

///|
struct BookkeeperAuthorityGrant {
  contract_version : String
  grant : BookkeeperRecordReference
  reviewer_id : String
  reviewer_kind : Json
  authority_ref : String
  evidence_refs : Array[String]
  active : Bool
  granted_at : Int
} derive(Debug, ToJson, FromJson)

///|
struct BookkeeperAuthorityRegistry {
  contract_version : String
  grants : Array[BookkeeperAuthorityGrant]
} derive(Debug, FromJson)

///|
struct BookkeeperReviewerAuthority {
  grant : BookkeeperRecordReference
  reviewer_id : String
  authority_ref : String
  authorized : Bool
  evidence_refs : Array[String]
} derive(Debug, ToJson)

///|
struct BookkeeperReviewDraft {
  contract_version : String
  mutation : BookkeeperRecordReference
  receipt : BookkeeperRecordReference
  stage : Json
  subject : BookkeeperRecordReference
  requested : String
  reviewer_kind : Json
  reviewer : BookkeeperReviewerAuthority
  evidence_refs : Array[BookkeeperEvidenceReference]
  summary : String
  decided_at : Int
} derive(Debug, ToJson)

///|
struct BookkeeperMutationResult {
  accepted : Bool
  idempotent : Bool
  event : BookkeeperRecordReference?
  review : Json?
  issues : Array[String]
  ui_state_path : String
} derive(Debug, FromJson)

///|
struct BookkeeperBrowserResponse {
  ok : Bool
  status : Int
  body : String
  error : String?
} derive(Debug, FromJson)

///|
struct BookkeeperState {
  contract_version : String
  projection_version : String
  source_path : String
  loaded : Bool
  deliverable_acceptance : Array[BookkeeperItem]
  outcome_binding : Array[BookkeeperItem]
  three_gap_findings : Array[BookkeeperItem]
  three_gap_review : Array[BookkeeperItem]
  capability_proposal : Array[BookkeeperItem]
  capability_review : Array[BookkeeperItem]
  mooncode_work_order : Array[BookkeeperItem]
  evaluation : Array[BookkeeperItem]
  adoption : Array[BookkeeperItem]
} derive(Debug, FromJson)

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
  bookkeeper : BookkeeperState
} derive(Debug, FromJson)

///|
struct UiClientConfig {
  live_reload_endpoint : String?
} derive(Debug, FromJson)

///|
struct Model {
  loading : Bool
  state : UiState
  error : String?
  refresh_count : Int
  live_reload_endpoint : String?
  locale : InterfaceLocale
  bookkeeper_store : BookkeeperStoreSnapshot?
  bookkeeper_authorities : BookkeeperAuthorityRegistry?
  selected_bookkeeper_record : BookkeeperRecordReference?
  selected_bookkeeper_authority : String?
  bookkeeper_mode : String
  bookkeeper_draft : String
  bookkeeper_busy : Bool
  bookkeeper_notice : String?
}

///|
enum Msg {
  Loaded(Result[UiState, Error])
  LoadedConfig(Result[UiClientConfig, Error])
  SetInterfaceLocale(InterfaceLocale)
  UseSystemInterfaceLocale
  LoadedBookkeeperStore(Result[BookkeeperStoreSnapshot, Error])
  LoadedBookkeeperAuthorities(Result[BookkeeperAuthorityRegistry, Error])
  SelectBookkeeperItem(BookkeeperItem)
  SelectBookkeeperAuthority(String)
  SetBookkeeperMode(String)
  SetBookkeeperDraft(String)
  SubmitBookkeeperMutation
  BookkeeperMutationFinished(Result[BookkeeperMutationResult, String])
  ReplayBookkeeper
  BookkeeperReplayFinished(Result[BookkeeperStoreSnapshot, String])
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
    bookkeeper: {
      contract_version: "moonbook.bookkeeper.v1",
      projection_version: "moonbook.bookkeeper.ui.v1",
      source_path: ".moonbook/bookkeeper/ui-state.json",
      loaded: false,
      deliverable_acceptance: [],
      outcome_binding: [],
      three_gap_findings: [],
      three_gap_review: [],
      capability_proposal: [],
      capability_review: [],
      mooncode_work_order: [],
      evaluation: [],
      adoption: [],
    },
  }
}

///|
fn app_shell_style() -> Array[String] {
  [
    "min-height:100vh", "padding:clamp(14px,3vw,32px)", "box-sizing:border-box",
    "overflow-x:hidden", "background:radial-gradient(circle at top left,#dbeafe 0,#f8fafc 36%,#f1f5f9 100%)",
    "color:#0f172a", "font-family:'Fira Sans','IBM Plex Sans','Avenir Next',sans-serif",
  ]
}

///|
fn page_grid_style() -> Array[String] {
  [
    "max-width:1480px", "margin:0 auto", "display:flex", "flex-wrap:wrap", "gap:24px",
    "align-items:flex-start", "width:100%", "min-width:0", "box-sizing:border-box",
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
  locale : InterfaceLocale,
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
      span(
        style=["color:#64748b", "font-size:12px"],
        interface_message(locale, NavOpen),
      ),
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
      href=if chapter.href.has_prefix("/") ||
        chapter.href.has_prefix("http://") ||
        chapter.href.has_prefix("https://") {
        chapter.href
      } else {
        "/" + chapter.href
      },
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
fn bookkeeper_stage_label(
  locale : InterfaceLocale,
  stage : String,
) -> String {
  match (locale, stage) {
    (SimplifiedChinese, "deliverable_acceptance") => "交付验收"
    (SimplifiedChinese, "outcome_binding") => "结果绑定"
    (SimplifiedChinese, "three_gap_findings") => "三差距发现"
    (SimplifiedChinese, "three_gap_review") => "三差距审核"
    (SimplifiedChinese, "capability_proposal") => "能力提案"
    (SimplifiedChinese, "capability_review") => "能力审核"
    (SimplifiedChinese, "mooncode_work_order") => "MoonCode 工作单"
    (SimplifiedChinese, "evaluation") => "能力评估"
    (SimplifiedChinese, "adoption") => "能力采用"
    (_, "deliverable_acceptance") => "Deliverable Acceptance"
    (_, "outcome_binding") => "Outcome Binding"
    (_, "three_gap_findings") => "Three-Gap Findings"
    (_, "three_gap_review") => "Three-Gap Review"
    (_, "capability_proposal") => "Capability Proposal"
    (_, "capability_review") => "Capability Review"
    (_, "mooncode_work_order") => "MoonCode Work Order"
    (_, "evaluation") => "Capability Evaluation"
    (_, "adoption") => "Capability Adoption"
    _ => stage
  }
}

///|
fn bookkeeper_item_card(
  emit : @rabbita.Emit[Msg],
  locale : InterfaceLocale,
  item : BookkeeperItem,
  selected : Bool,
) -> @rabbita.Html {
  article(
    style=[
      "padding:16px", "border-radius:18px", "background:rgba(248,250,252,.92)",
      if selected { "border:2px solid #2563eb" } else { "border:1px solid rgba(148,163,184,.20)" },
      "display:grid", "gap:12px",
    ],
    [
      div(
        style=[
          "display:flex", "justify-content:space-between", "align-items:flex-start",
          "gap:12px", "flex-wrap:wrap",
        ],
        [
          div([
            h3(style=["margin:0", "font-size:16px"], item.title),
            small(
              style=[
                "display:block", "margin-top:5px", "color:#64748b",
                "font-family:'Fira Code','SFMono-Regular',monospace",
              ],
              if item.record_version.is_blank() {
                item.record_id
              } else {
                "\{item.record_id} · \{item.record_version}"
              },
            ),
          ]),
          status_chip(item.status, item.tone),
        ],
      ),
      p(style=muted_text_style() + ["margin:0"], item.summary),
      div(
        style=["display:flex", "gap:8px", "flex-wrap:wrap"],
        [
          span(
            style=[
              "padding:6px 9px", "border-radius:10px", "background:#e2e8f0",
              "color:#334155", "font-size:12px", "font-weight:700",
            ],
            "\{item.evidence_count} \{interface_message(locale, BookkeeperEvidence)}",
          ),
          span(
            style=[
              "padding:6px 9px", "border-radius:10px", "background:#e2e8f0",
              "color:#334155", "font-size:12px", "font-weight:700",
            ],
            "\{item.issue_count} \{interface_message(locale, BookkeeperIssues)}",
          ),
          status_chip(
            if item.requires_human_review {
              interface_message(locale, BookkeeperHumanReview)
            } else {
              interface_message(locale, BookkeeperAutomatedState)
            },
            if item.requires_human_review { "review" } else { "info" },
          ),
        ],
      ),
      div(
        style=[
          "display:flex", "justify-content:space-between", "gap:10px", "flex-wrap:wrap",
          "padding-top:10px", "border-top:1px solid rgba(148,163,184,.18)",
          "font-size:12px", "color:#475569",
        ],
        [
          span("owner · \{item.owner_route}"),
          span(
            style=["font-weight:700", "color:#1d4ed8"],
            "next · \{item.next_action}",
          ),
        ],
      ),
      button(
        style=[
          "padding:9px 12px", "border-radius:12px", "border:1px solid #cbd5e1",
          "background:#fff", "color:#0f172a", "font-weight:700", "cursor:pointer",
        ],
        on_click=emit(SelectBookkeeperItem(item)),
        if selected { "Selected for operator action" } else { "Select exact record" },
      ),
    ],
  )
}

///|
fn bookkeeper_lane(
  emit : @rabbita.Emit[Msg],
  locale : InterfaceLocale,
  stage : String,
  items : Array[BookkeeperItem],
  selected : BookkeeperRecordReference?,
) -> @rabbita.Html {
  article(
    style=[
      "padding:18px", "border-radius:22px", "background:rgba(255,255,255,.72)",
      "border:1px solid rgba(148,163,184,.20)", "display:flex", "flex-direction:column",
      "gap:14px", "min-width:0",
    ],
    [
      div(
        style=["display:flex", "justify-content:space-between", "gap:10px"],
        [
          h3(
            style=["margin:0", "font-size:17px"],
            bookkeeper_stage_label(locale, stage),
          ),
          status_chip("\{items.length()}", if items.is_empty() { "info" } else { "healthy" }),
        ],
      ),
      if items.is_empty() {
        p(
          style=muted_text_style() + ["margin:0", "font-size:14px"],
          interface_message(locale, BookkeeperNoRecords),
        )
      } else {
        div(
          style=["display:grid", "gap:12px"],
          items.map(fn(item) {
            let is_selected = match selected {
              Some(reference) =>
                reference.record_id == item.record_id &&
                reference.record_version == item.record_version
              None => false
            }
            bookkeeper_item_card(emit, locale, item, is_selected)
          }),
        )
      },
    ],
  )
}

///|
fn selected_raw_record(
  model : Model,
  reference : BookkeeperRecordReference,
) -> BookkeeperRawRecord? {
  guard model.bookkeeper_store is Some(snapshot) else { return None }
  for record in snapshot.records {
    if record.record.record_id == reference.record_id &&
      record.record.record_version == reference.record_version {
      return Some(record)
    }
  }
  None
}

///|
fn selected_authority_grant(model : Model) -> BookkeeperAuthorityGrant? {
  guard model.bookkeeper_authorities is Some(registry) else { return None }
  guard model.selected_bookkeeper_authority is Some(authority_ref) else {
    return None
  }
  for grant in registry.grants {
    if grant.active && grant.authority_ref == authority_ref {
      return Some(grant)
    }
  }
  None
}

///|
#cfg(target="js")
extern "js" fn bookkeeper_nonce() -> String = "()=>{const id=globalThis.crypto?.randomUUID?.()||`${Date.now()}-${Math.random().toString(16).slice(2)}`;return id}"

///|
#cfg(target="js")
extern "js" fn bookkeeper_now_ms() -> Int = "()=>Date.now()"

///|
fn review_draft_for_selection(model : Model) -> String? {
  guard model.selected_bookkeeper_record is Some(reference) else { return None }
  guard selected_raw_record(model, reference) is Some(record) else { return None }
  guard selected_authority_grant(model) is Some(grant) else { return None }
  let nonce = bookkeeper_nonce()
  let draft : BookkeeperReviewDraft = {
    contract_version: "moonbook.bookkeeper.store.v1",
    mutation: {
      record_id: "ui-review-mutation-\{nonce}",
      record_version: "v1",
      record_digest: "ui-session-\{nonce}",
    },
    receipt: {
      record_id: "ui-review-receipt-\{nonce}",
      record_version: "v1",
      record_digest: "ui-session-\{nonce}",
    },
    stage: record.stage,
    subject: record.record,
    requested: "Accept",
    reviewer_kind: grant.reviewer_kind,
    reviewer: {
      grant: grant.grant,
      reviewer_id: grant.reviewer_id,
      authority_ref: grant.authority_ref,
      authorized: grant.active,
      evidence_refs: grant.evidence_refs,
    },
    evidence_refs: record.evidence_refs,
    summary: "Named reviewer accepted the exact selected record and evidence.",
    decided_at: bookkeeper_now_ms(),
  }
  Some(draft.to_json().stringify(indent=2))
}

///|
fn bookkeeper_operator_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let authority_buttons = match model.bookkeeper_authorities {
    Some(registry) =>
      registry.grants.filter(grant => grant.active).map(fn(grant) {
        let selected = model.selected_bookkeeper_authority == Some(grant.authority_ref)
        button(
          style=[
            "padding:8px 11px", "border-radius:12px",
            if selected { "border:2px solid #2563eb" } else { "border:1px solid #cbd5e1" },
            "background:#fff", "cursor:pointer", "font-weight:700",
          ],
          on_click=emit(SelectBookkeeperAuthority(grant.authority_ref)),
          "\{grant.reviewer_id} · \{grant.authority_ref}",
        )
      })
    None => []
  }
  article(
    style=[
      "padding:18px", "border-radius:22px", "background:#0f172a", "color:#f8fafc",
      "display:grid", "gap:14px",
    ],
    [
      div([
        h3(style=["margin:0 0 6px 0"], "Governed loop operator"),
        p(
          style=["margin:0", "color:#cbd5e1", "font-size:14px"],
          "Ingress a generic MoonFlow envelope, record a stage, review an exact record, or emit the next generic envelope. Authority can only be installed with the MoonBook CLI.",
        ),
      ]),
      div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
        button(on_click=emit(SetBookkeeperMode("ingress")), "Ingress envelope"),
        button(on_click=emit(SetBookkeeperMode("record")), "Durable record"),
        button(on_click=emit(SetBookkeeperMode("review")), "Governed review"),
        button(on_click=emit(SetBookkeeperMode("egress")), "Egress envelope"),
      ]),
      div(style=["display:flex", "gap:8px", "flex-wrap:wrap"],
        if authority_buttons.is_empty() {
          [small(style=["color:#fbbf24"], "No active reviewer authority. Install one with `moonbook bookkeeper authority install`.")]
        } else {
          authority_buttons
        },
      ),
      small(
        style=["color:#93c5fd", "font-family:'Fira Code','SFMono-Regular',monospace"],
        "mode · \{model.bookkeeper_mode}",
      ),
      textarea(
        value=model.bookkeeper_draft,
        on_input=value => emit(SetBookkeeperDraft(value)),
        disabled=model.bookkeeper_busy,
        style=[
          "width:100%", "min-height:260px", "box-sizing:border-box", "padding:14px",
          "border-radius:14px", "border:1px solid #475569", "background:#020617",
          "color:#e2e8f0", "font-family:'Fira Code','SFMono-Regular',monospace",
          "font-size:12px", "line-height:1.55", "resize:vertical",
        ],
        ([] : Array[@rabbita.Html]),
      ),
      div(style=["display:flex", "gap:10px", "flex-wrap:wrap"], [
        button(
          disabled=model.bookkeeper_busy || model.bookkeeper_draft.trim().is_blank(),
          on_click=emit(SubmitBookkeeperMutation),
          "Submit governed mutation",
        ),
        button(
          disabled=model.bookkeeper_busy,
          on_click=emit(ReplayBookkeeper),
          "Replay durable journal",
        ),
      ]),
      match model.bookkeeper_notice {
        Some(notice) => pre(style=["margin:0", "white-space:pre-wrap", "color:#bfdbfe"], notice)
        None => small(style=["color:#94a3b8"], "Select a lane record to bind review JSON to its exact digest and evidence.")
      },
    ],
  )
}

///|
fn bookkeeper_console(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let locale = model.locale
  let state = model.state.bookkeeper
  section(
    id="bookkeeper",
    style=panel_style() +
      ["padding:24px", "display:grid", "gap:22px", "overflow:hidden"],
    [
      div(
        style=[
          "display:flex", "justify-content:space-between", "align-items:flex-start",
          "gap:18px", "flex-wrap:wrap",
        ],
        [
          div(style=["max-width:820px"], [
            h2(
              style=["margin:0 0 8px 0", "font-size:28px"],
              interface_message(locale, BookkeeperTitle),
            ),
            p(
              style=muted_text_style() + ["margin:0"],
              interface_message(locale, BookkeeperSubtitle),
            ),
          ]),
          div(style=["display:grid", "gap:8px", "justify-items:end"], [
            status_chip(
              if state.loaded {
                interface_message(locale, BookkeeperProjectionLoaded)
              } else {
                interface_message(locale, BookkeeperProjectionMissing)
              },
              if state.loaded { "healthy" } else { "review" },
            ),
            small(
              style=[
                "color:#64748b", "font-family:'Fira Code','SFMono-Regular',monospace",
                "max-width:54ch", "overflow-wrap:anywhere",
              ],
              "\{state.contract_version} · \{state.projection_version} · \{state.source_path}",
            ),
          ]),
        ],
      ),
      bookkeeper_operator_panel(emit, model),
      div(
        style=[
          "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr))",
          "gap:14px", "align-items:start",
        ],
        [
          bookkeeper_lane(
            emit,
            locale,
            "deliverable_acceptance",
            state.deliverable_acceptance,
            model.selected_bookkeeper_record,
          ),
          bookkeeper_lane(emit, locale, "outcome_binding", state.outcome_binding, model.selected_bookkeeper_record),
          bookkeeper_lane(emit, locale, "three_gap_findings", state.three_gap_findings, model.selected_bookkeeper_record),
          bookkeeper_lane(emit, locale, "three_gap_review", state.three_gap_review, model.selected_bookkeeper_record),
          bookkeeper_lane(
            emit,
            locale,
            "capability_proposal",
            state.capability_proposal,
            model.selected_bookkeeper_record,
          ),
          bookkeeper_lane(emit, locale, "capability_review", state.capability_review, model.selected_bookkeeper_record),
          bookkeeper_lane(
            emit,
            locale,
            "mooncode_work_order",
            state.mooncode_work_order,
            model.selected_bookkeeper_record,
          ),
          bookkeeper_lane(emit, locale, "evaluation", state.evaluation, model.selected_bookkeeper_record),
          bookkeeper_lane(emit, locale, "adoption", state.adoption, model.selected_bookkeeper_record),
        ],
      ),
    ],
  )
}

///|
fn render_sidebar(
  emit : @rabbita.Emit[Msg],
  state : UiState,
  model : Model,
) -> @rabbita.Html {
  let sidebar_note = match model.error {
    Some(error) =>
      "Using fallback snapshot because the last refresh of `moonbook-ui-state.json` failed: \{error}"
    None =>
      match model.live_reload_endpoint {
        Some(endpoint) =>
          "The UI is subscribed to live updates from `\{endpoint}` and fetches `moonbook-ui-state.json` only after rebuild events."
        None =>
          "The UI is using static snapshot mode because no live update endpoint was configured for this build."
      }
  }
  aside(
    style=panel_style() +
      [
        "padding:22px", "position:sticky", "top:24px", "display:flex", "flex-direction:column",
        "gap:24px", "flex:0 1 320px", "max-width:100%", "box-sizing:border-box",
      ],
    [
      div([
        span(
          style=[
            "display:inline-flex", "padding:7px 12px", "border-radius:999px", "background:#dbeafe",
            "color:#1d4ed8", "font-size:12px", "font-weight:700", "letter-spacing:.05em",
            "text-transform:uppercase",
          ],
          interface_message(model.locale, SidebarProduct),
        ),
        h1(
          style=[
            "margin:16px 0 10px 0", "font-size:34px", "line-height:1.05", "letter-spacing:-.04em",
          ],
          state.title,
        ),
        p(style=muted_text_style() + ["margin:0"], state.summary),
      ]),
      div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
        button(
          on_click=emit(UseSystemInterfaceLocale),
          style=[
            "padding:8px 10px", "border-radius:10px", "border:1px solid #cbd5e1",
            "background:#fff", "cursor:pointer",
          ],
          interface_message(model.locale, LanguageSystem),
        ),
        button(
          on_click=emit(SetInterfaceLocale(English)),
          style=[
            "padding:8px 10px", "border-radius:10px", "border:1px solid #cbd5e1",
            "background:#fff", "cursor:pointer",
          ],
          interface_message(model.locale, LanguageEnglish),
        ),
        button(
          on_click=emit(SetInterfaceLocale(SimplifiedChinese)),
          style=[
            "padding:8px 10px", "border-radius:10px", "border:1px solid #cbd5e1",
            "background:#fff", "cursor:pointer",
          ],
          interface_message(model.locale, LanguageSimplifiedChinese),
        ),
      ]),
      div(style=["display:grid", "gap:8px"], [
        nav_link(
          model.locale,
          interface_message(model.locale, NavWorkspaceOverview),
          "#overview",
          current=true,
        ),
        nav_link(
          model.locale,
          interface_message(model.locale, NavBookkeeper),
          "#bookkeeper",
        ),
        nav_link(
          model.locale,
          interface_message(model.locale, NavReviewQueue),
          "#reviews",
        ),
        nav_link(
          model.locale,
          interface_message(model.locale, NavSynthesisMap),
          "#map",
        ),
        nav_link(
          model.locale,
          interface_message(model.locale, NavKeeperState),
          "#keeper",
        ),
      ]),
      div([
        h3(
          style=["margin:0 0 12px 0", "font-size:16px"],
          interface_message(model.locale, NavReadingSurface),
        ),
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
            interface_message(model.locale, SidebarNextStep),
          ),
          h3(
            style=["margin:0", "font-size:18px"],
            if model.loading {
              interface_message(model.locale, SidebarRefreshing)
            } else {
              interface_message(model.locale, SidebarLoaded)
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
              interface_message(model.locale, HeroEyebrow),
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
          "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr))",
          "gap:12px", "align-items:center",
        ],
        [
          input(
            placeholder=interface_message(model.locale, HeroSearchPlaceholder),
            value=search_value,
            read_only=true,
            style=[
              "width:100%", "padding:15px 18px", "border-radius:18px", "border:1px solid rgba(148,163,184,.24)",
              "background:rgba(255,255,255,.88)", "font-size:15px", "color:#0f172a",
              "box-sizing:border-box",
            ],
          ),
          button(
            style=[
              "padding:15px 18px", "border:none", "border-radius:18px", "background:#2563eb",
              "color:#fff", "font-weight:700", "cursor:pointer", "box-shadow:0 16px 35px rgba(37,99,235,.22)",
              "transition:transform .2s ease, box-shadow .2s ease",
            ],
            if model.loading {
              interface_message(model.locale, HeroRefreshing)
            } else {
              interface_message(model.locale, HeroSnapshotLive)
            },
          ),
        ],
      ),
    ],
  )
}

///|
fn render_page(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let state = model.state
  let operator_note = match model.error {
    Some(error) => "Last refresh error: \{error}"
    None => "Workspace snapshot currently available."
  }
  let refresh_note = if model.refresh_count == 0 {
    "Waiting for the first successful live snapshot refresh."
  } else {
    "Snapshot refresh count: \{model.refresh_count}"
  }
  let transport_note = match model.live_reload_endpoint {
    Some(endpoint) => "Live update transport: SSE via \{endpoint}"
    None => "Live update transport: disabled for static builds"
  }
  div(style=app_shell_style(), [
    div(style=page_grid_style(), [
      render_sidebar(emit, state, model),
      main_(
        style=[
          "display:grid", "gap:24px", "flex:1 1 680px", "min-width:0", "max-width:100%",
          "box-sizing:border-box",
        ],
        [
          hero_section(state, model),
          section(
            style=[
              "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,210px),1fr))",
              "gap:14px",
            ],
            state.metrics.map(metric_card),
          ),
          bookkeeper_console(emit, model),
          section(
            style=[
              "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,320px),1fr))",
              "gap:24px", "align-items:start",
            ],
            [
              section(style=["display:grid", "gap:14px"], [
                div([
                  h2(
                    style=["margin:0 0 8px 0", "font-size:28px"],
                    interface_message(model.locale, WorkflowTitle),
                  ),
                  p(
                    style=muted_text_style() + ["margin:0"],
                    interface_message(model.locale, WorkflowSubtitle),
                  ),
                ]),
                div(
                  style=[
                    "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr))",
                    "gap:14px",
                  ],
                  render_workflow_cards(state.workflow),
                ),
                panel_list(
                  interface_message(model.locale, ReviewsTitle),
                  interface_message(model.locale, ReviewsSubtitle),
                  state.review_queue,
                ),
              ]),
              section(style=["display:grid", "gap:14px"], [
                panel_list(
                  interface_message(model.locale, KeeperTitle),
                  interface_message(model.locale, KeeperSubtitle),
                  state.keeper_items,
                ),
                panel_list(
                  interface_message(model.locale, PagesTitle),
                  interface_message(model.locale, PagesSubtitle),
                  state.page_families,
                ),
              ]),
            ],
          ),
          section(
            id="map",
            style=panel_style() +
              [
                "padding:24px", "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,320px),1fr))",
                "gap:22px",
              ],
            [
              div([
                h2(
                  style=["margin:0 0 8px 0", "font-size:28px"],
                  interface_message(model.locale, MapTitle),
                ),
                p(
                  style=muted_text_style() + ["margin:0 0 18px 0"],
                  interface_message(model.locale, MapSubtitle),
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
                    interface_message(model.locale, OperatorEyebrow),
                  ),
                  h3(
                    style=["margin:0", "font-size:22px"],
                    interface_message(model.locale, OperatorTitle),
                  ),
                  ul(
                    style=[
                      "margin:0", "padding-left:18px", "display:grid", "gap:10px",
                      "color:#334155", "line-height:1.6",
                    ],
                    [
                      li(
                        interface_message(
                          model.locale,
                          OperatorReaderNavigation,
                        ),
                      ),
                      li(interface_message(model.locale, OperatorDashboard)),
                      li(
                        interface_message(model.locale, OperatorSynthesisPanel),
                      ),
                      li(
                        if model.loading {
                          "Fetching `moonbook-ui-state.json` after a live update signal."
                        } else {
                          "Latest snapshot loaded from `moonbook-ui-state.json`."
                        },
                      ),
                      li(refresh_note),
                      li(transport_note),
                      li(operator_note),
                    ],
                  ),
                  button(
                    style=[
                      "margin-top:auto", "padding:13px 16px", "border:none", "border-radius:16px",
                      "background:#0f172a", "color:#fff", "font-weight:700", "cursor:pointer",
                    ],
                    interface_message(model.locale, OperatorSnapshotReady),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
  ignore(fetch_ui_config_cmd)
  ignore(subscribe_live_reload_cmd)
  ignore(fetch_bookkeeper_store_cmd)
  ignore(fetch_bookkeeper_authorities_cmd)
  ignore(submit_bookkeeper_mutation_cmd)
  ignore(replay_bookkeeper_cmd)
}

///|
fn fetch_ui_state_cmd(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get("./moonbook-ui-state.json").expect_json(
    emit.map(fn(result) { Loaded(result) }),
  )
}

///|
fn fetch_ui_config_cmd(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get("./moonbook-ui-config.json").expect_json(
    emit.map(fn(result) { LoadedConfig(result) }),
  )
}

///|
fn fetch_bookkeeper_store_cmd(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get("/api/bookkeeper/state").expect_json(
    emit.map(fn(result) { LoadedBookkeeperStore(result) }),
  )
}

///|
fn fetch_bookkeeper_authorities_cmd(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get("/api/bookkeeper/authorities").expect_json(
    emit.map(fn(result) { LoadedBookkeeperAuthorities(result) }),
  )
}

///|
fn bookkeeper_mutation_route(mode : String) -> String {
  match mode {
    "record" => "/api/bookkeeper/records"
    "review" => "/api/bookkeeper/reviews"
    "egress" => "/api/bookkeeper/envelopes/egress"
    _ => "/api/bookkeeper/envelopes/ingress"
  }
}

///|
extern "js" fn post_bookkeeper_json(
  url : String,
  body : String,
) -> @js.Promise =
  #| async (url, body) => {
  #|   try {
  #|     const response = await fetch(url, {
  #|       method: "POST",
  #|       headers: { "Content-Type": "application/json" },
  #|       body,
  #|     });
  #|     return JSON.stringify({
  #|       ok: response.ok,
  #|       status: response.status,
  #|       body: await response.text(),
  #|       error: null,
  #|     });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, status: 0, body: "", error: String(error) });
  #|   }
  #| }

///|
async fn await_bookkeeper_response(
  promise : @js.Promise,
) -> BookkeeperBrowserResponse noraise {
  let text : String = promise.wait().cast() catch {
    error =>
      return { ok: false, status: 0, body: "", error: Some("\{error}") }
  }
  @json.from_json(@json.parse(text)) catch {
    error => { ok: false, status: 0, body: text, error: Some("\{error}") }
  }
}

///|
async fn post_bookkeeper_mutation(
  route : String,
  payload : Json,
) -> Result[BookkeeperMutationResult, String] noraise {
  let response = await_bookkeeper_response(
    post_bookkeeper_json(route, payload.stringify()),
  )
  let decoded : Result[BookkeeperMutationResult, Error] =
    try? @json.from_json(@json.parse(response.body))
  match decoded {
    Ok(result) =>
      if response.ok {
        Ok(result)
      } else {
        Err(if result.issues.is_empty() {
          "HTTP \{response.status} rejected the mutation"
        } else {
          result.issues.join(", ")
        })
      }
    Err(error) => Err(response.error.unwrap_or(
      "HTTP \{response.status}: \{error}; \{response.body}",
    ))
  }
}

///|
fn submit_bookkeeper_mutation_cmd(
  emit : @rabbita.Emit[Msg],
  mode : String,
  payload : Json,
) -> @rabbita.Cmd {
  @rabbita.perform(
    result => emit(BookkeeperMutationFinished(result)),
    fn() noraise {
      post_bookkeeper_mutation(bookkeeper_mutation_route(mode), payload)
    },
  )
}

///|
async fn post_bookkeeper_replay() -> Result[BookkeeperStoreSnapshot, String] noraise {
  let response = await_bookkeeper_response(
    post_bookkeeper_json("/api/bookkeeper/replay", "{}"),
  )
  if !response.ok {
    return Err(response.error.unwrap_or("Replay failed with HTTP \{response.status}"))
  }
  let decoded : Result[BookkeeperStoreSnapshot, Error] =
    try? @json.from_json(@json.parse(response.body))
  match decoded {
    Ok(snapshot) => Ok(snapshot)
    Err(error) => Err("Replay returned invalid state: \{error}")
  }
}

///|
fn replay_bookkeeper_cmd(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(
    result => emit(BookkeeperReplayFinished(result)),
    fn() noraise { post_bookkeeper_replay() },
  )
}

///|
fn bookkeeper_mode_template(mode : String) -> String {
  match mode {
    "record" =>
      #|{
      #|  "contract_version": "moonbook.bookkeeper.store.v1",
      #|  "record": {"record_id":"replace-me","record_version":"v1","record_digest":"sha256:replace-with-canonical-payload-digest"},
      #|  "stage": "MoonCodeResult",
      #|  "subject": null,
      #|  "links": [],
      #|  "title": "MoonCode result",
      #|  "summary": "Replace with result summary",
      #|  "owner_route": "mooncode",
      #|  "status": "returned",
      #|  "evidence_refs": [],
      #|  "issue_refs": [],
      #|  "requires_human_review": true,
      #|  "next_action": "evaluate result",
      #|  "source_product": "mooncode",
      #|  "recorded_at": 0,
      #|  "payload": {},
      #|  "side_effects_applied": false
      #|}
    "review" =>
      "Select an exact lane record and an active CLI-installed authority to prepare this review."
    "egress" =>
      #|{
      #|  "contract_version": "moonbook.bookkeeper.transport.v1",
      #|  "envelope": {"record_id":"replace-me","record_version":"v1","record_digest":"sha256:replace-me"},
      #|  "direction": "Egress",
      #|  "source_product": "moonbook",
      #|  "destination_product": "moonflow",
      #|  "message_kind": "reviewed_work_order",
      #|  "subject": {"record_id":"replace-me","record_version":"v1","record_digest":"sha256:replace-me"},
      #|  "links": [], "evidence_refs": [], "authority_ref": "replace-me",
      #|  "recorded_at": 0, "payload": {}, "external_activation_allowed": false,
      #|  "side_effects_applied": false
      #|}
    _ =>
      #|{
      #|  "contract_version": "moonbook.bookkeeper.transport.v1",
      #|  "envelope": {"record_id":"replace-me","record_version":"v1","record_digest":"sha256:replace-me"},
      #|  "direction": "Ingress",
      #|  "source_product": "moonflow",
      #|  "destination_product": "moonbook",
      #|  "message_kind": "deliverable_result",
      #|  "subject": {"record_id":"replace-me","record_version":"v1","record_digest":"sha256:replace-me"},
      #|  "links": [], "evidence_refs": [], "authority_ref": "",
      #|  "recorded_at": 0, "payload": {}, "external_activation_allowed": false,
      #|  "side_effects_applied": false
      #|}
  }
}

///|
#cfg(target="js")
extern "js" fn install_live_reload(endpoint : String) = "(endpoint)=>{if(!window.EventSource)return;const existing=window.__moonbookLiveReload;if(existing&&existing.endpoint===endpoint)return;if(existing&&existing.source){try{existing.source.close()}catch(_){}}const source=new EventSource(endpoint);source.addEventListener('reload',()=>window.location.reload());source.onerror=()=>{};window.__moonbookLiveReload={endpoint,source}}"

///|
fn subscribe_live_reload_cmd(
  emit : @rabbita.Emit[Msg],
  endpoint : String,
) -> @rabbita.Cmd {
  ignore(emit)
  @cmd.custom_cmd(_ => install_live_reload(endpoint), kind=@cmd.after_render)
}

///|
fn update(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    UseSystemInterfaceLocale => (use_system_interface_locale_cmd(), model)
    SetInterfaceLocale(locale) =>
      (
        persist_interface_locale_cmd(locale),
        {
          ..model,
          locale,
          state: if model.loading {
            demo_state()
          } else {
            model.state
          },
        },
      )
    LoadedConfig(Ok(config)) =>
      match config.live_reload_endpoint {
        Some(endpoint) =>
          (
            subscribe_live_reload_cmd(emit, endpoint),
            { ..model, live_reload_endpoint: Some(endpoint) },
          )
        None => (@rabbita.none, { ..model, live_reload_endpoint: None })
      }
    LoadedConfig(Err(_)) =>
      (@rabbita.none, { ..model, live_reload_endpoint: None })
    Loaded(Ok(state)) =>
      (
        @rabbita.none,
        {
          ..model,
          loading: false,
          state,
          error: None,
          refresh_count: model.refresh_count + 1,
        },
      )
    Loaded(Err(error)) =>
      (@rabbita.none, { ..model, loading: false, error: Some("\{error}") })
    LoadedBookkeeperStore(Ok(snapshot)) =>
      (@rabbita.none, { ..model, bookkeeper_store: Some(snapshot) })
    LoadedBookkeeperStore(Err(error)) =>
      (
        @rabbita.none,
        { ..model, bookkeeper_notice: Some("Store state unavailable: \{error}") },
      )
    LoadedBookkeeperAuthorities(Ok(registry)) => {
      let selected = match model.selected_bookkeeper_authority {
        Some(authority_ref) => Some(authority_ref)
        None => {
          let mut first : String? = None
          for grant in registry.grants {
            if grant.active && first is None {
              first = Some(grant.authority_ref)
            }
          }
          first
        }
      }
      (@rabbita.none, {
        ..model,
        bookkeeper_authorities: Some(registry),
        selected_bookkeeper_authority: selected,
      })
    }
    LoadedBookkeeperAuthorities(Err(error)) =>
      (
        @rabbita.none,
        { ..model, bookkeeper_notice: Some("Authority status unavailable: \{error}") },
      )
    SelectBookkeeperItem(item) => {
      let mut selected : BookkeeperRecordReference? = None
      match model.bookkeeper_store {
        Some(snapshot) =>
          for record in snapshot.records {
            if record.record.record_id == item.record_id &&
              record.record.record_version == item.record_version {
              selected = Some(record.record)
            }
          }
        None => ()
      }
      let next = { ..model, selected_bookkeeper_record: selected }
      let draft = if model.bookkeeper_mode == "review" {
        review_draft_for_selection(next).unwrap_or(model.bookkeeper_draft)
      } else {
        model.bookkeeper_draft
      }
      (@rabbita.none, {
        ..next,
        bookkeeper_draft: draft,
        bookkeeper_notice: if selected is Some(_) {
          Some("Bound operator session to \{item.record_id} · \{item.record_version}.")
        } else {
          Some("The projected item has no matching durable record; replay the journal first.")
        },
      })
    }
    SelectBookkeeperAuthority(authority_ref) => {
      let next = { ..model, selected_bookkeeper_authority: Some(authority_ref) }
      let draft = if model.bookkeeper_mode == "review" {
        review_draft_for_selection(next).unwrap_or(model.bookkeeper_draft)
      } else {
        model.bookkeeper_draft
      }
      (@rabbita.none, {
        ..next,
        bookkeeper_draft: draft,
        bookkeeper_notice: Some("Reviewer session bound to \{authority_ref}."),
      })
    }
    SetBookkeeperMode(mode) => {
      let next = { ..model, bookkeeper_mode: mode }
      let draft = if mode == "review" {
        review_draft_for_selection(next).unwrap_or(bookkeeper_mode_template(mode))
      } else {
        bookkeeper_mode_template(mode)
      }
      (@rabbita.none, { ..next, bookkeeper_draft: draft, bookkeeper_notice: None })
    }
    SetBookkeeperDraft(draft) =>
      (@rabbita.none, { ..model, bookkeeper_draft: draft })
    SubmitBookkeeperMutation => {
      let parsed : Result[Json, Error] = try? @json.parse(model.bookkeeper_draft)
      match parsed {
        Ok(payload) =>
          (
            submit_bookkeeper_mutation_cmd(
              emit, model.bookkeeper_mode, payload,
            ),
            { ..model, bookkeeper_busy: true, bookkeeper_notice: Some("Submitting governed mutation…") },
          )
        Err(error) =>
          (
            @rabbita.none,
            { ..model, bookkeeper_notice: Some("Draft is not valid JSON: \{error}") },
          )
      }
    }
    BookkeeperMutationFinished(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_ui_state_cmd(emit), fetch_bookkeeper_store_cmd(emit),
          fetch_bookkeeper_authorities_cmd(emit),
        ]),
        {
          ..model,
          bookkeeper_busy: false,
          bookkeeper_notice: Some(
            if result.accepted {
              "Mutation accepted. Projection and durable state are refreshing."
            } else {
              "Mutation rejected: \{result.issues.join(", ")}"
            },
          ),
        },
      )
    BookkeeperMutationFinished(Err(error)) =>
      (
        @rabbita.none,
        { ..model, bookkeeper_busy: false, bookkeeper_notice: Some("Mutation failed or was rejected: \{error}") },
      )
    ReplayBookkeeper =>
      (
        replay_bookkeeper_cmd(emit),
        { ..model, bookkeeper_busy: true, bookkeeper_notice: Some("Replaying durable Bookkeeper journal…") },
      )
    BookkeeperReplayFinished(Ok(snapshot)) =>
      (
        @rabbita.batch([fetch_ui_state_cmd(emit), fetch_bookkeeper_authorities_cmd(emit)]),
        {
          ..model,
          bookkeeper_busy: false,
          bookkeeper_store: Some(snapshot),
          bookkeeper_notice: Some("Replay complete; the served projection is refreshing."),
        },
      )
    BookkeeperReplayFinished(Err(error)) =>
      (
        @rabbita.none,
        { ..model, bookkeeper_busy: false, bookkeeper_notice: Some("Replay failed: \{error}") },
      )
  }
}

///|
fn main {
  let locale = initial_interface_locale()
  let (emit, cell) = @rabbita.cell_with_emit(
    model={
      loading: true,
      state: demo_state(),
      error: None,
      refresh_count: 0,
      live_reload_endpoint: None,
      locale,
      bookkeeper_store: None,
      bookkeeper_authorities: None,
      selected_bookkeeper_record: None,
      selected_bookkeeper_authority: None,
      bookkeeper_mode: "ingress",
      bookkeeper_draft: bookkeeper_mode_template("ingress"),
      bookkeeper_busy: false,
      bookkeeper_notice: None,
    },
    update~,
    view=(emit, model) => render_page(emit, model),
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @rabbita.batch([
      fetch_ui_state_cmd(emit), fetch_ui_config_cmd(emit),
      fetch_bookkeeper_store_cmd(emit), fetch_bookkeeper_authorities_cmd(emit),
    ]),
  )
  app.mount("app")
}
