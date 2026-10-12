///|
async test "ordinary build adds notebook using current listed chapters without modifying source" {
  let root = match @env.get_env_var("MOONBOOK_NOTEBOOK_EVIDENCE") {
    Some(path) => path + "/book"
    None => @fs.tmpdir(prefix="moonbook-notebook-")
  }
  if !@fs.exists(root + "/src/nested") {
    @fs.mkdir(root + "/src/nested", recursive=true)
  }
  let summary = "# Summary\n\n- [First](intro.md)\n  - [東京](nested/README.md)\n- [Draft]()\n"
  let first = "# First\n\nOriginal evidence.\n"
  let second = "# 東京\n\nComplete second chapter.\n"
  for
    (path, content) in [
      ("src/SUMMARY.md", summary),
      ("src/intro.md", first),
      ("src/nested/README.md", second),
      ("src/private.md", "Not listed private material"),
      ("book.toml", "[book]\ntitle = \"Notebook </script> & 東京\"\n"),
    ] {
    @fs.write_file(root + "/" + path, content, create_mode=CreateOrTruncate)
  }
  let book = @driver.load(root)
  book.build()
  let output = root + "/book/__moonbook/notebook.html"
  let page = @fs.read_file(output).text()
  assert_true(page.contains("../nested/index.html"))
  assert_true(page.contains("nested/README.md"))
  assert_true(page.contains("Export notebook archive"))
  assert_true(page.contains("Import notebook archive"))
  assert_true(page.contains("moonbook.reader-notebook-archive"))
  assert_true(page.contains("notebook-archive-preview"))
  assert_false(page.contains("Not listed private material"))
  assert_false(page.contains("Original evidence"))
  assert_false(page.contains("Notebook </script>"))
  assert_true(page.contains("Notebook &lt;/script&gt; &amp; 東京"))
  assert_true(
    @fs.read_file(root + "/book/nested/index.html")
    .text()
    .contains("../__moonbook/notebook.html"),
  )
  book.build()
  assert_eq(@fs.read_file(output).text(), page)
  assert_eq(@fs.read_file(root + "/src/intro.md").text(), first)
  assert_eq(@fs.read_file(root + "/src/nested/README.md").text(), second)
  assert_eq(@fs.read_file(root + "/src/SUMMARY.md").text(), summary)
  @fs.write_file(
    root + "/src/SUMMARY.md",
    summary + "- [Missing](missing.md)\n",
    create_mode=CreateOrTruncate,
  )
  assert_true((try? @driver.load(root)) is Err(_))
  assert_eq(@fs.read_file(output).text(), page)
  @fs.write_file(
    root + "/src/SUMMARY.md",
    summary,
    create_mode=CreateOrTruncate,
  )
}
