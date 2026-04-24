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
  let src_root = @path.Path(context.root)
    .join(@path.Path(context.config.book.src))
    .to_string()
  let not_found_markdown = load_not_found_markdown(src_root, context.config)
  let extra_markdown = match not_found_markdown {
    Some(markdown) => [markdown]
    None => []
  }
  let html_assets = configured_html_assets(context.config)
  copy_static_assets(
    context.root,
    src_root,
    context.build_dir,
    chapters,
    extra_markdown,
    html_assets,
  )
  write_cname(context.build_dir, context.config)
  let index_body = if chapters.is_empty() {
    let empty_text = renderer_text(
      context.config,
      "no-chapters",
      "No chapters found.",
    )
    render_shell(
      context.config,
      context_title(context.config),
      render_navigation(context.book.items, "index.html"),
      "<p>\{escape_html(empty_text)}</p>",
      render_pagelinks(context.config, None, None, "index.html"),
      render_live_reload_script(context.config),
      render_head_assets(context.config, "index.html"),
    )
  } else {
    let first = chapters[0]
    let first_href = relative_href("index.html", chapter_output_path(first))
    let open_label = renderer_text(context.config, "open-first", "Open")
    render_shell(
      context.config,
      context_title(context.config),
      render_navigation(context.book.items, "index.html"),
      "<p><a href=\"\{first_href}\">\{escape_html(open_label)} \{escape_html(first.name)}</a></p>",
      render_pagelinks(context.config, None, Some(first), "index.html"),
      render_live_reload_script(context.config),
      render_head_assets(context.config, "index.html"),
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
      context.config,
      chapter.display(),
      render_navigation(context.book.items, output_path),
      render_chapter_body(chapter),
      render_pagelinks(context.config, previous, next, output_path),
      render_live_reload_script(context.config),
      render_head_assets(context.config, output_path),
    )
    ensure_parent_dir(path.to_string())
    write_text_file(path.to_string(), page)
  }
  render_not_found_page(context, not_found_markdown)
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
async fn write_cname(build_dir : String, config : @core.Config) -> Unit {
  match config.read("output.html.cname") {
    Some(String(cname)) if !cname.is_empty() =>
      write_text_file(
        @path.Path(build_dir).join(@path.Path("CNAME")).to_string(),
        cname + "\n",
      )
    _ => ()
  }
}

///|
async fn copy_static_assets(
  book_root : String,
  src_root : String,
  build_dir : String,
  chapters : Array[@core.Chapter],
  extra_markdown : Array[String],
  html_assets : Array[String],
) -> Unit {
  let copied : Map[String, Unit] = {}
  for chapter in chapters {
    let chapter_dir = match chapter.source_path {
      Some(path) => path_dirname(path)
      None => "."
    }
    for asset in collect_markdown_assets(chapter.content) {
      if is_local_asset(asset) {
        let asset_path = strip_link_anchor(asset)
        let normalized = @pathx.normalize(
          if @pathx.is_absolute(asset_path) {
            asset_path
          } else if chapter_dir == "." {
            asset_path
          } else {
            @pathx.join(chapter_dir, asset_path)
          },
        )
        if !copied.contains(normalized) {
          let source_path = @path.Path(src_root)
            .join(@path.Path(normalized))
            .to_string()
          let dest_path = @path.Path(build_dir)
            .join(@path.Path(normalized))
            .to_string()
          ensure_parent_dir(dest_path)
          @fsx.write_bytes(
            dest_path,
            @fsx.read_bytes(source_path),
            create=0o666,
          )
          copied[normalized] = ()
        }
      }
    }
  }
  for markdown in extra_markdown {
    for asset in collect_markdown_assets(markdown) {
      if is_local_asset(asset) {
        let asset_path = strip_link_anchor(asset)
        let normalized = @pathx.normalize(asset_path)
        if !copied.contains(normalized) {
          let source_path = @path.Path(src_root)
            .join(@path.Path(normalized))
            .to_string()
          let dest_path = @path.Path(build_dir)
            .join(@path.Path(normalized))
            .to_string()
          ensure_parent_dir(dest_path)
          @fsx.write_bytes(
            dest_path,
            @fsx.read_bytes(source_path),
            create=0o666,
          )
          copied[normalized] = ()
        }
      }
    }
  }
  for asset in html_assets {
    let normalized = @pathx.normalize(asset)
    if !copied.contains(normalized) {
      let source_path = @path.Path(book_root)
        .join(@path.Path(normalized))
        .to_string()
      let dest_path = @path.Path(build_dir)
        .join(@path.Path(normalized))
        .to_string()
      ensure_parent_dir(dest_path)
      @fsx.write_bytes(dest_path, @fsx.read_bytes(source_path), create=0o666)
      copied[normalized] = ()
    }
  }
}

