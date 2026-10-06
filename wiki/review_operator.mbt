///|
priv suberror ReviewOperatorFailure {
  Rejected(Int, String)
}

///|
let review_operator_mutex : @async.Mutex = @async.Mutex()

///|
fn review_operator_text(value : Json, key : String) -> String {
  match value {
    Object(fields) =>
      match fields.get(key) {
        Some(String(text)) => text
        _ => ""
      }
    _ => ""
  }
}

///|
fn review_operator_digest(value : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(value)))
}

///|
async fn review_operator_page(root : String, relative : String) -> String {
  let path = root + "/wiki/" + relative
  if !@fsx.exists(path) {
    return ""
  }
  guard @fs.kind(path, follow_symlink=false) is Regular &&
    @fs.realpath(path) == path else {
    raise ReviewOperatorFailure::Rejected(
      409,
      "Review source is not a regular local Book file: " + relative,
    )
  }
  @fsx.read_file(path)
}

///|
fn review_operator_sections(text : String, title : String) -> Array[String] {
  let result : Array[String] = []
  let mut lines : Array[String] = []
  let mut selected = false
  for raw in text.split("\n") {
    let line = raw.to_owned()
    if line.has_prefix("# ") ||
      line.has_prefix("## ") ||
      line.has_prefix("### ") {
      if selected {
        result.push(lines.join("\n"))
      }
      selected = line == "### " + title
      lines = []
    }
    if selected {
      lines.push(line)
    }
  }
  if selected {
    result.push(lines.join("\n"))
  }
  result
}

///|
fn review_operator_unique_section(
  sections : Array[String],
  label : String,
) -> String raise {
  match sections {
    [] => ""
    [text] => text
    _ =>
      raise ReviewOperatorFailure::Rejected(
        409,
        "More than one exact " +
        label +
        " record exists; inspect the Book records before resolving",
      )
  }
}

///|
async fn review_operator_result(root : String, block : ReviewBlock) -> String {
  if block.kind.to_lower().contains("result") {
    let page = review_operator_page(root, "synthesis/observations.md")
    if page.is_empty() {
      return ""
    }
    // Legacy summaries are written verbatim into shared Markdown, so even the
    // writer's header/trailer pattern can occur inside a summary. Do not guess
    // an isolated record boundary. Every page character is displayed and bound
    // by the decision digest; the selected review ID still scopes the action.
    return "Complete legacy observations page: shared context for " +
      block.title +
      "\nThis page may include other results. The decision applies only to the selected review ID. Any change to this shared page requires another inspection.\n\n" +
      page
  }
  if block.kind.to_lower().contains("query") {
    let reference = find_review_field(block.block, "- Query page: ").unwrap_or(
      "",
    )
    if reference.find("](") is Some(index) && reference.has_suffix(")") {
      let link = reference[index + 2:reference.length() - 1].to_owned()
      let relative = link.strip_prefix("../").unwrap_or(link).to_owned()
      if relative.has_prefix("queries/") &&
        relative.has_suffix(".md") &&
        !relative.contains("\\") &&
        relative
        .split("/")
        .all(part => part != "" && part != "." && part != "..") {
        return review_operator_page(root, relative)
      }
    }
  }
  ""
}

///|
async fn review_operator_native_result(
  root : String,
  block : ReviewBlock,
  binding : Json,
) -> String {
  if review_operator_text(binding, "status") == "unresolved" {
    return ""
  }
  let work = review_operator_text(binding, "work_id")
  let path = root +
    "/.moonbook/native-wenyu-imports/" +
    review_operator_digest(work) +
    ".intent.json"
  guard @fs.kind(path, follow_symlink=false) is Regular &&
    @fs.realpath(path) == path else {
    raise ReviewOperatorFailure::Rejected(
      409, "The inspected native import result is unavailable",
    )
  }
  let intent_text = @fsx.read_file(path)
  let payload_text = review_operator_text(
    @json.parse(intent_text),
    "payload_text",
  )
  let payload = @json.parse(payload_text)
  guard review_operator_digest(payload_text) ==
    review_operator_text(binding, "payload_digest") &&
    review_operator_text(payload, "result_id") == block.title else {
    raise ReviewOperatorFailure::Rejected(
      409, "The inspected native result differs from this exact review",
    )
  }
  let again = native_review_status(
    root,
    work,
    review_operator_text(binding, "request_digest"),
    review_operator_text(binding, "payload_digest"),
    block.title,
  )
  guard again == binding && @fsx.read_file(path) == intent_text else {
    raise ReviewOperatorFailure::Rejected(
      409, "The native review changed while its result was being inspected",
    )
  }
  let artifacts = match payload {
    Object(fields) =>
      match fields.get("artifacts") {
        Some(Array(items)) =>
          items
          .map(item => {
            match item {
              String(path) => "- " + path
              _ => ""
            }
          })
          .join("\n")
        _ => ""
      }
    _ => ""
  }
  "Result: " +
  block.title +
  "\n\n" +
  review_operator_text(payload, "summary") +
  "\n\nReported artifacts:\n" +
  artifacts
}

