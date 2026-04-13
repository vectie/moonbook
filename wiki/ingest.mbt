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
  source_path : String
  source_page : String
  context_pages : Array[String]
  related_pages : Array[String]
  skill_paths : Array[String]
  notes : Array[String]
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
  let current = @fsx.read_file(index_path)
  let bullet = "- [\{title}](./\{relative_page}): source page for `\{@path.Path(stored_raw_path).basename()}`"
  if current.contains(bullet) {
    return
  }
  let next = if current.contains("## Sources\n\n_None yet._") {
    current
    .replace(old="## Sources\n\n_None yet._", new="## Sources\n\n\{bullet}")
    .to_string()
  } else if current.contains("## Sources\n") {
    current
    .replace(old="## Sources\n", new="## Sources\n\{bullet}\n")
    .to_string()
  } else {
    current + "\n## Sources\n\n" + bullet + "\n"
  }
  @fsx.write_to_file(index_path, next, create=0o644)
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
    request: "Run the skill-driven wiki ingest revision pass for \{source_title}. Read the source page, inspect the maintained wiki, and apply semantic follow-up through the seeded skill pack.",
    profile: "wiki_ingest_controller",
    output_contract: "keeper.plan.packet.v1",
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
fn ingest_packet_skill_paths() -> Array[String] {
  [
    "skills/wiki-ingest/SKILL.md", "skills/source-diarize/SKILL.md", "skills/entity-revise/SKILL.md",
    "skills/concept-revise/SKILL.md", "skills/synthesis-revise/SKILL.md", "skills/claim-audit/SKILL.md",
    "skills/contradiction-review/SKILL.md", "skills/review-decision/SKILL.md", "skills/index-maintain/SKILL.md",
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
priv struct StructuredClaim {
  subject : String
  predicate : String
  confidence : String
}

///|
fn StructuredClaim::id(self : StructuredClaim) -> String {
  "\{slugify_title(self.subject)}::\{slugify_title(self.predicate)}"
}

///|
fn StructuredClaim::summary_line(self : StructuredClaim) -> String {
  "\{self.subject} -> \{self.predicate} [\{self.confidence}]"
}

///|
fn StructuredClaim::kind(self : StructuredClaim) -> String {
  let lowered = self.predicate.to_lower()
  if lowered.has_prefix("supports ") {
    "supports"
  } else if lowered.has_prefix("uses ") {
    "uses"
  } else if lowered.has_prefix("improves ") {
    "improves"
  } else if lowered.has_prefix("keeps ") {
    "keeps"
  } else if lowered.contains("integrates with") {
    "integration"
  } else {
    "statement"
  }
}

///|
fn claim_relationship_target(
  claim : StructuredClaim,
) -> (String, String, String)? {
  let predicate = claim.predicate.trim().to_string()
  let lowered = predicate.to_lower()
  if lowered.has_prefix("supports ") {
    let target = predicate[9:].trim().to_string()
    return Some(relationship_target_tuple("supports", target))
  }
  if lowered.has_prefix("uses ") {
    let target = predicate[5:].trim().to_string()
    return Some(relationship_target_tuple("uses", target))
  }
  if lowered.has_prefix("improves ") {
    let target = predicate[9:].trim().to_string()
    return Some(relationship_target_tuple("improves", target))
  }
  if lowered.has_prefix("keeps ") {
    let target = predicate[6:].trim().to_string()
    return Some(relationship_target_tuple("keeps", target))
  }
  if looks_like_entity_name(predicate) {
    return Some(relationship_target_tuple("integrates with", predicate))
  }
  None
}

///|
fn relationship_target_tuple(
  verb : String,
  target : String,
) -> (String, String, String) {
  let kind = if looks_like_entity_name(target) { "entity" } else { "concept" }
  let relation = if kind == "entity" {
    "\{verb} [\{target}](../entities/\{slugify_title(target)}.md)"
  } else {
    let concept = target.to_lower()
    "\{verb} [\{title_case(concept)}](../concepts/\{slugify_title(concept)}.md)"
  }
  (kind, target, relation)
}

///|
fn looks_like_entity_name(text : String) -> Bool {
  let words = split_words(text)
  if words.is_empty() {
    return false
  }
  for word in words {
    if is_titlecase_word(word) {
      return true
    }
  }
  false
}

///|
async fn ensure_synthesis_overview(
  workspace : Paths,
  source_title : String,
  source_relative_page : String,
  overview : String,
  entities : Array[String],
  concepts : Array[String],
  claims : Array[String],
) -> String {
  let relative_page = "synthesis/overview.md"
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let source_link = relative_from_page(
    "wiki/" + relative_page,
    "wiki/" + source_relative_page,
  )
  let related = related_signal_line(entities, concepts)
  let claim_line = if claims.is_empty() {
    ""
  } else {
    "- Claims: " + claims.length().to_string() + "\n"
  }
  let entry = "### \{source_title}\n\n" +
    "- Source page: [\{source_title}](\{source_link})\n" +
    "- Signal: \{overview}\n" +
    claim_line +
    "\{related}\n"
  let existing = if @fsx.exists(page_path) {
    @fsx.read_file(page_path)
  } else {
    ""
  }
  let updated = if existing.is_empty() {
    "# Overview\n\n" +
    "## Current Synthesis\n\n" +
    "This page accumulates cross-source wiki signals.\n\n" +
    "## Source Updates\n\n" +
    entry
  } else {
    append_section_block(existing, "## Source Updates", entry)
  }
  @fsx.write_to_file(page_path, updated, create=0o644)
  update_summary(workspace.summary_path, "Overview", relative_page)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Core Pages",
    "Overview",
    relative_page,
    "cross-source synthesis page",
  )
  relative_page
}

///|
async fn ensure_claims_register(
  workspace : Paths,
  source_title : String,
  source_relative_page : String,
  claims : Array[StructuredClaim],
) -> String {
  let relative_page = "synthesis/claims.md"
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let source_link = relative_from_page(
    "wiki/" + relative_page,
    "wiki/" + source_relative_page,
  )
  let existing = if @fsx.exists(page_path) {
    @fsx.read_file(page_path)
  } else {
    "# Claims Register\n\n" +
    "This page collects lightweight extracted claims from ingested sources.\n\n" +
    "## Claims\n\n" +
    "_None yet._\n"
  }
  let mut updated = existing
  for claim in claims {
    updated = upsert_claim_block(updated, claim, source_title, source_link)
  }
  @fsx.write_to_file(page_path, updated, create=0o644)
  update_summary(workspace.summary_path, "Claims Register", relative_page)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Core Pages",
    "Claims Register",
    relative_page,
    "lightweight extracted claims with confidence markers",
  )
  relative_page
}

