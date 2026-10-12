///|
async test "ordinary build emits complete linked whole book and refreshes without changing sources" {
  let root = match @env.get_env_var("MOONBOOK_WHOLE_BOOK_EVIDENCE") {
    Some(path) => path + "/book"
    None => @fs.tmpdir(prefix="moonbook-whole-book-")
  }
  if !@fs.exists(root + "/src/guide/images") {
    @fs.mkdir(root + "/src/guide/images", recursive=true)
  }
  let summary = "# Summary\n\n- [Start](start.md)\n  - [Plan 東京](guide/README.md)\n- [Draft]()\n"
  let start = "# Start\n\n## Shared\n\nThe pilot has twelve teams. [Continue](guide/README.md#shared).\n\nRead note [^one].\n\n[^one]: First evidence note.\n"
  let plan = "# Plan 東京\n\n## Shared\n\nCapacity supports eight teams. 完全な記録 😀\n\n[Back](../start.md#shared), [local](#shared), and [top](../start.md#start).\n\n<a href='../start.md#shared'>Raw source link</a>\n\n![Diagram](images/chart.svg)\n\n| Task | Owner |\n| --- | --- |\n| Audit | Ana |\n\n```text\nA literal <a href=\"start.html\">example</a>.\n```\n\nRead note [^one].\n\n[^one]: Second evidence note.\n"
  let asset = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"40\"><text x=\"5\" y=\"25\">Eight teams</text></svg>"
  let sources = [
    ("src/SUMMARY.md", summary),
    ("src/start.md", start),
    ("src/guide/README.md", plan),
    ("src/guide/images/chart.svg", asset),
    ("src/private.md", "Unlisted private note must not appear."),
    ("book.toml", "[book]\ntitle = \"Synthetic pilot handbook\"\n"),
  ]
  for (path, content) in sources {
    @fs.write_file(root + "/" + path, content, create_mode=CreateOrTruncate)
  }
  @driver.load(root).build()
  let destination = root + "/book/__moonbook/print.html"
  let first = @fs.read_file(destination).text()
  for
    expected in [
      "twelve teams", "eight teams", "完全な記録 😀", "href=\"#chapter-2--shared\"",
      "href=\"#chapter-1--shared\"", "href=\"#chapter-1--start\"", "src=\"../guide/images/chart.svg\"",
      "id=\"chapter-2--footnote-one\"", "<td>Audit</td>",
    ] {
    assert_true(first.contains(expected), msg=expected)
  }
  assert_false(first.contains("Unlisted private note"))
  assert_false(first.contains("Draft"))
  assert_eq(@fs.read_file(root + "/book/guide/images/chart.svg").text(), asset)
  for (path, content) in sources {
    assert_eq(@fs.read_file(root + "/" + path).text(), content)
  }
  assert_true(
    @fs.read_file(root + "/book/guide/index.html")
    .text()
    .contains("../__moonbook/print.html"),
  )
  assert_true(
    @fs.read_file(root + "/book/__moonbook/search.html")
    .text()
    .contains("twelve teams"),
  )
  @driver.load(root).build()
  assert_eq(@fs.read_file(destination).text(), first)
  @fs.write_file(
    root + "/whole-book-before.html",
    first,
    create_mode=CreateOrTruncate,
  )
  let revised = start.replace(old="twelve teams", new="six teams").to_string()
  @fs.write_file(root + "/src/start.md", revised, create_mode=CreateOrTruncate)
  @driver.load(root).build()
  let second = @fs.read_file(destination).text()
  assert_true(second.contains("six teams"))
  assert_false(second.contains("twelve teams"))
  assert_eq(@fs.read_file(root + "/src/start.md").text(), revised)
  @fs.write_file(
    root + "/src/SUMMARY.md",
    summary + "- [Missing](missing.md)\n",
    create_mode=CreateOrTruncate,
  )
  try @driver.load(root) catch {
    _ => ()
  } noraise {
    _ => fail("missing chapter unexpectedly loaded")
  }
  assert_eq(@fs.read_file(destination).text(), second)
  @fs.write_file(
    root + "/src/SUMMARY.md",
    summary,
    create_mode=CreateOrTruncate,
  )
}

///|
async test "whole-book reserved output collision preserves existing output and author input" {
  let root = match @env.get_env_var("MOONBOOK_WHOLE_BOOK_EVIDENCE") {
    Some(path) => path + "/collision"
    None => @fs.tmpdir(prefix="moonbook-print-conflict-")
  }
  for directory in ["/src/__moonbook", "/book/__moonbook"] {
    if !@fs.exists(root + directory) {
      @fs.mkdir(root + directory, recursive=true)
    }
  }
  let content = "# Author chapter\nKeep the original.\n"
  @fs.write_file(
    root + "/src/SUMMARY.md",
    "# Summary\n\n- [Collision](__moonbook/print.md)\n",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/src/__moonbook/print.md",
    content,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/book/__moonbook/print.html",
    "prior projection",
    create_mode=CreateOrTruncate,
  )
  try @driver.load(root).build() catch {
    _ => ()
  } noraise {
    _ => fail("reserved output unexpectedly rendered")
  }
  assert_eq(@fs.read_file(root + "/src/__moonbook/print.md").text(), content)
  assert_eq(
    @fs.read_file(root + "/book/__moonbook/print.html").text(),
    "prior projection",
  )
}
