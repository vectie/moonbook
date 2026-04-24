///|
// Inline markdown rendering, link rewriting, and scalar-safe text helpers.

///|
fn render_inline(text : String) -> String {
  render_inline_with_refs(text, {})
}

///|
fn render_inline_with_refs(
  text : String,
  references : Map[String, String],
) -> String {
  let builder = StringBuilder::new()
  let mut i = 0
  while i < text.length() {
    if text[i] == '\\' && i + 1 < text.length() {
      let escaped = current_scalar(text, i + 1)
      builder.write_string(escape_html(escaped))
      i = i + 1 + scalar_width(text, i + 1)
    } else if i + 1 < text.length() && text[i] == '[' && text[i + 1] == '^' {
      match text[i + 2:].find("]") {
        Some(end) => {
          let name = text[i + 2:i + 2 + end].to_string()
          let id = slugify_heading(name)
          builder.write_string(
            "<sup class=\"footnote-reference\"><a href=\"#footnote-\{id}\" id=\"fr-\{id}\">\{escape_html(name)}</a></sup>",
          )
          i = i + end + 3
        }
        None => {
          builder.write_string("[")
          i += 1
        }
      }
    } else if text[i] == '`' {
      match text[i + 1:].find("`") {
        Some(end) => {
          let code = text[i + 1:i + 1 + end].to_string()
          builder.write_string("<code>\{escape_html(code)}</code>")
          i = i + end + 2
        }
        None => {
          builder.write_string("`")
          i += 1
        }
      }
    } else if i + 1 < text.length() && text[i] == '*' && text[i + 1] == '*' {
      match text[i + 2:].find("**") {
        Some(end) => {
          let content = text[i + 2:i + 2 + end].to_string()
          builder.write_string(
            "<strong>\{render_inline_with_refs(content, references)}</strong>",
          )
          i = i + end + 4
        }
        None => {
          builder.write_string("**")
          i += 2
        }
      }
    } else if i + 1 < text.length() && text[i] == '_' && text[i + 1] == '_' {
      match text[i + 2:].find("__") {
        Some(end) => {
          let content = text[i + 2:i + 2 + end].to_string()
          builder.write_string(
            "<strong>\{render_inline_with_refs(content, references)}</strong>",
          )
          i = i + end + 4
        }
        None => {
          builder.write_string("__")
          i += 2
        }
      }
    } else if text[i] == '*' {
      match text[i + 1:].find("*") {
        Some(end) => {
          let content = text[i + 1:i + 1 + end].to_string()
          builder.write_string(
            "<em>\{render_inline_with_refs(content, references)}</em>",
          )
          i = i + end + 2
        }
        None => {
          builder.write_string("*")
          i += 1
        }
      }
    } else if text[i] == '_' {
      match find_single_emphasis_end(text, i + 1, '_') {
        Some(end) => {
          let content = text[i + 1:end].to_string()
          builder.write_string(
            "<em>\{render_inline_with_refs(content, references)}</em>",
          )
          i = end + 1
        }
        None => {
          builder.write_string("_")
          i += 1
        }
      }
    } else if text[i] == '[' {
      match text[i + 1:].find("](") {
        Some(mid) => {
          let close_index = i + 1 + mid
          match text[close_index + 2:].find(")") {
            Some(end) => {
              let label = text[i + 1:close_index].to_string()
              let href = text[close_index + 2:close_index + 2 + end].to_string()
              let fixed_href = fix_link(href)
              builder.write_string(
                "<a href=\"\{escape_html(fixed_href)}\">\{render_inline_with_refs(label, references)}</a>",
              )
              i = close_index + end + 3
            }
            None => {
              builder.write_string("[")
              i += 1
            }
          }
        }
        None =>
          match text[i + 1:].find("]") {
            Some(end) => {
              let label = text[i + 1:i + 1 + end].to_string()
              let key = label.to_lower()
              match references.get(key) {
                Some(href) => {
                  let fixed_href = fix_link(href)
                  builder.write_string(
                    "<a href=\"\{escape_html(fixed_href)}\">\{render_inline_with_refs(label, references)}</a>",
                  )
                  i = i + end + 2
                }
                None => {
                  builder.write_string("[")
                  i += 1
                }
              }
            }
            None => {
              builder.write_string("[")
              i += 1
            }
          }
      }
    } else if i + 1 < text.length() && text[i] == '!' && text[i + 1] == '[' {
      match text[i + 2:].find("](") {
        Some(mid) => {
          let close_index = i + 2 + mid
          match text[close_index + 2:].find(")") {
            Some(end) => {
              let alt = text[i + 2:close_index].to_string()
              let src = text[close_index + 2:close_index + 2 + end].to_string()
              let fixed_src = fix_link(src)
              builder.write_string(
                "<img src=\"\{escape_html(fixed_src)}\" alt=\"\{escape_html(alt)}\">",
              )
              i = close_index + end + 3
            }
            None => {
              builder.write_string("!")
              i += 1
            }
          }
        }
        None => {
          builder.write_string("!")
          i += 1
        }
      }
    } else if text[i] == '<' {
      match text[i:].find(">") {
        Some(end) => {
          let tag = text[i + 1:i + end].to_string()
          if is_autolink(tag) {
            let fixed_href = fix_link(tag)
            builder.write_string(
              "<a href=\"\{escape_html(fixed_href)}\">\{escape_html(tag)}</a>",
            )
          } else {
            let html = text[i:i + end + 1].to_string()
            builder.write_string(rewrite_html_attributes(html))
          }
          i = i + end + 1
        }
        None => {
          builder.write_string("&lt;")
          i += 1
        }
      }
    } else {
      builder.write_string(escape_html(current_scalar(text, i)))
      i += scalar_width(text, i)
    }
  }
  builder.to_string()
}