///|
async fn ensure_claim_review_items(
  workspace : Paths,
  source_title : String,
  source_relative_page : String,
  claims : Array[StructuredClaim],
) -> String {
  let contested = contested_claims(
    @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/claims.md"))
    .to_string(),
    claims,
  )
  if contested.is_empty() {
    return ""
  }
  let relative_page = "reviews/pending.md"
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let source_link = relative_from_page(
    "wiki/" + relative_page,
    "wiki/" + source_relative_page,
  )
  let existing = if @fsx.exists(page_path) {
    @fsx.read_file(page_path)
  } else {
    "# Pending Review\n\n## Items\n\n_None yet._\n"
  }
  let review_id = "claim-review-\{slugify_title(source_title)}"
  let builder = StringBuilder::new()
  builder.write_string("### Claim review | \{source_title}\n\n")
  builder.write_string("- Review ID: `\{review_id}`\n")
  builder.write_string("- Source page: [\{source_title}](\{source_link})\n")
  builder.write_string("- Merge policy: `claim-resolution`\n")
  builder.write_string("- Status: `pending`\n")
  builder.write_string(
    "- Reason: conflicting or uncertain claims need review\n",
  )
  builder.write_string("- Claims:\n")
  for claim in contested {
    builder.write_string("  - \{claim.summary_line()}\n")
  }
  builder.write_string("\n")
  let updated = append_section_block(existing, "## Items", builder.to_string())
  @fsx.write_to_file(page_path, updated, create=0o644)
  update_summary(workspace.summary_path, "Pending Review", relative_page)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Core Pages",
    "Pending Review",
    relative_page,
    "queue of human review items for contested or uncertain updates",
  )
  relative_page
}

///|
fn related_signal_line(
  entities : Array[String],
  concepts : Array[String],
) -> String {
  let parts : Array[String] = []
  if !entities.is_empty() {
    parts.push("entities: " + entities.join(", "))
  }
  if !concepts.is_empty() {
    parts.push("concepts: " + concepts.map(title_case).join(", "))
  }
  if parts.is_empty() {
    ""
  } else {
    "- Related: " + parts.join(" | ") + "\n"
  }
}

///|
async fn update_index_section(
  index_path : String,
  section_title : String,
  title : String,
  relative_page : String,
  description : String,
) -> Unit {
  let bullet = "- [\{title}](./\{relative_page}): \{description}"
  let original = @fsx.read_file(index_path)
  if original.contains(bullet) {
    return
  }
  let current = remove_index_entry(original, relative_page)
  let next = normalize_markdown_spacing(
    insert_index_entry(current, section_title, bullet),
  )
  @fsx.write_to_file(index_path, next, create=0o644)
}

///|
fn remove_index_entry(content : String, relative_page : String) -> String {
  let link_marker = "(./\{relative_page})"
  let kept : Array[String] = []
  for line in content.split("\n") {
    if line.has_prefix("- [") && line.contains(link_marker) {
      continue
    }
    kept.push(line.to_string())
  }
  kept.join("\n")
}

///|
fn insert_index_entry(
  content : String,
  section_title : String,
  bullet : String,
) -> String {
  let target_header = "## \{section_title}"
  let lines = content.split("\n")
  let rebuilt : Array[String] = []
  let mut in_target = false
  let mut inserted = false
  for raw in lines {
    let line = raw.to_string()
    if line == target_header {
      in_target = true
      rebuilt.push(line)
      continue
    }
    if in_target && line.has_prefix("## ") {
      if !inserted {
        if !rebuilt.is_empty() &&
          rebuilt[rebuilt.length() - 1] != "" &&
          rebuilt[rebuilt.length() - 1] != target_header {
          rebuilt.push("")
        }
        rebuilt.push(bullet)
        inserted = true
      }
      in_target = false
    }
    if in_target && line == "_None yet._" {
      rebuilt.push(bullet)
      inserted = true
      continue
    }
    rebuilt.push(line)
  }
  if in_target && !inserted {
    if !rebuilt.is_empty() &&
      rebuilt[rebuilt.length() - 1] != "" &&
      rebuilt[rebuilt.length() - 1] != target_header {
      rebuilt.push("")
    }
    rebuilt.push(bullet)
    inserted = true
  }
  if inserted {
    rebuilt.join("\n")
  } else {
    content + "\n## \{section_title}\n\n" + bullet + "\n"
  }
}

///|
fn normalize_markdown_spacing(content : String) -> String {
  let normalized : Array[String] = []
  let mut blank_run = 0
  for raw in content.split("\n") {
    let line = raw.to_string()
    if line.trim().is_empty() {
      if blank_run == 0 {
        normalized.push("")
      }
      blank_run += 1
    } else {
      blank_run = 0
      normalized.push(line)
    }
  }
  let joined = normalized.join("\n")
  if joined.has_suffix("\n") {
    joined
  } else {
    joined + "\n"
  }
}

