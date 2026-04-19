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
  skill_paths : Array[String]
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
  evidence_id : String
} derive(Show, ToJson, FromJson)

///|
pub struct BookStateSummary {
  book_id : String
  root : String
  page_count : Int
  source_count : Int
  source_page_count : Int
  entity_count : Int
  entity_page_count : Int
  concept_count : Int
  concept_page_count : Int
  query_note_count : Int
  pending_review_count : Int
  keeper_memory_count : Int
  keeper_working_count : Int
  evidence_count : Int
  substantive_coverage_ready : Bool
  summary : String
} derive(Show, ToJson, FromJson)

///|
pub struct BookHealthReport {
  level : String
  summary : String
  source_page_count : Int
  entity_page_count : Int
  concept_page_count : Int
  query_note_count : Int
  pending_review_count : Int
  low_confidence_claim_count : Int
  maintenance_entry_count : Int
  keeper_working_count : Int
  evidence_count : Int
  substantive_coverage_ready : Bool
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
  let weak_coverage = book_has_weak_coverage(state)
  let query_ready = book_has_query_ready_coverage(state)
  let ingest_priority = if weak_coverage { 100 } else { 70 }
  let tasks : Array[BookTask] = []
  let bootstrap_research_goal = weak_coverage && research_bootstrap_goal(goal)

  if state.pending_review_count > 0 ||
    notes.contains("review") ||
    notes.contains("approve") ||
    notes.contains("safety") {
    tasks.push({
      id: "\{normalized_goal_id}-review",
      title: "Review pending book updates",
      kind: "review",
      prompt: "Load `skills/wiki-review/SKILL.md` and inspect `wiki/reviews/pending.md` to decide what should be approved, rejected, or revised for the goal: \{goal}",
      priority: 100,
      requires_review: false,
      target_pages: [
        "reviews/pending.md", "reviews/approved.md", "synthesis/claims.md",
      ],
    })
  }

