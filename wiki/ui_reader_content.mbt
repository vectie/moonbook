///|
// Reader-first artifact discovery for the generated MoonBook reading surface.
//
// These records are intentionally UI-local. The durable reader-projection
// contract lives in the reader_projection package; this file only resolves
// existing workspace artifacts so the renderer never substitutes generic
// MoonBook prose for a domain book.

///|
priv struct ReaderArtifactContent {
  view : String
  label : String
  title : String
  summary : String
  source_path : String
  source_revision : String
  source_digest : String
  source_review_status : String
  markdown : String
  available : Bool
  estimated_minutes : Int
  next_action : String
}

///|
priv struct ReaderArtifactBundle {
  identity : ReaderCanonicalBookIdentity
  learn : ReaderArtifactContent
  apply : ReaderArtifactContent
  research : ReaderArtifactContent
}

///|
// One deterministic identity binds every reader view to the same book snapshot.
// Individual artifact digests remain evidence references; they are not allowed
// to masquerade as the canonical book revision.
priv struct ReaderCanonicalBookIdentity {
  book_id : String
  subject_id : String
  revision : String
  digest : String
  payload : Json
}

///|
async fn ui_reader_artifacts(root : String) -> ReaderArtifactBundle {
  let learn = ui_learn_artifact(root)
  let apply = ui_apply_artifact(root, learn)
  let research = ui_research_artifact(root)
  let identity = reader_canonical_book_identity(root, learn, apply, research)
  { identity, learn, apply, research }
}

///|
fn reader_canonical_book_identity(
  root : String,
  learn : ReaderArtifactContent,
  apply : ReaderArtifactContent,
  research : ReaderArtifactContent,
) -> ReaderCanonicalBookIdentity {
  let book_id = moonbook_wiki_path(root).basename().to_owned()
  let payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "reader_contract_version": @reader_projection.reader_projection_contract_version(),
    "subject_kind": "canonical_book",
    "book_id": book_id,
    "artifacts": [
      reader_artifact_identity_json(learn),
      reader_artifact_identity_json(apply),
      reader_artifact_identity_json(research),
    ],
  }
  let digest = @bookkeeper_store.bookkeeper_payload_digest(payload)
  let subject_id = "reader-source:{book_id}:{digest[7:]}"
  { book_id, subject_id, revision: digest, digest, payload }
}

///|
fn reader_artifact_identity_json(artifact : ReaderArtifactContent) -> Json {
  {
    "view": artifact.view,
    "available": artifact.available,
    "source_path": artifact.source_path,
    "source_revision": artifact.source_revision,
    "source_digest": artifact.source_digest,
  }
}

///|
async fn ui_learn_artifact(root : String) -> ReaderArtifactContent {
  match
    read_first_reader_artifact(
      root,
      ["wiki/synthesis/beginner-course.md", "wiki/course/beginner-course.md"],
      require_course_shape=false,
      reject_course_shape=false,
    ) {
    Some((source_path, markdown)) =>
      reader_artifact_content(
        "learn", "Learn", source_path, markdown, "Start with the first lesson",
      )
    None =>
      match
        read_first_reader_artifact(
          root,
          ["raw/bootstrap/deep-report.md"],
          require_course_shape=true,
          reject_course_shape=false,
        ) {
        Some((source_path, markdown)) =>
          reader_artifact_content(
            "learn", "Learn", source_path, markdown, "Start with the first lesson",
          )
        None =>
          missing_reader_artifact(
            "learn", "Learn", "Beginner view unavailable", "MoonBook has not produced a readable beginner course for this book yet.",
            "Create and review wiki/synthesis/beginner-course.md",
          )
      }
  }
}

