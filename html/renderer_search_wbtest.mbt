///|
test "static search embeds exact source as inert JSON in SUMMARY order" {
  let text = "# Résumé 東京\n<script>bad()</script>\n</ScRiPt><img src=x onerror=bad()> & \" ' 😀"
  let nested = @core.chapter(
    "Child",
    "Nested full text",
    path=Some("part/index.md"),
    source_path=Some("part/README.md"),
  )
  let chapter = @core.chapter("<Title>", text, path=Some("first.md"), sub_items=[
    @core.item_chapter(nested),
  ])
  let book = @core.new_with_items([
    @core.item_part_title("Part"),
    @core.item_chapter(chapter),
    @core.item_separator(),
    @core.item_chapter(@core.Chapter::new_draft("Excluded draft", [])),
  ])
  let encoded = static_search_data(book.chapters())
  assert_false(encoded.contains("<"))
  assert_false(encoded.contains("&"))
  guard @json.parse(encoded) is Array(pages) else { fail("missing index") }
  assert_eq(pages.length(), 2)
  assert_eq(pages[0], {
    "title": "<Title>",
    "path": "first.html",
    "href": "../first.html",
    "text": text,
  })
  assert_eq(pages[1], {
    "title": "Child",
    "path": "part/README.md",
    "href": "../part/index.html",
    "text": "Nested full text",
  })
  assert_true(
    render_navigation(book.items, "part/index.html").contains(
      "href=\"../__moonbook/search.html\"",
    ),
  )
  assert_true(
    render_navigation(book.items, "index.html").contains(
      "href=\"__moonbook/search.html\"",
    ),
  )
}

///|
test "static search reserves only its generated directory before writing" {
  let config = @core.default()
  let collision = @core.new_with_items([
    @core.item_chapter(
      @core.chapter("Collision", "keep", path=Some("__moonbook/search.md")),
    ),
  ])
  assert_true(
    (Ok(
      check_static_search_paths(
        new_render_context("root", "output", config, collision),
      ),
    ) catch {
      error => Err(error)
    })
    is Err(_),
  )
  let allowed = @core.new_with_items([
    @core.item_chapter(
      @core.chapter("Search chapter", "keep", path=Some("search.md")),
    ),
  ])
  check_static_search_paths(
    new_render_context("root", "output", config, allowed),
  )
  let asset = @core.new_with_items([
    @core.item_chapter(
      @core.chapter(
        "Asset",
        "![asset](../__moonbook/icon.png)",
        path=Some("nested/chapter.md"),
        source_path=Some("nested/chapter.md"),
      ),
    ),
  ])
  assert_true(
    (Ok(
      check_static_search_paths(
        new_render_context("root", "output", config, asset),
      ),
    ) catch {
      error => Err(error)
    })
    is Err(_),
  )
  assert_true(is_static_search_reserved("one/../__moonbook/search.html"))
  assert_false(is_static_search_reserved("__moonbook-guide.html"))
}

///|
test "static search page has no external resources and an explicit empty index" {
  let context = new_render_context(
    "root",
    "output",
    @core.default(),
    @core.new(),
  )
  let page = static_search_page(context)
  assert_true(
    page.contains(
      "<script id=\"book-search-data\" type=\"application/json\">[]</script>",
    ),
  )
  assert_true(page.contains("role=\"status\" aria-live=\"polite\""))
  assert_true(page.contains("<noscript>"))
  assert_false(page.contains("fetch("))
  assert_false(page.contains(" src="))
  assert_false(page.contains("http://") || page.contains("https://"))
}

///|
test "static search escapes every title delimiter and refuses a colliding 404" {
  let title = "<one><two>&&\"\"</title><script>bad()</script>"
  let config = @core.from_json({ "book": { "title": title } })
  let page = static_search_page(
    new_render_context("root", "output", config, @core.new()),
  )
  assert_false(page.contains(title))
  assert_true(
    page.contains(
      "&lt;one&gt;&lt;two&gt;&amp;&amp;&quot;&quot;&lt;/title&gt;&lt;script&gt;bad()&lt;/script&gt;",
    ),
  )
  let collision = @core.from_json({
    "output": { "html": { "input-404": "__moonbook/search.md" } },
  })
  assert_true(
    (Ok(
      check_static_search_paths(
        new_render_context("root", "output", collision, @core.new()),
      ),
    ) catch {
      error => Err(error)
    })
    is Err(_),
  )
}
