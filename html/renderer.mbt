///|
pub struct RenderContext {
  root : String
  build_dir : String
  config : @core.Config
  book : @core.Book
} derive(Show, ToJson)

///|
pub fn new_render_context(
  root : String,
  build_dir : String,
  config : @core.Config,
  book : @core.Book,
) -> RenderContext {
  { root, build_dir, config, book }
}

///|
pub async fn render_html(context : RenderContext) -> Unit {
  ensure_dir(context.build_dir)
  let chapters = context.book.chapters()
  let index_body = if chapters.is_empty() {
    render_shell(
      context_title(context.config),
      render_navigation(context.book.items, "index.html"),
      "<p>No chapters found.</p>",
      render_pagelinks(None, None, "index.html"),
    )
  } else {
    let first = chapters[0]
    let first_href = relative_href("index.html", chapter_output_path(first))
    render_shell(
      context_title(context.config),
      render_navigation(context.book.items, "index.html"),
      "<p><a href=\"\{first_href}\">Open \{escape_html(first.name)}</a></p>",
      render_pagelinks(None, Some(first), "index.html"),
    )
  }
  write_text_file(
    @path.Path(context.build_dir).join(@path.Path("index.html")).to_string(),
    index_body,
  )
  for chapter in chapters {
    let output_path = chapter_output_path(chapter)
    let path = @path.Path(context.build_dir).join(@path.Path(output_path))
    let (previous, next) = previous_next_chapters(chapters, output_path)
    let page = render_shell(
      chapter.display(),
      render_navigation(context.book.items, output_path),
      render_chapter_body(chapter),
      render_pagelinks(previous, next, output_path),
    )
    ensure_parent_dir(path.to_string())
    write_text_file(path.to_string(), page)
  }
}

///|
async fn ensure_dir(path : String) -> Unit {
  if @fsx.exists(path) {
    return
  }
  @fsx.make_directory(path, recursive=true, exists_ok=true)
}

///|
async fn ensure_parent_dir(path : String) -> Unit {
  let parent = @pathx.dirname(path).to_string()
  if parent != "." && parent != path {
    ensure_dir(parent)
  }
}

///|
async fn write_text_file(path : String, content : String) -> Unit {
  @fsx.write_to_file(path, content, create=0o666)
}

///|
fn context_title(config : @core.Config) -> String {
  config.book.title.unwrap_or("MoonBook")
}

///|
fn chapter_output_path(chapter : @core.Chapter) -> String {
  match chapter.path {
    Some(path) =>
      @path.Path(path)
      .normalize()
      .to_string()
      .replace(old=".md", new=".html")
      .to_string()
    None => "draft.html"
  }
}

///|
fn render_navigation(
  items : Array[@core.BookItem],
  current_page : String,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("<nav class=\"sidebar\"><ol class=\"toc\">")
  render_navigation_items(builder, items, current_page)
  builder.write_string("</ol></nav>")
  builder.to_string()
}

///|
fn render_navigation_items(
  builder : StringBuilder,
  items : Array[@core.BookItem],
  current_page : String,
) -> Unit {
  for item in items {
    match item {
      Chapter(chapter) => {
        let href = relative_href(current_page, chapter_output_path(chapter))
        let current = if chapter_output_path(chapter) == current_page {
          " aria-current=\"page\" class=\"current\""
        } else {
          ""
        }
        builder.write_string("<li class=\"chapter-item\">")
        builder.write_string(
          "<a href=\"\{href}\"\{current}>\{escape_html(chapter.display())}</a>",
        )
        if !chapter.sub_items.is_empty() {
          builder.write_string("<ol>")
          render_navigation_items(builder, chapter.sub_items, current_page)
          builder.write_string("</ol>")
        }
        builder.write_string("</li>")
      }
      Separator => builder.write_string("<li class=\"separator\"><hr></li>")
      PartTitle(title) =>
        builder.write_string(
          "<li class=\"part-title\">\{escape_html(title)}</li>",
        )
    }
  }
}