///|
async fn ui_apply_artifact(
  root : String,
  learn : ReaderArtifactContent,
) -> ReaderArtifactContent {
  match
    read_first_reader_artifact(
      root,
      ["wiki/course/exercises.md", "wiki/synthesis/exercises.md"],
      require_course_shape=false,
      reject_course_shape=false,
    ) {
    Some((source_path, markdown)) =>
      reader_artifact_content(
        "apply", "Apply", source_path, markdown, "Try the first exercise",
      )
    None =>
      if learn.available {
        let practice = practice_markdown_from_course(
          learn.title,
          learn.markdown,
        )
        if !practice.trim().is_empty() {
          let derived = reader_artifact_content(
            "apply",
            "Apply",
            learn.source_path,
            practice,
            "Try the first exercise",
          )
          {
            ..derived,
            source_revision: learn.source_revision,
            source_digest: learn.source_digest,
            source_review_status: learn.source_review_status,
          }
        } else {
          missing_reader_artifact(
            "apply", "Apply", "Practice view unavailable", "The course exists, but it does not yet contain exercises, output artifacts, checkpoints, or common mistakes.",
            "Add practice blocks to the accepted course",
          )
        }
      } else {
        missing_reader_artifact(
          "apply", "Apply", "Practice view unavailable", "MoonBook needs an accepted course or exercise workbook before it can offer a practice path.",
          "Create and review wiki/course/exercises.md",
        )
      }
  }
}

///|
async fn ui_research_artifact(root : String) -> ReaderArtifactContent {
  match
    read_first_reader_artifact(
      root,
      ["wiki/synthesis/report.md", "raw/bootstrap/deep-report.md"],
      require_course_shape=false,
      reject_course_shape=true,
    ) {
    Some((source_path, markdown)) =>
      reader_artifact_content(
        "research", "Research", source_path, markdown, "Trace the main claim to its evidence",
      )
    None =>
      match
        read_first_reader_artifact(
          root,
          ["wiki/synthesis/overview.md"],
          require_course_shape=false,
          reject_course_shape=false,
        ) {
        Some((source_path, markdown)) =>
          reader_artifact_content(
            "research", "Research", source_path, markdown, "Trace the main claim to its evidence",
          )
        None =>
          missing_reader_artifact(
            "research", "Research", "Research view unavailable", "MoonBook has not produced a substantive synthesis or research report for this book yet.",
            "Produce and review a synthesis report",
          )
      }
  }
}

///|
async fn read_first_reader_artifact(
  root : String,
  candidates : Array[String],
  require_course_shape~ : Bool,
  reject_course_shape~ : Bool,
) -> (String, String)? {
  for relative in candidates {
    let path = moonbook_wiki_path(root)
      .join(moonbook_wiki_path(relative))
      .to_string()
    if @fsx.exists(path) {
      let markdown = @fsx.read_file(path)
      let course_shaped = reader_course_shape(markdown)
      if readable_reader_markdown(markdown) &&
        (!require_course_shape || course_shaped) &&
        (!reject_course_shape || !course_shaped) {
        return Some((relative, markdown))
      }
    }
  }
  None
}

///|
fn readable_reader_markdown(markdown : String) -> Bool {
  let normalized = markdown.trim()
  if normalized.is_empty() {
    return false
  }
  let lower = normalized.to_lower()
  !((lower.contains("_none yet._") || lower.contains("no synthesis yet")) &&
  normalized.length() < 360)
}

///|
fn reader_course_shape(markdown : String) -> Bool {
  let lower = markdown.to_lower()
  (lower.contains("## lesson") || lower.contains("### lesson")) &&
  (
    lower.contains("objective:") ||
    lower.contains("### objective") ||
    lower.contains("exercise:") ||
    lower.contains("### exercise")
  )
}

///|
fn reader_artifact_content(
  view : String,
  label : String,
  source_path : String,
  markdown : String,
  default_action : String,
) -> ReaderArtifactContent {
  let heading = first_markdown_heading(markdown)
  let title = if heading.trim().is_empty() { label } else { heading }
  let summary = reader_artifact_summary(markdown)
  let next_action = match first_reader_instruction(markdown) {
    Some(instruction) => instruction
    None => default_action
  }
  {
    view,
    label,
    title,
    summary,
    source_path,
    source_revision: reader_source_revision(markdown),
    source_digest: executable_sha256(markdown),
    // Reader artifacts cannot approve themselves. An exact Bookkeeper receipt
    // may be supplied through the typed adapter boundary; until then the source
    // remains explicitly pending regardless of Markdown body text.
    source_review_status: "pending-review",
    markdown,
    available: true,
    estimated_minutes: reader_estimated_minutes(markdown),
    next_action,
  }
}

