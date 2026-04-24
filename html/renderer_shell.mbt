///|
// HTML shell, navigation, 404, page-link, and path helpers.

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
  let sidebar_bg = escape_html(
    renderer_text(config, "theme-sidebar-bg", "#f6f8fa"),
  )
  let muted = escape_html(renderer_text(config, "theme-muted", "#656d76"))
  let code_bg = escape_html(renderer_text(config, "theme-code-bg", "#f6f8fa"))
  let copy_bg = escape_html(
    renderer_text(config, "theme-copy-button-bg", "#f6f8fa"),
  )
  let copy_hover_bg = escape_html(
    renderer_text(config, "theme-copy-hover-bg", "#eef2f6"),
  )
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
  let pager_muted = escape_html(
    renderer_text(config, "theme-pager-muted", "#656d76"),
  )
  "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\{escape_html(title)}</title>\{head_extra}<style>:root{--bg:\{bg};--paper:\{paper};--ink:\{ink};--accent:\{accent};--line:\{line}}*{box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",\"Noto Sans\",Helvetica,Arial,sans-serif,\"Apple Color Emoji\",\"Segoe UI Emoji\";font-size:16px;line-height:1.5;color:var(--ink);margin:0;display:grid;grid-template-columns:16rem minmax(0,1fr);min-height:100vh;background:linear-gradient(180deg,\{bg_start} 0%,\{bg_end} 100%)}.sidebar{padding:1.5rem 1rem;background:\{sidebar_bg};border-right:1px solid var(--line);overflow:auto}.toc,.toc ol{margin:0;padding-left:1.25rem}.toc{padding-left:0;list-style:none}.toc ol{list-style:none}.chapter-item,.part-title,.separator{margin:.35rem 0}.part-title{margin-top:1rem;font-size:.75rem;font-weight:600;letter-spacing:.02em;text-transform:uppercase;color:\{muted}}.separator hr{border:none;border-top:1px solid var(--line)}.sidebar a{text-decoration:none;color:var(--ink)}.sidebar a:hover{text-decoration:underline}.sidebar a.current{color:var(--accent);font-weight:600}.content{padding:0;min-width:0}.chapter{box-sizing:border-box;min-width:200px;max-width:980px;margin:0 auto;background:var(--paper);padding:45px;overflow:hidden}.chapter h1,.chapter h2{padding-bottom:.3em;border-bottom:1px solid #d8dee4}.chapter h1{margin:0 0 16px;font-size:2em}.chapter h2{margin:24px 0 16px;font-size:1.5em}.chapter h3{margin:24px 0 16px;font-size:1.25em}.chapter h4,.chapter h5,.chapter h6{margin:24px 0 16px}.chapter p,.chapter li,.chapter blockquote{line-height:1.75}.chapter ul,.chapter ol{padding-left:2em}.chapter blockquote{margin:0 0 16px;padding:0 1em;color:\{muted};border-left:.25em solid var(--line)}.chapter hr{height:.25em;padding:0;margin:24px 0;background-color:#d8dee4;border:0}.code-block{position:relative;margin:16px 0}.chapter pre{white-space:pre-wrap;background:\{code_bg};padding:16px;border-radius:6px;overflow:auto;max-width:100%;margin:0;border:1px solid var(--line);font:12px/1.45 ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace}.chapter code{overflow-wrap:anywhere;font-family:ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace}.chapter :not(pre)>code{padding:.2em .4em;margin:0;font-size:85%;background:rgba(175,184,193,.2);border-radius:6px}.code-copy{position:absolute;top:.65rem;right:.65rem;border:1px solid var(--line);background:\{copy_bg};color:var(--ink);border-radius:6px;padding:.3rem .65rem;font:600 12px/1.2 -apple-system,BlinkMacSystemFont,\"Segoe UI\",\"Noto Sans\",Helvetica,Arial,sans-serif;cursor:pointer;box-shadow:0 1px 0 \{copy_shadow}}.code-copy:hover{background:\{copy_hover_bg}}.code-copy[data-copied=\"true\"]{background:\{copy_active_bg};color:\{copy_active_ink}}.chapter img{display:block;max-width:100%;width:auto;height:auto;margin:1rem auto;border-radius:6px;box-shadow:0 1px 3px \{image_shadow}}.chapter table{display:block;width:max-content;max-width:100%;overflow:auto;border-spacing:0;border-collapse:collapse}.chapter th,.chapter td{padding:6px 13px;border:1px solid var(--line)}.chapter tr:nth-child(2n){background:#f6f8fa}.chapter a{color:var(--accent);text-decoration:none}.chapter a:hover{text-decoration:underline}.pagelinks{display:flex;justify-content:space-between;gap:1rem;box-sizing:border-box;max-width:980px;margin:0 auto;padding:24px 45px 0}.pagelinks a{text-decoration:none;color:var(--accent);font-weight:600}.pagelinks a:hover{text-decoration:underline}.pagelinks span{color:\{pager_muted}}@media (max-width:900px){body{grid-template-columns:1fr}.sidebar{border-right:none;border-bottom:1px solid var(--line)}}@media (max-width:767px){.chapter{padding:15px}.pagelinks{padding:15px 15px 0}.code-copy{position:static;display:inline-block;margin:0 0 .5rem auto}}</style></head><body>\{navigation}<main class=\"content\">\{pagelinks}\{body}</main><script>(function(){var L={copy:\"\{copy_label}\",copied:\"\{copied_label}\",failed:\"\{failed_label}\"};function s(b,t){b.textContent=t;b.setAttribute(\"data-label\",t)}function f(t){var a=document.createElement(\"textarea\");a.value=t;a.setAttribute(\"readonly\",\"\");a.style.position=\"fixed\";a.style.top=\"-9999px\";a.style.left=\"-9999px\";document.body.appendChild(a);a.focus();a.select();try{return document.execCommand(\"copy\")}catch(_){return false}finally{document.body.removeChild(a)}}async function c(t){if(navigator.clipboard&&window.isSecureContext){try{await navigator.clipboard.writeText(t);return true}catch(_){}}return f(t)}document.addEventListener(\"click\",async function(e){var b=e.target&&e.target.closest?e.target.closest(\".code-copy\"):null;if(!b)return;var w=b.parentElement;if(!w)return;var ctn=w.querySelector(\"code\");if(!ctn)return;var ok=await c(ctn.textContent||\"\");if(ok){s(b,L.copied);b.setAttribute(\"data-copied\",\"true\");setTimeout(function(){s(b,L.copy);b.removeAttribute(\"data-copied\")},1600)}else{s(b,L.failed);setTimeout(function(){s(b,L.copy)},1600)}})})();</script>\{live_reload_script}</body></html>"
}

///|
fn renderer_text(
  config : @core.Config,
  key : String,
  fallback : String,
) -> String {
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
      "<script>(function(){var e=\"\{escape_html(endpoint)}\";if(!window.EventSource)return;var s=new EventSource(e);s.addEventListener(\"reload\",function(){location.reload()});s.onerror=function(){};window.addEventListener(\"beforeunload\",function(){try{s.close()}catch(_){}})})();</script>"
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
    config, "not-found-title", "Document not found (404)",
  )
  let body = renderer_text(
    config, "not-found-body", "This URL is invalid, sorry. Please use the navigation bar or search to continue.",
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
