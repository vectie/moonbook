///|
async test "ordinary builds expose reverse chapter navigation and refresh after link edits" {
  let root = match @env.get_env_var("MOONBOOK_CONNECTIONS_EVIDENCE") {
    Some(path) => path + "/book"
    None => @fs.tmpdir(prefix="moonbook-connections-")
  }
  if !@fs.exists(root + "/src/guide") {
    @fs.mkdir(root + "/src/guide", recursive=true)
  }
  let summary = "# Summary\n\n- [Pilot decision](start.md)\n  - [Capacity evidence](guide/README.md)\n- [Résumé 東京](résumé 東京.md)\n- [Unconnected note](alone.md)\n- [Draft]()\n"
  let start = "# Pilot decision\n\nThe pilot proposes twelve teams. [Capacity](guide/README.md#capacity) and [summary](r%C3%A9sum%C3%A9%20%E6%9D%B1%E4%BA%AC.md) explain the trade-off.\n\n[Repeated capacity](guide/index.html#capacity).\n\n```html\n<a href=\"alone.html\">This is a code sample.</a>\n```\n"
  let plan = "# Capacity evidence\n\n## Capacity\n\nCurrent staffing supports eight teams.\n\n<a href='../start.html?view=full#pilot'>Return to the decision</a>\n"
  let sources = [
    ("src/SUMMARY.md", summary),
    ("src/start.md", start),
    ("src/guide/README.md", plan),
    (
      "src/résumé 東京.md", "# Résumé 東京\n\nComplete comparison 😀.\n",
    ),
    ("src/alone.md", "# Unconnected note\n\nNo authored links yet.\n"),
    (
      "src/private.md", "Unlisted private source must not appear in connections.\n",
    ),
    ("book.toml", "[book]\ntitle = \"Synthetic pilot handbook\"\n"),
  ]
  for (path, content) in sources {
    @fs.write_file(root + "/" + path, content, create_mode=CreateOrTruncate)
  }
  @driver.load(root).build()
  let output = root + "/book/__moonbook/connections.html"
  let first = @fs.read_file(output).text()
  assert_true(first.contains("4 chapters · 3 directed connections"))
  assert_true(first.contains("../guide/index.html"))
  assert_true(first.contains("../r%C3%A9sum%C3%A9%20%E6%9D%B1%E4%BA%AC.html"))
  assert_false(first.contains("Unlisted private source"))
  let capacity = @fs.read_file(root + "/book/guide/index.html").text()
  assert_true(capacity.contains("class=\"chapter chapter-connections\""))
  assert_true(capacity.contains("href=\"../start.html\""))
  assert_true(capacity.contains("../__moonbook/connections.html#chapter-2"))
  for (path, content) in sources {
    assert_eq(@fs.read_file(root + "/" + path).text(), content)
  }
  @driver.load(root).build()
  assert_eq(@fs.read_file(output).text(), first)
  @fs.write_file(
    root + "/connections-before.html",
    first,
    create_mode=CreateOrTruncate,
  )
  // Remove the reverse link and retarget the decision: both directions refresh.
  let revised_start = "# Pilot decision\n\n[Unconnected note](alone.md) is now linked.\n"
  let revised_plan = "# Capacity evidence\n\nCurrent staffing supports eight teams.\n"
  @fs.write_file(
    root + "/src/start.md",
    revised_start,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/src/guide/README.md",
    revised_plan,
    create_mode=CreateOrTruncate,
  )
  @driver.load(root).build()
  let second = @fs.read_file(output).text()
  assert_true(second.contains("4 chapters · 1 directed connection"))
  assert_eq(@fs.read_file(root + "/src/start.md").text(), revised_start)
  assert_eq(@fs.read_file(root + "/src/guide/README.md").text(), revised_plan)
  @fs.write_file(
    root + "/connections-after-edit.html",
    second,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/alone-after-edit.html",
    @fs.read_file(root + "/book/alone.html").text(),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/src/SUMMARY.md",
    summary + "- [Missing](missing.md)\n",
    create_mode=CreateOrTruncate,
  )
  try @driver.load(root).build() catch {
    error =>
      @fs.write_file(
        root + "/missing-chapter-error.txt",
        error.to_string(),
        create_mode=CreateOrTruncate,
      )
  } noraise {
    _ => fail("missing chapter unexpectedly built")
  }
  assert_eq(@fs.read_file(output).text(), second)
  // Restore the complete practical example, retaining both rebuild observations.
  for (path, content) in sources {
    @fs.write_file(root + "/" + path, content, create_mode=CreateOrTruncate)
  }
  @driver.load(root).build()
  assert_eq(@fs.read_file(output).text(), first)
}

///|
async test "connection projection refuses a reserved chapter before overwriting files" {
  let root = match @env.get_env_var("MOONBOOK_CONNECTIONS_EVIDENCE") {
    Some(path) => path + "/collision"
    None => @fs.tmpdir(prefix="moonbook-connections-collision-")
  }
  for directory in ["/src/__moonbook", "/book/__moonbook"] {
    if !@fs.exists(root + directory) {
      @fs.mkdir(root + directory, recursive=true)
    }
  }
  let chapter = "# Author source\nPreserve it.\n"
  @fs.write_file(
    root + "/src/SUMMARY.md",
    "# Summary\n\n- [Collision](__moonbook/connections.md)\n",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/src/__moonbook/connections.md",
    chapter,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/book/__moonbook/connections.html",
    "prior output",
    create_mode=CreateOrTruncate,
  )
  try @driver.load(root).build() catch {
    error => assert_true(error.to_string().contains("reserved"))
  } noraise {
    _ => fail("reserved path unexpectedly built")
  }
  assert_eq(
    @fs.read_file(root + "/src/__moonbook/connections.md").text(),
    chapter,
  )
  assert_eq(
    @fs.read_file(root + "/book/__moonbook/connections.html").text(),
    "prior output",
  )
}
