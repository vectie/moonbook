///|
pub struct BookTask {
  id : String
  title : String
  kind : String
  prompt : String
  priority : Int
  requires_review : Bool
  target_pages : Array[String]
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct BookTaskBatch {
  goal_id : String
  goal : String
  summary : String
  tasks : Array[BookTask]
} derive(Show, ToJson, FromJson)

///|
pub struct BookGoalAcceptance {
  goal_id : String
  accepted : Bool
  reason : String
  task_count : Int
  summary : String
} derive(Show, ToJson, FromJson)

///|
pub struct WorkerContextBundle {
  book_id : String
  workspace_root : String
  task_id : String
  prompt : String
  policy : Array[String]
  routines : Array[String]
  context_pages : Array[String]
  active_memory : Array[String]
  user_memory : Array[String]
  working_memory : Array[String]
  memory_summary : String
  output_contract : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub struct MemoryCandidate {
  kind : String
  title : String
  detail : String
  durable : Bool
  target_page : String?
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct BookResult {
  task_id : String
  summary : String
  artifacts : Array[String]
  memory_candidates : Array[MemoryCandidate]
  requires_review : Bool
  notify_town : Bool
} derive(Show, ToJson, FromJson)

///|
pub struct PersistResultOutcome {
  log_path : String
  updated_pages : Array[String]
  review_queued : Bool
  notify_town : Bool
} derive(Show, ToJson, FromJson)

///|
pub struct BookStateSummary {
  book_id : String
  root : String
  page_count : Int
  source_count : Int
  entity_count : Int
  concept_count : Int
  pending_review_count : Int
  summary : String
} derive(Show, ToJson, FromJson)

///|
pub struct BookHealthReport {
  level : String
  summary : String
  pending_review_count : Int
  low_confidence_claim_count : Int
  maintenance_entry_count : Int
  issues : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub struct BookCatalogRecord {
  id : String
  name : String
  purpose : String
  workspace_root : String
  memory_scope : String
  tags : Array[String]
  skills : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub async fn accept_goal(
  root : String,
  goal : String,
  goal_id? : String? = None,
) -> BookGoalAcceptance {
  let batch = produce_task_batch(root, goal, goal_id~)
  if batch.tasks.is_empty() {
    {
      goal_id: batch.goal_id,
      accepted: false,
      reason: "no local tasks could be produced",
      task_count: 0,
      summary: batch.summary,
    }
  } else {
    {
      goal_id: batch.goal_id,
      accepted: true,
      reason: "goal accepted into book-local task planning",
      task_count: batch.tasks.length(),
      summary: batch.summary,
    }
  }
}

///|
pub async fn produce_task_batch(
  root : String,
  goal : String,
  goal_id? : String? = None,
) -> BookTaskBatch {
  let workspace = workspace_paths(root)
  let state = summarize_state(root)
  let health = report_health(root)
  let normalized_goal_id = goal_id.unwrap_or("goal-\{slugify_title(goal)}")
  let notes = goal.to_lower()
  let tasks : Array[BookTask] = []

  if state.pending_review_count > 0 ||
    notes.contains("review") ||
    notes.contains("approve") ||
    notes.contains("safety") {
    tasks.push({
      id: "\{normalized_goal_id}-review",
      title: "Review pending book updates",
      kind: "review",
      prompt: "Inspect `wiki/reviews/pending.md`, decide what should be approved, rejected, or revised for the goal: \{goal}",
      priority: 100,
      requires_review: false,
      target_pages: [
        "reviews/pending.md", "reviews/approved.md", "synthesis/claims.md",
      ],
    })
  }

  let maintenance_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/maintenance-plan.md"))
    .to_string()
  let maintenance_text = if @fsx.exists(maintenance_path) {
    @fsx.read_file(maintenance_path)
  } else {
    ""
  }
  if maintenance_text.contains("### ") ||
    notes.contains("synth") ||
    notes.contains("maintain") ||
    notes.contains("update") ||
    notes.contains("memory") {
    tasks.push({
      id: "\{normalized_goal_id}-synthesis",
      title: "Update local synthesis and memory",
      kind: "synthesis",
      prompt: "Use `wiki/synthesis/maintenance-plan.md`, `wiki/index.md`, and `wiki/log.md` to revise durable wiki pages for the goal: \{goal}",
      priority: 90,
      requires_review: true,
      target_pages: [
        "synthesis/overview.md", "synthesis/claims.md", "synthesis/maintenance-plan.md",
      ],
    })
  }

  tasks.push({
    id: "\{normalized_goal_id}-analysis",
    title: "Produce domain-local task result",
    kind: "analysis",
    prompt: "Answer the goal inside this book boundary. Use the wiki pages as the durable context and do not leak into other books: \{goal}",
    priority: 80,
    requires_review: true,
    target_pages: ["index.md", "log.md", "synthesis/query-insights.md"],
  })

  if notes.contains("ingest") ||
    notes.contains("source") ||
    notes.contains("article") ||
    notes.contains("notes") {
    tasks.push({
      id: "\{normalized_goal_id}-ingest-followup",
      title: "Prepare ingest follow-up",
      kind: "ingest",
      prompt: "Inspect `raw/` and `wiki/sources/` to determine whether the goal requires new source ingestion or revision of existing source summaries: \{goal}",
      priority: 70,
      requires_review: true,
      target_pages: ["sources/", "synthesis/overview.md"],
    })
  }

  {
    goal_id: normalized_goal_id,
    goal,
    summary: "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level}",
    tasks: dedupe_tasks(tasks),
  }
}

///|
pub async fn hydrate_worker_context(
  root : String,
  task : BookTask,
) -> WorkerContextBundle {
  let workspace = workspace_paths(root)
  let keeper = keeper_snapshot(root)
  let policy = policy_lines(root)
  let routines = routine_lines(root)
  let memory_summary = summarize_memory(root)
  {
    book_id: book_identity(root),
    workspace_root: workspace.root,
    task_id: task.id,
    prompt: task.prompt,
    policy,
    routines,
    context_pages: default_context_pages(task.target_pages),
    active_memory: keeper.active_memory,
    user_memory: keeper.user_memory,
    working_memory: keeper.working_memory,
    memory_summary,
    output_contract: [
      "summary", "artifacts", "memory_candidates", "requires_review", "notify_town",
      "observations",
    ],
  }
}

///|
pub async fn persist_result(
  root : String,
  result : BookResult,
) -> PersistResultOutcome {
  let workspace = workspace_paths(root)
  let updated_pages : Array[String] = []
  let observations_relative = ensure_observations_page(workspace)
  updated_pages.push(observations_relative)
  let observations_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(observations_relative))
    .to_string()
  let mut observations = @fsx.read_file(observations_path)
  let block = persisted_result_block(result)
  observations = append_section_block(observations, "## Results", block)
  @fsx.write_to_file(observations_path, observations, create=0o644)

  for page in keeper_sync_result(root, result) {
    if !updated_pages.contains(page) {
      updated_pages.push(page)
    }
  }

  for candidate in result.memory_candidates {
    if !candidate.durable {
      continue
    }
    let relative_page = match candidate.target_page {
      Some(page) => page
      None => observations_relative
    }
    let absolute = @path.Path(workspace.wiki_dir)
      .join(@path.Path(relative_page))
      .to_string()
    if !@fsx.exists(absolute) {
      seed_memory_candidate_page(absolute, candidate.title)
      update_summary(workspace.summary_path, candidate.title, relative_page)
      update_index_section(
        @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
        memory_candidate_section(relative_page),
        candidate.title,
        relative_page,
        "durable memory promoted from persisted book results",
      )
      if !updated_pages.contains(relative_page) {
        updated_pages.push(relative_page)
      }
    }
    let current = @fsx.read_file(absolute)
    let next = append_section_block(
      current,
      "## Durable Memory",
      "### \{candidate.title}\n\n- Kind: `\{candidate.kind}`\n- Detail: \{candidate.detail}\n",
    )
    @fsx.write_to_file(absolute, next, create=0o644)
    if !updated_pages.contains(relative_page) {
      updated_pages.push(relative_page)
    }
  }

  let plan_relative = ensure_maintenance_plan_entry(
    workspace,
    "Persist result: \{result.task_id}",
    "persist-result",
    "wiki/" + observations_relative,
    updated_pages,
    [
      "notify_town: \{result.notify_town}",
      "requires_review: \{result.requires_review}",
      "artifacts: \{result.artifacts.length()}",
    ],
  )
  if !updated_pages.contains(plan_relative) {
    updated_pages.push(plan_relative)
  }

  let review_queued = if result.requires_review {
    queue_result_review(workspace, result, observations_relative)
  } else {
    false
  }
  if review_queued && !updated_pages.contains("reviews/pending.md") {
    updated_pages.push("reviews/pending.md")
  }

  append_result_log(
    @path.Path(workspace.wiki_dir).join(@path.Path("log.md")).to_string(),
    result,
    updated_pages,
  )
  {
    log_path: @path.Path(workspace.wiki_dir)
    .join(@path.Path("log.md"))
    .to_string(),
    updated_pages,
    review_queued,
    notify_town: result.notify_town,
  }
}

///|
pub async fn summarize_state(root : String) -> BookStateSummary {
  let workspace = workspace_paths(root)
  let pages = collect_markdown_pages(workspace.wiki_dir)
  let pending = list_pending_reviews(root)
  let source_count = count_markdown_under(workspace.wiki_dir, "sources")
  let entity_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_count = count_markdown_under(workspace.wiki_dir, "concepts")
  {
    book_id: book_identity(root),
    root: workspace.root,
    page_count: pages.length(),
    source_count,
    entity_count,
    concept_count,
    pending_review_count: pending.length(),
    summary: "pages=\{pages.length()} sources=\{source_count} entities=\{entity_count} concepts=\{concept_count} pending_review=\{pending.length()}",
  }
}

///|
pub async fn report_health(root : String) -> BookHealthReport {
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
  let issues : Array[String] = []
  if pending.length() >= 5 {
    issues.push("pending review backlog is high")
  }
  if low_confidence >= 3 {
    issues.push("low-confidence claims require attention")
  }
  if maintenance_entries >= 8 {
    issues.push("maintenance plan is growing and may need pruning")
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
    summary: "pending_review=\{pending.length()} low_confidence_claims=\{low_confidence} maintenance_entries=\{maintenance_entries}",
    pending_review_count: pending.length(),
    low_confidence_claim_count: low_confidence,
    maintenance_entry_count: maintenance_entries,
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
  let skills : Array[String] = ["analysis", "memory", "review"]
  for line in routine_lines(root) {
    let lowered = line.to_lower()
    if lowered.contains("plan") && !skills.contains("planning") {
      skills.push("planning")
    }
    if lowered.contains("index") && !skills.contains("retrieval") {
      skills.push("retrieval")
    }
  }
  skills
}

///|
async fn policy_lines(root : String) -> Array[String] {
  let path = @path.Path(@pathx.normalize(root))
    .join(@path.Path("AGENTS.md"))
    .to_string()
  let lines : Array[String] = []
  if !@fsx.exists(path) {
    return [
      "respect book-local boundaries", "promote only durable knowledge", "queue uncertain changes for review",
    ]
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
  let path = @path.Path(@pathx.normalize(root))
    .join(@path.Path("ROUTINES.md"))
    .to_string()
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
  if lines.is_empty() {
    [
      "1. read index first", "2. work inside this book boundary", "3. persist durable knowledge carefully",
    ]
  } else {
    lines
  }
}

///|
async fn summarize_memory(root : String) -> String {
  let workspace = workspace_paths(root)
  let keeper = keeper_snapshot(root)
  let claims_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/claims.md"))
    .to_string()
  let overview_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/overview.md"))
    .to_string()
  let claims = if @fsx.exists(claims_path) {
    count_heading_entries(@fsx.read_file(claims_path))
  } else {
    0
  }
  let updates = if @fsx.exists(overview_path) {
    count_heading_entries(@fsx.read_file(overview_path))
  } else {
    0
  }
  "keeper_active=\{keeper.active_memory.length()} keeper_user=\{keeper.user_memory.length()} keeper_working=\{keeper.working_memory.length()} claims=\{claims} overview_updates=\{updates}"
}

///|
fn default_context_pages(target_pages : Array[String]) -> Array[String] {
  let pages : Array[String] = [
    "index.md", "log.md", "synthesis/overview.md", "synthesis/claims.md",
  ]
  for page in target_pages {
    if !pages.contains(page) {
      pages.push(page)
    }
  }
  pages
}

///|
fn dedupe_tasks(tasks : Array[BookTask]) -> Array[BookTask] {
  let deduped : Array[BookTask] = []
  for task in tasks {
    if !deduped.map(item => item.id).contains(task.id) {
      deduped.push(task)
    }
  }
  deduped
}

///|
async fn ensure_observations_page(workspace : Paths) -> String {
  let relative = "synthesis/observations.md"
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  if !@fsx.exists(absolute) {
    @fsx.write_to_file(
      absolute,
      "# Observations\n\nThis page stores persisted task results and durable observations.\n\n## Results\n\n_None yet._\n",
      create=0o644,
    )
    update_summary(workspace.summary_path, "Observations", relative)
    update_index_section(
      @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
      "Core Pages",
      "Observations",
      relative,
      "persisted task results and memory observations",
    )
  }
  relative
}

///|
fn persisted_result_block(result : BookResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string("### \{result.task_id}\n\n")
  builder.write_string("- Summary: \{result.summary}\n")
  builder.write_string("- Requires review: `\{result.requires_review}`\n")
  builder.write_string("- Notify town: `\{result.notify_town}`\n")
  if !result.artifacts.is_empty() {
    builder.write_string("- Artifacts:\n")
    for artifact in result.artifacts {
      builder.write_string("  - `\{artifact}`\n")
    }
  }
  if !result.memory_candidates.is_empty() {
    builder.write_string("- Memory candidates:\n")
    for candidate in result.memory_candidates {
      builder.write_string(
        "  - \{candidate.title} (`\{candidate.kind}` durable=`\{candidate.durable}`)\n",
      )
    }
  }
  builder.write_string("\n")
  builder.to_string()
}

///|
async fn seed_memory_candidate_page(path : String, title : String) -> Unit {
  @fsx.write_to_file(
    path,
    "# \{title}\n\n## Durable Memory\n\n_None yet._\n",
    create=0o644,
  )
}

///|
async fn queue_result_review(
  workspace : Paths,
  result : BookResult,
  observations_relative : String,
) -> Bool {
  let relative = "reviews/pending.md"
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  let review_id = "result-review-\{slugify_title(result.task_id)}"
  let current = if @fsx.exists(absolute) {
    @fsx.read_file(absolute)
  } else {
    "# Pending Review\n\n## Items\n\n_None yet._\n"
  }
  if current.contains("- Review ID: `\{review_id}`") {
    return true
  }
  let link = relative_from_page(
    "wiki/" + relative,
    "wiki/" + observations_relative,
  )
  let block = "### Result review | \{result.task_id}\n\n" +
    "- Review ID: `\{review_id}`\n" +
    "- Result page: [\{result.task_id}](\{link})\n" +
    "- Status: `pending`\n" +
    "- Reason: persisted worker result requires promotion review\n" +
    "- Candidate insight: \{clamp_excerpt(result.summary)}\n\n"
  let updated = append_section_block(current, "## Items", block)
  @fsx.write_to_file(absolute, updated, create=0o644)
  update_summary(workspace.summary_path, "Pending Review", relative)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Core Pages",
    "Pending Review",
    relative,
    "queue of human review items for contested or high-value updates",
  )
  true
}

///|
async fn append_result_log(
  log_path : String,
  result : BookResult,
  updated_pages : Array[String],
) -> Unit {
  let now = "\{@async.now().to_int()}"
  let entry = "## [\{now}] persist | \{result.task_id}\n\n" +
    "- summary: \{result.summary}\n" +
    "- notify_town: `\{result.notify_town}`\n" +
    format_related_log_lines(updated_pages)
  let current = @fsx.read_file(log_path)
  let next = if current.has_suffix("\n") {
    current + "\n" + entry
  } else {
    current + "\n\n" + entry
  }
  @fsx.write_to_file(log_path, next, create=0o644)
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
fn memory_candidate_section(relative_page : String) -> String {
  if relative_page.has_prefix("entities/") {
    "Entities"
  } else if relative_page.has_prefix("concepts/") {
    "Concepts"
  } else if relative_page.has_prefix("queries/") {
    "Queries"
  } else if relative_page.has_prefix("sources/") {
    "Sources"
  } else {
    "Core Pages"
  }
}

///|
test "memory candidate section maps known page groups" {
  assert_eq(memory_candidate_section("entities/moonbook.md"), "Entities")
  assert_eq(memory_candidate_section("concepts/harness.md"), "Concepts")
  assert_eq(memory_candidate_section("queries/overview.md"), "Queries")
  assert_eq(memory_candidate_section("sources/article.md"), "Sources")
  assert_eq(memory_candidate_section("synthesis/notes.md"), "Core Pages")
}

///|
async test "catalog record defaults to book private memory scope" {
  let root = "/tmp/moonbook-bookapi-catalog"
  ignore(init_workspace(root))
  let record = catalog_record(root)
  assert_eq(record.memory_scope, "BookPrivate")
  assert_eq(record.id, "moonbook-bookapi-catalog")
}

///|
async test "catalog skills include base harness skills" {
  let root = "/tmp/moonbook-bookapi-skills"
  ignore(init_workspace(root))
  let skills = catalog_skills(root)
  assert_true(skills.contains("analysis"))
  assert_true(skills.contains("memory"))
  assert_true(skills.contains("review"))
}

///|
async test "hydrate worker context includes keeper memory slices" {
  let root = "/tmp/moonbook-bookapi-context"
  ignore(init_workspace(root))
  ignore(
    persist_result(root, {
      task_id: "task-memory",
      summary: "Observed that the user prefers concise status updates.",
      artifacts: [],
      memory_candidates: [
        {
          kind: "user_preference",
          title: "Concise status",
          detail: "The user prefers concise status updates.",
          durable: false,
          target_page: None,
        },
        {
          kind: "environment_fact",
          title: "Book scope",
          detail: "This book is used for persistent wiki experiments.",
          durable: false,
          target_page: None,
        },
      ],
      requires_review: false,
      notify_town: false,
    }),
  )
  let context = hydrate_worker_context(root, {
    id: "goal-analysis",
    title: "Analyze",
    kind: "analysis",
    prompt: "Do the work.",
    priority: 1,
    requires_review: false,
    target_pages: ["index.md"],
  })
  assert_true(context.user_memory.length() > 0)
  assert_true(context.active_memory.length() > 0)
  assert_true(context.working_memory.length() > 0)
}
