///|
pub struct IngestResult {
  page_path : String
  raw_path : String
  title : String
  imported : Bool
  related_pages : Array[String]
} derive(Show, ToJson)

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
    slugify_title(title),
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
  }
}

///|
priv struct Paths {
  root : String
  raw_dir : String
  wiki_dir : String
  summary_path : String
}

///|
fn workspace_paths(root : String) -> Paths {
  let normalized_root = @pathx.normalize(root)
  let raw_dir = @path.Path(normalized_root).join(@path.Path("raw")).to_string()
  let wiki_dir = @path.Path(normalized_root)
    .join(@path.Path("wiki"))
    .to_string()
  let summary_path = @path.Path(wiki_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  { root: normalized_root, raw_dir, wiki_dir, summary_path }
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
    let overview = summarize_source(content)
    let excerpt = excerpt_source(content, 24)
    "# \{title}\n\n" +
    "- Raw source: [\{relative_raw}](\{raw_link})\n" +
    "- Ingested at: `\{now}`\n\n" +
    "## Overview\n\n" +
    "\{overview}\n\n" +
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
  let link = "- [\{title}](./\{relative_page})"
  let current = @fsx.read_file(summary_path)
  if current.contains(link) {
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
    let synthesis_page = ensure_synthesis_overview(
      workspace,
      source_title,
      source_relative_page,
      "Binary source ingested. Review the raw file directly.",
      [],
      [],
      [],
    )
    return [synthesis_page]
  }

  let content = @fsx.read_file(stored_raw_path)
  let related_pages : Array[String] = []
  let entities = extract_candidate_entities(source_title, content)
  let concepts = extract_candidate_concepts(content)
  let claims = extract_claim_statements(content)
  for entity in entities {
    let relative = ensure_entity_page(
      workspace, entity, source_title, source_relative_page, content,
    )
    related_pages.push(relative)
  }
  for concept in concepts {
    let relative = ensure_concept_page(
      workspace, concept, source_title, source_relative_page, content,
    )
    related_pages.push(relative)
  }
  related_pages.push(
    ensure_synthesis_overview(
      workspace,
      source_title,
      source_relative_page,
      summarize_source(content),
      entities,
      concepts,
      claims,
    ),
  )
  if !claims.is_empty() {
    related_pages.push(
      ensure_claims_register(
        workspace,
        source_title,
        source_relative_page,
        claims,
      ),
    )
  }
  related_pages
}

///|
async fn ensure_entity_page(
  workspace : Paths,
  entity : String,
  source_title : String,
  source_relative_page : String,
  content : String,
) -> String {
  let slug = slugify_title(entity)
  let relative_page = "entities/\{slug}.md"
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
    ""
  }
  let updated = if existing.is_empty() {
    "# \{entity}\n\n" +
    "## Summary\n\n" +
    "\{entity_summary(entity, content)}\n\n" +
    "## Sources\n\n" +
    "- [\{source_title}](\{source_link})\n"
  } else {
    append_list_entry(
      existing,
      "## Sources",
      "- [\{source_title}](\{source_link})",
    )
  }
  @fsx.write_to_file(page_path, updated, create=0o644)
  update_summary(workspace.summary_path, entity, relative_page)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Entities",
    entity,
    relative_page,
    "entity page",
  )
  relative_page
}