///|
async fn append_log(
  log_path : String,
  title : String,
  relative_raw : String,
  relative_page : String,
  related_pages : Array[String],
) -> Unit {
  let now = "\{@async.now().to_int()}"
  let entry = "## [\{now}] ingest | \{title}\n\n" +
    "- raw: `\{relative_raw}`\n" +
    "- page: `wiki/\{relative_page}`\n" +
    format_related_log_lines(related_pages)
  let current = @fsx.read_file(log_path)
  let next = if current.has_suffix("\n") {
    current + "\n" + entry
  } else {
    current + "\n\n" + entry
  }
  @fsx.write_to_file(log_path, next, create=0o644)
}

///|
fn format_related_log_lines(related_pages : Array[String]) -> String {
  if related_pages.is_empty() {
    ""
  } else {
    let lines = related_pages.map(page => "- related: `wiki/\{page}`\n")
    lines.join("")
  }
}

///|
fn summarize_source(title : String, content : String) -> String {
  let paragraph = first_meaningful_line(title, content)
  let cleaned = strip_inline_markup(paragraph)
  if cleaned.is_empty() {
    "Source ingested. Open the raw file for details."
  } else if cleaned.length() > 320 {
    cleaned[:320].to_string() + "..."
  } else {
    cleaned
  }
}

///|
fn first_meaningful_line(title : String, content : String) -> String {
  let mut in_fence = false
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix("```") {
      in_fence = !in_fence
      continue
    }
    if in_fence ||
      line.is_empty() ||
      line.has_prefix("#") ||
      line.has_prefix("![](") ||
      line == "---" {
      continue
    }
    let cleaned = strip_inline_markup(line)
    if is_weak_summary_line(title, cleaned) {
      continue
    }
    if cleaned.length() >= 6 {
      return cleaned
    }
  }
  first_nonempty_line(content)
}

///|
fn is_weak_summary_line(title : String, line : String) -> Bool {
  let lowered = line.to_lower()
  let title_lowered = title.to_lower()
  lowered.has_prefix("相关页面") ||
  lowered.has_prefix("see also") ||
  lowered.has_prefix("上一篇") ||
  lowered.has_prefix("下一篇") ||
  lowered.has_prefix("view ") ||
  lowered.has_prefix("- ") ||
  lowered.has_prefix("* ") ||
  lowered.has_prefix("> ") ||
  lowered.has_prefix("[") ||
  lowered.contains("index.html") ||
  lowered.contains("./macos.md") ||
  lowered.contains("./readme.md") ||
  lowered == title_lowered
}

///|
fn excerpt_source(content : String, max_lines : Int) -> String {
  let lines : Array[String] = []
  for raw in content.split("\n") {
    let line = raw.to_string()
    if lines.length() >= max_lines {
      break
    }
    lines.push(line)
  }
  lines.join("\n")
}

///|
fn first_markdown_heading(content : String) -> String {
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix("#") {
      let mut index = 0
      while index < line.length() && line[index] == '#' {
        index += 1
      }
      let title = line[index:].trim().to_string()
      if !title.is_empty() {
        return strip_inline_markup(title)
      }
    }
  }
  ""
}

///|
fn first_nonempty_line(content : String) -> String {
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if !line.is_empty() {
      return line
    }
  }
  ""
}

///|
fn strip_inline_markup(text : String) -> String {
  text
  .replace(old="`", new="")
  .to_string()
  .replace(old="**", new="")
  .to_string()
  .replace(old="__", new="")
  .to_string()
  .replace(old="*", new="")
  .to_string()
  .replace(old="_", new="")
  .to_string()
  .replace(old="[", new="")
  .to_string()
  .replace(old="]", new="")
  .to_string()
}

///|
fn upsert_claim_block(
  content : String,
  claim : StructuredClaim,
  source_title : String,
  source_link : String,
) -> String {
  let header = "### \{claim.subject} :: \{claim.predicate}"
  let source_entry = "  - [\{source_title}](\{source_link})"
  let related_pages = claim_related_pages(claim).join(", ")
  let base = if content.contains("_None yet._") {
    content.replace(old="_None yet._", new="").to_string()
  } else {
    content
  }
  if !base.contains(header) {
    let block = header +
      "\n\n" +
      "- Claim ID: `\{claim.id()}`\n" +
      "- Subject: `\{claim.subject}`\n" +
      "- Predicate: `\{claim.predicate}`\n" +
      "- Kind: `\{claim.kind()}`\n" +
      "- Confidence: `\{claim.confidence}`\n" +
      "- Support: `1`\n" +
      "- Status: `active`\n" +
      "- Superseded by: `_None_`\n" +
      "- Related Pages: `\{related_pages}`\n" +
      "- Sources:\n" +
      source_entry +
      "\n\n"
    return append_section_block(base, "## Claims", block)
  }
  let support_line = find_claim_field(base, header, "- Support: `").unwrap_or(
    "1",
  )
  let increment = if base.contains(source_entry) { 0 } else { 1 }
  let updated_support = parse_decimal_int(support_line) + increment
  let with_support = replace_claim_field(
    base,
    header,
    "- Support: `",
    "\{updated_support}",
  )
  let with_metadata = replace_or_append_claim_field(
    replace_or_append_claim_field(
      replace_or_append_claim_field(
        with_support,
        header,
        "- Claim ID: `",
        claim.id(),
      ),
      header,
      "- Kind: `",
      claim.kind(),
    ),
    header,
    "- Related Pages: `",
    related_pages,
  )
  if with_metadata.contains(source_entry) {
    with_metadata
  } else {
    insert_claim_source_entry(with_metadata, header, source_entry)
  }
}

