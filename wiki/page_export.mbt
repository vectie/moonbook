///|
/// An exact decoded maintained page selected by its Book-relative citation.
pub struct ExportedWikiPage {
  citation : String
  digest : String
  metadata_status : String
  content : String
} derive(ToJson)

///|
pub struct WikiPageDossier {
  schema : String
  notice : String
  pages : Array[ExportedWikiPage]
} derive(ToJson)

///|
/// Export only explicitly selected maintained pages, in caller order. No raw
/// sources, linked pages, generated state or review transitions are included.
pub async fn export_wiki_pages(
  root : String,
  citations : Array[String],
) -> WikiPageDossier {
  guard citations.length() > 0 && citations.length() <= 32 else {
    fail("select between 1 and 32 maintained-page citations")
  }
  let seen : Map[String, Bool] = {}
  for citation in citations {
    guard !seen.contains(citation) else { fail("duplicate page citation") }
    seen[citation] = true
  }
  let pages : Array[ExportedWikiPage] = []
  let mut total = 0
  for citation in citations {
    let content = query_page_text(root, citation)
    guard content.length() <= 262144 else {
      fail("selected page exceeds 256 Ki UTF-16 code units")
    }
    total += content.length()
    guard total <= 1048576 else {
      fail("selected pages exceed 1 Mi UTF-16 code units in total")
    }
    pages.push({
      citation,
      digest: executable_sha256(content),
      metadata_status: page_export_metadata_status(content),
      content,
    })
  }
  {
    schema: "moonbook.wiki-page-dossier.v1",
    notice: "Read-only selected maintained-page snapshots. Metadata is not factual review. Linked and raw sources are not included. Sequential reads are not an atomic Book snapshot.",
    pages,
  }
}

///|
/// Literal fenced text prevents source Markdown/HTML from becoming active
/// dossier markup. JSON provides the exact machine round-trip representation.
pub fn WikiPageDossier::to_markdown(self : WikiPageDossier) -> String {
  let out = StringBuilder()
  out.write_string(
    "# MoonBook selected-page dossier\n\n" + self.notice + "\n\n",
  )
  for index, page in self.pages {
    out.write_string("## Page " + (index + 1).to_string() + "\n\n")
    let metadata = "Citation: " +
      page.citation.to_json().stringify() +
      "\nContent digest: " +
      page.digest +
      "\nPage metadata status: " +
      page.metadata_status.to_json().stringify()
    out.write_string(page_export_literal_block(metadata) + "\n")
    out.write_string(page_export_literal_block(page.content) + "\n")
  }
  out.to_string()
}

///|
fn page_export_literal_block(content : String) -> String {
  let out = StringBuilder()
  let mut longest = 0
  let mut current = 0
  for character in content {
    if character == '`' {
      current += 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }
  let fence = "`".repeat(if longest < 3 { 3 } else { longest + 1 })
  out.write_string(fence + "text\n" + content)
  if !content.has_suffix("\n") {
    out.write_string("\n")
  }
  out.write_string(fence + "\n")
  out.to_string()
}

///|
/// Preserve the full single-line status scalar. Remove only the conventional
/// single space after the colon and the physical CRLF terminator, not value
/// whitespace. This does not interpret quoted or multiline YAML values.
fn page_export_metadata_status(content : String) -> String {
  let lines = content.split("\n").to_array()
  if lines.is_empty() || !(lines[0] == "---" || lines[0] == "---\r") {
    return "Not supplied"
  }
  for index = 1; index < lines.length(); index = index + 1 {
    let original = lines[index].to_owned()
    let line = if original.has_suffix("\r") {
      original[:original.length() - 1].to_owned()
    } else {
      original
    }
    if line == "---" {
      break
    }
    if line.has_prefix("status:") {
      let value = line[7:].to_owned()
      return if value.has_prefix(" ") { value[1:].to_owned() } else { value }
    }
  }
  "Not supplied"
}
