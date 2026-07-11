///|
// MoonBook-native knowledge bundle and graph projection.

///|
fn moonbook_metadata_block(
  moonbook_type : String,
  title : String,
  summary : String,
  review_status : String,
  source_quality : String,
  tags : Array[String],
  updated_at : String,
) -> String {
  "---\n" +
  "moonbook_type: \{moonbook_type}\n" +
  "title: \"\{escape_metadata_value(title)}\"\n" +
  "summary: \"\{escape_metadata_value(clamp_excerpt(summary))}\"\n" +
  "review_status: \{review_status}\n" +
  "source_quality: \{source_quality}\n" +
  "tags: [\{tags.map(tag => escape_metadata_value(tag)).join(", ")}]\n" +
  "updated_at: \{updated_at}\n" +
  "---\n\n"
}

///|
fn escape_metadata_value(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new=" ")
}

///|
pub async fn generate_knowledge_bundle(root : String) -> KnowledgeBundle {
  let workspace = workspace_paths(root)
  normalize_knowledge_page_contracts(workspace)
  let summary = summarize_state(root)
  let health = report_health(root)
  let pages = collect_knowledge_pages(workspace)
  let graph = build_knowledge_graph(pages)
  {
    contract: knowledge_bundle_contract(),
    book_id: summary.book_id,
    root: workspace.root,
    generated_at: @async.now().to_int(),
    summary,
    health,
    pages,
    graph,
    review_queue_path: "wiki/reviews/pending.md",
    event_protocol: executable_book_event_protocol(),
  }
}

///|
/// Agent-authored durable pages may be substantively correct while omitting
/// MoonBook's machine-readable envelope. Bundle generation is the canonical
/// projection boundary, so normalize that deterministic metadata here instead
/// of asking every model prompt to reproduce boilerplate perfectly.
async fn normalize_knowledge_page_contracts(workspace : Paths) -> Unit {
  let updated_at = @async.now().to_int().to_string()
  for path in collect_markdown_pages(workspace.wiki_dir) {
    let relative = relative_to_root(path, workspace.root)
    if !(relative.has_prefix("wiki/sources/") ||
      relative.has_prefix("wiki/entities/") ||
      relative.has_prefix("wiki/concepts/") ||
      relative.has_prefix("wiki/queries/") ||
      relative.has_prefix("wiki/methods/")) {
      continue
    }
    let original = @fsx.read_file(path)
    let body = strip_moonbook_metadata_block(original)
    let page_type = infer_moonbook_page_type(relative)
    let title = detect_page_title(relative, body)
    let summary = infer_page_summary(body)
    let mut normalized_body = body.trim().to_owned()
    if page_type == "source" && !normalized_body.contains("- Raw source: [") {
      normalized_body = normalized_body +
        "\n\n## Provenance\n\n- Raw source: [research evidence packet](../../raw/bootstrap/evidence-matrix.md)"
    }
    let normalized = moonbook_metadata_block(
        page_type,
        title,
        summary,
        infer_review_status(relative, original),
        infer_page_source_quality(relative, original),
        infer_page_tags(relative, page_type),
        updated_at,
      ) +
      normalized_body +
      "\n"
    if normalized != original {
      @fsx.write_to_file(path, normalized, create=0o644)
    }
  }
}

///|
pub async fn write_knowledge_bundle(
  root : String,
  output_dir? : String? = None,
) -> String {
  let workspace = workspace_paths(root)
  let bundle = generate_knowledge_bundle(root)
  let dir = output_dir.unwrap_or(
    moonbook_wiki_path(workspace.root)
    .join(moonbook_wiki_path("book/knowledge"))
    .to_string(),
  )
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let manifest_path = moonbook_wiki_path(dir)
    .join(moonbook_wiki_path("manifest.json"))
    .to_string()
  let graph_path = moonbook_wiki_path(dir)
    .join(moonbook_wiki_path("graph.json"))
    .to_string()
  let pages_path = moonbook_wiki_path(dir)
    .join(moonbook_wiki_path("pages.json"))
    .to_string()
  @fsx.write_to_file(
    manifest_path,
    bundle.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    graph_path,
    bundle.graph.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    pages_path,
    Json::array(bundle.pages.map(page => page.to_json())).stringify(indent=2),
    create=0o644,
  )
  manifest_path
}

///|
pub async fn write_generated_knowledge_bundle(
  root : String,
  generated_dir : String,
) -> String {
  let bundle = generate_knowledge_bundle(root)
  let bundle_path = moonbook_wiki_path(generated_dir)
    .join(moonbook_wiki_path("knowledge-bundle.json"))
    .to_string()
  let graph_path = moonbook_wiki_path(generated_dir)
    .join(moonbook_wiki_path("graph.json"))
    .to_string()
  @fsx.write_to_file(
    bundle_path,
    bundle.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    graph_path,
    bundle.graph.to_json().stringify(indent=2),
    create=0o644,
  )
  bundle_path
}

