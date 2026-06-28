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
  let active_memory = select_memory_entries(keeper.active_memory, terms, 6)
  let working_memory = select_memory_entries(keeper.working_memory, terms, 8)
  {
    book_id: book_identity(root),
    workspace_root: workspace.root,
    task_id: task.id,
    prompt: task_prompt_with_material_hints(root, task, terms),
    policy,
    routines,
    skill_paths: resolve_skill_paths(root, task),
    context_pages: select_context_pages(root, task, terms),
    active_memory: if course_task_kind(task.kind) {
      filter_course_memory(active_memory)
    } else {
      active_memory
    },
    user_memory: select_memory_entries(keeper.user_memory, terms, 4),
    working_memory: if course_task_kind(task.kind) {
      filter_course_memory(working_memory)
    } else {
      working_memory
    },
    memory_summary,
    output_contract: if planbook_task_kind(task.kind) {
      planbook_provider_result_contract_lines()
    } else if document_reverse_task_kind(task.kind) {
      document_reverse_provider_result_contract_lines()
    } else if course_task_kind(task.kind) {
      course_provider_result_contract_lines()
    } else {
      provider_result_contract_lines()
    },
  }
}

///|

///|
// Worker context hydration helpers, skill resolution, and memory/context selection.

///|
fn filter_course_memory(entries : Array[String]) -> Array[String] {
  entries.filter(fn(entry) {
    let text = entry.to_lower()
    !text.contains("research artifact contract") &&
    !text.contains("research bootstrap dossier") &&
    !text.contains("required raw artifact") &&
    !text.contains("bootstrap ingest")
  })
}

///|
fn provider_result_contract_lines() -> Array[String] {
  [
    "Return exactly one JSON object.", "Do not output markdown fences or prose outside the JSON object.",
    "Use keys: result_id, summary, artifacts, memory_candidates, requires_review, notify_town.",
    "Set result_id to a stable identifier for this worker result.", "artifacts must be an array of workspace-relative output paths.",
    "memory_candidates must be an array of objects with kind, title, detail, durable, target_page.",
    "For weak-coverage research goals, follow the MoonBook phases in order: bootstrap_gather, source_materialize, knowledge_revise, marketing_project, review_finalize.",
    "For research bootstrap, artifacts must include raw/bootstrap/research-question.md, raw/bootstrap/search-log.md, raw/bootstrap/source-screen.md, raw/bootstrap/evidence-matrix.md, raw/bootstrap/local-sources.md, raw/bootstrap/synthesis-brief.md, raw/bootstrap/deep-report.md, and raw/bootstrap/marketing-brief.md, or the result must be a structured blocker explaining exactly which files are missing.",
    "For bootstrap ingest, MoonClaw should produce raw/bootstrap research artifacts and should not need to create wiki/* pages; MoonBook owns durable wiki materialization from the research envelope.",
    "If web_search or web_fetch is unavailable, explicitly say so in the blocker and record that limitation in raw/bootstrap/search-log.md or raw/bootstrap/source-screen.md when possible.",
    "For standing-watch tasks, summary must include exactly one marker block with standing_goal_decision, delta_score, new_source_count, and next_check_hint.",
    "For standing-watch no_change decisions, return a compact result and do not invent durable artifacts; for update or needs_review decisions, list the concrete artifact or wiki paths that changed.",
    "Use [] for empty arrays and null for missing target_page.", "For ingest or bootstrap work, generic completion text without substantive artifacts or durable candidates is a blocker, not success.",
    "If ingest work cannot produce the required raw research artifacts, say what material or tool is missing and set requires_review to true.",
  ]
}

