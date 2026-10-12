///|
// EPUB uses the ordinary Markdown renderer, then a bounded XML conversion.
// Unsupported raw HTML is reported, never silently converted into broken XHTML.
fn epub_xml_tag(tag : String) -> String {
  if tag.has_prefix("</") || tag.has_prefix("<!") || tag.has_prefix("<?") {
    return tag
  }
  let mut position = 1
  while position < tag.length() &&
        !whole_book_attribute_space(tag[position]) &&
        tag[position] != '>' &&
        tag[position] != '/' {
    position += 1
  }
  let name = tag[1:position].to_string()
  let result = StringBuilder()
  result.write_string(tag[:position].to_string())
  while position < tag.length() {
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() || tag[position] == '>' || tag[position] == '/' {
      break
    }
    let start = position
    while position < tag.length() &&
          !whole_book_attribute_space(tag[position]) &&
          tag[position] != '=' &&
          tag[position] != '>' &&
          tag[position] != '/' {
      position += 1
    }
    if start == position {
      return tag
    }
    let attribute = tag[start:position].to_string()
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() || tag[position] != '=' {
      if attribute == "checked" || attribute == "disabled" {
        result.write_string(" \{attribute}=\"\{attribute}\"")
      } else {
        return tag
      }
      continue
    }
    position += 1
    while position < tag.length() && whole_book_attribute_space(tag[position]) {
      position += 1
    }
    if position >= tag.length() ||
      (tag[position] != '\'' && tag[position] != '"') {
      return tag
    }
    let quote = tag[position]
    position += 1
    while position < tag.length() && tag[position] != quote {
      position += 1
    }
    if position >= tag.length() {
      return tag
    }
    position += 1
    result.write_string(" " + tag[start:position].to_string())
  }
  if ["img", "br", "hr", "input"].contains(name) || tag.has_suffix("/>") {
    result.write_string(" />")
  } else {
    result.write_string(">")
  }
  result.to_string()
}

///|
fn epub_chapter_document(chapter : @core.Chapter) -> @xml.Element raise {
  let body = transform_html_tags(render_chapter_body(chapter), epub_xml_tag)
  let root = @xml.parse(body) catch {
    error =>
      fail(
        "EPUB chapter \{chapter.name}: content cannot become XHTML: \{error.to_string()}",
      )
  }
  let ids : Map[String, Unit] = {}
  epub_collect_ids(root, ids)
  let title_id = slugify_heading(chapter.name)
  // Ordinary HTML removes a duplicate leading title. Keep its authored anchor.
  if !title_id.is_empty() && !ids.contains(title_id) {
    for index, node in root.children {
      if node is Element(element) && element.name == "h1" {
        root.children[index] = Element({
          ..element,
          attributes: [{ name: "id", value: title_id, }],
        })
        break
      }
    }
  }
  root
}

///|
fn epub_collect_ids(root : @xml.Element, ids : Map[String, Unit]) -> Unit raise {
  if root.attribute("id") is Some(id) {
    guard !id.is_empty() &&
      !id.iter().any(c => c == ' ' || c == '\t' || c == '\n' || c == '\r') else {
      fail("EPUB contains an empty or whitespace-bearing anchor")
    }
    guard !ids.contains(id) else {
      fail("EPUB contains duplicate anchor: \{id}")
    }
    ids[id] = ()
  }
  for child in root.child_elements() {
    epub_collect_ids(child, ids)
  }
}

///|
fn epub_xhtml(title : String, language : String, body : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\" lang=\"\{@xml.escape_attribute(language)}\" xml:lang=\"\{@xml.escape_attribute(language)}\">" +
  "<head><title>\{@xml.escape_text(title)}</title><link rel=\"stylesheet\" type=\"text/css\" href=\"book.css\" /></head><body>" +
  body +
  "</body></html>"
}

///|
fn epub_navigation(
  items : Array[@core.BookItem],
  targets : Map[String, String],
) -> String {
  let result = StringBuilder()
  for item in items {
    match item {
      Chapter(chapter) => {
        let nested = epub_navigation(chapter.sub_items, targets)
        if chapter.path is Some(path) &&
          targets.get(@pathx.normalize(path)) is Some(target) {
          result.write_string(
            "<li><a href=\"\{target}\">\{@xml.escape_text(chapter.display())}</a>",
          )
          if !nested.is_empty() {
            result.write_string("<ol>\{nested}</ol>")
          }
          result.write_string("</li>")
        } else if !nested.is_empty() {
          result.write_string(
            "<li><span>\{@xml.escape_text(chapter.name)}</span><ol>\{nested}</ol></li>",
          )
        }
      }
      PartTitle(_) => ()
      Separator => ()
    }
  }
  result.to_string()
}