///|
async fn ensure_concept_page(
  workspace : Paths,
  concept : String,
  source_title : String,
  source_relative_page : String,
  content : String,
) -> String {
  let title = title_case(concept)
  let slug = slugify_title(concept)
  let relative_page = "concepts/\{slug}.md"
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
    ""
  }
  let updated = if existing.is_empty() {
    "# \{title}\n\n" +
    "## Summary\n\n" +
    "\{concept_summary(concept, content)}\n\n" +
    "## Sources\n\n" +
    "- [\{source_title}](\{source_link})\n"
  } else {
    append_list_entry(
      existing,
      "## Sources",
      "- [\{source_title}](\{source_link})",
    )
  }
  @fsx.write_to_file(page_path, updated, create=0o644)
  update_summary(workspace.summary_path, title, relative_page)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Concepts",
    title,
    relative_page,
    "concept page",
  )
  relative_page
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
  claims : Array[String],
) -> String {
  let relative_page = "synthesis/claims.md"
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let source_link = relative_from_page(
    "wiki/" + relative_page,
    "wiki/" + source_relative_page,
  )
  let builder = StringBuilder::new()
  builder.write_string("### \{source_title}\n\n")
  builder.write_string("- Source page: [\{source_title}](\{source_link})\n")
  builder.write_string("- Confidence: `low`\n")
  builder.write_string("- Claims:\n")
  for claim in claims {
    builder.write_string("  - \{claim}\n")
  }
  builder.write_string("\n")
  let block = builder.to_string()
  let existing = if @fsx.exists(page_path) {
    @fsx.read_file(page_path)
  } else {
    ""
  }
  let updated = if existing.is_empty() {
    "# Claims Register\n\n" +
    "This page collects lightweight extracted claims from ingested sources.\n\n" +
    "## Claims\n\n" +
    block
  } else {
    append_section_block(existing, "## Claims", block)
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
  let current = @fsx.read_file(index_path)
  let bullet = "- [\{title}](./\{relative_page}): \{description}"
  if current.contains(bullet) {
    return
  }
  let placeholder = "## \{section_title}\n\n_None yet._"
  let section_header = "## \{section_title}\n"
  let next = if current.contains(placeholder) {
    current
    .replace(old=placeholder, new="## \{section_title}\n\n\{bullet}")
    .to_string()
  } else if current.contains(section_header) {
    current
    .replace(old=section_header, new="## \{section_title}\n\{bullet}\n")
    .to_string()
  } else {
    current + "\n## \{section_title}\n\n" + bullet + "\n"
  }
  @fsx.write_to_file(index_path, next, create=0o644)
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
fn summarize_source(content : String) -> String {
  let paragraph = first_nonempty_line(content)
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
fn append_list_entry(
  content : String,
  section_header : String,
  entry : String,
) -> String {
  if content.contains(entry) {
    return content
  }
  if content.contains(section_header + "\n\n") {
    content
    .replace(
      old=section_header + "\n\n",
      new=section_header + "\n\n" + entry + "\n",
    )
    .to_string()
  } else if content.contains(section_header + "\n") {
    content
    .replace(
      old=section_header + "\n",
      new=section_header + "\n" + entry + "\n",
    )
    .to_string()
  } else if content.has_suffix("\n") {
    content + "\n" + section_header + "\n\n" + entry + "\n"
  } else {
    content + "\n\n" + section_header + "\n\n" + entry + "\n"
  }
}

///|
fn append_section_block(
  content : String,
  section_header : String,
  block : String,
) -> String {
  if content.contains(block.trim().to_string()) {
    return content
  }
  if content.contains(section_header + "\n\n") {
    content
    .replace(
      old=section_header + "\n\n",
      new=section_header + "\n\n" + block + "\n",
    )
    .to_string()
  } else if content.contains(section_header + "\n") {
    content
    .replace(
      old=section_header + "\n",
      new=section_header + "\n" + block + "\n",
    )
    .to_string()
  } else if content.has_suffix("\n") {
    content + "\n" + section_header + "\n\n" + block + "\n"
  } else {
    content + "\n\n" + section_header + "\n\n" + block + "\n"
  }
}

///|
fn extract_candidate_entities(
  title : String,
  content : String,
) -> Array[String] {
  let counts : Map[String, Int] = {}
  for phrase in candidate_titlecase_phrases(title + "\n" + content) {
    if should_keep_entity_phrase(phrase) {
      counts[phrase] = counts.get(phrase).unwrap_or(0) + 1
    }
  }
  let ranked = rank_phrase_counts(counts)
  let selected : Array[String] = []
  for phrase in ranked {
    if selected.length() >= 3 {
      break
    }
    selected.push(phrase)
  }
  selected
}

///|
fn extract_candidate_concepts(content : String) -> Array[String] {
  let counts : Map[String, Int] = {}
  for word in lowercase_word_candidates(content) {
    if should_keep_concept_word(word) {
      counts[word] = counts.get(word).unwrap_or(0) + 1
    }
  }
  let ranked = rank_phrase_counts(counts)
  let selected : Array[String] = []
  for word in ranked {
    if selected.length() >= 4 {
      break
    }
    if counts.get(word).unwrap_or(0) >= 2 || is_salient_concept_word(word) {
      selected.push(word)
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
      | "Summary" => return false
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
    | "summary" => false
    _ => true
  }
}

///|
fn is_salient_concept_word(word : String) -> Bool {
  has_any_suffix(word, [
    "tion", "ment", "ness", "ity", "ism", "ship", "ance", "ence", "ing",
  ]) || [
    "runtime",
    "pipeline",
    "synthesis",
    "confidence",
    "ingestion",
    "integration",
    "workflow",
    "state",
    "memory",
    "evidence",
    "claims",
    "claim",
    "contradiction",
    "support",
    "query",
    "queries",
    "entity",
    "concept",
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
fn entity_summary(entity : String, content : String) -> String {
  first_matching_sentence(content, entity).unwrap_or(
    "\{entity} is mentioned in the current source and should be refined as more sources arrive.",
  )
}

///|
fn concept_summary(concept : String, content : String) -> String {
  first_matching_sentence(content, concept).unwrap_or(
    "The concept `\{concept}` appears in the current source and should be refined as the wiki accumulates more evidence.",
  )
}

///|
fn first_matching_sentence(content : String, needle : String) -> String? {
  for raw in content.split("\n") {
    let line = strip_inline_markup(raw.trim().to_string())
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    if line.to_lower().contains(needle.to_lower()) {
      return Some(clamp_excerpt(line))
    }
  }
  None
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
test "extract claim statements keeps simple grounded lines" {
  let claims = extract_claim_statements(
    "OpenClaw integrates with MoonClaw runtime.\nThe system improves synthesis.\n",
  )
  assert_eq(claims.length(), 2)
}

///|
test "append list entry avoids duplicates" {
  let content = "# Demo\n\n## Sources\n\n- [One](./one.md)\n"
  let updated = append_list_entry(content, "## Sources", "- [One](./one.md)")
  assert_eq(updated, content)
}
