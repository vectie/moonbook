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
  // Older workspaces may predate newer required pages such as wiki/history.
  // Re-running init is idempotent and repairs the contract before planning.
  ignore(init_workspace(root))
  let workspace = workspace_paths(root)
  let state = summarize_state(root)
  let health = report_health(root)
  let normalized_goal_id = goal_id.unwrap_or("goal-\{slugify_title(goal)}")
  let notes = goal.to_lower()
  let weak_coverage = book_has_weak_coverage(state)
  let query_ready = book_has_query_ready_coverage(state)
  let ingest_priority = if weak_coverage { 100 } else { 70 }
  let tasks : Array[BookTask] = []
  let course_requested = course_goal(goal)
  let planbook_requested = planbook_goal(goal)
  let document_reverse_requested = document_reverse_engineer_goal(goal)
  let bootstrap_research_goal = weak_coverage &&
    !course_requested &&
    !planbook_requested &&
    !document_reverse_requested &&
    research_bootstrap_goal(goal)

  if standing_watch_goal(goal) {
    tasks.push(standing_watch_task(normalized_goal_id, goal))
    return {
      goal_id: normalized_goal_id,
      goal,
      summary: "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level} standing_watch=1",
      tasks: dedupe_tasks(tasks),
    }
  }

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

  if planbook_requested {
    for task in planbook_semantic_tasks(normalized_goal_id, goal) {
      tasks.push(task)
    }
  } else if document_reverse_requested {
    for task in document_reverse_engineer_tasks(normalized_goal_id, goal) {
      tasks.push(task)
    }
  } else if course_requested {
    for task in course_semantic_tasks(normalized_goal_id, goal) {
      tasks.push(task)
    }
  } else if bootstrap_research_goal {
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
        "Load `skills/wiki-ingest/SKILL.md` and `skills/research-report/SKILL.md`, inspect `raw/`, `raw/bootstrap/`, `wiki/sources/`, and `wiki/synthesis/maintenance-plan.md`, then bootstrap durable book coverage for the goal. Discover or stage high-signal sources, write source packets into raw/bootstrap/, write a Kimi-quality long-form `raw/bootstrap/deep-report.md`, populate maintained source pages from those packets, and revise the wiki so later synthesis can cite durable pages: \{goal}"
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

  let maintenance_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("synthesis/maintenance-plan.md"))
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

  if !planbook_requested &&
    !document_reverse_requested &&
    (
      health.level != "healthy" ||
      weak_coverage ||
      notes.contains("plan") ||
      notes.contains("roadmap") ||
      notes.contains("next")
    ) {
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
      title: "Produce domain-local worker result",
      kind: "analysis",
      prompt: "Load `skills/wiki-query/SKILL.md` and answer the goal inside this extension boundary. Use the wiki pages as the durable context and do not leak into other books: \{goal}",
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
    } else if planbook_requested {
      "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level} planbook_phases=\{tasks.length()}"
    } else if document_reverse_requested {
      "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level} document_reverse_phases=\{tasks.length()}"
    } else if course_requested {
      "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level} course_phases=\{tasks.length()}"
    } else {
      "book=\{state.book_id} pages=\{state.page_count} pending_review=\{state.pending_review_count} health=\{health.level}"
    },
    tasks: dedupe_tasks(tasks),
  }
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
    None =>
      match
        fallback_standing_watch_task_for_goal(goal, batch.goal_id, task_id~) {
        Some(task) => Some(task)
        None => fallback_bootstrap_task_for_goal(goal, batch.goal_id, task_id~)
      }
  }
}

///|
fn fallback_standing_watch_task_for_goal(
  goal : String,
  goal_id : String,
  task_id? : String? = None,
) -> BookTask? {
  match task_id {
    Some(task_id) =>
      if external_standing_watch_task_id(task_id) {
        Some(standing_watch_task_with_id(task_id, goal))
      } else if standing_watch_goal(goal) {
        Some(standing_watch_task(goal_id, goal))
      } else {
        None
      }
    None =>
      if standing_watch_goal(goal) {
        Some(standing_watch_task(goal_id, goal))
      } else {
        None
      }
  }
}

///|
fn fallback_bootstrap_task_for_goal(
  goal : String,
  goal_id : String,
  task_id? : String? = None,
) -> BookTask? {
  if course_goal(goal) {
    let kind = match task_id {
      Some(task_id) => resolve_task_kind_from_external_id(task_id)
      None => None
    }
    let course_tasks = course_semantic_tasks(goal_id, goal)
    match kind {
      Some(kind) =>
        course_tasks
        .iter()
        .find_first(fn(task : BookTask) { task.kind == kind })
      None => None
    }
  } else if document_reverse_engineer_goal(goal) {
    let kind = match task_id {
      Some(task_id) => resolve_task_kind_from_external_id(task_id)
      None => None
    }
    let reverse_tasks = document_reverse_engineer_tasks(goal_id, goal)
    match kind {
      Some(kind) =>
        reverse_tasks
        .iter()
        .find_first(fn(task : BookTask) { task.kind == kind })
      None =>
        if reverse_tasks.is_empty() {
          None
        } else {
          Some(reverse_tasks[0])
        }
    }
  } else {
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
}

///|
pub async fn persist_result(
  root : String,
  result : BookResult,
  lifecycle_proof? : ExecutableBookLifecycleProof? = None,
) -> PersistResultOutcome {
  let workspace = workspace_paths(root)
  let provider_result = reconcile_provider_result(root, workspace, result)
  let normalized_result = materialize_research_envelope_result(
    root, workspace, provider_result,
  )
  let updated_pages : Array[String] = []
  let observations_relative = ensure_observations_page(workspace)
  updated_pages.push(observations_relative)
  let observations_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(observations_relative))
    .to_string()
  let mut observations = @fsx.read_file(observations_path)
  let block = persisted_result_block(normalized_result)
  observations = append_section_block(observations, "## Results", block)
  @fsx.write_to_file(observations_path, observations, create=0o644)
  if result_is_standing_watch(normalized_result) {
    let watch_relative = append_standing_watch_history(
      workspace, normalized_result,
    )
    if !updated_pages.contains(watch_relative) {
      updated_pages.push(watch_relative)
    }
  }
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
    "Persist result: \{normalized_result.result_id}",
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
  let source_coverage = summarize_source_coverage(workspace.wiki_dir)
  let bootstrap_cluster_complete = has_bootstrap_materialization(
    source_coverage.verified_count,
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
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("log.md"))
    .to_string(),
    normalized_result,
    reconciled_pages,
  )
  let review_path = if review_queued {
    Some("wiki/reviews/pending.md")
  } else {
    None
  }
  let executable_event = normalized_result.to_executable_book_event(
    book_id=book_identity(root),
    evidence_id=Some(evidence_id),
    review_path~,
    lifecycle_proof~,
  )
  let (executable_event_path, latest_executable_event_path) = write_executable_book_event(
    workspace, executable_event,
  )
  {
    log_path: moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("log.md"))
    .to_string(),
    updated_pages: reconciled_pages,
    review_queued,
    notify_town: normalized_result.notify_town,
    evidence_id,
    executable_event_path,
    latest_executable_event_path,
    executable_event,
  }
}

