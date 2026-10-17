///|
// An explicit, source-preserving export. Ordinary HTML builds remain unchanged.
pub async fn export_epub(context : RenderContext) -> String {
  let chapters = context.book.chapters()
  guard !chapters.is_empty() else {
    fail("EPUB needs at least one non-draft SUMMARY chapter")
  }
  let source_root = @afs.realpath(
    @pathx.join(context.root, context.config.book.src),
  )
  let output_dir = epub_destination(context.build_dir, source_root)
  let targets : Map[String, String] = {}
  let documents : Array[@xml.Element] = []
  let anchors : Map[String, Map[String, Unit]] = {}
  for index, chapter in chapters {
    let target = "chapter-\{index + 1}.xhtml"
    for path in [chapter.path, chapter.source_path] {
      if path is Some(path) {
        for
          alias in [
            @pathx.normalize(path),
            fix_link_path(@pathx.normalize(path)),
          ] {
          if targets.get(alias) is Some(other) && other != target {
            fail("EPUB ambiguous chapter path: \{alias}")
          }
          targets[alias] = target
        }
      }
    }
    let document = epub_chapter_document(chapter)
    let ids : Map[String, Unit] = {}
    epub_collect_ids(document, ids)
    documents.push(document)
    anchors[target] = ids
  }
  let language = context.config.book.language.unwrap_or("en")
  guard !language.is_empty() &&
    language
    .iter()
    .all(c => {
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '-'
    }) else {
    fail("EPUB book.language must be a language tag such as en or zh-CN")
  }
  let title = context_title(context.config)
  epub_validate_xml_text(title)
  guard !title.trim().is_empty() else {
    fail("EPUB book.title cannot be empty")
  }
  let images : Array[EpubImage] = []
  let entries : Array[(String, FixedArray[Byte])] = [
    ("mimetype", @fzip.str_to_u8("application/epub+zip")),
    (
      "META-INF/container.xml",
      @fzip.str_to_u8(
        "<?xml version=\"1.0\"?><container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"EPUB/package.opf\" media-type=\"application/oebps-package+xml\" /></rootfiles></container>",
      ),
    ),
    (
      "EPUB/book.css",
      @fzip.str_to_u8(
        "body{font-family:serif;line-height:1.55;margin:1em}img{max-width:100%;height:auto}pre{white-space:pre-wrap;overflow-wrap:anywhere}table{border-collapse:collapse;width:100%}th,td{border:1px solid #888;padding:.35em}blockquote{border-left:3px solid #aaa;padding-left:1em;margin-left:0}.breadcrumbs{font-size:.85em;color:#555}.boring{display:none}",
      ),
    ),
  ]
  let manifest = StringBuilder()
  manifest.write_string(
    "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\" /><item id=\"css\" href=\"book.css\" media-type=\"text/css\" />",
  )
  let spine = StringBuilder()
  let input_paths = [
    @pathx.join(context.root, "book.toml"),
    @pathx.join(source_root, "SUMMARY.md"),
  ]
  for index, chapter in chapters {
    let current = @pathx.normalize(
      chapter.source_path.unwrap_or(chapter.path.unwrap()),
    )
    let body = epub_rewrite_element(
      documents[index],
      current,
      targets,
      anchors,
      images,
    ) catch {
      error => fail("EPUB chapter \{chapter.name} (\{current}): \{error}")
    }
    let filename = "chapter-\{index + 1}.xhtml"
    entries.push(
      (
        "EPUB/" + filename,
        @fzip.str_to_u8(
          epub_xhtml(
            chapter.display(),
            language,
            "<nav aria-label=\"Book navigation\"><a href=\"nav.xhtml\">Contents</a></nav>" +
            @xml.serialize(body),
          ),
        ),
      ),
    )
    manifest.write_string(
      "<item id=\"chapter-\{index + 1}\" href=\"\{filename}\" media-type=\"application/xhtml+xml\" />",
    )
    spine.write_string("<itemref idref=\"chapter-\{index + 1}\" />")
    input_paths.push(@pathx.join(source_root, current))
  }
  for index, image in images {
    let path = @afs.realpath(@pathx.join(source_root, image.source)) catch {
      error => fail("EPUB image unavailable: \{image.source}: \{error}")
    }
    guard path.has_prefix(source_root + "/") else {
      fail("EPUB image leaves book source: \{image.source}")
    }
    let content = @fsx.read_bytes(path)
    guard epub_image_signature(content, image.media_type) else {
      fail("EPUB image bytes do not match their format: \{image.source}")
    }
    entries.push(("EPUB/" + image.destination, content.to_fixedarray()))
    manifest.write_string(
      "<item id=\"image-\{index + 1}\" href=\"\{image.destination}\" media-type=\"\{image.media_type}\" />",
    )
    input_paths.push(path)
  }
  let navigation = "<nav epub:type=\"toc\" id=\"toc\"><h1>\{@xml.escape_text(title)}</h1><ol>" +
    epub_navigation(context.book.items, targets) +
    "</ol></nav>"
  entries.push(
    ("EPUB/nav.xhtml", @fzip.str_to_u8(epub_xhtml(title, language, navigation))),
  )
  let modified = epub_modified(input_paths)
  let fingerprint = StringBuilder()
  fingerprint.write_string(context.config.book.to_json().stringify())
  let mut total_bytes = 0
  for (name, bytes) in entries {
    total_bytes += bytes.length()
    guard total_bytes <= 33554432 else {
      fail("EPUB supported export size is at most 32 MiB")
    }
    fingerprint.write_string(
      name + ":" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes)) + "\n",
    )
  }
  let identity = @crypto.bytes_to_hex_string(
    @crypto.sha256(@fzip.str_to_u8(fingerprint.to_string())),
  )
  let metadata = StringBuilder()
  metadata.write_string(
    "<dc:identifier id=\"book-id\">urn:moonbook:sha256:\{identity}</dc:identifier><dc:title>\{@xml.escape_text(title)}</dc:title><dc:language>\{@xml.escape_text(language)}</dc:language><meta property=\"dcterms:modified\">\{modified}</meta>",
  )
  for author in context.config.book.authors {
    epub_validate_xml_text(author)
    metadata.write_string(
      "<dc:creator>\{@xml.escape_text(author)}</dc:creator>",
    )
  }
  if context.config.book.description is Some(description) {
    epub_validate_xml_text(description)
    metadata.write_string(
      "<dc:description>\{@xml.escape_text(description)}</dc:description>",
    )
  }
  let package = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\" unique-identifier=\"book-id\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">" +
    metadata.to_string() +
    "</metadata><manifest>" +
    manifest.to_string() +
    "</manifest><spine>" +
    spine.to_string() +
    "</spine></package>"
  entries.push(("EPUB/package.opf", @fzip.str_to_u8(package)))
  // Stored ZIP entries make mimetype the first uncompressed entry with no extra.
  // A fixed valid DOS timestamp avoids export-clock differences in ZIP headers.
  let archive = @fzip.zip_sync_checked(entries, opts={
    ..@fzip.ZipEntryOptions::default(),
    level: 0,
    mtime: 2162688,
  })
  ensure_dir(output_dir)
  let destination = @pathx.join(output_dir, "book.epub")
  let temporary = destination + ".pending"
  @afs.write_file(
    temporary,
    archive.unsafe_reinterpret_as_bytes(),
    create_mode=CreateNew,
  )
  @fsx.atomic_replace(temporary, destination)
  destination
}

