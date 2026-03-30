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
  let navigation = render_navigation(chapters)
  let index_body = if chapters.is_empty() {
    render_shell(
      context_title(context.config),
      navigation,
      "<p>No chapters found.</p>",
    )
  } else {
    let first = chapters[0]
    let first_path = chapter_output_path(first)
    render_shell(
      context_title(context.config),
      navigation,
      "<p><a href=\"\{first_path}\">Open \{escape_html(first.name)}</a></p>",
    )
  }
  write_text_file(
    @path.Path(context.build_dir).join(@path.Path("index.html")).to_string(),
    index_body,
  )
  for chapter in chapters {
    let path = @path.Path(context.build_dir).join(
      @path.Path(chapter_output_path(chapter)),
    )
    let page = render_shell(
      chapter.display(),
      navigation,
      "<article class=\"chapter\"><h1>\{escape_html(chapter.display())}</h1><pre>\{escape_html(chapter.content)}</pre></article>",
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
fn render_navigation(chapters : Array[@core.Chapter]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("<ul class=\"sidebar\">")
  for chapter in chapters {
    builder.write_string(
      "<li><a href=\"\{chapter_output_path(chapter)}\">\{escape_html(chapter.display())}</a></li>",
    )
  }
  builder.write_string("</ul>")
  builder.to_string()
}

///|
fn render_shell(title : String, navigation : String, body : String) -> String {
  "<!doctype html><html><head><meta charset=\"utf-8\"><title>\{escape_html(title)}</title><style>body{font-family:ui-sans-serif,system-ui,sans-serif;margin:0;display:grid;grid-template-columns:18rem 1fr;min-height:100vh}.sidebar{margin:0;padding:2rem;list-style:none;background:#f3efe6}.content{padding:2rem}a{text-decoration:none;color:#8a2d0a}pre{white-space:pre-wrap;background:#fff8ef;padding:1rem;border-radius:12px}</style></head><body>\{navigation}<main class=\"content\">\{body}</main></body></html>"
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