///|
async fn write_executable_book_event(
  workspace : Paths,
  event : ExecutableBookEvent,
) -> (String, String) {
  let events_dir = moonbook_wiki_path(workspace.root)
    .join(moonbook_wiki_path(".moonbook/events"))
    .to_string()
  @fsx.make_directory(events_dir, recursive=true, exists_ok=true)
  let event_path = moonbook_wiki_path(events_dir)
    .join(moonbook_wiki_path("\{slugify_title(event.id)}.json"))
    .to_string()
  let latest_path = moonbook_wiki_path(events_dir)
    .join(moonbook_wiki_path("latest.json"))
    .to_string()
  let json = event.to_json().stringify(indent=2)
  @fsx.write_to_file(event_path, json, create=0o644)
  @fsx.write_to_file(
    latest_path,
    event.to_json().stringify(indent=2),
    create=0o644,
  )
  (
    relative_to_root(event_path, workspace.root),
    relative_to_root(latest_path, workspace.root),
  )
}

///|
async fn reconcile_provider_result(
  root : String,
  workspace : Paths,
  result : BookResult,
) -> BookResult {
  if result_stage_is_bootstrap_like(result) &&
    research_artifact_contract_active(root) {
    let missing = missing_research_artifacts(root)
    if !missing.is_empty() {
      return research_artifact_blocker_result(result, missing)
    }
    if result_is_empty_ingest_blocker(result) {
      return {
        result_id: result.result_id,
        summary: "Recovered research envelope completion from required raw artifacts written by the worker.",
        artifacts: required_research_artifacts(),
        memory_candidates: [],
        requires_review: false,
        notify_town: result.notify_town,
      }
    }
  }
  if !result_is_empty_ingest_blocker(result) {
    return result
  }
  let source_coverage = summarize_source_coverage(workspace.wiki_dir)
  let source_page_count = source_coverage.verified_count
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
      result_id: result.result_id,
      summary: "Recovered bootstrap completion from durable workspace pages despite weak provider completion text.",
      artifacts,
      memory_candidates: [],
      requires_review: false,
      notify_town: result.notify_town,
    }
  }
  {
    result_id: result.result_id,
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
async fn materialize_research_envelope_result(
  root : String,
  workspace : Paths,
  result : BookResult,
) -> BookResult {
  if !result_stage_is_bootstrap_like(result) ||
    !research_artifact_contract_active(root) ||
    !missing_research_artifacts(root).is_empty() {
    return result
  }
  let pages = materialize_research_envelope_pages(root, workspace, result)
  if pages.is_empty() {
    return result
  }
  let artifacts : Array[String] = []
  for artifact in result.artifacts {
    if !artifacts.contains(artifact) {
      artifacts.push(artifact)
    }
  }
  for page in pages {
    let artifact = "wiki/\{page}"
    if !artifacts.contains(artifact) {
      artifacts.push(artifact)
    }
  }
  {
    result_id: result.result_id,
    summary: "MoonBook materialized durable wiki pages from the raw research artifact envelope. " +
    result.summary,
    artifacts,
    memory_candidates: result.memory_candidates,
    requires_review: result.requires_review,
    notify_town: result.notify_town,
  }
}

///|
async fn materialize_research_envelope_pages(
  root : String,
  workspace : Paths,
  result : BookResult,
) -> Array[String] {
  let updated : Array[String] = []
  let topic = research_envelope_topic(root, result)
  let source_relative = "sources/research-evidence.md"
  let source_dir = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("sources"))
    .to_string()
  let source_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(source_relative))
    .to_string()
  @fsx.make_directory(source_dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    source_path,
    research_envelope_source_page(root, topic, result),
    create=0o644,
  )
  update_summary(workspace.summary_path, "Research Evidence", source_relative)
  update_index_section(
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("index.md"))
    .to_string(),
    "Sources",
    "Research Evidence",
    source_relative,
    "verified source page materialized by MoonBook from raw research artifacts",
  )
  updated.push(source_relative)

  let concept_relative = "concepts/research-artifact-envelope.md"
  let concept_dir = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("concepts"))
    .to_string()
  let concept_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(concept_relative))
    .to_string()
  @fsx.make_directory(concept_dir, recursive=true, exists_ok=true)
  let concept_block = "### \{result.result_id}\n\n" +
    "- Source: [Research Evidence](../sources/research-evidence.md)\n" +
    "- Summary: \{clamp_excerpt(result.summary)}\n" +
    "- Role: MoonBook consumes the raw research envelope and decides what becomes durable wiki state.\n\n"
  let concept_content = if @fsx.exists(concept_path) {
    append_section_block(
      @fsx.read_file(concept_path),
      "## Materialized Runs",
      concept_block,
    )
  } else {
    "# Research Artifact Envelope\n\n" +
    "A research artifact envelope is the raw evidence bundle returned by a worker before MoonBook promotes it into durable wiki pages.\n\n" +
    "## Materialized Runs\n\n" +
    concept_block
  }
  @fsx.write_to_file(concept_path, concept_content, create=0o644)
  update_summary(
    workspace.summary_path,
    "Research Artifact Envelope",
    concept_relative,
  )
  update_index_section(
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("index.md"))
    .to_string(),
    "Concepts",
    "Research Artifact Envelope",
    concept_relative,
    "MoonBook-owned boundary between raw worker evidence and durable wiki state",
  )
  updated.push(concept_relative)

  for entity in research_envelope_entities(root) {
    let entity_relative = "entities/\{slugify_title(entity)}.md"
    let entity_dir = moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path("entities"))
      .to_string()
    let entity_path = moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path(entity_relative))
      .to_string()
    @fsx.make_directory(entity_dir, recursive=true, exists_ok=true)
    let entity_evidence = clamp_excerpt(
      research_artifact_text(root, "raw/bootstrap/synthesis-brief.md"),
    )
    let entity_block = "### \{result.result_id}\n\n" +
      "- Source: [Research Evidence](../sources/research-evidence.md)\n" +
      "- Evidence: \{entity_evidence}\n\n"
    let entity_content = if @fsx.exists(entity_path) {
      append_section_block(
        @fsx.read_file(entity_path),
        "## Research Updates",
        entity_block,
      )
    } else {
      "# \{entity}\n\n" +
      "## Role\n\n" +
      "This entity was identified from the current research artifact envelope and needs continued revision as more sources are verified.\n\n" +
      "## Research Updates\n\n" +
      entity_block
    }
    @fsx.write_to_file(entity_path, entity_content, create=0o644)
    update_summary(workspace.summary_path, entity, entity_relative)
    update_index_section(
      moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path("index.md"))
      .to_string(),
      "Entities",
      entity,
      entity_relative,
      "entity page materialized from the current research artifact envelope",
    )
    if !updated.contains(entity_relative) {
      updated.push(entity_relative)
    }
  }

  let overview_relative = "synthesis/overview.md"
  let overview_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(overview_relative))
    .to_string()
  let overview_brief = clamp_excerpt(
    research_artifact_text(root, "raw/bootstrap/synthesis-brief.md"),
  )
  let overview_block = "### \{result.result_id}\n\n" +
    "- Source: [Research Evidence](../sources/research-evidence.md)\n" +
    "- Brief: \{overview_brief}\n\n"
  let overview_content = if @fsx.exists(overview_path) {
    append_section_block(
      @fsx.read_file(overview_path),
      "## Research Envelope Synthesis",
      overview_block,
    )
  } else {
    "# Overview\n\n## Research Envelope Synthesis\n\n" + overview_block
  }
  @fsx.write_to_file(overview_path, overview_content, create=0o644)
  update_summary(workspace.summary_path, "Overview", overview_relative)
  update_index_section(
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("index.md"))
    .to_string(),
    "Core Pages",
    "Overview",
    overview_relative,
    "synthesis generated from MoonBook-owned research envelope materialization",
  )
  if !updated.contains(overview_relative) {
    updated.push(overview_relative)
  }
  let report_relative = "synthesis/report.md"
  let report_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(report_relative))
    .to_string()
  @fsx.write_to_file(
    report_path,
    research_envelope_report_page(root, topic, result),
    create=0o644,
  )
  update_summary(workspace.summary_path, "Research Report", report_relative)
  update_index_section(
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("index.md"))
    .to_string(),
    "Core Pages",
    "Research Report",
    report_relative,
    "long-form research article materialized from raw bootstrap deep-report.md",
  )
  if !updated.contains(report_relative) {
    updated.push(report_relative)
  }
  updated
}

