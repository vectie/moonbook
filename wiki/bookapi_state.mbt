///|
// Book summary, health, catalog, and coverage readiness helpers.

///|
pub async fn summarize_state(root : String) -> BookStateSummary {
  refresh_workspace_projections(root)
  let workspace = workspace_paths(root)
  let pages = collect_markdown_pages(workspace.wiki_dir)
  let pending = list_pending_reviews(root)
  let source_coverage = summarize_source_coverage(workspace.wiki_dir)
  let source_page_count = source_coverage.verified_count
  let entity_page_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_page_count = count_markdown_under(workspace.wiki_dir, "concepts")
  let query_note_count = count_markdown_under(workspace.wiki_dir, "queries")
  let keeper = keeper_snapshot(root)
  let evidence_count = count_evidence_entries(root)
  let substantive_coverage_ready = has_substantive_coverage(
    source_page_count, entity_page_count, concept_page_count, evidence_count,
  )
  {
    book_id: book_identity(root),
    root: workspace.root,
    page_count: pages.length(),
    source_count: source_coverage.total_count,
    source_page_count,
    candidate_source_count: source_coverage.candidate_count,
    provisional_source_count: source_coverage.provisional_count,
    verified_source_count: source_coverage.verified_count,
    entity_count: entity_page_count,
    entity_page_count,
    concept_count: concept_page_count,
    concept_page_count,
    query_note_count,
    pending_review_count: pending.length(),
    keeper_memory_count: keeper.active_memory.length() +
    keeper.user_memory.length(),
    keeper_working_count: keeper.working_memory.length(),
    evidence_count,
    substantive_coverage_ready,
    summary: "pages=\{pages.length()} sources_total=\{source_coverage.total_count} sources_verified=\{source_coverage.verified_count} sources_candidate=\{source_coverage.candidate_count} sources_provisional=\{source_coverage.provisional_count} entities=\{entity_page_count} concepts=\{concept_page_count} queries=\{query_note_count} pending_review=\{pending.length()} keeper_working=\{keeper.working_memory.length()} evidence=\{evidence_count} ready_for_synthesis=\{substantive_coverage_ready}",
  }
}

///|
pub async fn report_health(root : String) -> BookHealthReport {
  refresh_workspace_projections(root)
  let workspace = workspace_paths(root)
  let pending = list_pending_reviews(root)
  let claims_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/claims.md"))
    .to_string()
  let maintenance_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/maintenance-plan.md"))
    .to_string()
  let low_confidence = count_low_confidence_claims(
    if @fsx.exists(claims_path) {
      @fsx.read_file(claims_path)
    } else {
      ""
    },
  )
  let maintenance_entries = count_heading_entries(
    if @fsx.exists(maintenance_path) {
      @fsx.read_file(maintenance_path)
    } else {
      ""
    },
  )
  let keeper = keeper_snapshot(root)
  let source_coverage = summarize_source_coverage(workspace.wiki_dir)
  let source_page_count = source_coverage.verified_count
  let entity_page_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_page_count = count_markdown_under(workspace.wiki_dir, "concepts")
  let query_note_count = count_markdown_under(workspace.wiki_dir, "queries")
  let evidence_count = count_evidence_entries(root)
  let issues = coverage_issues(
    source_coverage, entity_page_count, concept_page_count, evidence_count,
  )
  let substantive_coverage_ready = has_substantive_coverage(
    source_page_count, entity_page_count, concept_page_count, evidence_count,
  )
  if pending.length() >= 5 {
    issues.push("pending review backlog is high")
  }
  if low_confidence >= 3 {
    issues.push("low-confidence claims require attention")
  }
  if maintenance_entries >= 8 {
    issues.push("maintenance plan is growing and may need pruning")
  }
  if keeper.working_memory.length() >= 8 {
    issues.push("keeper working memory is crowded")
  }
  let level = if issues.length() >= 3 {
    "critical"
  } else if !issues.is_empty() {
    "degraded"
  } else {
    "healthy"
  }
  {
    level,
    summary: "sources_verified=\{source_coverage.verified_count} sources_candidate=\{source_coverage.candidate_count} sources_provisional=\{source_coverage.provisional_count} entities=\{entity_page_count} concepts=\{concept_page_count} queries=\{query_note_count} pending_review=\{pending.length()} low_confidence_claims=\{low_confidence} maintenance_entries=\{maintenance_entries} keeper_working=\{keeper.working_memory.length()} evidence=\{evidence_count} ready_for_synthesis=\{substantive_coverage_ready}",
    source_page_count,
    candidate_source_count: source_coverage.candidate_count,
    provisional_source_count: source_coverage.provisional_count,
    verified_source_count: source_coverage.verified_count,
    entity_page_count,
    concept_page_count,
    query_note_count,
    pending_review_count: pending.length(),
    low_confidence_claim_count: low_confidence,
    maintenance_entry_count: maintenance_entries,
    keeper_working_count: keeper.working_memory.length(),
    evidence_count,
    substantive_coverage_ready,
    issues,
  }
}

