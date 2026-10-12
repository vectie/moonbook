///|
test "notebook metadata stays inert and excludes chapter bodies and drafts" {
  let book = @core.new_with_items([
    @core.item_chapter(
      @core.chapter(
        "</ScRiPt> & 東京",
        "private body",
        path=Some("first.md"),
        source_path=Some("first.md"),
      ),
    ),
    @core.item_chapter(@core.Chapter::new_draft("Draft", [])),
  ])
  let data = reader_notebook_data(
    new_render_context("root", "out", @core.default(), book),
  )
  assert_false(data.contains("<"))
  assert_false(data.contains("&"))
  assert_false(data.contains("private body"))
  guard @json.parse(data) is { "pages": Array(pages), .. } else {
    fail("missing pages")
  }
  assert_eq(pages.length(), 1)
  assert_eq(pages[0], {
    "title": "</ScRiPt> & 東京",
    "path": "first.md",
    "href": "../first.html",
  })
}