///|
async fn research_envelope_topic(root : String, result : BookResult) -> String {
  let question = research_artifact_text(
    root, "raw/bootstrap/research-question.md",
  )
  let first = first_research_line(question)
  if !first.is_empty() {
    first
  } else {
    result.result_id
  }
}

///|
async fn research_envelope_source_page(
  root : String,
  topic : String,
  result : BookResult,
) -> String {
  let question = research_artifact_text(
    root, "raw/bootstrap/research-question.md",
  )
  let search = research_artifact_text(root, "raw/bootstrap/search-log.md")
  let screen = research_artifact_text(root, "raw/bootstrap/source-screen.md")
  let evidence = research_artifact_text(
    root, "raw/bootstrap/evidence-matrix.md",
  )
  let local_sources = research_artifact_text(
    root, "raw/bootstrap/local-sources.md",
  )
  let brief = research_artifact_text(root, "raw/bootstrap/synthesis-brief.md")
  "# Research Evidence\n\n" +
  "- Source type: verified research artifact envelope\n" +
  "- Durability: verified\n" +
  "- Materialized by: MoonBook\n" +
  "- Worker result: `\{result.result_id}`\n" +
  "- Topic: \{topic}\n\n" +
  "## Research Question\n\n\{question}\n\n" +
  "## Search Log\n\n\{search}\n\n" +
  "## Source Screen\n\n\{screen}\n\n" +
  "## Local Sources\n\n\{local_sources}\n\n" +
  "## Evidence Matrix\n\n\{evidence}\n\n" +
  "## Synthesis Brief\n\n\{brief}\n"
}

///|
async fn research_envelope_report_page(
  root : String,
  topic : String,
  result : BookResult,
) -> String {
  ignore(topic)
  ignore(result)
  let report = research_artifact_text(root, "raw/bootstrap/deep-report.md")
  let evidence = research_artifact_text(
    root, "raw/bootstrap/evidence-matrix.md",
  )
  if report.contains("## Evidence Matrix") ||
    (report.contains("## Evidence and Limits") && evidence.trim().is_empty()) {
    report + "\n"
  } else if evidence.trim().is_empty() {
    report + "\n"
  } else {
    report + "\n\n## Evidence Matrix\n\n" + evidence + "\n"
  }
}

///|
async fn research_artifact_text(root : String, relative : String) -> String {
  let path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path(relative))
    .to_string()
  if @fsx.exists(path) {
    @fsx.read_file(path)
  } else {
    "_Missing artifact: `\{relative}`._"
  }
}

///|
fn first_research_line(content : String) -> String {
  for raw in content.split("\n") {
    let line = raw.trim().to_owned()
    if line.is_empty() || line == "---" || line.has_prefix("```") {
      continue
    }
    if line.has_prefix("#") ||
      line.has_prefix("Task:") ||
      line == "Question:" ||
      line.has_prefix("Success criteria:") ||
      line.has_prefix("- ") {
      continue
    }
    if !line.is_empty() {
      return line
    }
  }
  ""
}

