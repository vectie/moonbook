///|
pub struct QueryResult {
  question : String
  answer : String
  citations : Array[String]
  saved_page : String?
} derive(Show, ToJson)

///|
priv struct QueryMatch {
  path : String
  relative_path : String
  title : String
  excerpt : String
  score : Int
}

///|
pub async fn query_wiki(
  root : String,
  question : String,
  save? : Bool = false,
) -> QueryResult {
  let workspace = workspace_paths(root)
  let page_paths = collect_markdown_pages(workspace.wiki_dir)
  let terms = query_terms(question)
  if terms.is_empty() {
    fail("query must contain at least one searchable term")
  }
  let matches = rank_matches(page_paths, workspace.root, terms)
  let selected = top_matches(matches, 3)
  if selected.is_empty() {
    let answer = no_results_answer(question)
    let saved_page = if save {
      Some(save_query_answer(workspace, question, answer, []))
    } else {
      None
    }
    return { question, answer, citations: [], saved_page }
  }
  let answer = answer_text(question, selected)
  let citations = selected.map(match_ => match_.relative_path)
  let saved_page = if save {
    Some(save_query_answer(workspace, question, answer, citations))
  } else {
    None
  }
  { question, answer, citations, saved_page }
}

///|
async fn collect_markdown_pages(root : String) -> Array[String] {
  let pages : Array[String] = []
  scan_markdown_pages(root, pages)
  pages.sort()
  pages
}

///|
async fn scan_markdown_pages(path : String, pages : Array[String]) -> Unit {
  if !@fsx.exists(path) {
    return
  }
  match @fs.kind(path, follow_symlink=false) {
    @fs.FileKind::Directory =>
      for child in @fsx.list_directory(path) {
        scan_markdown_pages(child, pages)
      }
    @fs.FileKind::Regular => if is_queryable_page(path) { pages.push(path) }
    _ => ()
  }
}

///|
fn is_queryable_page(path : String) -> Bool {
  let normalized = @pathx.normalize(path)
  let base = @path.Path(normalized).basename().to_string()
  @pathx.ext(normalized).to_string() == ".md" && base != "SUMMARY.md"
}

///|
async fn rank_matches(
  page_paths : Array[String],
  root : String,
  terms : Array[String],
) -> Array[QueryMatch] {
  let matches : Array[QueryMatch] = []
  for path in page_paths {
    let content = @fsx.read_file(path)
    let title = detect_page_title(path, content)
    let score = relevance_score(title, content, terms)
    if score > 0 {
      matches.push({
        path,
        relative_path: relative_to_root(path, root),
        title,
        excerpt: matching_excerpt(content, terms),
        score,
      })
    }
  }
  matches.sort_by(fn(a, b) {
    if a.score == b.score {
      relative_to_root(a.path, root).compare(relative_to_root(b.path, root))
    } else {
      b.score.compare(a.score)
    }
  })
  matches
}

///|
fn detect_page_title(path : String, content : String) -> String {
  let heading = first_markdown_heading(content)
  if !heading.is_empty() {
    heading
  } else {
    file_stem(path)
  }
}

///|
fn relevance_score(
  title : String,
  content : String,
  terms : Array[String],
) -> Int {
  let haystack_title = title.to_lower()
  let haystack_content = content.to_lower()
  let mut score = 0
  for term in terms {
    if haystack_title.contains(term) {
      score += 6
    }
    score += occurrence_count(haystack_content, term)
  }
  score
}

///|
fn occurrence_count(text : String, pattern : String) -> Int {
  if pattern.is_empty() {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start < text.length() {
    match text[start:].find(pattern) {
      Some(offset) => {
        count += 1
        start = start + offset + pattern.length()
      }
      None => break
    }
  }
  count
}

///|
fn matching_excerpt(content : String, terms : Array[String]) -> String {
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let lower = line.to_lower()
    for term in terms {
      if lower.contains(term) {
        return clamp_excerpt(strip_inline_markup(line))
      }
    }
  }
  clamp_excerpt(strip_inline_markup(first_nonempty_line(content)))
}

///|
fn clamp_excerpt(text : String) -> String {
  if text.is_empty() {
    "No excerpt available."
  } else if text.length() > 220 {
    text[:220].to_string() + "..."
  } else {
    text
  }
}

///|
fn top_matches(matches : Array[QueryMatch], limit : Int) -> Array[QueryMatch] {
  let selected : Array[QueryMatch] = []
  for i = 0; i < matches.length() && i < limit; i = i + 1 {
    selected.push(matches[i])
  }
  selected
}