///|
fn missing_reader_artifact(
  view : String,
  label : String,
  title : String,
  summary : String,
  next_action : String,
) -> ReaderArtifactContent {
  {
    view,
    label,
    title,
    summary,
    source_path: "unavailable",
    source_revision: "unavailable",
    source_digest: "unavailable",
    source_review_status: "missing",
    markdown: "",
    available: false,
    estimated_minutes: 0,
    next_action,
  }
}

///|
fn reader_source_revision(markdown : String) -> String {
  for prefix in ["source_revision:", "revision:"] {
    for raw in markdown.split("\n") {
      let line = raw.trim().to_owned()
      if line.to_lower().has_prefix(prefix) {
        let value = line[prefix.length():].trim().to_owned()
        if !value.is_empty() {
          return strip_inline_markup(value)
        }
      }
    }
  }
  executable_sha256(markdown)
}

///|
fn reader_artifact_summary(markdown : String) -> String {
  match reader_first_labeled_value(markdown, ["Main message:"]) {
    Some(message) => return clamp_text(strip_inline_markup(message), 320)
    None => ()
  }
  match reader_named_markdown_block(markdown, ["main message"]).get(0) {
    Some(message) => return clamp_text(strip_inline_markup(message), 320)
    None => ()
  }
  for paragraph in reader_summary_paragraphs(markdown) {
    let lower = strip_inline_markup(paragraph).trim().to_lower().to_owned()
    if !reader_summary_metadata_line(lower) {
      return clamp_text(strip_inline_markup(paragraph).trim().to_owned(), 320)
    }
  }
  "Open the source-backed view to continue."
}

///|
fn reader_summary_paragraphs(markdown : String) -> Array[String] {
  let paragraphs : Array[String] = []
  let current : Array[String] = []
  let mut in_fence = false
  let mut in_frontmatter = false
  let mut first_nonblank = true
  for raw in markdown.split("\n") {
    let line = raw.trim().to_owned()
    if first_nonblank && line.is_empty() {
      continue
    }
    if first_nonblank && line == "---" {
      in_frontmatter = true
      first_nonblank = false
      continue
    }
    first_nonblank = false
    if in_frontmatter {
      if line == "---" {
        in_frontmatter = false
      }
      continue
    }
    if line.has_prefix("```") {
      in_fence = !in_fence
      continue
    }
    if in_fence {
      continue
    }
    if line.is_empty() || reader_markdown_heading_depth(line) > 0 {
      reader_flush_summary_paragraph(paragraphs, current)
      continue
    }
    if line.has_prefix("|") ||
      line.has_prefix("<details") ||
      line.has_prefix("</details") ||
      line.has_prefix("<summary") {
      reader_flush_summary_paragraph(paragraphs, current)
      continue
    }
    current.push(line)
  }
  reader_flush_summary_paragraph(paragraphs, current)
  paragraphs
}

///|
fn reader_flush_summary_paragraph(
  paragraphs : Array[String],
  current : Array[String],
) -> Unit {
  if !current.is_empty() {
    paragraphs.push(current.join(" "))
    current.clear()
  }
}

///|
fn reader_summary_metadata_line(lower : String) -> Bool {
  lower.is_empty() ||
  lower.has_prefix("audience:") ||
  lower.has_prefix("prerequisite:") ||
  lower.has_prefix("prerequisites:") ||
  lower.has_prefix("source_revision:") ||
  lower.has_prefix("revision:") ||
  lower.has_prefix("review_status:") ||
  lower.has_prefix("moonbook_type:") ||
  lower.has_prefix("source_quality:") ||
  lower.has_prefix("tags:") ||
  lower.has_prefix("updated_at:") ||
  lower.has_prefix("lesson ") ||
  lower.has_prefix("objective:") ||
  lower.has_prefix("exercise:") ||
  lower.has_prefix("checkpoint:") ||
  lower.has_prefix("revisit after days:")
}

///|
fn first_reader_instruction(markdown : String) -> String? {
  for label in ["Exercise:", "Next action:", "Try:"] {
    let lower_label = label.to_lower()
    for raw in markdown.split("\n") {
      let line = raw.trim().to_owned()
      if line.to_lower().has_prefix(lower_label) {
        let value = line[label.length():].trim().to_owned()
        if !value.is_empty() {
          return Some(clamp_text(value, 180))
        }
      }
    }
  }
  None
}