///|
fn render_shell(
  title : String,
  navigation : String,
  body : String,
  pagelinks : String,
) -> String {
  "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\{escape_html(title)}</title><style>:root{--bg:#f6f1e8;--paper:#fffaf2;--ink:#2f241c;--accent:#8a2d0a;--line:#dfd2bf}*{box-sizing:border-box}body{font-family:Georgia,Cambria,\"Times New Roman\",serif;color:var(--ink);margin:0;display:grid;grid-template-columns:18rem 1fr;min-height:100vh;background:linear-gradient(180deg,#f3ecdf 0%,#fbf7f0 100%)}.sidebar{padding:2rem 1.25rem;background:#efe4d2;border-right:1px solid var(--line)}.toc,.toc ol{margin:0;padding-left:1.1rem}.toc{padding-left:0;list-style:none}.toc ol{list-style:none}.chapter-item,.part-title,.separator{margin:.35rem 0}.part-title{margin-top:1rem;font-size:.78rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#6a5747}.separator hr{border:none;border-top:1px solid var(--line)}.sidebar a{text-decoration:none;color:var(--ink)}.sidebar a.current{color:var(--accent);font-weight:700}.content{padding:2.5rem;max-width:56rem}.chapter{background:var(--paper);border:1px solid var(--line);border-radius:18px;padding:2rem;box-shadow:0 12px 40px rgba(73,49,24,.06)}.chapter h1{margin-top:0}.chapter pre{white-space:pre-wrap;background:#fff3e2;padding:1rem;border-radius:12px;overflow:auto}.pagelinks{display:flex;justify-content:space-between;gap:1rem;margin:0 0 1.5rem}.pagelinks a{text-decoration:none;color:var(--accent);font-weight:600}.pagelinks span{color:#8d7c6f}@media (max-width:900px){body{grid-template-columns:1fr}.sidebar{border-right:none;border-bottom:1px solid var(--line)}.content{padding:1rem}}</style></head><body>\{navigation}<main class=\"content\">\{pagelinks}\{body}</main></body></html>"
}

///|
fn render_chapter_body(chapter : @core.Chapter) -> String {
  let trail = chapter.parent_names.join(" > ")
  let breadcrumbs = if chapter.parent_names.is_empty() {
    ""
  } else {
    "<p class=\"breadcrumbs\">\{escape_html(trail)}</p>"
  }
  let content = render_markdown(
    strip_duplicate_leading_title(chapter.content, chapter),
  )
  "<article class=\"chapter\">\{breadcrumbs}<h1>\{escape_html(chapter.display())}</h1>\{content}</article>"
}

///|
fn render_pagelinks(
  previous : @core.Chapter?,
  next : @core.Chapter?,
  current_page : String,
) -> String {
  let prev = match previous {
    Some(chapter) =>
      "<a class=\"previous\" href=\"\{relative_href(current_page, chapter_output_path(chapter))}\">Previous: \{escape_html(chapter.name)}</a>"
    None => "<span></span>"
  }
  let nxt = match next {
    Some(chapter) =>
      "<a class=\"next\" href=\"\{relative_href(current_page, chapter_output_path(chapter))}\">Next: \{escape_html(chapter.name)}</a>"
    None => "<span></span>"
  }
  "<nav class=\"pagelinks\">\{prev}\{nxt}</nav>"
}

///|
fn previous_next_chapters(
  chapters : Array[@core.Chapter],
  current_path : String,
) -> (@core.Chapter?, @core.Chapter?) {
  for i = 0; i < chapters.length(); i = i + 1 {
    if chapter_output_path(chapters[i]) == current_path {
      let previous = if i > 0 { Some(chapters[i - 1]) } else { None }
      let next = if i + 1 < chapters.length() {
        Some(chapters[i + 1])
      } else {
        None
      }
      return (previous, next)
    }
  }
  (None, None)
}