///|

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
  assert_true(
    html.contains(
      "<h1 id=\"intro\"><a class=\"header-link\" href=\"#intro\">Intro</a></h1>",
    ),
  )
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

///|
test "render inline handles references autolinks escapes and underscores" {
  let refs : Map[String, String] = { "link": "https://example.com/link" }
  let html = render_inline_with_refs(
    "<!--comment--> With _emphasis_ **_bold_emphasis_** \\<escaped> <span>html</span> [link] <https://example.com/>",
    refs,
  )
  assert_true(html.contains("<!--comment-->"))
  assert_true(html.contains("<em>emphasis</em>"))
  assert_true(html.contains("<strong><em>bold_emphasis</em></strong>"))
  assert_true(html.contains("&lt;escaped&gt;"))
  assert_true(html.contains("<span>html</span>"))
  assert_true(html.contains("<a href=\"https://example.com/link\">link</a>"))
  assert_true(
    html.contains("<a href=\"https://example.com/\">https://example.com/</a>"),
  )
}

///|
test "render inline preserves emoji scalars" {
  let html = render_inline("Hello 🦞 world")
  assert_true(html.contains("🦞"))
}

///|
test "inline text content handles escaped emoji" {
  let text = inline_text_content("\\🦞 [ref]", {
    "ref": "https://example.com",
  })
  assert_eq(text, "🦞 ref")
}

///|
test "render markdown handles ordered lists blockquotes and rules" {
  let html = render_markdown(
    "> quoted line\n> more quote\n\n1. first\n2. second\n\n---\n",
  )
  assert_true(
    html.contains("<blockquote><p>quoted line more quote</p></blockquote>"),
  )
  assert_true(html.contains("<ol><li>first</li><li>second</li></ol>"))
  assert_true(html.contains("<hr>"))
}

///|
test "render markdown builds heading ids from rendered inline text" {
  let (body, refs) = split_link_references(
    "## <!--comment--> With *emphasis* **bold** **_bold_emphasis_** `code` \\<escaped> <span>html</span> [link] <https://example.com/>\n\n[link]: https://example.com/link\n",
  )
  let html = render_markdown_with_refs(body, refs)
  assert_true(
    html.contains(
      "id=\"with-emphasis-bold-bold_emphasis-code-escaped-html-link-httpsexamplecom\"",
    ),
  )
  assert_true(html.contains("href=\"https://example.com/link\">link</a>"))
  assert_true(
    html.contains("<a href=\"https://example.com/\">https://example.com/</a>"),
  )
}

///|
test "render markdown handles pipe tables" {
  let html = render_markdown(
    "| Name | Value |\n| --- | --- |\n| One | 1 |\n| Two | 2 |\n",
  )
  assert_true(html.contains("<div class=\"table-wrapper\"><table>"))
  assert_true(
    html.contains("<thead><tr><th>Name</th><th>Value</th></tr></thead>"),
  )
  assert_true(
    html.contains(
      "<tbody><tr><td>One</td><td>1</td></tr><tr><td>Two</td><td>2</td></tr></tbody>",
    ),
  )
}

///|
test "render markdown applies table alignment styles" {
  let html = render_markdown(
    "| Left | Center | Right |\n| :--- | :---: | ---: |\n| a | b | c |\n",
  )
  assert_true(html.contains("<th style=\"text-align: left\">Left</th>"))
  assert_true(html.contains("<th style=\"text-align: center\">Center</th>"))
  assert_true(html.contains("<th style=\"text-align: right\">Right</th>"))
  assert_true(html.contains("<td style=\"text-align: right\">c</td>"))
}

///|
test "heading slugs preserve unicode letters" {
  let html = render_markdown("## Hï\n")
  assert_true(html.contains("id=\"hï\""))
}

