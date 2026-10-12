///|
async fn main {
  match @env.args()[1:] {
    [root] =>
      println(@driver.export_epub(root)) catch {
        error => {
          println("EPUB export failed: \{error}")
          @sys.exit(1)
        }
      }
    _ => {
      println(
        "Usage: moonbook-epub <book-root>\nWrites <build-dir>/__moonbook/book.epub. See docs/EPUB_EXPORT.md.",
      )
      @sys.exit(2)
    }
  }
}
