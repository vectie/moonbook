///|
// Read the first href of an actual anchor tag, matching HTML's first-attribute
// behavior. Only this tag's attributes are considered, never attribute text.
fn connection_anchor_href(tag : String) -> String? {
  if tag.length() < 3 ||
    tag[0] != '<' ||
    (tag[1] != 'a' && tag[1] != 'A') ||
    (!whole_book_attribute_space(tag[2]) && tag[2] != '>') {
    return None
  }
  let mut position = 2
  while position < tag.length() {
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
    let name = tag[name_start:position].to_owned().to_lower()
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() || tag[position] == '>' {
      return None
    }
    if tag[position] != '=' {
      continue
    }
    position += 1
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() {
      return None
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
          (if quote == 0 {
            !whole_book_attribute_space(tag[position]) && tag[position] != '>'
          } else {
            tag[position] != quote
          }) {
      position += 1
    }
    let value = tag[value_start:position].to_owned()
    if name == "href" {
      return Some(value)
    }
    if quote != 0 && position < tag.length() {
      position += 1
    }
  }
  None
}

///|
// Decode one HTML-attribute layer before separating URL query/fragment. Percent
// bytes are decoded afterward, so %23 in a filename never becomes a fragment.
fn connection_attribute_text(value : String) -> String {
  let result = StringBuilder()
  let mut position = 0
  while position < value.length() {
    if value[position] == '&' {
      if value[position + 1:].find(";") is Some(end) && end <= 12 {
        let entity = value[position + 1:position + 1 + end].to_owned()
        if connection_entity(entity) is Some(character) {
          result.write_char(character)
          position += end + 2
          continue
        }
      }
    }
    result.write_string(current_scalar(value, position))
    position += scalar_width(value, position)
  }
  result.to_string()
}

///|
fn connection_entity(entity : String) -> Char? {
  match entity {
    "amp" | "AMP" => return Some('&')
    "quot" | "QUOT" => return Some('"')
    "apos" => return Some('\'')
    "lt" | "LT" => return Some('<')
    "gt" | "GT" => return Some('>')
    "colon" => return Some(':')
    "sol" => return Some('/')
    "quest" => return Some('?')
    "num" => return Some('#')
    "percnt" => return Some('%')
    "Tab" => return Some('\t')
    "NewLine" => return Some('\n')
    _ => ()
  }
  if !entity.has_prefix("#") {
    return None
  }
  let hex = entity.has_prefix("#x") || entity.has_prefix("#X")
  let start = if hex { 2 } else { 1 }
  if start == entity.length() {
    return None
  }
  let radix = if hex { 16 } else { 10 }
  let mut value = 0
  for position in start..<entity.length() {
    let code = entity[position].to_int()
    let digit = if code >= 48 && code <= 57 {
      code - 48
    } else if hex && code >= 65 && code <= 70 {
      code - 55
    } else if hex && code >= 97 && code <= 102 {
      code - 87
    } else {
      return None
    }
    value = value * radix + digit
    if value > 0x10ffff {
      return None
    }
  }
  if value == 0 || (value >= 0xd800 && value <= 0xdfff) {
    return None
  }
  value.to_char()
}
