///|
test "epub normalizes void and boolean tags without changing quoted content" {
  assert_eq(
    epub_xml_tag("<input type=\"checkbox\" checked disabled>"),
    "<input type=\"checkbox\" checked=\"checked\" disabled=\"disabled\" />",
  )
  assert_eq(
    epub_xml_tag("<img alt='the checked disabled words' src=\"a.png\">"),
    "<img alt='the checked disabled words' src=\"a.png\" />",
  )
  assert_eq(epub_xml_tag("<hr>"), "<hr />")
  assert_eq(epub_xml_tag("<img src=\"a.png\" />"), "<img src=\"a.png\" />")
  assert_eq(epub_xml_tag("</p>"), "</p>")
}

///|
test "epub chapter XHTML keeps unicode headings footnotes tables and code" {
  let chapter = @core.chapter(
    "Intro",
    "# Intro\n\n## Résumé 東京\n\nA **claim**[^note].\n\n- [x] done\n\n| Name | Value |\n| --- | ---: |\n| Alpha | 2 |\n\n```html\n<img src=\"example.png\">\n```\n\n[^note]: Full evidence.\n",
    path=Some("intro.md"),
  )
  let document = epub_chapter_document(chapter)
  let ids : Map[String, Unit] = Map([])
  epub_collect_ids(document, ids)
  assert_true(ids.contains("intro"))
  assert_true(ids.contains("résumé-東京"))
  assert_true(ids.contains("footnote-note"))
  let targets = { "intro.md": "chapter-1.xhtml" }
  let anchors = { "chapter-1.xhtml": ids }
  let images : Array[EpubImage] = []
  let transformed = @xml.serialize(
    epub_rewrite_element(document, "intro.md", targets, anchors, images),
  )
  assert_true(transformed.contains("chapter-1.xhtml#footnote-note"))
  assert_true(transformed.contains("&lt;img src="))
  assert_false(transformed.contains("code-copy"))
  assert_eq(images.length(), 0)
  ignore(@xml.parse(epub_xhtml("Title & work", "en", transformed)))
}

///|
test "epub resolves percent encoded chapter aliases and deduplicates local images" {
  let targets = {
    "guide/index.html": "chapter-2.xhtml",
    "guide/README.md": "chapter-2.xhtml",
    "résumé 東京.html": "chapter-3.xhtml",
  }
  let anchors = {
    "chapter-2.xhtml": { "capacity": () },
    "chapter-3.xhtml": { "résumé": () },
  }
  assert_eq(
    epub_chapter_link("start.md", "guide/README.md#capacity", targets, anchors),
    "chapter-2.xhtml#capacity",
  )
  assert_eq(
    epub_chapter_link(
      "guide/README.md", "../r%C3%A9sum%C3%A9%20%E6%9D%B1%E4%BA%AC.html#r%C3%A9sum%C3%A9",
      targets, anchors,
    ),
    "chapter-3.xhtml#r%C3%A9sum%C3%A9",
  )
  let images : Array[EpubImage] = []
  assert_eq(
    epub_image_link("guide/README.md", "../images/chart%20one.png", images),
    "images/image-1.png",
  )
  assert_eq(
    epub_image_link("start.md", "images/chart one.png", images),
    "images/image-1.png",
  )
  assert_eq(images.length(), 1)
  assert_eq(
    epub_chapter_link(
      "start.md", "https://example.com/?q=book#top", targets, anchors,
    ),
    "https://example.com/?q=book#top",
  )
}

///|
test "epub gives repairable errors for content outside the supported projection" {
  let targets = { "start.md": "chapter-1.xhtml" }
  let anchors = { "chapter-1.xhtml": { "present": () } }
  assert_true(
    (Ok(epub_chapter_link("start.md", "#absent", targets, anchors)) catch {
      error => Err(error)
    })
    is Err(_),
  )
  assert_true(
    (Ok(epub_chapter_link("start.md", "start.md?mode=all", targets, anchors)) catch {
      error => Err(error)
    })
    is Err(_),
  )
  assert_true(
    (Ok(epub_image_link("start.md", "https://example.com/a.png", [])) catch {
      error => Err(error)
    })
    is Err(_),
  )
  assert_true(
    (Ok(epub_image_link("start.md", "../private.png", [])) catch {
      error => Err(error)
    })
    is Err(_),
  )
  assert_true(
    (Ok(epub_image_link("start.md", "drawing.svg", [])) catch {
      error => Err(error)
    })
    is Err(_),
  )
  for
    body in [
      "<script>run()</script>", "<video src=\"film.mp4\"></video>", "<p style=\"background:url(remote.png)\">x</p>",
    ] {
    let element = @xml.parse(body)
    assert_true(
      (Ok(epub_rewrite_element(element, "start.md", targets, anchors, [])) catch {
        error => Err(error)
      })
      is Err(_),
    )
  }
  assert_true(
    (Ok(
      epub_chapter_document(
        @core.chapter("Bad", "<div>unclosed", path=Some("bad.md")),
      ),
    ) catch {
      error => Err(error)
    })
    is Err(_),
  )
}

///|
test "epub detects unsupported image signatures and XML control text" {
  assert_true(epub_image_signature(b"\x89PNG\r\n\x1a\n", "image/png"))
  assert_true(epub_image_signature(b"GIF89a", "image/gif"))
  assert_true(epub_image_signature(b"\xff\xd8\xff", "image/jpeg"))
  assert_false(epub_image_signature(b"not an image", "image/png"))
  assert_true(
    (Ok(epub_validate_xml_text("invalid\u0000text")) catch {
      error => Err(error)
    })
    is Err(_),
  )
  epub_validate_xml_text("Résumé 東京 😀\n")
}