///|
async fn review_operator_detail(root : String, review_id : String) -> Json {
  if review_id.trim().is_empty() ||
    review_id.length() > 512 ||
    review_id.contains("\n") ||
    review_id.contains("\r") {
    raise ReviewOperatorFailure::Rejected(400, "An exact review_id is required")
  }
  let pending = review_operator_page(root, "reviews/pending.md")
  let resolved = review_operator_page(root, "reviews/approved.md")
  let pending_matches = parse_review_blocks(pending).filter(block => {
    block.review_id == review_id
  })
  let resolved_matches = parse_review_blocks(resolved).filter(block => {
    block.review_id == review_id
  })
  guard pending_matches.length() + resolved_matches.length() == 1 else {
    raise ReviewOperatorFailure::Rejected(
      if pending_matches.is_empty() && resolved_matches.is_empty() {
        404
      } else {
        409
      },
      if pending_matches.is_empty() && resolved_matches.is_empty() {
        "Review item not found: " + review_id
      } else {
        "Duplicate or conflicting review ID; inspect the Book records before resolving: " +
        review_id
      },
    )
  }
  let in_pending = !pending_matches.is_empty()
  let block = if in_pending { pending_matches[0] } else { resolved_matches[0] }
  let status = review_status(block.block)
  let evidence_id = find_review_field(block.block, "- Evidence ID: `").unwrap_or(
    "",
  )
  let work = find_review_field(block.block, "- Native work: `").unwrap_or("")
  let evidence_page = review_operator_page(root, "synthesis/evidence.md")
  let evidence = if evidence_id == "" {
    ""
  } else {
    review_operator_unique_section(
      review_operator_sections(evidence_page, evidence_id),
      "evidence",
    )
  }
  let binding = if work == "" {
    Json::null()
  } else {
    native_review_status(
      root,
      work,
      find_review_field(block.block, "- Request digest: `").unwrap_or(""),
      find_review_field(block.block, "- Payload digest: `").unwrap_or(""),
      block.title,
    )
  }
  // Native summaries may themselves contain Markdown headings. Read the exact
  // validated import payload rather than truncate it at a projection heading.
  let result = if work == "" {
    review_operator_result(root, block)
  } else {
    review_operator_native_result(root, block, binding)
  }
  // The digest binds what the human actually inspected. It is not a new
  // evidence/acceptance gate and does not replace the existing CLI semantics.
  let captured : Json = {
    "review_text": block.block,
    "result_text": result,
    "evidence_text": evidence,
    "native_binding": binding,
  }
  {
    "review_id": review_id,
    "kind": block.kind,
    "title": block.title,
    "status": status,
    "review_digest": review_operator_digest(captured.stringify()),
    "review_text": block.block,
    "result_text": result,
    "evidence_text": evidence,
    "review_scope": "local-book-review",
    "original_task_acceptance": "unevaluated",
    "can_resolve": in_pending && status == "pending",
    "native_binding": binding,
  }
}

///|
async fn review_operator_queue(root : String) -> Json {
  let pending = review_operator_page(root, "reviews/pending.md")
  let items : Array[Json] = []
  let ids : Map[String, Bool] = Map([])
  for block in parse_review_blocks(pending) {
    if ids.contains(block.review_id) {
      raise ReviewOperatorFailure::Rejected(
        409,
        "Duplicate pending review ID: " + block.review_id,
      )
    }
    ids[block.review_id] = true
    items.push({
      "review_id": block.review_id,
      "kind": block.kind,
      "title": block.title,
      "status": review_status(block.block),
    })
  }
  {
    "schema": "moonbook.wiki-review-operator.v1",
    "ok": true,
    "items": items,
    "original_task_acceptance": "unevaluated",
  }
}

