///|
// Goal acceptance, semantic task planning, and external task resolution helpers.

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
      "Load `skills/wiki-ingest/SKILL.md`, `skills/source-diarize/SKILL.md`, and `skills/research-report/SKILL.md`. Treat bootstrap_gather as a fan-out phase, not a single sweep. Split the work into 2 to 4 bounded gather lanes such as repo-doc discovery, implementation evidence, architecture/topology notes, and cross-project linkage. Each lane must inspect only a small high-signal slice, write or contribute to concrete raw/bootstrap packets with provenance, evidence bullets, source-path notes, and report explicit blockers when its lane is weak. Success means writing `raw/bootstrap/research-question.md`, `raw/bootstrap/search-log.md`, `raw/bootstrap/source-screen.md`, and `raw/bootstrap/local-sources.md`, plus enough gathered material for source materialization and `raw/bootstrap/deep-report.md`. If web_search or web_fetch is unavailable, record that limitation in the search log instead of silently running local-only. Blockers are only scaffolding, placeholders, missing substantive source paths, missing required research artifacts, or gather outputs that are still too weak to hand off.",
      [
        "../raw/README.md", "../raw/bootstrap/", "synthesis/map.md", "synthesis/maintenance-plan.md",
      ],
      true,
    ),
    bootstrap_phase_task(
      goal_id,
      goal,
      "source_materialize",
      "Prepare source materialization evidence",
      90,
      "Load `skills/wiki-ingest/SKILL.md`. Use the gathered bootstrap packets to finish the source evidence envelope, especially `raw/bootstrap/evidence-matrix.md` and stable source ids. Do not claim ownership of durable `wiki/sources/*.md` writes; MoonBook will materialize those pages from the raw research envelope after persistence. Blockers are weak packets, placeholder sources, missing evidence matrix, or no source material strong enough for MoonBook materialization.",
      [
        "../raw/bootstrap/evidence-matrix.md", "../raw/bootstrap/source-screen.md",
      ],
      true,
    ),
    bootstrap_phase_task(
      goal_id,
      goal,
      "knowledge_revise",
      "Prepare knowledge revision evidence",
      80,
      "Load `skills/entity-revise/SKILL.md`, `skills/concept-revise/SKILL.md`, `skills/synthesis-revise/SKILL.md`, `skills/claim-audit/SKILL.md`, and `skills/research-report/SKILL.md`. Prepare ontology and synthesis recommendations in `raw/bootstrap/synthesis-brief.md`, and write a long-form `raw/bootstrap/deep-report.md` using the evidence matrix. Do not write marketing copy in this phase; MoonBook schedules a separate marketing_project phase with `skills/wiki-marketing/SKILL.md` so buyer-facing copy stays focused. Do not write durable entity, concept, claim, or synthesis pages directly unless explicitly asked; MoonBook owns those durable wiki writes. Blockers are unsupported claims, missing synthesis brief, missing deep report, unresolved source contradictions, or no safe revision target.",
      [
        "../raw/bootstrap/synthesis-brief.md", "../raw/bootstrap/evidence-matrix.md",
        "../raw/bootstrap/deep-report.md", "synthesis/map.md",
      ],
      true,
    ),
    bootstrap_phase_task(
      goal_id,
      goal,
      "marketing_project",
      "Write product marketing brief",
      75,
      "Load only `skills/wiki-marketing/SKILL.md` plus the prepared research artifacts. Write `raw/bootstrap/marketing-brief.md` as buyer-facing product marketing, not a plan, audit, evidence log, or implementation summary. Use the exact skeleton from the skill. The only accepted `##` headings are: The Problem, The Product, Why It Wins, What You Can Ship, Who It Is For, Proof Points, Objections, Next Step. Reject and rewrite if any other `##` heading appears. Do not mention this task, provider execution, ReviewQueued, source IDs, raw paths, artifact contracts, or internal planning headings in the visible copy. Translate evidence into buyer value. Blockers are missing deep-report/evidence material, invalid marketing heading structure, or claims that cannot be supported without backend leakage.",
      [
        "../raw/bootstrap/deep-report.md", "../raw/bootstrap/evidence-matrix.md",
        "../raw/bootstrap/synthesis-brief.md", "../raw/bootstrap/marketing-brief.md",
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
  } else if normalized.contains("marketing") || normalized.contains("market") {
    Some("marketing_project")
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
