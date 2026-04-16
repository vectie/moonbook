///|
struct JourneyEntry {
  task_id : String
  stage : String
  summary : String
  status : String
  evidence_id : String
  highlights : Array[String]
} derive(Show, Eq)

///|
fn journey_relative_page() -> String {
  "history/journey.md"
}

///|
async fn ensure_journey_page(workspace : Paths) -> String {
  let relative = journey_relative_page()
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  if !@fsx.exists(absolute) {
    @fsx.write_to_file(absolute, journey_text(), create=0o644)
    update_summary(workspace.summary_path, "Journey", relative)
    update_index_section(
      @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
      "Core Pages",
      "Journey",
      relative,
      "compact operator timeline of major runs, decisions, failures, and promoted work",
    )
  }
  relative
}

///|
fn journey_text() -> String {
  "# Journey\n\n" +
  "A compact timeline of major book runs, promoted findings, failures, and open loops.\n\n" +
  "## Entries\n\n" +
  "_None yet._\n"
}

///|
async fn append_journey_entry(
  workspace : Paths,
  result : BookResult,
  evidence_id : String,
  review_queued : Bool,
  updated_pages : Array[String],
) -> String {
  let relative = ensure_journey_page(workspace)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  let current = @fsx.read_file(absolute)
  let block = journey_entry_block(
    result, evidence_id, review_queued, updated_pages,
  )
  let next = upsert_journey_block(current, result.task_id, block)
  @fsx.write_to_file(absolute, next, create=0o644)
  relative
}

///|
fn journey_entry_block(
  result : BookResult,
  evidence_id : String,
  review_queued : Bool,
  updated_pages : Array[String],
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("### \{result.task_id}\n\n")
  builder.write_string("- Stage: `\{journey_stage_label(result.task_id)}`\n")
  builder.write_string(
    "- Status: `\{journey_status_label(result, review_queued)}`\n",
  )
  builder.write_string("- Summary: \{clamp_excerpt(result.summary)}\n")
  builder.write_string("- Evidence: `\{evidence_id}`\n")
  let highlights = journey_highlights(result, updated_pages)
  if !highlights.is_empty() {
    builder.write_string("- Highlights:\n")
    for item in highlights {
      builder.write_string("  - \{item}\n")
    }
  }
  let open_loops = journey_open_loops(result, review_queued)
  if !open_loops.is_empty() {
    builder.write_string("- Open loops:\n")
    for item in open_loops {
      builder.write_string("  - \{item}\n")
    }
  }
  builder.write_string("\n")
  builder.to_string()
}

///|
fn journey_stage_label(task_id : String) -> String {
  match infer_task_kind_from_external_id(task_id) {
    Some(kind) => kind
    None => "run"
  }
}

///|
fn journey_status_label(result : BookResult, review_queued : Bool) -> String {
  if review_queued || result.requires_review {
    "pending-review"
  } else if result.notify_town {
    "escalated"
  } else {
    "settled"
  }
}

///|
fn journey_highlights(
  result : BookResult,
  updated_pages : Array[String],
) -> Array[String] {
  let highlights : Array[String] = []
  for page in updated_pages {
    if page.has_suffix("index.md") ||
      page.has_suffix("log.md") ||
      page == "reviews/pending.md" {
      continue
    }
    highlights.push("updated `wiki/\{page}`")
    if highlights.length() >= 4 {
      break
    }
  }
  if highlights.is_empty() && !result.artifacts.is_empty() {
    for artifact in result.artifacts {
      highlights.push("produced `\{artifact}`")
      if highlights.length() >= 4 {
        break
      }
    }
  }
  highlights
}

///|
fn journey_open_loops(
  result : BookResult,
  review_queued : Bool,
) -> Array[String] {
  let loops : Array[String] = []
  if review_queued || result.requires_review {
    loops.push("promotion review is still required")
  }
  if result.notify_town {
    loops.push("town-level follow-up should consume this result")
  }
  if result.artifacts.is_empty() {
    loops.push("no durable artifact paths were reported")
  }
  loops
}

