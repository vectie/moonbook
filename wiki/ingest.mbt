///|
pub struct IngestResult {
  page_path : String
  raw_path : String
  title : String
  imported : Bool
  related_pages : Array[String]
  keeper_packet_path : String
} derive(Show, ToJson)

///|
priv struct IngestKeeperProposal {
  title : String
  request : String
  profile : String
  output_contract : String
  semantic_phases : Array[String]
  execution_mode : String
  max_parallel_workers : Int
  gather_lanes : Array[IngestGatherLane]
  source_path : String
  source_page : String
  context_pages : Array[String]
  related_pages : Array[String]
  skill_paths : Array[String]
  notes : Array[String]
} derive(ToJson)

///|
priv struct IngestGatherLane {
  id : String
  title : String
  objective : String
  expected_artifacts : Array[String]
  expected_outputs : Array[String]
} derive(ToJson)

///|
pub async fn ingest_source(root : String, source_path : String) -> IngestResult {
  let workspace = workspace_paths(root)
  @fsx.make_directory(
    @path.Path(workspace.wiki_dir).join(@path.Path("sources")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(workspace.wiki_dir).join(@path.Path("entities")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(workspace.wiki_dir).join(@path.Path("concepts")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(workspace.wiki_dir).join(@path.Path("synthesis")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(workspace.wiki_dir).join(@path.Path("queries")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(workspace.wiki_dir).join(@path.Path("reviews")).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @path.Path(workspace.raw_dir).join(@path.Path("imported")).to_string(),
    recursive=true,
    exists_ok=true,
  )

  let resolved_source = resolve_input_source(source_path)
  if !@fsx.exists(resolved_source) {
    fail("source does not exist: \{resolved_source}")
  }
  validate_ingestable_source(resolved_source)

  let source_under_raw = is_under_root(resolved_source, workspace.raw_dir)
  let stored_raw_path = if source_under_raw {
    resolved_source
  } else {
    import_source_file(workspace.raw_dir, resolved_source)
  }
  let title = detect_source_title(stored_raw_path)
  let relative_raw = relative_to_root(stored_raw_path, workspace.root)
  let slug = unique_source_slug(
    @path.Path(workspace.wiki_dir).join(@path.Path("sources")).to_string(),
    suggest_source_slug(title, stored_raw_path),
  )
  let relative_page = "sources/\{slug}.md"
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let page_body = source_page_text(
    title, relative_raw, relative_page, stored_raw_path,
  )
  @fsx.write_to_file(page_path, page_body, create=0o644)

  let related_pages = enrich_ingest(
    workspace, title, relative_page, stored_raw_path,
  )
  let keeper_packet_path = emit_ingest_keeper_packet(
    workspace, title, stored_raw_path, relative_page, related_pages,
  )

  update_summary(workspace.summary_path, title, relative_page)
  update_index(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    title,
    relative_page,
    stored_raw_path,
  )
  append_log(
    @path.Path(workspace.wiki_dir).join(@path.Path("log.md")).to_string(),
    title,
    relative_raw,
    relative_page,
    related_pages,
  )

  {
    page_path,
    raw_path: stored_raw_path,
    title,
    imported: !source_under_raw,
    related_pages,
    keeper_packet_path,
  }
}

///|
fn resolve_input_source(source_path : String) -> String {
  if @path.Path(source_path).is_absolute() {
    @path.Path(source_path).normalize().to_string()
  } else {
    match @env.current_dir() {
      Some(current_dir) =>
        @path.Path(current_dir)
        .join(@path.Path(source_path))
        .normalize()
        .to_string()
      None => @path.Path(source_path).normalize().to_string()
    }
  }
}

///|
async fn suggest_source_slug(title : String, path : String) -> String {
  let basename_slug = slugify_title(file_stem(path))
  if !is_text_source(path) {
    return prefer_non_generic_slug(slugify_title(title), basename_slug)
  }
  let content = @fsx.read_file(path)
  let title_signal = (title + "\n" + file_stem(path)).to_lower()
  let content_signal = content.to_lower()
  let suggested = if title_signal.contains("troubleshoot") ||
    title_signal.contains("verification") ||
    title_signal.contains("common issue") ||
    title_signal.contains("常见问题") ||
    title_signal.contains("验证") {
    "verification-and-troubleshooting"
  } else if title_signal.contains("macos") ||
    title_signal.contains("menu bar") ||
    title_signal.contains("imessage") {
    "macos-installation"
  } else if title_signal.contains("windows") && title_signal.contains("部署") {
    "windows-manual-deployment"
  } else if title_signal.contains("install") ||
    title_signal.contains("环境准备") ||
    title_signal.contains("wsl") {
    "environment-preparation-and-installation"
  } else if content_signal.contains("wsl") {
    "environment-preparation-and-installation"
  } else if content_signal.contains("windows") &&
    content_signal.contains("powershell") {
    "windows-manual-deployment"
  } else if content_signal.contains("macos") &&
    (
      content_signal.contains("install script") ||
      content_signal.contains("pnpm") ||
      content_signal.contains("imessage")
    ) {
    "macos-installation"
  } else if content_signal.contains("troubleshoot") ||
    content_signal.contains("common issue") {
    "verification-and-troubleshooting"
  } else {
    slugify_title(title)
  }
  prefer_non_generic_slug(suggested, basename_slug)
}

///|
fn prefer_non_generic_slug(primary : String, fallback : String) -> String {
  if is_generic_source_slug(primary) {
    if is_generic_source_slug(fallback) {
      "source"
    } else {
      fallback
    }
  } else {
    primary
  }
}

///|
fn is_generic_source_slug(slug : String) -> Bool {
  slug.is_empty() ||
  [
    "source", "readme", "index", "home", "summary", "guide", "notes", "doc", "docs",
  ].contains(slug)
}

///|
fn is_under_root(path : String, root : String) -> Bool {
  let normalized_path = @pathx.normalize(path)
  let normalized_root = @pathx.normalize(root)
  normalized_path == normalized_root ||
  normalized_path.has_prefix(normalized_root + "/")
}

///|
async fn import_source_file(raw_dir : String, source_path : String) -> String {
  let imported_dir = @path.Path(raw_dir)
    .join(@path.Path("imported"))
    .to_string()
  let basename = @path.Path(source_path).basename().to_string()
  let destination = unique_import_path(imported_dir, basename)
  @fsx.write_bytes(destination, @fsx.read_bytes(source_path), create=0o644)
  destination
}

///|
async fn unique_import_path(imported_dir : String, basename : String) -> String {
  let ext = @pathx.ext(basename).to_string()
  let stem = if ext.is_empty() {
    basename
  } else {
    basename[:basename.length() - ext.length()].to_string()
  }
  let mut index = 0
  while true {
    let candidate_name = if index == 0 {
      basename
    } else {
      "\{stem}-\{index}\{ext}"
    }
    let candidate = @path.Path(imported_dir)
      .join(@path.Path(candidate_name))
      .to_string()
    if !@fsx.exists(candidate) {
      return candidate
    }
    index += 1
  }
  imported_dir
}

///|
async fn detect_source_title(path : String) -> String {
  if is_text_source(path) {
    let content = @fsx.read_file(path)
    let heading = first_markdown_heading(content)
    if !heading.is_empty() {
      return heading
    }
    let paragraph = first_nonempty_line(content)
    if !paragraph.is_empty() {
      return strip_inline_markup(paragraph)
    }
  }
  file_stem(path)
}

///|
async fn validate_ingestable_source(path : String) -> Unit {
  match source_rejection_reason(path) {
    Some(reason) =>
      fail("source is not substantive enough for ingest: \{reason}: \{path}")
    None => ()
  }
}

///|
async fn source_rejection_reason(path : String) -> String? {
  let basename = @path.Path(path).basename().to_string()
  let lowered = basename.to_lower()
  if basename.is_blank() {
    return Some("missing file name")
  }
  if basename.has_prefix(".") {
    return Some("hidden or placeholder files are not ingestable sources")
  }
  if [".gitkeep", ".keep", ".ds_store", "thumbs.db"].contains(lowered) {
    return Some("workspace placeholder files are not ingestable sources")
  }
  if is_text_source(path) {
    if @fsx.read_file(path).trim().to_string().is_blank() {
      return Some("empty text files are not ingestable sources")
    }
  } else if @fsx.read_bytes(path).length() == 0 {
    return Some("empty binary files are not ingestable sources")
  }
  None
}

///|
async fn source_page_text(
  title : String,
  relative_raw : String,
  relative_page : String,
  stored_raw_path : String,
) -> String {
  let raw_link = relative_from_page("wiki/" + relative_page, relative_raw)
  let now = "\{@async.now().to_int()}"
  if is_text_source(stored_raw_path) {
    let content = @fsx.read_file(stored_raw_path)
    let overview = summarize_source(title, content)
    let excerpt = excerpt_source(content, 24)
    let source_type = detect_source_type(title, stored_raw_path, content)
    let scope = detect_source_scope(title, stored_raw_path, content)
    let signals = detect_source_signals(title, stored_raw_path, content)
    "# \{title}\n\n" +
    "- Raw source: [\{relative_raw}](\{raw_link})\n" +
    "- Source type: \{source_type}\n" +
    "- Scope: \{scope}\n" +
    "- Ingested at: `\{now}`\n\n" +
    "## Summary\n\n" +
    "\{overview}\n\n" +
    render_source_signals(signals) +
    "## Extract\n\n" +
    "```text\n\{excerpt}\n```\n"
  } else {
    "# \{title}\n\n" +
    "- Raw source: [\{relative_raw}](\{raw_link})\n" +
    "- Ingested at: `\{now}`\n\n" +
    "## Overview\n\n" +
    "Binary source ingested. Review the raw file directly.\n"
  }
}

///|
async fn update_summary(
  summary_path : String,
  title : String,
  relative_page : String,
) -> Unit {
  let safe_title = escape_link_label(title)
  let link = "- [\{safe_title}](./\{relative_page})"
  let current = @fsx.read_file(summary_path)
  if current.contains("(./\{relative_page})") ||
    current.contains("(\{relative_page})") {
    return
  }
  let next = if current.has_suffix("\n") {
    current + link + "\n"
  } else {
    current + "\n" + link + "\n"
  }
  @fsx.write_to_file(summary_path, next, create=0o644)
}

///|
async fn update_index(
  index_path : String,
  title : String,
  relative_page : String,
  stored_raw_path : String,
) -> Unit {
  update_index_section(
    index_path,
    "Sources",
    escape_link_label(title),
    relative_page,
    "source page for `\{@path.Path(stored_raw_path).basename()}`",
  )
}

///|
async fn enrich_ingest(
  workspace : Paths,
  source_title : String,
  source_relative_page : String,
  stored_raw_path : String,
) -> Array[String] {
  if !is_text_source(stored_raw_path) {
    let maintenance_plan_page = ensure_maintenance_plan_entry(
      workspace,
      "Ingest: \{source_title}",
      "ingest",
      "wiki/" + source_relative_page,
      ["synthesis/overview.md"],
      [
        "skill-followup: source-diarize, synthesis-revise, index-maintain", "binary source: review raw asset directly before semantic revision",
      ],
    )
    let synthesis_page = ensure_synthesis_overview(
      workspace,
      source_title,
      source_relative_page,
      "Binary source ingested. Review the raw file directly.",
      [],
      [],
      [],
    )
    let pages : Array[String] = [synthesis_page, maintenance_plan_page]
    let synthesis_map_page = refresh_synthesis_map(workspace.root)
    if !pages.contains(synthesis_map_page) {
      pages.push(synthesis_map_page)
    }
    return pages
  }

  let content = @fsx.read_file(stored_raw_path)
  let related_pages : Array[String] = []
  let entities = extract_candidate_entities(source_title, content)
  let concepts = extract_candidate_concepts(content)
  let claims = extract_structured_claims(content)
  related_pages.push(
    ensure_synthesis_overview(
      workspace,
      source_title,
      source_relative_page,
      summarize_source(source_title, content),
      entities,
      concepts,
      claims.map(claim => claim.summary_line()),
    ),
  )
  if !claims.is_empty() {
    let claims_page = ensure_claims_register(
      workspace, source_title, source_relative_page, claims,
    )
    related_pages.push(claims_page)
    let review_page = ensure_claim_review_items(
      workspace, source_title, source_relative_page, claims,
    )
    if !review_page.is_empty() {
      related_pages.push(review_page)
    }
  }
  let maintenance_plan_page = ensure_maintenance_plan_entry(
    workspace,
    "Ingest: \{source_title}",
    "ingest",
    "wiki/" + source_relative_page,
    related_pages,
    ingest_plan_notes(source_relative_page, entities, concepts, claims),
  )
  if !related_pages.contains(maintenance_plan_page) {
    related_pages.push(maintenance_plan_page)
  }
  let synthesis_map_page = refresh_synthesis_map(workspace.root)
  if !related_pages.contains(synthesis_map_page) {
    related_pages.push(synthesis_map_page)
  }
  related_pages
}

///|
async fn emit_ingest_keeper_packet(
  workspace : Paths,
  source_title : String,
  stored_raw_path : String,
  source_relative_page : String,
  related_pages : Array[String],
) -> String {
  let jobs_dir = @path.Path(workspace.root)
    .join(@path.Path("keeper/jobs"))
    .to_string()
  @fsx.make_directory(jobs_dir, recursive=true, exists_ok=true)
  let slug = file_stem(source_relative_page)
  let packet_path = @path.Path(jobs_dir)
    .join(@path.Path("ingest-\{slug}.json"))
    .to_string()
  let notes = ingest_packet_notes(stored_raw_path, source_relative_page)
  let packet : IngestKeeperProposal = {
    title: source_title,
    request: "Run the skill-driven wiki ingest revision pass for \{source_title}. Act as the book keeper, not a generic ingest runner. Read the source page, inspect the maintained wiki, honor the semantic phases, and use the gather lane specs below to spawn multiple bounded MoonClaw gather workers in parallel when the source surface is broad. Do not compress the gather phase into one catch-all worker unless the material is obviously tiny.",
    profile: "wiki_ingest_controller",
    output_contract: "keeper.plan.packet.v1",
    semantic_phases: ingest_semantic_phases(),
    execution_mode: "parallel-lane-bootstrap",
    max_parallel_workers: 4,
    gather_lanes: ingest_gather_lanes(source_title, source_relative_page),
    source_path: relative_to_root(stored_raw_path, workspace.root),
    source_page: "wiki/" + source_relative_page,
    context_pages: ingest_packet_context_pages(source_relative_page),
    related_pages: related_pages.map(page => "wiki/" + page),
    skill_paths: ingest_packet_skill_paths(),
    notes,
  }
  @fsx.write_to_file(
    packet_path,
    packet.to_json().stringify(indent=2),
    create=0o644,
  )
  packet_path
}

///|
async fn ingest_packet_notes(
  stored_raw_path : String,
  source_relative_page : String,
) -> Array[String] {
  if !is_text_source(stored_raw_path) {
    return [
      "binary-source: review raw asset directly before semantic revision", "skill-followup: source-diarize, synthesis-revise, index-maintain",
    ]
  }
  let content = @fsx.read_file(stored_raw_path)
  let entities = extract_candidate_entities(file_stem(stored_raw_path), content)
  let concepts = extract_candidate_concepts(content)
  let claims = extract_structured_claims(content)
  ingest_plan_notes(source_relative_page, entities, concepts, claims)
}

///|
fn ingest_packet_context_pages(source_relative_page : String) -> Array[String] {
  [
    "wiki/index.md",
    "wiki/log.md",
    "wiki/" + source_relative_page,
    "wiki/synthesis/overview.md",
    "wiki/synthesis/claims.md",
    "wiki/synthesis/maintenance-plan.md",
    "wiki/reviews/pending.md",
    "RESOLVER.md",
  ]
}

///|
fn ingest_semantic_phases() -> Array[String] {
  [
    "bootstrap_gather", "source_materialize", "knowledge_revise", "marketing_project",
    "review_finalize",
  ]
}

///|
fn ingest_gather_lanes(
  source_title : String,
  source_relative_page : String,
) -> Array[IngestGatherLane] {
  [
    {
      id: "docs",
      title: "Docs lane",
      objective: "Read only high-signal docs, READMEs, guides, and product-facing markdown relevant to \{source_title}. Produce packet-ready evidence with provenance and candidate ontology.",
      expected_artifacts: ["raw/bootstrap/*docs*.md"],
      expected_outputs: [
        "inspected source paths", "evidence bullets", "candidate entities", "candidate concepts",
        "lane readiness judgment",
      ],
    },
    {
      id: "implementation",
      title: "Implementation lane",
      objective: "Read only the highest-signal code, manifests, configs, and runtime wiring that support durable claims about wiki/\{source_relative_page}. Produce packet-ready implementation evidence, not final synthesis.",
      expected_artifacts: ["raw/bootstrap/*implementation*.md"],
      expected_outputs: [
        "inspected source paths", "runtime or code evidence bullets", "candidate entities",
        "candidate concepts", "unresolved questions",
      ],
    },
    {
      id: "architecture",
      title: "Architecture lane",
      objective: "Read only files that explain system boundaries, topology, call chains, or cross-component responsibilities related to \{source_title}. Produce architecture notes with relationship candidates and uncertainty markers.",
      expected_artifacts: ["raw/bootstrap/*architecture*.md"],
      expected_outputs: [
        "inspected source paths", "relationship evidence bullets", "candidate entities",
        "candidate concepts", "topology notes",
      ],
    },
  ]
}

///|
fn ingest_packet_skill_paths() -> Array[String] {
  [
    "skills/wiki-ingest/SKILL.md", "skills/source-diarize/SKILL.md", "skills/entity-revise/SKILL.md",
    "skills/concept-revise/SKILL.md", "skills/synthesis-revise/SKILL.md", "skills/claim-audit/SKILL.md",
    "skills/contradiction-review/SKILL.md", "skills/review-decision/SKILL.md", "skills/index-maintain/SKILL.md",
    "skills/research-report/SKILL.md", "skills/wiki-marketing/SKILL.md",
  ]
}

///|
fn ingest_plan_notes(
  source_relative_page : String,
  entities : Array[String],
  concepts : Array[String],
  claims : Array[StructuredClaim],
) -> Array[String] {
  let notes : Array[String] = []
  notes.push(
    "semantic-phases: bootstrap_gather -> source_materialize -> knowledge_revise -> marketing_project -> review_finalize",
  )
  notes.push(
    "execution-mode: parallel-lane-bootstrap with one MoonClaw gather worker per lane when the source surface is broad",
  )
  notes.push("gather-lanes: docs, implementation, architecture")
  notes.push(
    "skill-followup: source-diarize, synthesis-revise, index-maintain, claim-audit",
  )
  notes.push(
    "consider-skill: entity-revise on wiki/entities/* from wiki/\{source_relative_page}",
  )
  if !entities.is_empty() {
    notes.push("candidate-entities: " + entities.join(", "))
  }
  notes.push(
    "consider-skill: concept-revise on wiki/concepts/* from wiki/\{source_relative_page}",
  )
  if !concepts.is_empty() {
    notes.push("candidate-concepts: " + concepts.map(title_case).join(", "))
  }
  if !claims.is_empty() {
    notes.push("claims: " + claims.length().to_string())
    notes.push(
      "consider-skill: contradiction-review and review-decision for low-confidence or conflicting claims",
    )
  }
  notes
}

///|
test "slugify title normalizes punctuation and case" {
  assert_eq(slugify_title("My Source: V1"), "my-source-v1")
}

///|
test "prefer non generic slug falls back to basename" {
  assert_eq(prefer_non_generic_slug("source", "install"), "install")
}

///|
test "relative link from page reaches raw source" {
  assert_eq(
    relative_from_page("wiki/sources/example.md", "raw/imported/file.md"),
    "../../raw/imported/file.md",
  )
}

///|
test "detect source title prefers markdown heading" {
  let tmp = "/Users/kq/Workspace/moonbook/wiki-title-test.md"
  ignore(tmp)
  let title = first_markdown_heading("# Demo Title\n\nBody\n")
  assert_eq(title, "Demo Title")
}

///|
test "extract candidate entities uses titlecase phrases" {
  let entities = extract_candidate_entities(
    "OpenClaw Deploy Guide", "OpenClaw connects to MoonClaw runtime.\nMoonClaw stores workspace state.\n",
  )
  assert_true(entities.contains("OpenClaw"))
  assert_true(entities.contains("MoonClaw"))
}

///|
test "extract candidate entities keeps known lowercase runtime names" {
  let entities = extract_candidate_entities(
    "OpenClaw guide", "openclaw works with feishu feishu and powershell powershell on windows",
  )
  assert_true(entities.contains("OpenClaw"))
  assert_true(entities.contains("Feishu"))
  assert_true(entities.contains("PowerShell"))
}

///|
test "extract candidate concepts ranks repeated lowercase words" {
  let concepts = extract_candidate_concepts(
    "ingestion ingestion synthesis synthesis synthesis claims confidence",
  )
  assert_eq(concepts[0], "synthesis")
}

///|
test "extract candidate concepts keeps salient words even without repetition" {
  let concepts = extract_candidate_concepts(
    "runtime pipeline confidence synthesis",
  )
  assert_true(concepts.contains("runtime"))
  assert_true(concepts.contains("synthesis"))
}

///|
test "extract candidate concepts prefers canonical operational concepts" {
  let concepts = extract_candidate_concepts(
    "Install OpenClaw with npm, restart the gateway, and verify Feishu channel status on macOS.",
  )
  assert_true(concepts.contains("installation methods"))
  assert_true(concepts.contains("gateway operations"))
  assert_true(concepts.contains("channel integration"))
}

///|
test "summarize source skips related-page boilerplate" {
  let summary = summarize_source(
    "在Windows操作系统中手动部署OpenClaw", "# 在Windows操作系统中手动部署OpenClaw\n\n相关页面：[查看 macOS 安装说明](./macos.md)\n\n在PowerShell中执行如下命令，安装最新版本的OpenClaw。\n",
  )
  assert_eq(
    summary, "在PowerShell中执行如下命令，安装最新版本的OpenClaw。",
  )
}

///|
test "detect source scope prefers title over incidental cross links" {
  let scope = detect_source_scope(
    "在Windows操作系统中手动部署OpenClaw", "README.md", "相关页面：[查看 macOS 安装说明](./macos.md)\n\n在PowerShell中执行如下命令。",
  )
  assert_eq(scope, "Windows; installation and onboarding")
}

///|
test "extract claim statements keeps simple grounded lines" {
  let claims = extract_claim_statements(
    "OpenClaw integrates with MoonClaw runtime.\nThe system improves synthesis.\n",
  )
  assert_eq(claims.length(), 2)
}

///|
test "parse structured claim extracts subject predicate and confidence" {
  let claim = parse_structured_claim(
    "OpenClaw integrates with MoonClaw runtime.",
  ).unwrap()
  assert_eq(claim.subject, "OpenClaw")
  assert_eq(claim.confidence, "medium")
}

///|
test "upsert claim block accumulates support" {
  let content = "# Claims Register\n\n## Claims\n\n_None yet._\n"
  let claim = {
    subject: "OpenClaw",
    predicate: "MoonClaw runtime",
    confidence: "medium",
  }
  let once = upsert_claim_block(content, claim, "Source A", "../sources/a.md")
  let twice = upsert_claim_block(once, claim, "Source B", "../sources/b.md")
  assert_true(twice.contains("- Support: `2`"))
}

///|
test "append list entry avoids duplicates" {
  let content = "# Demo\n\n## Sources\n\n- [One](./one.md)\n"
  let updated = append_list_entry(content, "## Sources", "- [One](./one.md)")
  assert_eq(updated, normalize_markdown_spacing(content))
}

///|
test "rewrite index section collapses duplicate source headings" {
  let content = "# Index\n\n## Sources\n\n- [One](./sources/one.md): first\n\n## Queries\n\n_None yet._\n\n## Sources\n\n- [Two](./sources/two.md): second\n"
  let rewritten = normalize_markdown_spacing(
    rewrite_index_section(
      content,
      "Sources",
      collect_index_section_entries(content, "Sources"),
    ),
  )
  let mut count = 0
  for _ in rewritten.split("## Sources") {
    count += 1
  }
  assert_eq(count, 2)
  assert_true(rewritten.contains("[One](./sources/one.md)"))
  assert_true(rewritten.contains("[Two](./sources/two.md)"))
}

///|
async test "ingest rejects placeholder raw artifacts" {
  let root = "/tmp/moonbook-ingest-reject-dotfile"
  ignore(init_workspace(root))
  let placeholder = @path.Path(root)
    .join(@path.Path("raw/assets/.gitkeep"))
    .to_string()
  @fsx.write_to_file(placeholder, "", create=0o644)
  let mut message = ""
  ignore(ingest_source(root, placeholder)) catch {
    error => message = "\{error}"
  }
  assert_true(message.contains("not substantive enough for ingest"))
  assert_true(message.contains(".gitkeep"))
}

///|
async test "ingest leaves ontology revision to follow-up skills" {
  let root = "/tmp/moonbook-ingest-thin-harness"
  ignore(init_workspace(root))
  let source = @path.Path(root).join(@path.Path("raw/demo.md")).to_string()
  @fsx.write_to_file(
    source,
    "# Demo Source\n\nOpenClaw integrates with Feishu.\n\nGateway restart is required after config changes.\n",
    create=0o644,
  )
  let result = ingest_source(root, source)
  assert_true(result.related_pages.contains("synthesis/overview.md"))
  assert_true(result.related_pages.contains("synthesis/maintenance-plan.md"))
  assert_true(result.related_pages.contains("synthesis/claims.md"))
  assert_true(result.keeper_packet_path.contains("/keeper/jobs/ingest-"))
  assert_true(@fsx.exists(result.keeper_packet_path))
  assert_true(!@fsx.exists(root + "/wiki/entities/openclaw.md"))
  assert_true(!@fsx.exists(root + "/wiki/concepts/gateway-operations.md"))
  let plan = @fsx.read_file(root + "/wiki/synthesis/maintenance-plan.md")
  assert_true(plan.contains("skill-followup: source-diarize"))
  assert_true(plan.contains("consider-skill: entity-revise"))
  assert_true(plan.contains("consider-skill: concept-revise"))
  let packet = @fsx.read_file(result.keeper_packet_path)
  assert_true(packet.contains("\"profile\": \"wiki_ingest_controller\""))
  assert_true(packet.contains("\"skills/source-diarize/SKILL.md\""))
  assert_true(
    packet.contains("\"execution_mode\": \"parallel-lane-bootstrap\""),
  )
  assert_true(packet.contains("\"max_parallel_workers\": 4"))
  assert_true(packet.contains("\"semantic_phases\""))
  assert_true(packet.contains("\"gather_lanes\""))
  assert_true(packet.contains("\"id\": \"docs\""))
  assert_true(packet.contains("\"id\": \"implementation\""))
  assert_true(packet.contains("\"id\": \"architecture\""))
  assert_true(packet.contains("one MoonClaw gather worker per lane"))
}
