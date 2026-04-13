///|
pub struct ReviewItem {
  review_id : String
  kind : String
  title : String
  status : String
} derive(Show, ToJson)

///|
pub struct ReviewActionResult {
  review_id : String
  action : String
  promoted_pages : Array[String]
} derive(Show, ToJson)

///|
pub async fn list_pending_reviews(root : String) -> Array[ReviewItem] {
  let workspace = workspace_paths(root)
  let pending_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("reviews/pending.md"))
    .to_string()
  let content = if @fsx.exists(pending_path) {
    @fsx.read_file(pending_path)
  } else {
    ""
  }
  let items : Array[ReviewItem] = []
  for block in parse_review_blocks(content) {
    items.push({
      review_id: block.review_id,
      kind: block.kind,
      title: block.title,
      status: review_status(block.block),
    })
  }
  items
}

///|
pub async fn approve_review(
  root : String,
  review_id : String,
) -> ReviewActionResult {
  apply_review_action(root, review_id, "approved")
}

///|
pub async fn reject_review(
  root : String,
  review_id : String,
) -> ReviewActionResult {
  apply_review_action(root, review_id, "rejected")
}

///|
async fn apply_review_action(
  root : String,
  review_id : String,
  action : String,
) -> ReviewActionResult {
  let workspace = workspace_paths(root)
  let pending_relative = "reviews/pending.md"
  let approved_relative = "reviews/approved.md"
  let pending_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(pending_relative))
    .to_string()
  let approved_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(approved_relative))
    .to_string()
  let pending = if @fsx.exists(pending_path) {
    @fsx.read_file(pending_path)
  } else {
    fail("pending review page does not exist")
  }
  let blocks = parse_review_blocks(pending)
  let mut maybe_block : ReviewBlock? = None
  for block in blocks {
    if block.review_id == review_id {
      maybe_block = Some(block)
      break
    }
  }
  let block = match maybe_block {
    Some(found) => found
    None => fail("review item not found: \{review_id}")
  }
  let remaining = remove_review_block(pending, block)
  @fsx.write_to_file(
    pending_path,
    normalize_review_page(remaining),
    create=0o644,
  )

  let existing_approved = if @fsx.exists(approved_path) {
    @fsx.read_file(approved_path)
  } else {
    approved_review_text()
  }
  let finalized_block = finalize_review_block(block, action)
  let updated_approved = append_section_block(
    existing_approved, "## Items", finalized_block,
  )
  @fsx.write_to_file(
    approved_path,
    normalize_review_page(updated_approved),
    create=0o644,
  )

  let promoted_pages : Array[String] = [approved_relative]
  let claims_relative = maybe_apply_claim_review(workspace, block, action)
  if !claims_relative.is_empty() {
    promoted_pages.push(claims_relative)
  }
  let result_pages = maybe_apply_result_review(workspace, block, action)
  for page in result_pages {
    if !promoted_pages.contains(page) {
      promoted_pages.push(page)
    }
  }
  let query_pages = maybe_apply_query_review(workspace, block, action)
  for page in query_pages {
    if !promoted_pages.contains(page) {
      promoted_pages.push(page)
    }
  }
  let evidence_relative = maybe_update_review_evidence(workspace, block, action)
  if !evidence_relative.is_empty() &&
    !promoted_pages.contains(evidence_relative) {
    promoted_pages.push(evidence_relative)
  }
  let plan_relative = ensure_maintenance_plan_entry(
    workspace,
    "\{title_case(action)} review: \{block.title}",
    if block.kind.contains("query") {
      "query-review"
    } else {
      "claim-review"
    },
    "wiki/" + approved_relative,
    promoted_pages,
    [
      "review id: \{block.review_id}",
      "status: \{action}",
      "kind: \{block.kind}",
    ],
  )
  if !promoted_pages.contains(plan_relative) {
    promoted_pages.push(plan_relative)
  }
  append_review_log(
    @path.Path(workspace.wiki_dir).join(@path.Path("log.md")).to_string(),
    block.review_id,
    action,
    promoted_pages,
  )
  let insights_relative = refresh_keeper_insights(workspace.root)
  if !promoted_pages.contains(insights_relative) {
    promoted_pages.push(insights_relative)
  }
  let synthesis_map_relative = refresh_synthesis_map(workspace.root)
  if !promoted_pages.contains(synthesis_map_relative) {
    promoted_pages.push(synthesis_map_relative)
  }
  { review_id, action, promoted_pages }
}

