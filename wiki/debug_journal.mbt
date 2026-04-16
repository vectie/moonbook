///|
fn debug_journal_relative_page() -> String {
  "history/debug-journal.md"
}

///|
async fn ensure_debug_journal_page(workspace : Paths) -> String {
  let relative = debug_journal_relative_page()
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  if !@fsx.exists(absolute) {
    @fsx.write_to_file(absolute, debug_journal_text(), create=0o644)
    update_summary(workspace.summary_path, "Debug Journal", relative)
    update_index_section(
      @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
      "Core Pages",
      "Debug Journal",
      relative,
      "detailed run-by-run debug notes, intermediate material preparation, and unresolved blockers",
    )
  }
  relative
}

///|
fn debug_journal_text() -> String {
  "# Debug Journal\n\n" +
  "Detailed run-by-run notes for debugging keeper decomposition, worker gathering, material preparation, and promotion quality.\n\n" +
  "## Entries\n\n" +
  "_None yet._\n"
}

///|
async fn append_debug_journal_entry(
  workspace : Paths,
  result : BookResult,
  evidence_id : String,
  review_queued : Bool,
  updated_pages : Array[String],
) -> String {
  let relative = ensure_debug_journal_page(workspace)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  let current = @fsx.read_file(absolute)
  let block = debug_journal_entry_block(
    result, evidence_id, review_queued, updated_pages,
  )
  let next = upsert_debug_journal_block(current, result.task_id, block)
  @fsx.write_to_file(absolute, next, create=0o644)
  relative
}

///|
fn debug_journal_entry_block(
  result : BookResult,
  evidence_id : String,
  review_queued : Bool,
  updated_pages : Array[String],
) -> String {
  let builder = StringBuilder::new()
  let stage = infer_task_kind_from_external_id(result.task_id).unwrap_or("run")
  builder.write_string("### \{result.task_id}\n\n")
  builder.write_string("- Stage: `\{stage}`\n")
  builder.write_string("- Summary: \{result.summary}\n")
  builder.write_string("- Evidence: `\{evidence_id}`\n")
  builder.write_string("- Review queued: `\{review_queued}`\n")
  builder.write_string("- Notify town: `\{result.notify_town}`\n")
  builder.write_string(
    "- Result class: `\{debug_result_class(result, updated_pages)}`\n",
  )
  if !updated_pages.is_empty() {
    builder.write_string("- Updated pages:\n")
    for page in updated_pages {
      builder.write_string("  - `\{debug_workspace_relative_path(page)}`\n")
    }
  }
  if !result.artifacts.is_empty() {
    builder.write_string("- Reported artifacts:\n")
    for artifact in result.artifacts {
      builder.write_string("  - `\{artifact}`\n")
    }
  }
  if !result.memory_candidates.is_empty() {
    builder.write_string("- Memory candidates:\n")
    for candidate in result.memory_candidates {
      let target = candidate.target_page.unwrap_or("null")
      builder.write_string(
        "  - \{candidate.title} | kind=`\{candidate.kind}` durable=`\{candidate.durable}` target=`\{target}`\n",
      )
    }
  }
  let debug_notes = debug_open_loops(result, updated_pages)
  if !debug_notes.is_empty() {
    builder.write_string("- Debug notes:\n")
    for note in debug_notes {
      builder.write_string("  - \{note}\n")
    }
  }
  builder.write_string("\n")
  builder.to_string()
}

///|
fn debug_workspace_relative_path(path : String) -> String {
  if path.has_prefix("wiki/") || path.has_prefix("keeper/") {
    path
  } else {
    "wiki/\{path}"
  }
}

///|
fn debug_result_class(
  result : BookResult,
  updated_pages : Array[String],
) -> String {
  if updated_pages.any(fn(page) {
      page.has_prefix("sources/") ||
      page.has_prefix("entities/") ||
      page.has_prefix("concepts/") ||
      page.has_prefix("queries/")
    }) ||
    result.artifacts.any(fn(path) {
      path.contains("wiki/sources/") ||
      path.contains("wiki/entities/") ||
      path.contains("wiki/concepts/") ||
      path.contains("wiki/queries/")
    }) {
    "substantive"
  } else {
    "administrative"
  }
}

///|
fn debug_open_loops(
  result : BookResult,
  updated_pages : Array[String],
) -> Array[String] {
  let notes : Array[String] = []
  if result.artifacts.is_empty() {
    notes.push("no durable artifact paths were reported")
  }
  if !updated_pages.any(fn(page) {
      page.has_prefix("sources/") ||
      page.has_prefix("entities/") ||
      page.has_prefix("concepts/") ||
      page.has_prefix("queries/")
    }) {
    notes.push("no substantive source/entity/concept/query pages were updated")
  }
  if result.memory_candidates.is_empty() {
    notes.push("no structured memory candidates were returned")
  }
  notes
}

///|
fn upsert_debug_journal_block(
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
test "debug result class marks substantive outputs" {
  let result : BookResult = {
    task_id: "goal-ingest",
    summary: "Updated source page.",
    artifacts: ["wiki/sources/demo.md"],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  }
  assert_eq(debug_result_class(result, ["sources/demo.md"]), "substantive")
}

///|
test "debug result class marks administrative outputs" {
  let result : BookResult = {
    task_id: "goal-ingest",
    summary: "Completed provider task.",
    artifacts: [],
    memory_candidates: [],
    requires_review: false,
    notify_town: false,
  }
  assert_eq(
    debug_result_class(result, ["history/journey.md"]),
    "administrative",
  )
}

///|
test "debug workspace paths keep keeper files readable" {
  assert_eq(
    debug_workspace_relative_path("synthesis/observations.md"),
    "wiki/synthesis/observations.md",
  )
  assert_eq(
    debug_workspace_relative_path("keeper/WORKING.md"),
    "keeper/WORKING.md",
  )
}