///|
fn upsert_journey_block(
  content : String,
  task_id : String,
  block : String,
) -> String {
  let header = "### \{task_id}"
  if !content.contains(header) {
    return append_section_block(content, "## Entries", block)
  }
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let replacement = lines_array(block)
  let mut skipping = false
  let mut inserted = false
  for line in lines {
    if line == header {
      if !inserted {
        for replacement_line in replacement {
          rebuilt.push(replacement_line)
        }
        inserted = true
      }
      skipping = true
      continue
    }
    if skipping && line.has_prefix("### ") {
      skipping = false
    }
    if !skipping {
      rebuilt.push(line)
    }
  }
  if !inserted {
    for replacement_line in replacement {
      rebuilt.push(replacement_line)
    }
  }
  rebuilt.join("\n")
}

///|
async fn recent_journey_entries(
  root : String,
  limit? : Int = 4,
) -> Array[JourneyEntry] {
  let workspace = workspace_paths(root)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(journey_relative_page()))
    .to_string()
  if !@fsx.exists(absolute) {
    return []
  }
  let lines = lines_array(@fsx.read_file(absolute))
  let blocks : Array[String] = []
  let builder = StringBuilder::new()
  let mut in_block = false
  for line in lines {
    if line.has_prefix("### ") {
      if in_block {
        blocks.push(builder.to_string())
        builder.reset()
      }
      in_block = true
    }
    if in_block {
      builder.write_string(line)
      builder.write_char('\n')
    }
  }
  if in_block {
    blocks.push(builder.to_string())
  }
  let entries : Array[JourneyEntry] = []
  for block in blocks {
    if entries.length() >= limit {
      break
    }
    let task_id = parse_journey_header(block)
    if task_id.is_empty() {
      continue
    }
    entries.push({
      task_id,
      stage: journey_block_field(block, "- Stage: `").unwrap_or("run"),
      summary: journey_block_field(block, "- Summary: ").unwrap_or(
        "No summary.",
      ),
      status: journey_block_field(block, "- Status: `").unwrap_or("settled"),
      evidence_id: journey_block_field(block, "- Evidence: `").unwrap_or(""),
      highlights: journey_block_list(block, "- Highlights:"),
    })
  }
  entries
}

///|
fn parse_journey_header(block : String) -> String {
  for raw in block.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix("### ") {
      return line[4:].trim().to_string()
    }
  }
  ""
}

///|
fn journey_block_field(block : String, prefix : String) -> String? {
  for raw in block.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix(prefix) {
      if prefix.has_suffix("`") {
        return Some(
          line
          .strip_prefix(prefix)
          .unwrap_or(line)
          .strip_suffix("`")
          .unwrap_or(line)
          .to_string(),
        )
      }
      return Some(line.strip_prefix(prefix).unwrap_or(line).to_string())
    }
  }
  None
}

///|
fn journey_block_list(block : String, header : String) -> Array[String] {
  let items : Array[String] = []
  let mut collecting = false
  for raw in block.split("\n") {
    let line = raw.trim().to_string()
    if line == header {
      collecting = true
      continue
    }
    if collecting && line.has_prefix("- ") && !line.has_prefix("- Open loops:") {
      break
    }
    if collecting && line.has_prefix("  - ") {
      items.push(line.strip_prefix("  - ").unwrap_or(line).to_string())
    }
  }
  items
}

///|
test "journey block upsert replaces existing task entry" {
  let content = "# Journey\n\n## Entries\n\n### task-a\n\n- Stage: `run`\n\n"
  let block = "### task-a\n\n- Stage: `analysis`\n\n"
  let next = upsert_journey_block(content, "task-a", block)
  assert_true(next.contains("- Stage: `analysis`"))
  assert_true(!next.contains("- Stage: `run`"))
}

///|
async test "journey recent entries reads newest first" {
  let root = "/tmp/moonbook-journey-entries"
  ignore(init_workspace(root))
  let workspace = workspace_paths(root)
  ignore(
    append_journey_entry(
      workspace,
      {
        task_id: "goal-a-ingest",
        summary: "First run.",
        artifacts: ["wiki/sources/a.md"],
        memory_candidates: [],
        requires_review: false,
        notify_town: false,
      },
      "EV-a",
      false,
      ["sources/a.md"],
    ),
  )
  ignore(
    append_journey_entry(
      workspace,
      {
        task_id: "goal-b-analysis",
        summary: "Second run.",
        artifacts: ["wiki/queries/b.md"],
        memory_candidates: [],
        requires_review: true,
        notify_town: false,
      },
      "EV-b",
      true,
      ["queries/b.md"],
    ),
  )
  let entries = recent_journey_entries(root, limit=2)
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].task_id, "goal-b-analysis")
  assert_eq(entries[1].task_id, "goal-a-ingest")
}
