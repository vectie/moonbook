///|
async fn ensure_maintenance_plan_entry(
  workspace : Paths,
  title : String,
  kind : String,
  source_page : String,
  related_pages : Array[String],
  notes : Array[String],
) -> String {
  let relative_page = "synthesis/maintenance-plan.md"
  let plan_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path(relative_page))
    .to_string()
  let existing = if @fsx.exists(plan_path) {
    @fsx.read_file(plan_path)
  } else {
    maintenance_plan_text()
  }
  let source_link = relative_from_page("wiki/" + relative_page, source_page)
  let builder = StringBuilder::new()
  builder.write_string("### \{title}\n\n")
  builder.write_string("- Kind: `\{kind}`\n")
  builder.write_string("- Source: [\{source_page}](\{source_link})\n")
  if !related_pages.is_empty() {
    builder.write_string("- Candidate pages:\n")
    for page in related_pages {
      let link = relative_from_page("wiki/" + relative_page, "wiki/" + page)
      builder.write_string("  - [\{page}](\{link})\n")
    }
  }
  if !notes.is_empty() {
    builder.write_string("- Notes:\n")
    for note in notes {
      builder.write_string("  - \{note}\n")
    }
  }
  builder.write_string("\n")
  let updated = append_section_block(
    existing,
    "## Planned Updates",
    builder.to_string(),
  )
  @fsx.write_to_file(plan_path, updated, create=0o644)
  update_summary(workspace.summary_path, "Maintenance Plan", relative_page)
  update_index_section(
    @path.Path(workspace.wiki_dir).join(@path.Path("index.md")).to_string(),
    "Core Pages",
    "Maintenance Plan",
    relative_page,
    "multi-page synthesis and maintenance queue",
  )
  relative_page
}

///|
fn maintenance_plan_text() -> String {
  "# Maintenance Plan\n\n" +
  "This page tracks planned multi-page wiki updates produced by ingest, query, and review flows.\n\n" +
  "## Planned Updates\n\n" +
  "_None yet._\n"
}
