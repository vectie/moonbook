///|
fn evidence_relative_page() -> String {
  "synthesis/evidence.md"
}

///|
async fn ensure_evidence_page(workspace : Paths) -> String {
  let relative = evidence_relative_page()
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  if !@fsx.exists(absolute) {
    @fsx.write_to_file(
      absolute,
      "# Evidence\n\nStructured support records for persisted results and promoted knowledge.\n\n## Records\n\n_None yet._\n",
      create=0o644,
    )
    update_summary(workspace.summary_path, "Evidence", relative)
    update_index_section(
      @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
      "Core Pages",
      "Evidence",
      relative,
      "support records for claims, results, and review outcomes",
    )
  }
  relative
}

///|
async fn append_result_evidence(
  workspace : Paths,
  result : BookResult,
) -> String {
  let relative = ensure_evidence_page(workspace)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  let current = @fsx.read_file(absolute)
  let evidence_id = "EV-\{slugify_title(result.task_id)}-\{@async.now().to_int()}"
  let builder = StringBuilder::new()
  let status = if result.requires_review {
    "pending-review"
  } else {
    "accepted"
  }
  builder.write_string("### \{evidence_id}\n\n")
  builder.write_string("- Task ID: `\{result.task_id}`\n")
  builder.write_string("- Status: `\{status}`\n")
  builder.write_string("- Summary: \{keeper_compact_text(result.summary)}\n")
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
        "  - \{candidate.title} | \{candidate.kind} | durable=\{candidate.durable}\n",
      )
    }
  }
  builder.write_string("\n")
  let next = append_section_block(current, "## Records", builder.to_string())
  @fsx.write_to_file(absolute, next, create=0o644)
  evidence_id
}

///|
async fn update_evidence_status(
  workspace : Paths,
  evidence_id : String,
  status : String,
  note : String,
) -> String {
  let relative = ensure_evidence_page(workspace)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  let current = @fsx.read_file(absolute)
  let next = replace_evidence_field(
    append_evidence_note(current, evidence_id, note),
    evidence_id,
    "- Status: `",
    status,
  )
  @fsx.write_to_file(absolute, next, create=0o644)
  relative
}

///|
async fn count_evidence_entries(root : String) -> Int {
  let workspace = workspace_paths(root)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(evidence_relative_page()))
    .to_string()
  if !@fsx.exists(absolute) {
    return 0
  }
  count_heading_entries(@fsx.read_file(absolute))
}

///|
fn replace_evidence_field(
  content : String,
  evidence_id : String,
  prefix : String,
  value : String,
) -> String {
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let mut in_block = false
  for line in lines {
    if line == "### \{evidence_id}" {
      in_block = true
      rebuilt.push(line)
      continue
    }
    if in_block && line.has_prefix("### ") {
      in_block = false
    }
    if in_block && line.has_prefix(prefix) {
      rebuilt.push(prefix + value + "`")
    } else {
      rebuilt.push(line)
    }
  }
  rebuilt.join("\n")
}

///|
fn append_evidence_note(
  content : String,
  evidence_id : String,
  note : String,
) -> String {
  if note.trim().is_empty() {
    return content
  }
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let mut in_block = false
  let mut inserted = false
  for line in lines {
    if line == "### \{evidence_id}" {
      in_block = true
      rebuilt.push(line)
      continue
    }
    if in_block && line.has_prefix("### ") && !inserted {
      rebuilt.push("- Review note: \{note}")
      inserted = true
      in_block = false
    }
    rebuilt.push(line)
  }
  if in_block && !inserted {
    rebuilt.push("- Review note: \{note}")
  }
  rebuilt.join("\n")
}

///|
test "replace evidence field updates status" {
  let content = "# Evidence\n\n## Records\n\n### EV-a\n\n- Status: `pending-review`\n"
  let next = replace_evidence_field(content, "EV-a", "- Status: `", "accepted")
  assert_true(next.contains("- Status: `accepted`"))
}
