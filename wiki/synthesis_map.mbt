///|
async fn ensure_synthesis_map_page(workspace : Paths) -> String {
  let relative = "synthesis/map.md"
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  if !@fsx.exists(absolute) {
    @fsx.write_to_file(
      absolute,
      "# Synthesis Map\n\nCoverage, hub pages, and open maintenance loops for this wiki.\n\n## Coverage\n\n_None yet._\n\n## Entity Hubs\n\n_None yet._\n\n## Concept Hubs\n\n_None yet._\n\n## Open Loops\n\n_None yet._\n",
      create=0o644,
    )
    update_summary(workspace.summary_path, "Synthesis Map", relative)
    update_index_section(
      @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
      "Core Pages",
      "Synthesis Map",
      relative,
      "coverage and maintenance view across the maintained wiki",
    )
  }
  relative
}

///|
async fn refresh_synthesis_map(root : String) -> String {
  let workspace = workspace_paths(root)
  let relative = ensure_synthesis_map_page(workspace)
  let absolute = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative))
    .to_string()
  let pages = collect_markdown_pages(workspace.wiki_dir)
  let claims_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/claims.md"))
    .to_string()
  let claims_text = if @fsx.exists(claims_path) {
    @fsx.read_file(claims_path)
  } else {
    ""
  }
  let source_coverage = summarize_source_coverage(workspace.wiki_dir)
  let source_count = source_coverage.verified_count
  let entity_count = count_markdown_under(workspace.wiki_dir, "entities")
  let concept_count = count_markdown_under(workspace.wiki_dir, "concepts")
  let query_count = count_markdown_under(workspace.wiki_dir, "queries")
  let evidence_count = count_evidence_entries(root)
  let coverage_ready = has_substantive_coverage(
    source_count, entity_count, concept_count, evidence_count,
  )
  let bootstrap_complete = has_bootstrap_materialization(
    source_coverage.verified_count,
    entity_count,
    concept_count,
    query_count,
  )
  let bootstrap_outcome = if bootstrap_complete {
    "complete"
  } else {
    "incomplete"
  }
  let coverage : Array[String] = [
    "- Verified source pages: `\{source_coverage.verified_count}`",
    "- Candidate source pages: `\{source_coverage.candidate_count}`",
    "- Provisional source pages: `\{source_coverage.provisional_count}`",
    "- Entity pages: `\{entity_count}`",
    "- Concept pages: `\{concept_count}`",
    "- Query pages: `\{query_count}`",
    "- Claim entries: `\{count_heading_entries(claims_text)}`",
    "- Evidence records: `\{evidence_count}`",
  ]
  let readiness : Array[String] = [
    "- Coverage ready: `\{coverage_ready}`",
    "- Bootstrap outcome: `\{bootstrap_outcome}`",
  ]
  let entity_hubs = ranked_page_hubs(
    pages.filter(path => path.contains("/wiki/entities/")),
    workspace.root,
    5,
  )
  let concept_hubs = ranked_page_hubs(
    pages.filter(path => path.contains("/wiki/concepts/")),
    workspace.root,
    5,
  )
  let pending = list_pending_reviews(root)
  let open_loops : Array[String] = []
  if !pending.is_empty() {
    open_loops.push("- Pending reviews: `\{pending.length()}`")
  }
  let low_confidence = count_low_confidence_claims(claims_text)
  if low_confidence > 0 {
    open_loops.push("- Low-confidence claims: `\{low_confidence}`")
  }
  let keeper = keeper_snapshot(root)
  if keeper.working_memory.length() >= 8 {
    open_loops.push(
      "- Keeper working memory is crowded: `\{keeper.working_memory.length()}`",
    )
  }
  if evidence_count == 0 {
    open_loops.push("- No evidence records have been captured yet.")
  }
  let content = "# Synthesis Map\n\n" +
    "Coverage, hub pages, and open maintenance loops for this wiki.\n\n" +
    "## Coverage\n\n" +
    coverage.join("\n") +
    "\n\n## Readiness\n\n" +
    readiness.join("\n") +
    "\n\n## Entity Hubs\n\n" +
    render_hub_lines(entity_hubs) +
    "\n## Concept Hubs\n\n" +
    render_hub_lines(concept_hubs) +
    "\n## Open Loops\n\n" +
    (if open_loops.is_empty() {
      "_None yet._\n"
    } else {
      open_loops.join("\n") + "\n"
    })
  @fsx.write_to_file(absolute, content, create=0o644)
  relative
}

///|
async fn ranked_page_hubs(
  page_paths : Array[String],
  root : String,
  limit : Int,
) -> Array[(String, Int)] {
  let ranked : Array[(String, Int)] = []
  for path in page_paths {
    let score = page_hub_score(@fsx.read_file(path))
    if score > 0 {
      ranked.push((relative_to_root(path, root), score))
    }
  }
  ranked.sort_by(fn(a, b) {
    if a.1 == b.1 {
      a.0.compare(b.0)
    } else {
      b.1.compare(a.1)
    }
  })
  let selected : Array[(String, Int)] = []
  for i = 0; i < ranked.length() && i < limit; i = i + 1 {
    selected.push(ranked[i])
  }
  selected
}

///|
fn page_hub_score(content : String) -> Int {
  count_list_entries(content, "## Sources") +
  count_list_entries(content, "## Relationships") +
  count_list_entries(content, "## Query Signals") +
  count_list_entries(content, "## Approved Insights")
}

///|
fn count_list_entries(content : String, section_header : String) -> Int {
  let lines = lines_array(content)
  let mut in_section = false
  let mut count = 0
  for line in lines {
    if line == section_header {
      in_section = true
      continue
    }
    if in_section && line.has_prefix("## ") {
      break
    }
    if in_section && line.trim().to_string().has_prefix("- ") {
      count += 1
    }
  }
  count
}

///|
fn render_hub_lines(items : Array[(String, Int)]) -> String {
  if items.is_empty() {
    "_None yet._\n"
  } else {
    items.map(item => "- `\{item.0}` score=`\{item.1}`").join("\n") + "\n"
  }
}

///|
test "page hub score counts multiple wiki signals" {
  let score = page_hub_score(
    "## Sources\n\n- a\n- b\n\n## Relationships\n\n- c\n\n## Query Signals\n\n- d\n",
  )
  assert_eq(score, 4)
}