  if bootstrap_research_goal {
    for task in bootstrap_semantic_tasks(normalized_goal_id, goal) {
      tasks.push(task)
    }
  } else if weak_coverage ||
    notes.contains("research") ||
    notes.contains("ingest") ||
    notes.contains("source") ||
    notes.contains("article") ||
    notes.contains("notes") ||
    notes.contains("discover") ||
    notes.contains("populate") ||
    notes.contains("bootstrap") {
    tasks.push({
      id: "\{normalized_goal_id}-ingest-followup",
      title: if weak_coverage {
        "Bootstrap ingest and population"
      } else {
        "Prepare ingest follow-up"
      },
      kind: "ingest",
      prompt: if weak_coverage {
        "Load `skills/wiki-ingest/SKILL.md`, inspect `raw/`, `raw/bootstrap/`, `wiki/sources/`, and `wiki/synthesis/maintenance-plan.md`, then bootstrap durable book coverage for the goal. Discover or stage high-signal sources, write source packets into raw/bootstrap/, populate maintained source pages from those packets, and revise the wiki so later synthesis can cite durable pages: \{goal}"
      } else {
        "Load `skills/wiki-ingest/SKILL.md` and inspect `raw/`, `raw/bootstrap/`, and `wiki/sources/` to determine whether the goal requires new source ingestion or revision of existing source summaries: \{goal}"
      },
      priority: ingest_priority,
      requires_review: true,
      target_pages: if weak_coverage {
        [
          "../raw/README.md", "../raw/bootstrap/", "sources/", "synthesis/overview.md",
          "synthesis/maintenance-plan.md", "synthesis/evidence.md",
        ]
      } else {
        ["sources/", "synthesis/overview.md"]
      },
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
    if query_ready {
      tasks.push({
        id: "\{normalized_goal_id}-synthesis",
        title: "Update local synthesis and memory",
        kind: "synthesis",
        prompt: "Load `skills/wiki-memory/SKILL.md` and `skills/wiki-query/SKILL.md`, then use `wiki/synthesis/maintenance-plan.md`, `wiki/index.md`, and `wiki/log.md` to revise durable wiki pages for the goal: \{goal}",
        priority: 90,
        requires_review: true,
        target_pages: [
          "synthesis/overview.md", "synthesis/claims.md", "synthesis/maintenance-plan.md",
        ],
      })
    }
  }

  if health.level != "healthy" ||
    weak_coverage ||
    notes.contains("plan") ||
    notes.contains("roadmap") ||
    notes.contains("next") {
    tasks.push({
      id: "\{normalized_goal_id}-planning",
      title: "Refresh local planning surfaces",
      kind: "planning",
      prompt: "Load `RESOLVER.md` and `skills/wiki-lint/SKILL.md`, then use `wiki/synthesis/maintenance-plan.md`, `wiki/synthesis/map.md`, `wiki/synthesis/evidence.md`, and `keeper/INSIGHTS.md` to plan the next local wiki revisions for the goal: \{goal}",
      priority: 95,
      requires_review: true,
      target_pages: [
        "synthesis/maintenance-plan.md", "synthesis/map.md", "synthesis/evidence.md",
        "../keeper/INSIGHTS.md",
      ],
    })
  }

  if query_ready {
    tasks.push({
      id: "\{normalized_goal_id}-analysis",
      title: "Produce domain-local task result",
      kind: "analysis",
      prompt: "Load `skills/wiki-query/SKILL.md` and answer the goal inside this book boundary. Use the wiki pages as the durable context and do not leak into other books: \{goal}",
      priority: 80,
      requires_review: true,
      target_pages: ["index.md", "log.md", "synthesis/query-insights.md"],
    })
  }

  {
    goal_id: normalized_goal_id,
    goal,
    summary: if bootstrap_research_goal {
      "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level} bootstrap_phases=\{tasks.length()}"
    } else {
      "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level}"
    },
    tasks: dedupe_tasks(tasks),
  }
}

///|
fn research_bootstrap_goal(goal : String) -> Bool {
  let notes = goal.to_lower()
  notes.contains("research") ||
  notes.contains("ingest") ||
  notes.contains("source") ||
  notes.contains("article") ||
  notes.contains("notes") ||
  notes.contains("discover") ||
  notes.contains("populate") ||
  notes.contains("bootstrap")
}

///|
fn bootstrap_semantic_tasks(goal_id : String, goal : String) -> Array[BookTask] {
  [
    bootstrap_phase_task(
      goal_id,
      goal,
      "bootstrap_gather",
      "Gather bootstrap materials",
      100,
      "Load `skills/wiki-ingest/SKILL.md` and `skills/source-diarize/SKILL.md`. Treat bootstrap_gather as a fan-out phase, not a single sweep. Split the work into 2 to 4 bounded gather lanes such as repo-doc discovery, implementation evidence, architecture/topology notes, and cross-project linkage. Each lane must inspect only a small high-signal slice, write or contribute to concrete raw/bootstrap packets with provenance, evidence bullets, and source-path notes, and report explicit blockers when its lane is weak. Success means at least one substantive source candidate, at least one bootstrap packet, and enough gathered material for source materialization. Blockers are only scaffolding, placeholders, missing substantive source paths, or gather outputs that are still too weak to hand off.",
      [
        "../raw/README.md", "../raw/bootstrap/", "synthesis/map.md", "synthesis/maintenance-plan.md",
      ],
      true,
    ),
    bootstrap_phase_task(
      goal_id,
      goal,
      "source_materialize",
      "Materialize durable source pages",
      90,
      "Load `skills/wiki-ingest/SKILL.md`. Use the gathered bootstrap packets to create or revise durable `wiki/sources/*.md` pages and refresh index/log coverage. Success means at least one durable source page and matching index/log updates. Blockers are weak packets, placeholder sources, or no durable source material.",
      ["sources/", "index.md", "log.md"],
      true,
    ),
    bootstrap_phase_task(
      goal_id,
      goal,
      "knowledge_revise",
      "Revise knowledge surfaces",
      80,
      "Load `skills/entity-revise/SKILL.md`, `skills/concept-revise/SKILL.md`, `skills/synthesis-revise/SKILL.md`, and `skills/claim-audit/SKILL.md`. Revise entity, concept, claim, and synthesis pages using the durable source pages created in the prior phase. Success means visible ontology or synthesis updates with claims or cross-links. Blockers are missing source pages, unsupported claims, or no durable revision target.",
      [
        "entities/", "concepts/", "synthesis/overview.md", "synthesis/claims.md",
        "synthesis/map.md", "synthesis/maintenance-plan.md",
      ],
      true,
    ),
    bootstrap_phase_task(
      goal_id,
      goal,
      "review_finalize",
      "Finalize bootstrap review",
      70,
      "Load `skills/wiki-review/SKILL.md`, `skills/review-decision/SKILL.md`, and `skills/contradiction-review/SKILL.md`. Review the revised pages, classify blockers, and decide whether the bootstrap pass is ready for durable use. Success means an explicit review-ready conclusion or a structured blocker with missing material. Generic completion prose is not success.",
      [
        "reviews/pending.md", "reviews/approved.md", "history/journey.md", "history/debug-journal.md",
      ],
      true,
    ),
  ]
}

///|
fn bootstrap_phase_task(
  goal_id : String,
  goal : String,
  kind : String,
  title : String,
  priority : Int,
  prompt : String,
  target_pages : Array[String],
  requires_review : Bool,
) -> BookTask {
  {
    id: "\{goal_id}-\{kind}",
    title,
    kind,
    prompt: "\{prompt}\n\nGoal: \{goal}",
    priority,
    requires_review,
    target_pages,
  }
}

///|
pub async fn hydrate_worker_context(
  root : String,
  task : BookTask,
) -> WorkerContextBundle {
  let workspace = workspace_paths(root)
  let keeper = keeper_snapshot(root)
  let terms = query_terms(task.title + " " + task.prompt)
  let policy = policy_lines(root)
  let routines = routine_lines(root)
  let memory_summary = summarize_memory(root)
  {
    book_id: book_identity(root),
    workspace_root: workspace.root,
    task_id: task.id,
    prompt: task_prompt_with_material_hints(root, task, terms),
    policy,
    routines,
    skill_paths: resolve_skill_paths(root, task),
    context_pages: select_context_pages(root, task, terms),
    active_memory: select_memory_entries(keeper.active_memory, terms, 6),
    user_memory: select_memory_entries(keeper.user_memory, terms, 4),
    working_memory: select_memory_entries(keeper.working_memory, terms, 8),
    memory_summary,
    output_contract: provider_result_contract_lines(),
  }
}

///|
fn provider_result_contract_lines() -> Array[String] {
  [
    "Return exactly one JSON object.", "Do not output markdown fences or prose outside the JSON object.",
    "Use keys: task_id, summary, artifacts, memory_candidates, requires_review, notify_town.",
    "Set task_id to the active provider task id.", "artifacts must be an array of workspace-relative output paths.",
    "memory_candidates must be an array of objects with kind, title, detail, durable, target_page.",
    "For weak-coverage research goals, follow the MoonBook phases in order: bootstrap_gather, source_materialize, knowledge_revise, review_finalize.",
    "For bootstrap ingest, artifacts should include one or more raw/bootstrap/* packets before wiki revision claims.",
    "Use [] for empty arrays and null for missing target_page.", "For ingest or bootstrap work, generic completion text without substantive artifacts or durable candidates is a blocker, not success.",
    "If ingest work does not produce durable source/entity/concept/query updates, say what material is missing and set requires_review to true.",
  ]
}

///|
async fn task_prompt_with_material_hints(
  root : String,
  task : BookTask,
  terms : Array[String],
) -> String {
  if !bootstrap_material_task_kind(task.kind) {
    return task.prompt
  }
  let hints = bootstrap_source_hint_lines(
    root,
    terms,
    task.title + " " + task.prompt,
  )
  if hints.is_empty() {
    return task.prompt
  }
  task.prompt +
  "\n\nLocal source hints for this bootstrap pass:\n" +
  hints.join("\n") +
  "\n\nUse these paths as candidate primary materials before concluding that the book has no substantive sources."
}

///|
fn bootstrap_material_task_kind(kind : String) -> Bool {
  kind == "ingest" ||
  kind == "bootstrap_gather" ||
  kind == "source_materialize" ||
  kind == "knowledge_revise"
}

///|
async fn bootstrap_source_hint_lines(
  root : String,
  terms : Array[String],
  raw_text : String,
) -> Array[String] {
  let normalized_text = raw_text.to_lower()
  let selected_terms : Array[String] = []
  for repo in ["moontown", "moonbook", "moonclaw"] {
    if (terms.contains(repo) || normalized_text.contains(repo)) &&
      !selected_terms.contains(repo) {
      selected_terms.push(repo)
    }
  }
  if selected_terms.is_empty() {
    return []
  }
  let base = bootstrap_source_search_root(root)
  let hints : Array[String] = []
  for repo in selected_terms {
    let repo_dir = @path.Path(base).join(@path.Path(repo)).to_string()
    if !@fsx.exists(repo_dir) {
      continue
    }
    hints.push("- local repo `\{repo}`: `\{repo_dir}`")
    for candidate in bootstrap_repo_candidate_files(repo_dir) {
      hints.push("  - candidate source: `\{candidate}`")
    }
  }
  hints
}

///|
async fn bootstrap_source_search_root(root : String) -> String {
  for relative in ["..", "../..", "../../..", "../../../..", "../../../../.."] {
    let candidate = @path.Path(root)
      .join(@path.Path(relative))
      .normalize()
      .to_string()
    if @fsx.exists(
        @path.Path(candidate).join(@path.Path("moontown")).to_string(),
      ) ||
      @fsx.exists(
        @path.Path(candidate).join(@path.Path("moonclaw")).to_string(),
      ) ||
      @fsx.exists(
        @path.Path(candidate).join(@path.Path("moonbook")).to_string(),
      ) {
      return candidate
    }
  }
  let current = @env.current_dir().unwrap_or(root)
  let current_parent = @path.Path(current)
    .join(@path.Path(".."))
    .normalize()
    .to_string()
  if @fsx.exists(
      @path.Path(current_parent).join(@path.Path("moontown")).to_string(),
    ) ||
    @fsx.exists(
      @path.Path(current_parent).join(@path.Path("moonclaw")).to_string(),
    ) ||
    @fsx.exists(
      @path.Path(current_parent).join(@path.Path("moonbook")).to_string(),
    ) {
    current_parent
  } else {
    @path.Path(root).join(@path.Path("..")).normalize().to_string()
  }
}

///|
async fn bootstrap_repo_candidate_files(repo_dir : String) -> Array[String] {
  let files : Array[String] = []
  for
    relative in [
      "README.md", "README.mbt.md", "AGENTS.md", "moon.mod.json", "cmd/main/main.mbt",
    ] {
    let absolute = @path.Path(repo_dir).join(@path.Path(relative)).to_string()
    if @fsx.exists(absolute) {
      files.push(absolute)
    }
  }
  files
}

///|
pub async fn resolve_task_for_goal(
  root : String,
  goal : String,
  task_id? : String? = None,
) -> BookTask? {
  let batch = produce_task_batch(root, goal)
  match resolve_task_from_batch(batch.tasks, task_id~) {
    Some(task) => Some(task)
    None => fallback_bootstrap_task_for_goal(goal, batch.goal_id, task_id~)
  }
}

///|
fn fallback_bootstrap_task_for_goal(
  goal : String,
  goal_id : String,
  task_id? : String? = None,
) -> BookTask? {
  guard research_bootstrap_goal(goal) else { return None }
  let kind = match task_id {
    Some(task_id) => resolve_task_kind_from_external_id(task_id)
    None => None
  }
  let bootstrap_tasks = bootstrap_semantic_tasks(goal_id, goal)
  match kind {
    Some(kind) =>
      bootstrap_tasks
      .iter()
      .find_first(fn(task : BookTask) { task.kind == kind })
    None => None
  }
}

///|
pub async fn persist_result(
  root : String,
  result : BookResult,
) -> PersistResultOutcome {
  let workspace = workspace_paths(root)
  let normalized_result = reconcile_provider_result(root, workspace, result)
  let updated_pages : Array[String] = []
  let observations_relative = ensure_observations_page(workspace)
  updated_pages.push(observations_relative)
  let observations_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(observations_relative))
    .to_string()
  let mut observations = @fsx.read_file(observations_path)
  let block = persisted_result_block(normalized_result)
  observations = append_section_block(observations, "## Results", block)
  @fsx.write_to_file(observations_path, observations, create=0o644)
  let evidence_id = append_result_evidence(workspace, normalized_result)
  let evidence_relative = evidence_relative_page()
  if !updated_pages.contains(evidence_relative) {
    updated_pages.push(evidence_relative)
  }

  for page in keeper_sync_result(root, normalized_result) {
    if !updated_pages.contains(page) {
      updated_pages.push(page)
    }
  }

  for
    page in promote_durable_candidates(
      workspace,
      immediate_durable_candidates(normalized_result),
    ) {
    if !updated_pages.contains(page) {
      updated_pages.push(page)
    }
  }

  let plan_relative = ensure_maintenance_plan_entry(
    workspace,
    "Persist result: \{normalized_result.task_id}",
    "persist-result",
    "wiki/" + observations_relative,
    updated_pages,
    [
      "notify_town: \{normalized_result.notify_town}",
      "requires_review: \{normalized_result.requires_review}",
      "artifacts: \{normalized_result.artifacts.length()}",
      "evidence: \{evidence_id}",
    ],
  )
  if !updated_pages.contains(plan_relative) {
    updated_pages.push(plan_relative)
  }
  let staged = staged_durable_candidates(normalized_result)
  let review_queued = if normalized_result.requires_review || !staged.is_empty() {
    queue_result_review(
      workspace, normalized_result, observations_relative, evidence_id, staged,
    )
  } else {
    false
  }
  if review_queued && !updated_pages.contains("reviews/pending.md") {
    updated_pages.push("reviews/pending.md")
  }
  let reconciled_pages = reconcile_result_pages(
    root, workspace, normalized_result, updated_pages,
  )
  let bootstrap_cluster_complete = has_bootstrap_materialization(
    count_markdown_under(workspace.wiki_dir, "sources"),
    count_markdown_under(workspace.wiki_dir, "entities"),
    count_markdown_under(workspace.wiki_dir, "concepts"),
    count_markdown_under(workspace.wiki_dir, "queries"),
  )
  let journey_relative = append_journey_entry(
    workspace, normalized_result, evidence_id, review_queued, reconciled_pages, bootstrap_cluster_complete,
  )
  if !reconciled_pages.contains(journey_relative) {
    reconciled_pages.push(journey_relative)
  }
  let debug_journal_relative = append_debug_journal_entry(
    workspace, normalized_result, evidence_id, review_queued, reconciled_pages, bootstrap_cluster_complete,
  )
  if !reconciled_pages.contains(debug_journal_relative) {
    reconciled_pages.push(debug_journal_relative)
  }

  let insights_relative = refresh_keeper_insights(root)
  if !reconciled_pages.contains(insights_relative) {
    reconciled_pages.push(insights_relative)
  }
  let synthesis_map_relative = refresh_synthesis_map(root)
  if !reconciled_pages.contains(synthesis_map_relative) {
    reconciled_pages.push(synthesis_map_relative)
  }

  append_result_log(
    @path.Path(workspace.wiki_dir).join(@path.Path("log.md")).to_string(),
    normalized_result,
    reconciled_pages,
  )
  {
    log_path: @path.Path(workspace.wiki_dir)
    .join(@path.Path("log.md"))
    .to_string(),
    updated_pages: reconciled_pages,
    review_queued,
    notify_town: normalized_result.notify_town,
    evidence_id,
  }
}

///|
async fn reconcile_provider_result(
  root : String,
  workspace : Paths,
  result : BookResult,
) -> BookResult {
  if !result_is_empty_ingest_blocker(result) {
    return result
  }
  let source_page_count = count_markdown_under(workspace.wiki_dir, "sources")
  let entity_page_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_page_count = count_markdown_under(workspace.wiki_dir, "concepts")
  let query_note_count = count_markdown_under(workspace.wiki_dir, "queries")
  if has_bootstrap_materialization(
      source_page_count, entity_page_count, concept_page_count, query_note_count,
    ) {
    let artifacts = recent_substantive_pages(root, limit=8).map(fn(page) {
      "wiki/\{page}"
    })
    return {
      task_id: result.task_id,
      summary: "Recovered bootstrap completion from durable workspace pages despite weak provider completion text.",
      artifacts,
      memory_candidates: [],
      requires_review: false,
      notify_town: result.notify_town,
    }
  }
  {
    task_id: result.task_id,
    summary: "Blocked ingest: provider returned generic completion text without durable artifacts or memory candidates.",
    artifacts: [],
    memory_candidates: [
      {
        kind: "blocker",
        title: "Ingest provider returned an empty result",
        detail: "The provider payload for this ingest run contained no durable artifacts and no memory candidates. The next MoonClaw pass must either materialize wiki/sources, wiki/entities, wiki/concepts, or wiki/queries pages, or return an explicit blocker with the missing materials.",
        durable: false,
        target_page: None,
      },
      {
        kind: "next_step",
        title: "Review gather and revision worker outputs",
        detail: "Inspect the gather, material-prep, and revision outputs in the MoonClaw run workspace to see whether the workers produced usable materials that were lost before provider-result emission.",
        durable: false,
        target_page: None,
      },
    ],
    requires_review: true,
    notify_town: result.notify_town,
  }
}

///|
fn result_is_empty_ingest_blocker(result : BookResult) -> Bool {
  let summary = result.summary.trim().to_lower()
  let stage = infer_task_kind_from_external_id(result.task_id).unwrap_or("")
  stage == "ingest" &&
  result.artifacts.is_empty() &&
  result.memory_candidates.is_empty() &&
  (
    summary == "completed provider task bootstrap ingest and population." ||
    summary == "completed provider task." ||
    summary == "completed extension task." ||
    summary.contains("completed provider task")
  )
}

///|
async fn reconcile_result_pages(
  root : String,
  workspace : Paths,
  result : BookResult,
  updated_pages : Array[String],
) -> Array[String] {
  let reconciled : Array[String] = []
  for page in updated_pages {
    if !reconciled.contains(page) {
      reconciled.push(page)
    }
  }
  for artifact in result.artifacts {
    let relative = normalize_result_workspace_path(artifact)
    if !relative.is_empty() &&
      @fsx.exists(
        @path.Path(workspace.root).join(@path.Path(relative)).to_string(),
      ) &&
      !reconciled.contains(relative) {
      reconciled.push(relative)
    }
  }
  for candidate in result.memory_candidates {
    match candidate.target_page {
      Some(page) =>
        if !page.is_empty() &&
          @fsx.exists(
            @path.Path(workspace.wiki_dir).join(@path.Path(page)).to_string(),
          ) &&
          !reconciled.contains(page) {
          reconciled.push(page)
        }
      None => ()
    }
  }
  if result_stage_is_bootstrap_like(result) &&
    !result_has_substantive_pages(reconciled) {
    for page in recent_substantive_pages(root, limit=8) {
      if !reconciled.contains(page) {
        reconciled.push(page)
      }
    }
  }
  reconciled
}

///|
fn result_stage_is_bootstrap_like(result : BookResult) -> Bool {
  match infer_task_kind_from_external_id(result.task_id) {
    Some("ingest") => true
    _ => {
      let summary = result.summary.to_lower()
      summary.contains("bootstrap") || summary.contains("materializ")
    }
  }
}

///|
fn normalize_result_workspace_path(path : String) -> String {
  let normalized = path.trim().to_string()
  if normalized.has_prefix("wiki/") {
    normalized[5:].to_string()
  } else if normalized.has_prefix("keeper/") {
    normalized
  } else {
    normalized
  }
}

///|
fn result_has_substantive_pages(pages : Array[String]) -> Bool {
  pages.any(fn(page) {
    page.has_prefix("sources/") ||
    page.has_prefix("entities/") ||
    page.has_prefix("concepts/") ||
    page.has_prefix("queries/")
  })
}

///|
async fn recent_substantive_pages(
  root : String,
  limit? : Int = 8,
) -> Array[String] {
  let workspace = workspace_paths(root)
  let candidates : Array[(String, Int64)] = []
  for dir in ["sources", "entities", "concepts", "queries"] {
    let absolute = @path.Path(workspace.wiki_dir)
      .join(@path.Path(dir))
      .to_string()
    if !@fsx.exists(absolute) {
      continue
    }
    for path in collect_markdown_pages(absolute) {
      candidates.push(
        (
          relative_to_root(path, workspace.wiki_dir),
          @fsx.mtime(path).unwrap_or(0L),
        ),
      )
    }
  }
  for
    path in [
      @path.Path(workspace.wiki_dir)
      .join(@path.Path("synthesis/overview.md"))
      .to_string(),
      @path.Path(workspace.wiki_dir)
      .join(@path.Path("synthesis/claims.md"))
      .to_string(),
    ] {
    if @fsx.exists(path) {
      candidates.push(
        (
          relative_to_root(path, workspace.wiki_dir),
          @fsx.mtime(path).unwrap_or(0L),
        ),
      )
    }
  }
  candidates.sort_by(fn(a, b) {
    if a.1 == b.1 {
      a.0.compare(b.0)
    } else {
      b.1.compare(a.1)
    }
  })
  let selected : Array[String] = []
  for i = 0; i < candidates.length() && i < limit; i = i + 1 {
    if !selected.contains(candidates[i].0) {
      selected.push(candidates[i].0)
    }
  }
  selected
}

///|
pub async fn summarize_state(root : String) -> BookStateSummary {
  refresh_workspace_projections(root)
  let workspace = workspace_paths(root)
  let pages = collect_markdown_pages(workspace.wiki_dir)
  let pending = list_pending_reviews(root)
  let source_page_count = count_markdown_under(workspace.wiki_dir, "sources")
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
    source_count: source_page_count,
    source_page_count,
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
    summary: "pages=\{pages.length()} sources=\{source_page_count} entities=\{entity_page_count} concepts=\{concept_page_count} queries=\{query_note_count} pending_review=\{pending.length()} keeper_working=\{keeper.working_memory.length()} evidence=\{evidence_count} ready_for_synthesis=\{substantive_coverage_ready}",
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
  let source_page_count = count_markdown_under(workspace.wiki_dir, "sources")
  let entity_page_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_page_count = count_markdown_under(workspace.wiki_dir, "concepts")
  let query_note_count = count_markdown_under(workspace.wiki_dir, "queries")
  let evidence_count = count_evidence_entries(root)
  let issues = coverage_issues(
    source_page_count, entity_page_count, concept_page_count, evidence_count,
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
    summary: "sources=\{source_page_count} entities=\{entity_page_count} concepts=\{concept_page_count} queries=\{query_note_count} pending_review=\{pending.length()} low_confidence_claims=\{low_confidence} maintenance_entries=\{maintenance_entries} keeper_working=\{keeper.working_memory.length()} evidence=\{evidence_count} ready_for_synthesis=\{substantive_coverage_ready}",
    source_page_count,
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
  let evidence = count_evidence_entries(root)
  "keeper_active=\{keeper.active_memory.length()} keeper_user=\{keeper.user_memory.length()} keeper_working=\{keeper.working_memory.length()} claims=\{claims} overview_updates=\{updates} evidence=\{evidence}"
}

///|
async fn resolve_skill_paths(root : String, task : BookTask) -> Array[String] {
  let normalized = @pathx.normalize(root)
  let selected : Array[String] = []
  let candidates = task_skill_names(task)
  for name in candidates {
    let path = @path.Path(normalized)
      .join(@path.Path("skills/\{name}/SKILL.md"))
      .to_string()
    if @fsx.exists(path) {
      selected.push(relative_to_root(path, normalized))
    }
  }
  let resolver = @path.Path(normalized)
    .join(@path.Path("RESOLVER.md"))
    .to_string()
  if @fsx.exists(resolver) {
    selected.push(relative_to_root(resolver, normalized))
  }
  selected
}

///|
fn task_skill_names(task : BookTask) -> Array[String] {
  let names : Array[String] = []
  let kinds = [task.kind]
  for kind in kinds {
    match kind {
      "ingest" => {
        names.push("wiki-ingest")
        names.push("source-diarize")
        names.push("entity-revise")
        names.push("concept-revise")
        names.push("synthesis-revise")
        names.push("claim-audit")
        names.push("index-maintain")
        names.push("wiki-memory")
      }
      "bootstrap_gather" => {
        names.push("wiki-ingest")
        names.push("source-diarize")
        names.push("index-maintain")
      }
      "source_materialize" => {
        names.push("wiki-ingest")
        names.push("source-diarize")
        names.push("entity-revise")
        names.push("concept-revise")
        names.push("claim-audit")
        names.push("index-maintain")
      }
      "knowledge_revise" => {
        names.push("entity-revise")
        names.push("concept-revise")
        names.push("synthesis-revise")
        names.push("claim-audit")
        names.push("contradiction-review")
        names.push("index-maintain")
      }
      "review_finalize" => {
        names.push("wiki-review")
        names.push("review-decision")
        names.push("contradiction-review")
        names.push("claim-audit")
        names.push("memory-prune")
      }
      "review" => {
        names.push("wiki-review")
        names.push("review-decision")
        names.push("contradiction-review")
        names.push("claim-audit")
      }
      "planning" => {
        names.push("wiki-lint")
        names.push("contradiction-review")
        names.push("index-maintain")
        names.push("memory-prune")
      }
      "synthesis" => {
        names.push("wiki-memory")
        names.push("wiki-query")
        names.push("synthesis-revise")
        names.push("query-promote")
        names.push("memory-prune")
      }
      _ => {
        names.push("wiki-query")
        names.push("query-promote")
        names.push("claim-audit")
        if task.prompt.to_lower().contains("course") ||
          task.prompt.to_lower().contains("teach") ||
          task.prompt.to_lower().contains("walkthrough") {
          names.push("wiki-course")
        }
      }
    }
  }
  names
}

///|
async fn skill_markdown_paths(root : String) -> Array[String] {
  let dir = @path.Path(@pathx.normalize(root))
    .join(@path.Path("skills"))
    .to_string()
  let paths : Array[String] = []
  if !@fsx.exists(dir) {
    return paths
  }
  for child in @fsx.list_directory(dir) {
    let candidate = @path.Path(dir)
      .join(@path.Path(child))
      .join(@path.Path("SKILL.md"))
      .to_string()
    if @fsx.exists(candidate) {
      paths.push(candidate)
    }
  }
  paths.sort()
  paths
}

///|
fn parse_skill_name(content : String, fallback : String) -> String {
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix("name:") {
      return line.strip_prefix("name:").unwrap_or(line).trim().to_string()
    }
  }
  fallback
}

///|
fn skill_name_from_path(path : String) -> String {
  let normalized = @pathx.normalize(path)
  if normalized.contains("/skills/wiki-ingest/") {
    "wiki-ingest"
  } else if normalized.contains("/skills/wiki-query/") {
    "wiki-query"
  } else if normalized.contains("/skills/wiki-lint/") {
    "wiki-lint"
  } else if normalized.contains("/skills/wiki-review/") {
    "wiki-review"
  } else if normalized.contains("/skills/wiki-memory/") {
    "wiki-memory"
  } else if normalized.contains("/skills/wiki-course/") {
    "wiki-course"
  } else if normalized.contains("/skills/source-diarize/") {
    "source-diarize"
  } else if normalized.contains("/skills/entity-revise/") {
    "entity-revise"
  } else if normalized.contains("/skills/concept-revise/") {
    "concept-revise"
  } else if normalized.contains("/skills/synthesis-revise/") {
    "synthesis-revise"
  } else if normalized.contains("/skills/claim-audit/") {
    "claim-audit"
  } else if normalized.contains("/skills/contradiction-review/") {
    "contradiction-review"
  } else if normalized.contains("/skills/index-maintain/") {
    "index-maintain"
  } else if normalized.contains("/skills/query-promote/") {
    "query-promote"
  } else if normalized.contains("/skills/memory-prune/") {
    "memory-prune"
  } else if normalized.contains("/skills/review-decision/") {
    "review-decision"
  } else {
    @path.Path(normalized).basename().to_string()
  }
}

///|
fn default_context_pages(target_pages : Array[String]) -> Array[String] {
  let pages : Array[String] = [
    "index.md", "log.md", "synthesis/overview.md", "synthesis/claims.md", "synthesis/map.md",
    "synthesis/evidence.md", "history/journey.md", "history/debug-journal.md",
  ]
  for page in target_pages {
    if !pages.contains(page) {
      pages.push(page)
    }
  }
  pages
}

///|
async fn select_context_pages(
  root : String,
  task : BookTask,
  terms : Array[String],
) -> Array[String] {
  let workspace = workspace_paths(root)
  let selected = default_context_pages(task.target_pages)
  if terms.is_empty() {
    return selected
  }
  let pages = collect_markdown_pages(workspace.wiki_dir)
  let ranked : Array[(String, Int)] = []
  for path in pages {
    let relative = relative_to_root(path, workspace.root)
      .strip_prefix("wiki/")
      .unwrap_or(relative_to_root(path, workspace.root))
      .to_string()
    if selected.contains(relative) {
      continue
    }
    let content = @fsx.read_file(path)
    let score = relevance_score(
      detect_page_title(path, content),
      content,
      terms,
    )
    if score > 0 {
      ranked.push((relative, score))
    }
  }
  ranked.sort_by(fn(a, b) {
    if a.1 == b.1 {
      a.0.compare(b.0)
    } else {
      b.1.compare(a.1)
    }
  })
  for i = 0; i < ranked.length() && selected.length() < 8; i = i + 1 {
    selected.push(ranked[i].0)
  }
  selected
}

///|
fn select_memory_entries(
  entries : Array[String],
  terms : Array[String],
  limit : Int,
) -> Array[String] {
  let selected : Array[String] = []
  if entries.is_empty() {
    return selected
  }
  let ranked : Array[(String, Int)] = []
  for entry in entries {
    ranked.push((entry, memory_entry_score(entry, terms)))
  }
  ranked.sort_by(fn(a, b) {
    if a.1 == b.1 {
      a.0.compare(b.0)
    } else {
      b.1.compare(a.1)
    }
  })
  for i = 0; i < ranked.length() && selected.length() < limit; i = i + 1 {
    if ranked[i].1 > 0 || i == 0 {
      selected.push(ranked[i].0)
    }
  }
  selected
}

///|
fn memory_entry_score(entry : String, terms : Array[String]) -> Int {
  let lowered = entry.to_lower()
  let mut score = 0
  for term in terms {
    if lowered.contains(term) {
      score += 3
    }
  }
  score
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
  evidence_id : String,
  durable_candidates : Array[MemoryCandidate],
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
    "- Evidence ID: `\{evidence_id}`\n" +
    "- Merge policy: `promote-durable`\n" +
    "- Status: `pending`\n" +
    "- Reason: persisted worker result requires promotion review\n" +
    "- Candidate insight: \{clamp_excerpt(result.summary)}\n" +
    format_review_candidate_lines(durable_candidates) +
    "\n"
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
fn immediate_durable_candidates(result : BookResult) -> Array[MemoryCandidate] {
  let selected : Array[MemoryCandidate] = []
  for candidate in result.memory_candidates {
    if candidate.durable && !result.requires_review {
      selected.push(candidate)
    }
  }
  selected
}

///|
fn staged_durable_candidates(result : BookResult) -> Array[MemoryCandidate] {
  let selected : Array[MemoryCandidate] = []
  for candidate in result.memory_candidates {
    if candidate.durable && result.requires_review {
      selected.push(candidate)
    }
  }
  selected
}

///|
async fn promote_durable_candidates(
  workspace : Paths,
  candidates : Array[MemoryCandidate],
) -> Array[String] {
  let updated_pages : Array[String] = []
  for candidate in candidates {
    let relative_page = match candidate.target_page {
      Some(page) => page
      None => "synthesis/observations.md"
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
    }
    let current = @fsx.read_file(absolute)
    let next = upsert_durable_candidate_block(current, candidate)
    @fsx.write_to_file(absolute, next, create=0o644)
    if !updated_pages.contains(relative_page) {
      updated_pages.push(relative_page)
    }
  }
  updated_pages
}

///|
fn upsert_durable_candidate_block(
  content : String,
  candidate : MemoryCandidate,
) -> String {
  let header = "### \{candidate.title}"
  let block = "### \{candidate.title}\n\n- Kind: `\{candidate.kind}`\n- Detail: \{candidate.detail}\n"
  if !content.contains(header) {
    return append_section_block(content, "## Durable Memory", block)
  }
  let with_kind = replace_durable_candidate_field(
    content,
    header,
    "- Kind: `",
    candidate.kind,
  )
  replace_durable_candidate_field(
    with_kind,
    header,
    "- Detail: ",
    candidate.detail,
    quoted=false,
  )
}

///|
fn replace_durable_candidate_field(
  content : String,
  header : String,
  prefix : String,
  value : String,
  quoted? : Bool = true,
) -> String {
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let mut in_block = false
  for line in lines {
    if line == header {
      in_block = true
      rebuilt.push(line)
      continue
    }
    if in_block && line.has_prefix("### ") {
      in_block = false
    }
    if in_block && line.has_prefix(prefix) {
      rebuilt.push(if quoted { prefix + value + "`" } else { prefix + value })
    } else {
      rebuilt.push(line)
    }
  }
  rebuilt.join("\n")
}

///|
fn format_review_candidate_lines(candidates : Array[MemoryCandidate]) -> String {
  if candidates.is_empty() {
    ""
  } else {
    let builder = StringBuilder::new()
    builder.write_string("- Durable candidates:\n")
    for candidate in candidates {
      let target = candidate.target_page.unwrap_or("")
      builder.write_string(
        "  - \{candidate.title} | \{candidate.kind} | \{target} | \{candidate.detail}\n",
      )
    }
    builder.to_string()
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
  source_page_count : Int,
  entity_page_count : Int,
  concept_page_count : Int,
  evidence_count : Int,
) -> Array[String] {
  let issues : Array[String] = []
  if source_page_count == 0 {
    issues.push("no durable sources have been ingested yet")
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
  source_page_count : Int,
  entity_page_count : Int,
  concept_page_count : Int,
  evidence_count : Int,
) -> Bool {
  source_page_count > 0 &&
  (entity_page_count > 0 || concept_page_count > 0) &&
  evidence_count > 0
}

///|
fn has_bootstrap_materialization(
  source_page_count : Int,
  entity_page_count : Int,
  concept_page_count : Int,
  query_note_count : Int,
) -> Bool {
  source_page_count > 0 &&
  (entity_page_count > 0 || concept_page_count > 0 || query_note_count > 0)
}

///|
async fn refresh_workspace_projections(root : String) -> Unit {
  let workspace = workspace_paths(root)
  let source_page_count = count_markdown_under(workspace.wiki_dir, "sources")
  let entity_page_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_page_count = count_markdown_under(workspace.wiki_dir, "concepts")
  let query_note_count = count_markdown_under(workspace.wiki_dir, "queries")
  let bootstrap_complete = has_bootstrap_materialization(
    source_page_count, entity_page_count, concept_page_count, query_note_count,
  )
  ignore(ensure_journey_page(workspace))
  ignore(ensure_debug_journal_page(workspace))
  ignore(refresh_keeper_insights(root))
  ignore(refresh_synthesis_map(root))
  if !bootstrap_complete {
    return
  }
  let substantive_pages = recent_substantive_pages(root, limit=8)
  let synthetic = workspace_projection_reconcile_result()
  let review_queued = !list_pending_reviews(root).is_empty()
  let journey_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(journey_relative_page()))
    .to_string()
  if file_needs_projection_reconcile(journey_path) {
    ignore(
      append_journey_entry(
        workspace, synthetic, "workspace-inventory", review_queued, substantive_pages,
        true,
      ),
    )
  }
  let debug_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(debug_journal_relative_page()))
    .to_string()
  if file_needs_projection_reconcile(debug_path) {
    ignore(
      append_debug_journal_entry(
        workspace, synthetic, "workspace-inventory", review_queued, substantive_pages,
        true,
      ),
    )
  }
}

///|
fn workspace_projection_reconcile_result() -> BookResult {
  {
    task_id: "workspace-bootstrap-ingest-followup",
    summary: "Recovered bootstrap completion from durable workspace pages after runtime bookkeeping did not close the loop cleanly.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  }
}

///|
async fn file_needs_projection_reconcile(path : String) -> Bool {
  if !@fsx.exists(path) {
    true
  } else {
    let content = @fsx.read_file(path)
    content.contains("_None yet._")
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
fn resolve_task_from_batch(
  tasks : Array[BookTask],
  task_id? : String? = None,
) -> BookTask? {
  match task_id {
    Some(task_id) => {
      let exact = tasks
        .iter()
        .find_first(fn(task : BookTask) { task.id == task_id })
      match exact {
        Some(task) => Some(task)
        None =>
          match resolve_task_kind_from_external_id(task_id) {
            Some(kind) =>
              tasks.iter().find_first(fn(task : BookTask) { task.kind == kind })
            None => None
          }
      }
    }
    None => if tasks.is_empty() { None } else { Some(tasks[0]) }
  }
}

///|
fn infer_task_kind_from_external_id(task_id : String) -> String? {
  let normalized = task_id.trim().to_lower()
  if normalized.contains("bootstrap") || normalized.contains("ingest") {
    Some("ingest")
  } else if normalized.contains("review") {
    Some("review")
  } else if normalized.contains("plan") || normalized.contains("planning") {
    Some("planning")
  } else if normalized.contains("synthesis") {
    Some("synthesis")
  } else if normalized.contains("analysis") || normalized.contains("query") {
    Some("analysis")
  } else {
    None
  }
}

///|
fn resolve_task_kind_from_external_id(task_id : String) -> String? {
  let normalized = task_id.trim().to_lower()
  if normalized.contains("bootstrap") || normalized.contains("ingest") {
    Some("bootstrap_gather")
  } else if normalized.contains("material") ||
    normalized.contains("populate") ||
    normalized.contains("source") {
    Some("source_materialize")
  } else if normalized.contains("revise") || normalized.contains("synthesis") {
    Some("knowledge_revise")
  } else if normalized.contains("finalize") {
    Some("review_finalize")
  } else if normalized.contains("review") {
    Some("review")
  } else if normalized.contains("plan") || normalized.contains("planning") {
    Some("planning")
  } else if normalized.contains("analysis") || normalized.contains("query") {
    Some("analysis")
  } else {
    None
  }
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
async test "bootstrap repo candidate files prefers primary repo documents" {
  let root = "/tmp/moonbook-bootstrap-candidates"
  ignore(@fsx.make_directory(root, recursive=true, exists_ok=true))
  let readme = root + "/README.md"
  let mod = root + "/moon.mod.json"
  ignore(@fsx.write_to_file(readme, "# Demo\n", create=0o644))
  ignore(@fsx.write_to_file(mod, "{ }\n", create=0o644))
  let files = bootstrap_repo_candidate_files(root)
  assert_true(files.contains(readme))
  assert_true(files.contains(mod))
}

///|
async test "task prompt adds local source hints for ingest work" {
  let workspace_parent = "/tmp/moonbook-prompt-hints"
  let book_root = workspace_parent + "/book"
  let moontown = workspace_parent + "/moontown"
  ignore(@fsx.make_directory(book_root, recursive=true, exists_ok=true))
  ignore(@fsx.make_directory(moontown, recursive=true, exists_ok=true))
  ignore(
    @fsx.write_to_file(moontown + "/README.md", "# Moontown\n", create=0o644),
  )
  let task : BookTask = {
    id: "goal-research-ingest",
    title: "Bootstrap ingest and population",
    kind: "ingest",
    prompt: "Inspect sources.",
    priority: 100,
    requires_review: true,
    target_pages: [],
  }
  let prompt = task_prompt_with_material_hints(book_root, task, [
    "research", "moontown",
  ])
  assert_true(prompt.contains("Local source hints for this bootstrap pass"))
  assert_true(prompt.contains("/tmp/moonbook-prompt-hints/moontown"))
  assert_true(prompt.contains("README.md"))
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
  assert_true(skills.contains("wiki-ingest"))
  assert_true(skills.contains("wiki-query"))
  assert_true(skills.contains("wiki-review"))
  assert_true(skills.contains("source-diarize"))
  assert_true(skills.contains("query-promote"))
  assert_true(skills.contains("review-decision"))
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
  assert_true(context.skill_paths.contains("skills/wiki-query/SKILL.md"))
  assert_true(context.skill_paths.contains("skills/query-promote/SKILL.md"))
  assert_true(context.skill_paths.contains("RESOLVER.md"))
}

///|
async test "persist result appends compact journey entry" {
  let root = "/tmp/moonbook-bookapi-journey"
  ignore(init_workspace(root))
  ignore(
    persist_result(root, {
      task_id: "goal-research-moontown-ingest-followup",
      summary: "Populated durable source coverage and staged review for one promoted finding.",
      artifacts: ["wiki/sources/moontown.md"],
      memory_candidates: [],
      requires_review: true,
      notify_town: false,
    }),
  )
  let journey = @fsx.read_file(root + "/wiki/history/journey.md")
  assert_true(journey.contains("### goal-research-moontown"))
  assert_true(journey.contains("- Stage: `bootstrap`"))
  assert_true(
    journey.contains("- Latest task: `goal-research-moontown-ingest-followup`"),
  )
  assert_true(journey.contains("- Status: `pending-review`"))
}

///|
async test "persist result appends detailed debug journal entry" {
  let root = "/tmp/moonbook-bookapi-debug-journal"
  ignore(init_workspace(root))
  ignore(
    persist_result(root, {
      task_id: "goal-research-moontown-ingest-followup",
      summary: "Completed provider task Bootstrap ingest and population.",
      artifacts: [],
      memory_candidates: [],
      requires_review: false,
      notify_town: false,
    }),
  )
  let journal = @fsx.read_file(root + "/wiki/history/debug-journal.md")
  assert_true(journal.contains("### goal-research-moontown"))
  assert_true(
    journal.contains("- Latest task: `goal-research-moontown-ingest-followup`"),
  )
  assert_true(journal.contains("- Result class: `administrative`"))
  assert_true(journal.contains("no durable artifact paths were reported"))
  assert_true(journal.contains("Ingest provider returned an empty result"))
}

///|
async test "persist result reconciles substantive bootstrap pages from workspace" {
  let root = "/tmp/moonbook-bookapi-reconcile-bootstrap"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/wiki/sources/demo.md",
      "# Demo Source\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/entities/moonbook.md",
      "# MoonBook\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/concepts/provider-backed-execution.md",
      "# Provider-backed execution\n",
      create=0o644,
    ),
  )
  ignore(
    persist_result(root, {
      task_id: "goal-research-moontown-ingest-followup",
      summary: "Completed provider task Bootstrap ingest and population.",
      artifacts: [],
      memory_candidates: [],
      requires_review: false,
      notify_town: false,
    }),
  )
  let journey = @fsx.read_file(root + "/wiki/history/journey.md")
  let journal = @fsx.read_file(root + "/wiki/history/debug-journal.md")
  assert_true(journey.contains("- Status: `bootstrap-complete`"))
  assert_true(journal.contains("- Result class: `substantive`"))
  assert_true(journal.contains("wiki/sources/demo.md"))
  assert_true(
    journal.contains(
      "Recovered bootstrap completion from durable workspace pages despite weak provider completion text.",
    ),
  )
}

///|
async test "summarize state backfills projection pages from durable workspace state" {
  let root = "/tmp/moonbook-bookapi-projection-reconcile"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/wiki/sources/demo.md",
      "# Demo Source\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/entities/moonbook.md",
      "# MoonBook\n",
      create=0o644,
    ),
  )
  let summary = summarize_state(root)
  inspect(summary.substantive_coverage_ready, content="false")
  let journey = @fsx.read_file(root + "/wiki/history/journey.md")
  let journal = @fsx.read_file(root + "/wiki/history/debug-journal.md")
  let map = @fsx.read_file(root + "/wiki/synthesis/map.md")
  assert_true(
    journey.contains(
      "Recovered bootstrap completion from durable workspace pages after runtime bookkeeping did not close the loop cleanly.",
    ),
  )
  assert_true(journal.contains("- Result class: `substantive`"))
  assert_true(map.contains("- Bootstrap outcome: `complete`"))
}

///|
async test "reconcile provider result converts empty ingest completion into blocker" {
  let root = "/tmp/moonbook-bookapi-normalize-blocker"
  ignore(init_workspace(root))
  let normalized = reconcile_provider_result(root, workspace_paths(root), {
    task_id: "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
    summary: "Completed provider task Bootstrap ingest and population.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  })
  assert_eq(
    normalized.summary,
    "Blocked ingest: provider returned generic completion text without durable artifacts or memory candidates.",
  )
  assert_true(normalized.requires_review)
  assert_eq(normalized.memory_candidates.length(), 2)
  assert_eq(normalized.memory_candidates[0].kind, "blocker")
}

///|
async test "reconcile provider result prefers durable workspace pages over weak provider completion text" {
  let root = "/tmp/moonbook-bookapi-normalize-recovered"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/wiki/sources/demo.md",
      "# Demo Source\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/entities/moonbook.md",
      "# MoonBook\n",
      create=0o644,
    ),
  )
  let normalized = reconcile_provider_result(root, workspace_paths(root), {
    task_id: "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
    summary: "Completed provider task Bootstrap ingest and population.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  })
  assert_eq(
    normalized.summary,
    "Recovered bootstrap completion from durable workspace pages despite weak provider completion text.",
  )
  assert_true(!normalized.requires_review)
  assert_true(!normalized.artifacts.is_empty())
}

///|
async test "produce task batch bootstraps research goals on weak coverage" {
  let root = "/tmp/moonbook-bookapi-bootstrap"
  ignore(init_workspace(root))
  let batch = produce_task_batch(
    root, "research moontown, moonbook and moonclaw",
  )
  assert_true(batch.summary.contains("bootstrap_phases"))
  assert_true(batch.tasks.any(fn(task) { task.kind == "bootstrap_gather" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "source_materialize" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "knowledge_revise" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "review_finalize" }))
  assert_true(!batch.tasks.any(fn(task) { task.kind == "ingest" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "planning" }))
  assert_true(
    !batch.tasks.any(fn(task) {
      task.kind == "analysis" || task.kind == "synthesis"
    }),
  )
  let gather = batch.tasks
    .iter()
    .find_first(fn(task : BookTask) { task.kind == "bootstrap_gather" })
    .unwrap()
  assert_true(gather.prompt.contains("Success means"))
  assert_true(gather.prompt.contains("Blockers"))
  assert_true(gather.prompt.contains("fan-out phase"))
  assert_true(gather.prompt.contains("2 to 4 bounded gather lanes"))
  assert_true(gather.target_pages.contains("synthesis/map.md"))
  let materialize = batch.tasks
    .iter()
    .find_first(fn(task : BookTask) { task.kind == "source_materialize" })
    .unwrap()
  assert_true(materialize.prompt.contains("wiki/sources"))
  assert_true(materialize.target_pages.contains("index.md"))
}

///|
async test "produce task batch allows synthesis after durable coverage exists" {
  let root = "/tmp/moonbook-bookapi-query-ready"
  ignore(init_workspace(root))
  ignore(ingest_source(root, root + "/raw/README.md"))
  ignore(
    persist_result(root, {
      task_id: "task-evidence",
      summary: "Validated durable wiki support records.",
      artifacts: [],
      memory_candidates: [
        {
          kind: "fact",
          title: "Moontown",
          detail: "Moontown orchestrates town-level work.",
          durable: true,
          target_page: Some("entities/moontown.md"),
        },
        {
          kind: "fact",
          title: "Orchestration",
          detail: "Town orchestration is a recurring concept in this book.",
          durable: true,
          target_page: Some("concepts/orchestration.md"),
        },
      ],
      requires_review: false,
      notify_town: false,
    }),
  )
  let batch = produce_task_batch(root, "refresh synthesis for current research")
  assert_true(batch.tasks.any(fn(task) { task.kind == "analysis" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "synthesis" }))
}

///|
async test "resolve task for goal accepts external bootstrap task ids" {
  let root = "/tmp/moonbook-bookapi-external-task"
  ignore(init_workspace(root))
  let task = resolve_task_for_goal(
    root,
    "research moontown, moonbook and moonclaw",
    task_id=Some("goal-coding-research-bootstrap-ingest"),
  ).unwrap()
  assert_eq(task.kind, "bootstrap_gather")
}

///|
async test "resolve task for goal recovers bootstrap semantic task after coverage exists" {
  let root = "/tmp/moonbook-bookapi-bootstrap-fallback"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/wiki/sources/demo.md",
      "# Demo Source\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/entities/demo.md",
      "# Demo Entity\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/concepts/demo.md",
      "# Demo Concept\n",
      create=0o644,
    ),
  )
  ignore(
    @fsx.write_to_file(
      root + "/wiki/synthesis/evidence.md",
      "# Evidence\n\n## Results\n\n- seeded\n",
      create=0o644,
    ),
  )
  let task = resolve_task_for_goal(
    root,
    "research moontown, moonbook and moonclaw",
    task_id=Some(
      "goal-research-moontown-moonbook-and-moonclaw-bootstrap_gather",
    ),
  ).unwrap()
  assert_eq(task.kind, "bootstrap_gather")
}