///|
fn claim_related_pages(claim : StructuredClaim) -> Array[String] {
  let pages : Array[String] = ["entities/\{slugify_title(claim.subject)}.md"]
  match claim_relationship_target(claim) {
    Some((target_kind, target_name, _)) =>
      if target_kind == "entity" {
        pages.push("entities/\{slugify_title(target_name)}.md")
      } else {
        pages.push("concepts/\{slugify_title(target_name.to_lower())}.md")
      }
    None => ()
  }
  pages
}

///|
async fn contested_claims(
  claims_page_path : String,
  claims : Array[StructuredClaim],
) -> Array[StructuredClaim] {
  let existing = if @fsx.exists(claims_page_path) {
    @fsx.read_file(claims_page_path)
  } else {
    ""
  }
  let contested : Array[StructuredClaim] = []
  for claim in claims {
    let pattern = "### \{claim.subject} :: "
    if existing.contains(pattern) &&
      !existing.contains("### \{claim.subject} :: \{claim.predicate}") {
      contested.push(claim)
    } else if claim.confidence == "low" {
      contested.push(claim)
    }
  }
  contested
}

///|
fn parse_decimal_int(text : String) -> Int {
  let mut value = 0
  for c in text {
    if c >= '0' && c <= '9' {
      value = value * 10 + (c.to_int() - '0'.to_int())
    }
  }
  value
}

///|
fn find_claim_field(
  content : String,
  header : String,
  prefix : String,
) -> String? {
  let lines = lines_array(content)
  let mut in_block = false
  for line in lines {
    if line == header {
      in_block = true
      continue
    }
    if in_block && line.has_prefix("### ") {
      break
    }
    if in_block && line.has_prefix(prefix) && line.has_suffix("`") {
      return Some(line[prefix.length():line.length() - 1].to_string())
    }
  }
  None
}

