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
pub async fn sync_skill(root : String, name : String) -> SkillSyncResult {
  let normalized_root = @pathx.normalize(root)
  let records = list_skills(normalized_root)
  let selected = resolve_skill_selector(records, name) catch {
    error => fail("no skill found for sync: \{name}; \{error}")
  }
  guard selected.scope == "workspace" else {
    fail("skill sync requires a workspace-owned skill")
  }
  let baseline = resolve_skill_baseline(records, selected).unwrap_or_else(() => {
    fail("skill sync requires a seeded baseline for \{selected.name}")
  })
  let compare = compare_skill(normalized_root, name)
  let candidate_dir = skill_candidate_dir(normalized_root, selected.name)
  let selected_dir = @path.Path(candidate_dir)
    .join(@path.Path("workspace"))
    .to_string()
  let baseline_dir = @path.Path(candidate_dir)
    .join(@path.Path("baseline"))
    .to_string()
  let manifest_path = @path.Path(candidate_dir)
    .join(@path.Path("SYNC.json"))
    .to_string()
  @fsx.make_directory(candidate_dir, recursive=true, exists_ok=true)
  copy_skill_tree_replace(
    @pathx.dirname(selected.path).to_string(),
    selected_dir,
  )
  copy_skill_tree_replace(
    @pathx.dirname(baseline.path).to_string(),
    baseline_dir,
  )
  @fsx.write_to_file(
    manifest_path,
    {
      name: selected.name,
      selected_path: selected.path,
      baseline_path: baseline.path,
      selected_scope: selected.scope,
      baseline_scope: baseline.scope,
      summary: compare.summary,
      status: compare.status,
      changed_line_count: compare.changed_line_count,
      selected_only_line_count: compare.selected_only_line_count,
      baseline_only_line_count: compare.baseline_only_line_count,
      first_change_line: compare.first_change_line,
      generated_at: @async.now().to_int(),
    }
    .to_json()
    .stringify(indent=2),
    create=0o644,
  )
  {
    root: normalized_root,
    name: selected.name,
    candidate_dir,
    manifest_path,
    selected_path: selected.path,
    baseline_path: baseline.path,
    summary: compare.summary,
  }
}

///|

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

///|
async test "sync skill stages workspace and baseline candidate bundle" {
  let root = "/tmp/moonbook-skill-sync-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let path = root + "/skills/wiki-ingest/SKILL.md"
  let original = @fsx.read_file(path)
  @fsx.write_to_file(
    path,
    original + "\n## Candidate Override\n\nSync me.\n",
    create=0o644,
  )
  let result = sync_skill(root, "wiki-ingest")
  assert_true(@fsx.exists(result.candidate_dir + "/workspace/SKILL.md"))
  assert_true(@fsx.exists(result.candidate_dir + "/baseline/SKILL.md"))
  assert_true(@fsx.exists(result.manifest_path))
  let manifest = @fsx.read_file(result.manifest_path)
  assert_true(manifest.contains("\"status\": \"drifted\""))
}
