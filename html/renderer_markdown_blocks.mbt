///|
// Markdown block rendering, lists, tables, headings, and code blocks.

fn escape_html(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
  .to_string()
}

///|
fn render_markdown(markdown : String) -> String {
  render_markdown_with_refs(markdown, {})
}

///|
fn render_markdown_with_refs(
  markdown : String,
  references : Map[String, String],
) -> String {
  let builder = StringBuilder::new()
  let paragraph : Array[String] = []
  let list_stack : Array[(Int, Bool, Int, Array[String])] = []
  let quote_lines : Array[String] = []
  let heading_ids : Map[String, Int] = {}
  let mut pending_table_header : String? = None
  let mut table_header : (Array[String], Array[String])? = None
  let table_rows : Array[Array[String]] = []
  let mut code_lines : Array[String] = []
  let mut code_language = ""
  let mut code_modifiers : Array[String] = []
  let mut in_code_block = false

  for raw_line in markdown.split("\n") {
    let line = raw_line.to_string()
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("```") {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_lists_with_refs(builder, list_stack, references)
      flush_blockquote_with_refs(builder, quote_lines, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      if in_code_block {
        builder.write_string(
          render_code_block(code_language, code_modifiers, code_lines),
        )
        code_lines = []
        code_language = ""
        code_modifiers = []
        in_code_block = false
      } else {
        in_code_block = true
        let (language, modifiers) = parse_code_info(
          trimmed[3:].trim().to_string(),
        )
        code_language = language
        code_modifiers = modifiers
      }
      continue
    }
    if in_code_block {
      code_lines.push(line)
      continue
    }
    if table_header is Some(_) && !is_table_row(trimmed) {
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
    }
    match pending_table_header {
      Some(header) =>
        if is_table_separator(trimmed) {
          table_header = Some(
            (parse_table_row(header), parse_table_alignments(trimmed)),
          )
          pending_table_header = None
          continue
        } else {
          paragraph.push(header)
          pending_table_header = None
        }
      None => ()
    }
    if trimmed.is_empty() {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_lists_with_refs(builder, list_stack, references)
      flush_blockquote_with_refs(builder, quote_lines, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      continue
    }
    if trimmed == "---" {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_lists_with_refs(builder, list_stack, references)
      flush_blockquote_with_refs(builder, quote_lines, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      builder.write_string("<hr>")
      continue
    }
    if is_html_block(trimmed) {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_lists_with_refs(builder, list_stack, references)
      flush_blockquote_with_refs(builder, quote_lines, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      builder.write_string(rewrite_html_attributes(trimmed))
      continue
    }
    if trimmed.has_prefix("> ") {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_lists_with_refs(builder, list_stack, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      quote_lines.push(trimmed[2:].trim().to_string())
      continue
    }
    let indent = list_indent(line)
    if trimmed.has_prefix("- ") || trimmed.has_prefix("* ") {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_blockquote_with_refs(builder, quote_lines, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      push_list_item(
        list_stack,
        indent,
        false,
        1,
        trimmed[2:].trim().to_string(),
      )
      continue
    }
    match ordered_list_item(trimmed) {
      Some((start, item)) => {
        flush_paragraph_with_refs(builder, paragraph, references)
        flush_blockquote_with_refs(builder, quote_lines, references)
        table_header = flush_table_with_refs(
          builder, table_header, table_rows, references,
        )
        push_list_item(list_stack, indent, true, start, item)
        continue
      }
      None => ()
    }
    if table_header is Some(_) && is_table_row(trimmed) {
      table_rows.push(parse_table_row(trimmed))
      continue
    }
    if is_table_row(trimmed) {
      flush_paragraph_with_refs(builder, paragraph, references)
      flush_lists_with_refs(builder, list_stack, references)
      flush_blockquote_with_refs(builder, quote_lines, references)
      table_header = flush_table_with_refs(
        builder, table_header, table_rows, references,
      )
      pending_table_header = Some(trimmed)
      continue
    }
    match heading_level(trimmed) {
      Some(level) => {
        flush_paragraph_with_refs(builder, paragraph, references)
        flush_lists_with_refs(builder, list_stack, references)
        flush_blockquote_with_refs(builder, quote_lines, references)
        table_header = flush_table_with_refs(
          builder, table_header, table_rows, references,
        )
        let text = trimmed[level + 1:].trim().to_string()
        let id = unique_heading_id(
          inline_text_content(text, references),
          heading_ids,
        )
        let title = render_inline_with_refs(text, references)
        builder.write_string(
          "<h\{level} id=\"\{id}\"><a class=\"header-link\" href=\"#\{id}\">\{title}</a></h\{level}>",
        )
      }
      None => paragraph.push(trimmed)
    }
  }

  flush_paragraph_with_refs(builder, paragraph, references)
  flush_lists_with_refs(builder, list_stack, references)
  flush_blockquote_with_refs(builder, quote_lines, references)
  match pending_table_header {
    Some(header) => paragraph.push(header)
    None => ()
  }
  flush_paragraph_with_refs(builder, paragraph, references)
  ignore(flush_table_with_refs(builder, table_header, table_rows, references))
  if in_code_block {
    builder.write_string(
      render_code_block(code_language, code_modifiers, code_lines),
    )
  }
  builder.to_string()
}

///|
fn parse_code_info(info : String) -> (String, Array[String]) {
  let parts = info
    .split(",")
    .map(fn(part) { part.trim().to_string() })
    .filter(fn(part) { !part.is_empty() })
    .to_array()
  if parts.is_empty() {
    return ("", [])
  }
  let language = parts[0]
  let modifiers : Array[String] = []
  for i = 1; i < parts.length(); i = i + 1 {
    modifiers.push(parts[i])
  }
  (language, modifiers)
}

///|
fn code_class_attr(language : String, modifiers : Array[String]) -> String {
  let classes : Array[String] = []
  if !language.is_empty() {
    classes.push("language-" + language)
  }
  for modifier in modifiers {
    classes.push(modifier)
  }
  if classes.is_empty() {
    ""
  } else {
    let class_names = classes.join(" ")
    " class=\"\{escape_html(class_names)}\""
  }
}

///|
fn render_code_block(
  language : String,
  modifiers : Array[String],
  code_lines : Array[String],
) -> String {
  let class_attr = code_class_attr(language, modifiers)
  let pre_class = if should_use_playground(language, modifiers) {
    " class=\"playground\""
  } else {
    ""
  }
  let code = render_code_lines(language, modifiers, code_lines)
  "<div class=\"code-block\"><button class=\"code-copy\" type=\"button\">Copy</button><pre\{pre_class}><code\{class_attr}>\{code}</code></pre></div>"
}

///|
fn should_use_playground(language : String, modifiers : Array[String]) -> Bool {
  if language != "rust" {
    return false
  }
  for modifier in modifiers {
    if modifier == "noplayground" {
      return false
    }
  }
  true
}

///|
fn render_code_lines(
  language : String,
  modifiers : Array[String],
  code_lines : Array[String],
) -> String {
  let builder = StringBuilder::new()
  let hidden_prefix = code_hidelines_prefix(language, modifiers)
  for i = 0; i < code_lines.length(); i = i + 1 {
    let line = code_lines[i]
    let with_newline = if i + 1 < code_lines.length() {
      line + "\n"
    } else {
      line
    }
    let rendered = if language == "rust" {
      render_rust_code_line(with_newline)
    } else {
      render_prefixed_hidden_line(with_newline, hidden_prefix)
    }
    builder.write_string(rendered)
  }
  builder.to_string()
}

///|
fn code_hidelines_prefix(
  language : String,
  modifiers : Array[String],
) -> String {
  for modifier in modifiers {
    if modifier.has_prefix("hidelines=") {
      return modifier["hidelines=".length():].to_string()
    }
  }
  if language == "rust" {
    "#"
  } else {
    "~"
  }
}

///|
fn render_prefixed_hidden_line(line : String, prefix : String) -> String {
  match remove_hidden_prefix(line, prefix) {
    Some(content) => "<span class=\"boring\">\{escape_html(content)}</span>"
    None => escape_html(line)
  }
}

///|
fn remove_hidden_prefix(line : String, prefix : String) -> String? {
  if prefix.is_empty() {
    return None
  }
  let trimmed = line.trim_start().to_string()
  let indent_len = line.length() - trimmed.length()
  if trimmed.has_prefix(prefix) {
    Some(line[:indent_len].to_string() + trimmed[prefix.length():].to_string())
  } else {
    None
  }
}

///|
fn render_rust_code_line(line : String) -> String {
  let trimmed = line.trim_start().to_string()
  let indent_len = line.length() - trimmed.length()
  let indent = line[:indent_len].to_string()
  if trimmed.has_prefix("##") {
    return escape_html(indent + trimmed[1:].to_string())
  }
  if trimmed.has_prefix("#[") {
    return escape_html(line)
  }
  if trimmed == "#" ||
    trimmed.has_prefix("# ") ||
    trimmed.has_prefix("#!") ||
    (trimmed.has_prefix("#") && !trimmed.has_prefix("##")) {
    let content = if trimmed == "#" {
      indent
    } else if trimmed.has_prefix("#!") {
      indent + trimmed
    } else if trimmed.has_prefix("# ") {
      indent + trimmed[2:].to_string()
    } else if trimmed.has_prefix("#[") {
      line
    } else {
      indent + trimmed[1:].to_string()
    }
    return "<span class=\"boring\">\{escape_html(content)}</span>"
  }
  escape_html(line)
}

///|
fn strip_duplicate_leading_title(
  markdown : String,
  chapter : @core.Chapter,
) -> String {
  let lines = markdown.split("\n").map(fn(line) { line.to_string() }).to_array()
  if lines.is_empty() {
    return markdown
  }
  let mut first_content = 0
  while first_content < lines.length() && lines[first_content].trim().is_empty() {
    first_content += 1
  }
  if first_content >= lines.length() {
    return markdown
  }
  let trimmed = lines[first_content].trim().to_string()
  match heading_level(trimmed) {
    Some(level) => {
      let title = trimmed[level + 1:].trim().to_string()
      if title == chapter.name || title == chapter.display() {
        lines[first_content + 1:].join("\n")
      } else {
        markdown
      }
    }
    None => markdown
  }
}

///|
fn heading_level(line : String) -> Int? {
  let mut level = 0
  for c in line {
    if c == '#' {
      level += 1
    } else {
      break
    }
  }
  if level > 0 && level <= 6 && line.length() > level && line[level] == ' ' {
    Some(level)
  } else {
    None
  }
}

///|
fn flush_paragraph_with_refs(
  builder : StringBuilder,
  paragraph : Array[String],
  references : Map[String, String],
) -> Unit {
  if paragraph.is_empty() {
    return
  }
  let text = paragraph.join(" ")
  builder.write_string("<p>\{render_inline_with_refs(text, references)}</p>")
  paragraph.clear()
}

///|
fn push_list_item(
  list_stack : Array[(Int, Bool, Int, Array[String])],
  indent : Int,
  ordered : Bool,
  start : Int,
  item : String,
) -> Unit {
  match list_stack.last() {
    Some((last_indent, last_ordered, last_start, items)) =>
      if last_indent == indent && last_ordered == ordered {
        items.push(item)
        list_stack[list_stack.length() - 1] = (
          last_indent, last_ordered, last_start, items,
        )
      } else {
        list_stack.push((indent, ordered, start, [item]))
      }
    None => list_stack.push((indent, ordered, start, [item]))
  }
}

///|
fn flush_lists_with_refs(
  builder : StringBuilder,
  list_stack : Array[(Int, Bool, Int, Array[String])],
  references : Map[String, String],
) -> Unit {
  if list_stack.is_empty() {
    return
  }
  let mut index = 0
  while index < list_stack.length() {
    index = render_list_group(builder, list_stack, index, references)
  }
  list_stack.clear()
}

///|
fn render_list_group(
  builder : StringBuilder,
  list_stack : Array[(Int, Bool, Int, Array[String])],
  start : Int,
  references : Map[String, String],
) -> Int {
  let entry = list_stack[start]
  let indent = entry.0
  let ordered = entry.1
  let list_start = entry.2
  let items = entry.3
  let open_tag = if ordered && list_start != 1 {
    "<ol start=\"\{list_start}\">"
  } else if ordered {
    "<ol>"
  } else {
    "<ul>"
  }
  let close_tag = if ordered { "</ol>" } else { "</ul>" }
  builder.write_string(open_tag)
  let mut next_index = start + 1
  for i = 0; i < items.length(); i = i + 1 {
    builder.write_string(
      "<li>\{render_list_item_with_refs(items[i], references)}",
    )
    if i == items.length() - 1 &&
      next_index < list_stack.length() &&
      list_stack[next_index].0 > indent {
      next_index = render_list_group(
        builder, list_stack, next_index, references,
      )
    }
    builder.write_string("</li>")
  }
  builder.write_string(close_tag)
  next_index
}

///|
fn render_list_item_with_refs(
  item : String,
  references : Map[String, String],
) -> String {
  match parse_task_list_item(item) {
    Some((checked, text)) => {
      let marker = if checked {
        "<input type=\"checkbox\" checked disabled> "
      } else {
        "<input type=\"checkbox\" disabled> "
      }
      marker + render_inline_with_refs(text, references)
    }
    None => render_inline_with_refs(item, references)
  }
}

///|
fn parse_task_list_item(item : String) -> (Bool, String)? {
  if item.has_prefix("[ ] ") {
    Some((false, item[4:].to_string()))
  } else if item.has_prefix("[x] ") || item.has_prefix("[X] ") {
    Some((true, item[4:].to_string()))
  } else {
    None
  }
}

///|
fn flush_blockquote_with_refs(
  builder : StringBuilder,
  quote_lines : Array[String],
  references : Map[String, String],
) -> Unit {
  if quote_lines.is_empty() {
    return
  }
  let text = quote_lines.join(" ")
  builder.write_string(
    "<blockquote><p>\{render_inline_with_refs(text, references)}</p></blockquote>",
  )
  quote_lines.clear()
}

///|
fn flush_table_with_refs(
  builder : StringBuilder,
  table_header : (Array[String], Array[String])?,
  table_rows : Array[Array[String]],
  references : Map[String, String],
) -> (Array[String], Array[String])? {
  match table_header {
    Some((header, alignments)) => {
      builder.write_string("<div class=\"table-wrapper\"><table><thead><tr>")
      for i = 0; i < header.length(); i = i + 1 {
        let style = table_cell_style(alignments, i)
        builder.write_string(
          "<th\{style}>\{render_inline_with_refs(header[i], references)}</th>",
        )
      }
      builder.write_string("</tr></thead><tbody>")
      for row in table_rows {
        builder.write_string("<tr>")
        for i = 0; i < row.length(); i = i + 1 {
          let style = table_cell_style(alignments, i)
          builder.write_string(
            "<td\{style}>\{render_inline_with_refs(row[i], references)}</td>",
          )
        }
        builder.write_string("</tr>")
      }
      builder.write_string("</tbody></table></div>")
      table_rows.clear()
      None
    }
    None => None
  }
}

///|
fn table_cell_style(alignments : Array[String], index : Int) -> String {
  if index >= alignments.length() || alignments[index].is_empty() {
    ""
  } else {
    " style=\"text-align: \{alignments[index]}\""
  }
}

///|
fn is_table_row(line : String) -> Bool {
  line.contains("|") && !line.has_prefix("|-")
}

///|
fn is_table_separator(line : String) -> Bool {
  let pieces = parse_table_row(line)
  if pieces.is_empty() {
    return false
  }
  for piece in pieces {
    let trimmed = piece.trim().to_string()
    if trimmed.is_empty() {
      return false
    }
    for c in trimmed {
      if c != '-' && c != ':' {
        return false
      }
    }
  }
  true
}

///|
fn parse_table_row(line : String) -> Array[String] {
  line
  .split("|")
  .map(fn(piece) { piece.trim().to_string() })
  .filter(fn(piece) { !piece.is_empty() })
  .to_array()
}

///|
fn parse_table_alignments(line : String) -> Array[String] {
  parse_table_row(line).map(parse_alignment_piece)
}

///|
fn parse_alignment_piece(piece : String) -> String {
  let trimmed = piece.trim().to_string()
  let left = trimmed.has_prefix(":")
  let right = trimmed.has_suffix(":")
  if left && right {
    "center"
  } else if right {
    "right"
  } else if left {
    "left"
  } else {
    ""
  }
}

///|
fn ordered_list_item(line : String) -> (Int, String)? {
  let mut dot_index : Int? = None
  let mut number = 0
  for i = 0; i < line.length(); i = i + 1 {
    let c = line[i]
    if c == '.' {
      dot_index = Some(i)
      break
    }
    if c < '0' || c > '9' {
      return None
    }
    number = number * 10 + (c.to_int() - '0'.to_int())
  }
  match dot_index {
    Some(index) =>
      if index + 1 < line.length() && line[index + 1] == ' ' {
        Some((number, line[index + 2:].trim().to_string()))
      } else {
        None
      }
    None => None
  }
}

///|
fn list_indent(line : String) -> Int {
  let mut spaces = 0
  for c in line {
    if c == ' ' {
      spaces += 1
    } else {
      break
    }
  }
  spaces / 2
}

///|
fn unique_heading_id(text : String, ids : Map[String, Int]) -> String {
  let base = slugify_heading(text)
  let count = ids.get(base).unwrap_or(0)
  ids[base] = count + 1
  if count == 0 {
    base
  } else {
    base + "-" + count.to_string()
  }
}

///|
fn slugify_heading(text : String) -> String {
  let builder = StringBuilder::new()
  let mut previous_dash = false
  for c in text.to_lower() {
    let normalized = if (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c.to_int() > 127 {
      Some(c)
    } else if c == ' ' || c == '-' || c == '_' {
      Some('-')
    } else {
      None
    }
    match normalized {
      Some('-') =>
        if !previous_dash && builder.to_string() != "" {
          builder.write_char('-')
          previous_dash = true
        }
      Some(ch) => {
        builder.write_char(ch)
        previous_dash = false
      }
      None => ()
    }
  }
  let slug = builder.to_string()
  if slug.is_empty() {
    ""
  } else if slug[slug.length() - 1] == '-' {
    slug[:slug.length() - 1].to_string()
  } else {
    slug
  }
}
