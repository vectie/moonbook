///|
fn is_transcript_source(path : String) -> Bool {
  let ext = @pathx.ext(path).to_owned().to_lower()
  ext == ".vtt" || ext == ".srt"
}

///|
async fn ingest_transcript_source(
  root : String,
  source_path : String,
) -> IngestResult {
  if is_remote_source(source_path) {
    fail("transcript ingestion accepts local files only")
  }
  let workspace = workspace_paths(@fs.realpath(root))
  if !@fsx.exists(workspace.summary_path) ||
    !@fsx.exists(workspace.wiki_dir + "/index.md") {
    fail(
      "transcript import requires an initialized Book; run moonbook wiki init <root> first",
    )
  }
  let input = resolve_input_source(workspace.root, source_path)
  let bytes = @fsx.read_bytes(input)
  if bytes.length() > 1048576 {
    fail("transcript exceeds 1 MiB; split the export")
  }
  let webvtt = @pathx.ext(source_path).to_owned().to_lower() == ".vtt"
  let format = if webvtt { "WebVTT" } else { "SRT" }
  @fsx.make_directory(
    workspace.raw_dir + "/imported",
    recursive=true,
    exists_ok=true,
  )
  let raw_path = unique_import_path(
    workspace.raw_dir + "/imported",
    if webvtt {
      "transcript.vtt"
    } else {
      "transcript.srt"
    },
  )
  @fsx.write_bytes(raw_path, bytes, create=0o644)
  let cues = parse_transcript(bytes, webvtt) catch {
    error =>
      fail(
        "transcript import failed; original retained at \{raw_path}: \{error}",
      )
  }
  let filename = file_stem(input)
    .iter()
    .take(200)
    .map(ch => if ch.to_int() < 32 { ' ' } else { ch })
    .to_array()
  let title = "Transcript: " + String::from_array(filename)
  let sources_dir = workspace.wiki_dir + "/sources"
  @fsx.make_directory(sources_dir, recursive=true, exists_ok=true)
  let slug_title = String::from_array(
    slugify_title(String::from_array(filename)).iter().take(64).to_array(),
  )
  let slug = unique_source_slug(sources_dir, "transcript-" + slug_title)
  let relative_page = "sources/" + slug + ".md"
  let page_path = workspace.wiki_dir + "/" + relative_page
  let relative_raw = relative_to_root(raw_path, workspace.root)
  let raw_link = relative_from_page("wiki/" + relative_page, relative_raw)
  let summary = "Local timed transcript with \{cues.length()} cues. Times are offsets supplied by the export; speaker labels and statements are unverified."
  let extract = cues
    .map(cue => "[" + cue.start + " --> " + cue.end + "] " + cue.text)
    .join("\n\n")
  let page = moonbook_metadata_block(
      "source",
      title,
      summary,
      "accepted",
      "verified",
      ["source", "transcript"],
      @async.now().to_string(),
    ) +
    "# " +
    ris_markdown_title(title) +
    "\n\n" +
    "- Raw source: [\{relative_raw}](\{raw_link})\n" +
    "- Source type: \{format} transcript\n" +
    "- Extraction: complete cue text in export order. Cue identifiers, timing settings, header metadata, NOTE, STYLE and REGION blocks remain in the original only. No audio or video was fetched or transcribed.\n\n" +
    "## Summary\n\n" +
    summary +
    "\n\n## Extract\n\n" +
    ris_fenced_text(extract)
  @fsx.write_to_file(page_path, page, create=0o644)
  let safe_title = ris_markdown_title(title)
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
    title,
    imported: true,
    related_pages: [],
    keeper_packet_path: "",
  }
}
