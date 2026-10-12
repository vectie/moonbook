///|
/// Exact maintained-page text observed during this read, bound by content hash.
pub struct ComparedWikiPage {
  citation : String
  digest : String
  metadata_status : String
} derive(ToJson)

///|
pub struct WikiPageComparison {
  schema : String
  before : ComparedWikiPage
  after : ComparedWikiPage
  diff : @page_compare.PageTextDiff
} derive(ToJson)

///|
/// Compare two maintained wiki citations without modifying either page or any
/// review record. Reads are sequential; the hashes identify the observed text,
/// not a locked Book snapshot or factual acceptance.
pub async fn compare_wiki_pages(
  root : String,
  before_citation : String,
  after_citation : String,
) -> WikiPageComparison {
  let before = query_page_text(root, before_citation)
  let after = if before_citation == after_citation {
    before
  } else {
    query_page_text(root, after_citation)
  }
  let diff = @page_compare.compare_page_text(before, after)
  {
    schema: "moonbook.wiki-page-comparison.v1",
    before: {
      citation: before_citation,
      digest: executable_sha256(before),
      metadata_status: query_metadata_status(before),
    },
    after: {
      citation: after_citation,
      digest: executable_sha256(after),
      metadata_status: query_metadata_status(after),
    },
    diff,
  }
}

///|
/// JSON-quoted lines keep markup and terminal control characters inert. The
/// ending escape in each quoted line preserves LF/CRLF and final-newline changes.
pub fn WikiPageComparison::to_text(self : WikiPageComparison) -> String {
  let lines = [
    "MoonBook maintained-page comparison",
    "Read-only observed text. Page metadata is not factual review. No claim, review state or permission is changed.",
    "Before: " +
    self.before.citation.to_json().stringify() +
    " " +
    self.before.digest,
    "After: " +
    self.after.citation.to_json().stringify() +
    " " +
    self.after.digest,
    "Metadata before: " + self.before.metadata_status.to_json().stringify(),
    "Metadata after: " + self.after.metadata_status.to_json().stringify(),
    "Added: \{self.diff.added}; removed: \{self.diff.removed}; unchanged: \{self.diff.unchanged}.",
    "Each row: kind before-line:after-line JSON-quoted exact text; '-' means no line on that side.",
    "",
  ]
  for line in self.diff.lines {
    let marker = if line.kind == "equal" {
      "="
    } else if line.kind == "remove" {
      "-"
    } else {
      "+"
    }
    lines.push(
      marker +
      " " +
      line.before_line.map(n => n.to_string()).unwrap_or("-") +
      ":" +
      line.after_line.map(n => n.to_string()).unwrap_or("-") +
      " " +
      line.text.to_json().stringify(),
    )
  }
  lines.join("\n") + "\n"
}