///|
async fn research_envelope_entities(root : String) -> Array[String] {
  let text = (research_artifact_text(root, "raw/bootstrap/research-question.md") +
  "\n" +
  research_artifact_text(root, "raw/bootstrap/synthesis-brief.md") +
  "\n" +
  research_artifact_text(root, "raw/bootstrap/evidence-matrix.md")).to_lower()
  let entities : Array[String] = []
  for item in ["Moontown", "MoonBook", "MoonClaw"] {
    if text.contains(item.to_lower()) {
      entities.push(item)
    }
  }
  if entities.is_empty() {
    entities.push(
      title_case(book_identity(root).replace(old="-", new=" ").to_string()),
    )
  }
  entities
}

///|
async fn research_artifact_contract_active(root : String) -> Bool {
  let workspace = workspace_paths(root)
  @fsx.exists(
    moonbook_wiki_path(workspace.root)
    .join(moonbook_wiki_path("raw/bootstrap/RESEARCH_REQUEST.md"))
    .to_string(),
  ) ||
  @fsx.exists(
    moonbook_wiki_path(workspace.root)
    .join(moonbook_wiki_path("raw/bootstrap/SOURCE_HINTS.md"))
    .to_string(),
  )
}

///|
async fn missing_research_artifacts(root : String) -> Array[String] {
  let workspace = workspace_paths(root)
  let missing : Array[String] = []
  for relative in required_research_artifacts() {
    let absolute = moonbook_wiki_path(workspace.root)
      .join(moonbook_wiki_path(relative))
      .to_string()
    if !@fsx.exists(absolute) {
      missing.push(relative)
    }
  }
  missing
}

///|
fn research_artifact_blocker_result(
  result : BookResult,
  missing : Array[String],
) -> BookResult {
  let missing_text = missing.join(", ")
  {
    result_id: result.result_id,
    summary: "Blocked research bootstrap: missing required research artifacts: \{missing_text}. Provider must either create these files or return a tool/source-access blocker that names the unavailable capability.",
    artifacts: result.artifacts,
    memory_candidates: [
      {
        kind: "blocker",
        title: "Research artifact contract not satisfied",
        detail: "Missing required artifacts: \{missing_text}. The provider must write the research question, search log, source screen, evidence matrix, local source digest, synthesis brief, and long-form deep report before MoonBook can treat this bootstrap as research-complete.",
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
  let stage = infer_task_kind_from_external_id(result.result_id).unwrap_or("")
  (
    stage == "ingest" ||
    stage == "bootstrap_gather" ||
    stage == "source_materialize" ||
    stage == "knowledge_revise" ||
    stage == "marketing_project" ||
    stage == "review_finalize"
  ) &&
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
        moonbook_wiki_path(workspace.root)
        .join(moonbook_wiki_path(relative))
        .to_string(),
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
            moonbook_wiki_path(workspace.wiki_dir)
            .join(moonbook_wiki_path(page))
            .to_string(),
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
  match infer_task_kind_from_external_id(result.result_id) {
    Some("ingest") => true
    _ => {
      let summary = result.summary.to_lower()
      summary.contains("bootstrap") || summary.contains("materializ")
    }
  }
}

///|
fn normalize_result_workspace_path(path : String) -> String {
  let normalized = path.trim().to_owned()
  if normalized.has_prefix("wiki/") {
    normalized[5:].to_owned()
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
    let absolute = moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path(dir))
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
      moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path("synthesis/overview.md"))
      .to_string(),
      moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path("synthesis/claims.md"))
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
async fn summarize_memory(root : String) -> String {
  let workspace = workspace_paths(root)
  let keeper = keeper_snapshot(root)
  let claims_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("synthesis/claims.md"))
    .to_string()
  let overview_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("synthesis/overview.md"))
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

///|
async fn ensure_observations_page(workspace : Paths) -> String {
  let relative = "synthesis/observations.md"
  let absolute = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(relative))
    .to_string()
  if !@fsx.exists(absolute) {
    @fsx.write_to_file(
      absolute,
      "# Observations\n\nThis page stores persisted worker results and durable observations.\n\n## Results\n\n_None yet._\n",
      create=0o644,
    )
    update_summary(workspace.summary_path, "Observations", relative)
    update_index_section(
      moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path("index.md"))
      .to_string(),
      "Core Pages",
      "Observations",
      relative,
      "persisted worker results and memory observations",
    )
  }
  relative
}

