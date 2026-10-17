///|
pub(all) struct QueryRetainedDescriptor {
  reference : String
  page_digest : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QueryRetainedSource {
  reference : String
  page_digest : String
  digest : String
  size : Int32
  bytes_base64 : String
  text : String?
} derive(Debug, Eq, ToJson)

///|
/// Recognize only the generated source-page provenance header. Markdown links,
/// examples, fenced extracts, and arbitrary source-looking text are not paths.
fn query_retained_reference(citation : String, content : String) -> String? {
  if !citation.has_prefix("wiki/sources/") || !content.has_prefix("---\n") {
    return None
  }
  let lines = content.split("\n").map(line => line.to_owned()).to_array()
  let mut end = 1
  let mut source_kind = 0
  while end < lines.length() && lines[end] != "---" {
    if lines[end].has_prefix("moonbook_type:") &&
      lines[end] != "moonbook_type: source" {
      return None
    }
    if lines[end] == "moonbook_type: source" {
      source_kind += 1
    }
    end += 1
  }
  if source_kind != 1 ||
    end + 4 >= lines.length() ||
    lines[end + 1] != "" ||
    !lines[end + 2].has_prefix("# ") ||
    lines[end + 3] != "" {
    return None
  }
  let provenance = lines[end + 4]
  if !provenance.has_prefix("- Raw source: [raw/") ||
    !provenance.has_suffix(")") {
    return None
  }
  let pieces = provenance[15:].split("](").to_array()
  if pieces.length() != 2 {
    return None
  }
  let reference = pieces[0].to_owned()
  if !reference.has_prefix("raw/") ||
    reference.split("/").any(part => part == "" || part == "." || part == "..") ||
    reference
    .iter()
    .any(ch => ch.to_int() < 32 || "\\:?#%[]()".contains(ch.to_string())) {
    return None
  }
  let expected = "- Raw source: [" +
    reference +
    "](" +
    relative_from_page(citation, reference) +
    ")"
  if provenance != expected {
    return None
  }
  // Any second provenance-like line outside a fenced example makes the
  // binding ambiguous, including malformed duplicate declarations.
  let mut fence = ""
  let mut count = 0
  for line in lines[end + 1:] {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("```") || trimmed.has_prefix("~~~") {
      let marker = trimmed[:3].to_owned()
      if fence == "" {
        fence = marker
      } else if fence == marker {
        fence = ""
      }
    } else if fence == "" && trimmed.has_prefix("- Raw source:") {
      count += 1
    }
  }
  if count == 1 {
    Some(reference)
  } else {
    None
  }
}

///|
/// The optional descriptor is advisory; unreadable raw bytes never prevent
/// inspection of the maintained page. Its digest binds the whole page.
pub async fn query_retained_descriptor(
  root : String,
  citation : String,
  content : String,
) -> QueryRetainedDescriptor? noraise {
  guard query_retained_reference(citation, content) is Some(reference) else {
    return None
  }
  try {
    ignore(@fsx.read_retained_bytes(@fs.realpath(root), reference))
    Some({ reference, page_digest: executable_sha256(content), })
  } catch {
    _ => None
  }
}

///|
/// Re-read the selected maintained page and resolve its generated binding.
/// There is intentionally no requested raw path, root, or remote URL argument.
/// Returned bytes are the complete bounded current file, not ingest-time proof.
pub async fn query_retained_source(
  root : String,
  citation : String,
  page_digest : String,
) -> QueryRetainedSource {
  let content = query_page_text(root, citation)
  if executable_sha256(content) != page_digest {
    fail("maintained page changed; inspect it again")
  }
  guard query_retained_reference(citation, content) is Some(reference) else {
    fail("retained source binding unavailable")
  }
  let bytes = @fsx.read_retained_bytes(@fs.realpath(root), reference)
  // Reject a binding changed while the bytes were being read too.
  if query_page_text(root, citation) != content {
    fail("maintained page changed during retained source inspection")
  }
  let decoded = @utf8.decode(bytes) catch { _ => "\u0000" }
  let text = if decoded
    .iter()
    .any(ch => ch.to_int() < 32 && ch != '\t' && ch != '\r' && ch != '\n') {
    None
  } else {
    Some(decoded)
  }
  {
    reference,
    page_digest,
    digest: "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes)),
    size: bytes.length(),
    bytes_base64: @base64.encode(bytes),
    text,
  }
}