///|
fn document_reverse_provider_result_contract_lines() -> Array[String] {
  [
    "Return exactly one JSON object.", "Do not output markdown fences or prose outside the JSON object.",
    "Use keys: result_id, summary, artifacts, memory_candidates, requires_review, notify_town.",
    "Set result_id to a stable identifier for this worker result.", "artifacts must be an array of workspace-relative output paths.",
    "This is a reverse-document task, not a research bootstrap task.", "Load skills/document-reverse-engineer/SKILL.md and inspect the named finished document before writing.",
    "Expected artifacts are raw/bootstrap/source-document.md, raw/bootstrap/document-deconstruction.md, raw/bootstrap/argument-map.md, raw/bootstrap/style-profile.md, raw/bootstrap/improvement-plan.md, and raw/bootstrap/regenerated-document.md.",
    "Do not require research-question.md, search-log.md, source-screen.md, evidence-matrix.md, local-sources.md, deep-report.md, or marketing-brief.md unless the user explicitly asks for research bootstrap artifacts.",
    "The regenerated document must rebuild from the extracted logic map and style profile; do not return a generic summary or sentence-by-sentence paraphrase.",
    "If the source document is missing or only a placeholder, return a structured blocker and set requires_review to true.",
    "Use [] for empty arrays and null for missing target_page.",
  ]
}

///|
fn course_provider_result_contract_lines() -> Array[String] {
  [
    "Return exactly one JSON object.", "Do not output markdown fences or prose outside the JSON object.",
    "Use keys: result_id, summary, artifacts, memory_candidates, requires_review, notify_town.",
    "Set result_id to a stable identifier for this worker result.", "artifacts must be an array of workspace-relative output paths.",
    "This is a course task, not a research bootstrap task.", "Do not require research-question.md, search-log.md, source-screen.md, evidence-matrix.md, local-sources.md, synthesis-brief.md, or marketing-brief.md unless the course prompt explicitly asks for them.",
    "Course artifacts should include raw/bootstrap/course-outline.md, raw/bootstrap/deep-report.md when used as the workbook, and wiki/synthesis/beginner-course.md.",
    "The visible course must teach through lessons, examples, exercises, output artifacts, checkpoints, and common mistakes.",
    "Reject Deep Research Analysis, Verified Findings, source-audit headings, provider status, ReviewQueued state, run ids, and process logs as reader-facing course structure.",
    "Use [] for empty arrays and null for missing target_page.",
  ]
}

///|
fn planbook_provider_result_contract_lines() -> Array[String] {
  [
    "Return exactly one JSON object.", "Do not output markdown fences or prose outside the JSON object.",
    "Use keys: result_id, summary, artifacts, memory_candidates, requires_review, notify_town.",
    "Set result_id to a stable identifier for this worker result.", "artifacts must include the durable plan path when a plan was written or updated.",
    "This is a PlanBook task, not a research bootstrap task and not a course task.",
    "Do not require research-question.md, search-log.md, source-screen.md, evidence-matrix.md, local-sources.md, synthesis-brief.md, marketing-brief.md, course-outline.md, or beginner-course.md unless the plan explicitly names them as implementation artifacts.",
    "The summary must include exactly one marker block with planbook_decision, plan_path, owner, and remaining_blockers.",
    "Allowed planbook_decision values: ready_to_execute, needs_owner, needs_more_context, blocked.",
    "Use remaining_blockers: none when there are no blockers; otherwise list concrete owner-scoped blockers.",
    "A valid PlanBook result records executable acceptance criteria and validation commands, not generic completion prose.",
    "Use [] for empty arrays and null for missing target_page.",
  ]
}