///|
pub async fn catalog_record(root : String) -> BookCatalogRecord {
  let workspace = workspace_paths(root)
  {
    id: book_identity(root),
    name: catalog_name(root),
    purpose: catalog_purpose(root),
    workspace_root: workspace.root,
    memory_scope: catalog_memory_scope(root),
    tags: catalog_tags(root),
    skills: catalog_skills(root),
  }
}

///|
fn book_identity(root : String) -> String {
  @path.Path(@pathx.normalize(root)).basename().to_string()
}

///|
async fn catalog_name(root : String) -> String {
  let path = @path.Path(@pathx.normalize(root))
    .join(@path.Path("book.toml"))
    .to_string()
  if @fsx.exists(path) {
    let config = try? @core.from_toml(@fsx.read_file(path))
    match config {
      Ok(config) =>
        match config.book.title {
          Some(title) if !title.trim().is_empty() => return title
          _ => ()
        }
      Err(_) => ()
    }
  }
  "MoonBook / \{book_identity(root)}"
}

///|
async fn catalog_purpose(root : String) -> String {
  let home_path = @path.Path(@pathx.normalize(root))
    .join(@path.Path("wiki/Home.md"))
    .to_string()
  if @fsx.exists(home_path) {
    for raw in @fsx.read_file(home_path).split("\n") {
      let line = raw.trim().to_string()
      if !line.is_empty() &&
        !line.has_prefix("#") &&
        !line.has_prefix("- ") &&
        !line.has_prefix("1.") {
        return clamp_excerpt(line)
      }
    }
  }
  "Persistent per-domain wiki workspace with local memory, routines, and review."
}

///|
async fn catalog_memory_scope(root : String) -> String {
  let wiki_config = @path.Path(@pathx.normalize(root))
    .join(@path.Path("wiki.toml"))
    .to_string()
  if @fsx.exists(wiki_config) &&
    @fsx.read_file(wiki_config).to_lower().contains("task_ephemeral") {
    "TaskEphemeral"
  } else {
    "BookPrivate"
  }
}

///|
async fn catalog_tags(root : String) -> Array[String] {
  let tags : Array[String] = ["wiki", "moonbook"]
  let title = (catalog_name(root) catch { _ => "" }).to_lower()
  if title.contains("finance") && !tags.contains("finance") {
    tags.push("finance")
  }
  if title.contains("coding") && !tags.contains("coding") {
    tags.push("coding")
  }
  for line in policy_lines(root) {
    let lowered = line.to_lower()
    if lowered.contains("review") && !tags.contains("review") {
      tags.push("review")
    }
    if lowered.contains("memory") && !tags.contains("memory") {
      tags.push("memory")
    }
  }
  tags
}

///|
async fn catalog_skills(root : String) -> Array[String] {
  let skills : Array[String] = []
  for path in skill_markdown_paths(root) {
    let content = @fsx.read_file(path)
    let fallback = skill_name_from_path(path)
    let name = parse_skill_name(content, fallback)
    if !name.is_empty() && !skills.contains(name) {
      skills.push(name)
    }
  }
  if skills.is_empty() {
    ["wiki-ingest", "wiki-query", "wiki-lint", "wiki-review", "wiki-memory"]
  } else {
    skills
  }
}

///|
async fn policy_lines(root : String) -> Array[String] {
  let normalized = @pathx.normalize(root)
  let candidate_paths = [
    @path.Path(normalized).join(@path.Path("keeper/POLICY.md")).to_string(),
    @path.Path(normalized).join(@path.Path("AGENTS.md")).to_string(),
  ]
  let lines : Array[String] = []
  for path in candidate_paths {
    if !@fsx.exists(path) {
      continue
    }
    for raw in @fsx.read_file(path).split("\n") {
      let line = raw.trim().to_string()
      if line.has_prefix("- ") {
        lines.push(line.strip_prefix("- ").unwrap_or(line).to_string())
        if lines.length() >= 6 {
          break
        }
      }
    }
    if lines.length() >= 6 {
      break
    }
  }
  if lines.is_empty() {
    [
      "respect book-local boundaries", "promote only durable knowledge", "queue uncertain changes for review",
    ]
  } else {
    lines
  }
}

