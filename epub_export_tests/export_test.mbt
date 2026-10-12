///|
fn epub_entries(bytes : Bytes) -> Map[String, FixedArray[Byte]] raise {
  Map::from_array(
    @fzip.unzip_sync(bytes.to_fixedarray(), opts={ verify_checksum: true, }),
  )
}

///|
fn epub_text(
  entries : Map[String, FixedArray[Byte]],
  name : String,
) -> String raise {
  @fzip.str_from_u8(entries[name])
}

///|
async fn write_sources(
  root : String,
  sources : Array[(String, String)],
) -> Unit {
  for (path, content) in sources {
    @fs.write_file(root + "/" + path, content, create_mode=CreateOrTruncate)
  }
}

///|
async test "export reads SUMMARY into a portable ebook then refreshes after editorial changes" {
  let root = match @env.get_env_var("MOONBOOK_EPUB_EVIDENCE") {
    Some(path) => path + "/book"
    None => @fs.tmpdir(prefix="moonbook-epub-")
  }
  for dir in ["/src/guide", "/src/images"] {
    if !@fs.exists(root + dir) {
      @fs.mkdir(root + dir, recursive=true)
    }
  }
  let intro = "# Pilot & plan\n\nA **twelve-team** proposal with [capacity](guide/README.md#capacity), [summary](r%C3%A9sum%C3%A9%20%E6%9D%B1%E4%BA%AC.md#r%C3%A9sum%C3%A9-%E6%9D%B1%E4%BA%AC) and [web evidence](https://example.com/?a=1&b=2).\n\n![Local chart](images/chart.png)\n\n- [x] capture evidence\n- [ ] revisit sizing\n\n| Scope | Teams |\n| --- | ---: |\n| Pilot | 12 |\n\nFootnote[^basis].\n\n[^basis]: A retained basis, not factual verification.\n\n```html\n<img src=\"code-only.png\">\n```\n"
  let capacity = "# Capacity\n\nEight teams fit the current staffing.\n\n[Back](../start.md#pilot-plan). ![Same chart](../images/chart.png)\n\n## Capacity\n\nMore detail.\n"
  let summary = "# Summary\n\n# Decision\n\n- [Pilot & plan](start.md)\n  - [Capacity](guide/README.md)\n- [Résumé 東京](résumé 東京.md)\n- [Draft]()\n"
  let config = "[book]\ntitle = \"Pilot & evidence\"\nauthors = [\"Research & Ops\"]\nlanguage = \"en\"\ndescription = \"A portable handbook.\"\n[build]\nbuild-dir = \"exports\"\ncreate-missing = true\n"
  let sources = [
    ("src/start.md", intro),
    ("src/guide/README.md", capacity),
    (
      "src/résumé 東京.md", "# Résumé 東京\n\nAll evidence stays in this snapshot 😀.\n",
    ),
    ("src/SUMMARY.md", summary),
    ("src/private.md", "Unlisted company note."),
    ("book.toml", config),
  ]
  write_sources(root, sources)
  let png : Bytes = [
    0x89, 0x50, 0x4e, 0x47, 0xd, 0xa, 0x1a, 0xa, 0x0, 0x0, 0x0, 0xd, 0x49, 0x48,
    0x44, 0x52, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1, 0x8, 0x2, 0x0, 0x0, 0x0,
    0x90, 0x77, 0x53, 0xde, 0x0, 0x0, 0x0, 0xc, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c,
    0x63, 0x50, 0x4a, 0x5b, 0x5, 0x0, 0x1, 0xe0, 0x1, 0x33, 0x8d, 0xa2, 0x99, 0xda,
    0x0, 0x0, 0x0, 0x0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
  ]
  @fs.write_file(
    root + "/src/images/chart.png",
    png,
    create_mode=CreateOrTruncate,
  )
  let destination = @driver.export_epub(root)
  assert_eq(destination, root + "/exports/__moonbook/book.epub")
  let first = @fs.read_file(destination).binary()
  let entries = epub_entries(first)
  let infos = @fzip.unzip_list(first.to_fixedarray())
  assert_eq(infos[0].name, "mimetype")
  assert_eq(epub_text(entries, "mimetype"), "application/epub+zip")
  assert_eq(entries.length(), 9)
  assert_true(
    epub_text(entries, "EPUB/package.opf").contains("Pilot &amp; evidence"),
  )
  assert_true(
    epub_text(entries, "EPUB/package.opf").contains("Research &amp; Ops"),
  )
  assert_true(
    epub_text(entries, "EPUB/nav.xhtml").contains(
      "<ol><li><a href=\"chapter-2.xhtml\">",
    ),
  )
  assert_true(
    epub_text(entries, "EPUB/chapter-1.xhtml").contains(
      "chapter-2.xhtml#capacity",
    ),
  )
  assert_true(
    epub_text(entries, "EPUB/chapter-1.xhtml").contains(
      "chapter-3.xhtml#r%C3%A9sum%C3%A9-%E6%9D%B1%E4%BA%AC",
    ),
  )
  assert_true(
    epub_text(entries, "EPUB/chapter-2.xhtml").contains(
      "chapter-1.xhtml#pilot-plan",
    ),
  )
  assert_true(
    epub_text(entries, "EPUB/chapter-3.xhtml").contains("snapshot 😀"),
  )
  assert_eq(entries["EPUB/images/image-1.png"], png.to_fixedarray())
  for (path, content) in sources {
    assert_eq(@fs.read_file(root + "/" + path).text(), content)
  }
  assert_false(@fs.exists(root + "/book"))
  ignore(@driver.export_epub(root))
  assert_eq(@fs.read_file(destination).binary(), first)
  @fs.write_file(root + "/before.epub", first, create_mode=CreateOrTruncate)
  let revised_sources = [
    (
      "src/SUMMARY.md", "# Summary\n\n- [Résumé 東京](résumé 東京.md)\n- [Pilot & plan](start.md)\n",
    ),
    (
      "src/start.md", "# Pilot & plan\n\nRevised to eight teams. [Summary](résumé 東京.md).\n",
    ),
  ]
  write_sources(root, revised_sources)
  ignore(@driver.export_epub(root))
  let revised = @fs.read_file(destination).binary()
  let after = epub_entries(revised)
  assert_true(
    epub_text(after, "EPUB/chapter-1.xhtml").contains("snapshot 😀"),
  )
  assert_true(
    epub_text(after, "EPUB/chapter-2.xhtml").contains("Revised to eight teams"),
  )
  assert_false(after.contains("EPUB/chapter-3.xhtml"))
  assert_false(after.contains("EPUB/images/image-1.png"))
  assert_false(epub_text(after, "EPUB/nav.xhtml").contains("Capacity"))
  @fs.write_file(
    root + "/after-edit.epub",
    revised,
    create_mode=CreateOrTruncate,
  )
  // Failed exports preserve the last complete ebook and every supplied input.
  let failures = [
    ("<script>bad()</script>\n", "unsupported element"),
    ("[Missing](absent.md)\n", "SUMMARY target"),
    ("[Missing](#absent)\n", "heading or anchor"),
    ("![Missing](images/missing.png)\n", "image unavailable"),
    ("<div>unclosed\n", "XHTML"),
  ]
  for (text, expected) in failures {
    @fs.write_file(root + "/src/start.md", text, create_mode=CreateOrTruncate)
    try @driver.export_epub(root) catch {
      error => assert_true(error.to_string().contains(expected))
    } noraise {
      _ => fail("unsupported ebook unexpectedly exported")
    }
    assert_eq(@fs.read_file(destination).binary(), revised)
    assert_eq(@fs.read_file(root + "/src/start.md").text(), text)
  }
  @fs.write_file(
    root + "/src/SUMMARY.md",
    summary + "- [Absent](missing.md)\n",
    create_mode=CreateOrTruncate,
  )
  assert_true((try? @driver.export_epub(root)) is Err(_))
  assert_false(@fs.exists(root + "/src/missing.md"))
  assert_eq(@fs.read_file(destination).binary(), revised)
  write_sources(root, sources)
  ignore(@driver.export_epub(root))
}