///|
async fn maybe_apply_claim_review(
  workspace : Paths,
  block : ReviewBlock,
  action : String,
) -> String {
  if !block.kind.to_lower().contains("claim") {
    return ""
  }
  let relative_page = "synthesis/claims.md"
  let claims_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  if !@fsx.exists(claims_path) {
    return ""
  }
  let mut claims_text = @fsx.read_file(claims_path)
  let claims = claim_summaries_from_review_block(block.block)
  for claim in claims {
    let header = "### \{claim.subject} :: \{claim.predicate}"
    if !claims_text.contains(header) {
      continue
    }
    claims_text = replace_claim_field(
      claims_text,
      header,
      "- Status: `",
      if action == "approved" {
        "approved"
      } else {
        "rejected"
      },
    )
    claims_text = replace_claim_field(
      claims_text,
      header,
      "- Confidence: `",
      if action == "approved" {
        "high"
      } else {
        "low"
      },
    )
    if action == "approved" {
      claims_text = supersede_conflicting_claims(claims_text, claim)
    }
  }
  @fsx.write_to_file(claims_path, claims_text, create=0o644)
  relative_page
}

///|
async fn maybe_apply_query_review(
  workspace : Paths,
  block : ReviewBlock,
  action : String,
) -> Array[String] {
  if !block.kind.to_lower().contains("query") || action != "approved" {
    return []
  }
  let relative_page = "synthesis/overview.md"
  let overview_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  if !@fsx.exists(overview_path) {
    return []
  }
  let query_page = find_review_field(block.block, "- Query page: [").unwrap_or(
    "./queries/unknown.md",
  )
  let insight = find_review_field(block.block, "- Candidate insight: ").unwrap_or(
    "No summary recorded.",
  )
  let builder = StringBuilder::new()
  builder.write_string("### Approved query insight | \{block.title}\n\n")
  builder.write_string("- Review ID: `\{block.review_id}`\n")
  builder.write_string("- Query page: \{query_page}\n")
  builder.write_string("- Insight: \{insight}\n\n")
  let updated = append_section_block(
    @fsx.read_file(overview_path),
    "## Approved Insights",
    builder.to_string(),
  )
  @fsx.write_to_file(overview_path, updated, create=0o644)
  ignore(keeper_capture_query_insight(workspace.root, block.title, insight))
  let promoted : Array[String] = [relative_page]
  for citation in review_citations(block.block) {
    let page_relative = citation
      .strip_prefix("wiki/")
      .unwrap_or(citation)
      .to_string()
    if !page_relative.has_prefix("entities/") &&
      !page_relative.has_prefix("concepts/") &&
      !page_relative.has_prefix("sources/") {
      continue
    }
    let page_path = @path.Path(workspace.wiki_dir)
      .join(@path.Path(page_relative))
      .to_string()
    if !@fsx.exists(page_path) {
      continue
    }
    let query_link = relative_from_page(
      "wiki/" + page_relative,
      "wiki/" + query_page_relative(query_page),
    )
    let page_updated = append_list_entry(
      @fsx.read_file(page_path),
      "## Approved Insights",
      "- [Query: \{block.title}](\{query_link}): \{insight}",
    )
    @fsx.write_to_file(page_path, page_updated, create=0o644)
    if !promoted.contains(page_relative) {
      promoted.push(page_relative)
    }
  }
  promoted
}

///|
async fn maybe_apply_result_review(
  workspace : Paths,
  block : ReviewBlock,
  action : String,
) -> Array[String] {
  if !block.kind.to_lower().contains("result") || action != "approved" {
    return []
  }
  let candidates = durable_candidates_from_review_block(block.block)
  if candidates.is_empty() {
    return []
  }
  promote_durable_candidates(workspace, candidates)
}

///|
async fn maybe_update_review_evidence(
  workspace : Paths,
  block : ReviewBlock,
  action : String,
) -> String {
  let evidence_id = find_review_field(block.block, "- Evidence ID: `").unwrap_or(
    "",
  )
  if evidence_id.is_empty() {
    return ""
  }
  update_evidence_status(
    workspace,
    evidence_id,
    action,
    "review \{action} for \{block.review_id}",
  )
}

///|
fn review_citations(block : String) -> Array[String] {
  let raw = find_review_field(block, "- Citations: ").unwrap_or("")
  let citations : Array[String] = []
  if raw.is_empty() {
    return citations
  }
  for piece in raw.split(", ") {
    let text = piece.trim().to_string()
    if text.is_empty() {
      continue
    }
    let stripped = text.strip_prefix("`").unwrap_or(text).to_string()
    citations.push(stripped.strip_suffix("`").unwrap_or(stripped).to_string())
  }
  citations
}

///|
fn query_page_relative(link_field : String) -> String {
  match link_field.find("](./") {
    Some(index) => link_field[index + 4:link_field.length() - 1].to_string()
    None => "queries/unknown.md"
  }
}
