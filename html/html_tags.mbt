///|
// Visit actual tags only. Comments and raw text elements remain opaque.
// This is a bounded scanner for renderer output, not a general DOM parser.
fn transform_html_tags(html : String, rewrite : (String) -> String) -> String {
  let result = StringBuilder()
  let mut position = 0
  let mut raw_element = ""
  while position < html.length() {
    if !raw_element.is_empty() {
      // Raw script/style contents are opaque, including tag-like text.
      let closing = "</" + raw_element
      if whole_book_ascii_find(html, position, closing) is Some(offset) {
        result.write_string(html[position:offset].to_owned())
        position = offset
        raw_element = ""
      } else {
        result.write_string(html[position:].to_owned())
        break
      }
    }
    if html[position:].has_prefix("<!--") {
      let end = match html[position + 4:].find("-->") {
        Some(offset) => position + 4 + offset + 3
        None => html.length()
      }
      result.write_string(html[position:end].to_owned())
      position = end
      continue
    }
    if html[position] != '<' {
      result.write_string(current_scalar(html, position))
      position += scalar_width(html, position)
      continue
    }
    let start = position
    let mut quote : UInt16 = 0
    position += 1
    while position < html.length() {
      let code = html[position]
      if quote != 0 {
        if code == quote {
          quote = 0
        }
      } else if code == '"' || code == '\'' {
        quote = code
      } else if code == '>' {
        break
      }
      position += 1
    }
    if position == html.length() {
      result.write_string(html[start:].to_owned())
      break
    }
    let tag = html[start:position + 1].to_owned()
    result.write_string(rewrite(tag))
    let lower = tag.to_lower()
    for name in ["script", "style", "textarea", "title"] {
      if lower.has_prefix("<" + name) &&
        lower.length() > name.length() + 1 &&
        (
          lower[name.length() + 1] == '>' ||
          whole_book_attribute_space(lower[name.length() + 1])
        ) {
        raw_element = name
      }
    }
    position += 1
  }
  result.to_string()
}