///|
async fn routine_lines(root : String) -> Array[String] {
  let normalized = @pathx.normalize(root)
  let path = @path.Path(normalized).join(@path.Path("ROUTINES.md")).to_string()
  let lines : Array[String] = []
  if @fsx.exists(path) {
    for raw in @fsx.read_file(path).split("\n") {
      let line = raw.trim().to_string()
      if line.has_prefix("1.") ||
        line.has_prefix("2.") ||
        line.has_prefix("3.") ||
        line.has_prefix("4.") {
        lines.push(line)
      }
    }
  }
  let resolver = @path.Path(normalized)
    .join(@path.Path("RESOLVER.md"))
    .to_string()
  if @fsx.exists(resolver) {
    for raw in @fsx.read_file(resolver).split("\n") {
      let line = raw.trim().to_string()
      if line.has_prefix("- intent:") {
        lines.push(line)
      }
      if lines.length() >= 6 {
        break
      }
    }
  }
  if lines.is_empty() {
    [
      "1. read index first", "2. work inside this book boundary", "3. persist durable knowledge carefully",
    ]
  } else {
    lines
  }
}

///|
async fn count_markdown_under(wiki_dir : String, child : String) -> Int {
  let path = @path.Path(wiki_dir).join(@path.Path(child)).to_string()
  if !@fsx.exists(path) {
    return 0
  }
  let mut count = 0
  for page in collect_markdown_pages(path) {
    if @path.Path(page).basename().to_string() != "SUMMARY.md" {
      count += 1
    }
  }
  count
}

///|
fn count_low_confidence_claims(content : String) -> Int {
  let mut count = 0
  for block in claim_blocks(content) {
    if claim_block_field(block, "- Confidence: `").unwrap_or("") == "low" {
      count += 1
    }
  }
  count
}

///|
fn count_heading_entries(content : String) -> Int {
  let mut count = 0
  for raw in content.split("\n") {
    if raw.to_string().has_prefix("### ") {
      count += 1
    }
  }
  count
}

///|
fn coverage_issues(
  source_coverage : SourceCoverageSummary,
  entity_page_count : Int,
  concept_page_count : Int,
  evidence_count : Int,
) -> Array[String] {
  let issues : Array[String] = []
  if source_coverage.verified_count == 0 {
    if source_coverage.candidate_count > 0 ||
      source_coverage.provisional_count > 0 {
      issues.push(
        "only candidate or provisional source pages exist; no verified source digestion is present yet",
      )
    } else {
      issues.push("no verified sources have been ingested yet")
    }
  }
  if entity_page_count == 0 && concept_page_count == 0 {
    issues.push("no maintained entity or concept coverage exists yet")
  }
  if evidence_count == 0 {
    issues.push("no evidence records have been captured yet")
  }
  issues
}

///|
fn has_substantive_coverage(
  verified_source_page_count : Int,
  entity_page_count : Int,
  concept_page_count : Int,
  evidence_count : Int,
) -> Bool {
  verified_source_page_count > 0 &&
  (entity_page_count > 0 || concept_page_count > 0) &&
  evidence_count > 0
}

///|
fn has_bootstrap_materialization(
  verified_source_page_count : Int,
  entity_page_count : Int,
  concept_page_count : Int,
  query_note_count : Int,
) -> Bool {
  verified_source_page_count > 0 &&
  (entity_page_count > 0 || concept_page_count > 0 || query_note_count > 0)
}

///|
async fn summarize_source_coverage(wiki_dir : String) -> SourceCoverageSummary {
  let sources_dir = @path.Path(wiki_dir).join(@path.Path("sources")).to_string()
  if !@fsx.exists(sources_dir) {
    return {
      total_count: 0,
      candidate_count: 0,
      provisional_count: 0,
      verified_count: 0,
    }
  }
  let mut total_count = 0
  let mut candidate_count = 0
  let mut provisional_count = 0
  let mut verified_count = 0
  for path in collect_markdown_pages(sources_dir) {
    total_count += 1
    match classify_source_page(@fsx.read_file(path)) {
      "candidate" => candidate_count += 1
      "provisional" => provisional_count += 1
      _ => verified_count += 1
    }
  }
  { total_count, candidate_count, provisional_count, verified_count }
}

///|
fn classify_source_page(content : String) -> String {
  let normalized = content.to_lower()
  if normalized.contains("source type: bootstrap candidate inventory") ||
    normalized.contains("candidate sources") ||
    normalized.contains("the files themselves are not readable") {
    "candidate"
  } else if normalized.contains("source type: provisional") ||
    normalized.contains("durability: provisional") ||
    normalized.contains("source type: candidate inventory") {
    "provisional"
  } else {
    "verified"
  }
}

///|
fn book_has_weak_coverage(state : BookStateSummary) -> Bool {
  !state.substantive_coverage_ready
}

///|
fn book_has_query_ready_coverage(state : BookStateSummary) -> Bool {
  state.substantive_coverage_ready
}

///|
