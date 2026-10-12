///|
/// Load and export an existing book without honoring create-missing. A missing
/// SUMMARY chapter is an error; export never creates editable source files.
pub async fn export_epub(book_root : String) -> String {
  let root = @afs.realpath(book_root)
  let config_path = @pathx.join(root, "book.toml")
  let config = if @fsx.exists(config_path) {
    @core.from_toml(@fsx.read_file(config_path))
  } else {
    @core.default()
  }
  let source_root = @pathx.join(root, config.book.src)
  let summary = @summary.parse_summary(
    @fsx.read_file(@pathx.join(source_root, "SUMMARY.md")),
  )
  let book = load_book_from_disk(summary, source_root)
  MDBook::{ root, config, book, summary, }.export_epub()
}

///|
/// Export the loaded SUMMARY book to <build-dir>/__moonbook/book.epub.
/// This does not run the HTML build or change editable content.
pub async fn MDBook::export_epub(self : MDBook) -> String {
  @html.export_epub(
    @html.new_render_context(
      self.root,
      resolved_build_dir(self.root, self.config),
      self.config,
      preprocess_book(self.book),
    ),
  )
}