///|
fn persisted_result_block(result : BookResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string("### \{result.result_id}\n\n")
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
  let absolute = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(relative))
    .to_string()
  let review_id = "result-review-\{slugify_title(result.result_id)}"
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
  let block = "### Result review | \{result.result_id}\n\n" +
    "- Review ID: `\{review_id}`\n" +
    "- Result page: [\{result.result_id}](\{link})\n" +
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
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("index.md"))
    .to_string(),
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
  let entry = "## [\{now}] persist | \{result.result_id}\n\n" +
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
    let absolute = moonbook_wiki_path(workspace.wiki_dir)
      .join(moonbook_wiki_path(relative_page))
      .to_string()
    if !@fsx.exists(absolute) {
      seed_memory_candidate_page(absolute, candidate.title)
      update_summary(workspace.summary_path, candidate.title, relative_page)
      update_index_section(
        moonbook_wiki_path(workspace.wiki_dir)
        .join(moonbook_wiki_path("index.md"))
        .to_string(),
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
async fn refresh_workspace_projections(root : String) -> Unit {
  let workspace = workspace_paths(root)
  let source_coverage = summarize_source_coverage(workspace.wiki_dir)
  let source_page_count = source_coverage.verified_count
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
  let journey_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(journey_relative_page()))
    .to_string()
  if file_needs_projection_reconcile(journey_path) {
    ignore(
      append_journey_entry(
        workspace, synthetic, "workspace-inventory", review_queued, substantive_pages,
        true,
      ),
    )
  }
  let debug_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(debug_journal_relative_page()))
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
    result_id: "workspace-bootstrap-ingest-followup",
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
fn standing_watch_goal(goal : String) -> Bool {
  let notes = goal.to_lower()
  notes.contains("standing-watch") ||
  notes.contains("standing watch") ||
  notes.contains("standing_goal_decision") ||
  notes.contains("next_check_hint") ||
  notes.contains("24/7") ||
  notes.contains("24 x 7") ||
  notes.contains("periodically check")
}

///|
fn standing_watch_task(goal_id : String, goal : String) -> BookTask {
  standing_watch_task_with_id("\{goal_id}-standing-watch", goal)
}

///|
fn standing_watch_task_with_id(task_id : String, goal : String) -> BookTask {
  {
    id: task_id,
    title: "Run standing watch decision",
    kind: "standing-watch",
    prompt: standing_watch_prompt(goal),
    priority: 100,
    requires_review: false,
    target_pages: [
      "history/standing-watch.md", "history/journey.md", "sources/", "synthesis/overview.md",
      "synthesis/claims.md", "synthesis/evidence.md", "synthesis/maintenance-plan.md",
      "reviews/pending.md", "../raw/bootstrap/",
    ],
  }
}

///|
fn external_standing_watch_task_id(task_id : String) -> Bool {
  let normalized = task_id.trim().to_lower()
  normalized.contains("standing-watch") ||
  (normalized.has_prefix("standing-") && normalized.contains("-tick-"))
}

///|
fn standing_watch_prompt(goal : String) -> String {
  "Load `skills/standing-watch/SKILL.md` before deciding. Treat this as a recurring book-local watch pass, not a one-off report. Compare the current wiki baseline, prior watch history, and available sources against the standing goal. Only update durable wiki pages when there is meaningful new evidence, contradiction, or synthesis value. If there is no meaningful delta, return a compact no-change result instead of inventing content.\n\nStanding goal:\n\{goal}\n\nYour summary must include these machine-readable lines exactly once:\nstanding_goal_decision: update | no_change | needs_review | failed\ndelta_score: 0-100\nnew_source_count: <integer>\nnext_check_hint: normal | slower | faster | review"
}

///|
fn result_is_standing_watch(result : BookResult) -> Bool {
  let text = (result.result_id + "\n" + result.summary).to_lower()
  text.contains("standing-watch") ||
  text.contains("standing_goal_decision") ||
  text.contains("next_check_hint")
}

///|
async fn append_standing_watch_history(
  workspace : Paths,
  result : BookResult,
) -> String {
  let relative = "history/standing-watch.md"
  let dir = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("history"))
    .to_string()
  let absolute = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path(relative))
    .to_string()
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let current = if @fsx.exists(absolute) {
    @fsx.read_file(absolute)
  } else {
    "# Standing Watch\n\nThis page stores MoonBook-owned decisions for recurring 24/7 topic checks. The AI decides whether a check found meaningful new information; MoonBook records the decision, evidence paths, and review state.\n\n## Decisions\n\n_None yet._\n"
  }
  let block = standing_watch_history_block(result)
  let updated = append_section_block(current, "## Decisions", block)
  @fsx.write_to_file(absolute, updated, create=0o644)
  update_summary(workspace.summary_path, "Standing Watch", relative)
  update_index_section(
    moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("index.md"))
    .to_string(),
    "Core Pages",
    "Standing Watch",
    relative,
    "recurring watch decisions and deltas for long-running book upkeep",
  )
  relative
}

///|
fn standing_watch_history_block(result : BookResult) -> String {
  let decision = standing_watch_summary_field(
    result.summary,
    "standing_goal_decision",
    "unknown",
  )
  let delta_score = standing_watch_summary_field(
    result.summary,
    "delta_score",
    "unknown",
  )
  let new_source_count = standing_watch_summary_field(
    result.summary,
    "new_source_count",
    "unknown",
  )
  let next_check_hint = standing_watch_summary_field(
    result.summary,
    "next_check_hint",
    "normal",
  )
  let builder = StringBuilder::new()
  builder.write_string("### \{result.result_id}\n\n")
  builder.write_string("- Decision: `\{decision}`\n")
  builder.write_string("- Delta score: `\{delta_score}`\n")
  builder.write_string("- New source count: `\{new_source_count}`\n")
  builder.write_string("- Next check hint: `\{next_check_hint}`\n")
  builder.write_string("- Requires review: `\{result.requires_review}`\n")
  builder.write_string("- Notify town: `\{result.notify_town}`\n")
  if !result.artifacts.is_empty() {
    builder.write_string("- Artifacts:\n")
    for artifact in result.artifacts {
      builder.write_string("  - `\{artifact}`\n")
    }
  }
  builder.write_string("- Summary: \{clamp_excerpt(result.summary)}\n\n")
  builder.to_string()
}

