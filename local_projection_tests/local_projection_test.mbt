///|
async test "local projection renders real Book context and preserves it on repeat" {
  let root = @fs.tmpdir(prefix="book-local-projection-")
  ignore(@wiki.init_workspace(root, title=Some("Wenyu Local Studio")))
  @fs.write_file(
    root + "/raw/bootstrap/marketing-brief.md",
    "# Wenyu Local Studio\n\nA local civic art studio with existing Book context.\n",
    create_mode=CreateOrTruncate,
  )
  let first = @wiki.ensure_local_projection(root)
  assert_eq(first.contract, "moonbook.local_projection.v1")
  assert_true(
    first.generated_artifacts.contains("book/site/generated/index.html"),
  )
  assert_true(
    first.generated_artifacts.contains("book/site/generated/styles.css"),
  )
  assert_true(first.generated_artifacts.contains("book/site/generated/app.js"))
  assert_true(
    first.generated_artifacts.contains(
      "book/site/generated/knowledge-bundle.json",
    ),
  )
  assert_true(
    first.generated_artifacts.contains("book/site/generated/book-state.json"),
  )
  assert_eq(first.preserved_artifacts, [])
  assert_eq(first.missing_artifacts, [])
  let bytes : Map[String, String] = Map([])
  for path in first.generated_artifacts {
    let text = @fs.read_file(root + "/" + path).text()
    assert_false(text.is_empty())
    bytes[path] = text
  }
  let html = bytes["book/site/generated/index.html"]
  assert_true(html.contains("Wenyu Local Studio"))
  assert_true(html.contains("styles.css") && html.contains("app.js"))
  assert_false(html.contains("href=\"../../index.html\""))
  assert_false(html.contains("href=\"../../Home.html\""))
  assert_true(html.contains("full Book build pending"))
  assert_true(
    html.contains("href=\"./journal.html\"") &&
    html.contains("href=\"./course.html\""),
  )
  let journal = bytes["book/site/generated/journal.html"]
  assert_false(journal.contains("href=\"../../"))
  let second = @wiki.ensure_local_projection(root)
  assert_eq(second.generated_artifacts, [])
  assert_eq(second.preserved_artifacts, first.generated_artifacts)
  assert_eq(second.missing_artifacts, [])
  for path, text in bytes {
    assert_eq(@fs.read_file(root + "/" + path).text(), text)
  }
}

///|
async test "local projection preserves authored HTML CSS and prompt artifacts without claiming generation" {
  let root = @fs.tmpdir(prefix="book-local-projection-human-")
  ignore(@wiki.init_workspace(root, title=Some("Wenyu preserved")))
  @fs.mkdir(root + "/book/site/generated", recursive=true)
  @fs.mkdir(root + "/build", recursive=true)
  let human : Array[(String, String)] = [
    ("book/site/generated/index.html", "<html>Human-owned site</html>"),
    ("book/site/generated/styles.css", "/* Human-owned stylesheet */"),
    ("build/ASSET_PROMPTS.md", "Human-owned prompts"),
    ("build/ASSET_MANIFEST.md", "Provider-authored manifest"),
  ]
  for (path, text) in human {
    @fs.write_file(root + "/" + path, text, create_mode=CreateOrTruncate)
  }
  let outcome = @wiki.ensure_local_projection(root)
  assert_true(
    outcome.preserved_artifacts.contains("book/site/generated/index.html"),
  )
  assert_false(
    outcome.generated_artifacts.contains("book/site/generated/index.html"),
  )
  assert_true(
    outcome.generated_artifacts.contains("book/site/generated/app.js"),
  )
  for (path, text) in human {
    assert_eq(@fs.read_file(root + "/" + path).text(), text)
  }
}

///|
async test "local projection reports blocked files as missing and keeps unrelated image bytes" {
  let root = @fs.tmpdir(prefix="book-local-projection-missing-")
  ignore(@wiki.init_workspace(root))
  @fs.mkdir(root + "/book/site/generated/index.html", recursive=true)
  let asset = root + "/raw/assets/existing.svg"
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><title>Existing art</title></svg>"
  @fs.write_file(asset, svg, create_mode=CreateNew)
  let outcome = @wiki.ensure_local_projection(root)
  assert_true(
    outcome.missing_artifacts.contains("book/site/generated/index.html"),
  )
  assert_false(
    outcome.generated_artifacts.contains("book/site/generated/index.html"),
  )
  assert_false(
    outcome.preserved_artifacts.contains("book/site/generated/index.html"),
  )
  assert_eq(@fs.read_file(asset).text(), svg)
}

///|
async test "ordinary Book projection writes still refresh generated output" {
  let root = @fs.tmpdir(prefix="book-normal-projection-")
  ignore(@wiki.init_workspace(root, title=Some("Normal Book Build")))
  ignore(@wiki.ensure_local_projection(root))
  @fs.write_file(
    root + "/book/site/generated/index.html",
    "Old generated page",
    create_mode=CreateOrTruncate,
  )
  let path = @wiki.write_marketing_projection(root, root + "/book/site")
  assert_eq(path, root + "/book/site/generated/index.html")
  let html = @fs.read_file(path).text()
  assert_false(html == "Old generated page")
  assert_true(html.contains("Normal Book Build"))
  assert_true(html.contains("href=\"../../Home.html\""))
}

///|
async test "local projection retains links to already rendered full Book pages" {
  let root = @fs.tmpdir(prefix="book-local-existing-chapters-")
  ignore(@wiki.init_workspace(root))
  @fs.mkdir(root + "/book", recursive=true)
  @fs.write_file(
    root + "/book/index.html",
    "Existing Book index",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/book/Home.html",
    "Existing Wiki home",
    create_mode=CreateNew,
  )
  ignore(@wiki.ensure_local_projection(root))
  let html = @fs.read_file(root + "/book/site/generated/index.html").text()
  assert_true(html.contains("href=\"../../index.html\""))
  assert_true(html.contains("href=\"../../Home.html\""))
  assert_eq(
    @fs.read_file(root + "/book/index.html").text(),
    "Existing Book index",
  )
}
