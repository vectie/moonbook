///|
// Connections come only from rendered author content, before menus, pagers or
// the generated connection panels are added. Each directed chapter pair occurs
// once, regardless of how many headings or footnotes link to it.
priv struct ChapterConnections {
  chapters : Array[@core.Chapter]
  bodies : Array[String]
  outgoing : Array[Array[Int]]
  incoming : Array[Array[Int]]
}

///|
fn chapter_connections(chapters : Array[@core.Chapter]) -> ChapterConnections {
  let targets : Map[String, Int] = Map([])
  let bodies = chapters.map(chapter => {
    render_chapter_body(chapter, outline=true)
  })
  let outgoing : Array[Array[Int]] = chapters.map(_ => [])
  let incoming : Array[Array[Int]] = chapters.map(_ => [])
  for index, chapter in chapters {
    targets[chapter_output_path(chapter)] = index
    if chapter.source_path is Some(source) {
      targets[@pathx.normalize(source)] = index
      targets[fix_link_path(@pathx.normalize(source))] = index
    }
  }
  for source, chapter in chapters {
    let found : Map[Int, Unit] = Map([])
    let _ = transform_html_tags(bodies[source], fn(tag) {
      if connection_anchor_href(tag) is Some(href) &&
        connection_target(href, chapter_output_path(chapter), targets)
        is Some(target) &&
        target != source {
        found[target] = ()
      }
      tag
    })
    // Both directions follow SUMMARY order rather than incidental link order.
    for target in 0..<chapters.length() {
      if found.contains(target) {
        outgoing[source].push(target)
        incoming[target].push(source)
      }
    }
  }
  { chapters, bodies, outgoing, incoming, }
}

///|
fn connection_target(
  href : String,
  current_page : String,
  targets : Map[String, Int],
) -> Int? {
  let href = connection_attribute_text(href).trim().to_owned()
  if href.is_empty() ||
    href.has_prefix("#") ||
    href.has_prefix("/") ||
    href.contains(":") ||
    href.contains("\\") {
    return None
  }
  let fragment = href.find("#").unwrap_or(href.length())
  let before_fragment = href[:fragment].to_owned()
  let query = before_fragment.find("?").unwrap_or(before_fragment.length())
  let path = whole_book_percent_path_text(before_fragment[:query].to_owned())
  if path.is_empty() || path.has_prefix("/") || path.contains("\\") {
    return None
  }
  targets.get(@pathx.normalize(@pathx.join(path_dirname(current_page), path)))
}

///|
// Keep URL delimiters in filenames literal when generating navigation. The
// original author links are unchanged; these links name known rendered outputs.
fn connection_href(from : String, to : String) -> String {
  let encoded = StringBuilder()
  for byte in @utf8.encode(relative_href(from, to)) {
    let code = byte.to_int()
    if (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      byte == b'/' ||
      byte == b'.' ||
      byte == b'-' ||
      byte == b'_' ||
      byte == b'~' {
      encoded.write_char(code.to_char().unwrap())
    } else {
      encoded.write_string("%")
      encoded.write_string(
        "0123456789ABCDEF"[code / 16:code / 16 + 1].to_owned(),
      )
      encoded.write_string(
        "0123456789ABCDEF"[code % 16:code % 16 + 1].to_owned(),
      )
    }
  }
  encoded.to_string()
}

///|
fn connection_list(
  graph : ChapterConnections,
  indexes : Array[Int],
  current_page : String,
) -> String {
  if indexes.is_empty() {
    return "<p>None in this build.</p>"
  }
  let body = StringBuilder()
  body.write_string("<ul>")
  for index in indexes {
    let chapter = graph.chapters[index]
    let href = connection_href(current_page, chapter_output_path(chapter))
    let title = escape_html(chapter.display())
    let source = escape_html(
      chapter.source_path.unwrap_or(chapter_output_path(chapter)),
    )
    body.write_string(
      "<li><a href=\"\{href}\">\{title}</a> <small>\{source}</small></li>",
    )
  }
  body.write_string("</ul>")
  body.to_string()
}

///|
fn render_chapter_connections(
  graph : ChapterConnections,
  index : Int,
  current_page : String,
) -> String {
  let incoming = connection_list(graph, graph.incoming[index], current_page)
  let outgoing = connection_list(graph, graph.outgoing[index], current_page)
  let map = connection_href(current_page, "__moonbook/connections.html") +
    "#chapter-\{index + 1}"
  "<section class=\"chapter chapter-connections\" aria-label=\"Chapter connections\"><h2>Chapter connections</h2><h3>Referenced by</h3>\{incoming}<h3>Links to</h3>\{outgoing}<p><a href=\"\{map}\">Explore all chapter connections</a></p></section>"
}

///|
fn chapter_connections_page(
  context : RenderContext,
  graph : ChapterConnections,
) -> String {
  let current = "__moonbook/connections.html"
  let body = StringBuilder()
  let count = graph.chapters.length()
  let mut edges = 0
  for outgoing in graph.outgoing {
    edges += outgoing.length()
  }
  let chapter_label = if count == 1 { "chapter" } else { "chapters" }
  let connection_label = if edges == 1 { "connection" } else { "connections" }
  let title = escape_html(context_title(context.config))
  body.write_string(
    "<article class=\"chapter\"><h1>Chapter connections</h1><p>\{title} · \{count} \{chapter_label} · \{edges} directed \{connection_label}</p><p>Follow the explicit links between chapters, or use Referenced by to find the chapters that cite this one. Each chapter pair appears once, in book order. Rebuild after editing links.</p><p>Only links in rendered chapter content count. Menus, previous/next navigation, same-chapter anchors, external sites and unlisted files are excluded. A link is an authored reference, not evidence that either chapter is correct.</p>",
  )
  if count == 0 {
    body.write_string("<p>No chapters found.</p>")
  }
  for index, chapter in graph.chapters {
    let chapter_title = escape_html(chapter.display())
    let href = connection_href(current, chapter_output_path(chapter))
    let incoming = connection_list(graph, graph.incoming[index], current)
    let outgoing = connection_list(graph, graph.outgoing[index], current)
    body.write_string(
      "<section id=\"chapter-\{index + 1}\" class=\"connection-entry\"><h2><a href=\"\{href}\">\{chapter_title}</a></h2><h3>Referenced by</h3>\{incoming}<h3>Links to</h3>\{outgoing}</section>",
    )
  }
  body.write_string("</article>")
  render_shell(
    context.config,
    "Chapter connections · " + context_title(context.config),
    render_navigation(context.book.items, current),
    body.to_string(),
    "",
    render_live_reload_script(context.config),
    render_head_assets(context.config, current),
  )
}

///|
async fn write_chapter_connections(
  context : RenderContext,
  graph : ChapterConnections,
) -> Unit {
  let destination = @pathx.join(
    context.build_dir,
    "__moonbook/connections.html",
  )
  ensure_parent_dir(destination)
  write_text_file(destination, chapter_connections_page(context, graph))
}