///|
fn relative_href(from_path : String, to_path : String) -> String {
  let from_parts = split_path_segments(path_dirname(from_path))
  let to_parts = split_path_segments(@pathx.normalize(to_path))
  let mut common = 0
  while common < from_parts.length() &&
        common < to_parts.length() &&
        from_parts[common] == to_parts[common] {
    common += 1
  }
  let builder : Array[String] = []
  for _ in common..<from_parts.length() {
    builder.push("..")
  }
  for i in common..<to_parts.length() {
    builder.push(to_parts[i])
  }
  if builder.is_empty() {
    "."
  } else {
    builder.join("/")
  }
}

///|
fn path_dirname(path : String) -> String {
  let normalized = @pathx.normalize(path)
  match normalized.rev_find("/") {
    Some(index) => normalized[:index].to_string()
    None => "."
  }
}

///|
fn split_path_segments(path : String) -> Array[String] {
  let normalized = @pathx.normalize(path)
  if normalized == "." || normalized.is_empty() {
    []
  } else {
    normalized
    .split("/")
    .filter(fn(segment) { !segment.is_empty() && segment != "." })
    .map(fn(segment) { segment.to_string() })
    .to_array()
  }
}

///|
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
  let builder = StringBuilder::new()
  let paragraph : Array[String] = []
  let list_items : Array[String] = []
  let mut code_lines : Array[String] = []
  let mut code_language = ""
  let mut in_code_block = false

  for raw_line in markdown.split("\n") {
    let line = raw_line.to_string()
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("```") {
      flush_paragraph(builder, paragraph)
      flush_list(builder, list_items)
      if in_code_block {
        let code = escape_html(code_lines.join("\n"))
        let class_attr = if code_language.is_empty() {
          ""
        } else {
          " class=\"language-\{escape_html(code_language)}\""
        }
        builder.write_string("<pre><code\{class_attr}>\{code}</code></pre>")
        code_lines = []
        code_language = ""
        in_code_block = false
      } else {
        in_code_block = true
        code_language = trimmed[3:].trim().to_string()
      }
      continue
    }
    if in_code_block {
      code_lines.push(line)
      continue
    }
    if trimmed.is_empty() {
      flush_paragraph(builder, paragraph)
      flush_list(builder, list_items)
      continue
    }
    if trimmed.has_prefix("- ") || trimmed.has_prefix("* ") {
      flush_paragraph(builder, paragraph)
      list_items.push(trimmed[2:].trim().to_string())
      continue
    }
    match heading_level(trimmed) {
      Some(level) => {
        flush_paragraph(builder, paragraph)
        flush_list(builder, list_items)
        let text = trimmed[level + 1:].trim().to_string()
        builder.write_string("<h\{level}>\{render_inline(text)}</h\{level}>")
      }
      None => paragraph.push(trimmed)
    }
  }

  flush_paragraph(builder, paragraph)
  flush_list(builder, list_items)
  if in_code_block {
    let code = escape_html(code_lines.join("\n"))
    let class_attr = if code_language.is_empty() {
      ""
    } else {
      " class=\"language-\{escape_html(code_language)}\""
    }
    builder.write_string("<pre><code\{class_attr}>\{code}</code></pre>")
  }
  builder.to_string()
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
fn flush_paragraph(builder : StringBuilder, paragraph : Array[String]) -> Unit {
  if paragraph.is_empty() {
    return
  }
  let text = paragraph.join(" ")
  builder.write_string("<p>\{render_inline(text)}</p>")
  paragraph.clear()
}

///|
fn flush_list(builder : StringBuilder, list_items : Array[String]) -> Unit {
  if list_items.is_empty() {
    return
  }
  builder.write_string("<ul>")
  for item in list_items {
    builder.write_string("<li>\{render_inline(item)}</li>")
  }
  builder.write_string("</ul>")
  list_items.clear()
}