///|
async fn collect_knowledge_pages(
  workspace : Paths,
) -> Array[KnowledgePageRecord] {
  let records : Array[KnowledgePageRecord] = []
  for path in collect_markdown_pages(workspace.wiki_dir) {
    let relative = relative_to_root(path, workspace.root)
    if !is_durable_knowledge_page(relative) {
      continue
    }
    let content = @fsx.read_file(path)
    records.push(knowledge_page_record(relative, content))
  }
  records
}

///|
fn is_durable_knowledge_page(relative : String) -> Bool {
  relative.has_prefix("wiki/sources/") ||
  relative.has_prefix("wiki/entities/") ||
  relative.has_prefix("wiki/concepts/") ||
  relative.has_prefix("wiki/synthesis/") ||
  relative.has_prefix("wiki/queries/") ||
  relative.has_prefix("wiki/methods/") ||
  relative.has_prefix("wiki/planning/")
}

///|
fn knowledge_page_record(
  relative : String,
  content : String,
) -> KnowledgePageRecord {
  let body = strip_moonbook_metadata_block(content)
  let moonbook_type = infer_moonbook_page_type(relative)
  let title = detect_page_title(relative, body)
  let summary = infer_page_summary(body)
  let links = extract_knowledge_links(relative, body)
  {
    path: relative,
    moonbook_type,
    title,
    summary,
    review_status: infer_review_status(relative, content),
    source_quality: infer_page_source_quality(relative, content),
    tags: infer_page_tags(relative, moonbook_type),
    outbound_links: links,
  }
}

///|
fn strip_moonbook_metadata_block(content : String) -> String {
  let trimmed = content.trim_start()
  if !trimmed.has_prefix("---") {
    return content
  }
  match trimmed[3:].find("\n---") {
    Some(offset) => trimmed[3 + offset + 4:].to_owned()
    None => content
  }
}

///|
fn infer_moonbook_page_type(relative : String) -> String {
  if relative.has_prefix("wiki/sources/") {
    "source"
  } else if relative.has_prefix("wiki/entities/") {
    "entity"
  } else if relative.has_prefix("wiki/concepts/") {
    "concept"
  } else if relative.has_prefix("wiki/queries/") {
    "query"
  } else if relative.has_prefix("wiki/planning/") {
    "plan"
  } else if relative.contains("/synthesis/claims.md") {
    "claims"
  } else if relative.has_prefix("wiki/synthesis/") {
    "synthesis"
  } else if relative.has_prefix("wiki/methods/") {
    "method"
  } else {
    "page"
  }
}

///|
fn infer_page_summary(content : String) -> String {
  for raw in content.split("\n") {
    let line = strip_inline_markup(raw.trim().to_owned())
    if line.is_empty() ||
      line.has_prefix("#") ||
      line.has_prefix("- ") ||
      line.has_prefix("|") ||
      line.has_prefix("```") ||
      line == "_None yet._" {
      continue
    }
    return clamp_excerpt(line)
  }
  "No summary available yet."
}

///|
fn infer_review_status(relative : String, content : String) -> String {
  let lowered = content.to_lower()
  if relative.contains("/reviews/pending") || lowered.contains("pending-review") {
    "pending-review"
  } else if lowered.contains("status: `pending`") ||
    lowered.contains("- status: `pending`") {
    "pending-review"
  } else if lowered.contains("status: `rejected`") {
    "rejected"
  } else {
    "accepted"
  }
}

///|
fn infer_page_source_quality(relative : String, content : String) -> String {
  if !relative.has_prefix("wiki/sources/") {
    return "not-source"
  }
  classify_source_page(content)
}

///|
fn infer_page_tags(relative : String, moonbook_type : String) -> Array[String] {
  let tags : Array[String] = [moonbook_type]
  if relative.contains("/synthesis/") && !tags.contains("synthesis") {
    tags.push("synthesis")
  }
  if relative.contains("/planning/") && !tags.contains("planning") {
    tags.push("planning")
  }
  if relative.contains("/sources/") && !tags.contains("evidence") {
    tags.push("evidence")
  }
  tags
}

///|
fn build_knowledge_graph(pages : Array[KnowledgePageRecord]) -> KnowledgeGraph {
  let edges : Array[KnowledgeGraphEdge] = []
  let known = pages.map(page => page.path)
  for page in pages {
    for link in page.outbound_links {
      if known.contains(link) {
        edges.push({ from: page.path, to: link, label: "links_to" })
      }
    }
  }
  { nodes: pages, edges }
}