///|
async fn task_prompt_with_material_hints(
  root : String,
  task : BookTask,
  terms : Array[String],
) -> String {
  if planbook_task_kind(task.kind) {
    return task.prompt + skill_body_excerpt_block(root, task)
  }
  if standing_watch_task_kind(task.kind) {
    return task.prompt +
      standing_watch_context_block(root) +
      skill_body_excerpt_block(root, task)
  }
  if course_task_kind(task.kind) {
    return task.prompt + skill_body_excerpt_block(root, task)
  }
  if document_reverse_task_kind(task.kind) {
    return task.prompt + skill_body_excerpt_block(root, task)
  }
  if !bootstrap_material_task_kind(task.kind) {
    return task.prompt
  }
  let hints = bootstrap_source_hint_lines(
    root,
    terms,
    task.title + " " + task.prompt,
  )
  let artifact_contract = research_artifact_contract_block()
  let skill_block = skill_body_excerpt_block(root, task)
  let hint_block = if hints.is_empty() {
    ""
  } else {
    "\n\nLocal source hints for this bootstrap pass:\n" +
    hints.join("\n") +
    "\n\nUse these paths as candidate primary materials before concluding that the book has no substantive sources."
  }
  task.prompt + artifact_contract + skill_block + hint_block
}

///|
fn standing_watch_task_kind(kind : String) -> Bool {
  kind == "standing-watch"
}

///|
fn course_task_kind(kind : String) -> Bool {
  kind == "course_outline" ||
  kind == "course_workbook" ||
  kind == "course_project" ||
  kind == "course_review"
}

///|
fn document_reverse_task_kind(kind : String) -> Bool {
  kind == "document-reverse-engineer"
}

///|
fn planbook_task_kind(kind : String) -> Bool {
  kind == "planbook_context" ||
  kind == "planbook_write" ||
  kind == "planbook_review"
}

///|
fn bootstrap_material_task_kind(kind : String) -> Bool {
  kind == "ingest" ||
  kind == "bootstrap_gather" ||
  kind == "source_materialize" ||
  kind == "knowledge_revise" ||
  kind == "marketing_project"
}

///|
async fn standing_watch_context_block(root : String) -> String {
  let workspace = workspace_paths(root)
  let state = summarize_state(root)
  let health = report_health(root)
  let watch_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("history/standing-watch.md"))
    .to_string()
  let previous = if @fsx.exists(watch_path) {
    clamp_excerpt(@fsx.read_file(watch_path))
  } else {
    "_No previous standing-watch decisions._"
  }
  "\n\nStanding watch workspace baseline:\n" +
  "- book_id: `\{state.book_id}`\n" +
  "- health: `\{health.level}`\n" +
  "- source_page_count: `\{state.source_page_count}`\n" +
  "- entity_page_count: `\{state.entity_page_count}`\n" +
  "- concept_page_count: `\{state.concept_page_count}`\n" +
  "- query_note_count: `\{state.query_note_count}`\n" +
  "- pending_review_count: `\{state.pending_review_count}`\n" +
  "- substantive_coverage_ready: `\{state.substantive_coverage_ready}`\n\n" +
  "Recent standing-watch history excerpt:\n\{previous}\n"
}

