///|
pub struct RisImportedReference {
  record_number : Int
  title : String
  citation : String
  page_path : String
} derive(Debug, ToJson)

///|
pub struct RisImportResult {
  raw_path : String
  references : Array[RisImportedReference]
} derive(Debug, ToJson)

///|
/// Retain a local RIS export and make one complete searchable source page per
/// reference. No URL, DOI, attachment, or bibliographic claim is fetched or
/// verified. Reimport creates new pages and leaves earlier evidence untouched.
pub async fn import_ris(root : String, source_path : String) -> RisImportResult {
  let workspace = workspace_paths(@fs.realpath(root))
  if !@fsx.exists(workspace.summary_path) ||
    !@fsx.exists(workspace.wiki_dir + "/index.md") {
    fail(
      "RIS import requires an initialized Book; run moonbook wiki init <root> first",
    )
  }
  let input = resolve_input_source(workspace.root, source_path)
  let bytes = @fsx.read_bytes(input)
  if bytes.length() > 2097152 {
    fail("RIS file exceeds 2 MiB; split the export before importing")
  }
  let imported_dir = workspace.raw_dir + "/imported"
  @fsx.make_directory(imported_dir, recursive=true, exists_ok=true)
  // Use a simple generated name so every source page can resolve the ordinary
  // retained-source provenance link, regardless of the export's filename.
  let raw_path = unique_import_path(imported_dir, "references.ris")
  @fsx.write_bytes(raw_path, bytes, create=0o644)
  let records = parse_ris(@utf8.decode(bytes, ignore_bom=true)) catch {
    error =>
      fail("RIS import failed; original retained at \{raw_path}: \{error}")
  }
  let sources_dir = workspace.wiki_dir + "/sources"
  @fsx.make_directory(sources_dir, recursive=true, exists_ok=true)
  let raw_reference = relative_to_root(raw_path, workspace.root)
  let references : Array[RisImportedReference] = []
  for index, record in records {
    let slug_title = slugify_title(record.title)
    let slug_title = if slug_title.length() > 100 {
      slug_title[:100].to_owned()
    } else {
      slug_title
    }
    let slug = unique_source_slug(
      sources_dir,
      "ris-" + (if slug_title.is_empty() { "reference" } else { slug_title }),
    )
    let relative_page = "sources/" + slug + ".md"
    let citation = "wiki/" + relative_page
    let page_path = sources_dir + "/" + slug + ".md"
    let raw_link = relative_from_page(citation, raw_reference)
    let ordinal = index + 1
    let summary = "RIS bibliography record \{ordinal}. Supplied reference metadata and abstract; not full text or factual verification."
    let page = moonbook_metadata_block(
        "source",
        record.title,
        summary,
        "accepted",
        "verified",
        ["source", "bibliography", "ris"],
        @async.now().to_string(),
      ) +
      "# " +
      ris_markdown_title(record.title) +
      "\n\n" +
      "- Raw source: [\{raw_reference}](\{raw_link})\n" +
      "- Source type: RIS bibliography reference\n" +
      "- Record number in retained export: \{ordinal}\n" +
      "- Scope: supplied bibliographic metadata; URLs and attachments have not been fetched.\n\n" +
      "## Summary\n\n" +
      summary +
      "\n\n" +
      "## Extract\n\n" +
      ris_fenced_text(ris_record_text(record))
    @fsx.write_to_file(page_path, page, create=0o644)
    let safe_title = ris_markdown_title(record.title)
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
      raw_reference,
      relative_page,
      [],
    )
    references.push({
      record_number: ordinal,
      title: record.title,
      citation,
      page_path,
    })
  }
  { raw_path, references, }
}
