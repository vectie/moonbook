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
  "<article class=\"chapter\">\{breadcrumbs}<h1>\{escape_html(chapter.display())}</h1><pre>\{escape_html(chapter.content)}</pre></article>"
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