///|
async fn skill_body_excerpt_block(root : String, task : BookTask) -> String {
  let selected = resolve_skill_paths(root, task)
  if selected.is_empty() {
    return "\n\nLoaded skill bodies:\n- No skill files were resolved. Return a structured blocker if the task depends on unavailable skills.\n"
  }
  let normalized = @pathx.normalize(root)
  let builder = StringBuilder::new()
  builder.write_string(
    "\n\nLoaded skill body excerpts:\nRead these excerpts as operational instructions, not just metadata. If an excerpt conflicts with the task, follow the explicit task contract above and report the conflict.\n",
  )
  for relative in selected {
    if relative == "RESOLVER.md" {
      continue
    }
    let absolute = moonbook_wiki_path(normalized)
      .join(moonbook_wiki_path(relative))
      .to_string()
    if !@fsx.exists(absolute) {
      builder.write_string("- `\{relative}`: missing from workspace.\n")
      continue
    }
    builder.write_string("\n### `\{relative}`\n")
    let mut line_count = 0
    for raw in @fsx.read_file(absolute).split("\n") {
      let line = raw.to_owned()
      if line.trim().is_empty() && line_count > 24 {
        continue
      }
      builder.write_string(line + "\n")
      line_count += 1
      let max_lines = if relative.contains("research-report") {
        190
      } else {
        96
      }
      if line_count >= max_lines {
        builder.write_string("...\n")
        break
      }
    }
  }
  builder.to_string()
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
    let repo_dir = moonbook_wiki_path(base)
      .join(moonbook_wiki_path(repo))
      .to_string()
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
    let candidate = moonbook_wiki_path(root)
      .join(moonbook_wiki_path(relative))
      .normalize()
      .to_string()
    if @fsx.exists(
        moonbook_wiki_path(candidate)
        .join(moonbook_wiki_path("moontown"))
        .to_string(),
      ) ||
      @fsx.exists(
        moonbook_wiki_path(candidate)
        .join(moonbook_wiki_path("moonclaw"))
        .to_string(),
      ) ||
      @fsx.exists(
        moonbook_wiki_path(candidate)
        .join(moonbook_wiki_path("moonbook"))
        .to_string(),
      ) {
      return candidate
    }
  }
  let current = @env.current_dir().unwrap_or(root)
  let current_parent = moonbook_wiki_path(current)
    .join(moonbook_wiki_path(".."))
    .normalize()
    .to_string()
  if @fsx.exists(
      moonbook_wiki_path(current_parent)
      .join(moonbook_wiki_path("moontown"))
      .to_string(),
    ) ||
    @fsx.exists(
      moonbook_wiki_path(current_parent)
      .join(moonbook_wiki_path("moonclaw"))
      .to_string(),
    ) ||
    @fsx.exists(
      moonbook_wiki_path(current_parent)
      .join(moonbook_wiki_path("moonbook"))
      .to_string(),
    ) {
    current_parent
  } else {
    moonbook_wiki_path(root)
    .join(moonbook_wiki_path(".."))
    .normalize()
    .to_string()
  }
}

///|
async fn bootstrap_repo_candidate_files(repo_dir : String) -> Array[String] {
  let files : Array[String] = []
  for
    relative in [
      "README.md", "README.mbt.md", "AGENTS.md", "moon.mod.json", "cmd/main/main.mbt",
    ] {
    let absolute = moonbook_wiki_path(repo_dir)
      .join(moonbook_wiki_path(relative))
      .to_string()
    if @fsx.exists(absolute) {
      files.push(absolute)
    }
  }
  files
}

///|
async fn resolve_skill_paths(root : String, task : BookTask) -> Array[String] {
  let normalized = @pathx.normalize(root)
  let selected : Array[String] = []
  let candidates = task_skill_names(task)
  for name in candidates {
    ensure_seed_skill_available(normalized, name)
    let path = moonbook_wiki_path(normalized)
      .join(moonbook_wiki_path("skills/\{name}/SKILL.md"))
      .to_string()
    if @fsx.exists(path) {
      selected.push(relative_to_root(path, normalized))
    }
  }
  let resolver = moonbook_wiki_path(normalized)
    .join(moonbook_wiki_path("RESOLVER.md"))
    .to_string()
  if @fsx.exists(resolver) {
    selected.push(relative_to_root(resolver, normalized))
  }
  selected
}

///|
async fn ensure_seed_skill_available(root : String, name : String) -> Unit {
  let destination = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("skills/\{name}"))
    .to_string()
  let skill_path = moonbook_wiki_path(destination)
    .join(moonbook_wiki_path("SKILL.md"))
    .to_string()
  if @fsx.exists(skill_path) {
    return
  }
  let source = moonbook_wiki_path(seed_module_root())
    .join(moonbook_wiki_path("seed/wiki/skills/\{name}"))
    .to_string()
  if !@fsx.exists(source) {
    return
  }
  @fsx.make_directory(destination, recursive=true, exists_ok=true)
  copy_seed_tree(source, destination)
}