///|
fn inline_text_content(
  text : String,
  references : Map[String, String],
) -> String {
  let builder = StringBuilder::new()
  let mut i = 0
  while i < text.length() {
    if text[i] == '\\' && i + 1 < text.length() {
      let escaped = current_scalar(text, i + 1)
      builder.write_string(escaped)
      i = i + 1 + scalar_width(text, i + 1)
    } else if i + 1 < text.length() && text[i] == '[' && text[i + 1] == '^' {
      match text[i + 2:].find("]") {
        Some(end) => {
          builder.write_string(text[i + 2:i + 2 + end].to_string())
          i = i + end + 3
        }
        None => {
          builder.write_char('[')
          i += 1
        }
      }
    } else if text[i] == '`' {
      match text[i + 1:].find("`") {
        Some(end) => {
          builder.write_string(text[i + 1:i + 1 + end].to_string())
          i = i + end + 2
        }
        None => {
          builder.write_char('`')
          i += 1
        }
      }
    } else if i + 1 < text.length() &&
      (
        (text[i] == '*' && text[i + 1] == '*') ||
        (text[i] == '_' && text[i + 1] == '_')
      ) {
      let delimiter = text[i:i + 2].to_string()
      match text[i + 2:].find(delimiter) {
        Some(end) => {
          builder.write_string(
            inline_text_content(text[i + 2:i + 2 + end].to_string(), references),
          )
          i = i + end + 4
        }
        None => {
          builder.write_string(delimiter)
          i += 2
        }
      }
    } else if text[i] == '*' || text[i] == '_' {
      let delimiter = text[i:i + 1].to_string()
      let closing = if text[i] == '_' {
        find_single_emphasis_end(text, i + 1, '_')
      } else {
        match text[i + 1:].find(delimiter) {
          Some(end) => Some(i + 1 + end)
          None => None
        }
      }
      match closing {
        Some(end) => {
          builder.write_string(
            inline_text_content(text[i + 1:end].to_string(), references),
          )
          i = end + 1
        }
        None => {
          builder.write_string(text[i:i + 1].to_string())
          i += 1
        }
      }
    } else if i + 1 < text.length() && text[i] == '!' && text[i + 1] == '[' {
      match text[i + 2:].find("](") {
        Some(mid) => {
          let close_index = i + 2 + mid
          builder.write_string(text[i + 2:close_index].to_string())
          match text[close_index + 2:].find(")") {
            Some(end) => i = close_index + end + 3
            None => i += 1
          }
        }
        None => {
          builder.write_char('!')
          i += 1
        }
      }
    } else if text[i] == '[' {
      match text[i + 1:].find("](") {
        Some(mid) => {
          let close_index = i + 1 + mid
          builder.write_string(
            inline_text_content(text[i + 1:close_index].to_string(), references),
          )
          match text[close_index + 2:].find(")") {
            Some(end) => i = close_index + end + 3
            None => i += 1
          }
        }
        None =>
          match text[i + 1:].find("]") {
            Some(end) => {
              let label = text[i + 1:i + 1 + end].to_string()
              let key = label.to_lower()
              match references.get(key) {
                Some(_) => {
                  builder.write_string(inline_text_content(label, references))
                  i = i + end + 2
                }
                None => {
                  builder.write_char('[')
                  i += 1
                }
              }
            }
            None => {
              builder.write_char('[')
              i += 1
            }
          }
      }
    } else if text[i] == '<' {
      match text[i:].find(">") {
        Some(end) => {
          let tag = text[i + 1:i + end].to_string()
          if is_autolink(tag) {
            builder.write_string(tag)
          }
          i = i + end + 1
        }
        None => {
          builder.write_char('<')
          i += 1
        }
      }
    } else {
      builder.write_string(current_scalar(text, i))
      i += scalar_width(text, i)
    }
  }
  builder.to_string()
}

