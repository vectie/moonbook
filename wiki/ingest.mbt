///|
pub struct IngestResult {
  page_path : String
  raw_path : String
  title : String
  imported : Bool
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
  )

  { page_path, raw_path: stored_raw_path, title, imported: !source_under_raw }
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
async fn append_log(
  log_path : String,
  title : String,
  relative_raw : String,
  relative_page : String,
) -> Unit {
  let now = "\{@async.now().to_int()}"
  let entry = "## [\{now}] ingest | \{title}\n\n" +
    "- raw: `\{relative_raw}`\n" +
    "- page: `wiki/\{relative_page}`\n"
  let current = @fsx.read_file(log_path)
  let next = if current.has_suffix("\n") {
    current + "\n" + entry
  } else {
    current + "\n\n" + entry
  }
  @fsx.write_to_file(log_path, next, create=0o644)
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
