///|
pub struct SkillRecord {
  id : String
  name : String
  path : String
  scope : String
  origin : String
  source_kind : String
  extension : String?
  description : String
  references : Array[String]
  overrides : Array[String]
  shadowed_by : Array[String]
  line_count : Int
} derive(Show, ToJson)

///|
pub struct SkillDoctorReport {
  root : String
  total_count : Int
  workspace_count : Int
  seed_core_count : Int
  seed_extension_count : Int
  duplicate_names : Array[String]
  missing_reference_paths : Array[String]
  warnings : Array[String]
} derive(Show, ToJson)

///|
pub struct SkillInstallResult {
  root : String
  name : String
  destination_path : String
  source_path : String?
  action : String
} derive(Show, ToJson)

///|
pub struct SkillCompareResult {
  root : String
  name : String
  selected_path : String
  selected_scope : String
  baseline_path : String?
  baseline_scope : String?
  status : String
  summary : String
  compared_line_count : Int
  changed_line_count : Int
  selected_only_line_count : Int
  baseline_only_line_count : Int
  first_change_line : Int?
  selected_excerpt : Array[String]
  baseline_excerpt : Array[String]
} derive(Show, ToJson)

///|
pub async fn list_skills(root : String) -> Array[SkillRecord] {
  let normalized_root = @pathx.normalize(root)
  let records = collect_skill_records(normalized_root)
  annotate_skill_relationships(records)
}

///|
pub async fn find_skill(root : String, name : String) -> SkillRecord? {
  let normalized = name.trim().to_lower().to_string()
  let records = list_skills(root)
  for record in records {
    let record_name = record.name.to_lower().to_string()
    let basename = @path.Path(record.path)
      .basename()
      .to_string()
      .to_lower()
      .to_string()
    if record_name == normalized || basename == normalized {
      return Some(record)
    }
  }
  None
}

///|
pub async fn doctor_skills(root : String) -> SkillDoctorReport {
  let normalized_root = @pathx.normalize(root)
  let records = list_skills(normalized_root)
  let duplicate_names = duplicate_skill_names(records)
  let missing_reference_paths = collect_missing_reference_paths(records)
  let warnings = []
  let mut workspace_count = 0
  let mut seed_core_count = 0
  let mut seed_extension_count = 0
  for record in records {
    match record.scope {
      "workspace" => workspace_count += 1
      "seed-core" => seed_core_count += 1
      "seed-extension" => seed_extension_count += 1
      _ => ()
    }
    if record.scope == "workspace" && !record.overrides.is_empty() {
      let overridden = record.overrides.join(", ")
      warnings.push("workspace skill \{record.name} overrides \{overridden}")
    }
    if record.description.is_empty() {
      warnings.push("skill \{record.name} is missing a description")
    }
  }
  for name in duplicate_names {
    warnings.push("duplicate skill name: \{name}")
  }
  {
    root: normalized_root,
    total_count: records.length(),
    workspace_count,
    seed_core_count,
    seed_extension_count,
    duplicate_names,
    missing_reference_paths,
    warnings,
  }
}