///|
fn answer_text(question : String, matches : Array[QueryMatch]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# Query: \{question}\n\n")
  builder.write_string("## Answer\n\n")
  builder.write_string(
    "Based on the current wiki pages, the strongest matches are summarized below.\n\n",
  )
  builder.write_string("## Relevant Pages\n\n")
  for match_ in matches {
    builder.write_string("- `\{match_.relative_path}`: \{match_.title}\n")
  }
  builder.write_string("\n## Extracts\n\n")
  for match_ in matches {
    builder.write_string("### \{match_.title}\n\n")
    builder.write_string("> \{match_.excerpt}\n\n")
  }
  builder.write_string("## Citations\n\n")
  for match_ in matches {
    builder.write_string("- `\{match_.relative_path}`\n")
  }
  builder.to_string()
}

///|
fn no_results_answer(question : String) -> String {
  "# Query: \{question}\n\n" +
  "## Answer\n\n" +
  "No relevant wiki pages were found for this query.\n"
}

///|
async fn save_query_answer(
  workspace : Paths,
  question : String,
  answer : String,
  citations : Array[String],
) -> String {
  let queries_dir = @path.Path(workspace.wiki_dir)
    .join(@path.Path("queries"))
    .to_string()
  @fsx.make_directory(queries_dir, recursive=true, exists_ok=true)
  let slug = unique_source_slug(queries_dir, slugify_title(question))
  let relative_page = "queries/\{slug}.md"
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let page = saved_query_text(question, answer, citations)
  @fsx.write_to_file(page_path, page, create=0o644)
  update_summary(workspace.summary_path, "Query: \{question}", relative_page)
  update_analysis_index(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    question,
    relative_page,
  )
  append_query_log(
    @path.Path(workspace.wiki_dir).join(@path.Path("log.md")).to_string(),
    question,
    relative_page,
  )
  page_path
}

///|
fn saved_query_text(
  question : String,
  answer : String,
  citations : Array[String],
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# Query: \{question}\n\n")
  builder.write_string("- Saved at: `\{@async.now().to_int()}`\n")
  if !citations.is_empty() {
    builder.write_string("- Citations:\n")
    for citation in citations {
      builder.write_string("  - `\{citation}`\n")
    }
    builder.write_string("\n")
  } else {
    builder.write_string("\n")
  }
  builder.write_string(answer)
  builder.write_string("\n")
  builder.to_string()
}

///|
async fn update_analysis_index(
  index_path : String,
  question : String,
  relative_page : String,
) -> Unit {
  let current = @fsx.read_file(index_path)
  let bullet = "- [Query: \{question}](./\{relative_page}): saved query result"
  if current.contains(bullet) {
    return
  }
  let next = if current.contains("## Queries\n\n_None yet._") {
    current
    .replace(old="## Queries\n\n_None yet._", new="## Queries\n\n\{bullet}")
    .to_string()
  } else if current.contains("## Queries\n") {
    current
    .replace(old="## Queries\n", new="## Queries\n\{bullet}\n")
    .to_string()
  } else {
    current + "\n## Queries\n\n" + bullet + "\n"
  }
  @fsx.write_to_file(index_path, next, create=0o644)
}

///|
async fn append_query_log(
  log_path : String,
  question : String,
  relative_page : String,
) -> Unit {
  let now = "\{@async.now().to_int()}"
  let entry = "## [\{now}] query | \{question}\n\n" +
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
fn query_terms(question : String) -> Array[String] {
  let cleaned = question
    .to_lower()
    .replace(old="?", new=" ")
    .to_string()
    .replace(old="!", new=" ")
    .to_string()
    .replace(old=",", new=" ")
    .to_string()
    .replace(old=".", new=" ")
    .to_string()
    .replace(old=":", new=" ")
    .to_string()
  let terms : Array[String] = []
  for piece in cleaned.split(" ") {
    let text = piece.trim().to_string()
    if text.length() >= 2 {
      terms.push(text)
    }
  }
  terms
}

///|
test "query terms normalizes punctuation" {
  assert_eq(query_terms("Alpha, beta? A!"), ["alpha", "beta"])
}

///|
test "occurrence count finds repeated matches" {
  assert_eq(occurrence_count("alpha beta alpha", "alpha"), 2)
}

///|
test "matching excerpt prefers matching line" {
  let excerpt = matching_excerpt(
    "# Title\n\nfirst line\n\nrelevant alpha note\n",
    ["alpha"],
  )
  assert_eq(excerpt, "relevant alpha note")
}
