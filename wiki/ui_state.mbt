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
