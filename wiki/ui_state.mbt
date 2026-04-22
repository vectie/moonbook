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
pub struct UiResearchReportSection {
  title : String
  detail : String
  evidence : String
} derive(Show, ToJson, FromJson)

///|
priv struct ResearchEvidenceRow {
  source_id : String
  evidence : String
  locator : String
  confidence : String
  notes : String
}

///|
pub struct UiMarketingSection {
  title : String
  body : String
  bullets : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub struct UiMarketingBrief {
  source_path : String
  headline : String
  lede : String
  sections : Array[UiMarketingSection]
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
  marketing_brief : UiMarketingBrief
  research_artifacts : Array[UiPanelItem]
  research_brief : String
  research_long_report : String
  research_report : Array[UiResearchReportSection]
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
  let project_title = ui_project_title(root)
  let project_summary = ui_project_summary(project_title, state, health)
  {
    root: @pathx.normalize(root),
    title: project_title,
    summary: project_summary,
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
    marketing_brief: ui_marketing_brief(root),
    research_artifacts: ui_research_artifacts(root),
    research_brief: ui_research_brief(root),
    research_long_report: ui_research_long_report(root),
    research_report: ui_research_report(root, project_title),
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
async fn ui_project_title(root : String) -> String {
  let catalog = catalog_name(root).trim()
  if !catalog.is_empty() && catalog != "LLM Wiki" {
    return catalog.to_string()
  }
  let leaf = @path.Path(@pathx.normalize(root)).basename().to_string()
  if leaf.has_prefix("research-") {
    return titleize_topic_slug(leaf[9:].to_string())
  }
  titleize_topic_slug(leaf)
}

///|
fn ui_project_summary(
  topic : String,
  state : BookStateSummary,
  health : BookHealthReport,
) -> String {
  if state.substantive_coverage_ready {
    return "MoonBook has verified source coverage, ontology pages, and evidence records for \{topic}. The generated surfaces can now summarize the domain instead of falling back to bootstrap diagnostics."
  }
  if state.verified_source_count == 0 &&
    (state.candidate_source_count > 0 || state.provisional_source_count > 0) {
    return "Bootstrap incomplete for \{topic}. The current workspace only has candidate or provisional source coverage, so the generated surfaces stay diagnostic instead of pretending the topic is already supported."
  }
  if state.source_page_count == 0 {
    return "Bootstrap incomplete for \{topic}. No verified source digestion exists yet, so the workspace should present missing coverage directly instead of defaulting to generic product copy."
  }
  if state.entity_page_count == 0 && state.concept_page_count == 0 {
    return "\{topic} has verified source material, but ontology coverage is still missing. The next pass should promote entity or concept pages before presenting this as mature synthesis."
  }
  let issue_summary = health.issues.join("; ")
  "MoonBook is still tightening coverage for \{topic}. \{issue_summary}"
}

///|
fn titleize_topic_slug(slug : String) -> String {
  let words : Array[String] = []
  for raw in slug.replace(old="_", new="-").to_string().split("-") {
    let token = raw.trim().to_string()
    if token.is_empty() {
      continue
    }
    if token == "llm" {
      words.push("LLM")
    } else {
      words.push(
        token[:1].to_upper().to_string() + token[1:].to_lower().to_string(),
      )
    }
  }
  if words.is_empty() {
    "MoonBook"
  } else {
    words.join(" ")
  }
}

///|
fn compact_review_label(kind : String, title : String) -> String {
  let compact = compact_task_label(title)
  "\{kind} | \{compact}"
}

///|
fn compact_task_label(text : String) -> String {
  let normalized = text.trim().to_lower()
  let lane = if normalized.contains("moontown-research-lane") {
    "Moontown lane"
  } else if normalized.contains("moonbook-research-lane") {
    "MoonBook lane"
  } else if normalized.contains("moonclaw-research-lane") {
    "MoonClaw lane"
  } else {
    ""
  }
  let action = if normalized.contains("bootstrap_gather") ||
    normalized.contains("bootstrap gather") {
    "bootstrap gather"
  } else if normalized.contains("wiki-review") ||
    normalized.contains("review-the-revised-pages") {
    "bootstrap review"
  } else if normalized.contains("entity-revise") ||
    normalized.contains("concept-revise") ||
    normalized.contains("synthesis-revise") {
    "ontology revise"
  } else if normalized.contains("wiki-ingest") &&
    normalized.contains("source-diarize") {
    "source gather"
  } else if normalized.contains("materialize") ||
    normalized.contains("source pages") {
    "source materialize"
  } else if normalized.contains("query") {
    "query pass"
  } else {
    ""
  }
  let rebuilt = if !lane.is_empty() && !action.is_empty() {
    "\{lane} \{action}"
  } else if !action.is_empty() {
    action
  } else if !lane.is_empty() {
    lane
  } else if normalized.has_prefix("goal-") {
    normalized[5:].to_string()
  } else {
    normalized.to_string()
  }
  let cleaned = rebuilt.replace(old="_", new=" ").to_string()
  let titled = titleize_topic_slug(
    cleaned.replace(old=" ", new="-").to_string(),
  )
  clamp_label(titled, 84)
}

///|
fn clamp_label(text : String, max_len : Int) -> String {
  if text.length() <= max_len {
    text
  } else {
    text[:max_len - 1].to_string() + "…"
  }
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
    chips.push({
      label: if state.substantive_coverage_ready {
        "review backlog"
      } else {
        "pending review"
      },
      tone: "review",
    })
  }
  chips.push({
    label: if state.substantive_coverage_ready {
      "ready for synthesis"
    } else if state.verified_source_count == 0 &&
      (state.candidate_source_count > 0 || state.provisional_source_count > 0) {
      "bootstrap incomplete"
    } else if state.source_page_count == 0 {
      "no verified sources"
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
      label: "Verified Sources",
      value: state.source_page_count.to_string(),
      note: if state.candidate_source_count > 0 ||
        state.provisional_source_count > 0 {
        "Verified source pages anchor synthesis. Candidate=\{state.candidate_source_count}, provisional=\{state.provisional_source_count}, verified=\{state.verified_source_count}."
      } else {
        "Verified source summaries under `wiki/sources/` anchor later query and synthesis work."
      },
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
  if state.verified_source_count == 0 &&
    (state.candidate_source_count > 0 || state.provisional_source_count > 0) {
    items.push({
      title: "Bootstrap incomplete",
      detail: "The workspace only has candidate or provisional source pages. MoonBook should not present this as durable coverage until at least one verified source and one ontology page exist.",
      meta: "candidate=\{state.candidate_source_count}, provisional=\{state.provisional_source_count}",
    })
  } else if state.source_page_count == 0 {
    items.push({
      title: "No verified sources yet",
      detail: "The workspace is still scaffold-only or blocked before source digestion. Put material under `raw/`, then run ingest so MoonBook can generate verified source pages.",
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
      detail: if state.verified_source_count == 0 &&
        (state.candidate_source_count > 0 || state.provisional_source_count > 0) {
        "Bootstrap produced candidate or provisional source pages, but not verified digestion. The next pass must turn real inspected material into `wiki/sources/` before broader synthesis work."
      } else if state.source_page_count == 0 {
        "No verified source pages exist yet. Bootstrap starts in `raw/`, then writes `wiki/sources/` before broader synthesis work."
      } else if state.substantive_coverage_ready {
        "Source pages, ontology pages, and evidence are in place. Ingest can now revise rather than just bootstrap."
      } else {
        "Source pages exist, but ontology or evidence coverage still needs another ingest/review pass."
      },
      status: if state.verified_source_count == 0 &&
        (state.candidate_source_count > 0 || state.provisional_source_count > 0) {
        "blocked"
      } else if state.source_page_count == 0 {
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
      detail: if state.substantive_coverage_ready {
        "Approvals can promote into overview, claims, cited pages, and staged durable targets without blocking the whole workspace from being presentable."
      } else {
        "Approvals can promote into overview, claims, cited pages, and staged durable targets, but they should not mask missing verified source or ontology coverage."
      },
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
          title: compact_review_label(item.kind, item.title),
          detail: find_review_field(block.block, "- Reason: ").unwrap_or(
            "Pending review item.",
          ),
          meta: find_review_field(block.block, "- Merge policy: `").unwrap_or(
            item.status,
          ),
        })
      None =>
        items.push({
          title: compact_review_label(item.kind, item.title),
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
async fn ui_research_artifacts(root : String) -> Array[UiPanelItem] {
  let items : Array[UiPanelItem] = []
  for spec in research_artifact_specs() {
    let path = @path.Path(root).join(@path.Path(spec.path)).to_string()
    if @fsx.exists(path) {
      items.push({
        title: spec.title,
        detail: markdown_excerpt(@fsx.read_file(path), 260),
        meta: spec.path,
      })
    } else {
      items.push({
        title: spec.title,
        detail: "Missing required artifact. Bootstrap should remain incomplete until this research record exists or a precise blocker explains why it cannot be produced.",
        meta: "missing: \{spec.path}",
      })
    }
  }
  items
}

///|
async fn ui_research_brief(root : String) -> String {
  for
    relative in [
      "raw/bootstrap/synthesis-brief.md", "raw/bootstrap/evidence-matrix.md",
    ] {
    let path = @path.Path(root).join(@path.Path(relative)).to_string()
    if @fsx.exists(path) {
      return @fsx.read_file(path)
    }
  }
  "No synthesis brief has been generated yet. The site should stay diagnostic until the research lane writes `raw/bootstrap/synthesis-brief.md` or explains the blocker."
}

///|
async fn ui_marketing_brief(root : String) -> UiMarketingBrief {
  for
    relative in [
      "wiki/synthesis/marketing.md", "raw/bootstrap/marketing-brief.md", "site/marketing.md",
    ] {
    let path = @path.Path(root).join(@path.Path(relative)).to_string()
    if @fsx.exists(path) {
      return parse_marketing_brief(relative, @fsx.read_file(path))
    }
  }
  {
    source_path: "missing: raw/bootstrap/marketing-brief.md",
    headline: "Marketing brief needed",
    lede: "Load `skills/wiki-marketing/SKILL.md` and generate `raw/bootstrap/marketing-brief.md` before using this as a product website.",
    sections: [
      {
        title: "Authoring contract",
        body: "The generated site renderer is ready, but the persuasive product copy must come from a keeper-authored marketing brief rather than MoonBook code.",
        bullets: [
          "Write a seller-facing headline and lede", "Add feature, audience, strength, surface, and conversion sections",
          "Keep evidence and debug detail in the wiki, journal, or course surfaces",
        ],
      },
    ],
  }
}

///|
fn parse_marketing_brief(
  source_path : String,
  content : String,
) -> UiMarketingBrief {
  let headline_parts : Array[String] = []
  let lede_parts : Array[String] = []
  let sections : Array[UiMarketingSection] = []
  let body_parts : Array[String] = []
  let bullets : Array[String] = []
  let mut headline = ""
  let mut current_title = ""
  let mut seen_section = false
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("# ") {
      headline = clean_marketing_text(line[2:].trim().to_string())
      continue
    }
    if line.has_prefix("## ") {
      if !current_title.is_empty() {
        sections.push({
          title: current_title,
          body: body_parts.join(" "),
          bullets: bullets.copy(),
        })
        body_parts.clear()
        bullets.clear()
      }
      current_title = clean_marketing_text(line[3:].trim().to_string())
      seen_section = true
      continue
    }
    if line.has_prefix("### ") {
      let subtitle = clean_marketing_text(line[4:].trim().to_string())
      if seen_section {
        bullets.push(subtitle)
      } else {
        lede_parts.push(subtitle)
      }
      continue
    }
    if line.has_prefix("- ") {
      let item = clean_marketing_text(line[2:].trim().to_string())
      if seen_section {
        bullets.push(item)
      } else {
        lede_parts.push(item)
      }
      continue
    }
    let cleaned = clean_marketing_text(line)
    if seen_section {
      body_parts.push(cleaned)
    } else if headline.is_empty() {
      headline_parts.push(cleaned)
    } else {
      lede_parts.push(cleaned)
    }
  }
  if !current_title.is_empty() {
    sections.push({
      title: current_title,
      body: body_parts.join(" "),
      bullets: bullets.copy(),
    })
  }
  let resolved_headline = if !headline.is_empty() {
    headline
  } else if !headline_parts.is_empty() {
    clamp_text(headline_parts.join(" "), 130)
  } else {
    "Marketing brief needs a headline"
  }
  let resolved_lede = if lede_parts.is_empty() {
    "The marketing brief exists but needs a short seller-facing lede."
  } else {
    clamp_text(lede_parts.join(" "), 360)
  }
  let resolved_sections = if sections.is_empty() {
    [
      {
        title: "Brief needs sections",
        body: "Add `##` sections for features, buyers, strengths, surfaces, and conversion path.",
        bullets: [],
      },
    ]
  } else {
    normalize_marketing_sections(sections)
  }
  {
    source_path,
    headline: resolved_headline,
    lede: resolved_lede,
    sections: resolved_sections,
  }
}

///|
fn normalize_marketing_sections(
  sections : Array[UiMarketingSection],
) -> Array[UiMarketingSection] {
  let normalized : Array[UiMarketingSection] = []
  for
    title in [
      "The Problem", "The Product", "Why It Wins", "What You Can Ship", "Who It Is For",
      "Proof Points", "Objections", "Next Step",
    ] {
    let body_parts : Array[String] = []
    let bullets : Array[String] = []
    for section in sections {
      if marketing_canonical_section_title(section.title) == title {
        if !section.body.trim().is_empty() {
          body_parts.push(sanitize_marketing_surface_text(section.body))
        }
        for bullet in section.bullets {
          if !bullet.trim().is_empty() {
            let cleaned = sanitize_marketing_surface_text(bullet)
            if !cleaned.trim().is_empty() {
              bullets.push(cleaned)
            }
          }
        }
      }
    }
    if !body_parts.is_empty() || !bullets.is_empty() {
      normalized.push({ title, body: body_parts.join(" "), bullets })
    }
  }
  if normalized.is_empty() {
    [
      {
        title: "The Problem",
        body: "The marketing brief did not follow the wiki-marketing skill skeleton. Regenerate it from `skills/wiki-marketing/SKILL.md` before using this page as final copy.",
        bullets: [],
      },
    ]
  } else {
    normalized
  }
}

///|
fn marketing_canonical_section_title(title : String) -> String {
  let lower = title.trim().to_lower()
  if lower == "the problem" ||
    lower.contains("buyer pain") ||
    lower.contains("buyer problem") ||
    lower.contains("core buyer pain") ||
    lower.contains("pain") ||
    lower.contains("problem") {
    "The Problem"
  } else if lower == "the product" ||
    lower.contains("product promise") ||
    lower.contains("core promise") ||
    lower.contains("product") ||
    lower.contains("positioning") ||
    lower.contains("promise") {
    "The Product"
  } else if lower == "why it wins" ||
    lower.contains("differentiation") ||
    lower.contains("supported strength") ||
    lower.contains("strength") ||
    lower.contains("competitive framing") ||
    lower.contains("wins") {
    "Why It Wins"
  } else if lower == "what you can ship" ||
    lower.contains("seller narrative") ||
    lower.contains("messaging angle") ||
    lower.contains("ship") ||
    lower.contains("deliverable") ||
    lower.contains("materialization target") {
    "What You Can Ship"
  } else if lower == "who it is for" ||
    lower.contains("audience") ||
    lower.contains("buyer") ||
    lower.contains("who") {
    "Who It Is For"
  } else if lower == "proof points" ||
    lower.contains("proof") ||
    lower.contains("evidence") ||
    lower.contains("verification") {
    "Proof Points"
  } else if lower == "objections" ||
    lower.contains("objection") ||
    lower.contains("guardrail") ||
    lower.contains("risk") {
    "Objections"
  } else if lower == "next step" ||
    lower.contains("next") ||
    lower.contains("action") ||
    lower.contains("cta") {
    "Next Step"
  } else {
    "Proof Points"
  }
}

///|
fn clean_marketing_text(text : String) -> String {
  let stripped = text
    .replace_all(old="**", new="")
    .replace_all(old="`", new="")
    .to_string()
    .trim(chars="# ")
    .to_string()
  sanitize_marketing_surface_text(clean_report_text(stripped))
}

///|
fn sanitize_marketing_surface_text(text : String) -> String {
  let mut cleaned = text
    .replace_all(old="raw/bootstrap/", new="research intake ")
    .replace_all(old="raw/bootstrap", new="research intake")
    .replace_all(old="wiki/sources/", new="source page ")
    .replace_all(old="wiki/entities/", new="entity page ")
    .replace_all(old="wiki/concepts/", new="concept page ")
    .replace_all(old="wiki/synthesis/", new="synthesis page ")
    .replace_all(old="memory_candidates", new="memory signals")
    .replace_all(old="requires_review", new="review signals")
    .replace_all(old="notify_town", new="town notification signals")
    .replace_all(old="task_id", new="task identifier")
    .replace_all(old="bootstrap_gather", new="research gathering")
    .replace_all(old="source_materialize", new="source preparation")
    .replace_all(old="knowledge_revise", new="knowledge revision")
    .replace_all(old="review_finalize", new="review closeout")
    .replace_all(old="marketing_project", new="marketing projection")
    .to_string()
  for prefix in ["C", "L", "W", "B"] {
    for index in 1..<31 {
      cleaned = cleaned
        .replace_all(old="\{prefix}\{index}, ", new="")
        .replace_all(old=", \{prefix}\{index}", new="")
        .replace_all(old="(\{prefix}\{index})", new="")
        .replace_all(old="\{prefix}\{index}.", new="")
        .replace_all(old="\{prefix}\{index}", new="")
        .to_string()
    }
  }
  cleaned
  .replace_all(old="Supported by .", new="")
  .replace_all(old="Supported by", new="")
  .replace_all(old="via .", new="")
  .replace_all(old=" .", new=".")
  .replace_all(old=" ,", new=",")
  .replace_all(old="  ", new=" ")
  .to_string()
  .trim()
  .to_string()
}

///|
async fn ui_research_long_report(root : String) -> String {
  for relative in ["wiki/synthesis/report.md", "raw/bootstrap/deep-report.md"] {
    let path = @path.Path(root).join(@path.Path(relative)).to_string()
    if @fsx.exists(path) {
      return @fsx.read_file(path)
    }
  }
  ""
}

///|
async fn ui_research_report(
  root : String,
  title : String,
) -> Array[UiResearchReportSection] {
  let brief = read_workspace_text(root, "raw/bootstrap/synthesis-brief.md")
  let evidence = read_workspace_text(root, "raw/bootstrap/evidence-matrix.md")
  let local_sources = read_workspace_text(
    root, "raw/bootstrap/local-sources.md",
  )
  let source_screen = read_workspace_text(
    root, "raw/bootstrap/source-screen.md",
  )
  let source_page = read_workspace_text(
    root, "wiki/sources/research-evidence.md",
  )
  let overview = read_workspace_text(root, "wiki/synthesis/overview.md")
  let evidence_rows = parse_research_evidence_rows(evidence)
  let corpus = brief +
    "\n\n" +
    evidence +
    "\n\n" +
    local_sources +
    "\n\n" +
    source_screen +
    "\n\n" +
    source_page +
    "\n\n" +
    overview
  [
    {
      title: "Executive summary",
      detail: research_executive_summary(title, brief, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["readme", "overview", "synthesis", title.to_lower()],
        evidence,
        "executive",
      ),
    },
    {
      title: "What is \{title}?",
      detail: research_topic_summary(title, brief, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        [title.to_lower(), "readme", "overview"],
        evidence,
        title.to_lower(),
      ),
    },
    {
      title: "Architecture",
      detail: research_keyword_summary(
        evidence_rows,
        [
          "architecture", "component", "topology", "boundary", "controller", "adapter",
          "routing",
        ],
        "Architecture evidence is still thin. Add files or source rows that describe components, boundaries, controllers, workers, and handoff points.",
      ),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["architecture", "topology", "controller", "adapter", "routing"],
        evidence,
        "architecture",
      ),
    },
    {
      title: "Runtime model",
      detail: research_keyword_summary(
        evidence_rows,
        [
          "runtime", "job", "session", "worker", "task", "provider", "gateway", "tool",
        ],
        "Runtime behavior is not yet summarized from evidence. The next gather pass should inspect job, provider, session, and worker runtime files.",
      ),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["runtime", "job", "session", "worker", "provider", "tool"],
        evidence,
        "runtime",
      ),
    },
    {
      title: "Memory and state",
      detail: research_keyword_summary(
        evidence_rows,
        [
          "memory", "state", "artifact", "workspace", "persistent", "durable", "storage",
          "keeper",
        ],
        "Memory and state behavior still needs a sourced section. Capture what is durable, what is temporary, and which layer owns each state family.",
      ),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["memory", "state", "artifact", "workspace", "storage", "keeper"],
        evidence,
        "memory",
      ),
    },
    {
      title: "Relationship to Moontown and MoonBook",
      detail: research_relationship_summary(title, corpus, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        [
          "moontown", "moonbook", "moonclaw", "relationship", "orchestration", "materialization",
        ],
        evidence,
        "moontown",
      ),
    },
    {
      title: "Comparative positioning",
      detail: research_comparison_summary(title, source_screen, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        [
          "mdbook", "openclaw", "maria", "compare", "comparison", "rewrite", "motivated",
        ],
        source_screen + "\n" + evidence,
        "comparison",
      ),
    },
    {
      title: "Maturity and gaps",
      detail: research_maturity_summary(brief, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["gap", "missing", "risk", "blocker", "future", "todo", "needs"],
        brief + "\n" + evidence,
        "gap",
      ),
    },
    {
      title: "Evidence table",
      detail: if evidence.trim().is_empty() {
        "No evidence matrix exists yet. Generate `raw/bootstrap/evidence-matrix.md` before treating this as a research report."
      } else {
        research_evidence_table_summary(evidence_rows)
      },
      evidence: "raw/bootstrap/evidence-matrix.md",
    },
  ]
}

///|
fn parse_research_evidence_rows(content : String) -> Array[ResearchEvidenceRow] {
  let rows : Array[ResearchEvidenceRow] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if !line.has_prefix("|") || line.contains("---") {
      continue
    }
    let cells = line
      .split("|")
      .map(fn(part) { part.trim().to_string() })
      .to_array()
    if cells.length() < 5 {
      continue
    }
    let source_id = cells[1]
    if source_id.is_empty() ||
      source_id == "Source ID" ||
      source_id == "Claim ID" {
      continue
    }
    rows.push({
      source_id,
      evidence: clean_report_text(cells[2]),
      locator: clean_report_text(cells[3]),
      confidence: clean_report_text(cells[4]),
      notes: if cells.length() > 5 {
        clean_report_text(cells[5])
      } else {
        ""
      },
    })
  }
  rows
}

///|
fn research_executive_summary(
  title : String,
  brief : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  match
    best_report_paragraph(brief, [
      "executive", "summary", "answer", "finding", "verified",
    ]) {
    Some(text) =>
      if is_shallow_report_paragraph(text) {
        research_executive_summary_from_rows(title, rows)
      } else {
        text
      }
    None => research_executive_summary_from_rows(title, rows)
  }
}

///|
fn research_executive_summary_from_rows(
  title : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  if rows.is_empty() {
    "No executive summary is available yet. Generate `raw/bootstrap/synthesis-brief.md` with a direct answer before presenting this page as a research article."
  } else {
    "\{title} is supported by \{rows.length()} screened evidence rows. The strongest current basis is \{row_brief(rows[0])}; keep explicit gaps visible until the synthesis brief becomes more analytical."
  }
}

///|
fn research_topic_summary(
  title : String,
  brief : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  match
    best_report_paragraph(brief, [
      title.to_lower(),
      "what is",
      "role",
      "purpose",
      "system",
    ]) {
    Some(text) =>
      if is_shallow_report_paragraph(text) {
        research_topic_summary_from_rows(title, rows)
      } else {
        text
      }
    None => research_topic_summary_from_rows(title, rows)
  }
}

///|
fn research_topic_summary_from_rows(
  title : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  let selected = select_evidence_rows(
    rows,
    [title.to_lower(), "readme", "overview", "home"],
    2,
  )
  if selected.is_empty() {
    "\{title} has not been explained from verified evidence yet. The report needs a role paragraph sourced from the synthesis brief or entity page."
  } else {
    "\{title} is described through \{selected.length()} high-signal source row(s): \{row_list_sentence(selected)}"
  }
}

///|
fn is_shallow_report_paragraph(text : String) -> Bool {
  let lowered = text.to_lower()
  lowered.has_prefix("topic:") ||
  lowered.has_prefix("verified findings:") ||
  lowered.has_prefix("web verification status:") ||
  lowered.has_prefix("next materialization:") ||
  lowered.contains("local source hints were mounted") ||
  lowered.contains("candidate source lists are not enough")
}

///|
fn best_non_shallow_report_paragraph(
  corpus : String,
  keywords : Array[String],
) -> String? {
  match best_report_paragraph(corpus, keywords) {
    Some(text) =>
      if is_shallow_report_paragraph(text) {
        None
      } else {
        Some(text)
      }
    None => None
  }
}

///|
fn research_keyword_summary(
  rows : Array[ResearchEvidenceRow],
  keywords : Array[String],
  fallback : String,
) -> String {
  let selected = select_evidence_rows(rows, keywords, 3)
  if selected.is_empty() {
    fallback
  } else {
    "The screened evidence points to \{row_list_sentence(selected)}"
  }
}

///|
fn research_relationship_summary(
  title : String,
  corpus : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  ignore(corpus)
  let selected = select_evidence_rows(
    rows,
    [
      "moontown", "moonbook", "moonclaw", "orchestration", "materialization", "runtime",
    ],
    3,
  )
  if selected.is_empty() {
    "Cross-project relationship evidence is not yet strong enough. The report should explain town orchestration, book memory/materialization, and claw execution boundaries."
  } else {
    "\{title} should be read inside the town-book-claw split: Moontown owns orchestration, MoonBook owns durable workspace and memory materialization, and MoonClaw owns worker execution. Current supporting rows: \{row_list_sentence(selected)}"
  }
}

///|
fn research_comparison_summary(
  title : String,
  source_screen : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  ignore(source_screen)
  let selected = select_evidence_rows(
    rows,
    [
      "mdbook", "openclaw", "maria", "compare", "comparison", "rewrite", "motivated",
    ],
    2,
  )
  if selected.is_empty() {
    "No supported comparison section exists yet for \{title}. The report should avoid external positioning claims until source-screen rows and evidence rows support them."
  } else {
    "Comparative positioning is supported only where the evidence names a lineage or adjacent system. Current support: \{row_list_sentence(selected)}"
  }
}

///|
fn research_maturity_summary(
  brief : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  match
    best_non_shallow_report_paragraph(brief, [
      "maturity", "gap", "missing", "risk", "blocker", "future", "trajectory",
    ]) {
    Some(text) => text
    None =>
      if rows.is_empty() {
        "Maturity is not yet assessed from evidence. The synthesis brief should distinguish verified behavior, provisional behavior, and implementation gaps."
      } else {
        let weak_rows = select_evidence_rows(
          rows,
          [
            "needs", "missing", "blocked", "provisional", "candidate", "unavailable",
          ],
          2,
        )
        if weak_rows.is_empty() {
          "Maturity looks presentable at the evidence-envelope level: \{rows.length()} source rows were screened. The next improvement is deeper synthesis, not more generic process copy."
        } else {
          "Maturity is mixed. The evidence envelope has \{rows.length()} screened rows, but gaps remain around \{row_list_sentence(weak_rows)}"
        }
      }
  }
}

///|
fn research_evidence_table_summary(rows : Array[ResearchEvidenceRow]) -> String {
  if rows.is_empty() {
    return "The evidence matrix exists but has no parseable source rows yet."
  }
  let local_count = research_evidence_ref_count(rows, "L")
  let web_count = research_evidence_ref_count(rows, "W")
  let examples = select_evidence_rows(
    rows,
    ["readme", "architecture", "runtime", "memory", "provider", "tool"],
    3,
  )
  "The report is backed by \{rows.length()} screened source row(s): \{local_count} local and \{web_count} web. Representative rows: \{row_list_sentence(examples)}"
}

///|
fn research_evidence_ref_count(
  rows : Array[ResearchEvidenceRow],
  prefix : String,
) -> Int {
  let refs : Array[String] = []
  for row in rows {
    for field in [row.source_id, row.locator, row.evidence, row.notes] {
      for source_ref in research_evidence_refs(field, prefix) {
        if !refs.contains(source_ref) {
          refs.push(source_ref)
        }
      }
    }
  }
  refs.length()
}

///|
fn research_evidence_refs(text : String, prefix : String) -> Array[String] {
  let refs : Array[String] = []
  let normalized = text
    .replace_all(old=",", new=" ")
    .replace_all(old=";", new=" ")
    .replace_all(old="(", new=" ")
    .replace_all(old=")", new=" ")
    .replace_all(old="[", new=" ")
    .replace_all(old="]", new=" ")
    .replace_all(old="`", new=" ")
  for token in normalized.split(" ") {
    let item = token.trim().trim(chars=".:").to_string()
    if item.length() < 2 || !item.has_prefix(prefix) {
      continue
    }
    let suffix = item[prefix.length():]
    if suffix.is_empty() {
      continue
    }
    let mut all_digits = true
    for ch in suffix {
      if ch < '0' || ch > '9' {
        all_digits = false
        break
      }
    }
    if all_digits && !refs.contains(item) {
      refs.push(item)
    }
  }
  refs
}

///|
async fn read_workspace_text(root : String, relative : String) -> String {
  let path = @path.Path(root).join(@path.Path(relative)).to_string()
  if @fsx.exists(path) {
    @fsx.read_file(path)
  } else {
    ""
  }
}

///|
fn report_evidence(corpus : String, keyword : String) -> String {
  match best_report_paragraph(corpus, [keyword]) {
    Some(text) => clamp_text(text, 180)
    None => "Evidence pending"
  }
}

///|
fn report_evidence_from_rows(
  rows : Array[ResearchEvidenceRow],
  keywords : Array[String],
  fallback_corpus : String,
  fallback_keyword : String,
) -> String {
  let selected = select_evidence_rows(rows, keywords, 1)
  if selected.is_empty() {
    report_evidence(fallback_corpus, fallback_keyword)
  } else {
    clamp_text("\{selected[0].source_id}: \{row_brief(selected[0])}", 180)
  }
}

///|
fn select_evidence_rows(
  rows : Array[ResearchEvidenceRow],
  keywords : Array[String],
  limit : Int,
) -> Array[ResearchEvidenceRow] {
  let selected : Array[ResearchEvidenceRow] = []
  for row in rows {
    if evidence_row_matches(row, keywords) {
      selected.push(row)
      if selected.length() >= limit {
        break
      }
    }
  }
  if selected.is_empty() && !rows.is_empty() && limit > 0 {
    selected.push(rows[0])
  }
  selected
}

///|
fn evidence_row_matches(
  row : ResearchEvidenceRow,
  keywords : Array[String],
) -> Bool {
  let haystack = (row.source_id +
  " " +
  row.evidence +
  " " +
  row.locator +
  " " +
  row.confidence +
  " " +
  row.notes).to_lower()
  for keyword in keywords {
    let key = keyword.trim().to_lower()
    if !key.is_empty() && haystack.contains(key) {
      return true
    }
  }
  false
}

///|
fn row_list_sentence(rows : Array[ResearchEvidenceRow]) -> String {
  rows.map(fn(row) { "\{row.source_id} (\{row_brief(row)})" }).join("; ") + "."
}

///|
fn row_brief(row : ResearchEvidenceRow) -> String {
  let base = if !row.evidence.is_empty() {
    row.evidence
  } else if !row.locator.is_empty() {
    row.locator
  } else {
    row.notes
  }
  clamp_text(clean_report_text(base), 220)
}

///|
fn clean_report_text(text : String) -> String {
  let focused = match marker_tail(text, "preview=") {
    Some(value) => value
    None =>
      match marker_tail(text, "snippet=") {
        Some(value) => value
        None => text
      }
  }
  focused
  .replace_all(old="`", new="")
  .replace_all(old="**", new="")
  .replace_all(old="alias=", new="")
  .replace_all(old="path=", new="")
  .replace_all(old="original=", new="")
  .replace_all(old="preview=", new="")
  .replace_all(old="snippet=", new="")
  .replace_all(old="status=included", new="")
  .replace_all(old="status=fetched", new="")
  .to_string()
  .trim()
  .to_string()
}

///|
fn marker_tail(text : String, marker : String) -> String? {
  match text.find(marker) {
    Some(index) => Some(text[index + marker.length():].trim().to_string())
    None => None
  }
}

///|
fn best_report_paragraph(corpus : String, keywords : Array[String]) -> String? {
  let chunks = markdown_paragraphs(corpus)
  let mut best_score = 0
  let mut best_text : String? = None
  for chunk in chunks {
    let lowered = chunk.to_lower()
    let mut score = 0
    for keyword in keywords {
      let key = keyword.trim().to_lower()
      if !key.is_empty() && lowered.contains(key) {
        score += 1
      }
    }
    if score > best_score {
      best_score = score
      best_text = Some(clamp_text(chunk, 620))
    }
  }
  best_text
}

///|
fn markdown_paragraphs(content : String) -> Array[String] {
  let chunks : Array[String] = []
  let current : Array[String] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() {
      if !current.is_empty() {
        chunks.push(current.join(" "))
        current.clear()
      }
      continue
    }
    if line == "---" || line.has_prefix("```") {
      continue
    }
    if line.has_prefix("|") {
      continue
    }
    let cleaned = if line.has_prefix("#") {
      line.replace(old="#", new="").to_string().trim().to_string()
    } else {
      line
    }
    if !cleaned.is_empty() {
      current.push(cleaned)
    }
  }
  if !current.is_empty() {
    chunks.push(current.join(" "))
  }
  chunks
}

///|
fn clamp_text(text : String, max_len : Int) -> String {
  if text.length() <= max_len {
    text
  } else if max_len <= 3 {
    "...".to_string()
  } else {
    let builder = StringBuilder::new()
    let mut count = 0
    for ch in text {
      if count >= max_len - 3 {
        break
      }
      builder.write_char(ch)
      count += 1
    }
    builder.to_string() + "..."
  }
}

///|
priv struct ResearchArtifactSpec {
  title : String
  path : String
}

///|
fn research_artifact_specs() -> Array[ResearchArtifactSpec] {
  [
    { title: "Research question", path: "raw/bootstrap/research-question.md" },
    { title: "Search log", path: "raw/bootstrap/search-log.md" },
    { title: "Source screen", path: "raw/bootstrap/source-screen.md" },
    { title: "Evidence matrix", path: "raw/bootstrap/evidence-matrix.md" },
    { title: "Local sources", path: "raw/bootstrap/local-sources.md" },
    { title: "Synthesis brief", path: "raw/bootstrap/synthesis-brief.md" },
    { title: "Deep report", path: "raw/bootstrap/deep-report.md" },
  ]
}

///|
fn markdown_excerpt(content : String, max_len : Int) -> String {
  let parts : Array[String] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() ||
      line.has_prefix("#") ||
      line.has_prefix("|") ||
      line == "---" ||
      line.has_prefix("```") {
      continue
    }
    parts.push(clean_report_text(line))
    if parts.join(" ").length() >= max_len {
      break
    }
  }
  let joined = parts.join(" ")
  if joined.is_empty() {
    return "Artifact exists but does not yet contain a readable summary."
  }
  clamp_text(joined, max_len)
}

///|
fn marketing_projection_html(state : UiState, updated_note : String) -> String {
  ignore(updated_note)
  let book_prefix = "../../"
  let marketing_sections = marketing_brief_sections_html(state.marketing_brief)
  let hero_panels = marketing_hero_panels_html(state.marketing_brief)
  let research_article = research_article_projection_html(state)
  let product_story = escape_html(state.marketing_brief.lede)
  let project_title = escape_html(state.title)
  let hero_headline = escape_html(state.marketing_brief.headline)
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
  "  <script src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script>\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"marketing\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"\{book_prefix}index.html\"><span class=\"brand-mark\">MB</span><span>\{project_title}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"\{book_prefix}index.html\">Book</a>\n" +
  "      <a href=\"#research\">Research</a>\n" +
  "      <a href=\"#features\">Story</a>\n" +
  "      <a href=\"#conversion\">Depth</a>\n" +
  "      <a href=\"./skills.html\">Skills</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Product website</p>\n" +
  "        <h1>\{hero_headline}</h1>\n" +
  "        <p class=\"lede\">\{product_story}</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"#features\">See the product</a>\n" +
  "          <a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Explore the wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./journal.html\">View progress</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\">\n" +
  "        \{hero_panels}\n" +
  "      </div>\n" +
  "    </section>\n" +
  research_article +
  "    <section class=\"section reveal\" id=\"features\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Product story</p>\n" +
  "        <h2>What the product offers, who it helps, and where readers should go next.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{marketing_sections}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"conversion\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Conversion path</p>\n" +
  "        <h2>Start with the product page, then open the surfaces that prove depth.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"depth-grid product-depth-grid\">\n" +
  "        <div class=\"depth-card\"><h3>For readers who want proof</h3><p>Keep the sales page focused, then route serious readers to the detailed wiki and structured book when they want substance.</p><div class=\"hero-actions stacked\"><a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Open wiki</a><a class=\"button button-secondary\" href=\"\{book_prefix}index.html\">Open book</a></div></div>\n" +
  "        <div class=\"depth-card\"><h3>For teams who operate it</h3><p>The journal, course, and skill manager stay one click away without crowding the product story.</p><div class=\"hero-actions stacked\"><a class=\"button button-secondary\" href=\"./journal.html\">Journal</a><a class=\"button button-secondary\" href=\"./course.html\">Course</a><a class=\"button button-secondary\" href=\"./skills.html\">Skills</a></div></div>\n" +
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
fn marketing_brief_sections_html(brief : UiMarketingBrief) -> String {
  let cards : Array[String] = []
  for section in brief.sections {
    if !section.title.trim().is_empty() &&
      (!section.body.trim().is_empty() || !section.bullets.is_empty()) {
      cards.push(marketing_brief_section_card(section))
    }
  }
  if cards.is_empty() {
    "<article class=\"workflow-card marketing-card\"><span class=\"workflow-status status-needed\">brief needed</span><h3>Marketing brief needs content</h3><p>Generate `raw/bootstrap/marketing-brief.md` from `skills/wiki-marketing/SKILL.md` so this page can present real buyer-facing positioning.</p></article>"
  } else {
    cards.join("")
  }
}

///|
fn marketing_hero_panels_html(brief : UiMarketingBrief) -> String {
  let first = brief.sections.get(0)
  let second = brief.sections.get(1)
  let first_panel = match first {
    Some(section) => marketing_hero_panel("product focus", section, false)
    None =>
      "<div class=\"panel-block\"><span class=\"panel-label\">product focus</span><p>\{escape_html(brief.lede)}</p></div>"
  }
  let second_panel = match second {
    Some(section) => marketing_hero_panel("reader value", section, true)
    None =>
      "<div class=\"panel-block panel-block-dark\"><span class=\"panel-label\">reader value</span><p>Open the deeper surfaces when you need proof, docs, timeline, or repeatable procedures.</p></div>"
  }
  first_panel + second_panel
}

///|
fn marketing_hero_panel(
  label : String,
  section : UiMarketingSection,
  dark : Bool,
) -> String {
  let block_class = if dark {
    "panel-block panel-block-dark"
  } else {
    "panel-block"
  }
  let bullets = if section.bullets.is_empty() {
    ""
  } else {
    let take_count = if section.bullets.length() < 3 {
      section.bullets.length()
    } else {
      3
    }
    let visible : Array[String] = []
    for index in 0..<take_count {
      visible.push(section.bullets[index])
    }
    "<ul class=\"hero-panel-list\">" +
    visible.map(fn(item) { "<li>\{escape_html(item)}</li>" }).join("") +
    "</ul>"
  }
  "<div class=\"\{block_class}\">" +
  "<span class=\"panel-label\">\{escape_html(label)}</span>" +
  "<h3>\{escape_html(section.title)}</h3>" +
  (if section.body.trim().is_empty() {
    ""
  } else {
    "<p>\{escape_html(section.body)}</p>"
  }) +
  bullets +
  "</div>"
}

///|
fn marketing_brief_section_card(section : UiMarketingSection) -> String {
  let body = section.body.trim().to_string()
  let bullets = if section.bullets.is_empty() {
    ""
  } else {
    "<ul>" +
    section.bullets.map(fn(item) { "<li>\{escape_html(item)}</li>" }).join("") +
    "</ul>"
  }
  "<article class=\"workflow-card marketing-card\">" +
  "<span class=\"workflow-status status-active\">highlight</span>" +
  "<h3>\{escape_html(section.title)}</h3>" +
  (if body.is_empty() { "" } else { "<p>\{escape_html(body)}</p>" }) +
  bullets +
  "</article>"
}

///|
fn research_article_projection_html(state : UiState) -> String {
  if !state.research_long_report.trim().is_empty() {
    "<section class=\"section reveal\" id=\"research\">" +
    "<div class=\"section-heading\">" +
    "<p class=\"eyebrow\">Deep research</p>" +
    "<h2>The generated site should present the knowledge, not only the product shell.</h2>" +
    "</div>" +
    "<div class=\"article-layout\">" +
    report_toc_html(state.research_long_report) +
    "<article class=\"long-report article-report\">" +
    markdown_report_html(state.research_long_report) +
    "</article>" +
    "</div>" +
    "</section>"
  } else {
    let cards = state.research_report
      .map(fn(section) { research_report_card_html(section) })
      .join("")
    "<section class=\"section reveal\" id=\"research\">" +
    "<div class=\"section-heading\">" +
    "<p class=\"eyebrow\">Research readiness</p>" +
    "<h2>The article view needs `raw/bootstrap/deep-report.md` before it can match a deep-research page.</h2>" +
    "</div>" +
    "<div class=\"report-grid\">\{cards}</div>" +
    "</section>"
  }
}

///|
fn research_report_card_html(section : UiResearchReportSection) -> String {
  "<article class=\"report-card\">" +
  "<div class=\"report-card-head\"><span class=\"workflow-status status-needed\">research</span><h3>\{escape_html(section.title)}</h3></div>" +
  "<p>\{escape_html(section.detail)}</p>" +
  (if section.evidence.trim().is_empty() {
    ""
  } else {
    "<div class=\"report-evidence\">\{escape_html(section.evidence)}</div>"
  }) +
  "</article>"
}

///|
fn markdown_report_html(markdown : String) -> String {
  let lines = markdown.split("\n").to_array()
  let html : Array[String] = []
  let mut index = 0
  let mut heading_index = 0
  let mut in_list = false
  while index < lines.length() {
    let line = lines[index].trim().to_string()
    if line.is_empty() {
      if in_list {
        html.push("</ul>")
        in_list = false
      }
      index += 1
      continue
    }
    if line.has_prefix("```mermaid") {
      if in_list {
        html.push("</ul>")
        in_list = false
      }
      let code : Array[String] = []
      index += 1
      while index < lines.length() && !lines[index].trim().has_prefix("```") {
        code.push(lines[index].to_string())
        index += 1
      }
      let rendered_code = escape_html(code.join("\n"))
      html.push("<div class=\"mermaid report-mermaid\">\{rendered_code}</div>")
      index += 1
      continue
    }
    if line.has_prefix("```") {
      if in_list {
        html.push("</ul>")
        in_list = false
      }
      let code : Array[String] = []
      index += 1
      while index < lines.length() && !lines[index].trim().has_prefix("```") {
        code.push(lines[index].to_string())
        index += 1
      }
      let rendered_code = escape_html(code.join("\n"))
      html.push(
        "<pre class=\"report-code\"><code>\{rendered_code}</code></pre>",
      )
      index += 1
      continue
    }
    if line.has_prefix("|") {
      if in_list {
        html.push("</ul>")
        in_list = false
      }
      let table_lines : Array[String] = []
      while index < lines.length() && lines[index].trim().has_prefix("|") {
        table_lines.push(lines[index].trim().to_string())
        index += 1
      }
      html.push(markdown_table_html(table_lines))
      continue
    }
    if line.has_prefix("- ") {
      if !in_list {
        html.push("<ul>")
        in_list = true
      }
      html.push("<li>\{inline_markdown_html(line[2:].trim().to_string())}</li>")
      index += 1
      continue
    }
    if in_list {
      html.push("</ul>")
      in_list = false
    }
    if line.has_prefix("# ") {
      heading_index += 1
      html.push(
        "<h2 id=\"report-sec-\{heading_index}\">\{inline_markdown_html(line[2:].trim().to_string())}</h2>",
      )
    } else if line.has_prefix("## ") {
      heading_index += 1
      html.push(
        "<h3 id=\"report-sec-\{heading_index}\">\{inline_markdown_html(line[3:].trim().to_string())}</h3>",
      )
    } else if line.has_prefix("### ") {
      html.push("<h4>\{inline_markdown_html(line[4:].trim().to_string())}</h4>")
    } else {
      html.push("<p>\{inline_markdown_html(line)}</p>")
    }
    index += 1
  }
  if in_list {
    html.push("</ul>")
  }
  html.join("")
}

///|
fn report_toc_html(markdown : String) -> String {
  let links : Array[String] = []
  let mut heading_index = 0
  for raw in markdown.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix("# ") || line.has_prefix("## ") {
      heading_index += 1
      let title = if line.has_prefix("## ") {
        line[3:].trim().to_string()
      } else {
        line[2:].trim().to_string()
      }
      if !title.is_empty() && links.length() < 14 {
        links.push(
          "<a href=\"#report-sec-\{heading_index}\">\{inline_markdown_html(title)}</a>",
        )
      }
    }
  }
  if links.is_empty() {
    ""
  } else {
    let body = links.join("")
    "<aside class=\"article-toc\"><p class=\"eyebrow\">Contents</p>\{body}</aside>"
  }
}

///|
fn markdown_table_html(lines : Array[String]) -> String {
  let rows : Array[String] = []
  let mut is_head = true
  for raw in lines {
    if raw.contains("---") {
      continue
    }
    let cells = raw
      .split("|")
      .map(fn(part) { part.trim().to_string() })
      .to_array()
    let visible : Array[String] = []
    for cell in cells {
      if !cell.is_empty() {
        visible.push(cell)
      }
    }
    if visible.is_empty() {
      continue
    }
    let tag = if is_head { "th" } else { "td" }
    rows.push(
      "<tr>" +
      visible
      .map(fn(cell) { "<\{tag}>\{inline_markdown_html(cell)}</\{tag}>" })
      .join("") +
      "</tr>",
    )
    is_head = false
  }
  if rows.is_empty() {
    ""
  } else {
    let body = rows.join("")
    "<div class=\"report-table-wrap\"><table class=\"report-table\">\{body}</table></div>"
  }
}

///|
fn inline_markdown_html(text : String) -> String {
  escape_html(text)
  .replace_all(old="**", new="")
  .replace_all(old="`", new="")
  .to_string()
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
  "              <article class=\"panel-item skill-command-card\"><strong>Sync candidate bundle</strong><p>Stage the workspace skill and its baseline into `skill-candidates/` for review without mutating repo seeds.</p><pre class=\"preview-block\"><code id=\"skill-command-sync\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"sync\">Copy command</button></article>\n" +
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
  ".hero-actions.stacked { align-items: flex-start; flex-direction: column; }\n" +
  ".button { display: inline-flex; align-items: center; justify-content: center; min-height: 3.15rem; padding: 0.85rem 1.2rem; border-radius: 999px; border: 1px solid transparent; font-weight: 700; }\n" +
  ".button-primary { color: #fff8ef; background: linear-gradient(135deg, var(--forest), #245b4d); box-shadow: 0 18px 36px rgba(23, 60, 52, 0.24); }\n" +
  ".button-secondary { border-color: var(--line); background: rgba(255, 255, 255, 0.56); }\n" +
  ".chip-row { display: flex; flex-wrap: wrap; gap: 0.7rem; margin-top: 1.25rem; }\n" +
  ".chip { padding: 0.5rem 0.72rem; border-radius: 999px; font-size: 0.9rem; border: 1px solid var(--line); background: rgba(255, 255, 255, 0.58); }\n" +
  ".chip-healthy { color: #1b6b4f; }\n" +
  ".chip-alert { color: #9a3e1f; }\n" +
  ".chip-review { color: #8b5b00; }\n" +
  ".hero-stage, .metric-card, .workflow-card, .panel-shell, .depth-card, .report-card, .long-report { border: 1px solid var(--line); box-shadow: var(--shadow); }\n" +
  ".hero-stage { display: grid; gap: 1rem; padding: 1.15rem; border-radius: 1.95rem; background: linear-gradient(180deg, rgba(255, 252, 246, 0.86), rgba(242, 228, 202, 0.74)); }\n" +
  ".panel-block, .metric-card, .workflow-card, .panel-shell, .depth-card, .panel-item, .report-card, .long-report { border-radius: 1.35rem; background: rgba(255,255,255,0.58); }\n" +
  ".panel-block { padding: 1rem; }\n" +
  ".panel-block-dark { background: var(--forest-deep); color: #edf5f0; }\n" +
  ".panel-label { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: var(--muted); }\n" +
  ".panel-block-dark .panel-label { color: rgba(237, 245, 240, 0.74); }\n" +
  ".hero-panel-list { margin: 0.85rem 0 0; padding-left: 1.1rem; color: var(--muted); line-height: 1.65; }\n" +
  ".panel-block-dark .hero-panel-list, .panel-block-dark p { color: rgba(237, 245, 240, 0.78); }\n" +
  "pre { overflow: auto; margin: 0.9rem 0 0; padding: 1rem; border-radius: 1rem; background: var(--forest-deep); color: #eff7f2; }\n" +
  ".section { padding: 4rem 0 0; }\n" +
  ".section-heading { display: flex; flex-direction: column; gap: 0.7rem; max-width: 48rem; }\n" +
  ".section-heading.narrow { max-width: 39rem; }\n" +
  ".metric-grid, .workflow-grid, .triple-grid, .depth-grid, .report-grid { display: grid; gap: 1rem; margin-top: 1.7rem; }\n" +
  ".metric-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }\n" +
  ".workflow-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }\n" +
  ".journey-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".readiness-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".triple-grid, .depth-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }\n" +
  ".report-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); align-items: stretch; }\n" +
  ".article-layout { display: grid; grid-template-columns: 16rem minmax(0, 1fr); gap: 1.2rem; align-items: start; margin-top: 1.7rem; }\n" +
  ".article-toc { position: sticky; top: 5.4rem; display: grid; gap: .35rem; padding: 1rem; border: 1px solid var(--line); border-radius: 1.2rem; background: rgba(255,255,255,.68); box-shadow: var(--shadow); }\n" +
  ".article-toc a { display: block; padding: .55rem .65rem; border-radius: .8rem; color: var(--muted); font-size: .9rem; line-height: 1.35; }\n" +
  ".article-toc a:hover, .article-toc a:focus-visible { color: var(--ink); background: rgba(23,60,52,.08); outline: none; }\n" +
  ".long-report { margin-top: 1.5rem; padding: 1.55rem; background: rgba(255,255,255,.74); }\n" +
  ".article-layout .long-report { margin-top: 0; }\n" +
  ".long-report h2 { font-family: 'Instrument Serif', Georgia, serif; font-size: clamp(2rem, 4vw, 3.3rem); line-height: .98; margin: .1rem 0 1rem; }\n" +
  ".long-report h3 { margin: 1.35rem 0 .55rem; font-size: 1.12rem; letter-spacing: -.01em; }\n" +
  ".long-report h4 { margin: 1rem 0 .4rem; color: var(--forest); }\n" +
  ".long-report p, .long-report li { color: var(--muted); font-size: .98rem; line-height: 1.75; }\n" +
  ".long-report ul { margin: .6rem 0 .75rem 1.2rem; padding: 0; }\n" +
  ".long-report .mermaid, .report-code { overflow-x: auto; margin: 1rem 0; padding: 1rem; border-radius: 1rem; border: 1px solid var(--line); background: rgba(23,60,52,.07); color: var(--ink); font-size: .88rem; line-height: 1.55; }\n" +
  ".report-mermaid { min-height: 14rem; display: grid; place-items: center; }\n" +
  ".report-table-wrap { overflow-x: auto; margin: 1rem 0; border-radius: 1rem; border: 1px solid var(--line); }\n" +
  ".report-table { width: 100%; border-collapse: collapse; min-width: 36rem; background: rgba(255,255,255,.64); }\n" +
  ".report-table th, .report-table td { padding: .7rem .8rem; text-align: left; border-bottom: 1px solid var(--line); color: var(--muted); font-size: .9rem; vertical-align: top; }\n" +
  ".report-table th { color: var(--ink); background: rgba(23,60,52,.08); }\n" +
  ".metric-card, .workflow-card, .panel-shell, .depth-card, .report-card { padding: 1.3rem; }\n" +
  ".report-card { display: flex; flex-direction: column; gap: 1rem; min-height: 17rem; }\n" +
  ".report-card-head { display: flex; flex-direction: column; gap: 0.45rem; }\n" +
  ".report-card p { margin: 0; color: var(--muted); line-height: 1.75; }\n" +
  ".report-evidence { margin-top: auto; color: var(--forest); font-weight: 700; line-height: 1.55; }\n" +
  ".architecture-map { display: grid; grid-template-columns: 1fr auto 1fr auto 1fr auto 1fr; gap: 0.5rem; align-items: center; padding: 0.85rem; border-radius: 1rem; background: rgba(23, 60, 52, 0.07); }\n" +
  ".architecture-map span { display: block; padding: 0.65rem; border-radius: 0.8rem; background: rgba(255,255,255,0.72); font-weight: 700; text-align: center; }\n" +
  ".architecture-map small { color: var(--muted); font-weight: 500; }\n" +
  ".metric-card strong { display: block; margin-top: 0.4rem; font-size: 2rem; line-height: 1; }\n" +
  ".metric-label, .workflow-status { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }\n" +
  ".workflow-status { margin-bottom: 0.7rem; }\n" +
  ".status-active, .status-stable, .status-durable, .status-multi-surface, .status-open-boundary, .status-observable { color: #1b6b4f; }\n" +
  ".status-expanded, .status-crowded, .status-needed, .status-blocked { color: #9a3e1f; }\n" +
  ".metric-card p, .workflow-card p, .panel-item p, .panel-item small, .panel-block p { color: var(--muted); line-height: 1.66; }\n" +
  ".marketing-card ul { margin: 1rem 0 0; padding-left: 1.15rem; color: var(--muted); line-height: 1.7; }\n" +
  ".panel-item { padding: 1rem; margin-top: 0.9rem; border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".surface-card { display: flex; flex-direction: column; gap: 0.65rem; margin-top: 0; }\n" +
  ".surface-card a { margin-top: auto; color: var(--forest); font-weight: 700; }\n" +
  ".product-depth-grid .depth-card p { color: var(--muted); line-height: 1.7; }\n" +
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
  "  .hero, .metric-grid, .workflow-grid, .journey-grid, .readiness-grid, .triple-grid, .depth-grid, .report-grid, .article-layout, .skill-explorer, .skill-detail-grid, .skill-diagnostics-grid, .skill-action-grid, .skill-compare-grid, .skill-compare-excerpts { grid-template-columns: 1fr; }\n" +
  "  .article-toc { position: static; }\n" +
  "  .architecture-map { grid-template-columns: 1fr; }\n" +
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
  "if (window.mermaid) {\n" +
  "  window.mermaid.initialize({ startOnLoad: true, theme: 'base', flowchart: { useMaxWidth: true, htmlLabels: true } });\n" +
  "}\n" +
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
  "    const commandSync = document.getElementById('skill-command-sync');\n" +
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
  "      if (kind === 'sync') {\n" +
  "        return skill && skill.scope === 'workspace'\n" +
  "          ? `moonbook skill sync ${quotedName} ${quotedRoot}`\n" +
  "          : '# sync requires a workspace-owned override';\n" +
  "      }\n" +
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
  "      if (commandSync) commandSync.textContent = commandText(skill, 'sync');\n" +
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
  let brief_path = @path.Path(root)
    .join(@path.Path("raw/bootstrap/marketing-brief.md"))
    .to_string()
  @fsx.write_to_file(
    brief_path,
    "# Sell the Workspace That Keeps Learning\n\nA product-facing front door for teams that want polished presentation and maintained knowledge in the same local project.\n\n## The Problem\n\nTeams need a clean story first and deeper proof later.\n\n- launch pages drift away from the docs\n- product proof gets buried in internal notes\n\n## The Product\n\nMoonBook turns maintained wiki state into a polished product website.\n\n- polished product website\n- detailed wiki behind the pitch\n- repeatable skill-driven publishing\n\n## Why It Wins\n\nThe pitch and the evidence live in the same workspace.\n\n- skill-driven publishing\n- durable wiki behind the site\n",
    create=0o644,
  )
  let deep_report_path = @path.Path(root)
    .join(@path.Path("raw/bootstrap/deep-report.md"))
    .to_string()
  @fsx.write_to_file(
    deep_report_path,
    "# MoonBook: Deep Research Analysis\n\n## Executive Summary\n\nMoonBook should present sourced research artifacts before marketing claims.\n\n## Architecture\n\n| Layer | Role |\n| --- | --- |\n| Book | Maintained memory and projection surface |\n\n```mermaid\nflowchart LR\nRaw[Raw packets] --> Wiki[Durable wiki]\nWiki --> Site[Generated site]\n```\n",
    create=0o644,
  )
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
  assert_true(@fsx.read_file(index_path).contains("Product website"))
  assert_true(
    @fsx.read_file(index_path).contains(
      "Sell the Workspace That Keeps Learning",
    ),
  )
  assert_true(@fsx.read_file(index_path).contains("The Problem"))
  assert_true(@fsx.read_file(index_path).contains("The Product"))
  assert_true(@fsx.read_file(index_path).contains("polished product website"))
  assert_true(@fsx.read_file(index_path).contains("Deep research"))
  assert_true(@fsx.read_file(index_path).contains("article-toc"))
  assert_true(
    @fsx.read_file(index_path).contains("MoonBook: Deep Research Analysis"),
  )
  assert_true(@fsx.read_file(index_path).contains("report-table"))
  assert_true(@fsx.read_file(index_path).contains("report-mermaid"))
  assert_true(
    !@fsx.read_file(index_path).contains("raw/bootstrap/marketing-brief.md"),
  )
  assert_true(!@fsx.read_file(index_path).contains("Research trail"))
  assert_true(!@fsx.read_file(index_path).contains("Live product signals"))
  assert_true(!@fsx.read_file(index_path).contains("Coverage Readiness"))
  assert_true(!@fsx.read_file(index_path).contains("critical"))
  assert_true(!@fsx.read_file(index_path).contains("no verified sources"))
  assert_true(!@fsx.read_file(index_path).contains("Skill-authored"))
  assert_true(!@fsx.read_file(index_path).contains("Claims Register"))
  assert_true(!@fsx.read_file(index_path).contains("Maintenance Plan"))
  assert_true(
    !@fsx.read_file(index_path).contains("Marketing page out of the box"),
  )
  assert_true(@fsx.read_file(skills_index_path).contains("Skill manager"))
  assert_true(
    @fsx.read_file(skills_state_path).contains("\"skill_diagnostics\""),
  )
  assert_true(!@fsx.read_file(index_path).contains("missing: raw/bootstrap"))
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
async test "ui state projects research artifacts and synthesis brief" {
  let root = "/tmp/moonbook-ui-state-research-artifacts"
  ignore(init_workspace(root))
  let bootstrap_dir = @path.Path(root)
    .join(@path.Path("raw/bootstrap"))
    .to_string()
  @fsx.make_directory(bootstrap_dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @path.Path(root)
    .join(@path.Path("raw/bootstrap/synthesis-brief.md"))
    .to_string(),
    "# Synthesis Brief\n\nFinding: MoonBook should present sourced research artifacts before marketing claims.\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @path.Path(root)
    .join(@path.Path("raw/bootstrap/evidence-matrix.md"))
    .to_string(),
    "# Evidence Matrix\n\n| Source ID | Evidence | Locator | Confidence | Notes |\n| --- | --- | --- | --- | --- |\n| L1 | preview=`MoonBook is a MoonBit rewrite of mdBook with wiki-maintainer projections.` | original=`README.md` | High | local README |\n| L2 | preview=`Architecture uses a keeper, skills, and generated site surfaces.` | original=`wiki/bookapi.mbt` | Medium | architecture row |\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @path.Path(root)
    .join(@path.Path("raw/bootstrap/deep-report.md"))
    .to_string(),
    "# Deep Report\n\n## Executive Summary\n\nMoonBook should present sourced research artifacts before marketing claims [L1].\n",
    create=0o644,
  )
  let state = generate_ui_state(root)
  assert_eq(state.research_artifacts.length(), 7)
  assert_true(state.research_long_report.contains("Deep Report"))
  assert_true(state.research_report.length() >= 8)
  assert_true(
    state.research_artifacts.any(fn(item) {
      item.meta == "raw/bootstrap/synthesis-brief.md" &&
      item.detail.contains("MoonBook should present sourced research artifacts")
    }),
  )
  assert_true(state.research_brief.contains("Finding: MoonBook should present"))
  assert_true(
    state.research_report.any(fn(section) {
      section.title == "Executive summary" &&
      section.detail.contains("MoonBook should present")
    }),
  )
  assert_true(
    state.research_report.all(fn(section) {
      !section.detail.contains("| Source ID")
    }),
  )
  assert_true(
    state.research_report.all(fn(section) { !section.detail.contains("alias=") }),
  )
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