///|
test "render markdown handles nested lists" {
  let html = render_markdown(
    "- parent\n  - child\n  - child 2\n1. top\n  1. nested\n",
  )
  assert_true(
    html.contains(
      "<ul><li>parent<ul><li>child</li><li>child 2</li></ul></li></ul>",
    ),
  )
  assert_true(html.contains("<ol><li>top<ol><li>nested</li></ol></li></ol>"))
}

///|
test "render inline preserves raw html and rewrites links" {
  let html = render_inline(
    "See <a href=\"chapter.md#part\">chapter</a> and <img src=\"images/pic.png\" alt=\"Pic\">",
  )
  assert_true(html.contains("<a href=\"chapter.html#part\">chapter</a>"))
  assert_true(html.contains("<img src=\"images/pic.png\" alt=\"Pic\">"))
}

///|
test "collect markdown assets includes raw html src values" {
  let assets = collect_markdown_assets(
    "<img src=\"images/pic.png\"> <a href=\"chapter.md\">chapter</a>",
  )
  assert_eq(assets, ["images/pic.png", "chapter.md"])
}

///|
test "non-file URL schemes are preserved and not treated as local assets" {
  assert_eq(
    fix_link("data:image/svg+xml;base64,abc"),
    "data:image/svg+xml;base64,abc",
  )
  assert_eq(fix_link("javascript:void(0)"), "javascript:void(0)")
  assert_eq(fix_link("tel:+86123456"), "tel:+86123456")
  assert_false(is_local_asset("data:image/svg+xml;base64,abc"))
  assert_false(is_local_asset("javascript:void(0)"))
  assert_false(is_local_asset("tel:+86123456"))
}

///|
test "split footnotes separates definitions from body" {
  let (body, footnotes) = split_footnotes("Hello[^1]\n\n[^1]: Footnote text\n")
  assert_true(body.contains("Hello[^1]"))
  assert_eq(footnotes.length(), 1)
  assert_eq(footnotes[0].0, "1")
  assert_eq(footnotes[0].1, "Footnote text")
}

///|
test "render chapter body renders footnote references and definitions" {
  let chapter = @core.chapter(
    "Chapter 1",
    "Hello[^1]\n\n[^1]: Footnote text\n",
    path=Some("chapter_1.md"),
    source_path=Some("chapter_1.md"),
  )
  let body = render_chapter_body(chapter)
  assert_true(body.contains("class=\"footnote-reference\""))
  assert_true(body.contains("id=\"footnote-1\""))
  assert_true(body.contains("Footnote text"))
  assert_true(body.contains("class=\"footnote-backref\""))
}

///|
test "parse code info splits language and modifiers" {
  let (language, modifiers) = parse_code_info("rust,ignore,editable")
  assert_eq(language, "rust")
  assert_eq(modifiers, ["ignore", "editable"])
}

///|
test "render markdown emits separate code classes for modifiers" {
  let html = render_markdown("```rust,ignore,editable\nfn main {}\n```\n")
  assert_true(
    html.contains("<button class=\"code-copy\" type=\"button\">Copy</button>"),
  )
  assert_true(
    html.contains(
      "<code class=\"language-rust ignore editable\">fn main {}</code>",
    ),
  )
}

///|
test "render markdown wraps rust playground blocks" {
  let html = render_markdown(
    "```rust,editable\nfn f() {\n    println!(\"hello\");\n}\n```\n",
  )
  assert_true(html.contains("<div class=\"code-block\">"))
  assert_true(html.contains("<pre class=\"playground\">"))
  assert_true(html.contains("class=\"language-rust editable\""))
}

///|
test "render markdown hides generic prefixed lines in code blocks" {
  let html = render_markdown(
    "```python,hidelines=!!!\n!!!hidden()\nnothidden():\n!!!    hidden()\n    !!!hidden()\n    nothidden()\n```\n",
  )
  assert_true(html.contains("<span class=\"boring\">hidden()\n</span>"))
  assert_true(html.contains("<span class=\"boring\">    hidden()\n</span>"))
  assert_true(html.contains("    nothidden()"))
}

///|
test "render markdown hides default non-rust boring lines" {
  let html = render_markdown("```python\n~hidden()\nvisible()\n```\n")
  assert_true(html.contains("<span class=\"boring\">hidden()\n</span>"))
  assert_true(html.contains("visible()"))
}

