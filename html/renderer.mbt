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
          @fsx.write_to_file(
            dest_path,
            @fsx.read_file(source_path),
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
          @fsx.write_to_file(
            dest_path,
            @fsx.read_file(source_path),
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
      @fsx.write_to_file(dest_path, @fsx.read_file(source_path), create=0o666)
      copied[normalized] = ()
    }
  }
}

///|
fn context_title(config : @core.Config) -> String {
  config.book.title.unwrap_or(renderer_text(config, "default-title", "Book"))
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
  config : @core.Config,
  title : String,
  navigation : String,
  body : String,
  pagelinks : String,
  live_reload_script : String,
  head_extra : String,
) -> String {
  let copy_label = escape_html(renderer_text(config, "copy", "Copy"))
  let copied_label = escape_html(renderer_text(config, "copied", "Copied"))
  let failed_label = escape_html(renderer_text(config, "copy-failed", "Failed"))
  let bg = escape_html(renderer_text(config, "theme-bg", "#ffffff"))
  let paper = escape_html(renderer_text(config, "theme-paper", "#ffffff"))
  let ink = escape_html(renderer_text(config, "theme-ink", "#1f2328"))
  let accent = escape_html(renderer_text(config, "theme-accent", "#0969da"))
  let line = escape_html(renderer_text(config, "theme-line", "#d0d7de"))
  let bg_start = escape_html(renderer_text(config, "theme-bg-start", "#ffffff"))
  let bg_end = escape_html(renderer_text(config, "theme-bg-end", "#ffffff"))
  let sidebar_bg = escape_html(renderer_text(config, "theme-sidebar-bg", "#f6f8fa"))
  let muted = escape_html(renderer_text(config, "theme-muted", "#656d76"))
  let code_bg = escape_html(renderer_text(config, "theme-code-bg", "#f6f8fa"))
  let copy_bg = escape_html(
    renderer_text(config, "theme-copy-button-bg", "#f6f8fa"),
  )
  let copy_hover_bg = escape_html(renderer_text(config, "theme-copy-hover-bg", "#eef2f6"))
  let copy_active_bg = escape_html(
    renderer_text(config, "theme-copy-active-bg", "#e7edf3"),
  )
  let copy_active_ink = escape_html(
    renderer_text(config, "theme-copy-active-ink", "#1f2328"),
  )
  let copy_shadow = escape_html(
    renderer_text(config, "theme-shadow-copy", "rgba(31,35,40,.04)"),
  )
  let image_shadow = escape_html(
    renderer_text(config, "theme-shadow-image", "rgba(31,35,40,.08)"),
  )
  let pager_muted = escape_html(renderer_text(config, "theme-pager-muted", "#656d76"))
  "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\{escape_html(title)}</title>\{head_extra}<style>:root{--bg:\{bg};--paper:\{paper};--ink:\{ink};--accent:\{accent};--line:\{line}}*{box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",\"Noto Sans\",Helvetica,Arial,sans-serif,\"Apple Color Emoji\",\"Segoe UI Emoji\";font-size:16px;line-height:1.5;color:var(--ink);margin:0;display:grid;grid-template-columns:16rem minmax(0,1fr);min-height:100vh;background:linear-gradient(180deg,\{bg_start} 0%,\{bg_end} 100%)}.sidebar{padding:1.5rem 1rem;background:\{sidebar_bg};border-right:1px solid var(--line);overflow:auto}.toc,.toc ol{margin:0;padding-left:1.25rem}.toc{padding-left:0;list-style:none}.toc ol{list-style:none}.chapter-item,.part-title,.separator{margin:.35rem 0}.part-title{margin-top:1rem;font-size:.75rem;font-weight:600;letter-spacing:.02em;text-transform:uppercase;color:\{muted}}.separator hr{border:none;border-top:1px solid var(--line)}.sidebar a{text-decoration:none;color:var(--ink)}.sidebar a:hover{text-decoration:underline}.sidebar a.current{color:var(--accent);font-weight:600}.content{padding:0;min-width:0}.chapter{box-sizing:border-box;min-width:200px;max-width:980px;margin:0 auto;background:var(--paper);padding:45px;overflow:hidden}.chapter h1,.chapter h2{padding-bottom:.3em;border-bottom:1px solid #d8dee4}.chapter h1{margin:0 0 16px;font-size:2em}.chapter h2{margin:24px 0 16px;font-size:1.5em}.chapter h3{margin:24px 0 16px;font-size:1.25em}.chapter h4,.chapter h5,.chapter h6{margin:24px 0 16px}.chapter p,.chapter li,.chapter blockquote{line-height:1.75}.chapter ul,.chapter ol{padding-left:2em}.chapter blockquote{margin:0 0 16px;padding:0 1em;color:\{muted};border-left:.25em solid var(--line)}.chapter hr{height:.25em;padding:0;margin:24px 0;background-color:#d8dee4;border:0}.code-block{position:relative;margin:16px 0}.chapter pre{white-space:pre-wrap;background:\{code_bg};padding:16px;border-radius:6px;overflow:auto;max-width:100%;margin:0;border:1px solid var(--line);font:12px/1.45 ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace}.chapter code{overflow-wrap:anywhere;font-family:ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace}.chapter :not(pre)>code{padding:.2em .4em;margin:0;font-size:85%;background:rgba(175,184,193,.2);border-radius:6px}.code-copy{position:absolute;top:.65rem;right:.65rem;border:1px solid var(--line);background:\{copy_bg};color:var(--ink);border-radius:6px;padding:.3rem .65rem;font:600 12px/1.2 -apple-system,BlinkMacSystemFont,\"Segoe UI\",\"Noto Sans\",Helvetica,Arial,sans-serif;cursor:pointer;box-shadow:0 1px 0 \{copy_shadow}}.code-copy:hover{background:\{copy_hover_bg}}.code-copy[data-copied=\"true\"]{background:\{copy_active_bg};color:\{copy_active_ink}}.chapter img{display:block;max-width:100%;width:auto;height:auto;margin:1rem auto;border-radius:6px;box-shadow:0 1px 3px \{image_shadow}}.chapter table{display:block;width:max-content;max-width:100%;overflow:auto;border-spacing:0;border-collapse:collapse}.chapter th,.chapter td{padding:6px 13px;border:1px solid var(--line)}.chapter tr:nth-child(2n){background:#f6f8fa}.chapter a{color:var(--accent);text-decoration:none}.chapter a:hover{text-decoration:underline}.pagelinks{display:flex;justify-content:space-between;gap:1rem;box-sizing:border-box;max-width:980px;margin:0 auto;padding:24px 45px 0}.pagelinks a{text-decoration:none;color:var(--accent);font-weight:600}.pagelinks a:hover{text-decoration:underline}.pagelinks span{color:\{pager_muted}}@media (max-width:900px){body{grid-template-columns:1fr}.sidebar{border-right:none;border-bottom:1px solid var(--line)}}@media (max-width:767px){.chapter{padding:15px}.pagelinks{padding:15px 15px 0}.code-copy{position:static;display:inline-block;margin:0 0 .5rem auto}}</style></head><body>\{navigation}<main class=\"content\">\{pagelinks}\{body}</main><script>(function(){var L={copy:\"\{copy_label}\",copied:\"\{copied_label}\",failed:\"\{failed_label}\"};function s(b,t){b.textContent=t;b.setAttribute(\"data-label\",t)}function f(t){var a=document.createElement(\"textarea\");a.value=t;a.setAttribute(\"readonly\",\"\");a.style.position=\"fixed\";a.style.top=\"-9999px\";a.style.left=\"-9999px\";document.body.appendChild(a);a.focus();a.select();try{return document.execCommand(\"copy\")}catch(_){return false}finally{document.body.removeChild(a)}}async function c(t){if(navigator.clipboard&&window.isSecureContext){try{await navigator.clipboard.writeText(t);return true}catch(_){}}return f(t)}document.addEventListener(\"click\",async function(e){var b=e.target&&e.target.closest?e.target.closest(\".code-copy\"):null;if(!b)return;var w=b.parentElement;if(!w)return;var ctn=w.querySelector(\"code\");if(!ctn)return;var ok=await c(ctn.textContent||\"\");if(ok){s(b,L.copied);b.setAttribute(\"data-copied\",\"true\");setTimeout(function(){s(b,L.copy);b.removeAttribute(\"data-copied\")},1600)}else{s(b,L.failed);setTimeout(function(){s(b,L.copy)},1600)}})})();</script>\{live_reload_script}</body></html>"
}