///|
fn standing_watch_summary_field(
  summary : String,
  key : String,
  fallback : String,
) -> String {
  let prefix = key + ":"
  for raw in summary.split("\n") {
    let mut line = raw.trim().to_owned()
    if line.has_prefix("- ") {
      line = line[2:].trim().to_owned()
    }
    if line.to_lower().has_prefix(prefix) {
      return line[prefix.length():].trim().to_owned()
    }
  }
  fallback
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
test "standing watch goal detection stays generic" {
  assert_true(standing_watch_goal("standing-watch topic=one person company"))
  assert_true(standing_watch_goal("Periodically check this topic for deltas"))
  assert_true(!standing_watch_goal("research moontown, moonbook and moonclaw"))
}

///|
test "planbook goal detection stays bounded to executable planning" {
  assert_true(
    planbook_goal("write an implementation plan with acceptance criteria"),
  )
  assert_true(planbook_goal("/ce: plan fix daemon supervision"))
  assert_true(planbook_goal("create a repair packet for self-healing autonomy"))
  assert_true(
    planbook_goal("repair the self-healing autonomy loop and validate it"),
  )
  assert_true(!planbook_goal("research LLM training in very detail"))
  assert_true(!planbook_goal("research self-healing agent literature"))
  assert_true(!planbook_goal("create a beginner course on isometric maps"))
}

///|
test "document reverse engineering goal detection stays bounded" {
  assert_true(
    document_reverse_engineer_goal(
      "reverse engineer this finished document and generate a better version",
    ),
  )
  assert_true(
    document_reverse_engineer_goal(
      "deconstruct document logic from this good document",
    ),
  )
  assert_true(!document_reverse_engineer_goal("research MoonBook architecture"))
  assert_true(!document_reverse_engineer_goal("write a beginner course"))
}

///|
async test "produce task batch creates dedicated standing watch task" {
  let root = "/tmp/moonbook-extension-api-standing-watch"
  ignore(init_workspace(root))
  let batch = produce_task_batch(
    root, "standing-watch: periodically check latest sources about one person company and update the book only when there is a meaningful delta",
  )
  assert_true(batch.summary.contains("standing_watch=1"))
  assert_eq(batch.tasks.length(), 1)
  assert_eq(batch.tasks[0].kind, "standing-watch")
  assert_true(batch.tasks[0].prompt.contains("skills/standing-watch/SKILL.md"))
  assert_true(batch.tasks[0].prompt.contains("standing_goal_decision"))
  assert_true(batch.tasks[0].target_pages.contains("history/standing-watch.md"))
}

///|
async test "produce task batch routes reverse document goals to document skill" {
  let root = "/tmp/moonbook-extension-api-document-reverse"
  ignore(init_workspace(root))
  let batch = produce_task_batch(
    root, "reverse engineer this finished document, extract the core logic, and generate a better version",
  )
  assert_true(batch.summary.contains("document_reverse_phases"))
  assert_eq(batch.tasks.length(), 1)
  assert_eq(batch.tasks[0].kind, "document-reverse-engineer")
  assert_true(
    batch.tasks[0].prompt.contains("skills/document-reverse-engineer/SKILL.md"),
  )
  assert_true(
    batch.tasks[0].target_pages.contains(
      "../raw/bootstrap/regenerated-document.md",
    ),
  )
}

///|
async test "produce task batch routes executable plan goals to planbook" {
  let root = "/tmp/moonbook-extension-api-planbook"
  ignore(init_workspace(root))
  let batch = produce_task_batch(
    root, "write an implementation plan with acceptance criteria for live autonomy self-healing",
  )
  assert_true(batch.summary.contains("planbook_phases"))
  assert_true(batch.tasks.any(fn(task) { task.kind == "planbook_context" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "planbook_write" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "planbook_review" }))
  assert_true(!batch.tasks.any(fn(task) { task.kind == "bootstrap_gather" }))
  assert_true(!batch.tasks.any(fn(task) { task.kind == "planning" }))
  let writer = batch.tasks
    .iter()
    .find_first(fn(task : BookTask) { task.kind == "planbook_write" })
    .unwrap()
  assert_true(writer.prompt.contains("skills/planbook/SKILL.md"))
  assert_true(!writer.prompt.contains("skills/research-report/SKILL.md"))
  assert_true(writer.target_pages.contains("../plans/"))
  assert_true(writer.target_pages.contains("planning/execution-evidence.md"))
}

///|
async test "persist standing watch result records durable watch history" {
  let root = "/tmp/moonbook-extension-api-standing-watch-history"
  ignore(init_workspace(root))
  let outcome = persist_result(root, {
    result_id: "goal-opc-standing-watch",
    summary: "standing_goal_decision: no_change\ndelta_score: 8\nnew_source_count: 0\nnext_check_hint: slower\nNo credible new source changed the book baseline.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: true,
  })
  assert_true(outcome.updated_pages.contains("history/standing-watch.md"))
  let history = @fsx.read_file(root + "/wiki/history/standing-watch.md")
  assert_true(history.contains("### goal-opc-standing-watch"))
  assert_true(history.contains("- Decision: `no_change`"))
  assert_true(history.contains("- Next check hint: `slower`"))
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
  assert_true(prompt.contains("Research artifact contract"))
  assert_true(prompt.contains("raw/bootstrap/research-question.md"))
  assert_true(prompt.contains("Local source hints for this bootstrap pass"))
  assert_true(prompt.contains("/tmp/moonbook-prompt-hints/moontown"))
  assert_true(prompt.contains("README.md"))
}

///|
async test "bootstrap context carries skill body excerpts and required research artifacts" {
  let root = "/tmp/moonbook-extension-api-bootstrap-contract"
  ignore(init_workspace(root))
  let context = hydrate_worker_context(root, {
    id: "goal-research-bootstrap_gather",
    title: "Gather bootstrap materials",
    kind: "bootstrap_gather",
    prompt: "Research moontown.",
    priority: 100,
    requires_review: true,
    target_pages: [],
  })
  assert_true(context.prompt.contains("Research artifact contract"))
  assert_true(context.prompt.contains("Loaded skill body excerpts"))
  assert_true(context.prompt.contains("skills/wiki-ingest/SKILL.md"))
  assert_true(
    context.output_contract.any(fn(line) {
      line.contains("raw/bootstrap/evidence-matrix.md")
    }),
  )
}

///|
async test "standing watch context loads watch skill and marker contract" {
  let root = "/tmp/moonbook-extension-api-standing-watch-context"
  ignore(init_workspace(root))
  let task = standing_watch_task(
    "goal-opc", "standing-watch: periodically check one person company news",
  )
  let context = hydrate_worker_context(root, task)
  assert_true(context.skill_paths.contains("skills/standing-watch/SKILL.md"))
  assert_true(context.skill_paths.contains("skills/source-diarize/SKILL.md"))
  assert_true(context.prompt.contains("Standing watch workspace baseline"))
  assert_true(context.prompt.contains("standing_goal_decision"))
  assert_true(!context.prompt.contains("research artifact contract above"))
  assert_true(
    context.output_contract.any(fn(line) {
      line.contains("standing-watch tasks")
    }),
  )
}

///|
async test "planbook worker context uses planbook contract not research or course" {
  let root = "/tmp/moonbook-extension-api-planbook-context"
  ignore(init_workspace(root))
  let task = planbook_semantic_tasks(
      "goal-planbook", "write an implementation plan with acceptance criteria",
    )[1]
  let context = hydrate_worker_context(root, task)
  assert_true(@fsx.exists(root + "/plans/index.md"))
  assert_true(@fsx.exists(root + "/wiki/planning/index.md"))
  assert_true(@fsx.exists(root + "/wiki/planning/execution-evidence.md"))
  assert_true(@fsx.exists(root + "/wiki/reviews/active-plan-review.md"))
  assert_true(context.skill_paths.contains("skills/planbook/SKILL.md"))
  assert_true(!context.skill_paths.contains("skills/research-report/SKILL.md"))
  assert_true(!context.skill_paths.contains("skills/wiki-course/SKILL.md"))
  assert_true(context.prompt.contains("Loaded skill body excerpts"))
  assert_true(
    context.output_contract.contains(
      "This is a PlanBook task, not a research bootstrap task and not a course task.",
    ),
  )
  assert_true(
    context.output_contract.any(fn(line) { line.contains("planbook_decision") }),
  )
  assert_true(
    !context.output_contract.any(fn(line) {
      line.contains("For research bootstrap") ||
      line.contains("Course artifacts should include")
    }),
  )
}

///|
async test "document reverse worker context uses reverse contract not research bootstrap" {
  let root = "/tmp/moonbook-extension-api-document-reverse-context"
  ignore(init_workspace(root))
  let task = document_reverse_engineer_tasks(
      "goal-document", "reverse engineer this finished document",
    )[0]
  let context = hydrate_worker_context(root, task)
  assert_true(
    context.skill_paths.contains("skills/document-reverse-engineer/SKILL.md"),
  )
  assert_true(!context.skill_paths.contains("skills/research-report/SKILL.md"))
  assert_true(context.prompt.contains("Loaded skill body excerpts"))
  assert_true(
    context.output_contract.contains(
      "This is a reverse-document task, not a research bootstrap task.",
    ),
  )
  assert_true(
    context.output_contract.any(fn(line) {
      line.contains("raw/bootstrap/document-deconstruction.md")
    }),
  )
  assert_true(
    !context.output_contract.any(fn(line) {
      line.contains("For research bootstrap") ||
      line.contains("artifacts must include raw/bootstrap/research-question.md")
    }),
  )
}

///|
async test "catalog record defaults to book private memory scope" {
  let root = "/tmp/moonbook-extension-api-catalog"
  ignore(init_workspace(root))
  let record = catalog_record(root)
  assert_eq(record.memory_scope, "BookPrivate")
  assert_eq(record.id, "moonbook-extension-api-catalog")
}

///|
async test "catalog skills include base harness skills" {
  let root = "/tmp/moonbook-extension-api-skills"
  ignore(init_workspace(root))
  let skills = catalog_skills(root)
  assert_true(skills.contains("wiki-ingest"))
  assert_true(skills.contains("wiki-query"))
  assert_true(skills.contains("wiki-review"))
  assert_true(skills.contains("source-diarize"))
  assert_true(skills.contains("research-report"))
  assert_true(skills.contains("planbook"))
  assert_true(skills.contains("standing-watch"))
  assert_true(skills.contains("query-promote"))
  assert_true(skills.contains("review-decision"))
}

///|
async test "hydrate worker context includes keeper memory slices" {
  let root = "/tmp/moonbook-extension-api-context"
  ignore(init_workspace(root))
  ignore(
    persist_result(root, {
      result_id: "task-memory",
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
  let root = "/tmp/moonbook-extension-api-journey"
  ignore(init_workspace(root))
  ignore(
    persist_result(root, {
      result_id: "goal-research-moontown-ingest-followup",
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
    journey.contains(
      "- Latest result: `goal-research-moontown-ingest-followup`",
    ),
  )
  assert_true(journey.contains("- Status: `pending-review`"))
}

///|
async test "persist result appends detailed debug journal entry" {
  let root = "/tmp/moonbook-extension-api-debug-journal"
  ignore(init_workspace(root))
  ignore(
    persist_result(root, {
      result_id: "goal-research-moontown-ingest-followup",
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
    journal.contains(
      "- Latest result: `goal-research-moontown-ingest-followup`",
    ),
  )
  assert_true(journal.contains("- Result class: `administrative`"))
  assert_true(journal.contains("no durable artifact paths were reported"))
  assert_true(journal.contains("Ingest provider returned an empty result"))
}

///|
async test "research bootstrap result blocks when required artifacts are missing" {
  let root = "/tmp/moonbook-extension-api-research-contract"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/raw/bootstrap/RESEARCH_REQUEST.md",
      "# Research Request\n",
      create=0o644,
    ),
  )
  let normalized = reconcile_provider_result(root, workspace_paths(root), {
    result_id: "goal-research-moontown-bootstrap_gather",
    summary: "Completed provider task.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  })
  assert_true(
    normalized.summary.contains(
      "Blocked research bootstrap: missing required research artifacts",
    ),
  )
  assert_true(normalized.requires_review)
  assert_eq(
    normalized.memory_candidates[0].title,
    "Research artifact contract not satisfied",
  )
}

///|
async test "persist result materializes raw research envelope into wiki pages" {
  let root = "/tmp/moonbook-extension-api-research-envelope"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/raw/bootstrap/RESEARCH_REQUEST.md",
      "# Research Request\n",
      create=0o644,
    ),
  )
  for relative in required_research_artifacts() {
    let content = if relative.has_suffix("research-question.md") {
      "# MoonBook Research\n\nResearch MoonBook as the durable workspace layer.\n"
    } else if relative.has_suffix("synthesis-brief.md") {
      "# Synthesis Brief\n\nMoonBook owns durable wiki materialization from raw research artifacts.\n"
    } else {
      "# Artifact\n\nMoonBook evidence for the research envelope.\n"
    }
    ignore(@fsx.write_to_file(root + "/" + relative, content, create=0o644))
  }
  let outcome = persist_result(root, {
    result_id: "goal-research-moonbook-bootstrap_gather",
    summary: "Completed raw research artifact envelope for MoonBook.",
    artifacts: required_research_artifacts(),
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  })
  assert_true(@fsx.exists(root + "/wiki/sources/research-evidence.md"))
  assert_true(@fsx.exists(root + "/wiki/entities/moonbook.md"))
  assert_true(
    @fsx.exists(root + "/wiki/concepts/research-artifact-envelope.md"),
  )
  assert_true(@fsx.exists(root + "/wiki/synthesis/report.md"))
  assert_true(
    @fsx.read_file(root + "/wiki/sources/research-evidence.md").contains(
      "Source type: verified research artifact envelope",
    ),
  )
  assert_true(
    @fsx.read_file(root + "/wiki/synthesis/overview.md").contains(
      "durable wiki materialization",
    ),
  )
  assert_true(outcome.updated_pages.contains("sources/research-evidence.md"))
}

///|
async test "generic completion with complete research envelope is materialized by moonbook" {
  let root = "/tmp/moonbook-extension-api-research-envelope-generic"
  ignore(init_workspace(root))
  ignore(
    @fsx.write_to_file(
      root + "/raw/bootstrap/RESEARCH_REQUEST.md",
      "# Research Request\n",
      create=0o644,
    ),
  )
  for relative in required_research_artifacts() {
    ignore(
      @fsx.write_to_file(
        root + "/" + relative,
        "# Artifact\n\nMoonBook and MoonClaw research evidence.\n",
        create=0o644,
      ),
    )
  }
  let outcome = persist_result(root, {
    result_id: "goal-research-moonbook-bootstrap_gather",
    summary: "Completed provider task.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  })
  assert_true(outcome.updated_pages.contains("sources/research-evidence.md"))
  assert_true(
    @fsx.exists(root + "/wiki/concepts/research-artifact-envelope.md"),
  )
  assert_true(
    @fsx.read_file(root + "/wiki/synthesis/observations.md").contains(
      "MoonBook materialized durable wiki pages from the raw research artifact envelope",
    ),
  )
}

///|
async test "persist result reconciles substantive bootstrap pages from workspace" {
  let root = "/tmp/moonbook-extension-api-reconcile-bootstrap"
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
      result_id: "goal-research-moontown-ingest-followup",
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
  let root = "/tmp/moonbook-extension-api-projection-reconcile"
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
  let root = "/tmp/moonbook-extension-api-normalize-blocker"
  ignore(init_workspace(root))
  let normalized = reconcile_provider_result(root, workspace_paths(root), {
    result_id: "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
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
  let root = "/tmp/moonbook-extension-api-normalize-recovered"
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
    result_id: "goal-research-moontown-moonbook-and-moonclaw-ingest-followup",
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
  let root = "/tmp/moonbook-extension-api-bootstrap"
  ignore(init_workspace(root))
  let batch = produce_task_batch(
    root, "research moontown, moonbook and moonclaw",
  )
  assert_true(batch.summary.contains("bootstrap_phases"))
  assert_true(batch.tasks.any(fn(task) { task.kind == "bootstrap_gather" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "source_materialize" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "knowledge_revise" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "marketing_project" }))
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
  assert_true(
    materialize.prompt.contains("MoonBook will materialize those pages"),
  )
  assert_true(
    materialize.target_pages.contains("../raw/bootstrap/evidence-matrix.md"),
  )
}

///|
async test "produce task batch routes course goals without research report skill" {
  let root = "/tmp/moonbook-extension-api-course"
  ignore(init_workspace(root))
  let batch = produce_task_batch(
    root, "create a beginner course and workbook for Wenyu Valley tile-map game design",
  )
  assert_true(batch.summary.contains("course_phases"))
  assert_true(batch.tasks.any(fn(task) { task.kind == "course_outline" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "course_workbook" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "course_project" }))
  assert_true(batch.tasks.any(fn(task) { task.kind == "course_review" }))
  assert_true(!batch.tasks.any(fn(task) { task.kind == "bootstrap_gather" }))
  assert_true(!batch.tasks.any(fn(task) { task.kind == "marketing_project" }))
  let workbook = batch.tasks
    .iter()
    .find_first(fn(task : BookTask) { task.kind == "course_workbook" })
    .unwrap()
  assert_true(workbook.prompt.contains("skills/wiki-course/SKILL.md"))
  assert_true(!workbook.prompt.contains("skills/research-report/SKILL.md"))
  assert_true(
    workbook.target_pages.contains("../raw/bootstrap/course-outline.md"),
  )
  assert_true(workbook.target_pages.contains("../raw/bootstrap/deep-report.md"))
}

///|
async test "course worker context uses course contract not research bootstrap contract" {
  let root = "/tmp/moonbook-extension-api-course-context"
  ignore(init_workspace(root))
  let task = course_semantic_tasks(
      "goal-course", "create a beginner course and workbook for Wenyu Valley tile-map game design",
    )[1]
  let context = hydrate_worker_context(root, task)
  assert_true(context.skill_paths.contains("skills/wiki-course/SKILL.md"))
  assert_true(!context.skill_paths.contains("skills/research-report/SKILL.md"))
  assert_true(context.prompt.contains("Loaded skill body excerpts"))
  assert_true(
    context.output_contract.contains(
      "This is a course task, not a research bootstrap task.",
    ),
  )
  assert_true(
    !context.output_contract.any(fn(line) {
      line.contains("For research bootstrap")
    }),
  )
}

///|
test "course memory filter removes stale research-bootstrap operational records" {
  let filtered = filter_course_memory([
    "- Research artifact contract not satisfied: Missing required artifacts.", "- provider-review: Completed from research bootstrap dossier.",
    "- Course lesson artifact updated.",
  ])
  assert_true(filtered == ["- Course lesson artifact updated."])
}

///|
async test "produce task batch allows synthesis after durable coverage exists" {
  let root = "/tmp/moonbook-extension-api-query-ready"
  ignore(init_workspace(root))
  ignore(ingest_source(root, root + "/raw/README.md"))
  ignore(
    persist_result(root, {
      result_id: "task-evidence",
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
  let root = "/tmp/moonbook-extension-api-external-task"
  ignore(init_workspace(root))
  let task = resolve_task_for_goal(
    root,
    "research moontown, moonbook and moonclaw",
    task_id=Some("goal-coding-research-bootstrap-ingest"),
  ).unwrap()
  assert_eq(task.kind, "bootstrap_gather")
}

///|
async test "resolve task for goal accepts external standing watch task ids" {
  let root = "/tmp/moonbook-extension-api-external-standing-watch-task"
  ignore(init_workspace(root))
  let task = resolve_task_for_goal(
    root,
    "Research latest One Person Company news and update the book only when there is a meaningful delta.",
    task_id=Some("standing-watch-opc-news-tick-1"),
  ).unwrap()
  assert_eq(task.id, "standing-watch-opc-news-tick-1")
  assert_eq(task.kind, "standing-watch")
  assert_true(task.prompt.contains("skills/standing-watch/SKILL.md"))
  assert_true(task.prompt.contains("standing_goal_decision"))
  assert_true(!task.prompt.contains("Research artifact contract"))
}

///|
async test "resolve task for goal recovers bootstrap semantic task after coverage exists" {
  let root = "/tmp/moonbook-extension-api-bootstrap-fallback"
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
