///|
pub struct LintFinding {
  kind : String
  path : String?
  message : String
} derive(Show, ToJson)

///|
pub struct LintResult {
  findings : Array[LintFinding]
  report : String
} derive(Show, ToJson)

///|
pub async fn lint_wiki(root : String) -> LintResult {
  let workspace = lint_paths(root)
  let page_paths = collect_lint_pages(workspace.wiki_dir)
  let relative_pages = page_paths.map(path => {
    relative_to_root(path, workspace.root)
  })
  let summary_text = @fsx.read_file(workspace.summary_path)
  let index_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("index.md"))
    .to_string()
  let index_text = @fsx.read_file(index_path)
  let findings : Array[LintFinding] = []
  let contents = page_content_map(page_paths, workspace.root)

  let inbound = inbound_link_counts(page_paths, workspace.root)
  let summary_links = extract_markdown_links(summary_text)
  let tracked_pages = builtin_tracked_pages()

  for relative_page in relative_pages {
    let absolute = @path.Path(workspace.root)
      .join(@path.Path(relative_page))
      .to_string()
    if tracked_pages.contains(relative_page) {
      continue
    }
    let inbound_count = inbound.get(relative_page).unwrap_or(0)
    let in_summary = summary_links.contains("./" + relative_page) ||
      summary_links.contains(relative_page)
    if !in_summary && inbound_count == 0 {
      findings.push({
        kind: "orphan-page",
        path: Some(relative_page),
        message: "page has no inbound links and is not listed in SUMMARY.md",
      })
    }
    let index_reference = relative_page
      .strip_prefix("wiki/")
      .unwrap_or(relative_page)
      .to_string()
    if !index_text.contains(relative_page) &&
      !index_text.contains(index_reference) &&
      !index_text.contains("./" + index_reference) {
      findings.push({
        kind: "missing-index-entry",
        path: Some(relative_page),
        message: "page is not referenced from wiki/index.md",
      })
    }
    if relative_page.has_prefix("wiki/sources/") {
      let content = @fsx.read_file(absolute)
      if !content.contains("- Raw source: [") {
        findings.push({
          kind: "missing-raw-link",
          path: Some(relative_page),
          message: "source page does not include a Raw source link",
        })
      }
    }
  }

  for placeholder in index_placeholders(index_text) {
    findings.push({
      kind: "placeholder-section",
      path: Some("wiki/index.md"),
      message: placeholder,
    })
  }
  for finding in stale_wording_findings(contents) {
    findings.push(finding)
  }
  for finding in contradiction_findings(contents) {
    findings.push(finding)
  }

  let report = lint_report(findings)
  append_lint_log(
    @path.Path(workspace.wiki_dir).join(@path.Path("log.md")).to_string(),
    findings.length(),
  )
  { findings, report }
}

///|
priv struct LintPaths {
  root : String
  wiki_dir : String
  summary_path : String
}