///|
fn extract_knowledge_links(
  relative : String,
  content : String,
) -> Array[String] {
  let links : Array[String] = []
  let mut start = 0
  while start < content.length() {
    match content[start:].find("](") {
      Some(open_offset) => {
        let target_start = start + open_offset + 2
        match content[target_start:].find(")") {
          Some(close_offset) => {
            let raw_target = content[target_start:target_start + close_offset].to_owned()
            match normalize_knowledge_link(relative, raw_target) {
              Some(target) if !links.contains(target) => links.push(target)
              _ => ()
            }
            start = target_start + close_offset + 1
          }
          None => break
        }
      }
      None => break
    }
  }
  links
}

///|
fn normalize_knowledge_link(relative : String, target : String) -> String? {
  let cleaned = strip_link_fragment(target).trim().to_owned()
  if cleaned.is_empty() ||
    cleaned.contains("://") ||
    cleaned.has_prefix("mailto:") ||
    cleaned.has_prefix("#") {
    return None
  }
  let without_prefix = if cleaned.has_prefix("/") {
    cleaned.strip_prefix("/").unwrap_or(cleaned).to_owned()
  } else if cleaned.has_prefix("./") {
    let base_dir = relative_parent(relative)
    join_relative_knowledge_path(base_dir, cleaned[2:].to_owned())
  } else if cleaned.has_prefix("../") {
    resolve_parent_link(relative_parent(relative), cleaned)
  } else {
    let base_dir = relative_parent(relative)
    join_relative_knowledge_path(base_dir, cleaned)
  }
  let normalized = if without_prefix.has_prefix("wiki/") &&
    without_prefix.has_suffix(".md") {
    normalize_relative_segments(without_prefix)
  } else if without_prefix.has_suffix(".md") {
    normalize_relative_segments("wiki/" + without_prefix)
  } else {
    return None
  }
  if is_durable_knowledge_page(normalized) {
    Some(normalized)
  } else {
    None
  }
}

///|
fn strip_link_fragment(target : String) -> String {
  match target.find("#") {
    Some(index) => target[:index].to_owned()
    None => target
  }
}

///|
fn relative_parent(relative : String) -> String {
  match relative.rev_find("/") {
    Some(index) => relative[:index].to_owned()
    None => ""
  }
}

///|
fn join_relative_knowledge_path(base : String, child : String) -> String {
  if base.is_empty() {
    child
  } else {
    base + "/" + child
  }
}

///|
fn resolve_parent_link(base : String, target : String) -> String {
  let mut current = base
  let mut rest = target
  while rest.has_prefix("../") {
    current = relative_parent(current)
    rest = rest[3:].to_owned()
  }
  join_relative_knowledge_path(current, rest)
}

///|
fn normalize_relative_segments(path : String) -> String {
  let parts : Array[String] = []
  for part in path.split("/") {
    if part.is_empty() || part == "." {
      continue
    }
    if part == ".." {
      if !parts.is_empty() {
        let _ = parts.pop()
      }
    } else {
      parts.push(part.to_owned())
    }
  }
  parts.join("/")
}

///|
test "knowledge link normalization resolves wiki relative links" {
  assert_true(
    normalize_knowledge_link(
      "wiki/entities/moonbook.md", "../concepts/executable-book.md",
    )
    is Some("wiki/concepts/executable-book.md"),
  )
  assert_true(
    normalize_knowledge_link(
      "wiki/synthesis/overview.md", "./claims.md#claim-a",
    )
    is Some("wiki/synthesis/claims.md"),
  )
}

///|
async test "knowledge bundle builds graph from maintained pages" {
  let root = "/tmp/moonbook-knowledge-bundle"
  let _ = init_workspace(root)
  @fsx.make_directory(root + "/wiki/entities", recursive=true, exists_ok=true)
  @fsx.make_directory(root + "/wiki/concepts", recursive=true, exists_ok=true)
  @fsx.write_to_file(
    root + "/wiki/entities/moonbook.md",
    "# MoonBook\n\nMoonBook links to [Executable Book](../concepts/executable-book.md).\n",
    create=0o644,
  )
  @fsx.write_to_file(
    root + "/wiki/concepts/executable-book.md",
    "# Executable Book\n\nA book with durable knowledge and runnable artifacts.\n",
    create=0o644,
  )
  let bundle = generate_knowledge_bundle(root)
  assert_eq(bundle.contract, "moonbook.knowledge_bundle.v1")
  assert_true(
    bundle.pages.any(fn(page) {
      page.path == "wiki/entities/moonbook.md" && page.moonbook_type == "entity"
    }),
  )
  assert_true(
    bundle.graph.edges.any(fn(edge) {
      edge.from == "wiki/entities/moonbook.md" &&
      edge.to == "wiki/concepts/executable-book.md"
    }),
  )
}
