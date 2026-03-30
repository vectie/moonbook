///|
using @html {a, article, div, h1, li, main_, nav, p, section, span, ul}

///|
fn demo_book() -> @core.Book {
  @core.new_with_items([
    @core.item_chapter(
      @core.chapter(
        "Introduction",
        "# Introduction\n\nMoonBook is being translated from mdBook into MoonBit.",
        number=Some(@core.SectionNumber::new([1])),
        path=Some("introduction.html"),
        source_path=Some("introduction.md"),
      ),
    ),
    @core.item_chapter(
      @core.chapter(
        "Second Chapter",
        "Exact feature parity is still under construction.",
        number=Some(@core.SectionNumber::new([2])),
        path=Some("second.html"),
        source_path=Some("second.md"),
      ),
    ),
  ])
}

///|
fn render_chapter_link(chapter : @core.Chapter) -> @rabbita.Html {
  li([
    a(href=chapter.path.unwrap_or("#"), [
      span(
        class="chapter-number",
        chapter.number.map(fn(n) { n.to_string() }).unwrap_or(""),
      ),
      span(class="chapter-title", chapter.name),
    ]),
  ])
}

///|
fn render_page(book : @core.Book) -> @rabbita.Html {
  let chapters = book.chapters()
  div(class="moonbook-app", [
    nav(class="sidebar", [
      h1("MoonBook"),
      p("Rabbita frontend shell for the MoonBit port of mdBook."),
      ul(chapters.map(render_chapter_link)),
    ]),
    main_(class="content", [
      article([
        h1("MoonBook"),
        p("This Rabbita surface will become the primary browser renderer."),
        section([
          p(
            "Current status: translated core model, summary parsing, and HTML build pipeline.",
          ),
        ]),
      ]),
    ]),
  ])
}

///|
fn main {
  let app = @rabbita.static_cell(render_page(demo_book()))
  @rabbita.new(app).mount("app")
}