///|
fn renderer_text(config : @core.Config, key : String, fallback : String) -> String {
  match config.read("output.html.ui." + key) {
    Some(String(value)) if !value.is_empty() => value
    _ => fallback
  }
}

///|
fn render_live_reload_script(config : @core.Config) -> String {
  match config.read("output.html.live-reload-endpoint") {
    Some(String(endpoint)) => {
      let endpoint = if endpoint.has_prefix("/") {
        endpoint
      } else {
        "/" + endpoint
      }
      "<script>(function(){var e=\"\{escape_html(endpoint)}\";var c=null;async function p(){try{var r=await fetch(e,{cache:\"no-store\"});if(r.ok){var t=await r.text();if(c===null){c=t}else if(c!==t){location.reload();return}}}catch(_){ }setTimeout(p,1000)}setTimeout(p,1000)})();</script>"
    }
    _ => ""
  }
}

///|
fn render_head_assets(config : @core.Config, current_page : String) -> String {
  let builder = StringBuilder::new()
  for asset in html_additional_css(config) {
    let href = relative_href(current_page, @pathx.normalize(asset))
    builder.write_string(
      "<link rel=\"stylesheet\" href=\"\{escape_html(href)}\">",
    )
  }
  for asset in html_additional_js(config) {
    let src = relative_href(current_page, @pathx.normalize(asset))
    builder.write_string("<script src=\"\{escape_html(src)}\"></script>")
  }
  builder.to_string()
}