///|
async test "empty or source-overlapping export leaves the source tree intact" {
  let root = match @env.get_env_var("MOONBOOK_EPUB_EVIDENCE") {
    Some(path) => path + "/invalid"
    None => @fs.tmpdir(prefix="moonbook-epub-invalid-")
  }
  if !@fs.exists(root + "/src") {
    @fs.mkdir(root + "/src", recursive=true)
  }
  write_sources(root, [
    ("src/SUMMARY.md", "# Summary\n"),
    ("book.toml", "[book]\ntitle = \"Empty\"\n"),
  ])
  assert_true((try? @driver.export_epub(root)) is Err(_))
  assert_false(@fs.exists(root + "/book/__moonbook/book.epub"))
  write_sources(root, [
    ("src/SUMMARY.md", "# Summary\n\n- [A](a.md)\n"),
    ("src/a.md", "# A\n\nKeep editable text.\n"),
    ("book.toml", "[build]\nbuild-dir = \"src\"\n"),
  ])
  try @driver.export_epub(root) catch {
    error =>
      assert_true(error.to_string().contains("outside the editable source"))
  } noraise {
    _ => fail("export wrote into the source directory")
  }
  assert_eq(
    @fs.read_file(root + "/src/a.md").text(),
    "# A\n\nKeep editable text.\n",
  )
  assert_false(@fs.exists(root + "/src/__moonbook"))
}