///|
async fn epub_destination(build_dir : String, source_root : String) -> String {
  let destination = @pathx.normalize(@pathx.join(build_dir, "__moonbook"))
  let mut existing = destination
  let suffix : Array[String] = []
  while !@afs.exists(existing) {
    suffix.push(moonbook_html_path(existing).basename().to_owned())
    let parent = @pathx.dirname(existing).to_string()
    guard parent != existing else { fail("EPUB output has no existing parent") }
    existing = parent
  }
  let mut resolved = @afs.realpath(existing)
  for part in suffix.rev() {
    resolved = @pathx.join(resolved, part)
  }
  guard resolved != source_root && !resolved.has_prefix(source_root + "/") else {
    fail("EPUB output directory must be outside the editable source directory")
  }
  resolved
}

///|
fn epub_pad(value : Int32) -> String {
  if value < 10 {
    "0\{value}"
  } else {
    value.to_string()
  }
}

///|
fn epub_modified(paths : Array[String]) -> String raise {
  let mut latest = 0L
  for path in paths {
    if @fsx.mtime(path) is Some(value) && value > latest {
      latest = value
    }
  }
  let time = @time.unix(latest)
  "\{time.year()}-\{epub_pad(time.month())}-\{epub_pad(time.day())}T\{epub_pad(time.hour())}:\{epub_pad(time.minute())}:\{epub_pad(time.second())}Z"
}