///|
fn reader_estimated_minutes(markdown : String) -> Int {
  let mut words = 0
  for line in markdown.split("\n") {
    for part in line.split(" ") {
      if !part.trim().is_empty() {
        words += 1
      }
    }
  }
  let by_words = (words + 199) / 200
  let by_characters = (markdown.length() + 899) / 900
  let minutes = if by_words > by_characters { by_words } else { by_characters }
  if minutes < 1 {
    1
  } else {
    minutes
  }
}

///|
fn practice_markdown_from_course(title : String, course : String) -> String {
  let blocks : Array[String] = []
  let mut lesson = ""
  let mut lesson_emitted = false
  let mut capture_depth = 0
  for raw in course.split("\n") {
    let line = raw.trim().to_owned()
    let lower = line.to_lower()
    let heading_depth = reader_markdown_heading_depth(line)
    let heading_text = if heading_depth > 0 {
      line[heading_depth:].trim().to_owned()
    } else {
      ""
    }
    if heading_depth > 0 && heading_text.to_lower().has_prefix("lesson") {
      lesson = line
      lesson_emitted = false
      capture_depth = 0
      continue
    }
    if heading_depth > 0 && reader_practice_heading(heading_text.to_lower()) {
      if !lesson_emitted {
        if !lesson.is_empty() {
          blocks.push(lesson)
        }
        lesson_emitted = true
      }
      blocks.push(line)
      capture_depth = heading_depth
      continue
    }
    if heading_depth > 0 {
      if capture_depth > 0 && heading_depth > capture_depth {
        blocks.push(raw.to_owned())
      } else {
        capture_depth = 0
      }
      continue
    }
    if reader_practice_line(lower) {
      if !lesson_emitted {
        if !lesson.is_empty() {
          blocks.push(lesson)
        }
        lesson_emitted = true
      }
      blocks.push(line)
      blocks.push("")
      capture_depth = 0
      continue
    }
    if capture_depth > 0 {
      blocks.push(raw.to_owned())
    }
  }
  if blocks.is_empty() {
    ""
  } else {
    "# Practice: \{title}\n\nWork through one exercise at a time. Produce the named artifact, then use the checkpoint before continuing.\n\n" +
    blocks.join("\n")
  }
}

///|
fn reader_markdown_heading_depth(line : String) -> Int {
  let mut depth = 0
  while depth < line.length() && line[depth] == '#' {
    depth += 1
  }
  if depth > 0 && depth < line.length() && line[depth] == ' ' {
    depth
  } else {
    0
  }
}

///|
fn reader_practice_heading(lower : String) -> Bool {
  lower == "exercise" ||
  lower.has_prefix("exercise ") ||
  lower == "output artifact" ||
  lower.has_prefix("output artifact ") ||
  lower == "checkpoint" ||
  lower.has_prefix("checkpoint ") ||
  lower == "common mistake" ||
  lower.has_prefix("common mistake ") ||
  lower == "self-explanation" ||
  lower.has_prefix("self-explanation ") ||
  lower == "retrieval" ||
  lower.has_prefix("retrieval ") ||
  lower == "retrieval checkpoint" ||
  lower.has_prefix("retrieval checkpoint ") ||
  lower == "transfer" ||
  lower.has_prefix("transfer ") ||
  lower == "transfer task" ||
  lower.has_prefix("transfer task ") ||
  lower == "revisit" ||
  lower.has_prefix("revisit ")
}

///|
fn reader_practice_line(lower : String) -> Bool {
  lower.has_prefix("exercise:") ||
  lower.has_prefix("### exercise") ||
  lower.has_prefix("output artifact:") ||
  lower.has_prefix("### output artifact") ||
  lower.has_prefix("checkpoint:") ||
  lower.has_prefix("### checkpoint") ||
  lower.has_prefix("common mistake:") ||
  lower.has_prefix("### common mistake") ||
  lower.has_prefix("self-explanation:") ||
  lower.has_prefix("retrieval checkpoint:") ||
  lower.has_prefix("retrieval:") ||
  lower.has_prefix("transfer task:") ||
  lower.has_prefix("transfer:") ||
  lower.has_prefix("revisit:") ||
  lower.has_prefix("revisit after days:")
}
