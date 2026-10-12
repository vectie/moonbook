///|
// Collected during the same Markdown pass that assigns actual heading IDs.
// These are generated navigation labels, not a second Markdown parser.
priv struct ChapterHeading {
  level : Int
  id : String
  label : String
}

///|
fn render_chapter_outline(headings : Array[ChapterHeading]) -> String {
  if headings.is_empty() {
    return ""
  }
  let builder = StringBuilder()
  builder.write_string(
    "<details class=\"chapter-outline\" open=\"open\"><summary>On this page</summary><nav aria-label=\"On this page\"><ol>",
  )
  for heading in headings {
    let label = if heading.label.trim().is_empty() {
      "Untitled section"
    } else {
      heading.label
    }
    let href = outline_fragment(heading.id)
    builder.write_string(
      "<li class=\"outline-level-\{heading.level}\"><a href=\"#\{href}\">\{escape_html(label)}</a></li>",
    )
  }
  builder.write_string("</ol></nav></details>")
  builder.to_string()
}

///|
// A literal UTF-8 fragment, including Unicode and reserved URL characters.
fn outline_fragment(id : String) -> String {
  let builder = StringBuilder()
  for byte in @utf8.encode(id) {
    let code = byte.to_int()
    if (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      byte == b'-' ||
      byte == b'_' ||
      byte == b'.' ||
      byte == b'~' {
      builder.write_char(code.to_char().unwrap())
    } else {
      builder.write_string("%")
      builder.write_string(
        "0123456789ABCDEF"[code / 16:code / 16 + 1].to_owned(),
      )
      builder.write_string(
        "0123456789ABCDEF"[code % 16:code % 16 + 1].to_owned(),
      )
    }
  }
  builder.to_string()
}