///|
fn lint_paths(root : String) -> LintPaths {
  let normalized_root = @pathx.normalize(root)
  let wiki_dir = @path.Path(normalized_root)
    .join(@path.Path("wiki"))
    .to_string()
  let summary_path = @path.Path(wiki_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  { root: normalized_root, wiki_dir, summary_path }
}

///|
async fn collect_lint_pages(root : String) -> Array[String] {
  let pages : Array[String] = []
  scan_lint_pages(root, pages)
  pages.sort()
  pages
}

///|
async fn scan_lint_pages(path : String, pages : Array[String]) -> Unit {
  if !@fsx.exists(path) {
    return
  }
  match @fs.kind(path, follow_symlink=false) {
    @fs.FileKind::Directory =>
      for child in @fsx.list_directory(path) {
        scan_lint_pages(child, pages)
      }
    @fs.FileKind::Regular =>
      if @pathx.ext(path).to_string() == ".md" &&
        @path.Path(path).basename().to_string() != "SUMMARY.md" {
        pages.push(path)
      }
    _ => ()
  }
}

///|
async fn inbound_link_counts(
  page_paths : Array[String],
  root : String,
) -> Map[String, Int] {
  let counts : Map[String, Int] = {}
  for path in page_paths {
    let current_relative = relative_to_root(path, root)
    let current_dir = @path.Path(current_relative).dirname().to_string()
    let content = @fsx.read_file(path)
    for link in extract_markdown_links(content) {
      if !link.has_suffix(".md") {
        continue
      }
      let normalized = normalize_page_link(current_dir, link)
      counts[normalized] = counts.get(normalized).unwrap_or(0) + 1
    }
  }
  counts
}

///|
async fn page_content_map(
  page_paths : Array[String],
  root : String,
) -> Map[String, String] {
  let contents : Map[String, String] = {}
  for path in page_paths {
    contents[relative_to_root(path, root)] = @fsx.read_file(path)
  }
  contents
}

///|
fn extract_markdown_links(markdown : String) -> Array[String] {
  let links : Array[String] = []
  let mut i = 0
  while i < markdown.length() {
    if markdown[i] == '[' {
      match markdown[i + 1:].find("](") {
        Some(mid) => {
          let close_index = i + 1 + mid
          match markdown[close_index + 2:].find(")") {
            Some(end) => {
              links.push(
                markdown[close_index + 2:close_index + 2 + end].to_string(),
              )
              i = close_index + end + 3
            }
            None => i += 1
          }
        }
        None => i += 1
      }
    } else {
      i += 1
    }
  }
  links
}

///|
fn normalize_page_link(current_dir : String, link : String) -> String {
  let plain = strip_link_anchor(link)
  if plain.has_prefix("./") || plain.has_prefix("../") {
    @pathx.normalize(@pathx.join(current_dir, plain))
  } else {
    @pathx.normalize(plain)
  }
}

///|
fn strip_link_anchor(link : String) -> String {
  match link.find("#") {
    Some(index) => link[:index].to_string()
    None => link
  }
}

///|
fn builtin_tracked_pages() -> Array[String] {
  ["wiki/Home.md", "wiki/index.md", "wiki/log.md"]
}

///|
fn index_placeholders(index_text : String) -> Array[String] {
  let findings : Array[String] = []
  if index_text.contains("## Entities\n\n_None yet._") {
    findings.push("Entities section is still empty")
  }
  if index_text.contains("## Concepts\n\n_None yet._") {
    findings.push("Concepts section is still empty")
  }
  if index_text.contains("## Sources\n\n_None yet._") {
    findings.push("Sources section is still empty")
  }
  if index_text.contains("## Queries\n\n_None yet._") {
    findings.push("Queries section is still empty")
  }
  findings
}

///|
fn stale_wording_findings(contents : Map[String, String]) -> Array[LintFinding] {
  let findings : Array[LintFinding] = []
  for path in contents.keys() {
    let content = contents[path]
    for raw in content.split("\n") {
      let line = raw.trim().to_string()
      if line.is_empty() || line.has_prefix("#") || line.has_prefix("- ") {
        continue
      }
      let lower = line.to_lower()
      if contains_stale_word(lower) && !contains_explicit_year(line) {
        findings.push({
          kind: "stale-wording",
          path: Some(path),
          message: "time-sensitive wording without an explicit year/date: \{clamp_line(line)}",
        })
        break
      }
    }
  }
  findings
}

///|
fn contradiction_findings(contents : Map[String, String]) -> Array[LintFinding] {
  let findings : Array[LintFinding] = []
  let claims : Map[String, Array[Claim]] = {}
  for path in contents.keys() {
    for claim in extract_claims(path, contents[path]) {
      let bucket = claims.get(claim.subject).unwrap_or([])
      bucket.push(claim)
      claims[claim.subject] = bucket
    }
  }
  for subject in claims.keys() {
    let entries = claims[subject]
    let predicates : Array[String] = []
    for entry in entries {
      if !predicates.contains(entry.predicate) {
        predicates.push(entry.predicate)
      }
    }
    if predicates.length() >= 2 {
      let evidence = entries
        .map(entry => "\{entry.path} => \{entry.predicate}")
        .join("; ")
      findings.push({
        kind: "contradictory-claim",
        path: None,
        message: "subject `\{subject}` has conflicting `is` claims: \{evidence}",
      })
    }
  }
  findings
}

///|
priv struct Claim {
  subject : String
  predicate : String
  path : String
}

///|
fn extract_claims(path : String, content : String) -> Array[Claim] {
  let claims : Array[Claim] = []
  for raw in content.split("\n") {
    let line = strip_inline_markup(raw.trim().to_string())
    if line.is_empty() || line.has_prefix("#") || line.has_prefix("- ") {
      continue
    }
    match line.find(" is ") {
      Some(index) => {
        let subject = line[:index].trim().to_string()
        let predicate = cleanup_predicate(line[index + 4:].to_string())
        if likely_claim_subject(subject) && likely_claim_predicate(predicate) {
          claims.push({ subject, predicate, path })
        }
      }
      None => ()
    }
  }
  claims
}

///|
fn cleanup_predicate(text : String) -> String {
  let cleaned = text
    .replace(old=".", new="")
    .to_string()
    .replace(old="!", new="")
    .to_string()
    .replace(old="?", new="")
    .to_string()
  cleaned.trim().to_string()
}

///|
fn likely_claim_subject(text : String) -> Bool {
  if text.is_empty() || text.length() > 48 {
    return false
  }
  let mut words = 0
  for piece in text.split(" ") {
    if !piece.to_string().is_empty() {
      words += 1
    }
  }
  words >= 1 && words <= 6
}

///|
fn likely_claim_predicate(text : String) -> Bool {
  !text.is_empty() && text.length() <= 120
}

///|
fn contains_stale_word(text : String) -> Bool {
  text.contains("latest") ||
  text.contains("current") ||
  text.contains("recent") ||
  text.contains("today") ||
  text.contains("now")
}

///|
fn contains_explicit_year(text : String) -> Bool {
  let mut run = 0
  for c in text {
    if c >= '0' && c <= '9' {
      run += 1
      if run >= 4 {
        return true
      }
    } else {
      run = 0
    }
  }
  false
}

///|
fn clamp_line(text : String) -> String {
  if text.length() > 120 {
    text[:120].to_string() + "..."
  } else {
    text
  }
}

///|
fn lint_report(findings : Array[LintFinding]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# Wiki Lint\n\n")
  if findings.is_empty() {
    builder.write_string("No findings.\n")
    return builder.to_string()
  }
  builder.write_string("## Findings\n\n")
  for finding in findings {
    match finding.path {
      Some(path) =>
        builder.write_string(
          "- `\{finding.kind}` in `\{path}`: \{finding.message}\n",
        )
      None => builder.write_string("- `\{finding.kind}`: \{finding.message}\n")
    }
  }
  builder.to_string()
}

///|
async fn append_lint_log(log_path : String, finding_count : Int) -> Unit {
  let now = "\{@async.now().to_int()}"
  let entry = "## [\{now}] lint | wiki health check\n\n" +
    "- findings: `\{finding_count}`\n"
  let current = @fsx.read_file(log_path)
  let next = if current.has_suffix("\n") {
    current + "\n" + entry
  } else {
    current + "\n\n" + entry
  }
  @fsx.write_to_file(log_path, next, create=0o644)
}

///|
test "extract markdown links finds page targets" {
  let links = extract_markdown_links(
    "[One](./a.md) and [Two](../b.md#x) and [Skip](https://example.com)",
  )
  assert_eq(links, ["./a.md", "../b.md#x", "https://example.com"])
}

///|
test "normalize page link resolves relative page paths" {
  assert_eq(
    normalize_page_link("wiki/sources", "../queries/x.md"),
    "wiki/queries/x.md",
  )
}

///|
test "index placeholder detection reports empty sections" {
  let placeholders = index_placeholders(
    "## Entities\n\n_None yet._\n\n## Sources\n\n_None yet._\n",
  )
  assert_eq(placeholders, [
    "Entities section is still empty", "Sources section is still empty",
  ])
}

///|
test "stale wording finds time-sensitive lines without dates" {
  let findings = stale_wording_findings({
    "wiki/page.md": "The latest version is stable.\n",
  })
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].kind, "stale-wording")
}

///|
test "contradiction findings detect conflicting simple claims" {
  let findings = contradiction_findings({
    "wiki/a.md": "Alpha is red.\n",
    "wiki/b.md": "Alpha is blue.\n",
  })
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].kind, "contradictory-claim")
}