///|
test "render markdown applies rust hideline rules" {
  let html = render_markdown(
    "```rust\n#![allow(something)]\n#\n#hidden();\n# hidden();\n## not_hidden();\n#[not_hidden]\nnot_hidden();\n```\n",
  )
  assert_true(html.contains("<pre class=\"playground\">"))
  assert_true(
    html.contains("<span class=\"boring\">#![allow(something)]\n</span>"),
  )
  assert_true(html.contains("<span class=\"boring\">\n</span>"))
  assert_true(html.contains("<span class=\"boring\">hidden();\n</span>"))
  assert_true(html.contains("<span class=\"boring\">hidden();\n</span>"))
  assert_true(html.contains("# not_hidden();"))
  assert_true(html.contains("#[not_hidden]"))
  assert_true(html.contains("not_hidden();"))
}

///|
test "parse task list item detects checked and unchecked markers" {
  assert_eq(parse_task_list_item("[ ] todo"), Some((false, "todo")))
  assert_eq(parse_task_list_item("[x] done"), Some((true, "done")))
  assert_eq(parse_task_list_item("plain"), None)
}

///|
test "ordered list item parses explicit start number" {
  assert_eq(ordered_list_item("3. third"), Some((3, "third")))
}

///|
test "render markdown preserves ordered list start number" {
  let html = render_markdown("3. third\n4. fourth\n")
  assert_true(
    html.contains("<ol start=\"3\"><li>third</li><li>fourth</li></ol>"),
  )
}

///|
test "render markdown renders task list checkboxes" {
  let html = render_markdown("- [ ] todo\n- [x] done\n")
  assert_true(html.contains("<input type=\"checkbox\" disabled> todo"))
  assert_true(html.contains("<input type=\"checkbox\" checked disabled> done"))
}

///|
test "render inline handles image markdown" {
  let html = render_inline("Look ![Diagram](images/diagram.png) here")
  assert_true(html.contains("<img src=\"images/diagram.png\" alt=\"Diagram\">"))
}

///|
test "collect markdown assets finds image sources" {
  let assets = collect_markdown_assets(
    "![One](images/one.png) and ![Two](./nested/two.jpg)",
  )
  assert_eq(assets, ["images/one.png", "./nested/two.jpg"])
}

///|
test "collect markdown assets finds normal file links" {
  let assets = collect_markdown_assets(
    "[Config](downloads/openclaw-config.json) and [Archive](./downloads/package.zip#latest)",
  )
  assert_eq(assets, [
    "downloads/openclaw-config.json", "./downloads/package.zip#latest",
  ])
}

///|
test "html page links are not treated as copyable local assets" {
  assert_false(is_local_asset("./index.html"))
  assert_false(is_local_asset("guide/page.htm#top"))
  assert_true(is_local_asset("./downloads/package.zip"))
}

///|
test "404 path helpers support default custom and disabled cases" {
  let default_cfg = @core.default()
  assert_eq(not_found_input_path(default_cfg), Some("404.md"))
  assert_eq(not_found_output_path(default_cfg), Some("404.html"))
  let custom_cfg = default_cfg.set(
    "output.html.input-404",
    Json::string("not-found.md"),
  )
  assert_eq(not_found_input_path(custom_cfg), Some("not-found.md"))
  assert_eq(not_found_output_path(custom_cfg), Some("not-found.html"))
  let disabled_cfg = default_cfg.set("output.html.input-404", Json::string(""))
  assert_eq(not_found_input_path(disabled_cfg), None)
  assert_eq(not_found_output_path(disabled_cfg), None)
}

///|
test "404 head uses configured site url as base href" {
  let config = @core.default().set(
    "output.html.site-url",
    Json::string("/docs"),
  )
  let head = render_not_found_head(config)
  assert_true(head.contains("<base href=\"/docs/\">"))
}

///|
test "default 404 markdown supports ui overrides" {
  let config = @core.default()
    .set("output.html.ui.not-found-title", Json::string("未找到页面"))
    .set(
      "output.html.ui.not-found-body",
      Json::string("请返回目录继续浏览。"),
    )
  let markdown = default_not_found_markdown(config)
  assert_true(markdown.contains("# 未找到页面"))
  assert_true(markdown.contains("请返回目录继续浏览。"))
}

