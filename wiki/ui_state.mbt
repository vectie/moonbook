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
pub struct UiJourneyItem {
  title : String
  stage : String
  status : String
  summary : String
  highlights : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub struct UiChapterLink {
  title : String
  href : String
  source_path : String
  number : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiSkillDiagnostics {
  total_count : Int
  workspace_count : Int
  seed_core_count : Int
  seed_extension_count : Int
  duplicate_count : Int
  missing_reference_count : Int
  warning_count : Int
  duplicate_names : Array[String]
  missing_reference_paths : Array[String]
  warnings : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub struct UiSkillItem {
  key : String
  name : String
  scope : String
  origin : String
  extension : String
  description : String
  path : String
  references : Array[String]
  missing_references : Array[String]
  overrides : Array[String]
  shadowed_by : Array[String]
  line_count : Int
  duplicate : Bool
  compare_status : String
  compare_summary : String
  compare_baseline_path : String
  compare_baseline_scope : String
  compare_changed_line_count : Int
  compare_selected_only_line_count : Int
  compare_baseline_only_line_count : Int
  compare_first_change_line : String
  compare_selected_excerpt : Array[String]
  compare_baseline_excerpt : Array[String]
  content : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiState {
  root : String
  title : String
  summary : String
  status_chips : Array[UiStatusChip]
  metrics : Array[UiMetric]
  workflow : Array[UiWorkflowItem]
  readiness : Array[UiPanelItem]
  review_queue : Array[UiPanelItem]
  keeper_items : Array[UiPanelItem]
  page_families : Array[UiPanelItem]
  journey : Array[UiJourneyItem]
  chapters : Array[UiChapterLink]
  skill_diagnostics : UiSkillDiagnostics
  skills : Array[UiSkillItem]
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
  let journey = ui_journey_items(root)
  let skill_records = list_skills(root)
  let skill_report = doctor_skills(root)
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
    root: @pathx.normalize(root),
    title: catalog_name(root),
    summary: catalog_purpose(root),
    status_chips,
    metrics,
    workflow,
    readiness,
    review_queue,
    keeper_items,
    page_families,
    journey,
    chapters: ui_chapter_links(root),
    skill_diagnostics: ui_skill_diagnostics(skill_report),
    skills: ui_skill_items(root, skill_records),
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
  let journal_index_path = @path.Path(generated_dir)
    .join(@path.Path("journal.html"))
    .to_string()
  let journal_state_path = @path.Path(generated_dir)
    .join(@path.Path("journal-state.json"))
    .to_string()
  let course_index_path = @path.Path(generated_dir)
    .join(@path.Path("course.html"))
    .to_string()
  let course_state_path = @path.Path(generated_dir)
    .join(@path.Path("course-state.json"))
    .to_string()
  let skills_index_path = @path.Path(generated_dir)
    .join(@path.Path("skills.html"))
    .to_string()
  let skills_state_path = @path.Path(generated_dir)
    .join(@path.Path("skills-state.json"))
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
  @fsx.write_to_file(
    journal_state_path,
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    journal_index_path,
    journal_projection_html(state, updated_note),
    create=0o644,
  )
  @fsx.write_to_file(
    course_state_path,
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    course_index_path,
    course_projection_html(state, updated_note),
    create=0o644,
  )
  @fsx.write_to_file(
    skills_state_path,
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    skills_index_path,
    skills_projection_html(state, updated_note),
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
async fn ui_journey_items(root : String) -> Array[UiJourneyItem] {
  let entries = recent_journey_entries(root, limit=4)
  if entries.is_empty() {
    return [
      {
        title: "Journey not started",
        stage: "bootstrap",
        status: "waiting",
        summary: "Persisted book results will start populating `wiki/history/journey.md` once the book begins ingest, review, or synthesis work.",
        highlights: ["keep the timeline compact and decision-focused"],
      },
    ]
  }
  entries.map(fn(entry) {
    {
      title: entry.task_id,
      stage: entry.stage,
      status: entry.status,
      summary: entry.summary,
      highlights: if entry.highlights.is_empty() {
        ["evidence: \{entry.evidence_id}"]
      } else {
        entry.highlights
      },
    }
  })
}

///|
fn ui_skill_diagnostics(report : SkillDoctorReport) -> UiSkillDiagnostics {
  {
    total_count: report.total_count,
    workspace_count: report.workspace_count,
    seed_core_count: report.seed_core_count,
    seed_extension_count: report.seed_extension_count,
    duplicate_count: report.duplicate_names.length(),
    missing_reference_count: report.missing_reference_paths.length(),
    warning_count: report.warnings.length(),
    duplicate_names: report.duplicate_names,
    missing_reference_paths: report.missing_reference_paths,
    warnings: report.warnings,
  }
}

///|
async fn ui_skill_items(
  root : String,
  records : Array[SkillRecord],
) -> Array[UiSkillItem] {
  let items : Array[UiSkillItem] = []
  for record in records {
    let compare = compare_skill(root, record.name) catch {
      _ =>
        {
          root: ".",
          name: record.name,
          selected_path: record.path,
          selected_scope: record.scope,
          baseline_path: None,
          baseline_scope: None,
          status: "unknown",
          summary: "Comparison unavailable.",
          compared_line_count: record.line_count,
          changed_line_count: 0,
          selected_only_line_count: 0,
          baseline_only_line_count: 0,
          first_change_line: None,
          selected_excerpt: [],
          baseline_excerpt: [],
        }
    }
    let content = if @fsx.exists(record.path) {
      @fsx.read_file(record.path)
    } else {
      ""
    }
    let missing_references : Array[String] = []
    for reference in record.references {
      if !@fsx.exists(reference) {
        missing_references.push(reference)
      }
    }
    items.push({
      key: record.scope + "|" + record.origin + "|" + record.path,
      name: record.name,
      scope: record.scope,
      origin: record.origin,
      extension: record.extension.unwrap_or("-"),
      description: record.description,
      path: record.path,
      references: record.references,
      missing_references,
      overrides: record.overrides,
      shadowed_by: record.shadowed_by,
      line_count: record.line_count,
      duplicate: !record.overrides.is_empty() || !record.shadowed_by.is_empty(),
      compare_status: compare.status,
      compare_summary: compare.summary,
      compare_baseline_path: compare.baseline_path.unwrap_or("-"),
      compare_baseline_scope: compare.baseline_scope.unwrap_or("-"),
      compare_changed_line_count: compare.changed_line_count,
      compare_selected_only_line_count: compare.selected_only_line_count,
      compare_baseline_only_line_count: compare.baseline_only_line_count,
      compare_first_change_line: match compare.first_change_line {
        Some(line) => line.to_string()
        None => "-"
      },
      compare_selected_excerpt: compare.selected_excerpt,
      compare_baseline_excerpt: compare.baseline_excerpt,
      content,
    })
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
  let advantages = marketing_advantage_cards()
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
  "  <meta name=\"description\" content=\"Marketing projection generated from MoonBook workspace state and product advantages.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"marketing\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"\{book_prefix}index.html\"><span class=\"brand-mark\">MB</span><span>\{project_title}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"\{book_prefix}index.html\">Book</a>\n" +
  "      <a href=\"./skills.html\">Skills</a>\n" +
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
  "          <a class=\"button button-secondary\" href=\"./journal.html\">Open journal view</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./skills.html\">Open skills view</a>\n" +
  "        </div>\n" +
  "        <div class=\"chip-row\">\{status_chips}</div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">positioning</span>\n" +
  "          <p>The wiki stays detailed and evidence-oriented. This surface stays horizontal: it explains the structural advantage of durable knowledge, multiple projections, and extension-friendly boundaries.</p>\n" +
  "        </div>\n" +
  "        <div class=\"panel-block panel-block-dark\">\n" +
  "          <span class=\"panel-label\">last update</span>\n" +
  "          <pre><code>\{update_note_html}</code></pre>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"state\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Product edge</p>\n" +
  "        <h2>Anchor the pitch in the current workspace state.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"metric-grid\">\{metrics}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading narrow\">\n" +
  "        <p class=\"eyebrow\">Advantages</p>\n" +
  "        <h2>Explain why this shape is stronger than shallow or tightly coupled alternatives.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{advantages}</div>\n" +
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
fn marketing_journey_item(item : UiJourneyItem) -> String {
  let highlights = item.highlights
    .map(fn(highlight) { "<li>\{escape_html(highlight)}</li>" })
    .join("")
  "<article class=\"journey-card\">" +
  "<div class=\"journey-meta\"><span>\{escape_html(item.stage)}</span><span class=\"journey-status status-\{escape_html(item.status)}\">\{escape_html(item.status)}</span></div>" +
  "<h3>\{escape_html(item.title)}</h3>" +
  "<p>\{escape_html(item.summary)}</p>" +
  "<ul>\{highlights}</ul>" +
  "</article>"
}

///|
fn marketing_advantage_cards() -> String {
  [
    marketing_workflow_card(
      "Durable knowledge instead of disposable answers", "The system accumulates maintained pages, so each new task starts from revised state rather than rediscovering raw fragments.",
      "durable",
    ),
    marketing_workflow_card(
      "One workspace, multiple surfaces", "Detailed wiki, static book, marketing site, and journal view all derive from the same local workspace instead of drifting apart.",
      "multi-surface",
    ),
    marketing_workflow_card(
      "Extension-friendly, not runtime-locked", "MoonBook remains a useful standalone wiki while still exposing clear seams for worker and town runtimes to plug in.",
      "open-boundary",
    ),
    marketing_workflow_card(
      "Operational truth stays visible", "Coverage readiness, review pressure, evidence, and Keeper memory remain inspectable, so the product story stays grounded.",
      "observable",
    ),
  ].join("")
}

///|
fn marketing_workflow_card(
  title : String,
  detail : String,
  status : String,
) -> String {
  "<article class=\"workflow-card\">" +
  "<span class=\"workflow-status status-\{escape_html(status)}\">\{escape_html(status)}</span>" +
  "<h3>\{escape_html(title)}</h3>" +
  "<p>\{escape_html(detail)}</p>" +
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
fn journal_projection_html(state : UiState, updated_note : String) -> String {
  let book_prefix = "../../"
  let timeline = state.journey
    .map(fn(item) { marketing_journey_item(item) })
    .join("")
  let stages = state.workflow
    .map(fn(item) {
      "<article class=\"module-card\">" +
      "<span class=\"module-kicker\">\{escape_html(item.status)}</span>" +
      "<h3>\{escape_html(item.title)}</h3>" +
      "<p>\{escape_html(item.detail)}</p>" +
      "</article>"
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
  let chapters = state.chapters
    .map(fn(item) {
      "<a class=\"chapter-link\" href=\"\{book_prefix}\{escape_html(item.href)}\">" +
      "<span class=\"chapter-number\">\{escape_html(item.number)}</span>" +
      "<span class=\"chapter-copy\"><strong>\{escape_html(item.title)}</strong><small>\{escape_html(item.source_path)}</small></span>" +
      "</a>"
    })
    .join("")
  let next_actions = state.readiness
    .map(fn(item) { marketing_panel_item(item) })
    .join("")
  let synthesis_preview = escape_html(state.synthesis_preview)
  let update_note_html = escape_html(updated_note)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{escape_html(state.title)} Journal</title>\n" +
  "  <meta name=\"description\" content=\"Journal view generated from MoonBook journey and wiki state.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"journal\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"./index.html\"><span class=\"brand-mark\">MB</span><span>\{escape_html(state.title)}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"./index.html\">Marketing</a>\n" +
  "      <a href=\"./skills.html\">Skills</a>\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"#timeline\">Timeline</a>\n" +
  "      <a href=\"#next\">Next</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell journal-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Journal view</p>\n" +
  "        <h1>Follow the book from earlier runs through the current state and the next pressure points.</h1>\n" +
  "        <p class=\"lede\">\{escape_html(state.summary)}</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"\{book_prefix}Home.html\">Open maintained wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./index.html\">Back to marketing</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">What changed recently</span>\n" +
  "          <pre><code>\{update_note_html}</code></pre>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Current operating shape</p>\n" +
  "        <h2>What phases define the book right now.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{stages}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"timeline\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Past to now</p>\n" +
  "        <h2>Timeline of major runs, decisions, and open loops.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"journey-grid\">\{timeline}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Now</p>\n" +
  "        <h2>The current state that the timeline has produced.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"metric-grid\">\{metrics}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"next\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Future</p>\n" +
  "        <h2>What still needs attention next.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"triple-grid\">\n" +
  "        <div class=\"panel-shell\"><h3>Next actions</h3>\{next_actions}</div>\n" +
  "        <div class=\"depth-card\"><h3>Chapter links</h3><div class=\"chapter-stack\">\{chapters}</div></div>\n" +
  "        <div class=\"depth-card\"><h3>Synthesis preview</h3><pre class=\"preview-block\"><code>\{synthesis_preview}</code></pre></div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn course_projection_html(state : UiState, updated_note : String) -> String {
  let book_prefix = "../../"
  let module_cards = state.workflow
    .map(fn(item) {
      "<article class=\"module-card\">" +
      "<span class=\"module-kicker\">\{escape_html(item.status)}</span>" +
      "<h3>\{escape_html(item.title)}</h3>" +
      "<p>\{escape_html(item.detail)}</p>" +
      "</article>"
    })
    .join("")
  let journey = state.journey
    .map(fn(item) { marketing_journey_item(item) })
    .join("")
  let checkpoints = course_checkpoint_cards().join("")
  let glossary = course_glossary_cards().join("")
  let metrics = state.metrics
    .map(fn(metric) {
      "<article class=\"metric-card metric-\{metric.tone}\">" +
      "<span class=\"metric-label\">\{escape_html(metric.label)}</span>" +
      "<strong>\{escape_html(metric.value)}</strong>" +
      "<p>\{escape_html(metric.note)}</p>" +
      "</article>"
    })
    .join("")
  let code_translation = course_translation_block(state, updated_note)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{escape_html(state.title)} Course</title>\n" +
  "  <meta name=\"description\" content=\"Educational course projection generated from MoonBook workspace state.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"course\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"./index.html\"><span class=\"brand-mark\">MB</span><span>\{escape_html(state.title)}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"./index.html\">Marketing</a>\n" +
  "      <a href=\"./journal.html\">Journal</a>\n" +
  "      <a href=\"./skills.html\">Skills</a>\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"#modules\">Modules</a>\n" +
  "      <a href=\"#checkpoints\">Checkpoints</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell journal-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Course view</p>\n" +
  "        <h1>Learn how this workspace works without reading the whole codebase.</h1>\n" +
  "        <p class=\"lede\">\{escape_html(state.summary)}</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"\{book_prefix}Home.html\">Open maintained wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./index.html\">Back to marketing</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./journal.html\">Open journal</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">teaching frame</span>\n" +
  "          <p>This surface explains the system in plain language. It teaches the actors, flow, and operational reasoning without replacing the detailed wiki.</p>\n" +
  "        </div>\n" +
  "        <div class=\"panel-block panel-block-dark\">\n" +
  "          <span class=\"panel-label\">latest change</span>\n" +
  "          <pre><code>\{escape_html(updated_note)}</code></pre>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"modules\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Module 1</p>\n" +
  "        <h2>Meet the operating stages.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{module_cards}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Module 2</p>\n" +
  "        <h2>Translate system language into plain English.</h2>\n" +
  "      </div>\n" +
  "      \{code_translation}\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Module 3</p>\n" +
  "        <h2>See the timeline and the state together.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"journey-grid\">\{journey}</div>\n" +
  "      <div class=\"metric-grid\">\{metrics}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading narrow\">\n" +
  "        <p class=\"eyebrow\">Module 4</p>\n" +
  "        <h2>Vocabulary you can use to steer the system better.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"journey-grid quiz-grid\">\{glossary}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"checkpoints\">\n" +
  "      <div class=\"section-heading narrow\">\n" +
  "        <p class=\"eyebrow\">Checkpoints</p>\n" +
  "        <h2>Test whether the explanation is actually usable.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"journey-grid quiz-grid\">\{checkpoints}</div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn skills_projection_html(state : UiState, updated_note : String) -> String {
  let book_prefix = "../../"
  let diagnostics = state.skill_diagnostics
  let metric_cards = [
      {
        label: "Tracked Skills",
        value: diagnostics.total_count.to_string(),
        note: "Workspace plus seeded core and extension skills visible in one surface.",
        tone: "healthy",
      },
      {
        label: "Workspace Overrides",
        value: diagnostics.workspace_count.to_string(),
        note: "Skills living under the active workspace `skills/` directory.",
        tone: if diagnostics.workspace_count > 0 {
          "review"
        } else {
          "info"
        },
      },
      {
        label: "Duplicate Names",
        value: diagnostics.duplicate_count.to_string(),
        note: "Name collisions across scopes that can confuse selection and override behavior.",
        tone: if diagnostics.duplicate_count > 0 {
          "alert"
        } else {
          "healthy"
        },
      },
      {
        label: "Missing References",
        value: diagnostics.missing_reference_count.to_string(),
        note: "Bundled `references/` paths mentioned by skills but missing on disk.",
        tone: if diagnostics.missing_reference_count > 0 {
          "alert"
        } else {
          "healthy"
        },
      },
    ]
    .map(fn(metric) {
      "<article class=\"metric-card metric-\{metric.tone}\">" +
      "<span class=\"metric-label\">\{escape_html(metric.label)}</span>" +
      "<strong>\{escape_html(metric.value)}</strong>" +
      "<p>\{escape_html(metric.note)}</p>" +
      "</article>"
    })
    .join("")
  let first_skill = if state.skills.is_empty() {
    empty_ui_skill_item()
  } else {
    state.skills[0]
  }
  let duplicate_items = if diagnostics.duplicate_names.is_empty() {
    "<article class=\"panel-item\"><strong>No duplicate names</strong><p>The current inventory does not collide on skill names.</p><small>healthy</small></article>"
  } else {
    diagnostics.duplicate_names
    .map(fn(name) {
      "<article class=\"panel-item\"><strong>\{escape_html(name)}</strong><p>This skill name exists in more than one scope. Check the detail panel to see override and shadow relationships.</p><small>duplicate</small></article>"
    })
    .join("")
  }
  let warning_items = if diagnostics.warnings.is_empty() {
    "<article class=\"panel-item\"><strong>No doctor warnings</strong><p>The skill inventory has no extra warnings beyond duplicates or missing references.</p><small>clean</small></article>"
  } else {
    diagnostics.warnings
    .map(fn(warning) {
      "<article class=\"panel-item\"><strong>Doctor warning</strong><p>\{escape_html(warning)}</p><small>attention</small></article>"
    })
    .join("")
  }
  let first_skill_references = join_lines(first_skill.references)
  let first_skill_overrides = join_lines_or_default(
    first_skill.overrides,
    "None",
  )
  let first_skill_shadowed = join_lines_or_default(
    first_skill.shadowed_by,
    "Not shadowed",
  )
  let first_skill_selected_excerpt = join_lines_or_default(
    first_skill.compare_selected_excerpt,
    "No selected excerpt.",
  )
  let first_skill_baseline_excerpt = join_lines_or_default(
    first_skill.compare_baseline_excerpt,
    "No baseline excerpt.",
  )
  let root_json = escape_html(state.root)
  let skill_rows = state.skills
    .map(fn(skill) {
      let extension_attr = if skill.extension == "-" {
        ""
      } else {
        " data-extension=\"\{escape_html(skill.extension)}\""
      }
      let duplicate = if skill.duplicate { "true" } else { "false" }
      let scope_tone = if skill.scope == "workspace" {
        "review"
      } else if skill.scope == "seed-extension" {
        "alert"
      } else {
        "healthy"
      }
      let duplicate_badge = if skill.duplicate {
        "<span class=\"chip chip-alert\">duplicate</span>"
      } else {
        ""
      }
      let description = if skill.description.is_empty() {
        "No description."
      } else {
        skill.description
      }
      "<button class=\"skill-row\" type=\"button\" data-skill-key=\"\{escape_html(skill.key)}\" data-skill-name=\"\{escape_html(skill.name)}\" data-scope=\"\{escape_html(skill.scope)}\" data-origin=\"\{escape_html(skill.origin)}\" data-duplicate=\"\{duplicate}\"\{extension_attr}>" +
      "<span class=\"skill-row-head\"><strong>\{escape_html(skill.name)}</strong><span class=\"skill-badges\"><span class=\"chip chip-\{scope_tone}\">\{escape_html(skill.scope)}</span>\{duplicate_badge}</span></span>" +
      "<span class=\"skill-row-body\">\{escape_html(description)}</span>" +
      "<span class=\"skill-row-meta\">\{escape_html(skill.extension)} · \{escape_html(skill.path)}</span>" +
      "</button>"
    })
    .join("")
  let skills_json = escape_html(state.to_json().stringify(indent=2))
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{escape_html(state.title)} Skills</title>\n" +
  "  <meta name=\"description\" content=\"Skill manager view generated from MoonBook skill inventory and diagnostics.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"skills\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"./index.html\"><span class=\"brand-mark\">MB</span><span>\{escape_html(state.title)}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"./index.html\">Marketing</a>\n" +
  "      <a href=\"./journal.html\">Journal</a>\n" +
  "      <a href=\"./course.html\">Course</a>\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"#explorer\">Explorer</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell journal-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Skill manager</p>\n" +
  "        <h1>Scan, compare, and inspect the skills that actually steer this workspace.</h1>\n" +
  "        <p class=\"lede\">This surface pulls together workspace overrides, core seeded skills, extension skill packs, duplicate names, bundled references, and doctor warnings in one browser view.</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"#explorer\">Open explorer</a>\n" +
  "          <a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Open wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./index.html\">Back to marketing</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">what changed</span>\n" +
  "          <pre><code>\{escape_html(updated_note)}</code></pre>\n" +
  "        </div>\n" +
  "        <div class=\"panel-block panel-block-dark\">\n" +
  "          <span class=\"panel-label\">first resolved skill</span>\n" +
  "          <p><strong>\{escape_html(first_skill.name)}</strong></p>\n" +
  "          <p>\{escape_html(first_skill.description)}</p>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Inventory</p>\n" +
  "        <h2>Browser-first visibility over the skill substrate.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"metric-grid\">\{metric_cards}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Pressure points</p>\n" +
  "        <h2>Duplicate names and doctor warnings stay visible.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"triple-grid skill-diagnostics-grid\">\n" +
  "        <div class=\"panel-shell\"><h3>Duplicate names</h3>\{duplicate_items}</div>\n" +
  "        <div class=\"panel-shell\"><h3>Doctor warnings</h3>\{warning_items}</div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"explorer\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Explorer</p>\n" +
  "        <h2>Filter the inventory, then inspect one skill in detail.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"skill-explorer\">\n" +
  "        <aside class=\"skill-sidebar panel-shell\">\n" +
  "          <div class=\"skill-toolbar\">\n" +
  "            <input id=\"skill-search\" class=\"skill-search\" type=\"search\" placeholder=\"Search skills, scopes, or origins\">\n" +
  "            <div class=\"skill-filters\">\n" +
  "              <button class=\"filter-pill is-active\" type=\"button\" data-skill-filter=\"all\">All</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"workspace\">Workspace</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"seed-core\">Seed Core</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"seed-extension\">Seed Extension</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"duplicate\">Duplicates</button>\n" +
  "            </div>\n" +
  "          </div>\n" +
  "          <div id=\"skill-list\" class=\"skill-list\">\{skill_rows}</div>\n" +
  "          <p id=\"skill-empty\" class=\"skill-empty\" hidden>No skills match the current filter.</p>\n" +
  "        </aside>\n" +
  "        <section class=\"skill-detail panel-shell\">\n" +
  "          <div class=\"skill-detail-head\">\n" +
  "            <div>\n" +
  "              <p class=\"eyebrow\">Selected skill</p>\n" +
  "              <h3 id=\"skill-detail-name\">\{escape_html(first_skill.name)}</h3>\n" +
  "            </div>\n" +
  "            <div id=\"skill-detail-badges\" class=\"chip-row\"></div>\n" +
  "          </div>\n" +
  "          <p id=\"skill-detail-description\" class=\"lede skill-detail-description\">\{escape_html(first_skill.description)}</p>\n" +
  "          <div class=\"skill-detail-grid\">\n" +
  "            <article class=\"panel-item\"><strong>Path</strong><p id=\"skill-detail-path\">\{escape_html(first_skill.path)}</p><small>resolved source</small></article>\n" +
  "            <article class=\"panel-item\"><strong>Origin</strong><p id=\"skill-detail-origin\">\{escape_html(first_skill.origin)}</p><small id=\"skill-detail-extension\">\{escape_html(first_skill.extension)}</small></article>\n" +
  "            <article class=\"panel-item\"><strong>References</strong><p id=\"skill-detail-references\">\{escape_html(first_skill_references)}</p><small>bundled detail files</small></article>\n" +
  "            <article class=\"panel-item\"><strong>Overrides / Shadowing</strong><p id=\"skill-detail-overrides\">\{escape_html(first_skill_overrides)}</p><small id=\"skill-detail-shadowed\">\{escape_html(first_skill_shadowed)}</small></article>\n" +
  "          </div>\n" +
  "          <div class=\"panel-shell skill-compare-shell\">\n" +
  "            <div class=\"section-heading compact-heading\">\n" +
  "              <p class=\"eyebrow\">Override drift</p>\n" +
  "              <h3>Compare the selected skill against its nearest baseline.</h3>\n" +
  "            </div>\n" +
  "            <div class=\"skill-compare-grid\">\n" +
  "              <article class=\"panel-item\"><strong>Status</strong><p id=\"skill-compare-status\">\{escape_html(first_skill.compare_status)}</p><small id=\"skill-compare-summary\">\{escape_html(first_skill.compare_summary)}</small></article>\n" +
  "              <article class=\"panel-item\"><strong>Baseline</strong><p id=\"skill-compare-baseline-path\">\{escape_html(first_skill.compare_baseline_path)}</p><small id=\"skill-compare-baseline-scope\">\{escape_html(first_skill.compare_baseline_scope)}</small></article>\n" +
  "              <article class=\"panel-item\"><strong>Change counts</strong><p id=\"skill-compare-counts\">changed=\{first_skill.compare_changed_line_count.to_string()} | selected-only=\{first_skill.compare_selected_only_line_count.to_string()} | baseline-only=\{first_skill.compare_baseline_only_line_count.to_string()}</p><small id=\"skill-compare-anchor\">first change line: \{escape_html(first_skill.compare_first_change_line)}</small></article>\n" +
  "            </div>\n" +
  "            <div class=\"skill-compare-excerpts\">\n" +
  "              <div class=\"skill-code-shell\"><div class=\"skill-code-head\"><span class=\"panel-label\">Selected excerpt</span></div><pre class=\"preview-block skill-code-block skill-diff-block\"><code id=\"skill-compare-selected\">\{escape_html(first_skill_selected_excerpt)}</code></pre></div>\n" +
  "              <div class=\"skill-code-shell\"><div class=\"skill-code-head\"><span class=\"panel-label\">Baseline excerpt</span></div><pre class=\"preview-block skill-code-block skill-diff-block\"><code id=\"skill-compare-baseline\">\{escape_html(first_skill_baseline_excerpt)}</code></pre></div>\n" +
  "            </div>\n" +
  "          </div>\n" +
  "          <div class=\"panel-shell skill-actions-shell\">\n" +
  "            <div class=\"section-heading compact-heading\">\n" +
  "              <p class=\"eyebrow\">Actions</p>\n" +
  "              <h3>Manage the selected skill through MoonBook CLI.</h3>\n" +
  "            </div>\n" +
  "            <div class=\"skill-action-grid\">\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Show metadata</strong><p>Inspect the resolved machine-readable record for the selected skill.</p><pre class=\"preview-block\"><code id=\"skill-command-show\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"show\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Compare against baseline</strong><p>Print the machine-readable drift report for the selected skill and its nearest baseline.</p><pre class=\"preview-block\"><code id=\"skill-command-compare\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"compare\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Install into workspace</strong><p>Copy a seeded skill into `skills/` so it becomes editable inside this workspace.</p><pre class=\"preview-block\"><code id=\"skill-command-install\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"install\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Scaffold workspace skill</strong><p>Create a new workspace-owned skill template with the same slug as the selected capability.</p><pre class=\"preview-block\"><code id=\"skill-command-scaffold\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"scaffold\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Doctor inventory</strong><p>Re-run duplicate and bundled-reference diagnostics for the whole workspace.</p><pre class=\"preview-block\"><code id=\"skill-command-doctor\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"doctor\">Copy command</button></article>\n" +
  "            </div>\n" +
  "            <p id=\"skill-command-note\" class=\"skill-command-note\">The generated site stays static. Real writes still go through MoonBook CLI so management remains explicit and auditable.</p>\n" +
  "          </div>\n" +
  "          <div class=\"skill-code-shell\">\n" +
  "            <div class=\"skill-code-head\"><span class=\"panel-label\">SKILL.md</span><span id=\"skill-detail-lines\">\{first_skill.line_count.to_string()} lines</span></div>\n" +
  "            <pre class=\"preview-block skill-code-block\"><code id=\"skill-detail-content\">\{escape_html(first_skill.content)}</code></pre>\n" +
  "          </div>\n" +
  "        </section>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script id=\"skills-state-inline\" type=\"application/json\">\{skills_json}</script>\n" +
  "  <script id=\"skills-root-inline\" type=\"application/json\">\{root_json}</script>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn empty_ui_skill_item() -> UiSkillItem {
  {
    key: "empty",
    name: "No skills found",
    scope: "empty",
    origin: "none",
    extension: "-",
    description: "The inventory is empty.",
    path: "",
    references: [],
    missing_references: [],
    overrides: [],
    shadowed_by: [],
    line_count: 0,
    duplicate: false,
    compare_status: "empty",
    compare_summary: "No comparison available.",
    compare_baseline_path: "-",
    compare_baseline_scope: "-",
    compare_changed_line_count: 0,
    compare_selected_only_line_count: 0,
    compare_baseline_only_line_count: 0,
    compare_first_change_line: "-",
    compare_selected_excerpt: [],
    compare_baseline_excerpt: [],
    content: "",
  }
}

///|
fn join_lines(values : Array[String]) -> String {
  if values.is_empty() {
    "None"
  } else {
    values.join("\n")
  }
}

///|
fn join_lines_or_default(values : Array[String], fallback : String) -> String {
  if values.is_empty() {
    fallback
  } else {
    values.join("\n")
  }
}

///|
fn course_translation_block(state : UiState, updated_note : String) -> String {
  let left = "workspace.health = \{state.status_chips.length()} visible signals\\n" +
    "workspace.metrics = \{state.metrics.length()} live counters\\n" +
    "workspace.journey = \{state.journey.length()} timeline entries\\n" +
    "latest_update = \{updated_note}"
  let right = [
      "The workspace exposes a small set of visible health signals.", "It keeps a few live counters so you can tell whether coverage is real.",
      "It maintains a compact timeline instead of forcing you to read raw logs.",
      "The latest update is surfaced as the current narrative anchor.",
    ]
    .map(fn(line) { "<li>\{escape_html(line)}</li>" })
    .join("")
  "<div class=\"depth-grid\">" +
  "<div class=\"depth-card\"><h3>System language</h3><pre class=\"preview-block\"><code>\{escape_html(left)}</code></pre></div>" +
  "<div class=\"depth-card\"><h3>Plain English</h3><ul class=\"translation-list\">\{right}</ul></div>" +
  "</div>"
}

///|
fn course_glossary_cards() -> Array[String] {
  [
    course_glossary_card(
      "Coverage readiness", "Whether the workspace has enough durable sources, ontology pages, and evidence to support synthesis reliably.",
    ),
    course_glossary_card(
      "Journey", "A compact timeline page that records major runs, decisions, failures, and open loops from past to now.",
    ),
    course_glossary_card(
      "Projection", "A derived website surface built from maintained wiki state, not a separate source of truth.",
    ),
    course_glossary_card(
      "Keeper memory", "Bounded working, user, and active memory used to hydrate future worker runs without bloating the core wiki.",
    ),
  ]
}

///|
fn course_glossary_card(term : String, explanation : String) -> String {
  "<article class=\"journey-card quiz-card\">" +
  "<div class=\"journey-meta\"><span>glossary</span><span class=\"journey-status status-active\">term</span></div>" +
  "<h3>\{escape_html(term)}</h3>" +
  "<p>\{escape_html(explanation)}</p>" +
  "</article>"
}

///|
fn course_checkpoint_cards() -> Array[String] {
  [
    course_checkpoint_card(
      "Why is the course surface separate from marketing?", "Because the course teaches how the system works, while marketing emphasizes the horizontal product advantage.",
    ),
    course_checkpoint_card(
      "Why is the journal surface separate from the course?", "Because the journal follows time from past to now to next, while the course organizes explanation into reusable teaching modules.",
    ),
    course_checkpoint_card(
      "What page should you inspect if you want the durable run timeline?", "Start with `wiki/history/journey.md`, not the marketing or course surfaces.",
    ),
    course_checkpoint_card(
      "What makes this course safe to generate automatically?", "It is derived from maintained wiki state and teaches that state, instead of inventing an independent narrative.",
    ),
  ]
}

///|
fn course_checkpoint_card(question : String, answer : String) -> String {
  "<article class=\"journey-card quiz-card\">" +
  "<div class=\"journey-meta\"><span>checkpoint</span><span class=\"journey-status status-active\">interactive</span></div>" +
  "<h3>\{escape_html(question)}</h3>" +
  "<button class=\"quiz-toggle\" type=\"button\">Reveal answer</button>" +
  "<p class=\"quiz-answer\" hidden>\{escape_html(answer)}</p>" +
  "</article>"
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
  ".journey-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".readiness-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".triple-grid, .depth-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }\n" +
  ".metric-card, .workflow-card, .panel-shell, .depth-card { padding: 1.3rem; }\n" +
  ".metric-card strong { display: block; margin-top: 0.4rem; font-size: 2rem; line-height: 1; }\n" +
  ".metric-label, .workflow-status { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }\n" +
  ".workflow-status { margin-bottom: 0.7rem; }\n" +
  ".status-active, .status-stable, .status-durable, .status-multi-surface, .status-open-boundary, .status-observable { color: #1b6b4f; }\n" +
  ".status-expanded, .status-crowded, .status-needed, .status-blocked { color: #9a3e1f; }\n" +
  ".metric-card p, .workflow-card p, .panel-item p, .panel-item small, .panel-block p { color: var(--muted); line-height: 1.66; }\n" +
  ".panel-item { padding: 1rem; margin-top: 0.9rem; border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".journey-card { padding: 1.2rem; border-radius: 1.35rem; border: 1px solid rgba(16, 33, 29, 0.08); background: rgba(255,255,255,0.62); box-shadow: var(--shadow); }\n" +
  ".journey-card ul { margin: 0.9rem 0 0; padding-left: 1.1rem; color: var(--muted); }\n" +
  ".translation-list { margin: 0; padding-left: 1.1rem; color: var(--muted); line-height: 1.7; }\n" +
  ".journey-meta { display: flex; justify-content: space-between; gap: 1rem; margin-bottom: 0.7rem; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }\n" +
  ".journey-status { color: var(--muted); }\n" +
  ".journal-shell .hero h1 { max-width: 11ch; }\n" +
  ".quiz-grid { align-items: start; }\n" +
  ".quiz-toggle { margin-top: 1rem; min-height: 2.75rem; padding: 0.7rem 1rem; border-radius: 999px; border: 1px solid var(--line); background: rgba(23, 60, 52, 0.06); font: inherit; font-weight: 700; color: var(--ink); cursor: pointer; }\n" +
  ".quiz-answer { margin-top: 0.9rem; }\n" +
  ".chapter-stack { display: grid; gap: 0.8rem; margin-top: 1rem; }\n" +
  ".chapter-link { display: grid; grid-template-columns: auto 1fr; gap: 0.8rem; align-items: start; padding: 0.9rem 1rem; border-radius: 1rem; background: rgba(255,255,255,0.66); border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".chapter-number { display: inline-grid; place-items: center; min-width: 2rem; height: 2rem; border-radius: 999px; background: rgba(23, 60, 52, 0.08); font-weight: 700; }\n" +
  ".chapter-copy { display: grid; gap: 0.2rem; }\n" +
  ".chapter-copy small { color: var(--muted); }\n" +
  ".preview-block { min-height: 18rem; background: rgba(16, 33, 29, 0.95); }\n" +
  ".skill-diagnostics-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }\n" +
  ".skill-explorer { display: grid; grid-template-columns: minmax(18rem, 25rem) minmax(0, 1fr); gap: 1rem; margin-top: 1.7rem; align-items: start; }\n" +
  ".skill-sidebar, .skill-detail { padding: 1.3rem; }\n" +
  ".skill-toolbar { display: grid; gap: 0.9rem; }\n" +
  ".skill-search { width: 100%; min-height: 3rem; padding: 0.8rem 1rem; border-radius: 999px; border: 1px solid var(--line); background: rgba(255,255,255,0.76); font: inherit; color: var(--ink); }\n" +
  ".skill-filters { display: flex; flex-wrap: wrap; gap: 0.6rem; }\n" +
  ".filter-pill { min-height: 2.45rem; padding: 0.6rem 0.9rem; border-radius: 999px; border: 1px solid var(--line); background: rgba(255,255,255,0.62); font: inherit; font-weight: 700; color: var(--muted); cursor: pointer; }\n" +
  ".filter-pill.is-active { color: #fff8ef; background: linear-gradient(135deg, var(--forest), #245b4d); border-color: transparent; }\n" +
  ".skill-list { display: grid; gap: 0.75rem; margin-top: 1rem; max-height: 58rem; overflow: auto; padding-right: 0.2rem; }\n" +
  ".skill-row { display: grid; gap: 0.55rem; width: 100%; text-align: left; padding: 1rem; border-radius: 1.1rem; border: 1px solid rgba(16, 33, 29, 0.1); background: rgba(255,255,255,0.64); color: inherit; cursor: pointer; transition: transform 180ms ease, border-color 180ms ease, box-shadow 180ms ease; }\n" +
  ".skill-row:hover, .skill-row.is-selected { transform: translateY(-1px); border-color: rgba(23, 60, 52, 0.24); box-shadow: 0 16px 30px rgba(23, 60, 52, 0.12); }\n" +
  ".skill-row-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }\n" +
  ".skill-row-body, .skill-row-meta, .skill-empty, .skill-detail-description { color: var(--muted); }\n" +
  ".skill-row-meta { font-size: 0.82rem; line-height: 1.5; word-break: break-word; }\n" +
  ".skill-badges { display: inline-flex; flex-wrap: wrap; gap: 0.4rem; justify-content: flex-end; }\n" +
  ".skill-detail-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }\n" +
  ".skill-detail-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1.2rem; }\n" +
  ".skill-detail-grid .panel-item p, .skill-detail-grid .panel-item small { white-space: pre-wrap; word-break: break-word; }\n" +
  ".compact-heading { margin-bottom: 0.95rem; }\n" +
  ".skill-compare-shell { margin-top: 1.2rem; }\n" +
  ".skill-compare-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; }\n" +
  ".skill-compare-excerpts { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1rem; }\n" +
  ".skill-diff-block { min-height: 18rem; max-height: 26rem; }\n" +
  ".skill-actions-shell { margin-top: 1.2rem; }\n" +
  ".skill-action-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }\n" +
  ".skill-command-card { display: grid; gap: 0.85rem; align-content: start; }\n" +
  ".skill-command-card .preview-block { min-height: 5rem; margin: 0; }\n" +
  ".skill-copy-command { justify-self: start; }\n" +
  ".skill-command-note { margin: 0.2rem 0 0; color: var(--muted); }\n" +
  ".skill-code-shell { margin-top: 1.2rem; }\n" +
  ".skill-code-head { display: flex; justify-content: space-between; gap: 1rem; align-items: center; margin-bottom: 0.75rem; }\n" +
  ".skill-code-block { min-height: 32rem; max-height: 52rem; }\n" +
  "#skill-detail-content { white-space: pre-wrap; word-break: break-word; }\n" +
  ".reveal { opacity: 0; transform: translateY(18px); transition: opacity 560ms ease, transform 560ms ease; }\n" +
  ".reveal.is-visible { opacity: 1; transform: translateY(0); }\n" +
  "@media (max-width: 980px) {\n" +
  "  .hero, .metric-grid, .workflow-grid, .journey-grid, .readiness-grid, .triple-grid, .depth-grid, .skill-explorer, .skill-detail-grid, .skill-diagnostics-grid, .skill-action-grid, .skill-compare-grid, .skill-compare-excerpts { grid-template-columns: 1fr; }\n" +
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
  "}\n" +
  "document.querySelectorAll('.quiz-toggle').forEach((button) => {\n" +
  "  button.addEventListener('click', () => {\n" +
  "    const answer = button.parentElement && button.parentElement.querySelector('.quiz-answer');\n" +
  "    if (!answer) return;\n" +
  "    const hidden = answer.hasAttribute('hidden');\n" +
  "    if (hidden) {\n" +
  "      answer.removeAttribute('hidden');\n" +
  "      button.textContent = 'Hide answer';\n" +
  "    } else {\n" +
  "      answer.setAttribute('hidden', 'hidden');\n" +
  "      button.textContent = 'Reveal answer';\n" +
  "    }\n" +
  "  });\n" +
  "});\n" +
  "const bodyPage = document.body && document.body.dataset ? document.body.dataset.page : '';\n" +
  "if (bodyPage === 'skills') {\n" +
  "  const inlineState = document.getElementById('skills-state-inline');\n" +
  "  const inlineRoot = document.getElementById('skills-root-inline');\n" +
  "  let parsed = null;\n" +
  "  let root = '.';\n" +
  "  if (inlineState && inlineState.textContent) {\n" +
  "    try {\n" +
  "      parsed = JSON.parse(inlineState.textContent);\n" +
  "    } catch (_) {\n" +
  "      parsed = null;\n" +
  "    }\n" +
  "  }\n" +
  "  if (inlineRoot && inlineRoot.textContent) {\n" +
  "    try {\n" +
  "      root = JSON.parse(inlineRoot.textContent);\n" +
  "    } catch (_) {\n" +
  "      root = '.';\n" +
  "    }\n" +
  "  }\n" +
  "  const statePromise = parsed ? Promise.resolve(parsed) : fetch('./skills-state.json').then((response) => response.json()).catch(() => null);\n" +
  "  statePromise.then((state) => {\n" +
  "    if (!state || !Array.isArray(state.skills)) return;\n" +
  "    const list = document.getElementById('skill-list');\n" +
  "    const empty = document.getElementById('skill-empty');\n" +
  "    const search = document.getElementById('skill-search');\n" +
  "    const filters = Array.from(document.querySelectorAll('[data-skill-filter]'));\n" +
  "    const detailName = document.getElementById('skill-detail-name');\n" +
  "    const detailDescription = document.getElementById('skill-detail-description');\n" +
  "    const detailPath = document.getElementById('skill-detail-path');\n" +
  "    const detailOrigin = document.getElementById('skill-detail-origin');\n" +
  "    const detailExtension = document.getElementById('skill-detail-extension');\n" +
  "    const detailReferences = document.getElementById('skill-detail-references');\n" +
  "    const detailOverrides = document.getElementById('skill-detail-overrides');\n" +
  "    const detailShadowed = document.getElementById('skill-detail-shadowed');\n" +
  "    const detailLines = document.getElementById('skill-detail-lines');\n" +
  "    const detailContent = document.getElementById('skill-detail-content');\n" +
  "    const detailBadges = document.getElementById('skill-detail-badges');\n" +
  "    const compareStatus = document.getElementById('skill-compare-status');\n" +
  "    const compareSummary = document.getElementById('skill-compare-summary');\n" +
  "    const compareBaselinePath = document.getElementById('skill-compare-baseline-path');\n" +
  "    const compareBaselineScope = document.getElementById('skill-compare-baseline-scope');\n" +
  "    const compareCounts = document.getElementById('skill-compare-counts');\n" +
  "    const compareAnchor = document.getElementById('skill-compare-anchor');\n" +
  "    const compareSelected = document.getElementById('skill-compare-selected');\n" +
  "    const compareBaseline = document.getElementById('skill-compare-baseline');\n" +
  "    const commandShow = document.getElementById('skill-command-show');\n" +
  "    const commandCompare = document.getElementById('skill-command-compare');\n" +
  "    const commandInstall = document.getElementById('skill-command-install');\n" +
  "    const commandScaffold = document.getElementById('skill-command-scaffold');\n" +
  "    const commandDoctor = document.getElementById('skill-command-doctor');\n" +
  "    const commandNote = document.getElementById('skill-command-note');\n" +
  "    const commandButtons = Array.from(document.querySelectorAll('.skill-copy-command'));\n" +
  "    let activeFilter = 'all';\n" +
  "    let selectedKey = state.skills[0] ? state.skills[0].key : '';\n" +
  "    const shellQuote = (value) => {\n" +
  "      const text = String(value == null ? '' : value);\n" +
  "      return `'${text.replace(/'/g, `'\"'\"'`)}'`;\n" +
  "    };\n" +
  "    const skillSlug = (value) => {\n" +
  "      const slug = String(value || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');\n" +
  "      return slug || 'new-skill';\n" +
  "    };\n" +
  "    const skillSelector = (skill) => {\n" +
  "      if (skill && skill.scope === 'seed-extension' && skill.extension && skill.extension !== '-') {\n" +
  "        return `${skill.name}@${skill.extension}`;\n" +
  "      }\n" +
  "      return skill && skill.name ? skill.name : '';\n" +
  "    };\n" +
  "    const commandText = (skill, kind) => {\n" +
  "      const quotedRoot = shellQuote(root || '.');\n" +
  "      const quotedName = shellQuote(skillSelector(skill));\n" +
  "      if (kind === 'show') return `moonbook skill show ${quotedName} ${quotedRoot}`;\n" +
  "      if (kind === 'compare') return `moonbook skill compare ${quotedName} ${quotedRoot}`;\n" +
  "      if (kind === 'doctor') return `moonbook skill doctor ${quotedRoot}`;\n" +
  "      if (kind === 'scaffold') return `moonbook skill scaffold ${shellQuote(skillSlug(skill && skill.name ? skill.name : 'new-skill'))} ${quotedRoot}`;\n" +
  "      if (kind === 'install') {\n" +
  "        return skill && (skill.scope === 'workspace' || (Array.isArray(skill.shadowed_by) && skill.shadowed_by.length > 0))\n" +
  "          ? '# already installed in workspace'\n" +
  "          : `moonbook skill install ${quotedName} ${quotedRoot}`;\n" +
  "      }\n" +
  "      return '';\n" +
  "    };\n" +
  "    const copyText = async (value) => {\n" +
  "      if (navigator.clipboard && window.isSecureContext) {\n" +
  "        await navigator.clipboard.writeText(value);\n" +
  "        return;\n" +
  "      }\n" +
  "      const node = document.createElement('textarea');\n" +
  "      node.value = value;\n" +
  "      node.setAttribute('readonly', '');\n" +
  "      node.style.position = 'fixed';\n" +
  "      node.style.top = '-9999px';\n" +
  "      document.body.appendChild(node);\n" +
  "      node.focus();\n" +
  "      node.select();\n" +
  "      document.execCommand('copy');\n" +
  "      document.body.removeChild(node);\n" +
  "    };\n" +
  "    const renderDetail = (skill) => {\n" +
  "      if (!skill) return;\n" +
  "      detailName.textContent = skill.name;\n" +
  "      detailDescription.textContent = skill.description || 'No description.';\n" +
  "      detailPath.textContent = skill.path || '-';\n" +
  "      detailOrigin.textContent = skill.origin || '-';\n" +
  "      detailExtension.textContent = skill.extension || '-';\n" +
  "      detailReferences.textContent = (skill.references && skill.references.length ? skill.references : ['None']).join('\\n');\n" +
  "      detailOverrides.textContent = (skill.overrides && skill.overrides.length ? skill.overrides : ['None']).join('\\n');\n" +
  "      detailShadowed.textContent = (skill.shadowed_by && skill.shadowed_by.length ? skill.shadowed_by : ['Not shadowed']).join('\\n');\n" +
  "      detailLines.textContent = `${skill.line_count || 0} lines`;\n" +
  "      detailContent.textContent = skill.content || '';\n" +
  "      if (compareStatus) compareStatus.textContent = skill.compare_status || '-';\n" +
  "      if (compareSummary) compareSummary.textContent = skill.compare_summary || 'No comparison summary.';\n" +
  "      if (compareBaselinePath) compareBaselinePath.textContent = skill.compare_baseline_path || '-';\n" +
  "      if (compareBaselineScope) compareBaselineScope.textContent = skill.compare_baseline_scope || '-';\n" +
  "      if (compareCounts) compareCounts.textContent = `changed=${skill.compare_changed_line_count || 0} | selected-only=${skill.compare_selected_only_line_count || 0} | baseline-only=${skill.compare_baseline_only_line_count || 0}`;\n" +
  "      if (compareAnchor) compareAnchor.textContent = `first change line: ${skill.compare_first_change_line || '-'}`;\n" +
  "      if (compareSelected) compareSelected.textContent = (skill.compare_selected_excerpt && skill.compare_selected_excerpt.length ? skill.compare_selected_excerpt : ['No selected excerpt.']).join('\\n');\n" +
  "      if (compareBaseline) compareBaseline.textContent = (skill.compare_baseline_excerpt && skill.compare_baseline_excerpt.length ? skill.compare_baseline_excerpt : ['No baseline excerpt.']).join('\\n');\n" +
  "      if (commandShow) commandShow.textContent = commandText(skill, 'show');\n" +
  "      if (commandCompare) commandCompare.textContent = commandText(skill, 'compare');\n" +
  "      if (commandInstall) commandInstall.textContent = commandText(skill, 'install');\n" +
  "      if (commandScaffold) commandScaffold.textContent = commandText(skill, 'scaffold');\n" +
  "      if (commandDoctor) commandDoctor.textContent = commandText(skill, 'doctor');\n" +
  "      if (commandNote) {\n" +
  "        commandNote.textContent = skill.scope === 'workspace' || (Array.isArray(skill.shadowed_by) && skill.shadowed_by.length > 0)\n" +
  "          ? 'This skill is already workspace-owned. Edit the path above directly or scaffold a sibling variant if you want a clean branch.'\n" +
  "          : 'This skill currently resolves from a seeded pack. Install it into the workspace if you want local ownership and edits.';\n" +
  "      }\n" +
  "      detailBadges.innerHTML = '';\n" +
  "      const badges = [skill.scope, skill.origin];\n" +
  "      if (skill.extension && skill.extension !== '-') badges.push(skill.extension);\n" +
  "      if (skill.duplicate) badges.push('duplicate');\n" +
  "      if (Array.isArray(skill.missing_references) && skill.missing_references.length) badges.push('missing references');\n" +
  "      badges.forEach((label) => {\n" +
  "        const span = document.createElement('span');\n" +
  "        span.className = `chip ${label === 'duplicate' || label === 'missing references' ? 'chip-alert' : label === 'workspace' ? 'chip-review' : 'chip-healthy'}`;\n" +
  "        span.textContent = label;\n" +
  "        detailBadges.appendChild(span);\n" +
  "      });\n" +
  "    };\n" +
  "    const visibleSkills = () => {\n" +
  "      const query = search && search.value ? search.value.trim().toLowerCase() : '';\n" +
  "      return state.skills.filter((skill) => {\n" +
  "        const matchesFilter = activeFilter === 'all' ? true : activeFilter === 'duplicate' ? !!skill.duplicate : skill.scope === activeFilter;\n" +
  "        const haystack = [skill.name, skill.scope, skill.origin, skill.extension, skill.description, skill.path].join(' ').toLowerCase();\n" +
  "        return matchesFilter && (!query || haystack.includes(query));\n" +
  "      });\n" +
  "    };\n" +
  "    const renderList = () => {\n" +
  "      const filtered = visibleSkills();\n" +
  "      Array.from(list.querySelectorAll('.skill-row')).forEach((node) => {\n" +
  "        const skill = state.skills.find((item) => item.key === node.dataset.skillKey);\n" +
  "        const show = filtered.includes(skill);\n" +
  "        node.hidden = !show;\n" +
  "        node.classList.toggle('is-selected', show && skill && skill.key === selectedKey);\n" +
  "      });\n" +
  "      if (empty) empty.hidden = filtered.length > 0;\n" +
  "      if (!filtered.find((item) => item.key === selectedKey) && filtered[0]) {\n" +
  "        selectedKey = filtered[0].key;\n" +
  "        renderDetail(filtered[0]);\n" +
  "      }\n" +
  "    };\n" +
  "    list.addEventListener('click', (event) => {\n" +
  "      const button = event.target && event.target.closest ? event.target.closest('.skill-row') : null;\n" +
  "      if (!button) return;\n" +
  "      const skill = state.skills.find((item) => item.key === button.dataset.skillKey);\n" +
  "      if (!skill) return;\n" +
  "      selectedKey = skill.key;\n" +
  "      renderDetail(skill);\n" +
  "      renderList();\n" +
  "    });\n" +
  "    commandButtons.forEach((button) => {\n" +
  "      button.addEventListener('click', async () => {\n" +
  "        const skill = state.skills.find((item) => item.key === selectedKey);\n" +
  "        if (!skill) return;\n" +
  "        const kind = button.dataset.skillCommand || 'show';\n" +
  "        const text = commandText(skill, kind);\n" +
  "        if (!text) return;\n" +
  "        await copyText(text);\n" +
  "        const original = button.textContent;\n" +
  "        button.textContent = 'Copied';\n" +
  "        window.setTimeout(() => {\n" +
  "          button.textContent = original;\n" +
  "        }, 1400);\n" +
  "      });\n" +
  "    });\n" +
  "    filters.forEach((button) => {\n" +
  "      button.addEventListener('click', () => {\n" +
  "        activeFilter = button.dataset.skillFilter || 'all';\n" +
  "        filters.forEach((item) => item.classList.toggle('is-active', item === button));\n" +
  "        renderList();\n" +
  "      });\n" +
  "    });\n" +
  "    if (search) search.addEventListener('input', renderList);\n" +
  "    renderDetail(state.skills[0]);\n" +
  "    renderList();\n" +
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
  let skills_index_path = @path.Path(generated_dir)
    .join(@path.Path("skills.html"))
    .to_string()
  let skills_state_path = @path.Path(generated_dir)
    .join(@path.Path("skills-state.json"))
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
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir).join(@path.Path("journal.html")).to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir)
      .join(@path.Path("journal-state.json"))
      .to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir).join(@path.Path("course.html")).to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir)
      .join(@path.Path("course-state.json"))
      .to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir).join(@path.Path("skills.html")).to_string(),
    ),
  )
  assert_true(
    @fsx.exists(
      @path.Path(generated_dir)
      .join(@path.Path("skills-state.json"))
      .to_string(),
    ),
  )
  assert_true(@fsx.read_file(index_path).contains("Live marketing projection"))
  assert_true(@fsx.read_file(skills_index_path).contains("Skill manager"))
  assert_true(
    @fsx.read_file(skills_state_path).contains("\"skill_diagnostics\""),
  )
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
  assert_true(state.journey.length() > 0)
}

///|
async test "ui state includes skill inventory diagnostics" {
  let root = "/tmp/moonbook-ui-state-skills"
  ignore(init_workspace(root))
  let state = generate_ui_state(root)
  assert_true(state.skill_diagnostics.total_count >= 17)
  assert_true(state.skills.length() >= 17)
  assert_true(state.skills[0].content.contains("---"))
}
