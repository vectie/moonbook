///|
// Skill selector, baseline resolution, and diff summarization helpers.

fn resolve_skill_selector(
  records : Array[SkillRecord],
  name : String,
) -> SkillRecord raise {
  let (normalized_name, extension_filter) = parse_skill_selector(name)
  let matches : Array[SkillRecord] = []
  for record in records {
    let record_name = record.name.to_lower().to_string()
    let basename = @path.Path(@pathx.dirname(record.path).to_string())
      .basename()
      .to_string()
      .to_lower()
      .to_string()
    let extension_matches = match extension_filter {
      Some(extension) => record.extension == Some(extension)
      None => true
    }
    if extension_matches &&
      (record_name == normalized_name || basename == normalized_name) {
      matches.push(record)
    }
  }
  guard !matches.is_empty() else { fail("no matching skill") }
  if matches.length() == 1 {
    return matches[0]
  }
  let workspace_matches = matches.filter(fn(record) {
    record.scope == "workspace"
  })
  if workspace_matches.length() == 1 {
    return workspace_matches[0]
  }
  let core_matches = matches.filter(fn(record) { record.scope == "seed-core" })
  if core_matches.length() == 1 {
    return core_matches[0]
  }
  let candidates = matches.map(fn(record) {
    let ext = record.extension.unwrap_or("-")
    "\{record.scope}:\{ext}:\{record.path}"
  })
  let joined = candidates.join(", ")
  fail("ambiguous skill selector \{name}: \{joined}")
}

///|
fn resolve_skill_baseline(
  records : Array[SkillRecord],
  selected : SkillRecord,
) -> SkillRecord? {
  if selected.scope == "workspace" {
    let seeded = records.filter(fn(record) {
      record.scope != "workspace" && record.name == selected.name
    })
    let core = seeded.filter(fn(record) { record.scope == "seed-core" })
    if core.length() == 1 {
      return Some(core[0])
    }
    if seeded.length() == 1 {
      return Some(seeded[0])
    }
    None
  } else {
    let workspace = records.filter(fn(record) {
      record.scope == "workspace" && record.name == selected.name
    })
    if workspace.length() == 1 {
      Some(workspace[0])
    } else {
      None
    }
  }
}

///|
priv struct SkillDiffSummary {
  compared_line_count : Int
  changed_line_count : Int
  selected_only_line_count : Int
  baseline_only_line_count : Int
  first_change_line : Int?
  selected_excerpt : Array[String]
  baseline_excerpt : Array[String]
  diff_summary : String
}

///|
fn summarize_skill_diff(
  selected_text : String,
  baseline_text : String,
) -> SkillDiffSummary {
  let selected_lines : Array[String] = []
  for line in selected_text.split("\n") {
    selected_lines.push(line.to_string())
  }
  let baseline_lines : Array[String] = []
  for line in baseline_text.split("\n") {
    baseline_lines.push(line.to_string())
  }
  let compared_line_count = if selected_lines.length() < baseline_lines.length() {
    selected_lines.length()
  } else {
    baseline_lines.length()
  }
  let mut changed_line_count = 0
  let mut first_change_line : Int? = None
  let mut index = 0
  while index < compared_line_count {
    if selected_lines[index] != baseline_lines[index] {
      changed_line_count += 1
      if first_change_line is None {
        first_change_line = Some(index + 1)
      }
    }
    index += 1
  }
  let selected_only_line_count = if selected_lines.length() >
    compared_line_count {
    selected_lines.length() - compared_line_count
  } else {
    0
  }
  let baseline_only_line_count = if baseline_lines.length() >
    compared_line_count {
    baseline_lines.length() - compared_line_count
  } else {
    0
  }
  let anchor = match first_change_line {
    Some(line) => line
    None =>
      if selected_only_line_count > 0 || baseline_only_line_count > 0 {
        compared_line_count + 1
      } else {
        1
      }
  }
  let selected_excerpt = excerpt_lines(selected_text, anchor, 8)
  let baseline_excerpt = excerpt_lines(baseline_text, anchor, 8)
  let diff_summary = if changed_line_count == 0 &&
    selected_only_line_count == 0 &&
    baseline_only_line_count == 0 {
    "The selected skill matches its baseline line-for-line."
  } else {
    "Compared \{compared_line_count} shared lines; changed=\{changed_line_count}, selected-only=\{selected_only_line_count}, baseline-only=\{baseline_only_line_count}."
  }
  {
    compared_line_count,
    changed_line_count,
    selected_only_line_count,
    baseline_only_line_count,
    first_change_line,
    selected_excerpt,
    baseline_excerpt,
    diff_summary,
  }
}

///|
fn excerpt_lines(
  text : String,
  anchor_line : Int,
  radius : Int,
) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_string())
  }
  let start = if anchor_line - 1 <= 0 { 0 } else { anchor_line - 1 }
  let end = if start + radius > lines.length() {
    lines.length()
  } else {
    start + radius
  }
  let excerpt : Array[String] = []
  let mut index = start
  while index < end {
    excerpt.push("\{index + 1} | \{lines[index]}")
    index += 1
  }
  excerpt
}

///|
