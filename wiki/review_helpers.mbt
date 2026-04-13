///|
priv struct ReviewBlock {
  review_id : String
  kind : String
  title : String
  block : String
}

///|
fn parse_review_blocks(content : String) -> Array[ReviewBlock] {
  let lines = lines_array(content)
  let blocks : Array[ReviewBlock] = []
  let mut current : Array[String] = []
  for line in lines {
    if line.has_prefix("### ") && !current.is_empty() {
      blocks.push(build_review_block(current.join("\n")))
      current = []
    }
    if line.has_prefix("### ") || !current.is_empty() {
      current.push(line)
    }
  }
  if !current.is_empty() {
    blocks.push(build_review_block(current.join("\n")))
  }
  blocks
}

///|
fn build_review_block(block : String) -> ReviewBlock {
  let lines = lines_array(block)
  let header = lines[0]
  let label = header.strip_prefix("### ").unwrap_or(header).to_string()
  let separator = label.find(" | ")
  let kind = match separator {
    Some(index) => label[:index].to_string()
    None => label
  }
  let title = match separator {
    Some(index) => label[index + 3:].to_string()
    None => label
  }
  let review_id = find_review_field(block, "- Review ID: `").unwrap_or(
    fallback_review_id(kind, title),
  )
  { review_id, kind, title, block }
}

///|
fn fallback_review_id(kind : String, title : String) -> String {
  slugify_title(kind + "-" + title)
}

///|
fn find_review_field(block : String, prefix : String) -> String? {
  for raw in block.split("\n") {
    let line = raw.to_string()
    if line.has_prefix(prefix) {
      if line.has_suffix("`") {
        return Some(line[prefix.length():line.length() - 1].to_string())
      }
      return Some(line[prefix.length():].trim().to_string())
    }
  }
  None
}

///|
fn review_status(block : String) -> String {
  find_review_field(block, "- Status: `").unwrap_or("pending")
}

///|
fn remove_review_block(content : String, block : ReviewBlock) -> String {
  content.replace(old=block.block, new="").to_string()
}

///|
fn normalize_review_page(content : String) -> String {
  let mut next = content
    .replace(old="_None yet._\n\n### ", new="### ")
    .to_string()
  while next.contains("\n\n\n") {
    next = next.replace(old="\n\n\n", new="\n\n").to_string()
  }
  if !next.contains("### ") &&
    next.contains("## Items") &&
    !next.contains("_None yet._") {
    next = next
      .replace(old="## Items\n\n", new="## Items\n\n_None yet._\n")
      .to_string()
  }
  next
}

///|
fn finalize_review_block(block : ReviewBlock, action : String) -> String {
  let mut updated = block.block
  updated = replace_or_append_review_field(updated, "- Status: `", action, true)
  updated = append_review_resolution(updated, action)
  updated
}

///|
fn replace_or_append_review_field(
  block : String,
  prefix : String,
  value : String,
  quoted : Bool,
) -> String {
  let lines = lines_array(block)
  let rebuilt : Array[String] = []
  let mut replaced = false
  for line in lines {
    if line.has_prefix(prefix) {
      rebuilt.push(if quoted { prefix + value + "`" } else { prefix + value })
      replaced = true
    } else {
      rebuilt.push(line)
    }
  }
  if !replaced {
    rebuilt.push(if quoted { prefix + value + "`" } else { prefix + value })
  }
  rebuilt.join("\n")
}

///|
fn append_review_resolution(block : String, action : String) -> String {
  let resolution = "- Resolution: `\{action}` at `\{@async.now().to_int()}`"
  if block.contains(resolution) {
    block
  } else {
    block.trim().to_string() + "\n" + resolution + "\n"
  }
}

///|
fn claim_summaries_from_review_block(block : String) -> Array[StructuredClaim] {
  let claims : Array[StructuredClaim] = []
  for raw in block.split("\n") {
    let line = raw.trim().to_string()
    if !line.has_prefix("- ") && !line.has_prefix("  - ") {
      continue
    }
    let entry = line
      .strip_prefix("- ")
      .unwrap_or(line.strip_prefix("  - ").unwrap_or(line))
      .to_string()
    match parse_review_claim_summary(entry) {
      Some(claim) => claims.push(claim)
      None => ()
    }
  }
  claims
}

