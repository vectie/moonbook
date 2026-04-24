///|
// Markdown asset discovery, HTML attribute rewriting, references, and footnotes.

fn collect_markdown_assets(markdown : String) -> Array[String] {
  let assets : Array[String] = []
  let mut i = 0
  while i < markdown.length() {
    if markdown[i] == '!' && markdown[i + 1] == '[' {
      match markdown[i + 2:].find("](") {
        Some(mid) => {
          let close_index = i + 2 + mid
          match markdown[close_index + 2:].find(")") {
            Some(end) => {
              assets.push(
                markdown[close_index + 2:close_index + 2 + end].to_string(),
              )
              i = close_index + end + 3
            }
            None => i += 1
          }
        }
        None => i += 1
      }
    } else if markdown[i] == '[' {
      match markdown[i + 1:].find("](") {
        Some(mid) => {
          let close_index = i + 1 + mid
          match markdown[close_index + 2:].find(")") {
            Some(end) => {
              assets.push(
                markdown[close_index + 2:close_index + 2 + end].to_string(),
              )
              i = close_index + end + 3
            }
            None => i += 1
          }
        }
        None => i += 1
      }
    } else {
      i += 1
    }
  }
  for attr in ["src", "href"] {
    for value in collect_html_attribute_values(markdown, attr) {
      assets.push(value)
    }
  }
  assets
}

///|
fn is_html_block(line : String) -> Bool {
  line.has_prefix("<") && line.has_suffix(">")
}

///|
fn rewrite_html_attributes(html : String) -> String {
  let mut rewritten = html
  for attr in ["href", "src"] {
    for value in collect_html_attribute_values(rewritten, attr) {
      let fixed = fix_link(value)
      rewritten = rewritten
        .replace(
          old="\{attr}=\"\{value}\"",
          new="\{attr}=\"\{escape_html(fixed)}\"",
        )
        .to_string()
    }
  }
  rewritten
}

///|
fn collect_html_attribute_values(html : String, attr : String) -> Array[String] {
  let values : Array[String] = []
  let pattern = attr + "=\""
  let mut start = 0
  while start < html.length() {
    match html[start:].find(pattern) {
      Some(offset) => {
        let value_start = start + offset + pattern.length()
        match html[value_start:].find("\"") {
          Some(end) => {
            values.push(html[value_start:value_start + end].to_string())
            start = value_start + end + 1
          }
          None => break
        }
      }
      None => break
    }
  }
  values
}

///|
fn split_link_references(markdown : String) -> (String, Map[String, String]) {
  let body : Array[String] = []
  let references : Map[String, String] = {}
  for raw_line in markdown.split("\n") {
    let line = raw_line.to_string()
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("[") {
      match trimmed.find("]:") {
        Some(index) =>
          if index > 1 && trimmed[1] != '^' {
            let name = trimmed[1:index].trim().to_lower().to_string()
            let value = trimmed[index + 2:].trim().to_string()
            if !name.is_empty() && !value.is_empty() {
              references[name] = value
            } else {
              body.push(line)
            }
          } else {
            body.push(line)
          }
        None => body.push(line)
      }
    } else {
      body.push(line)
    }
  }
  (body.join("\n"), references)
}

///|
fn split_footnotes(markdown : String) -> (String, Array[(String, String)]) {
  let body : Array[String] = []
  let footnotes : Array[(String, String)] = []
  for raw_line in markdown.split("\n") {
    let line = raw_line.to_string()
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("[^") {
      match trimmed.find("]:") {
        Some(index) => {
          let name = trimmed[2:index].to_string()
          let content = trimmed[index + 2:].trim().to_string()
          footnotes.push((name, content))
        }
        None => body.push(line)
      }
    } else {
      body.push(line)
    }
  }
  (body.join("\n"), footnotes)
}

///|
fn render_footnotes(
  footnotes : Array[(String, String)],
  references : Map[String, String],
) -> String {
  if footnotes.is_empty() {
    return ""
  }
  let builder = StringBuilder::new()
  builder.write_string(
    "<section class=\"footnotes\"><hr><ol class=\"footnote-definition\">",
  )
  for footnote in footnotes {
    let name = footnote.0
    let content = footnote.1
    let id = slugify_heading(name)
    let rendered = render_markdown_with_refs(content, references)
    let backref = "<a href=\"#fr-\{id}\" class=\"footnote-backref\">↩</a>"
    builder.write_string("<li id=\"footnote-\{id}\">\{rendered}\{backref}</li>")
  }
  builder.write_string("</ol></section>")
  builder.to_string()
}
