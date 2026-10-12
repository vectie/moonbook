///|
test "whole-book links resolve chapter aliases and rebase local assets" {
  let targets = {
    "intro.html": "chapter-1",
    "guide/index.html": "chapter-2",
    "guide/README.html": "chapter-2",
  }
  assert_eq(
    whole_book_link("#details", true, "chapter-2", "guide/index.html", targets),
    "#chapter-2--details",
  )
  assert_eq(
    whole_book_link(
      "../intro.html#plan", true, "chapter-2", "guide/index.html", targets,
    ),
    "#chapter-1--plan",
  )
  assert_eq(
    whole_book_link(
      "README.html", true, "chapter-2", "guide/index.html", targets,
    ),
    "#chapter-2",
  )
  assert_eq(
    whole_book_link(
      "images/chart.png", false, "chapter-2", "guide/index.html", targets,
    ),
    "../guide/images/chart.png",
  )
  assert_eq(
    whole_book_link(
      "../intro.html?view=1#plan", true, "chapter-2", "guide/index.html", targets,
    ),
    "../intro.html?view=1#plan",
  )
  for
    url in [
      "https://example.com/guide.md#a", "//example.com/image.png", "/root.html",
      "mailto:reader@example.com", "data:image/png;base64,a", "",
    ] {
    assert_eq(
      whole_book_link(url, true, "chapter-2", "guide/index.html", targets),
      url,
    )
  }
  assert_eq(
    whole_book_link("#", true, "chapter-1", "intro.html", targets),
    "#chapter-1",
  )
  assert_false(is_local_asset("#details"))
}

///|
test "whole-book HTML rewriting respects attribute boundaries and opaque contents" {
  let html = "<p id='note' data-id=\"untouched\"><a HREF = '../intro.html#plan' title='x > y'>go</a><img src=icon.png></p><!-- <a href=\"lost.html\"> --><script>const s='İ <a href=\"lost.html\">';</ScRiPt><style>/* <i id='no'> */</style><p id=last>😀</p><code>&lt;a href=\"example.html\"&gt;</code>"
  let actual = whole_book_rewrite_html(html, "chapter-2", "guide/index.html", {
    "intro.html": "chapter-1",
  })
  assert_true(
    actual.contains("<p id=\"chapter-2--note\" data-id=\"untouched\">"),
  )
  assert_true(actual.contains("<a href=\"#chapter-1--plan\" title='x > y'>"))
  assert_true(actual.contains("<img src=\"../guide/icon.png\">"))
  assert_true(actual.contains("<!-- <a href=\"lost.html\"> -->"))
  assert_true(
    actual.contains("<script>const s='İ <a href=\"lost.html\">';</ScRiPt>"),
  )
  assert_true(actual.contains("<style>/* <i id='no'> */</style>"))
  assert_true(actual.contains("<p id=\"chapter-2--last\">😀</p>"))
  assert_true(actual.contains("<code>&lt;a href=\"example.html\"&gt;</code>"))
  assert_eq(
    whole_book_rewrite_html("<a href='unfinished", "c", "a.html", {}),
    "<a href='unfinished",
  )
}

///|
test "whole-book projection keeps repeated headings footnotes Unicode and no drafts" {
  let a = @core.chapter(
    "Intro",
    "# Intro\n\n## Shared\n\n[Other](nested/README.md#shared) and [^a].\n\n[^a]: First note.\n",
    path=Some("intro.md"),
    source_path=Some("intro.md"),
  )
  let b = @core.chapter(
    "Details 東京",
    "# Details 東京\n\n## Shared\n\n[Local](#shared) and [^a].\n\n[^a]: Second note.\n",
    path=Some("nested/index.md"),
    source_path=Some("nested/README.md"),
  )
  let context = new_render_context(
    "root",
    "output",
    @core.default(),
    @core.new_with_items([
      @core.item_chapter(a),
      @core.item_chapter(b),
      @core.item_chapter(@core.Chapter::new_draft("Draft must stay out", [])),
    ]),
  )
  let page = whole_book_page(context)
  for
    expected in [
      "href=\"#chapter-2--shared\"", "id=\"chapter-1--shared\"", "id=\"chapter-2--shared\"",
      "id=\"chapter-1--footnote-a\"", "href=\"#chapter-2--footnote-a\"", "href=\"#chapter-2--fr-a\"",
      "id=\"chapter-1--intro\"", "Source: nested/README.md", "Details 東京", "break-before:page",
      "@media print", "window.print()",
    ] {
    assert_true(page.contains(expected), msg=expected)
  }
  assert_false(page.contains("Draft must stay out"))
  assert_true(
    page.find("First note").unwrap() < page.find("Second note").unwrap(),
  )
  assert_true(
    render_navigation(context.book.items, "nested/index.html").contains(
      "href=\"../__moonbook/print.html\"",
    ),
  )
  assert_true(
    render_navigation(context.book.items, "index.html").contains(
      "href=\"__moonbook/print.html\"",
    ),
  )
}

///|
test "whole-book empty content and repeated title delimiters remain explicit" {
  let config = @core.from_json({ "book": { "title": "<one><two>&&\"\"" } })
  let page = whole_book_page(
    new_render_context("root", "output", config, @core.new()),
  )
  assert_true(page.contains("&lt;one&gt;&lt;two&gt;&amp;&amp;&quot;&quot;"))
  assert_true(page.contains("0 chapters"))
  assert_true(page.contains("No chapters found."))
  assert_false(page.contains("<one>"))
}

///|
test "whole-book chapter lookup accepts percent encoded paths and escaped ampersands" {
  let targets = { "guide/Space 東京 & notes.html": "chapter-3" }
  assert_eq(
    whole_book_link(
      "Space%20%E6%9D%B1%E4%BA%AC%20%26%20notes.html#topic", true, "chapter-2", "guide/index.html",
      targets,
    ),
    "#chapter-3--topic",
  )
  assert_eq(
    whole_book_link(
      "Space 東京 &amp; notes.html", true, "chapter-2", "guide/index.html", targets,
    ),
    "#chapter-3",
  )
  assert_eq(whole_book_path_text("x%FF%20y"), "x%FF%20y")
  assert_eq(whole_book_path_text("literal%zz.md"), "literal%zz.md")
}

///|
test "whole-book code samples keep every HTML delimiter as literal text" {
  assert_eq(
    escape_html("<<tag>>&\"<&\""),
    "&lt;&lt;tag&gt;&gt;&amp;&quot;&lt;&amp;&quot;",
  )
  let html = render_markdown("```text\n<a href=\"x\">example</a>\n```\n")
  assert_true(html.contains("&lt;a href=&quot;x&quot;&gt;example&lt;/a&gt;"))
}

///|
test "whole-book raw single quoted Markdown source links find rendered chapters" {
  let chapter = @core.chapter(
    "Start",
    "# Start\n\n<a href='start.md#start'>Raw source</a>\n",
    path=Some("start.md"),
    source_path=Some("start.md"),
  )
  let page = whole_book_page(
    new_render_context(
      "root",
      "output",
      @core.default(),
      @core.new_with_items([@core.item_chapter(chapter)]),
    ),
  )
  assert_true(page.contains("href=\"#chapter-1--start\">Raw source</a>"))
}