///|
pub async fn install_skill(root : String, name : String) -> SkillInstallResult {
  let normalized_root = @pathx.normalize(root)
  let (normalized_name, extension_filter) = parse_skill_selector(name)
  guard !normalized_name.is_empty() else {
    fail("skill name must not be empty")
  }
  let records = list_skills(normalized_root)
  let matches : Array[SkillRecord] = []
  for record in records {
    if record.scope == "workspace" {
      continue
    }
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
  guard !matches.is_empty() else { fail("no seeded skill found for \{name}") }
  let resolved_matches = match extension_filter {
    Some(_) => matches
    None =>
      if matches.length() > 1 {
        let core_matches = matches.filter(fn(record) {
          record.scope == "seed-core"
        })
        if core_matches.length() == 1 {
          [core_matches[0]]
        } else {
          matches
        }
      } else {
        matches
      }
  }
  guard resolved_matches.length() == 1 else {
    let candidates = resolved_matches.map(fn(record) {
      let ext = record.extension.unwrap_or("-")
      "\{record.scope}:\{ext}:\{record.path}"
    })
    let joined = candidates.join(", ")
    fail(
      "ambiguous seeded skill \{name}: \{joined}. Use name@extension to select one explicitly.",
    )
  }
  let record = resolved_matches[0]
  let destination_dir = workspace_skill_dir(normalized_root, record.name)
  guard !@fsx.exists(destination_dir) else {
    fail("workspace skill already exists at \{destination_dir}")
  }
  let source_dir = @pathx.dirname(record.path).to_string()
  copy_skill_tree(source_dir, destination_dir)
  {
    root: normalized_root,
    name: record.name,
    destination_path: destination_dir,
    source_path: Some(source_dir),
    action: "installed",
  }
}

///|
pub async fn scaffold_skill(root : String, name : String) -> SkillInstallResult {
  let normalized_root = @pathx.normalize(root)
  let slug = skill_slug(name)
  guard !slug.is_empty() else {
    fail("skill name must resolve to a non-empty slug")
  }
  let destination_dir = workspace_skill_dir(normalized_root, slug)
  guard !@fsx.exists(destination_dir) else {
    fail("workspace skill already exists at \{destination_dir}")
  }
  @fsx.make_directory(destination_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(
    @path.Path(destination_dir).join(@path.Path("references")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(destination_dir).join(@path.Path("agents")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  let skill_path = @path.Path(destination_dir)
    .join(@path.Path("SKILL.md"))
    .to_string()
  let display_name = skill_slug(name)
  @fsx.write_to_file(
    skill_path,
    scaffold_skill_text(display_name),
    create=0o644,
  )
  {
    root: normalized_root,
    name: display_name,
    destination_path: destination_dir,
    source_path: None,
    action: "scaffolded",
  }
}

///|
pub async fn compare_skill(root : String, name : String) -> SkillCompareResult {
  let normalized_root = @pathx.normalize(root)
  let records = list_skills(normalized_root)
  let selected = resolve_skill_selector(records, name) catch {
    error => fail("no skill found for comparison: \{name}; \{error}")
  }
  let baseline = resolve_skill_baseline(records, selected)
  let selected_text = if @fsx.exists(selected.path) {
    @fsx.read_file(selected.path)
  } else {
    ""
  }
  match baseline {
    Some(record) => {
      let baseline_text = if @fsx.exists(record.path) {
        @fsx.read_file(record.path)
      } else {
        ""
      }
      let summary = summarize_skill_diff(selected_text, baseline_text)
      {
        root: normalized_root,
        name: selected.name,
        selected_path: selected.path,
        selected_scope: selected.scope,
        baseline_path: Some(record.path),
        baseline_scope: Some(record.scope),
        status: if summary.changed_line_count == 0 &&
          summary.selected_only_line_count == 0 &&
          summary.baseline_only_line_count == 0 {
          "in-sync"
        } else {
          "drifted"
        },
        summary: summary.diff_summary,
        compared_line_count: summary.compared_line_count,
        changed_line_count: summary.changed_line_count,
        selected_only_line_count: summary.selected_only_line_count,
        baseline_only_line_count: summary.baseline_only_line_count,
        first_change_line: summary.first_change_line,
        selected_excerpt: summary.selected_excerpt,
        baseline_excerpt: summary.baseline_excerpt,
      }
    }
    None => {
      let line_count = count_lines(selected_text)
      {
        root: normalized_root,
        name: selected.name,
        selected_path: selected.path,
        selected_scope: selected.scope,
        baseline_path: None,
        baseline_scope: None,
        status: "no-baseline",
        summary: "No matching baseline was found for this skill. Compare applies once a workspace override or seeded counterpart exists.",
        compared_line_count: line_count,
        changed_line_count: 0,
        selected_only_line_count: 0,
        baseline_only_line_count: 0,
        first_change_line: None,
        selected_excerpt: excerpt_lines(selected_text, 1, 8),
        baseline_excerpt: [],
      }
    }
  }
}

///|
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
fn skill_module_root() -> String {
  @env.current_dir().unwrap_or(".")
}

///|
fn workspace_skill_dir(root : String, name : String) -> String {
  @path.Path(root)
  .join(@path.Path("skills"))
  .join(@path.Path(skill_slug(name)))
  .to_string()
}

///|
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
fn parse_skill_selector(name : String) -> (String, String?) {
  let normalized = name.trim().to_lower().to_string()
  match normalized.find("@") {
    Some(index) =>
      (
        normalized[:index].to_string(),
        Some(normalized[index + 1:].trim().to_string()),
      )
    None => (normalized, None)
  }
}

///|
async fn copy_skill_tree(
  source_path : String,
  destination_path : String,
) -> Unit {
  match @fs.kind(source_path, follow_symlink=false) {
    @fs.FileKind::Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = @path.Path(child).basename().to_string()
        copy_skill_tree(
          child,
          @path.Path(destination_path).join(@path.Path(child_name)).to_string(),
        )
      }
    }
    _ =>
      @fsx.write_to_file(
        destination_path,
        @fsx.read_file(source_path),
        create=0o644,
      )
  }
}

///|
fn skill_slug(name : String) -> String {
  let builder = StringBuilder::new()
  let mut wrote_dash = false
  let mut wrote_any = false
  for rune in name.to_lower() {
    let ch = rune.to_int()
    if (ch >= 97 && ch <= 122) || (ch >= 48 && ch <= 57) {
      builder.write_char(rune)
      wrote_dash = false
      wrote_any = true
    } else if !wrote_dash && wrote_any {
      builder.write_char('-')
      wrote_dash = true
    }
  }
  let slug = builder.to_string()
  if slug.has_suffix("-") {
    slug[0:slug.length() - 1].to_string()
  } else {
    slug
  }
}

///|
fn scaffold_skill_text(name : String) -> String {
  "---\n" +
  "name: \{name}\n" +
  "description: \"Explain when this skill should be used, what domain it owns, and what outcome it should produce.\"\n" +
  "---\n" +
  "\n" +
  "# \{name}\n" +
  "\n" +
  "This skill owns one narrow capability. Keep the harness thin and put the domain judgment here.\n" +
  "\n" +
  "## Use this skill when\n" +
  "\n" +
  "- the task repeatedly appears in this workspace\n" +
  "- the model needs domain-specific process, not just generic reasoning\n" +
  "- the desired output has a stable shape that should compound over time\n" +
  "- bundled references or scripts materially improve accuracy or speed\n" +
  "\n" +
  "## Do not use this skill when\n" +
  "\n" +
  "- a deterministic CLI command is enough\n" +
  "- the task belongs to another skill with a narrower domain boundary\n" +
  "- the request is one-off and should not become permanent operating procedure\n" +
  "\n" +
  "## Inputs\n" +
  "\n" +
  "- objective: the concrete user or system goal\n" +
  "- workspace root: where files should be read or written\n" +
  "- relevant constraints: quality bar, safety limits, scope limits, approval rules\n" +
  "- available evidence: pages, files, APIs, logs, or artifacts that should anchor the work\n" +
  "\n" +
  "## Outputs\n" +
  "\n" +
  "- durable output paths that were created or updated\n" +
  "- a compact summary of what changed and why\n" +
  "- unresolved risks, gaps, or follow-up needs\n" +
  "- explicit blocker language if the task cannot be completed safely\n" +
  "\n" +
  "## Workflow\n" +
  "\n" +
  "1. Confirm the domain boundary.\n" +
  "   Refuse to sprawl into adjacent concerns. Say what this skill owns and what it does not own.\n" +
  "2. Load only the minimum supporting context.\n" +
  "   Read the exact workspace files or bundled references that materially change the answer.\n" +
  "3. Separate latent and deterministic work.\n" +
  "   Use judgment for synthesis, classification, prioritization, and gap detection. Use code, scripts, or CLI commands for repeatable file work.\n" +
  "4. Produce durable artifacts.\n" +
  "   Prefer updating real files over leaving useful work trapped in prose.\n" +
  "5. Validate the result.\n" +
  "   Check that paths exist, links resolve, formatting is sane, and the output contract was satisfied.\n" +
  "6. Report with precision.\n" +
  "   Name the exact files touched, what changed, and what still needs review.\n" +
  "\n" +
  "## Quality bar\n" +
  "\n" +
  "- do not claim success without durable artifacts or a verified deterministic result\n" +
  "- keep summaries specific enough to debug later\n" +
  "- preserve source-of-truth boundaries\n" +
  "- make contradictions and uncertainty explicit\n" +
  "- avoid hidden side effects outside the declared write scope\n" +
  "\n" +
  "## Suggested references\n" +
  "\n" +
  "- put detailed domain rules under `references/`\n" +
  "- keep examples under `references/examples.md` if they help future runs\n" +
  "- add scripts under `scripts/` only when deterministic repetition justifies them\n" +
  "\n" +
  "## Example invocation\n" +
  "\n" +
  "Objective: explain a repeated domain task and materialize the correct files.\n" +
  "\n" +
  "Expected behavior:\n" +
  "\n" +
  "- inspect the minimum required inputs\n" +
  "- apply the domain workflow above\n" +
  "- write or update the intended files\n" +
  "- return a concise summary with explicit output paths\n" +
  "\n" +
  "## Maintenance notes\n" +
  "\n" +
  "- if this skill grows past a lean operating guide, split detailed material into `references/`\n" +
  "- if the same code is being repeated, move it into `scripts/`\n" +
  "- if the domain boundary changes, update the description first so the resolver still triggers correctly\n"
}

///|
test "parse skill metadata reads frontmatter fields" {
  let (name, description) = parse_skill_metadata(
    "/tmp/wiki-ingest", "---\nname: wiki-ingest\ndescription: test skill\n---\n# Body\n",
  )
  assert_eq(name, "wiki-ingest")
  assert_eq(description, "test skill")
}

///|
test "collect reference paths extracts bundled references" {
  let refs = collect_reference_paths(
    "/tmp/skill", "- `references/raw-first-contract.md`\n- use `references/bootstrap-examples.md`\n",
  )
  assert_eq(refs, [
    "/tmp/skill/references/bootstrap-examples.md", "/tmp/skill/references/raw-first-contract.md",
  ])
}

///|
test "skill slug normalizes punctuation and case" {
  assert_eq(skill_slug("Wiki Ingest"), "wiki-ingest")
  assert_eq(skill_slug("Source / Diarize!"), "source-diarize")
}

///|
async test "install skill copies seeded skill tree into workspace" {
  let root = "/tmp/moonbook-skill-install-\{@async.now().to_int()}"
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let result = install_skill(root, "wiki-ingest")
  assert_eq(result.action, "installed")
  assert_true(@fsx.exists(result.destination_path + "/SKILL.md"))
  assert_true(
    @fsx.exists(result.destination_path + "/references/raw-first-contract.md"),
  )
}

///|
async test "scaffold skill creates workspace template" {
  let root = "/tmp/moonbook-skill-scaffold-\{@async.now().to_int()}"
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let result = scaffold_skill(root, "Research Notes")
  assert_eq(result.action, "scaffolded")
  assert_true(@fsx.exists(result.destination_path + "/SKILL.md"))
  let text = @fsx.read_file(result.destination_path + "/SKILL.md")
  assert_true(text.contains("## Workflow"))
  assert_true(text.contains("## Quality bar"))
}

///|
async test "compare skill reports drift against seeded baseline" {
  let root = "/tmp/moonbook-skill-compare-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let path = root + "/skills/wiki-ingest/SKILL.md"
  let original = @fsx.read_file(path)
  @fsx.write_to_file(
    path,
    original + "\n## Local Override Note\n\nThis workspace changed the skill.\n",
    create=0o644,
  )
  let result = compare_skill(root, "wiki-ingest")
  assert_eq(result.status, "drifted")
  assert_true(result.baseline_path is Some(_))
  assert_true(
    result.selected_only_line_count > 0 || result.changed_line_count > 0,
  )
}

///|
async test "compare skill reports missing baseline for scaffold-only skill" {
  let root = "/tmp/moonbook-skill-compare-nobase-\{@async.now().to_int()}"
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  ignore(scaffold_skill(root, "custom research lane"))
  let result = compare_skill(root, "custom-research-lane")
  assert_eq(result.status, "no-baseline")
}
