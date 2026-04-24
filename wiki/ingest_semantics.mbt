///|
// Claim, entity, concept, and ontology extraction helpers for wiki ingest.

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
  let entries = collect_index_section_entries(content, section_title)
  let merged = if entries.contains(bullet) {
    entries
  } else {
    [bullet, ..entries]
  }
  rewrite_index_section(content, section_title, merged)
}

///|
fn collect_index_section_entries(
  content : String,
  section_title : String,
) -> Array[String] {
  let target_header = "## \{section_title}"
  let entries : Array[String] = []
  let mut in_target = false
  for raw in content.split("\n") {
    let line = raw.to_string()
    if line == target_header {
      in_target = true
      continue
    }
    if in_target && line.has_prefix("## ") {
      in_target = false
    }
    if in_target && line.has_prefix("- ") && !entries.contains(line) {
      entries.push(line)
    }
  }
  entries
}

///|
fn rewrite_index_section(
  content : String,
  section_title : String,
  entries : Array[String],
) -> String {
  let target_header = "## \{section_title}"
  let lines = content.split("\n")
  let rebuilt : Array[String] = []
  let mut skipping_target = false
  let mut inserted = false
  for raw in lines {
    let line = raw.to_string()
    if line == target_header {
      if !inserted {
        insert_index_section_block(rebuilt, target_header, entries)
        inserted = true
      }
      skipping_target = true
      continue
    }
    if skipping_target && line.has_prefix("## ") {
      skipping_target = false
    }
    if skipping_target {
      continue
    }
    rebuilt.push(line)
  }
  if !inserted {
    if !rebuilt.is_empty() && rebuilt[rebuilt.length() - 1] != "" {
      rebuilt.push("")
    }
    insert_index_section_block(rebuilt, target_header, entries)
  }
  rebuilt.join("\n")
}

///|
fn insert_index_section_block(
  rebuilt : Array[String],
  target_header : String,
  entries : Array[String],
) -> Unit {
  rebuilt.push(target_header)
  rebuilt.push("")
  if entries.is_empty() {
    rebuilt.push("_None yet._")
  } else {
    for entry in entries {
      rebuilt.push(entry)
    }
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
  let section_title = section_header
    .strip_prefix("## ")
    .unwrap_or(section_header)
    .trim()
    .to_string()
  let entries = collect_index_section_entries(content, section_title)
  let merged = if entries.contains(entry) {
    entries
  } else {
    [entry, ..entries]
  }
  normalize_markdown_spacing(
    rewrite_index_section(content, section_title, merged),
  )
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
