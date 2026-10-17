///|
/// Read an actual maintained page within this Book. Links and non-page paths
/// are refused. A failed page read fails the query rather than hiding a source.
pub async fn query_page_text(root : String, citation : String) -> String {
  guard citation.has_prefix("wiki/") &&
    is_queryable_page("/" + citation) &&
    !citation.contains("\\") &&
    !citation.contains("\u0000") &&
    citation.split("/").all(part => part != "" && part != "." && part != "..") else {
    fail("invalid maintained-page citation")
  }
  let canonical = @fs.realpath(root)
  @utf8.decode(@fsx.read_maintained_bytes(canonical, citation))
}

///|
fn query_metadata_status(content : String) -> String {
  if !content.has_prefix("---\n") {
    return "Not supplied"
  }
  for line in content[4:].split("\n") {
    if line == "---" {
      break
    }
    if line.has_prefix("status:") {
      return line[7:].trim().to_owned()[:160].to_owned()
    }
  }
  "Not supplied"
}

///|
/// A readable text export of the same ranked excerpts; no generated synthesis,
/// review decisions, keeper updates, or saved query pages are produced.
pub fn query_context_brief(result : QueryResult) -> String {
  query_context_brief_at(result, 0, "No matching maintained pages found.\n")
}

///|
fn query_context_brief_at(
  result : QueryResult,
  rank_offset : Int32,
  empty_message : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "MoonBook context brief\n\nQuestion: " + result.question + "\n\n",
  )
  out.write_string(
    "Deterministic lexical matches from maintained pages at query time. Excerpts may be maintained summaries. This is not a generated answer or factual verification. Page metadata is informative only.\n\n",
  )
  if result.excerpts.is_empty() {
    out.write_string(empty_message)
  }
  for index, item in result.excerpts {
    out.write_string(
      "[" + (rank_offset + index + 1).to_string() + "] " + item.title + "\n",
    )
    out.write_string(item.excerpt + "\n")
    out.write_string("Citation: " + item.citation + "\n")
    out.write_string(
      "Page metadata status (unverified): " + item.metadata_status + "\n\n",
    )
  }
  out.to_string()
}