///|
fn parse_review_claim_summary(line : String) -> StructuredClaim? {
  match line.find(" -> ") {
    Some(index) =>
      match line.find(" [") {
        Some(confidence_start) =>
          Some({
            subject: line[:index].trim().to_string(),
            predicate: line[index + 4:confidence_start].trim().to_string(),
            confidence: line[confidence_start + 2:line.length() - 1]
            .trim()
            .to_string(),
          })
        None => None
      }
    None => None
  }
}

///|
fn durable_candidates_from_review_block(
  block : String,
) -> Array[MemoryCandidate] {
  let candidates : Array[MemoryCandidate] = []
  for raw in block.split("\n") {
    let line = raw.to_string()
    if !line.has_prefix("  - ") {
      continue
    }
    let entry = line.strip_prefix("  - ").unwrap_or(line).to_string()
    let parts : Array[String] = []
    for part in entry.split(" | ") {
      parts.push(part.trim().to_string())
    }
    if parts.length() < 4 {
      continue
    }
    let target_page = if parts[2].is_empty() { None } else { Some(parts[2]) }
    candidates.push({
      title: parts[0],
      kind: parts[1],
      target_page,
      detail: parts[3],
      durable: true,
    })
  }
  candidates
}

///|
fn supersede_conflicting_claims(
  claims_text : String,
  approved_claim : StructuredClaim,
) -> String {
  let lines = lines_array(claims_text)
  let rebuilt : Array[String] = []
  let mut current_header = ""
  let mut in_block = false
  for line in lines {
    if line.has_prefix("### ") {
      current_header = line.to_string()
      in_block = true
      rebuilt.push(line)
      continue
    }
    if in_block &&
      line.has_prefix("- Status: `") &&
      current_header.has_prefix("### \{approved_claim.subject} :: ") &&
      current_header !=
      "### \{approved_claim.subject} :: \{approved_claim.predicate}" {
      rebuilt.push("- Status: `superseded`")
      continue
    }
    if in_block &&
      line.has_prefix("- Superseded by: `") &&
      current_header.has_prefix("### \{approved_claim.subject} :: ") &&
      current_header !=
      "### \{approved_claim.subject} :: \{approved_claim.predicate}" {
      rebuilt.push(
        "- Superseded by: `\{approved_claim.subject} :: \{approved_claim.predicate}`",
      )
      continue
    }
    rebuilt.push(line)
  }
  rebuilt.join("\n")
}

///|
async fn append_review_log(
  log_path : String,
  review_id : String,
  action : String,
  promoted_pages : Array[String],
) -> Unit {
  let now = "\{@async.now().to_int()}"
  let entry = "## [\{now}] review | \{review_id}\n\n" +
    "- action: `\{action}`\n" +
    format_related_log_lines(promoted_pages)
  let current = @fsx.read_file(log_path)
  let next = if current.has_suffix("\n") {
    current + "\n" + entry
  } else {
    current + "\n\n" + entry
  }
  @fsx.write_to_file(log_path, next, create=0o644)
}

///|
test "build review block falls back to derived id" {
  let block = build_review_block(
    "### Query review | Alpha\n- Status: `pending`\n",
  )
  assert_eq(block.review_id, "query-review-alpha")
}

///|
test "parse review claim summary decodes structured line" {
  let claim = parse_review_claim_summary(
    "OpenClaw -> MoonClaw runtime [medium]",
  ).unwrap()
  assert_eq(claim.subject, "OpenClaw")
  assert_eq(claim.predicate, "MoonClaw runtime")
  assert_eq(claim.confidence, "medium")
}

///|
test "supersede conflicting claims updates old claim status" {
  let content = "# Claims\n\n## Claims\n\n" +
    "### Alpha :: red\n\n" +
    "- Status: `active`\n" +
    "- Superseded by: `_None_`\n\n" +
    "### Alpha :: blue\n\n" +
    "- Status: `active`\n" +
    "- Superseded by: `_None_`\n"
  let updated = supersede_conflicting_claims(content, {
    subject: "Alpha",
    predicate: "blue",
    confidence: "high",
  })
  assert_true(updated.contains("### Alpha :: red"))
  assert_true(updated.contains("- Status: `superseded`"))
  assert_true(updated.contains("- Superseded by: `Alpha :: blue`"))
}

///|
test "durable candidates from review block decode entries" {
  let block = "### Result review | task\n\n- Durable candidates:\n  - Insight | concept | concepts/insight.md | useful detail\n"
  let candidates = durable_candidates_from_review_block(block)
  assert_eq(candidates.length(), 1)
  assert_eq(candidates[0].title, "Insight")
  assert_eq(candidates[0].target_page, Some("concepts/insight.md"))
}