///|
fn render_inline(text : String) -> String {
  let builder = StringBuilder::new()
  let mut i = 0
  while i < text.length() {
    if text[i] == '`' {
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
          builder.write_string("<strong>\{render_inline(content)}</strong>")
          i = i + end + 4
        }
        None => {
          builder.write_string("**")
          i += 2
        }
      }
    } else if text[i] == '*' {
      match text[i + 1:].find("*") {
        Some(end) => {
          let content = text[i + 1:i + 1 + end].to_string()
          builder.write_string("<em>\{render_inline(content)}</em>")
          i = i + end + 2
        }
        None => {
          builder.write_string("*")
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
                "<a href=\"\{escape_html(fixed_href)}\">\{render_inline(label)}</a>",
              )
              i = close_index + end + 3
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
    } else {
      builder.write_string(escape_html(text[i:i + 1].to_string()))
      i += 1
    }
  }
  builder.to_string()
}

///|
fn fix_link(link : String) -> String {
  if link.has_prefix("#") || link.contains("://") || link.has_prefix("mailto:") {
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
fn fix_link_path(path : String) -> String {
  if path.has_suffix(".md") {
    path[:path.length() - 3].to_string() + ".html"
  } else {
    path
  }
}

///|
test "relative href handles nested chapter paths" {
  assert_eq(relative_href("index.html", "guide/index.html"), "guide/index.html")
  assert_eq(
    relative_href("guide/index.html", "chapter_1.html"),
    "../chapter_1.html",
  )
  assert_eq(
    relative_href("guide/intro.html", "guide/deep/topic.html"),
    "deep/topic.html",
  )
}

///|
test "navigation preserves parts separators and nesting" {
  let book = @core.new_with_items([
    @core.item_part_title("Part One"),
    @core.item_chapter(
      @core.chapter(
        "Intro",
        "# Intro",
        number=Some(@core.SectionNumber::new([1])),
        sub_items=[
          @core.item_chapter(
            @core.chapter(
              "Nested",
              "# Nested",
              number=Some(@core.SectionNumber::new([1, 1])),
              path=Some("guide/nested.md"),
              source_path=Some("guide/nested.md"),
              parent_names=["Intro"],
            ),
          ),
          @core.item_separator(),
        ],
        path=Some("intro.md"),
        source_path=Some("intro.md"),
      ),
    ),
  ])
  let nav = render_navigation(book.items, "intro.html")
  assert_true(nav.contains("Part One"))
  assert_true(nav.contains("guide/nested.html"))
  assert_true(nav.contains("<hr>"))
  assert_true(nav.contains("aria-current=\"page\""))
}

///|
test "render markdown handles paragraphs headings lists and code blocks" {
  let html = render_markdown(
    "# Intro\n\nHello world\nacross lines\n\n- one\n- two\n\n```rust\nfn main {}\n```\n",
  )
  assert_true(html.contains("<h1>Intro</h1>"))
  assert_true(html.contains("<p>Hello world across lines</p>"))
  assert_true(html.contains("<ul><li>one</li><li>two</li></ul>"))
  assert_true(html.contains("<code class=\"language-rust\">fn main {}</code>"))
}

///|
test "chapter body strips duplicate leading title" {
  let chapter = @core.chapter(
    "Chapter 1",
    "# Chapter 1\n\nHello\n",
    number=Some(@core.SectionNumber::new([1])),
    path=Some("chapter_1.md"),
    source_path=Some("chapter_1.md"),
  )
  let body = render_chapter_body(chapter)
  assert_eq(body.split("<h1>").to_array().length(), 2)
  assert_true(body.contains("<p>Hello</p>"))
}

///|
test "render inline handles emphasis code and links" {
  let html = render_inline(
    "A *small* **strong** `code` [chapter](guide.md#intro) and [site](https://example.com)",
  )
  assert_true(html.contains("<em>small</em>"))
  assert_true(html.contains("<strong>strong</strong>"))
  assert_true(html.contains("<code>code</code>"))
  assert_true(html.contains("<a href=\"guide.html#intro\">chapter</a>"))
  assert_true(html.contains("<a href=\"https://example.com\">site</a>"))
}