///|
fn configured_html_assets(config : @core.Config) -> Array[String] {
  let assets : Array[String] = []
  for asset in html_additional_css(config) {
    assets.push(asset)
  }
  for asset in html_additional_js(config) {
    assets.push(asset)
  }
  assets
}

///|
fn html_additional_css(config : @core.Config) -> Array[String] {
  json_string_array(config.read("output.html.additional-css"))
}

///|
fn html_additional_js(config : @core.Config) -> Array[String] {
  json_string_array(config.read("output.html.additional-js"))
}

///|
fn json_string_array(value : Json?) -> Array[String] {
  match value {
    Some(Array(values)) =>
      values.filter_map(fn(value) {
        match value {
          String(value) => Some(value)
          _ => None
        }
      })
    _ => []
  }
}

///|
fn render_chapter_body(chapter : @core.Chapter) -> String {
  let trail = chapter.parent_names.join(" > ")
  let breadcrumbs = if chapter.parent_names.is_empty() {
    ""
  } else {
    "<p class=\"breadcrumbs\">\{escape_html(trail)}</p>"
  }
  let stripped = strip_duplicate_leading_title(chapter.content, chapter)
  let (without_refs, references) = split_link_references(stripped)
  let (markdown, footnotes) = split_footnotes(without_refs)
  let content = render_markdown_with_refs(markdown, references) +
    render_footnotes(footnotes, references)
  "<article class=\"chapter\">\{breadcrumbs}<h1>\{escape_html(chapter.display())}</h1>\{content}</article>"
}

///|
async fn render_not_found_page(
  context : RenderContext,
  markdown : String?,
) -> Unit {
  let output_path = match not_found_output_path(context.config) {
    Some(path) => path
    None => return
  }
  let markdown = match markdown {
    Some(markdown) => markdown
    None => default_not_found_markdown(context.config)
  }
  let page = render_shell(
    context.config,
    context_title(context.config) +
    renderer_text(context.config, "not-found-suffix", " - 404"),
    render_navigation(context.book.items, output_path),
    render_not_found_body(markdown),
    render_pagelinks(context.config, None, None, output_path),
    render_live_reload_script(context.config),
    render_not_found_head(context.config) +
      render_not_found_assets(context.config),
  )
  let dest_path = @path.Path(context.build_dir)
    .join(@path.Path(output_path))
    .to_string()
  ensure_parent_dir(dest_path)
  write_text_file(dest_path, page)
}

///|
fn render_not_found_body(markdown : String) -> String {
  let (without_refs, references) = split_link_references(markdown)
  let (body, footnotes) = split_footnotes(without_refs)
  let content = render_markdown_with_refs(body, references) +
    render_footnotes(footnotes, references)
  "<article class=\"chapter not-found\">\{content}</article>"
}

///|
fn render_not_found_head(config : @core.Config) -> String {
  let base_url = normalized_site_url(config)
  "<base href=\"\{escape_html(base_url)}\">"
}