///|
fn replace_claim_field(
  content : String,
  header : String,
  prefix : String,
  value : String,
) -> String {
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let mut in_block = false
  for line in lines {
    if line == header {
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
fn replace_or_append_claim_field(
  content : String,
  header : String,
  prefix : String,
  value : String,
) -> String {
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let mut in_block = false
  let mut replaced = false
  for line in lines {
    if line == header {
      in_block = true
      rebuilt.push(line)
      continue
    }
    if in_block && line.has_prefix("### ") {
      if !replaced {
        rebuilt.push(prefix + value + "`")
        replaced = true
      }
      in_block = false
    }
    if in_block && line.has_prefix(prefix) {
      rebuilt.push(prefix + value + "`")
      replaced = true
    } else {
      rebuilt.push(line)
    }
  }
  if in_block && !replaced {
    rebuilt.push(prefix + value + "`")
  }
  rebuilt.join("\n")
}

///|
fn insert_claim_source_entry(
  content : String,
  header : String,
  source_entry : String,
) -> String {
  let lines = lines_array(content)
  let rebuilt : Array[String] = []
  let mut in_block = false
  let mut in_sources = false
  let mut inserted = false
  for line in lines {
    if line == header {
      in_block = true
      rebuilt.push(line)
      continue
    }
    if in_block && line.has_prefix("### ") {
      if in_sources && !inserted {
        rebuilt.push(source_entry)
        inserted = true
      }
      in_block = false
      in_sources = false
    }
    if in_block && line == "- Sources:" {
      in_sources = true
      rebuilt.push(line)
      continue
    }
    if in_block &&
      in_sources &&
      !inserted &&
      !line.has_prefix("  - ") &&
      !line.trim().is_empty() {
      rebuilt.push(source_entry)
      inserted = true
      in_sources = false
    }
    rebuilt.push(line)
  }
  if in_sources && !inserted {
    rebuilt.push(source_entry)
  }
  rebuilt.join("\n")
}

///|
fn lines_array(content : String) -> Array[String] {
  let lines : Array[String] = []
  for raw in content.split("\n") {
    lines.push(raw.to_string())
  }
  lines
}

///|
fn append_list_entry(
  content : String,
  section_header : String,
  entry : String,
) -> String {
  let cleaned = content.replace(old="_None yet._\n", new="").to_string()
  if content.contains(entry) {
    return cleaned
  }
  if cleaned.contains(section_header + "\n\n") {
    cleaned
    .replace(
      old=section_header + "\n\n",
      new=section_header + "\n\n" + entry + "\n",
    )
    .to_string()
  } else if cleaned.contains(section_header + "\n") {
    cleaned
    .replace(
      old=section_header + "\n",
      new=section_header + "\n" + entry + "\n",
    )
    .to_string()
  } else if cleaned.has_suffix("\n") {
    cleaned + "\n" + section_header + "\n\n" + entry + "\n"
  } else {
    cleaned + "\n\n" + section_header + "\n\n" + entry + "\n"
  }
}

///|
fn append_section_block(
  content : String,
  section_header : String,
  block : String,
) -> String {
  let cleaned = content.replace(old="_None yet._\n", new="").to_string()
  if content.contains(block.trim().to_string()) {
    return cleaned
  }
  if cleaned.contains(section_header + "\n\n") {
    cleaned
    .replace(
      old=section_header + "\n\n",
      new=section_header + "\n\n" + block + "\n",
    )
    .to_string()
  } else if cleaned.contains(section_header + "\n") {
    cleaned
    .replace(
      old=section_header + "\n",
      new=section_header + "\n" + block + "\n",
    )
    .to_string()
  } else if cleaned.has_suffix("\n") {
    cleaned + "\n" + section_header + "\n\n" + block + "\n"
  } else {
    cleaned + "\n\n" + section_header + "\n\n" + block + "\n"
  }
}

///|
fn extract_candidate_entities(
  title : String,
  content : String,
) -> Array[String] {
  let selected = detect_known_entities(title, content)
  let counts : Map[String, Int] = {}
  for phrase in candidate_titlecase_phrases(title + "\n" + content) {
    if should_keep_entity_phrase(phrase) {
      counts[phrase] = counts.get(phrase).unwrap_or(0) + 1
    }
  }
  let ranked = rank_phrase_counts(counts)
  if selected.length() >= 4 {
    return selected
  }
  for phrase in ranked {
    if selected.length() >= 5 {
      break
    }
    if counts.get(phrase).unwrap_or(0) < 2 && !title.contains(phrase) {
      continue
    }
    let normalized = normalize_entity_name(phrase)
    if !normalized.is_empty() && !selected.contains(normalized) {
      selected.push(normalized)
    }
  }
  selected
}

///|
fn extract_candidate_concepts(content : String) -> Array[String] {
  let selected = detect_canonical_concepts(content)
  if selected.length() >= 3 {
    return selected
  }
  let counts : Map[String, Int] = {}
  for word in lowercase_word_candidates(content) {
    if should_keep_concept_word(word) {
      counts[word] = counts.get(word).unwrap_or(0) + 1
    }
  }
  let ranked = rank_phrase_counts(counts)
  for word in ranked {
    if selected.length() >= 6 {
      break
    }
    if counts.get(word).unwrap_or(0) >= 3 || is_salient_concept_word(word) {
      let normalized = normalize_concept_name(word)
      if !normalized.is_empty() && !selected.contains(normalized) {
        selected.push(normalized)
      }
    }
  }
  selected
}

///|
fn extract_claim_statements(content : String) -> Array[String] {
  let claims : Array[String] = []
  for raw in content.split("\n") {
    let line = strip_inline_markup(raw.trim().to_string())
    if line.is_empty() || line.has_prefix("#") || line.has_prefix("- ") {
      continue
    }
    if likely_claim_line(line) && !claims.contains(line) {
      claims.push(clamp_excerpt(line))
      if claims.length() >= 5 {
        break
      }
    }
  }
  claims
}

///|
fn extract_structured_claims(content : String) -> Array[StructuredClaim] {
  let claims : Array[StructuredClaim] = []
  for statement in extract_claim_statements(content) {
    match parse_structured_claim(statement) {
      Some(claim) =>
        if !claims.map(claim_ => claim_.id()).contains(claim.id()) {
          claims.push(claim)
        }
      None => ()
    }
  }
  claims
}

///|
fn parse_structured_claim(statement : String) -> StructuredClaim? {
  let lowered = statement.to_lower()
  match lowered.find(" integrates with ") {
    Some(index) =>
      Some({
        subject: normalize_entity_name(statement[:index].trim().to_string()),
        predicate: normalize_claim_fragment(
          statement[index + 17:].trim().to_string(),
        ),
        confidence: "medium",
      })
    None =>
      match lowered.find(" keeps ") {
        Some(index) =>
          Some({
            subject: normalize_entity_name(statement[:index].trim().to_string()),
            predicate: "keeps " +
            normalize_claim_fragment(statement[index + 7:].trim().to_string()),
            confidence: "low",
          })
        None =>
          match lowered.find(" improves ") {
            Some(index) =>
              Some({
                subject: normalize_entity_name(
                  statement[:index].trim().to_string(),
                ),
                predicate: "improves " +
                normalize_claim_fragment(
                  statement[index + 10:].trim().to_string(),
                ),
                confidence: "low",
              })
            None =>
              match lowered.find(" supports ") {
                Some(index) =>
                  Some({
                    subject: normalize_entity_name(
                      statement[:index].trim().to_string(),
                    ),
                    predicate: "supports " +
                    normalize_claim_fragment(
                      statement[index + 10:].trim().to_string(),
                    ),
                    confidence: "medium",
                  })
                None =>
                  match lowered.find(" uses ") {
                    Some(index) =>
                      Some({
                        subject: normalize_entity_name(
                          statement[:index].trim().to_string(),
                        ),
                        predicate: "uses " +
                        normalize_claim_fragment(
                          statement[index + 6:].trim().to_string(),
                        ),
                        confidence: "medium",
                      })
                    None =>
                      match lowered.find(" is ") {
                        Some(index) =>
                          Some({
                            subject: normalize_entity_name(
                              statement[:index].trim().to_string(),
                            ),
                            predicate: normalize_claim_fragment(
                              statement[index + 4:].trim().to_string(),
                            ),
                            confidence: "medium",
                          })
                        None => None
                      }
                  }
              }
          }
      }
  }
}

///|
fn candidate_titlecase_phrases(text : String) -> Array[String] {
  let words = split_words(text)
  let phrases : Array[String] = []
  let mut current : Array[String] = []
  for word in words {
    if is_titlecase_word(word) {
      current.push(word)
      if current.length() >= 3 {
        phrases.push(current.join(" "))
        current = []
      }
    } else if !current.is_empty() {
      phrases.push(current.join(" "))
      current = []
    }
  }
  if !current.is_empty() {
    phrases.push(current.join(" "))
  }
  phrases
}

///|
fn normalize_entity_name(text : String) -> String {
  let cleaned = strip_leading_determiner(clean_phrase(text))
  match cleaned.to_lower() {
    "openclaw" => "OpenClaw"
    "moonclaw" => "MoonClaw"
    "moontown" => "Moontown"
    "feishu" => "Feishu"
    "nodejs" | "node-js" | "node.js" => "Node.js"
    "powershell" => "PowerShell"
    "wsl2" => "WSL2"
    "git" => "Git"
    "nginx" => "Nginx"
    "docker" => "Docker"
    "volcengine" => "Volcengine"
    "kimi" => "Kimi"
    "imessage" => "iMessage"
    "tailscale" => "Tailscale"
    _ => cleaned
  }
}

///|
fn normalize_concept_name(text : String) -> String {
  clean_phrase(text).to_lower()
}

///|
fn normalize_claim_fragment(text : String) -> String {
  clean_phrase(text)
}

///|
fn clean_phrase(text : String) -> String {
  strip_surrounding_punctuation(text.trim().to_string())
}

///|
fn strip_leading_determiner(text : String) -> String {
  if text.has_prefix("The ") {
    text[4:].to_string()
  } else if text.has_prefix("A ") {
    text[2:].to_string()
  } else if text.has_prefix("An ") {
    text[3:].to_string()
  } else {
    text
  }
}

///|
fn strip_surrounding_punctuation(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end && is_trimmable_punctuation(text[start]) {
    start += 1
  }
  while end > start && is_trimmable_punctuation(text[end - 1]) {
    end -= 1
  }
  text[start:end].trim().to_string()
}

///|
fn is_trimmable_punctuation(c : UInt16) -> Bool {
  let value = c.to_int()
  value == '.'.to_int() ||
  value == ','.to_int() ||
  value == ':'.to_int() ||
  value == ';'.to_int() ||
  value == '!'.to_int() ||
  value == '?'.to_int() ||
  value == '"'.to_int() ||
  value == '\''.to_int() ||
  value == '('.to_int() ||
  value == ')'.to_int()
}

///|
fn lowercase_word_candidates(text : String) -> Array[String] {
  let words : Array[String] = []
  for word in split_words(text) {
    let lower = word.to_lower()
    if lower == word {
      words.push(lower)
    }
  }
  words
}

///|
fn split_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let builder = StringBuilder::new()
  for c in text {
    if is_word_char(c) {
      builder.write_char(c)
    } else if builder.to_string() != "" {
      words.push(builder.to_string())
      builder.reset()
    }
  }
  if builder.to_string() != "" {
    words.push(builder.to_string())
  }
  words
}

///|
fn is_word_char(c : Char) -> Bool {
  let value = c.to_int()
  (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
  (value >= 'A'.to_int() && value <= 'Z'.to_int()) ||
  (value >= '0'.to_int() && value <= '9'.to_int()) ||
  value == '-'.to_int()
}

///|
fn is_titlecase_word(word : String) -> Bool {
  if word.length() < 3 {
    return false
  }
  let first = word[0].to_int()
  let second = if word.length() > 1 { word[1].to_int() } else { 0 }
  first >= 'A'.to_int() &&
  first <= 'Z'.to_int() &&
  second >= 'a'.to_int() &&
  second <= 'z'.to_int()
}

///|
fn should_keep_entity_phrase(phrase : String) -> Bool {
  let words = split_words(phrase)
  if words.is_empty() || phrase.length() < 3 {
    return false
  }
  for word in words {
    match word {
      "The"
      | "This"
      | "That"
      | "These"
      | "Those"
      | "Source"
      | "Overview"
      | "Notes"
      | "Guide"
      | "Chapter"
      | "Summary"
      | "QuickStart"
      | "Version"
      | "Status"
      | "Token"
      | "Secret"
      | "App"
      | "Yes"
      | "No"
      | "Skip" => return false
      _ => ()
    }
  }
  true
}

///|
fn should_keep_concept_word(word : String) -> Bool {
  if word.length() < 5 {
    return false
  }
  match word {
    "about"
    | "there"
    | "which"
    | "their"
    | "would"
    | "could"
    | "should"
    | "source"
    | "title"
    | "query"
    | "pages"
    | "page"
    | "keeps"
    | "improves"
    | "integrates"
    | "mentioned"
    | "review"
    | "using"
    | "where"
    | "these"
    | "those"
    | "wiki"
    | "index"
    | "summary"
    | "portal"
    | "upload"
    | "volcfe"
    | "status"
    | "token"
    | "secret"
    | "quickstart" => false
    _ => true
  }
}

///|
fn detect_known_entities(title : String, content : String) -> Array[String] {
  let title_lowered = title.to_lower()
  let lowered = (title + "\n" + content).to_lower()
  let ranked : Array[(String, Int)] = []
  let known : Array[(String, String)] = [
    ("openclaw", "OpenClaw"),
    ("moonclaw", "MoonClaw"),
    ("moontown", "Moontown"),
    ("feishu", "Feishu"),
    ("node.js", "Node.js"),
    ("nodejs", "Node.js"),
    ("powershell", "PowerShell"),
    ("wsl2", "WSL2"),
    ("volcengine", "Volcengine"),
    ("kimi", "Kimi"),
    ("git", "Git"),
    ("nginx", "Nginx"),
    ("docker", "Docker"),
    ("tailscale", "Tailscale"),
    ("imessage", "iMessage"),
  ]
  for item in known {
    let pattern = item.0
    let label = item.1
    let occurrences = count_substring(lowered, pattern)
    let mut score = occurrences * 10
    if title_lowered.contains(pattern) {
      score += 100
    }
    if score >= 20 || score >= 100 {
      ranked.push((label, score))
    }
  }
  ranked.sort_by(fn(left, right) {
    if left.1 == right.1 {
      left.0.compare(right.0)
    } else {
      right.1.compare(left.1)
    }
  })
  let entities : Array[String] = []
  for item in ranked {
    if entities.length() >= 5 {
      break
    }
    if !entities.contains(item.0) {
      entities.push(item.0)
    }
  }
  entities
}

///|
fn count_substring(text : String, pattern : String) -> Int {
  if pattern.is_empty() {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start < text.length() {
    match text[start:].find(pattern) {
      Some(index) => {
        count += 1
        start += index + pattern.length()
      }
      None => break
    }
  }
  count
}

///|
fn detect_canonical_concepts(text : String) -> Array[String] {
  let lowered = text.to_lower()
  let concepts : Array[String] = []
  if lowered.contains("install") ||
    lowered.contains("onboard") ||
    lowered.contains("npm") ||
    lowered.contains("pnpm") ||
    lowered.contains("source build") {
    concepts.push("installation methods")
  }
  if lowered.contains("gateway") ||
    lowered.contains("restart") ||
    lowered.contains("daemon") ||
    lowered.contains("status") ||
    lowered.contains("service") {
    concepts.push("gateway operations")
  }
  if lowered.contains("feishu") ||
    lowered.contains("channel") ||
    lowered.contains("plugin") ||
    lowered.contains("imessage") ||
    lowered.contains("pairing") {
    concepts.push("channel integration")
  }
  if lowered.contains("windows") ||
    lowered.contains("macos") ||
    lowered.contains("wsl") ||
    lowered.contains("server") ||
    lowered.contains("cloud") {
    concepts.push("deployment environments")
  }
  if lowered.contains("troubleshoot") ||
    lowered.contains("error") ||
    lowered.contains("verify") ||
    lowered.contains("validation") ||
    lowered.contains("常见问题") ||
    lowered.contains("验证") {
    concepts.push("troubleshooting patterns")
  }
  concepts
}

///|
fn source_signal_text(
  title : String,
  path : String,
  content : String,
) -> String {
  title + "\n" + file_stem(path) + "\n" + content
}

///|
fn detect_source_type(
  title : String,
  path : String,
  content : String,
) -> String {
  let title_lowered = (title + "\n" + file_stem(path)).to_lower()
  let lowered = source_signal_text(title, path, content).to_lower()
  if title_lowered.contains("install") ||
    title_lowered.contains("安装") ||
    title_lowered.contains("部署") ||
    title_lowered.contains("onboard") {
    "installation guide"
  } else if title_lowered.contains("troubleshoot") ||
    title_lowered.contains("常见问题") ||
    title_lowered.contains("验证") ||
    lowered.contains("troubleshoot") ||
    lowered.contains("常见问题") ||
    lowered.contains("验证") {
    "troubleshooting guide"
  } else if title_lowered.contains("reference") ||
    title_lowered.contains("api") ||
    lowered.contains("reference") ||
    lowered.contains("api") {
    "reference"
  } else if lowered.contains("install") ||
    lowered.contains("部署") ||
    lowered.contains("onboard") {
    "installation guide"
  } else {
    "source summary"
  }
}

///|
fn detect_source_scope(
  title : String,
  path : String,
  content : String,
) -> String {
  let title_lowered = (title + "\n" + file_stem(path)).to_lower()
  let lowered = source_signal_text(title, path, content).to_lower()
  let environment = if title_lowered.contains("macos") {
    "macOS"
  } else if title_lowered.contains("wsl") {
    "Windows + WSL2"
  } else if title_lowered.contains("windows") {
    "Windows"
  } else if lowered.contains("macos") {
    "macOS"
  } else if lowered.contains("wsl") {
    "Windows + WSL2"
  } else if lowered.contains("windows") {
    "Windows"
  } else {
    "mixed environments"
  }
  let focus = if title_lowered.contains("troubleshoot") ||
    title_lowered.contains("验证") ||
    title_lowered.contains("常见问题") ||
    lowered.contains("troubleshoot") ||
    lowered.contains("验证") ||
    lowered.contains("常见问题") {
    "verification and recovery"
  } else if title_lowered.contains("install") ||
    title_lowered.contains("安装") ||
    title_lowered.contains("部署") ||
    title_lowered.contains("onboard") {
    "installation and onboarding"
  } else if title_lowered.contains("gateway") ||
    title_lowered.contains("config") ||
    title_lowered.contains("token") ||
    lowered.contains("gateway") ||
    lowered.contains("config") ||
    lowered.contains("token") {
    "configuration and operations"
  } else if lowered.contains("install") ||
    lowered.contains("部署") ||
    lowered.contains("onboard") {
    "installation and onboarding"
  } else {
    "general operational guidance"
  }
  "\{environment}; \{focus}"
}

///|
fn detect_source_signals(
  title : String,
  path : String,
  content : String,
) -> Array[String] {
  let lowered = source_signal_text(title, path, content).to_lower()
  let signals : Array[String] = []
  if lowered.contains("wsl") {
    signals.push("WSL2 is a first-class path in this source.")
  }
  if lowered.contains("gateway") && lowered.contains("restart") {
    signals.push("Gateway restart is part of the operational flow.")
  }
  if lowered.contains("feishu") || lowered.contains("imessage") {
    signals.push(
      "Channel integration appears in the source and should stay separate from base installation.",
    )
  }
  if lowered.contains("token") ||
    lowered.contains("api key") ||
    lowered.contains("model") {
    signals.push(
      "Configuration secrets and model settings are operationally important.",
    )
  }
  if lowered.contains("install script") ||
    lowered.contains("npm") ||
    lowered.contains("pnpm") {
    signals.push("Multiple installation methods are described.")
  }
  signals
}

///|
fn render_source_signals(signals : Array[String]) -> String {
  if signals.is_empty() {
    ""
  } else {
    "## Key Signals\n\n" +
    signals.map(signal => "- " + signal + "\n").join("") +
    "\n"
  }
}

///|
fn is_salient_concept_word(word : String) -> Bool {
  has_any_suffix(word, [
    "tion", "ment", "ness", "ity", "ism", "ship", "ance", "ence", "ing",
  ]) ||
  [
    "runtime", "pipeline", "synthesis", "confidence", "ingestion", "integration",
    "workflow", "state", "memory", "evidence", "claims", "claim", "contradiction",
    "support", "query", "queries", "entity", "concept",
  ].contains(word)
}

///|
fn has_any_suffix(text : String, suffixes : Array[String]) -> Bool {
  for suffix in suffixes {
    if text.has_suffix(suffix) {
      return true
    }
  }
  false
}

///|
fn likely_claim_line(line : String) -> Bool {
  line.contains(" is ") ||
  line.contains(" integrates with ") ||
  line.contains(" uses ") ||
  line.contains(" supports ") ||
  line.contains(" improves ") ||
  line.contains(" keeps ")
}

///|
fn rank_phrase_counts(counts : Map[String, Int]) -> Array[String] {
  let pairs : Array[(String, Int)] = []
  for key, value in counts {
    pairs.push((key, value))
  }
  pairs.sort_by(fn(left, right) {
    if left.1 == right.1 {
      left.0.compare(right.0)
    } else {
      right.1.compare(left.1)
    }
  })
  let ranked : Array[String] = []
  for pair in pairs {
    ranked.push(pair.0)
  }
  ranked
}

///|
fn title_case(text : String) -> String {
  if text.is_empty() {
    return text
  }
  let builder = StringBuilder::new()
  let mut capitalize = true
  for c in text {
    if c == ' ' || c == '-' {
      builder.write_char(c)
      capitalize = true
    } else if capitalize {
      let value = c.to_int()
      if value >= 'a'.to_int() && value <= 'z'.to_int() {
        builder.write_char(Int::unsafe_to_char(value - 32))
      } else {
        builder.write_char(c)
      }
      capitalize = false
    } else {
      builder.write_char(c)
    }
  }
  builder.to_string()
}

///|
fn relative_to_root(path : String, root : String) -> String {
  let normalized_path = @pathx.normalize(path)
  let normalized_root = @pathx.normalize(root)
  if normalized_path == normalized_root {
    "."
  } else if normalized_path.has_prefix(normalized_root + "/") {
    normalized_path[normalized_root.length() + 1:].to_string()
  } else {
    normalized_path
  }
}

///|
fn relative_from_page(
  page_relative : String,
  target_relative : String,
) -> String {
  let from_dir = @path.Path(page_relative).dirname().to_string()
  let from_parts = split_segments(from_dir)
  let to_parts = split_segments(target_relative)
  let mut shared = 0
  while shared < from_parts.length() &&
        shared < to_parts.length() &&
        from_parts[shared] == to_parts[shared] {
    shared += 1
  }
  let pieces : Array[String] = []
  for back = shared; back < from_parts.length(); back = back + 1 {
    pieces.push("..")
  }
  for i = shared; i < to_parts.length(); i = i + 1 {
    pieces.push(to_parts[i])
  }
  if pieces.is_empty() {
    "."
  } else {
    pieces.join("/")
  }
}

///|
fn split_segments(path : String) -> Array[String] {
  let parts : Array[String] = []
  let normalized = @pathx.normalize(path)
  if normalized == "." || normalized.is_empty() {
    return parts
  }
  for piece in normalized.split("/") {
    let text = piece.to_string()
    if !text.is_empty() && text != "." {
      parts.push(text)
    }
  }
  parts
}

///|
fn slugify_title(title : String) -> String {
  let builder = StringBuilder::new()
  let mut wrote_dash = false
  for c in title {
    let value = c.to_int()
    if (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
      (value >= '0'.to_int() && value <= '9'.to_int()) {
      builder.write_char(c)
      wrote_dash = false
    } else if value >= 'A'.to_int() && value <= 'Z'.to_int() {
      builder.write_char(Int::unsafe_to_char(value + 32))
      wrote_dash = false
    } else if !wrote_dash {
      builder.write_char('-')
      wrote_dash = true
    }
  }
  let slug = builder
    .to_string()
    .trim()
    .to_string()
    .replace(old="--", new="-")
    .to_string()
  let slug = if slug.has_suffix("-") {
    slug[:slug.length() - 1].to_string()
  } else {
    slug
  }
  if slug.is_empty() {
    "source"
  } else {
    slug
  }
}

///|
async fn unique_source_slug(sources_dir : String, slug : String) -> String {
  let mut index = 0
  while true {
    let candidate = if index == 0 { slug } else { "\{slug}-\{index}" }
    let path = @path.Path(sources_dir)
      .join(@path.Path(candidate + ".md"))
      .to_string()
    if !@fsx.exists(path) {
      return candidate
    }
    index += 1
  }
  slug
}

///|
fn file_stem(path : String) -> String {
  let base = @path.Path(path).basename().to_string()
  let ext = @pathx.ext(base).to_string()
  if ext.is_empty() {
    base
  } else {
    base[:base.length() - ext.length()].to_string()
  }
}

///|
fn escape_link_label(text : String) -> String {
  text
  .replace(old="[", new="(")
  .to_string()
  .replace(old="]", new=")")
  .to_string()
}

///|
fn is_text_source(path : String) -> Bool {
  match @pathx.ext(path).to_string().to_lower() {
    ".md"
    | ".markdown"
    | ".txt"
    | ".html"
    | ".htm"
    | ".json"
    | ".yaml"
    | ".yml"
    | ".csv" => true
    _ => false
  }
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
  assert_eq(updated, content)
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
}
