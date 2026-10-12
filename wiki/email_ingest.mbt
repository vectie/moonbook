///|
fn is_email_source(path : String) -> Bool {
  @pathx.ext(path).to_owned().to_lower() == ".eml"
}

///|
async fn ingest_email_source(
  root : String,
  source_path : String,
) -> IngestResult {
  if is_remote_source(source_path) {
    fail("EML ingestion accepts local files only")
  }
  let workspace = workspace_paths(@fs.realpath(root))
  if !@fsx.exists(workspace.summary_path) ||
    !@fsx.exists(workspace.wiki_dir + "/index.md") {
    fail(
      "EML import requires an initialized Book; run moonbook wiki init <root> first",
    )
  }
  let input = resolve_input_source(workspace.root, source_path)
  let bytes = @fsx.read_bytes(input)
  if bytes.length() > 2097152 {
    fail("EML exceeds 2 MiB; export a smaller message")
  }
  @fsx.make_directory(
    workspace.raw_dir + "/imported",
    recursive=true,
    exists_ok=true,
  )
  // A stable safe basename keeps provenance links usable for arbitrary export
  // filenames. Exact bytes, including MIME attachments, survive before parsing.
  let raw_path = unique_import_path(
    workspace.raw_dir + "/imported",
    "message.eml",
  )
  @fsx.write_bytes(raw_path, bytes, create=0o644)
  let email = parse_email(bytes) catch {
    error =>
      fail("EML import failed; original retained at \{raw_path}: \{error}")
  }
  let sources_dir = workspace.wiki_dir + "/sources"
  @fsx.make_directory(sources_dir, recursive=true, exists_ok=true)
  let title_slug = slugify_title(email.title)
  let slug = unique_source_slug(
    sources_dir,
    "email-" +
    (if title_slug.length() > 100 {
      title_slug[:100].to_owned()
    } else {
      title_slug
    }),
  )
  let relative_page = "sources/" + slug + ".md"
  let page_path = workspace.wiki_dir + "/" + relative_page
  let relative_raw = relative_to_root(raw_path, workspace.root)
  let raw_link = relative_from_page("wiki/" + relative_page, relative_raw)
  let summary = "Local email export. Sender and date are supplied message headers, not authenticated identity or factual verification."
  let page = moonbook_metadata_block(
      "source",
      email.title,
      summary,
      "accepted",
      "verified",
      ["source", "email"],
      @async.now().to_string(),
    ) +
    "# " +
    ris_markdown_title(email.title) +
    "\n\n" +
    "- Raw source: [\{relative_raw}](\{raw_link})\n" +
    "- Source type: EML email\n" +
    "- Extraction: inline UTF-8 plain text. Attachments remain only in the original; HTML and external links are not fetched.\n\n" +
    "## Summary\n\n" +
    summary +
    "\n\n" +
    "## Extract\n\n" +
    ris_fenced_text(email.attribution + "\n\n" + email.body)
  @fsx.write_to_file(page_path, page, create=0o644)
  let safe_title = ris_markdown_title(email.title)
  update_summary(workspace.summary_path, safe_title, relative_page)
  update_index(
    workspace.wiki_dir + "/index.md",
    safe_title,
    relative_page,
    raw_path,
  )
  append_log(
    workspace.wiki_dir + "/log.md",
    safe_title,
    relative_raw,
    relative_page,
    [],
  )
  {
    page_path,
    raw_path,
    title: email.title,
    imported: true,
    related_pages: [],
    keeper_packet_path: "",
  }
}
