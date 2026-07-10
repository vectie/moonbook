///|
const REMOTE_SOURCE_MAX_BYTES : Int = 2 * 1024 * 1024

///|
const REMOTE_SOURCE_EXTRACT_CHARS : Int = 6000

///|
fn is_remote_source(value : String) -> Bool {
  let normalized = value.trim().to_owned().to_lower()
  normalized.has_prefix("https://") || normalized.has_prefix("http://")
}

///|
async fn fetch_remote_source(raw_dir : String, url : String) -> String {
  let (response, data) = @http.get(url, headers={
    "Accept": "text/html, text/plain, application/json;q=0.9, */*;q=0.1",
    "User-Agent": "MoonBook-MoonWiki/0.1 (+https://github.com/vectie/moonbook)",
  }) catch {
    error => fail("remote source request failed: \{error}")
  }
  if response.code < 200 || response.code > 299 {
    fail("remote source returned HTTP \{response.code}: \{url}")
  }
  let body = data.text() catch {
    error => fail("remote source body is not text: \{error}")
  }
  if body.length() > REMOTE_SOURCE_MAX_BYTES {
    fail(
      "remote source exceeds \{REMOTE_SOURCE_MAX_BYTES} byte ingest limit: \{url}",
    )
  }
  let content_type = remote_content_type(response.headers)
  let title = remote_document_title(body).unwrap_or(url)
  let extract = remote_text_extract(body)
  if extract.trim().is_empty() {
    fail("remote source did not contain substantive text: \{url}")
  }
  let imported_dir = moonbook_wiki_path(raw_dir)
    .join(moonbook_wiki_path("imported"))
    .to_string()
  let path = unique_import_path(
    imported_dir,
    "remote-source-\{@async.now().to_int()}.md",
  )
  let packet = "# \{strip_inline_markup(title)}\n\n" +
    "- Source URL: [\{url}](\{url})\n" +
    "- Retrieval status: HTTP \{response.code}\n" +
    "- Content type: `\{content_type}`\n" +
    "- Retrieval mode: bounded remote extract\n" +
    "- Extract limit: `\{REMOTE_SOURCE_EXTRACT_CHARS}` characters\n" +
    "- Retrieved at: `\{@async.now().to_int()}`\n\n" +
    "## Remote extract\n\n" +
    extract +
    "\n"
  @fsx.write_to_file(path, packet, create=0o644)
  path
}

///|
fn remote_content_type(headers : Map[String, String]) -> String {
  match headers.get("content-type") {
    Some(value) => value
    None =>
      match headers.get("Content-Type") {
        Some(value) => value
        None => "unknown"
      }
  }
}

///|
fn remote_document_title(body : String) -> String? {
  let lowered = body.to_lower()
  guard lowered.find("<title") is Some(open_start) else { return None }
  let from_open = lowered[open_start:]
  guard from_open.find(">") is Some(open_end_relative) else { return None }
  let content_start = open_start + open_end_relative + 1
  let from_content = lowered[content_start:]
  guard from_content.find("</title>") is Some(close_relative) else {
    return None
  }
  let title = remote_collapse_whitespace(
    remote_decode_entities(
      body[content_start:content_start + close_relative].to_owned(),
    ),
  )
  if title.is_empty() {
    None
  } else {
    Some(title)
  }
}

///|
fn remote_text_extract(body : String) -> String {
  let body = remote_remove_element(
    remote_remove_element(
      remote_remove_element(remote_remove_element(body, "script"), "style"),
      "svg",
    ),
    "noscript",
  )
  let builder = StringBuilder::new()
  let mut inside_tag = false
  for character in body {
    if character == '<' {
      inside_tag = true
      builder.write_char(' ')
    } else if character == '>' {
      inside_tag = false
      builder.write_char(' ')
    } else if !inside_tag {
      builder.write_char(character)
    }
  }
  let compact = remote_collapse_whitespace(
    remote_decode_entities(builder.to_string()),
  )
  if compact.length() > REMOTE_SOURCE_EXTRACT_CHARS {
    compact[:REMOTE_SOURCE_EXTRACT_CHARS].to_owned() + "…"
  } else {
    compact
  }
}

///|
fn remote_decode_entities(text : String) -> String {
  text
  .replace(old="&nbsp;", new=" ")
  .to_string()
  .replace(old="&amp;", new="&")
  .to_string()
  .replace(old="&lt;", new="<")
  .to_string()
  .replace(old="&gt;", new=">")
  .to_string()
  .replace(old="&quot;", new="\"")
  .to_string()
  .replace(old="&#39;", new="'")
  .to_string()
  .replace(old="&#039;", new="'")
  .to_string()
  .replace(old="&apos;", new="'")
  .to_string()
}

///|
fn remote_remove_element(body : String, tag : String) -> String {
  let mut result = body
  let open_marker = "<\{tag}"
  let close_marker = "</\{tag}>"
  while true {
    let lowered = result.to_lower()
    guard lowered.find(open_marker) is Some(start) else { return result }
    let tail = lowered[start:]
    guard tail.find(close_marker) is Some(close_relative) else {
      return result[:start].to_owned()
    }
    let end = start + close_relative + close_marker.length()
    result = result[:start].to_owned() + " " + result[end:].to_owned()
  }
  result
}

///|
fn remote_collapse_whitespace(text : String) -> String {
  let builder = StringBuilder::new()
  let mut last_was_space = true
  for character in text {
    let is_space = character == ' ' ||
      character == '\n' ||
      character == '\r' ||
      character == '\t'
    if is_space {
      if !last_was_space {
        builder.write_char(' ')
      }
      last_was_space = true
    } else {
      builder.write_char(character)
      last_was_space = false
    }
  }
  builder.to_string().trim().to_owned()
}

///|
test "remote source detection accepts only HTTP transports" {
  assert_true(
    is_remote_source("https://www.nasa.gov/reference/moonbase-environment/"),
  )
  assert_true(is_remote_source("http://example.test/source"))
  assert_false(is_remote_source("file:///tmp/source.md"))
  assert_false(is_remote_source("notes/source.md"))
}

///|
test "remote HTML title and extract are bounded plain text" {
  let html = "<html><head><title> Lunar &amp; Dust </title><script>install hidden-noise</script></head><body><h1>South Pole</h1><p>Sharp regolith.</p></body></html>"
  assert_true(remote_document_title(html) == Some("Lunar & Dust"))
  assert_true(remote_text_extract(html).contains("South Pole Sharp regolith."))
  assert_false(remote_text_extract(html).contains("hidden-noise"))
}