///|
test "configured html assets render relative head tags" {
  let config = @core.default()
    .set("output.html.additional-css", ["theme/custom.css"].to_json())
    .set("output.html.additional-js", ["scripts/book.js"].to_json())
  let head = render_head_assets(config, "guide/chapter.html")
  assert_true(head.contains("href=\"../theme/custom.css\""))
  assert_true(head.contains("src=\"../scripts/book.js\""))
}

///|
test "configured html assets are exposed for copying" {
  let config = @core.default()
    .set("output.html.additional-css", ["theme/custom.css"].to_json())
    .set("output.html.additional-js", ["scripts/book.js"].to_json())
  assert_eq(configured_html_assets(config), [
    "theme/custom.css", "scripts/book.js",
  ])
}

///|
test "renderer text falls back and supports ui overrides" {
  let config = @core.default()
    .set("output.html.ui.copy", Json::string("复制"))
    .set("output.html.ui.previous", Json::string("上一页"))
  assert_eq(renderer_text(config, "copy", "Copy"), "复制")
  assert_eq(renderer_text(config, "previous", "Previous"), "上一页")
  assert_eq(renderer_text(config, "next", "Next"), "Next")
}

///|
test "render shell supports theme color overrides" {
  let config = @core.default()
    .set("output.html.ui.theme-bg", Json::string("#111111"))
    .set("output.html.ui.theme-paper", Json::string("#222222"))
    .set("output.html.ui.theme-accent", Json::string("#ff4400"))
  let html = render_shell(config, "Title", "", "", "", "", "")
  assert_true(html.contains("--bg:#111111"))
  assert_true(html.contains("--paper:#222222"))
  assert_true(html.contains("--accent:#ff4400"))
}

///|
test "render shell supports extended chrome theme overrides" {
  let config = @core.default()
    .set("output.html.ui.theme-sidebar-bg", Json::string("#333333"))
    .set("output.html.ui.theme-code-bg", Json::string("#444444"))
    .set("output.html.ui.theme-pager-muted", Json::string("#555555"))
  let html = render_shell(config, "Title", "", "", "", "", "")
  assert_true(html.contains(".sidebar{padding:1.5rem 1rem;background:#333333"))
  assert_true(
    html.contains(".chapter pre{white-space:pre-wrap;background:#444444"),
  )
  assert_true(html.contains("color:#555555"))
}

///|
test "pagelinks use configurable labels" {
  let config = @core.default()
    .set("output.html.ui.previous", Json::string("上一页"))
    .set("output.html.ui.next", Json::string("下一页"))
  let previous = @core.chapter("One", "", path=Some("one.md"))
  let next = @core.chapter("Two", "", path=Some("two.md"))
  let html = render_pagelinks(config, Some(previous), Some(next), "index.html")
  assert_true(html.contains(">上一页: One</a>"))
  assert_true(html.contains(">下一页: Two</a>"))
}

///|
test "context title supports configurable default title" {
  let config = @core.default().set(
    "output.html.ui.default-title",
    Json::string("Docs"),
  )
  assert_eq(context_title(config), "Docs")
}

///|
test "404 head assets use normalized root-relative paths" {
  let config = @core.default()
    .set("output.html.additional-css", ["./theme/custom.css"].to_json())
    .set("output.html.additional-js", ["scripts/book.js"].to_json())
  let head = render_not_found_assets(config)
  assert_true(head.contains("href=\"theme/custom.css\""))
  assert_true(head.contains("src=\"scripts/book.js\""))
}

///|
test "render markdown adds heading ids and disambiguates duplicates" {
  let html = render_markdown("# Intro\n## Intro\n# Intro!\n")
  assert_true(
    html.contains(
      "<h1 id=\"intro\"><a class=\"header-link\" href=\"#intro\">Intro</a></h1>",
    ),
  )
  assert_true(
    html.contains(
      "<h2 id=\"intro-1\"><a class=\"header-link\" href=\"#intro-1\">Intro</a></h2>",
    ),
  )
  assert_true(
    html.contains(
      "<h1 id=\"intro-2\"><a class=\"header-link\" href=\"#intro-2\">Intro!</a></h1>",
    ),
  )
}
