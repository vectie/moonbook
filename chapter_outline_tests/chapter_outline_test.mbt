///|
async test "static chapter outline follows rendered sections and rebuilds from source" {
  let evidence = match @env.get_env_var("MOONBOOK_OUTLINE_EVIDENCE") {
    Some(path) => path
    None => @fs.tmpdir(prefix="moonbook-outline-retained-")
  }
  let root = evidence + "/book"
  @fs.mkdir(root + "/src/nested", recursive=true)
  let original =
    #|# Handbook
    #|
    #|A long chapter, with a retained raw source outside the rendered scope.
    #|
    #|## Start
    #|Some opening text.
    #|#### Deep *section* and `code`
    #|Read the details.
    #|## 東京 😀
    #|Unicode content.
    #|## [guide] & \<literal>
    #|Plain labels in navigation, with author links kept in the chapter.
    #|## A
    #|First.
    #|## A-1
    #|Literal suffix.
    #|## A
    #|Repeated section.
    #|## !!!
    #|Punctuation section.
    #|## Section
    #|Fallback name collision.
    #|## <!-- invisible -->
    #|No visible heading label.
    #|```markdown
    #|## This is code, not a section
    #|```
    #|> ## A quoted paragraph, not a rendered heading
    #|
    #|[guide]: ../plain.md
    #|[^note]: A footnote that does not become an outline heading.
    #|
  let plain = "# Plain\n\nA chapter with no sections.\n"
  let summary = "# Summary\n\n- [Handbook](nested/guide.md)\n- [Plain](plain.md)\n"
  for
    (path, content) in [
      ("src/nested/guide.md", original),
      ("src/plain.md", plain),
      ("src/SUMMARY.md", summary),
      ("src/unlisted.md", "Private unlisted source MUST NOT enter the outline."),
      ("book.toml", "[book]\ntitle = \"Outline handbook\"\n"),
    ] {
    @fs.write_file(root + "/" + path, content, create_mode=CreateOrTruncate)
  }
  let chapter = @core.chapter(
    "Handbook",
    @fs.read_file(root + "/src/nested/guide.md").text(),
    path=Some("nested/guide.md"),
    source_path=Some("nested/guide.md"),
  )
  let plain_chapter = @core.chapter(
    "Plain",
    plain,
    path=Some("plain.md"),
    source_path=Some("plain.md"),
  )
  let book = @core.new_with_items([
    @core.item_chapter(chapter),
    @core.item_chapter(plain_chapter),
  ])
  let context = @html.new_render_context(
    root,
    root + "/book",
    @core.default(),
    book,
  )
  @html.render_html(context)
  let first = @fs.read_file(root + "/book/nested/guide.html").text()
  assert_true(
    first.contains("<details class=\"chapter-outline\" open=\"open\">"),
  )
  assert_true(first.contains("<nav aria-label=\"On this page\"><ol>"))
  assert_true(first.contains("href=\"#a-2\">A</a>"))
  assert_true(first.contains("id=\"a-2\""))
  assert_true(first.contains("href=\"#%E6%9D%B1%E4%BA%AC-%F0%9F%98%80\""))
  assert_true(first.contains("Untitled section"))
  assert_false(first.contains("Private unlisted source"))
  assert_false(
    @fs.read_file(root + "/book/plain.html")
    .text()
    .contains("<details class=\"chapter-outline\""),
  )
  assert_false(
    @fs.read_file(root + "/book/__moonbook/print.html")
    .text()
    .contains("<details class=\"chapter-outline\""),
  )
  @fs.write_file(evidence + "/first.html", first, create_mode=CreateOrTruncate)
  @html.render_html(context)
  assert_eq(@fs.read_file(root + "/book/nested/guide.html").text(), first)
  assert_eq(@fs.read_file(root + "/src/nested/guide.md").text(), original)
  assert_eq(@fs.read_file(root + "/src/SUMMARY.md").text(), summary)
  let revised = "# Handbook\n\n## Revised section\nNew content.\n"
  // An explicit authored edit; keep the original input in the retained record.
  @fs.write_file(
    evidence + "/original.md",
    original,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/src/nested/guide.md",
    revised,
    create_mode=CreateOrTruncate,
  )
  let revised_chapter = @core.chapter(
    "Handbook",
    @fs.read_file(root + "/src/nested/guide.md").text(),
    path=Some("nested/guide.md"),
    source_path=Some("nested/guide.md"),
  )
  @html.render_html(
    @html.new_render_context(
      root,
      root + "/book",
      @core.default(),
      @core.new_with_items([
        @core.item_chapter(revised_chapter),
        @core.item_chapter(plain_chapter),
      ]),
    ),
  )
  let second = @fs.read_file(root + "/book/nested/guide.html").text()
  assert_true(second.contains("href=\"#revised-section\">Revised section</a>"))
  assert_false(second.contains("href=\"#start\""))
  assert_eq(@fs.read_file(root + "/src/nested/guide.md").text(), revised)
  assert_eq(@fs.read_file(root + "/src/plain.md").text(), plain)
  assert_eq(@fs.read_file(root + "/src/SUMMARY.md").text(), summary)
  assert_eq(
    @fs.read_file(root + "/src/unlisted.md").text(),
    "Private unlisted source MUST NOT enter the outline.",
  )
}