///|
async fn review_operator_dispatch(
  root : String,
  method_ : String,
  path : String,
  body : Json,
) -> (Int, Json) {
  if method_ == "GET" && path == "/api/wiki/reviews" {
    return (200, review_operator_queue(root))
  }
  if method_ != "POST" ||
    !["/api/wiki/reviews/inspect", "/api/wiki/reviews/resolve"].contains(path) {
    raise ReviewOperatorFailure::Rejected(404, "Unsupported wiki review route")
  }
  let review_id = review_operator_text(body, "review_id")
  let detail = review_operator_detail(root, review_id)
  if path == "/api/wiki/reviews/inspect" {
    return (
      200,
      {
        "schema": "moonbook.wiki-review-operator.v1",
        "ok": true,
        "detail": detail,
      },
    )
  }
  let decision = review_operator_text(body, "decision")
  if review_operator_text(body, "scope") != "local-book-review" ||
    !["approve", "reject"].contains(decision) {
    raise ReviewOperatorFailure::Rejected(
      400, "Explicit local-book-review scope and approve or reject decision required",
    )
  }
  if review_operator_text(detail, "status") != "pending" {
    raise ReviewOperatorFailure::Rejected(
      409, "This review is already resolved; inspect the current outcome",
    )
  }
  if review_operator_text(body, "expected_digest") == "" ||
    review_operator_text(body, "expected_digest") !=
    review_operator_text(detail, "review_digest") {
    raise ReviewOperatorFailure::Rejected(
      409, "The review or its displayed evidence changed; inspect it again before deciding",
    )
  }
  // Calls the same explicit manual action as the supported CLI. Browser
  // decisions are serialized here; this does not lock concurrent CLI writers.
  let outcome = if decision == "approve" {
    approve_review(root, review_id)
  } else {
    reject_review(root, review_id)
  }
  let readback = review_operator_detail(root, review_id)
  if review_operator_text(readback, "status") !=
    (if decision == "approve" { "approved" } else { "rejected" }) {
    raise ReviewOperatorFailure::Rejected(
      409, "Review write could not be confirmed; refresh its exact record",
    )
  }
  (
    200,
    {
      "schema": "moonbook.wiki-review-operator.v1",
      "ok": true,
      "detail": readback,
      "promoted_pages": outcome.promoted_pages,
    },
  )
}

///|
/// The ordinary Book server's socket-free wiki review route owner. Reads do not
/// initialize the workspace. Only an explicit, digest-bound resolve request
/// invokes the existing manual approve/reject writer. This never accepts a task.
///
/// ```mbt check
/// test {
///   ignore(@wiki.review_operator_request)
/// }
/// ```
pub async fn review_operator_request(
  root : String,
  method_ : String,
  path : String,
  body : Json,
) -> (Int, Json) noraise {
  try {
    review_operator_mutex.acquire()
    defer review_operator_mutex.release()
    let canonical = @fs.realpath(root)
    guard @fs.kind(canonical, follow_symlink=false) is Directory else {
      raise ReviewOperatorFailure::Rejected(
        404, "Book workspace is unavailable",
      )
    }
    review_operator_dispatch(canonical, method_, path, body)
  } catch {
    error => {
      let (status, message) = match error {
        ReviewOperatorFailure::Rejected(status, message) => (status, message)
        _ =>
          (
            500,
            "Wiki review operation failed; inspect the exact record before retrying: " +
            error.to_string(),
          )
      }
      let fields : Map[String, Json] = {
        "schema": "moonbook.wiki-review-operator.v1".to_json(),
        "ok": false.to_json(),
        "error": message.to_json(),
      }
      let review_id = review_operator_text(body, "review_id")
      if review_id != "" {
        try {
          fields["detail"] = review_operator_detail(
            @fs.realpath(root),
            review_id,
          )
        } catch {
          _ => ()
        }
      }
      (status, Json::object(fields))
    }
  }
}
