///|
priv struct EpubImage {
  source : String
  destination : String
  media_type : String
}

///|
fn epub_resolve_path(current : String, value : String) -> String raise {
  let decoded = whole_book_percent_path_text(value)
  guard !decoded.contains("\\") &&
    !decoded.contains(":") &&
    !decoded.contains("\u0000") &&
    !decoded.has_prefix("/") else {
    fail("EPUB expects a relative source path: \{value}")
  }
  let path = @pathx.normalize(@pathx.join(path_dirname(current), decoded))
  guard path != ".." && !path.has_prefix("../") else {
    fail("EPUB resource is outside the book source: \{value}")
  }
  path
}

///|
fn epub_image_link(
  current : String,
  value : String,
  images : Array[EpubImage],
) -> String raise {
  guard !value.is_empty() && !value.contains("?") && !value.contains("#") else {
    fail("EPUB image must name a local PNG, JPEG or GIF: \{value}")
  }
  let path = epub_resolve_path(current, value)
  for image in images {
    if image.source == path {
      return image.destination
    }
  }
  let (extension, media_type) = match @pathx.ext(path).to_string().to_lower() {
    ".png" => ("png", "image/png")
    ".jpg" | ".jpeg" => ("jpg", "image/jpeg")
    ".gif" => ("gif", "image/gif")
    _ =>
      fail("EPUB image format is unsupported: \{value}; use PNG, JPEG or GIF")
  }
  let destination = "images/image-\{images.length() + 1}.\{extension}"
  images.push({ source: path, destination, media_type, })
  destination
}

///|
fn epub_chapter_link(
  current : String,
  value : String,
  targets : Map[String, String],
  anchors : Map[String, Map[String, Unit]],
) -> String raise {
  if value.has_prefix("https://") ||
    value.has_prefix("http://") ||
    value.has_prefix("mailto:") {
    return value
  }
  guard !value.contains("?") else {
    fail("EPUB local chapter links cannot contain a query: \{value}")
  }
  let hash = value.find("#").unwrap_or(value.length())
  let path = value[:hash].to_string()
  let fragment = if hash < value.length() {
    value[hash + 1:].to_string()
  } else {
    ""
  }
  let resolved = if path.is_empty() {
    current
  } else {
    epub_resolve_path(current, path)
  }
  let target = match targets.get(resolved) {
    Some(target) => target
    None => fail("EPUB chapter link has no SUMMARY target: \{value}")
  }
  if !fragment.is_empty() {
    let decoded = whole_book_percent_path_text(fragment)
    guard anchors.get(target) is Some(ids) && ids.contains(decoded) else {
      fail("EPUB chapter link has no heading or anchor: \{value}")
    }
    target + "#" + epub_encode_fragment(decoded)
  } else {
    target
  }
}

///|
fn epub_rewrite_element(
  element : @xml.Element,
  current : String,
  targets : Map[String, String],
  anchors : Map[String, Map[String, Unit]],
  images : Array[EpubImage],
) -> @xml.Element raise {
  guard [
    "article", "section", "div", "p", "h1", "h2", "h3", "h4", "h5", "h6", "a", "em",
    "strong", "b", "i", "s", "del", "sup", "sub", "span", "code", "pre", "blockquote",
    "ul", "ol", "li", "table", "thead", "tbody", "tfoot", "tr", "th", "td", "caption",
    "img", "hr", "br", "input", "button", "details", "summary", "dl", "dt", "dd",
  ].contains(element.name) else {
    fail("EPUB unsupported element <\{element.name}> in \{current}")
  }
  let attributes : Array[@xml.Attribute] = []
  for attribute in element.attributes {
    let name = attribute.name
    let value = attribute.value
    epub_validate_xml_text(value)
    guard !name.to_lower().has_prefix("on") &&
      name != "srcset" &&
      name != "xmlns" &&
      !name.contains(":") else {
      fail("EPUB unsupported attribute \{name} in \{current}")
    }
    let rewritten = match name {
      "href" => {
        guard element.name == "a" else {
          fail("EPUB href is supported only on links")
        }
        epub_chapter_link(current, value, targets, anchors)
      }
      "src" => {
        guard element.name == "img" else {
          fail("EPUB src is supported only on images")
        }
        epub_image_link(current, value, images)
      }
      "style" => {
        guard ["text-align: left", "text-align: right", "text-align: center"].contains(
          value,
        ) else {
          fail("EPUB only supports table text-alignment inline styles")
        }
        value
      }
      _ => value
    }
    attributes.push({ name, value: rewritten, })
  }
  let children : Array[@xml.Node] = []
  for node in element.children {
    match node {
      Element(child) => {
        // The browser copy button has no action in a static ebook.
        if child.name == "button" &&
          child.attribute("class") == Some("code-copy") {
          continue
        }
        children.push(
          Element(
            epub_rewrite_element(child, current, targets, anchors, images),
          ),
        )
      }
      Text(text) => {
        epub_validate_xml_text(text)
        children.push(Text(text))
      }
    }
  }
  { name: element.name, attributes, children, }
}

///|
fn epub_encode_fragment(text : String) -> String {
  let result = StringBuilder()
  for byte in @utf8.encode(text) {
    let code = byte.to_int()
    if (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      byte == b'.' ||
      byte == b'-' ||
      byte == b'_' ||
      byte == b'~' {
      result.write_char(code.to_char().unwrap())
    } else {
      result.write_string("%")
      result.write_string(
        "0123456789ABCDEF"[code / 16:code / 16 + 1].to_owned(),
      )
      result.write_string(
        "0123456789ABCDEF"[code % 16:code % 16 + 1].to_owned(),
      )
    }
  }
  result.to_string()
}

///|
fn epub_image_signature(content : Bytes, media_type : String) -> Bool {
  match media_type {
    "image/png" => content.length() >= 8 && content[:8] == b"\x89PNG\r\n\x1a\n"
    "image/jpeg" => content.length() >= 3 && content[:3] == b"\xff\xd8\xff"
    "image/gif" =>
      content.length() >= 6 &&
      (content[:6] == b"GIF87a" || content[:6] == b"GIF89a")
    _ => false
  }
}

///|
fn epub_validate_xml_text(value : String) -> Unit raise {
  guard value
    .iter()
    .all(c => {
      let code = c.to_int()
      code == 9 ||
      code == 10 ||
      code == 13 ||
      (code >= 0x20 && code <= 0xd7ff) ||
      (code >= 0xe000 && code <= 0xfffd) ||
      (code >= 0x10000 && code <= 0x10ffff)
    }) else {
    fail("EPUB text contains a character XML cannot represent")
  }
}
