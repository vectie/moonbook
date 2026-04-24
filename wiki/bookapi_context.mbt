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

///|
// Worker context hydration helpers, skill resolution, and memory/context selection.

fn provider_result_contract_lines() -> Array[String] {
  [
    "Return exactly one JSON object.", "Do not output markdown fences or prose outside the JSON object.",
    "Use keys: task_id, summary, artifacts, memory_candidates, requires_review, notify_town.",
    "Set task_id to the active provider task id.", "artifacts must be an array of workspace-relative output paths.",
    "memory_candidates must be an array of objects with kind, title, detail, durable, target_page.",
    "For weak-coverage research goals, follow the MoonBook phases in order: bootstrap_gather, source_materialize, knowledge_revise, marketing_project, review_finalize.",
    "For research bootstrap, artifacts must include raw/bootstrap/research-question.md, raw/bootstrap/search-log.md, raw/bootstrap/source-screen.md, raw/bootstrap/evidence-matrix.md, raw/bootstrap/local-sources.md, raw/bootstrap/synthesis-brief.md, raw/bootstrap/deep-report.md, and raw/bootstrap/marketing-brief.md, or the result must be a structured blocker explaining exactly which files are missing.",
    "For bootstrap ingest, MoonClaw should produce raw/bootstrap research artifacts and should not need to create wiki/* pages; MoonBook owns durable wiki materialization from the research envelope.",
    "If web_search or web_fetch is unavailable, explicitly say so in the blocker and record that limitation in raw/bootstrap/search-log.md or raw/bootstrap/source-screen.md when possible.",
    "Use [] for empty arrays and null for missing target_page.", "For ingest or bootstrap work, generic completion text without substantive artifacts or durable candidates is a blocker, not success.",
    "If ingest work cannot produce the required raw research artifacts, say what material or tool is missing and set requires_review to true.",
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
fn bootstrap_material_task_kind(kind : String) -> Bool {
  kind == "ingest" ||
  kind == "bootstrap_gather" ||
  kind == "source_materialize" ||
  kind == "knowledge_revise" ||
  kind == "marketing_project"
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
    "\n\nLoaded skill body excerpts:\nRead these excerpts as operational instructions, not just metadata. If an excerpt conflicts with the task, follow the explicit research artifact contract above and report the conflict.\n",
  )
  for relative in selected {
    if relative == "RESOLVER.md" {
      continue
    }
    let absolute = @path.Path(normalized).join(@path.Path(relative)).to_string()
    if !@fsx.exists(absolute) {
      builder.write_string("- `\{relative}`: missing from workspace.\n")
      continue
    }
    builder.write_string("\n### `\{relative}`\n")
    let mut line_count = 0
    for raw in @fsx.read_file(absolute).split("\n") {
      let line = raw.to_string()
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
  } else if normalized.contains("/skills/research-report/") {
    "research-report"
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