///|
fn scalar_width(text : String, index : Int) -> Int {
  if index + 1 < text.length() {
    let first = text[index].to_int()
    let second = text[index + 1].to_int()
    if first >= 0xD800 &&
      first <= 0xDBFF &&
      second >= 0xDC00 &&
      second <= 0xDFFF {
      return 2
    }
  }
  1
}

///|
fn current_scalar(text : String, index : Int) -> String {
  text[index:index + scalar_width(text, index)].to_string()
}

///|
fn is_autolink(text : String) -> Bool {
  !text.contains(" ") &&
  (
    text.has_prefix("http://") ||
    text.has_prefix("https://") ||
    text.has_prefix("mailto:")
  )
}

///|
fn find_single_emphasis_end(
  text : String,
  start : Int,
  delimiter : Char,
) -> Int? {
  let delimiter_code = delimiter.to_int()
  for i = start; i < text.length(); i = i + 1 {
    if text[i].to_int() == delimiter_code {
      if delimiter == '_' &&
        i > 0 &&
        i + 1 < text.length() &&
        is_word_codepoint(text[i - 1]) &&
        is_word_codepoint(text[i + 1]) {
        continue
      }
      return Some(i)
    }
  }
  None
}

///|
fn is_word_codepoint(code : UInt16) -> Bool {
  let value = code.to_int()
  (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
  (value >= 'A'.to_int() && value <= 'Z'.to_int()) ||
  (value >= '0'.to_int() && value <= '9'.to_int()) ||
  value == '_'.to_int() ||
  value > 127
}

///|
fn fix_link(link : String) -> String {
  if should_preserve_link(link) {
    return link
  }
  match link.find("#") {
    Some(index) => {
      let base = link[:index].to_string()
      let anchor = link[index:].to_string()
      fix_link_path(base) + anchor
    }
    None => fix_link_path(link)
  }
}

///|
fn should_preserve_link(link : String) -> Bool {
  link.has_prefix("#") ||
  link.contains("://") ||
  link.has_prefix("mailto:") ||
  link.has_prefix("tel:") ||
  link.has_prefix("javascript:") ||
  link.has_prefix("data:")
}

///|
fn fix_link_path(path : String) -> String {
  if path.has_suffix(".md") {
    path[:path.length() - 3].to_string() + ".html"
  } else {
    path
  }
}

///|
fn is_local_asset(path : String) -> Bool {
  let plain = strip_link_anchor(path)
  !plain.has_prefix("#") &&
  !plain.contains("://") &&
  !plain.has_prefix("mailto:") &&
  !plain.has_prefix("tel:") &&
  !plain.has_prefix("javascript:") &&
  !plain.has_prefix("data:") &&
  !plain.has_suffix(".md") &&
  !plain.has_suffix(".html") &&
  !plain.has_suffix(".htm")
}

///|
fn strip_link_anchor(path : String) -> String {
  match path.find("#") {
    Some(index) => path[:index].to_string()
    None => path
  }
}

///|