///|
fn render_not_found_assets(config : @core.Config) -> String {
  let builder = StringBuilder::new()
  for asset in html_additional_css(config) {
    builder.write_string(
      "<link rel=\"stylesheet\" href=\"\{escape_html(@pathx.normalize(asset))}\">",
    )
  }
  for asset in html_additional_js(config) {
    builder.write_string(
      "<script src=\"\{escape_html(@pathx.normalize(asset))}\"></script>",
    )
  }
  builder.to_string()
}

///|
fn normalized_site_url(config : @core.Config) -> String {
  let base_url = match config.read("output.html.site-url") {
    Some(String(site_url)) if !site_url.is_empty() => site_url
    _ => "/"
  }
  if base_url.has_suffix("/") {
    base_url
  } else {
    base_url + "/"
  }
}

///|
fn default_not_found_markdown(config : @core.Config) -> String {
  let title = renderer_text(
    config,
    "not-found-title",
    "Document not found (404)",
  )
  let body = renderer_text(
    config,
    "not-found-body",
    "This URL is invalid, sorry. Please use the navigation bar or search to continue.",
  )
  "# \{title}\n\n\{body}\n"
}

///|
fn not_found_output_path(config : @core.Config) -> String? {
  match not_found_input_path(config) {
    Some(path) => Some(markdown_output_path(path))
    None => None
  }
}

///|
fn not_found_input_path(config : @core.Config) -> String? {
  match config.read("output.html.input-404") {
    Some(String(path)) => if path.is_empty() { None } else { Some(path) }
    _ => Some("404.md")
  }
}

///|
fn markdown_output_path(path : String) -> String {
  if path.has_suffix(".md") {
    path.replace(old=".md", new=".html").to_string()
  } else {
    path + ".html"
  }
}

///|
async fn load_not_found_markdown(
  src_root : String,
  config : @core.Config,
) -> String? {
  match not_found_input_path(config) {
    Some(path) => {
      let source_path = @path.Path(src_root).join(@path.Path(path)).to_string()
      if @fsx.exists(source_path) {
        Some(strip_utf8_bom_text(@fsx.read_file(source_path)))
      } else if path == "404.md" {
        Some(default_not_found_markdown(config))
      } else {
        fail("missing configured 404 source: \{source_path}")
      }
    }
    None => None
  }
}

///|
fn strip_utf8_bom_text(text : String) -> String {
  if text.has_prefix("\u{feff}") {
    text[1:].to_string()
  } else {
    text
  }
}

///|
fn render_pagelinks(
  config : @core.Config,
  previous : @core.Chapter?,
  next : @core.Chapter?,
  current_page : String,
) -> String {
  let previous_label = renderer_text(config, "previous", "Previous")
  let next_label = renderer_text(config, "next", "Next")
  let prev = match previous {
    Some(chapter) =>
      "<a class=\"previous\" href=\"\{relative_href(current_page, chapter_output_path(chapter))}\">\{escape_html(previous_label)}: \{escape_html(chapter.name)}</a>"
    None => "<span></span>"
  }
  let nxt = match next {
    Some(chapter) =>
      "<a class=\"next\" href=\"\{relative_href(current_page, chapter_output_path(chapter))}\">\{escape_html(next_label)}: \{escape_html(chapter.name)}</a>"
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
      builder.write_string(escape_html(text[i + 1:i + 2].to_string()))
      i += 2
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
      builder.write_string(escape_html(text[i:i + 1].to_string()))
      i += 1
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
      builder.write_string(text[i + 1:i + 2].to_string())
      i += 2
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
      builder.write_string(text[i:i + 1].to_string())
      i += 1
    }
  }
  builder.to_string()
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
  !plain.has_suffix(".md")
}

///|
fn strip_link_anchor(path : String) -> String {
  match path.find("#") {
    Some(index) => path[:index].to_string()
    None => path
  }
}

///|
fn collect_markdown_assets(markdown : String) -> Array[String] {
  let assets : Array[String] = []
  let mut i = 0
  while i + 1 < markdown.length() {
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
  assert_true(html.contains("<button class=\"code-copy\" type=\"button\">Copy</button>"))
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
    .set("output.html.ui.not-found-body", Json::string("请返回目录继续浏览。"))
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
  assert_true(html.contains(".chapter pre{white-space:pre-wrap;background:#444444"))
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
