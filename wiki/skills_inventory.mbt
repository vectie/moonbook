///|
// Skill inventory, metadata parsing, relationship, and diagnostics helpers.

async fn collect_skill_records(root : String) -> Array[SkillRecord] {
  let records = []
  let workspace_skills_dir = @path.Path(root)
    .join(@path.Path("skills"))
    .to_string()
  push_skill_records(
    records,
    collect_skill_dir_records(
      workspace_skills_dir,
      "workspace",
      "workspace",
      None,
    ),
  )
  let module_root = skill_module_root()
  let seed_core_dir = @path.Path(module_root)
    .join(@path.Path("seed/wiki/skills"))
    .to_string()
  push_skill_records(
    records,
    collect_skill_dir_records(seed_core_dir, "seed-core", "repo-seed", None),
  )
  let extension_seed_root = @path.Path(module_root)
    .join(@path.Path("seed/extensions"))
    .to_string()
  if @fsx.exists(extension_seed_root) {
    for extension_dir in @fsx.list_directory(extension_seed_root) {
      if !(is_directory(extension_dir) catch { _ => false }) {
        continue
      }
      let extension_name = @path.Path(extension_dir).basename().to_string()
      let skills_dir = @path.Path(extension_dir)
        .join(@path.Path("skills"))
        .to_string()
      push_skill_records(
        records,
        collect_skill_dir_records(
          skills_dir,
          "seed-extension",
          "extension-seed",
          Some(extension_name),
        ),
      )
    }
  }
  records
}

///|
fn push_skill_records(
  target : Array[SkillRecord],
  records : Array[SkillRecord],
) -> Unit {
  for record in records {
    target.push(record)
  }
}

///|
async fn collect_skill_dir_records(
  skills_dir : String,
  scope : String,
  origin : String,
  extension : String?,
) -> Array[SkillRecord] {
  if !@fsx.exists(skills_dir) ||
    !(is_directory(skills_dir) catch { _ => false }) {
    return []
  }
  let records = []
  for entry in @fsx.list_directory(skills_dir) {
    if !(is_directory(entry) catch { _ => false }) {
      continue
    }
    let skill_path = @path.Path(entry).join(@path.Path("SKILL.md")).to_string()
    if !@fsx.exists(skill_path) {
      continue
    }
    let text = @fsx.read_file(skill_path)
    let (name, description) = parse_skill_metadata(entry, text)
    records.push({
      id: "\{scope}:\{name}:\{entry}",
      name,
      path: skill_path,
      scope,
      origin,
      source_kind: "skill-dir",
      extension,
      description,
      references: collect_reference_paths(entry, text),
      overrides: [],
      shadowed_by: [],
      line_count: count_lines(text),
    })
  }
  records.sort_by(fn(left, right) {
    (left.name + "|" + left.scope + "|" + left.path).compare(
      right.name + "|" + right.scope + "|" + right.path,
    )
  })
  records
}

///|
fn annotate_skill_relationships(
  records : Array[SkillRecord],
) -> Array[SkillRecord] {
  let annotated = []
  for record in records {
    let overrides = []
    let shadowed_by = []
    for other in records {
      if record.id == other.id || record.name != other.name {
        continue
      }
      if record.scope == "workspace" && other.scope != "workspace" {
        overrides.push(other.scope + ":" + other.path)
      }
      if record.scope != "workspace" && other.scope == "workspace" {
        shadowed_by.push(other.path)
      }
    }
    annotated.push({
      id: record.id,
      name: record.name,
      path: record.path,
      scope: record.scope,
      origin: record.origin,
      source_kind: record.source_kind,
      extension: record.extension,
      description: record.description,
      references: record.references,
      overrides,
      shadowed_by,
      line_count: record.line_count,
    })
  }
  annotated
}

///|
fn duplicate_skill_names(records : Array[SkillRecord]) -> Array[String] {
  let duplicates = []
  for record in records {
    let mut count = 0
    for other in records {
      if other.name == record.name {
        count += 1
      }
    }
    if count > 1 && !duplicates.contains(record.name) {
      duplicates.push(record.name)
    }
  }
  duplicates.sort()
  duplicates
}

///|
async fn collect_missing_reference_paths(
  records : Array[SkillRecord],
) -> Array[String] {
  let missing = []
  for record in records {
    for reference in record.references {
      if !@fsx.exists(reference) && !missing.contains(reference) {
        missing.push(reference)
      }
    }
  }
  missing.sort()
  missing
}

///|
fn parse_skill_metadata(skill_dir : String, text : String) -> (String, String) {
  let fallback_name = @path.Path(skill_dir).basename().to_string()
  let mut name = fallback_name
  let mut description = ""
  let mut in_frontmatter = false
  let mut frontmatter_seen = false
  for line in text.split("\n") {
    let trimmed = line.trim().to_string()
    if trimmed == "---" {
      if !frontmatter_seen {
        in_frontmatter = true
        frontmatter_seen = true
        continue
      }
      if in_frontmatter {
        break
      }
    }
    if !in_frontmatter {
      continue
    }
    if trimmed.has_prefix("name:") {
      name = strip_wrapping_quotes(frontmatter_value(trimmed))
    } else if trimmed.has_prefix("description:") {
      description = strip_wrapping_quotes(frontmatter_value(trimmed))
    }
  }
  (name, description)
}

///|
fn collect_reference_paths(skill_dir : String, text : String) -> Array[String] {
  let references = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    let mut start = 0
    while start < line.length() {
      match line[start:].find("references/") {
        Some(index) => {
          let absolute_index = start + index
          let path = read_reference_token(line, absolute_index)
          let full_path = @path.Path(skill_dir)
            .join(@path.Path(path))
            .to_string()
          if !references.contains(full_path) {
            references.push(full_path)
          }
          start = absolute_index + 11
        }
        None => break
      }
    }
  }
  references.sort()
  references
}

///|
fn read_reference_token(line : String, start : Int) -> String {
  let chars = line.to_array()
  let mut end = start
  while end < chars.length() {
    let ch = chars[end]
    if ch == '`' || ch == ' ' || ch == ')' || ch == '(' || ch == ':' {
      break
    }
    end += 1
  }
  line[start:end].to_string()
}

///|
fn frontmatter_value(line : String) -> String {
  match line.find(":") {
    Some(index) => line[index + 1:].trim().to_string()
    None => ""
  }
}

///|
fn strip_wrapping_quotes(text : String) -> String {
  if text.length() >= 2 &&
    (
      (text[0] == '"' && text[text.length() - 1] == '"') ||
      (text[0] == '\'' && text[text.length() - 1] == '\'')
    ) {
    text[1:text.length() - 1].to_string()
  } else {
    text
  }
}

///|
async fn is_directory(path : String) -> Bool {
  match @fs.kind(path, follow_symlink=false) {
    @fs.FileKind::Directory => true
    _ => false
  }
}

///|
fn count_lines(text : String) -> Int {
  let mut count = 0
  for _ in text.split("\n") {
    count += 1
  }
  count
}

///|