///|
fn task_skill_names(task : BookTask) -> Array[String] {
  let names : Array[String] = []
  let kinds = [task.kind]
  for kind in kinds {
    match kind {
      "standing-watch" => {
        names.push("standing-watch")
        names.push("source-diarize")
        names.push("claim-audit")
        names.push("synthesis-revise")
        names.push("wiki-memory")
        names.push("wiki-review")
        names.push("query-promote")
      }
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
        names.push("research-report")
        names.push("web-first-research")
        names.push("repo-source-materialize")
        names.push("index-maintain")
      }
      "source_materialize" => {
        names.push("wiki-ingest")
        names.push("source-diarize")
        names.push("repo-source-materialize")
        names.push("research-report")
        names.push("entity-revise")
        names.push("concept-revise")
        names.push("claim-audit")
        names.push("index-maintain")
      }
      "knowledge_revise" => {
        names.push("entity-revise")
        names.push("concept-revise")
        names.push("synthesis-revise")
        names.push("repo-source-materialize")
        names.push("research-report")
        names.push("claim-audit")
        names.push("contradiction-review")
        names.push("index-maintain")
      }
      "marketing_project" => {
        names.push("wiki-marketing")
        names.push("research-report")
        names.push("claim-audit")
        names.push("review-decision")
      }
      "review_finalize" => {
        names.push("wiki-review")
        names.push("review-decision")
        names.push("contradiction-review")
        names.push("claim-audit")
        names.push("research-report")
        names.push("memory-prune")
      }
      "document-reverse-engineer" => {
        names.push("document-reverse-engineer")
        names.push("synthesis-revise")
        names.push("claim-audit")
        names.push("wiki-memory")
        names.push("wiki-review")
      }
      "course_outline" => {
        names.push("wiki-course")
        names.push("source-diarize")
        names.push("index-maintain")
      }
      "course_workbook" => {
        names.push("wiki-course")
        names.push("claim-audit")
        names.push("index-maintain")
      }
      "course_project" => {
        names.push("wiki-course")
        names.push("synthesis-revise")
        names.push("index-maintain")
        names.push("wiki-memory")
      }
      "course_review" => {
        names.push("wiki-course")
        names.push("wiki-review")
        names.push("review-decision")
      }
      "planbook_context" => {
        names.push("planbook")
        names.push("wiki-memory")
        names.push("index-maintain")
      }
      "planbook_write" => {
        names.push("planbook")
        names.push("wiki-memory")
        names.push("index-maintain")
      }
      "planbook_review" => {
        names.push("planbook")
        names.push("wiki-review")
        names.push("review-decision")
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
        names.push("research-report")
        names.push("query-promote")
        names.push("memory-prune")
      }
      _ => {
        names.push("wiki-query")
        names.push("query-promote")
        names.push("claim-audit")
        if task.prompt.to_lower().contains("research") ||
          task.prompt.to_lower().contains("report") ||
          task.prompt.to_lower().contains("evidence") ||
          task.prompt.to_lower().contains("synthesis") {
          names.push("research-report")
        }
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
  let dir = moonbook_wiki_path(@pathx.normalize(root))
    .join(moonbook_wiki_path("skills"))
    .to_string()
  let paths : Array[String] = []
  if !@fsx.exists(dir) {
    return paths
  }
  for child in @fsx.list_directory(dir) {
    let candidate = moonbook_wiki_path(dir)
      .join(moonbook_wiki_path(child))
      .join(moonbook_wiki_path("SKILL.md"))
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
    let line = raw.trim().to_owned()
    if line.has_prefix("name:") {
      return line.strip_prefix("name:").unwrap_or(line).trim().to_owned()
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
  } else if normalized.contains("/skills/planbook/") {
    "planbook"
  } else if normalized.contains("/skills/standing-watch/") {
    "standing-watch"
  } else if normalized.contains("/skills/research-report/") {
    "research-report"
  } else if normalized.contains("/skills/document-reverse-engineer/") {
    "document-reverse-engineer"
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
    moonbook_wiki_path(normalized).basename().to_owned()
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
      .to_owned()
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
