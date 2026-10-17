///|
// Rewrite actual tag attributes, never text/code examples or comments. The
// ordinary renderer remains responsible for Markdown and its raw-HTML policy.
fn whole_book_rewrite_html(
  html : String,
  chapter_id : String,
  current_page : String,
  targets : Map[String, String],
) -> String {
  transform_html_tags(html, fn(tag) {
    whole_book_rewrite_tag(tag, chapter_id, current_page, targets)
  })
}

///|
fn whole_book_attribute_space(code : UInt16) -> Bool {
  code == ' ' ||
  code == '\n' ||
  code == '\r' ||
  code == '\t' ||
  code == '\u{0c}'
}

///|
fn whole_book_rewrite_tag(
  tag : String,
  chapter_id : String,
  current_page : String,
  targets : Map[String, String],
) -> String {
  let result = StringBuilder()
  let mut position = 1
  while position < tag.length() &&
        !whole_book_attribute_space(tag[position]) &&
        tag[position] != '>' {
    position += 1
  }
  result.write_string(tag[:position].to_string())
  while position < tag.length() {
    let start = position
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    let name_start = position
    while position < tag.length() &&
          !whole_book_attribute_space(tag[position]) &&
          tag[position] != '=' &&
          tag[position] != '>' {
      position += 1
    }
    let name = tag[name_start:position].to_string().to_lower()
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() || tag[position] != '=' {
      if position == start {
        position += 1
      }
      result.write_string(tag[start:position].to_string())
      continue
    }
    position += 1
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() {
      result.write_string(tag[start:].to_string())
      break
    }
    let quote = if tag[position] == '"' || tag[position] == '\'' {
      tag[position]
    } else {
      0
    }
    if quote != 0 {
      position += 1
    }
    let value_start = position
    while position < tag.length() &&
          (if quote != 0 {
            tag[position] != quote
          } else {
            !whole_book_attribute_space(tag[position]) && tag[position] != '>'
          }) {
      position += 1
    }
    let value = tag[value_start:position].to_string()
    let rewritten = match name {
      "id" => chapter_id + "--" + value
      "href" | "src" =>
        whole_book_link(
          value,
          name == "href",
          chapter_id,
          current_page,
          targets,
        )
      _ => value
    }
    if quote != 0 && position < tag.length() {
      position += 1
    }
    if name == "id" || name == "href" || name == "src" {
      result.write_string(tag[start:name_start].to_string())
      result.write_string(name + "=\"")
      for character in rewritten {
        if character == '"' {
          result.write_string("&quot;")
        } else {
          result.write_char(character)
        }
      }
      result.write_string("\"")
    } else {
      result.write_string(tag[start:position].to_string())
    }
  }
  result.to_string()
}

///|
fn whole_book_link(
  value : String,
  is_link : Bool,
  chapter_id : String,
  current_page : String,
  targets : Map[String, String],
) -> String {
  if value.has_prefix("#") {
    return if is_link {
      "#" +
      chapter_id +
      (if value == "#" { "" } else { "--" + value[1:].to_string() })
    } else {
      value
    }
  }
  // Scheme, root-relative and protocol-relative URLs retain their meaning.
  if value.is_empty() || value.has_prefix("/") || value.contains(":") {
    return value
  }
  let fragment_at = value.find("#").unwrap_or(value.length())
  let path_and_query = value[:fragment_at].to_string()
  let query_at = path_and_query.find("?").unwrap_or(path_and_query.length())
  let path = path_and_query[:query_at].to_string()
  let query = path_and_query[query_at:].to_string()
  let fragment = value[fragment_at:].to_string()
  let resolved = if path.is_empty() {
    static_search_escape_html(current_page)
  } else {
    @pathx.join(static_search_escape_html(path_dirname(current_page)), path)
  }
  let lookup = if path.is_empty() {
    current_page
  } else {
    @pathx.join(path_dirname(current_page), whole_book_path_text(path))
  }
  if is_link && query.is_empty() && targets.get(lookup) is Some(target) {
    return "#" +
      target +
      (if fragment.is_empty() || fragment == "#" {
        ""
      } else {
        "--" + fragment[1:].to_string()
      })
  }
  relative_href("__moonbook/print.html", resolved) + query + fragment
}

///|
// ASCII tag-name matching keeps offsets correct beside non-ASCII text such as İ.
fn whole_book_ascii_find(
  text : String,
  start : Int32,
  pattern : String,
) -> Int32? {
  for position = start
      position + pattern.length() <= text.length()
      position = position + 1 {
    let mut matches = true
    for index in 0..<pattern.length() {
      let value = text[position + index].to_int()
      let lower = if value >= 65 && value <= 90 { value + 32 } else { value }
      if lower != pattern[index].to_int() {
        matches = false
        break
      }
    }
    if matches {
      return Some(position)
    }
  }
  None
}

///|
// Only lookup uses decoded paths; fallback URLs retain their original escaping.
fn whole_book_path_text(path : String) -> String {
  let text = path
    .replace_all(old="&quot;", new="\"")
    .replace_all(old="&apos;", new="'")
    .replace_all(old="&#39;", new="'")
    .replace_all(old="&lt;", new="<")
    .replace_all(old="&gt;", new=">")
    .replace_all(old="&amp;", new="&")
  whole_book_percent_path_text(text)
}

///|
fn whole_book_percent_path_text(text : String) -> String {
  let input = @utf8.encode(text)
  let output : Array[Byte] = []
  let mut position = 0
  while position < input.length() {
    if input[position] == b'%' && position + 2 < input.length() {
      let high = whole_book_hex(input[position + 1])
      let low = whole_book_hex(input[position + 2])
      if high >= 0 && low >= 0 {
        output.push((high * 16 + low).to_byte())
        position += 3
        continue
      }
    }
    output.push(input[position])
    position += 1
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => text
  }
}

///|
fn whole_book_hex(byte : Byte) -> Int32 {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    value - 48
  } else if value >= 65 && value <= 70 {
    value - 55
  } else if value >= 97 && value <= 102 {
    value - 87
  } else {
    -1
  }
}
