///|
pub struct UiStatusChip {
  label : String
  tone : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiMetric {
  label : String
  value : String
  note : String
  tone : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiWorkflowItem {
  title : String
  detail : String
  status : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiPanelItem {
  title : String
  detail : String
  meta : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiChapterLink {
  title : String
  href : String
  source_path : String
  number : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiState {
  title : String
  summary : String
  status_chips : Array[UiStatusChip]
  metrics : Array[UiMetric]
  workflow : Array[UiWorkflowItem]
  readiness : Array[UiPanelItem]
  review_queue : Array[UiPanelItem]
  keeper_items : Array[UiPanelItem]
  page_families : Array[UiPanelItem]
  chapters : Array[UiChapterLink]
  synthesis_preview : String
} derive(Show, ToJson, FromJson)

///|
pub async fn generate_ui_state(root : String) -> UiState {
  let workspace = workspace_paths(root)
  let state = summarize_state(root)
  let health = report_health(root)
  let keeper = keeper_snapshot(root)
  let pending = list_pending_reviews(root)
  let claims_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/claims.md"))
    .to_string()
  let claims_text = if @fsx.exists(claims_path) {
    @fsx.read_file(claims_path)
  } else {
    ""
  }
  let status_chips = ui_status_chips(state, health)
  let metrics = ui_metrics(state, health)
  let workflow = ui_workflow_items(state, health)
  let readiness = ui_readiness_items(state, health)
  let review_queue = ui_review_queue(root, pending)
  let keeper_items = [
    {
      title: "Active Memory",
      detail: "Reusable domain memory kept in Keeper for future worker hydration.",
      meta: "\{keeper.active_memory.length()} entries",
    },
    {
      title: "User Memory",
      detail: "Stable user collaboration preferences kept separate from task-local recall.",
      meta: "\{keeper.user_memory.length()} entries",
    },
    {
      title: "Working Memory",
      detail: if keeper.working_memory.length() >= 8 {
        "Working memory is crowded and should be pruned or promoted."
      } else {
        "Short-lived task memory remains within the bounded window."
      },
      meta: "\{keeper.working_memory.length()} entries",
    },
  ]
  let page_families = [
    {
      title: "Claims Register",
      detail: "Claim ids, confidence, support, supersession, and related-page metadata.",
      meta: "\{count_heading_entries(claims_text)} claims",
    },
    {
      title: "Synthesis Map",
      detail: "Coverage counts, hub pages, and open loops for planning pressure.",
      meta: "wiki/synthesis/map.md",
    },
    {
      title: "Evidence",
      detail: "Support records for persisted results and review outcomes.",
      meta: "\{count_evidence_entries(root)} records",
    },
  ]
  {
    title: catalog_name(root),
    summary: catalog_purpose(root),
    status_chips,
    metrics,
    workflow,
    readiness,
    review_queue,
    keeper_items,
    page_families,
    chapters: ui_chapter_links(root),
    synthesis_preview: ui_synthesis_preview(root),
  }
}

///|
pub async fn write_ui_state(root : String, output_path : String) -> String {
  let state = generate_ui_state(root)
  @fsx.write_to_file(
    output_path,
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  output_path
}

///|
pub async fn write_marketing_projection(
  root : String,
  site_root : String,
) -> String {
  let state = generate_ui_state(root)
  let updated_note = marketing_update_note(root)
  let generated_dir = @path.Path(site_root)
    .join(@path.Path("generated"))
    .to_string()
  @fsx.make_directory(generated_dir, recursive=true, exists_ok=true)
  let state_path = @path.Path(generated_dir)
    .join(@path.Path("marketing-state.json"))
    .to_string()
  let index_path = @path.Path(generated_dir)
    .join(@path.Path("index.html"))
    .to_string()
  let styles_path = @path.Path(generated_dir)
    .join(@path.Path("styles.css"))
    .to_string()
  let script_path = @path.Path(generated_dir)
    .join(@path.Path("app.js"))
    .to_string()
  @fsx.write_to_file(
    state_path,
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    index_path,
    marketing_projection_html(state, updated_note),
    create=0o644,
  )
  @fsx.write_to_file(styles_path, marketing_projection_styles(), create=0o644)
  @fsx.write_to_file(script_path, marketing_projection_script(), create=0o644)
  index_path
}

///|
fn ui_status_chips(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiStatusChip] {
  let chips : Array[UiStatusChip] = []
  chips.push({
    label: health.level,
    tone: if health.level == "healthy" {
      "healthy"
    } else {
      "alert"
    },
  })
  if state.pending_review_count > 0 {
    chips.push({ label: "pending review", tone: "review" })
  }
  chips.push({
    label: if state.substantive_coverage_ready {
      "ready for synthesis"
    } else if state.source_page_count == 0 {
      "no sources yet"
    } else {
      "ingest in progress"
    },
    tone: if state.substantive_coverage_ready {
      "healthy"
    } else {
      "alert"
    },
  })
  if health.maintenance_entry_count > 0 || health.keeper_working_count >= 8 {
    chips.push({ label: "planning pressure", tone: "alert" })
  }
  chips
}

///|
fn ui_metrics(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiMetric] {
  [
    {
      label: "Coverage Readiness",
      value: if state.substantive_coverage_ready {
        "ready"
      } else {
        "not ready"
      },
      note: if state.substantive_coverage_ready {
        "Source pages, maintained ontology, and evidence records are in place for synthesis."
      } else {
        health.issues.join("; ")
      },
      tone: if state.substantive_coverage_ready {
        "healthy"
      } else {
        "alert"
      },
    },
    {
      label: "Source Pages",
      value: state.source_page_count.to_string(),
      note: "Durable source summaries under `wiki/sources/` anchor later query and synthesis work.",
      tone: if state.evidence_count > 0 {
        "healthy"
      } else {
        "alert"
      },
    },
    {
      label: "Pending Review",
      value: state.pending_review_count.to_string(),
      note: "Queued claim, query, and result promotions awaiting operator review.",
      tone: if state.pending_review_count > 0 {
        "review"
      } else {
        "healthy"
      },
    },
    {
      label: "Ontology Pages",
      value: (state.entity_page_count + state.concept_page_count).to_string(),
      note: "\{state.entity_page_count} entities and \{state.concept_page_count} concepts currently structure the maintained wiki.",
      tone: if state.entity_page_count > 0 || state.concept_page_count > 0 {
        "healthy"
      } else {
        "alert"
      },
    },
    {
      label: "Query Notes",
      value: state.query_note_count.to_string(),
      note: "Saved query pages under `wiki/queries/` capture reusable analysis instead of leaving it in chat history.",
      tone: "info",
    },
  ]
}

///|
fn ui_readiness_items(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiPanelItem] {
  let items : Array[UiPanelItem] = []
  if state.source_page_count == 0 {
    items.push({
      title: "No sources yet",
      detail: "The workspace is still scaffold-only. Put material under `raw/`, then run ingest so MoonBook can generate durable source pages.",
      meta: "bootstrap required",
    })
  } else if !state.substantive_coverage_ready {
    items.push({
      title: "Ingest in progress",
      detail: "Source pages exist, but the wiki still needs stronger ontology coverage or evidence before synthesis should be treated as reliable.",
      meta: "populate entities, concepts, and evidence",
    })
  } else {
    items.push({
      title: "Ready for synthesis",
      detail: "The wiki has enough durable source and ontology coverage to support query and synthesis work without pretending the book is empty.",
      meta: "query path unblocked",
    })
  }
  if state.pending_review_count > 0 {
    items.push({
      title: "Pending review",
      detail: "High-value updates are staged but not fully promoted yet. Review affects what the site should present as settled knowledge.",
      meta: "\{state.pending_review_count} queued",
    })
  }
  if !health.issues.is_empty() {
    items.push({
      title: "Coverage gaps",
      detail: health.issues.join("; "),
      meta: "health:\{health.level}",
    })
  }
  items
}

///|
fn ui_workflow_items(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiWorkflowItem] {
  [
    {
      title: "Ingest",
      detail: if state.source_page_count == 0 {
        "No durable source pages exist yet. Bootstrap starts in `raw/`, then writes `wiki/sources/` before broader synthesis work."
      } else if state.substantive_coverage_ready {
        "Source pages, ontology pages, and evidence are in place. Ingest can now revise rather than just bootstrap."
      } else {
        "Source pages exist, but ontology or evidence coverage still needs another ingest/review pass."
      },
      status: if state.source_page_count == 0 {
        "needed"
      } else if state.substantive_coverage_ready {
        "stable"
      } else {
        "active"
      },
    },
    {
      title: "Query",
      detail: if state.substantive_coverage_ready {
        "Saved answers can cite durable pages, write query notes, and feed back into synthesis maintenance."
      } else {
        "Query should stay secondary until durable source and ontology coverage is ready."
      },
      status: if state.substantive_coverage_ready {
        "active"
      } else {
        "blocked"
      },
    },
    {
      title: "Review",
      detail: "Approvals can promote into overview, claims, cited pages, and staged durable targets.",
      status: if state.pending_review_count > 0 {
        "expanded"
      } else {
        "stable"
      },
    },
    {
      title: "Keeper",
      detail: "Memory, evidence, and planning signals remain visible through Keeper insights and the UI snapshot.",
      status: if health.keeper_working_count >= 8 {
        "crowded"
      } else {
        "stable"
      },
    },
  ]
}

///|
async fn ui_review_queue(
  root : String,
  pending : Array[ReviewItem],
) -> Array[UiPanelItem] {
  let workspace = workspace_paths(root)
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("reviews/pending.md"))
    .to_string()
  let content = if @fsx.exists(page_path) {
    @fsx.read_file(page_path)
  } else {
    ""
  }
  let blocks = parse_review_blocks(content)
  let items : Array[UiPanelItem] = []
  for item in pending {
    let mut matched : ReviewBlock? = None
    for entry in blocks {
      if entry.review_id == item.review_id {
        matched = Some(entry)
        break
      }
    }
    match matched {
      Some(block) =>
        items.push({
          title: "\{item.kind} | \{item.title}",
          detail: find_review_field(block.block, "- Reason: ").unwrap_or(
            "Pending review item.",
          ),
          meta: find_review_field(block.block, "- Merge policy: `").unwrap_or(
            item.status,
          ),
        })
      None =>
        items.push({
          title: "\{item.kind} | \{item.title}",
          detail: "Pending review item.",
          meta: item.status,
        })
    }
    if items.length() >= 4 {
      break
    }
  }
  if items.is_empty() {
    [
      {
        title: "Review Queue",
        detail: "No pending review items.",
        meta: "healthy",
      },
    ]
  } else {
    items
  }
}

///|
async fn ui_chapter_links(root : String) -> Array[UiChapterLink] {
  let workspace = workspace_paths(root)
  let summary_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  if !@fsx.exists(summary_path) {
    return []
  }
  let items : Array[UiChapterLink] = []
  let mut number = 1
  for raw in @fsx.read_file(summary_path).split("\n") {
    let line = raw.trim().to_string()
    if !line.has_prefix("- [") {
      continue
    }
    match summary_link_parts(line) {
      Some((title, href)) => {
        items.push({
          title,
          href: markdown_href_to_html(href),
          source_path: href,
          number: number.to_string(),
        })
        number += 1
      }
      None => ()
    }
    if items.length() >= 8 {
      break
    }
  }
  items
}

///|
fn summary_link_parts(line : String) -> (String, String)? {
  match line.find("](") {
    Some(split) =>
      if line.has_suffix(")") {
        Some(
          (
            line[3:split].to_string(),
            line[split + 2:line.length() - 1]
            .strip_prefix("./")
            .unwrap_or(line[split + 2:line.length() - 1])
            .to_string(),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn markdown_href_to_html(href : String) -> String {
  if href.has_suffix(".md") {
    href[:href.length() - 3].to_string() + ".html"
  } else {
    href
  }
}

///|
async fn ui_synthesis_preview(root : String) -> String {
  let workspace = workspace_paths(root)
  let map_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/map.md"))
    .to_string()
  if !@fsx.exists(map_path) {
    return "No synthesis map available yet."
  }
  let lines : Array[String] = []
  for raw in @fsx.read_file(map_path).split("\n") {
    let line = raw.to_string()
    if line.trim().is_empty() {
      continue
    }
    lines.push(line)
    if lines.length() >= 14 {
      break
    }
  }
  lines.join("\n")
}

///|
fn marketing_projection_html(state : UiState, updated_note : String) -> String {
  let book_prefix = "../../"
  let status_chips = state.status_chips
    .map(fn(chip) {
      "<span class=\"chip chip-\{chip.tone}\">\{escape_html(chip.label)}</span>"
    })
    .join("")
  let metrics = state.metrics
    .map(fn(metric) {
      "<article class=\"metric-card metric-\{metric.tone}\">" +
      "<span class=\"metric-label\">\{escape_html(metric.label)}</span>" +
      "<strong>\{escape_html(metric.value)}</strong>" +
      "<p>\{escape_html(metric.note)}</p>" +
      "</article>"
    })
    .join("")
  let workflow = state.workflow
    .map(fn(item) {
      "<article class=\"workflow-card\">" +
      "<span class=\"workflow-status status-\{escape_html(item.status)}\">\{escape_html(item.status)}</span>" +
      "<h3>\{escape_html(item.title)}</h3>" +
      "<p>\{escape_html(item.detail)}</p>" +
      "</article>"
    })
    .join("")
  let readiness = state.readiness
    .map(fn(item) { marketing_panel_item(item) })
    .join("")
  let reviews = state.review_queue
    .map(fn(item) { marketing_panel_item(item) })
    .join("")
  let keeper = state.keeper_items
    .map(fn(item) { marketing_panel_item(item) })
    .join("")
  let families = state.page_families
    .map(fn(item) { marketing_panel_item(item) })
    .join("")
  let chapters = state.chapters
    .map(fn(item) {
      "<a class=\"chapter-link\" href=\"\{book_prefix}\{escape_html(item.href)}\">" +
      "<span class=\"chapter-number\">\{escape_html(item.number)}</span>" +
      "<span class=\"chapter-copy\"><strong>\{escape_html(item.title)}</strong><small>\{escape_html(item.source_path)}</small></span>" +
      "</a>"
    })
    .join("")
  let project_title = escape_html(state.title)
  let project_summary = escape_html(state.summary)
  let synthesis_preview = escape_html(state.synthesis_preview)
  let update_note_html = escape_html(updated_note)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{project_title} Marketing Projection</title>\n" +
  "  <meta name=\"description\" content=\"Live marketing projection generated from the MoonBook workspace state.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body>\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"\{book_prefix}index.html\"><span class=\"brand-mark\">MB</span><span>\{project_title}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"\{book_prefix}index.html\">Book</a>\n" +
  "      <a href=\"#state\">State</a>\n" +
  "      <a href=\"#depth\">Depth</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Live marketing projection</p>\n" +
  "        <h1>\{project_title} is a maintained workspace, not a static note dump.</h1>\n" +
  "        <p class=\"lede\">\{project_summary}</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"\{book_prefix}Home.html\">Open detailed wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"\{book_prefix}index.html\">Open book</a>\n" +
  "        </div>\n" +
  "        <div class=\"chip-row\">\{status_chips}</div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">projection note</span>\n" +
  "          <p>This page is generated from MoonBook state. The wiki stays detailed and evidence-oriented. This projection compresses that state into an audience-facing story.</p>\n" +
  "        </div>\n" +
  "        <div class=\"panel-block panel-block-dark\">\n" +
  "          <span class=\"panel-label\">last update</span>\n" +
  "          <pre><code>\{update_note_html}</code></pre>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"state\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Current state</p>\n" +
  "        <h2>Market the system from reality, not from placeholders.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"metric-grid\">\{metrics}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading narrow\">\n" +
  "        <p class=\"eyebrow\">Operational loop</p>\n" +
  "        <h2>The workspace already knows how work compounds.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{workflow}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Readiness</p>\n" +
  "        <h2>Show whether the book can actually support synthesis.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"readiness-grid\">\{readiness}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Pressure points</p>\n" +
  "        <h2>Review, keeper memory, and coverage stay visible.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"triple-grid\">\n" +
  "        <div class=\"panel-shell\"><h3>Review queue</h3>\{reviews}</div>\n" +
  "        <div class=\"panel-shell\"><h3>Keeper memory</h3>\{keeper}</div>\n" +
  "        <div class=\"panel-shell\"><h3>Knowledge surfaces</h3>\{families}</div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"depth\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Depth links</p>\n" +
  "        <h2>Use the projection as the front door, then drop into maintained pages.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"depth-grid\">\n" +
  "        <div class=\"depth-card\"><h3>Chapters</h3><div class=\"chapter-stack\">\{chapters}</div></div>\n" +
  "        <div class=\"depth-card\"><h3>Synthesis preview</h3><pre class=\"preview-block\"><code>\{synthesis_preview}</code></pre></div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn marketing_panel_item(item : UiPanelItem) -> String {
  "<article class=\"panel-item\">" +
  "<strong>\{escape_html(item.title)}</strong>" +
  "<p>\{escape_html(item.detail)}</p>" +
  "<small>\{escape_html(item.meta)}</small>" +
  "</article>"
}

///|
async fn marketing_update_note(root : String) -> String {
  let workspace = workspace_paths(root)
  let log_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("log.md"))
    .to_string()
  if !@fsx.exists(log_path) {
    return "No log available."
  }
  let lines = @fsx.read_file(log_path).split("\n").to_array()
  for index = lines.length() - 1; index >= 0; index = index - 1 {
    let line = lines[index].trim().to_string()
    if line.has_prefix("## [") {
      return line
    }
  }
  "Workspace log present."
}

///|
fn marketing_projection_styles() -> String {
  ":root {\n" +
  "  --paper: #fbf5ea;\n" +
  "  --ink: #10211d;\n" +
  "  --muted: #5c6a63;\n" +
  "  --forest: #173c34;\n" +
  "  --forest-deep: #0d2620;\n" +
  "  --amber: #d97706;\n" +
  "  --coral: #ea6a4b;\n" +
  "  --line: rgba(16, 33, 29, 0.12);\n" +
  "  --shadow: 0 24px 80px rgba(18, 34, 30, 0.14);\n" +
  "}\n" +
  "* { box-sizing: border-box; }\n" +
  "html { scroll-behavior: smooth; }\n" +
  "body {\n" +
  "  margin: 0;\n" +
  "  min-height: 100vh;\n" +
  "  font-family: \"Space Grotesk\", \"Avenir Next\", \"Trebuchet MS\", sans-serif;\n" +
  "  color: var(--ink);\n" +
  "  background: radial-gradient(circle at top left, rgba(234, 106, 75, 0.17), transparent 28%), linear-gradient(180deg, #fffaf3 0%, var(--paper) 54%, #f3e7d6 100%);\n" +
  "}\n" +
  "a { color: inherit; text-decoration: none; }\n" +
  ".backdrop {\n" +
  "  position: fixed;\n" +
  "  inset: 0;\n" +
  "  pointer-events: none;\n" +
  "  background-image: linear-gradient(rgba(16, 33, 29, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(16, 33, 29, 0.03) 1px, transparent 1px);\n" +
  "  background-size: 34px 34px;\n" +
  "  mask-image: linear-gradient(180deg, rgba(0, 0, 0, 0.88), transparent 94%);\n" +
  "}\n" +
  ".topbar {\n" +
  "  position: sticky;\n" +
  "  top: 0;\n" +
  "  z-index: 30;\n" +
  "  display: flex;\n" +
  "  justify-content: space-between;\n" +
  "  align-items: center;\n" +
  "  gap: 1rem;\n" +
  "  padding: 1rem 1.4rem;\n" +
  "  backdrop-filter: blur(18px);\n" +
  "  background: rgba(251, 245, 234, 0.78);\n" +
  "  border-bottom: 1px solid var(--line);\n" +
  "}\n" +
  ".brand { display: inline-flex; align-items: center; gap: 0.8rem; font-weight: 700; letter-spacing: -0.04em; }\n" +
  ".brand-mark { display: grid; place-items: center; width: 2.45rem; height: 2.45rem; border-radius: 0.88rem; color: #fff8ef; background: linear-gradient(135deg, var(--forest), #285c4f); box-shadow: 0 16px 38px rgba(23, 60, 52, 0.28); }\n" +
  ".nav { display: inline-flex; gap: 1rem; flex-wrap: wrap; color: var(--muted); }\n" +
  ".nav a:hover { color: var(--ink); }\n" +
  ".page-shell { width: min(1200px, calc(100% - 2.4rem)); margin: 0 auto; padding: 2.5rem 0 5rem; }\n" +
  ".hero { display: grid; grid-template-columns: 1.08fr 0.92fr; gap: 2rem; align-items: stretch; }\n" +
  ".eyebrow { margin: 0 0 1rem; color: var(--amber); font-size: 0.8rem; font-weight: 700; letter-spacing: 0.18em; text-transform: uppercase; }\n" +
  "h1, h2, h3 { margin: 0; letter-spacing: -0.05em; }\n" +
  "h1 { font-family: \"Instrument Serif\", Georgia, serif; font-size: clamp(3.4rem, 7vw, 6.3rem); line-height: 0.94; max-width: 9ch; }\n" +
  "h2 { font-family: \"Instrument Serif\", Georgia, serif; font-size: clamp(2.2rem, 5vw, 4rem); line-height: 0.98; }\n" +
  "h3 { font-size: 1.12rem; }\n" +
  ".lede { margin: 1.3rem 0 0; max-width: 39rem; font-size: 1.07rem; line-height: 1.72; color: var(--muted); }\n" +
  ".hero-actions { display: flex; flex-wrap: wrap; gap: 0.9rem; margin-top: 1.6rem; }\n" +
  ".button { display: inline-flex; align-items: center; justify-content: center; min-height: 3.15rem; padding: 0.85rem 1.2rem; border-radius: 999px; border: 1px solid transparent; font-weight: 700; }\n" +
  ".button-primary { color: #fff8ef; background: linear-gradient(135deg, var(--forest), #245b4d); box-shadow: 0 18px 36px rgba(23, 60, 52, 0.24); }\n" +
  ".button-secondary { border-color: var(--line); background: rgba(255, 255, 255, 0.56); }\n" +
  ".chip-row { display: flex; flex-wrap: wrap; gap: 0.7rem; margin-top: 1.25rem; }\n" +
  ".chip { padding: 0.5rem 0.72rem; border-radius: 999px; font-size: 0.9rem; border: 1px solid var(--line); background: rgba(255, 255, 255, 0.58); }\n" +
  ".chip-healthy { color: #1b6b4f; }\n" +
  ".chip-alert { color: #9a3e1f; }\n" +
  ".chip-review { color: #8b5b00; }\n" +
  ".hero-stage, .metric-card, .workflow-card, .panel-shell, .depth-card { border: 1px solid var(--line); box-shadow: var(--shadow); }\n" +
  ".hero-stage { display: grid; gap: 1rem; padding: 1.15rem; border-radius: 1.95rem; background: linear-gradient(180deg, rgba(255, 252, 246, 0.86), rgba(242, 228, 202, 0.74)); }\n" +
  ".panel-block, .metric-card, .workflow-card, .panel-shell, .depth-card, .panel-item { border-radius: 1.35rem; background: rgba(255,255,255,0.58); }\n" +
  ".panel-block { padding: 1rem; }\n" +
  ".panel-block-dark { background: var(--forest-deep); color: #edf5f0; }\n" +
  ".panel-label { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: var(--muted); }\n" +
  ".panel-block-dark .panel-label { color: rgba(237, 245, 240, 0.74); }\n" +
  "pre { overflow: auto; margin: 0.9rem 0 0; padding: 1rem; border-radius: 1rem; background: var(--forest-deep); color: #eff7f2; }\n" +
  ".section { padding: 4rem 0 0; }\n" +
  ".section-heading { display: flex; flex-direction: column; gap: 0.7rem; max-width: 48rem; }\n" +
  ".section-heading.narrow { max-width: 39rem; }\n" +
  ".metric-grid, .workflow-grid, .triple-grid, .depth-grid { display: grid; gap: 1rem; margin-top: 1.7rem; }\n" +
  ".metric-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }\n" +
  ".workflow-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }\n" +
  ".readiness-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".triple-grid, .depth-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }\n" +
  ".metric-card, .workflow-card, .panel-shell, .depth-card { padding: 1.3rem; }\n" +
  ".metric-card strong { display: block; margin-top: 0.4rem; font-size: 2rem; line-height: 1; }\n" +
  ".metric-label, .workflow-status { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }\n" +
  ".workflow-status { margin-bottom: 0.7rem; }\n" +
  ".status-active, .status-stable { color: #1b6b4f; }\n" +
  ".status-expanded, .status-crowded, .status-needed, .status-blocked { color: #9a3e1f; }\n" +
  ".metric-card p, .workflow-card p, .panel-item p, .panel-item small, .panel-block p { color: var(--muted); line-height: 1.66; }\n" +
  ".panel-item { padding: 1rem; margin-top: 0.9rem; border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".chapter-stack { display: grid; gap: 0.8rem; margin-top: 1rem; }\n" +
  ".chapter-link { display: grid; grid-template-columns: auto 1fr; gap: 0.8rem; align-items: start; padding: 0.9rem 1rem; border-radius: 1rem; background: rgba(255,255,255,0.66); border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".chapter-number { display: inline-grid; place-items: center; min-width: 2rem; height: 2rem; border-radius: 999px; background: rgba(23, 60, 52, 0.08); font-weight: 700; }\n" +
  ".chapter-copy { display: grid; gap: 0.2rem; }\n" +
  ".chapter-copy small { color: var(--muted); }\n" +
  ".preview-block { min-height: 18rem; background: rgba(16, 33, 29, 0.95); }\n" +
  ".reveal { opacity: 0; transform: translateY(18px); transition: opacity 560ms ease, transform 560ms ease; }\n" +
  ".reveal.is-visible { opacity: 1; transform: translateY(0); }\n" +
  "@media (max-width: 980px) {\n" +
  "  .hero, .metric-grid, .workflow-grid, .readiness-grid, .triple-grid, .depth-grid { grid-template-columns: 1fr; }\n" +
  "  .page-shell { width: min(100% - 1.4rem, 1200px); }\n" +
  "}\n" +
  "@media (max-width: 640px) {\n" +
  "  .topbar { align-items: flex-start; flex-direction: column; }\n" +
  "  h1 { max-width: none; }\n" +
  "}\n" +
  "@media (prefers-reduced-motion: reduce) {\n" +
  "  html { scroll-behavior: auto; }\n" +
  "  .reveal { opacity: 1; transform: none; transition: none; }\n" +
  "  .tilt { transform: none !important; }\n" +
  "}\n"
}

///|
fn marketing_projection_script() -> String {
  "const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;\n" +
  "const revealNodes = document.querySelectorAll('.reveal');\n" +
  "if (!reduceMotion && 'IntersectionObserver' in window) {\n" +
  "  const observer = new IntersectionObserver((entries) => {\n" +
  "    for (const entry of entries) {\n" +
  "      if (entry.isIntersecting) {\n" +
  "        entry.target.classList.add('is-visible');\n" +
  "        observer.unobserve(entry.target);\n" +
  "      }\n" +
  "    }\n" +
  "  }, { threshold: 0.16 });\n" +
  "  revealNodes.forEach((node) => observer.observe(node));\n" +
  "} else {\n" +
  "  revealNodes.forEach((node) => node.classList.add('is-visible'));\n" +
  "}\n" +
  "if (!reduceMotion) {\n" +
  "  document.querySelectorAll('.tilt').forEach((node) => {\n" +
  "    node.addEventListener('pointermove', (event) => {\n" +
  "      const rect = node.getBoundingClientRect();\n" +
  "      const px = (event.clientX - rect.left) / rect.width - 0.5;\n" +
  "      const py = (event.clientY - rect.top) / rect.height - 0.5;\n" +
  "      node.style.transform = `perspective(1200px) rotateX(${(-py * 5).toFixed(2)}deg) rotateY(${(px * 7).toFixed(2)}deg) translateY(-2px)`;\n" +
  "    });\n" +
  "    node.addEventListener('pointerleave', () => {\n" +
  "      node.style.transform = '';\n" +
  "    });\n" +
  "  });\n" +
  "}\n"
}

///|
fn escape_html(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
  .to_string()
}

///|
test "summary link parts parse markdown bullets" {
  let parsed = summary_link_parts("- [Home](./Home.md)").unwrap()
  assert_eq(parsed.0, "Home")
  assert_eq(parsed.1, "Home.md")
}

///|
async test "write marketing projection emits generated site bundle" {
  let root = "/tmp/moonbook-marketing-projection"
  ignore(init_workspace(root))
  let site_root = @path.Path(root).join(@path.Path("book/site")).to_string()
  let index_path = write_marketing_projection(root, site_root)
  let generated_dir = @path.Path(site_root)
    .join(@path.Path("generated"))
    .to_string()
  assert_eq(
    index_path,
    @path.Path(generated_dir).join(@path.Path("index.html")).to_string(),
  )
  assert_true(@fsx.exists(index_path))
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir)
      .join(@path.Path("marketing-state.json"))
      .to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir).join(@path.Path("styles.css")).to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir).join(@path.Path("app.js")).to_string(),
    ),
  )
  assert_true(@fsx.read_file(index_path).contains("Live marketing projection"))
}

///|
async test "ui state exposes readiness and query counts" {
  let root = "/tmp/moonbook-ui-state-ready"
  ignore(init_workspace(root))
  let initial_state = generate_ui_state(root)
  assert_true(initial_state.readiness.length() > 0)
  let raw_path = @path.Path(root).join(@path.Path("raw/demo.md")).to_string()
  @fsx.write_to_file(
    raw_path,
    "# Demo Source\n\nMoonBook maintains source pages and synthesis coverage.\n",
    create=0o644,
  )
  ignore(ingest_source(root, raw_path))
  let state = generate_ui_state(root)
  assert_true(
    state.metrics.any(fn(metric) { metric.label == "Coverage Readiness" }),
  )
  assert_true(state.metrics.any(fn(metric) { metric.label == "Query Notes" }))
  assert_true(state.readiness.length() > 0)
}
