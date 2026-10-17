///|
test "chapter connections are deduplicated directional authored links in book order" {
  let first = @core.chapter(
    "Start",
    "# Start\n\n[Last first](last.md), [Plan](guide/README.md#detail), [Plan again](guide/index.html?view=full#two). [Self](#start)\n\n[Reference][p]\n\n[p]: guide/README.md\n\nA note [^one].\n\n[^one]: [Last](last.md).\n\n```html\n<a href=\"isolated.html\">Example</a>\n```\n\n`[Not a link](isolated.md)`\n\n<!-- <a href=\"isolated.html\">Comment</a> -->\n\n<script>const s = '<a href=\"isolated.html\">';</script>\n\n<style>a:after{content:'<a href=\"isolated.html\">'}</style>\n\n<textarea><a href=\"isolated.html\">Not active</a></textarea>\n\n[External](https://example.test/isolated.html), [Root](/isolated.html), [Unlisted](private.md).\n",
    path=Some("start.md"),
    source_path=Some("start.md"),
  )
  let plan = @core.chapter(
    "Plan",
    "# Plan\n\n<a data-label='href=\"isolated.html\"' HREF='../start.md#start'>Back</a>\n",
    path=Some("guide/index.md"),
    source_path=Some("guide/README.md"),
  )
  let last = @core.chapter("Last", "# Last\n", path=Some("last.md"))
  let isolated = @core.chapter("Alone", "# Alone\n", path=Some("isolated.md"))
  let graph = chapter_connections([first, plan, last, isolated])
  assert_eq(graph.outgoing, [[1, 2], [0], [], []])
  assert_eq(graph.incoming, [[1], [0], [0], []])
  let panel = render_chapter_connections(graph, 1, "guide/index.html")
  assert_true(panel.contains("href=\"../start.html\""))
  assert_true(panel.contains("../__moonbook/connections.html#chapter-2"))
  assert_false(graph.bodies[1].contains("Chapter connections"))
}

///|
test "connection targets normalize nested source and output aliases and encoded filenames" {
  let targets : Map[String, Int32] = {
    "guide/index.html": 0,
    "guide/README.md": 0,
    "guide/README.html": 0,
    "résumé 東京.html": 1,
    "a&b #?.html": 2,
  }
  assert_eq(
    connection_target("../guide/./README.md#detail", "deep/page.html", targets),
    Some(0),
  )
  assert_eq(
    connection_target(
      "../guide/index.html?view=x#detail", "deep/page.html", targets,
    ),
    Some(0),
  )
  assert_eq(
    connection_target(
      "../r%C3%A9sum%C3%A9%20%E6%9D%B1%E4%BA%AC.html", "deep/page.html", targets,
    ),
    Some(1),
  )
  assert_eq(
    connection_target("../a&amp;b%20%23%3F.html", "deep/page.html", targets),
    Some(2),
  )
  for
    href in [
      "#local", "?view=x", "", "/guide/index.html", "//host/guide/index.html", "https://host/guide/index.html",
      "mailto:someone@example.test", "../outside.html", "../../guide/index.html",
      "..\\guide\\index.html",
    ] {
    assert_eq(
      connection_target(href, "deep/page.html", targets),
      None,
      msg=href,
    )
  }
  assert_eq(
    connection_href("deep/page.html", "a&b #?.html"),
    "../a%26b%20%23%3F.html",
  )
  assert_eq(
    connection_href("__moonbook/connections.html", "résumé 東京.html"),
    "../r%C3%A9sum%C3%A9%20%E6%9D%B1%E4%BA%AC.html",
  )
}

///|
test "anchor scanner handles real attributes without counting attribute or raw-text examples" {
  assert_eq(
    connection_anchor_href("<A class='x' HREF = 'chapter.html#two'>"),
    Some("chapter.html#two"),
  )
  assert_eq(
    connection_anchor_href("<a disabled href=chapter.html>"),
    Some("chapter.html"),
  )
  assert_eq(
    connection_anchor_href("<a href='first.html' href='second.html'>"),
    Some("first.html"),
  )
  assert_eq(
    connection_anchor_href(
      "<a data-example='href=\"false.html\"' title='x > y'>",
    ),
    None,
  )
  assert_eq(connection_anchor_href("<area href='not-anchor.html'>"), None)
  assert_eq(connection_anchor_href("</a>"), None)
  let found : Array[String] = []
  let html = "<!-- <a href='comment.html'> -->İ😀<ScRiPt>let x='<a href=\"script.html\">';</SCRIPT><title><a href='title.html'></title><a href='real.html'>Actual</a>"
  let unchanged = transform_html_tags(html, fn(tag) {
    if connection_anchor_href(tag) is Some(href) {
      found.push(href)
    }
    tag
  })
  assert_eq(unchanged, html)
  assert_eq(found, ["real.html"])
}

///|
test "connection page includes isolated chapters and empty books without unsafe titles" {
  let chapter = @core.chapter(
    "<Title>&",
    "# Isolated\n",
    path=Some("alone.md"),
    source_path=Some("alone.md"),
  )
  let book = @core.new_with_items([
    @core.item_chapter(chapter),
    @core.item_chapter(@core.Chapter::new_draft("Hidden draft", [])),
  ])
  let graph = chapter_connections(book.chapters())
  let page = chapter_connections_page(
    new_render_context("root", "output", @core.default(), book),
    graph,
  )
  assert_true(page.contains("1 chapter · 0 directed connections"))
  assert_true(page.contains("&lt;Title&gt;&amp;"))
  assert_false(page.contains("<Title>"))
  assert_true(page.contains("None in this build."))
  // Draft navigation is inherited, but drafts are never connection entries.
  assert_eq(graph.chapters.length(), 1)
  let empty = chapter_connections_page(
    new_render_context("root", "output", @core.default(), @core.new()),
    chapter_connections([]),
  )
  assert_true(empty.contains("0 chapters · 0 directed connections"))
  assert_true(empty.contains("No chapters found."))
  assert_false(empty.contains("fetch("))
}

///|
test "connection attributes decode once before URL delimiters and percent filenames" {
  let targets : Map[String, Int32] = {
    "a&b.html": 0,
    "a#b.html": 1,
    "a&amp;b.html": 2,
  }
  assert_eq(connection_target("a&#38;b.html", "start.html", targets), Some(0))
  assert_eq(connection_target("a&#x26;b.html", "start.html", targets), Some(0))
  assert_eq(
    connection_target("a%23b.html&#35;heading", "start.html", targets),
    Some(1),
  )
  assert_eq(
    connection_target("a&amp;amp;b.html", "start.html", targets),
    Some(2),
  )
  assert_eq(
    connection_target("https&colon;//site/a.html", "start.html", targets),
    None,
  )
  assert_eq(
    connection_attribute_text("😀 &quot; &apos; &lt; &gt; &#128512;"),
    "😀 \" ' < > 😀",
  )
  assert_eq(
    connection_attribute_text("&unknown; &#; &#999999999;"),
    "&unknown; &#; &#999999999;",
  )
}
